(** The initial-stop half of the entry decision. See [entry_stop_check.mli]. *)

open Core

type initial_stops = {
  placed : Weinstein_stops.stop_state;
  placed_kind : Audit_recorder.stop_floor_kind;
  placed_basis : Audit_recorder.split_safe_basis;
  placed_distance_pct : float;
  gate_kind : Audit_recorder.stop_floor_kind;
  gate_distance_pct : float;
}

type decision = Lacks_structural_stop | Width of Stop_width_mode.outcome

type t = {
  decision_bar : Types.Daily_price.t option;
  effective_entry : float;
  stops : initial_stops;
  max_stop_distance_pct : float;
  decision : decision;
}

let _distance_from ~entry stop =
  Entry_audit_helpers.stop_distance_pct ~effective_entry:entry
    ~installed_stop:(Weinstein_stops.get_stop_level stop)

(* [placed] is the stop installed at [effective_entry]. Without [gate_entry]
   the decisions read its floor kind and distance, so the default path is
   unchanged. With [Some e] ({!Entry_cap_stop_gate}) they read those of the stop
   the ticket would install at [e]; [stop_at] runs the §5.1 re-anchor test of
   the placed stop at [e] too, so both carry the same floor kind. *)
let _initial_stops ~stop_at ~gate_entry ~effective_entry =
  let placed, placed_kind, placed_basis = stop_at ~gate_entry effective_entry in
  let placed_distance_pct = _distance_from ~entry:effective_entry placed in
  let gate_kind, gate_distance_pct =
    match gate_entry with
    | None -> (placed_kind, placed_distance_pct)
    | Some entry ->
        let stop, kind, _basis = stop_at ~gate_entry:None entry in
        (kind, _distance_from ~entry stop)
  in
  {
    placed;
    placed_kind;
    placed_basis;
    placed_distance_pct;
    gate_kind;
    gate_distance_pct;
  }

(* Investor-preset gate ([require_structural_stop], book Ch. 6: "investors
   should never use automatic percentages"). Rejects a candidate whose initial
   stop is the automatic-percentage fallback, before the width gate: a ticket
   with no structural stop is not one the investor places at any width. Side-
   agnostic — the fallback and its tag are shared by both sides, and Ch. 7 makes
   the 4-6% buy-stop trader-only on the short side too. *)
let _lacks_required_structural_stop ~require_structural_stop
    ~(floor_kind : Audit_recorder.stop_floor_kind) =
  require_structural_stop
  && match floor_kind with Buffer_fallback -> true | Support_floor -> false

(* G15 step 3, F3-parameterised: the width gate reads the gate distance. *)
let _decide ~require_structural_stop ~stop_width ~max_stop_distance_pct
    (stops : initial_stops) =
  if
    _lacks_required_structural_stop ~require_structural_stop
      ~floor_kind:stops.gate_kind
  then Lacks_structural_stop
  else
    Width
      (Stop_width_mode.gate ~policy:stop_width ~max_stop_distance_pct
         ~stop_distance_pct:stops.gate_distance_pct)

let evaluate ?(min_stop_distance_pct = 0.0) ?(trigger_at_suggested = false)
    ?(stop_anchor_at_entry_base = false)
    ?(continuation_stop_at_pullback_low = false)
    ?(require_structural_stop = false)
    ?(stop_width = Stop_width_mode.default_policy) ?gate_entry ~stops_config
    ~initial_stop_buffer ~bar_reader ~current_date
    (cand : Screener.scored_candidate) =
  let decision_bar =
    Entry_audit_helpers.latest_bar ~bar_reader ~current_date cand
  in
  let effective_entry =
    Entry_audit_helpers.effective_entry_of_close ~trigger_at_suggested
      ~close:
        (Option.map decision_bar ~f:(fun b -> b.Types.Daily_price.close_price))
      cand
  in
  (* The book §5.1 stop re-anchor only fires for the E-family entry: it pairs a
     stop just under the breakout base with an entry AT the breakout, so it is
     meaningful only when [trigger_at_suggested] anchors the entry at E. *)
  let reanchor_to_entry_base =
    stop_anchor_at_entry_base && trigger_at_suggested
  in
  let stop_at ~gate_entry entry =
    Entry_audit_helpers.initial_stop_and_kind ~min_stop_distance_pct
      ~continuation_stop_at_pullback_low ~reanchor_to_entry_base ?gate_entry
      ~stops_config ~initial_stop_buffer ~bar_reader ~current_date
      ~effective_entry:entry cand
  in
  let stops = _initial_stops ~stop_at ~gate_entry ~effective_entry in
  let max_stop_distance_pct =
    stops_config.Weinstein_stops.max_stop_distance_pct
  in
  {
    decision_bar;
    effective_entry;
    stops;
    max_stop_distance_pct;
    decision =
      _decide ~require_structural_stop ~stop_width ~max_stop_distance_pct stops;
  }
