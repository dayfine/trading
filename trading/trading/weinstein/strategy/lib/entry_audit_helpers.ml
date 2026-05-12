(** Private helpers for entry_audit_capture.ml.

    Holds the per-candidate entry-construction primitives and debug-trace
    emitters that would push entry_audit_capture.ml over the file-length limit
    if left inline. All symbols here are implementation detail — nothing is
    exposed via an .mli. *)

open Core
open Trading_strategy

(* ------------------------------------------------------------------ *)
(* Per-candidate entry construction helpers                            *)
(* ------------------------------------------------------------------ *)

(** G14 fix B: pin the entry price the strategy installs into [Position.t] state
    to the most recent raw close from [bar_reader]. The screener's
    [cand.suggested_entry] is a buffered breakout level (typically dollars above
    the actual current price) and historically diverged sharply from the
    broker's fill price for symbols whose lookback spanned a split boundary
    (e.g. PANW pre-split [cand.suggested_entry] in pre-split raw space vs broker
    fill in current raw space — see the G14 deep-dive in [dev/notes/] for the
    cascade timeline).

    Falls back to [cand.suggested_entry] when [bar_reader] returns no bars for
    [cand.ticker] (preserves the test/empty-bars edge). The
    [cand.suggested_entry] field itself remains the screener's audit metadata in
    [build_entry_event]; only the position-state and sizing/stop dollar
    quantities switch to the realised entry. *)
let effective_entry_price ~bar_reader ~current_date
    (cand : Screener.scored_candidate) : float =
  let bars =
    Bar_reader.daily_bars_for bar_reader ~symbol:cand.ticker ~as_of:current_date
  in
  match List.last bars with
  | None -> cand.suggested_entry
  | Some bar -> bar.Types.Daily_price.close_price

(** Compute the support-floor-aware initial stop for [cand] entering at
    [effective_entry], plus the [stop_floor_kind] tag for audit. Mirrors the
    logic in [entry_audit_capture.classify_stop_floor_kind] for the floor-kind
    tag — both key off [Support_floor.find_recent_level_with_callbacks].

    [?min_stop_distance_pct] is an optional floor on the placed stop's distance
    from [effective_entry]: when [Some pct], the resulting [stop_state] is
    widened (if necessary) so the [Initial] [stop_level] is at least [pct] away
    from entry. Used to re-wire {!Screener.candidate_params.initial_stop_pct}
    into the actual installed stop — see
    {!Weinstein_stops.widen_initial_to_min_distance}. *)
let initial_stop_and_kind ?(min_stop_distance_pct = 0.0) ~stops_config
    ~initial_stop_buffer ~bar_reader ~current_date ~effective_entry
    (cand : Screener.scored_candidate) =
  let daily_view =
    Bar_reader.daily_view_for bar_reader ~symbol:cand.ticker ~as_of:current_date
      ~lookback:stops_config.Weinstein_stops.support_floor_lookback_bars
  in
  let callbacks =
    Panel_callbacks.support_floor_callbacks_of_daily_view daily_view
  in
  let raw_stop =
    Weinstein_stops.compute_initial_stop_with_floor_with_callbacks
      ~config:stops_config ~side:cand.side ~entry_price:effective_entry
      ~callbacks ~fallback_buffer:initial_stop_buffer
  in
  let initial_stop =
    Weinstein_stops.Stop_widen.widen_initial_to_min_distance
      ~config:stops_config ~side:cand.side ~entry_price:effective_entry
      ~min_distance_pct:min_stop_distance_pct raw_stop
  in
  let stop_floor_kind : Audit_recorder.stop_floor_kind =
    match
      Weinstein_stops.Support_floor.find_recent_level_with_callbacks ~callbacks
        ~side:cand.side
        ~min_pullback_pct:stops_config.Weinstein_stops.min_correction_pct
    with
    | Some _ -> Support_floor
    | None -> Buffer_fallback
  in
  (initial_stop, stop_floor_kind)

