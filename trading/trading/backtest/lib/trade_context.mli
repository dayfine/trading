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
    - [stop_initial_distance_pct] — [|entry - installed_stop| / entry], the
      fractional distance from entry to the initial stop. 0.08 = 8%.
    - [stop_trigger_kind] — string label from
      {!Stop_log.classify_stop_trigger_kind}: [gap_down] / [intraday] /
      [end_of_period] / [non_stop_exit].
    - [days_to_first_stop_trigger] — calendar days from entry to exit when the
      exit was a stop trigger (Stop_loss); [None] otherwise.
    - [screener_score_at_entry] — cascade score the screener assigned at
      decision time. Links to the [optimal-strategy] oracle for M5.5 ML training
      (per-Friday counterfactual labels).

    Pure projection — no computation beyond simple subtraction / ratio / label
    rendering. The audit + stop-log inputs are joined on [(symbol, entry_date)]
    / [position_id]; trades without a matching audit record return [None] for
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
(** The 6 trailing column names for [trades.csv] in M5.2e order: [entry_stage],
    [entry_volume_ratio], [stop_initial_distance_pct], [stop_trigger_kind],
    [days_to_first_stop_trigger], [screener_score_at_entry]. Producers
    concatenate these onto the legacy 13-column header so consumers can locate
    columns by name. *)

val csv_row_fields : t -> string list
(** Render a {!t} as the 6 trailing CSV cells in the same order as
    {!csv_header_fields}. Floats render at %.4f, ints as decimal, string labels
    verbatim. [None] renders as the empty cell — consumers must tolerate empty
    cells (the canonical M5.2e missing-data sentinel). *)

val of_audit_and_stop_log :
  audit:Trade_audit.audit_record list ->
  stop_infos:Stop_log.stop_info list ->
  trade:Trading_simulation.Metrics.trade_metrics ->
  t
(** Compute the context row for a single trade by joining [audit] and
    [stop_infos] on [(symbol, entry_date)] / [position_id].

    The trade is matched to its audit record by [(symbol, entry_date)] — the
    same key {!Trade_audit_report} uses. Once an audit record is found, its
    [position_id] keys the {!Stop_log.stop_info} lookup; if no audit record
    matches, the stop-log lookup falls back to a by-symbol scan picking the
    first matching info.

    Each of the 6 fields populates independently:
    - Missing audit record → [entry_stage], [entry_volume_ratio],
      [stop_initial_distance_pct], [screener_score_at_entry] all [None].
    - Missing stop-log record (or non-stop exit) → [stop_trigger_kind] /
      [days_to_first_stop_trigger] = [None].

    Pure projection. Same inputs always produce the same output. *)
