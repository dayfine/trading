(** Shared types + config for the post-run trade validator (v1).

    See [dev/plans/post-run-validation-2026-07-12.md] for the design and the
    check table (V1-V11 in v1, V12-V15 by amendment), and
    [dev/notes/visual-trade-audit-2026-07-12.md] for the audit that derived
    V5/V6/V7/V9/V10 from real defect specimens. *)

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
  stop_fill_distance_pct : float option;
      (** [stop_fill_distance_pct] column: [|installed_stop - fill| / fill] —
          the fill-basis stop distance the [Stop_too_wide] gate bounds. V14
          reconstructs the installed stop from it, preferring it over the
          E-basis [stop_initial_distance_pct]. [None] when the cell is empty
          (legacy runs whose [trades.csv] predates the column). *)
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
  installed_stop : float; [@sexp.default 0.0]
      (** V12: the initial protective stop the strategy actually installed
          ([Trade_audit.entry_decision.installed_stop]). [0.0] on legacy audit
          sexps predating capture — V12 skips those. *)
  suggested_entry : float; [@sexp.default 0.0]
      (** The screener's graded breakout level [E]
          ([Trade_audit.entry_decision.suggested_entry]); carried for V12's
          specimen detail and the faithfulness harness. *)
}
[@@deriving sexp]
(** Decision-time features a check reads from a {!Trade_audit.entry_decision},
    keyed by [(symbol, entry_date)]. *)

type daily_bar = {
  date : Date.t;
  open_price : float;
  high : float;
  low : float;
  close : float;
  adjusted_close : float;
      (** The bar's {b adjusted} close — the one non-raw field on this record,
          carried for V15. Splits and dividends are back-rolled out of it, so a
          day-over-day jump in {i this} series is a corporate-action-free price
          discontinuity (a feed splice), whereas the same jump in [close] is
          just as likely to be an ordinary split. *)
  volume : int;
}
(** One daily OHLCV bar. The OHLC prices are the {b raw} (unadjusted) ones the
    simulator itself fills against ([Simulator] reads [Daily_price.open_price] /
    [.high_price] / [.low_price] / [.close_price], never [adjusted_close]), so
    V13's fill-in-range check and the fill prices in [trades.csv] share one
    basis. [volume] is likewise raw, which is what V3's dollar-ADV needs.
    [adjusted_close] is the lone exception, and only V15 reads it. *)

type bars = {
  weekly_dates : Date.t array;  (** Ascending weekly-bar dates. *)
  weekly_closes : float array;
      (** Adjusted weekly closes, parallel to dates. *)
  daily : daily_bar array;  (** Ascending daily OHLCV bars. *)
}
(** Per-symbol bar series used by the bar-dependent checks (V3, V7, V9, V10,
    V13, V14, V15). Note the two series are on {b different} price bases:
    [weekly_closes] is adjusted, [daily] is raw apart from its [adjusted_close]
    field. *)

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
  gate_max_stop_distance_pct : float;
      (** V12: the strategy's own [stops_config.max_stop_distance_pct]
          [Stop_too_wide] gate (default 0.15). A filled entry whose installed
          stop sits farther than this from its fill price is an invariant break
          — the gate that should have rejected it did not fire. *)
  fill_price_epsilon_pct : float;
      (** V13: relative slack allowed when testing a fill price against its
          bar's [[low, high]] — the range is widened to
          [[low * (1 - eps), high * (1 + eps)]]. Absorbs the last-digit rounding
          of the CSV price columns, not a real out-of-range fill. *)
  entry_bar_stopout_max_bars : int;
      (** V14: how many trading bars may elapse after the entry bar (through the
          exit bar inclusive) for an exit to still count as "on or right after
          the entry bar". [1] = same-day or next-trading-day exits. Bar counted,
          not calendar days, so a Friday entry exiting Monday is one bar and a
          Saturday-dated exit is zero. *)
  splice_pnl_pct_threshold : float;
      (** V15: only a round trip whose |P&L| exceeds this many percent is a
          splice candidate. Default [100.0] — a >100% move is the shape a
          ticker-reuse splice produces, not an ordinary few-day trade. *)
  splice_max_days_held : int;
      (** V15: and only when it was held at most this many {b calendar} days.
          Default [5]. Calendar rather than bar count so a Friday-to-Monday
          three-day hold reads as 3, matching how the CHS specimen was
          described. *)
  splice_adj_ratio_min : float;
      (** V15: lower bound of the acceptable day-over-day [adjusted_close]
          ratio. Default [0.4]. *)
  splice_adj_ratio_max : float;
      (** V15: upper bound of the same ratio. Default [2.5] — the CHS 2004-12-20
          splice was 3.9x. A ratio {i strictly} outside
          [[splice_adj_ratio_min, splice_adj_ratio_max]] flags; the bounds
          themselves pass. *)
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