(** Build the [CreateEntering] transition given the pre-computed sizing and
    effective entry. Returns only the transition; the caller constructs
    [entry_meta] from the same inputs without a circular dependency on the type
    defined in [entry_audit_capture]. *)
let build_entry_transition ~id ~current_date ~effective_entry ~shares
    (cand : Screener.scored_candidate) : Position.transition =
  let description =
    Printf.sprintf "Weinstein %s: %s"
      (Weinstein_types.grade_to_string cand.grade)
      (String.concat ~sep:"; " cand.rationale)
  in
  let kind =
    Position.CreateEntering
      {
        symbol = cand.ticker;
        side = cand.side;
        target_quantity = Float.of_int shares;
        entry_price = effective_entry;
        reasoning = Position.ManualDecision { description };
      }
  in
  { Position.position_id = id; date = current_date; kind }

(** G15 step 3: distance between [installed_stop] and [effective_entry] as a
    fraction of [effective_entry]. Symmetric for longs and shorts — both can
    have a structurally wide initial stop when the recent counter-move floor
    sits far from current price. *)
let stop_distance_pct ~effective_entry ~installed_stop =
  Float.abs (installed_stop -. effective_entry) /. effective_entry

(* ------------------------------------------------------------------ *)
(* Debug-trace emitters (off by default)                               *)
(* ------------------------------------------------------------------ *)

(** G15 follow-up (panel-golden cross-platform drift, 2026-05-01): when
    [PANEL_GOLDEN_DEBUG=1] is set in the environment, emit one line per
    candidate to [stderr] capturing the inputs to the [max_stop_distance_pct]
    gate and which branch fires. Used to compare macOS vs Linux GHA traces
    side-by-side and identify which candidate's [stop_distance_pct] flips across
    the threshold due to sub-ULP libm differences. Off by default so normal runs
    (including the goldens) are unaffected.

    Trace also carries the screener's per-candidate [score] (Int) and
    [rationale] (string list, joined with "; ") so cross-platform diffs can pin
    not just the gate outcome but the upstream score that produced the candidate
    order in the first place. The integer score is the sum of variant-gated
    scoring weights — when scores differ across platforms, the divergent
    classifier is upstream of the cascade in
    [analysis/weinstein/{relative_strength, volume,resistance}/]. *)
let emit_candidate_trace ~ticker ~score ~rationale ~effective_entry
    ~installed_stop ~stop_distance_pct ~max_stop_distance_pct ~outcome =
  match Sys.getenv "PANEL_GOLDEN_DEBUG" with
  | Some "1" ->
      let rationale_str = String.concat ~sep:"; " rationale in
      Printf.eprintf
        "CANDIDATE ticker=%s score=%d rationale=%s effective_entry=%.12f \
         installed_stop=%.12f stop_distance_pct=%.12f \
         max_stop_distance_pct=%.12f gate_outcome=%s\n\
         %!"
        ticker score rationale_str effective_entry installed_stop
        stop_distance_pct max_stop_distance_pct outcome
  | _ -> ()

(** G15 follow-up debug: emit a one-line trace per [classify_candidate] decision
    when [PANEL_GOLDEN_DEBUG=1]. Captures the downstream gates (Already_held /
    Insufficient_cash / Short_notional_cap / Kept) that [emit_candidate_trace]
    above does not see, plus the running [remaining_cash] / [short_notional_acc]
    at the moment the decision is made. Used jointly with the [CANDIDATE] trace
    to pin which gate diverges between macOS and Linux GHA. Off by default. *)
let emit_decision_trace ~ticker ~side ~decision ~remaining_cash
    ~short_notional_acc =
  match Sys.getenv "PANEL_GOLDEN_DEBUG" with
  | Some "1" ->
      let side_str =
        match side with
        | Trading_base.Types.Long -> "Long"
        | Trading_base.Types.Short -> "Short"
      in
      Printf.eprintf
        "DECISION ticker=%s side=%s decision=%s remaining_cash=%.6f \
         short_notional_acc=%.6f\n\
         %!"
        ticker side_str decision remaining_cash short_notional_acc
  | _ -> ()
