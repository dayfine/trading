(** Per-trade context columns for [trades.csv] export (M5.2e).

    Joins {!Trade_audit.audit_record}s and {!Stop_log.stop_info}s with the
    completed round-trip {!Trading_simulation.Metrics.trade_metrics} so each
    trade row in [trades.csv] can carry the M5.2e per-trade context fields:

    - [entry_stage] — Stage classification at entry tick (e.g. ["Stage2_late"]).
      Captures the [late : bool] sub-flag inside [Stage2] separately from
      regular Stage2 — late-Stage2 entries are the riskiest class and the M5.2e
      tuner cares about distinguishing them.
    - [entry_volume_ratio] — breakout-bar volume / 4-week avg volume at entry,
      sourced from {!Volume.result.volume_ratio}.
    - [stop_initial_distance_pct] —
      [|suggested_entry - installed_stop| / suggested_entry], the fractional
      distance from the {b screener's} entry [E] to the initial stop. 0.08 = 8%.
      {b E-basis, not fill-basis}: in arms whose fill diverges from [E] this
      overstates stop depth vs cost (the 2026-08-07 confound; findings §4
      RESOLVED) — for gate-basis analysis use [stop_fill_distance_pct].
    - [stop_fill_distance_pct] — [|installed_stop - fill| / fill], the same
      quantity the strategy's [Stop_too_wide] gate bounds and the V12 validator
      checks; [fill] is the round trip's realized entry price. [None] when the
      audit is missing or fill/stop is non-positive.
    - [stop_trigger_kind] — string label from
      {!Stop_log.classify_stop_trigger_kind}: [gap_down] / [intraday] /
      [end_of_period] / [non_stop_exit].
    - [days_to_first_stop_trigger] — calendar days from entry to exit when the
      exit was a stop trigger (Stop_loss); [None] otherwise.
    - [screener_score_at_entry] — cascade score the screener assigned at
      decision time. Links to the [optimal-strategy] oracle for M5.5 ML training
      (per-Friday counterfactual labels).
    - [position_id] — the strategy position ID resolved for this round-trip.
      Taken from the round-trip's own
      {!Trading_simulation.Metrics.trade_metrics.position_id} when the simulator
      recorded an order→position link for its entry fill, else from the matched
      {!Trade_audit.audit_record}. Surfaced as the trailing [trades.csv] column
      so downstream consumers (post-run validator, trade audit tooling) can join
      a trade row back to its {!Trade_audit} / {!Stop_log} record by position
      rather than by the ambiguous [(symbol, entry_date)] tuple — the latter
      misaligns on re-traded symbols. [None] when neither source has one.

    {2 How a trade is joined to its audit record}

    In preference order:

    + {b By position id} — the round-trip's [position_id], looked up against
      [entry.position_id]. Exact and date-independent.
    + {b By exact (symbol, entry_date)}.
    + {b By date proximity} — the most recent audit record for the symbol whose
      [entry.entry_date] is ≤ the fill date and no more than one week before it.

    Steps 2–3 are the historical join and are retained only as the fallback for
    round-trips that carry no position id. They are unreliable on their own: a
    resting entry ticket can fill arbitrarily long after the decision that
    placed it (measured on a 288-trade run: 51% of rows had {e no} audit record
    within a week of the fill, with a mean gap to the nearest prior record of
    ~97 days and a maximum of 1322), and widening the window does not fix it —
    at that spacing "most recent record within the window" stops identifying a
    unique decision, so a re-screened symbol would silently attach the wrong
    one. An empty column is visible; a wrong one is not.

    Pure projection — no computation beyond simple subtraction / ratio / label
    rendering. Trades with no matching audit record return [None] for
    audit-derived fields, mirroring the convention used by
    {!Trade_audit_report.per_trade_row}. *)

open Core

type t = {
  symbol : string;
  entry_date : Date.t;
  entry_stage : string option;
  entry_volume_ratio : float option;
  stop_initial_distance_pct : float option;
  stop_trigger_kind : string option;
  days_to_first_stop_trigger : int option;
  screener_score_at_entry : int option;
  position_id : string option;
  stop_fill_distance_pct : float option;
}
[@@deriving sexp]
(** One per-trade context row, keyed by [(symbol, entry_date)] for join with
    {!Trading_simulation.Metrics.trade_metrics}. *)

val stage_label : Weinstein_types.stage -> string
(** Render a {!Weinstein_types.stage} as the canonical export label. The
    [late : bool] inside [Stage2] expands to ["Stage2_late"] vs ["Stage2"];
    other stages render as bare ["Stage1"] / ["Stage3"] / ["Stage4"]. *)

val stop_trigger_kind_label : Stop_log.stop_trigger_kind -> string
(** Render a {!Stop_log.stop_trigger_kind} as the canonical lowercase export
    label: [gap_down] / [intraday] / [end_of_period] / [non_stop_exit]. *)

val csv_header_fields : string list
(** The 8 trailing column names for [trades.csv]: the 6 M5.2e columns
    ([entry_stage], [entry_volume_ratio], [stop_initial_distance_pct],
    [stop_trigger_kind], [days_to_first_stop_trigger],
    [screener_score_at_entry]), then [position_id], then
    [stop_fill_distance_pct]. Producers concatenate these onto the legacy
    13-column header so consumers can locate columns by name — see
    {!Trades_csv_schema} for the reader side of that lookup. New columns are
    {b appended} so every fixed base-column index used by positional readers
    stays valid (post-run validator's [exit_trigger]=12, [stop_trigger_kind]=16,
    [position_id]=19; faithfulness harness's [stop_initial_distance_pct]=15). *)

val csv_row_fields : t -> string list
(** Render a {!t} as the 8 trailing CSV cells in the same order as
    {!csv_header_fields}. Floats render at %.4f, ints as decimal, string labels
    verbatim. [None] renders as the empty cell — consumers must tolerate empty
    cells (the canonical M5.2e missing-data sentinel). *)

type precomputed
(** Index bundle amortising the audit + stop-log scans across many trades.

    {!of_audit_and_stop_log} rebuilt the audit index per trade — at Cell E 15 y
    scale (~3 700 round-trips × ~3 700 audit records) the per-row build pushed
    [trades.csv] writing into O(N²). Loop callers must hoist {!precompute}
    outside the iter and feed each iteration via {!of_precomputed}. *)

val precompute :
  audit:Trade_audit.audit_record list ->
  stop_infos:Stop_log.stop_info list ->
  precomputed
(** Build the index bundle once. O(N) over the audit + stop-log lists. The
    by-symbol stop-log fallback preserves the head-first semantics of the legacy
    [List.find]: when multiple [stop_info]s share a symbol, the first one in the
    input list wins. *)

val of_precomputed :
  precomputed -> trade:Trading_simulation.Metrics.trade_metrics -> t
(** Compute the context row for a single trade against pre-built indexes.
    Field-population semantics match {!of_audit_and_stop_log}. O(log N) per call
    (Map lookups). *)

val stop_info_for_trade :
  precomputed ->
  trade:Trading_simulation.Metrics.trade_metrics ->
  Stop_log.stop_info option
(** Resolve the {!Stop_log.stop_info} that belongs to [trade], keyed by the
    position ID the round-trip carries (falling back to the one recovered from
    the date-matched audit record, and then to the first {!Stop_log.stop_info}
    for the symbol when no position ID resolves at all).

    This is the {b canonical} trade → stop-info join and the single source of
    truth for every stop-derived [trades.csv] column: {!of_precomputed} uses it
    for [stop_trigger_kind] / [days_to_first_stop_trigger], and the result
    writer uses it for the [entry_stop] / [exit_stop] / [exit_trigger] columns.
    Routing both through this one function keeps those columns mutually
    consistent — the previous symbol-keyed FIFO pop in the writer misaligned
    against this position-keyed lookup on re-traded symbols. O(log N) per call.
*)

val of_audit_and_stop_log :
  audit:Trade_audit.audit_record list ->
  stop_infos:Stop_log.stop_info list ->
  trade:Trading_simulation.Metrics.trade_metrics ->
  t
(** Convenience wrapper: builds {!precomputed} inline and projects one trade.
    Useful for tests or one-shot callers; in a per-trade loop prefer
    {!precompute} + {!of_precomputed} to amortise the index build.

    Each of the 6 fields populates independently:
    - Missing audit record → [entry_stage], [entry_volume_ratio],
      [stop_initial_distance_pct], [screener_score_at_entry] all [None].
    - Missing stop-log record (or non-stop exit) → [stop_trigger_kind] /
      [days_to_first_stop_trigger] = [None].

    Pure projection. Same inputs always produce the same output. *)
