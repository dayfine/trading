(** Shared types + config for the post-run trade validator (v1).

    See [dev/plans/post-run-validation-2026-07-12.md] for the design and the
    11-check table, and [dev/notes/visual-trade-audit-2026-07-12.md] for the
    audit that derived V5/V6/V7/V9/V10 from real defect specimens. *)

open Core

(** Whether a failed check indicates a hard bug ({!Invariant}) or a soft quality
    heuristic ({!Expectation}). *)
type severity = Invariant | Expectation [@@deriving sexp, equal]

type trade_row = {
  symbol : string;
  side : string;  (** ["LONG"] / ["SHORT"] from [trades.csv]. *)
  entry_date : Date.t;
  exit_date : Date.t;
  entry_price : float;
  exit_price : float;
  quantity : float;
  exit_trigger : string;  (** [exit_trigger] column, e.g. ["stop_loss"]. *)
  stop_trigger_kind : string;
      (** [stop_trigger_kind] column: [gap_down] / [intraday] / [end_of_period]
          / [non_stop_exit]; empty string when absent. *)
  stop_initial_distance_pct : float option;
      (** [stop_initial_distance_pct] column; [None] when the cell is empty. *)
  position_id : string option;
      (** [position_id] column (trailing column added by #1942), e.g.
          ["A-wein-5618"]. [None] for legacy runs whose [trades.csv] predates
          the column; the audit join falls back to [(symbol, entry_date)] for
          those. *)
}
(** A parsed [trades.csv] round-trip row (only the fields the checks read). *)

type open_row = {
  symbol : string;
  side : string;
  entry_date : Date.t;
  entry_price : float;
  quantity : float;
}
(** A parsed [open_positions.csv] row (position still held at run end). *)

type entry_context = {
  stage : Weinstein_types.stage;
  macro_trend : Weinstein_types.market_trend;
  ma_direction : Weinstein_types.ma_direction;
  resistance_quality : Weinstein_types.overhead_quality option;
}
[@@deriving sexp]
(** Decision-time features a check reads from a {!Trade_audit.entry_decision},
    keyed by [(symbol, entry_date)]. *)

type bars = {
  weekly_dates : Date.t array;  (** Ascending weekly-bar dates. *)
  weekly_closes : float array;
      (** Adjusted weekly closes, parallel to dates. *)
  daily : (Date.t * float * int) array;
      (** Ascending [(date, close_price, volume)] daily bars for dollar-ADV. *)
}
(** Per-symbol bar series used by the bar-dependent checks (V3, V7, V9, V10). *)

type check_config = {
  overhead_pct : float;
      (** V9: a prior top above entry but no more than this fraction above it
          (0.25 = within 25% overhead) flags the entry. *)
  overhead_lookback_bars : int;
      (** V9: weekly-close lookback (weeks) for the prior-top search. *)
  spike_pct : float;
      (** V10: entry-week close more than this fraction above the
          [spike_lookback_weeks]-ago close flags. *)
  spike_lookback_weeks : int;  (** V10: the "N weeks ago" reference offset. *)
  virgin_lookback_bars : int;
      (** V7: min weekly bars of history required to trust a [Virgin_territory]
          label. *)
  min_entry_dollar_adv : float option;
      (** V3: armed only when [Some]; entry-week dollar-ADV below this flags. *)
  adv_lookback_bars : int;  (** V3: daily-bar window for the dollar-ADV mean. *)
  stale_exit_after_days : int option;
      (** V4: armed only when [Some]; an open position whose last bar is older
          than this many days before run end flags. *)
  stop_distance_min_pct : float;  (** V11: lower bound on stop distance. *)
  stop_distance_max_pct : float;  (** V11: upper bound on stop distance. *)
  disabled_checks : string list;  (** Check ids to omit from the report. *)
  severity_overrides : (string * string) list;
      (** [(check_id, "INVARIANT" | "EXPECTATION")] overrides of the default
          severity — the EXP->INV promotion path as gates get armed. *)
}
[@@deriving sexp]
(** Validator thresholds. Every check parameter routes here — no magic numbers
    in the check logic. *)

type specimen = { symbol : string; entry_date : string; detail : string }
[@@deriving sexp]
(** One violating trade: the symbol, its entry date, and the offending value. *)

type check_result = {
  id : string;  (** e.g. ["V1"]. *)
  severity : severity;
  passed : bool;  (** [true] when [n_violations = 0]. *)
  n_violations : int;
  n_skipped : int;
      (** Trades the check could not evaluate (missing audit / bars / basis
          mismatch / gate unarmed). *)
  specimens : specimen list;  (** Up to 10 violating rows. *)
}
[@@deriving sexp]
(** The outcome of one check. *)

type audit_join = { matched : int; total : int } [@@deriving sexp]
(** Audit-join coverage: how many [trades.csv] rows resolved to a
    [trade_audit.sexp] record ([matched]) out of [total] trades. Surfaced in the
    report so a dead join ([matched = 0], the signal-vs-fill entry_date skew
    that silently skipped V1/V2/V7/V8 on the record run) can never again
    masquerade as "PASS (all skipped)". *)

type report = { checks : check_result list; audit_join : audit_join }
[@@deriving sexp]
(** The full validation report — one {!check_result} per enabled check, plus the
    audit-join coverage over the run's trades. *)

type inputs = {
  trades : trade_row list;
  open_positions : open_row list;
  audit : trade_row -> entry_context option;
  bars : string -> bars option;
  run_end : Date.t;
  config : check_config;
}
(** Everything the checks read. Function fields let tests inject synthetic
    lookups without touching the filesystem. *)

val far_future : Date.t
(** A sentinel run-end far past any real bar date; the [empty_inputs] default
    and the run-end fallback when a run has no trades. *)

val default_config : check_config
(** The v1 defaults (overhead 25%, 260-week lookback, spike 60%, gates unarmed).
*)

val load_config : string option -> check_config
(** [load_config path] returns {!default_config} when [path] is [None], else
    parses a {!check_config} sexp from [path]. *)

val empty_inputs : ?config:check_config -> unit -> inputs
(** An {!inputs} with no trades / positions and always-[None] lookups. Tests
    override individual fields via record update. *)
