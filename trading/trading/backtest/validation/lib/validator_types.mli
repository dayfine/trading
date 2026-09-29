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

type decision_bar_read = {
  close_at_decision : float option; [@sexp.option]
      (** V20: [Trade_audit.entry_decision.close_at_decision] — the RAW daily
          close the strategy saw at decision time. [None] when the audit record
          lacks it. *)
  adjusted_close_at_decision : float option; [@sexp.option]
      (** V20: [Trade_audit.entry_decision.adjusted_close_at_decision] — the
          same bar's ADJUSTED close (issue #2973). [None] on audit files written
          before the field existed. *)
  ma_value : float option; [@sexp.option]
      (** V20: [Trade_audit.entry_decision.ma_value] — the stage classifier's MA
          level, on the ADJUSTED basis. [None] on legacy audit files. *)
}
[@@deriving sexp]
(** The three decision-bar reads V20 compares, grouped so {!entry_context} stays
    within the record-size guideline. Every field is optional because each was
    added to [trade_audit.sexp] at a different time. *)

val no_decision_bar : decision_bar_read
(** All three reads [None] — a legacy audit record with none of them. *)

type entry_context = {
  stage : Weinstein_types.stage;
  macro_trend : Weinstein_types.market_trend;
      (** The macro read at {b placement} (the screen that wrote the ticket) —
          V2's input. Not the read at fill time; V23 reads that from
          {!inputs.screens}. *)
  ma_direction : Weinstein_types.ma_direction;
  resistance_quality : Weinstein_types.overhead_quality option;
  installed_stop : float; [@sexp.default 0.0]
      (** V12/V21: the initial protective stop the strategy actually installed
          ([Trade_audit.entry_decision.installed_stop]). [0.0] on legacy audit
          sexps predating capture — V12 and V21 skip those. *)
  screener_proxy_stop : float option; [@sexp.option]
      (** V21: the screener's fixed-percentage proxy stop
          ([Trade_audit.entry_decision.screener_proxy_stop], ~8% under [E] for a
          long at the screener default). Files written before #3007 carry it
          under the key [suggested_stop]; [Trade_audit]'s reader maps that key,
          so they still populate this field. [None] only when a caller built the
          context without it — V21 skips such rows. *)
  suggested_entry : float; [@sexp.default 0.0]
      (** The screener's graded breakout level [E]
          ([Trade_audit.entry_decision.suggested_entry]); carried for V12's
          specimen detail and the faithfulness harness. *)
  decision_bar : decision_bar_read; [@sexp.default no_decision_bar]
      (** V20's decision-bar reads. *)
}
[@@deriving sexp]
(** Decision-time features a check reads from a {!Trade_audit.entry_decision},
    keyed by [(symbol, entry_date)]. *)

type screen_read = {
  screen_date : Date.t;
      (** The Friday the screen ran ([Trade_audit.cascade_summary.date]). *)
  screen_macro_trend : Weinstein_types.market_trend;
      (** The macro trend that screen read
          ([Trade_audit.cascade_summary.macro_trend]) — the same [Macro.result]
          the #2976 suspension decided on that week. *)
}
(** One weekly screen's macro read, projected from [trade_audit.sexp]'s
    [cascade_summaries]. V23's input. *)

type stop_history = {
  position_id : string;
      (** [Trade_audit.entry_decision.position_id] of the audit record. *)
  symbol : string;
  entry_date : Date.t;
      (** The audit entry date — the {b signal} Friday, not the fill date
          [trades.csv] carries. Used only to label V22 specimens. *)
  decisions : Weinstein_stops.Stop_decision.t list;
      (** [Trade_audit.audit_record.stop_decisions] (#2986), oldest first, with
          runs of same-ISO-week holds already collapsed to their latest row
          ([Stop_decision.push]). [[]] on an audit record that has none — either
          the position never reached a stop update, or the file predates #2986.
      *)
}
(** One audit position's weekly trailing-stop decision record. V22's input. *)

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
  fallback_exit_labels : string list;
      (** V16: the [exit_trigger] values that mark a round trip as closed by a
          {b fallback safety net} rather than by a strategy rule. Default
          [["stale_force_exit"; "margin_call"; "maintenance_reduce";
           "buyin_stress"; "force_liquidation"; "force_liquidation_position";
           "force_liquidation_portfolio"]].

          ["force_liquidation"] is the token the drawdown breaker emits since
          2026-09-14 — it is
          {!Weinstein_strategy.Force_liquidation_runner.exit_label}, carried on
          the exit's [StrategySignal] and surfaced verbatim in [trades.csv]. The
          two [force_liquidation_*] tokens are {b legacy}: they were produced
          only by a [trades.csv] post-processing relabel, removed in the same
          change, and are retained so validator runs over artifacts written
          before it still count those rows.

          ["delisted"] is deliberately absent: a position exited on its
          [active_through] marker is an EXPECTED corporate action, not a defect.
          Configurable so a new safety net can be added to the list the day it
          lands, without touching the check. *)
  stale_entry_days : int;
      (** V17: how many {b calendar} days may separate an entry fill from the
          most recent daily bar at or before it before the fill counts as priced
          against a dead series. Default [7] — clears an ordinary long weekend
          plus an adjacent market holiday, so only a genuinely ended series
          trips it, while still sitting strictly below the 10-day gap of the
          record's second CY entry (2020-04-25, against a series that ended
          2020-04-15) — the specimen V17 was written for. The comparison is
          strict, so a gap of exactly [stale_entry_days] passes. Calendar rather
          than bar count because the question is "how long has this symbol been
          silent", which a bar count cannot express for a symbol that stopped
          printing. *)
  store_median_close_max : float;
      (** V18: a symbol whose {b median} stored close exceeds this many dollars
          is flagged as mis-scaled. Default [10_000.0] — two orders of magnitude
          above a normal US equity, and two below MEL's ~$170k, so the rule has
          room on both sides. Median rather than mean so the handful of $8-12
          prints mixed into MEL's series cannot drag the statistic back toward a
          plausible level. A legitimately high-priced instrument (BRK.A) trips
          this by design; see {!Validator_store_check.check_v18} for why that is
          the right trade for an EXPECTATION check, and raise this ceiling to
          silence it for a run that legitimately holds one. *)
  store_zero_volume_move_pct : float;
      (** V18: a one-bar close move of more than this many percent
          {b on zero volume} is flagged as a phantom print. Default [90.0] —
          MEL's 2017-02-08 bar moved -99.99% ($175,002 -> $12.20) on volume 0.
          Strict, so a move of exactly this size passes. *)
  store_zero_volume_max : int;
      (** V18: the volume at or below which a bar counts as untraded for the
          rule above. Default [0] — literally nobody traded it. Raise it to
          catch the near-zero-volume prints that surround MEL's phantom bars, at
          the cost of flagging genuinely thin real moves. *)
  store_min_bars : int;
      (** V18: fewest stored daily bars a symbol needs before its series is
          judged at all. Default [20] — about a month of trading. A shorter
          series is {!Validator_step.Skip}ped and counted, never passed: a
          median over five bars is not evidence the series is sane. At least one
          bar is always required regardless of this value. *)
  audit_basis_ratio_min : float;
      (** V20: lower bound of the acceptable close-at-decision / [ma_value]
          ratio on an entry decision. Default [0.2]. A ratio {i strictly}
          outside [[audit_basis_ratio_min, audit_basis_ratio_max]] flags; the
          bounds themselves pass. See {!Validator_audit_checks.check_v20} for
          the band's rationale. *)
  audit_basis_ratio_max : float;
      (** V20: upper bound of the same ratio. Default [5.0] — the NVDA
          2021-04-23 specimen (#2973) read raw close 610.61 against an adjusted
          MA of 13.67, a ratio of ~44.7. *)
  installed_tighter_than_proxy_max_pct : float;
      (** V21: an entry flags when its [installed_stop] is {b tighter} (closer
          to entry) than the audit's [screener_proxy_stop] by more than this
          fraction of the proxy — long [(installed - proxy) / proxy], short
          [(proxy - installed) / proxy], strict, so exactly this distance passes
          and a looser stop never flags. Default [0.03]: the #2975 specimen
          (EQT: [E = 23.36], proxy [21.4912] = 8% under E, installed [22.4256] =
          the 4% [Buffer_fallback]) is [0.9344 / 21.4912 = 4.35%] tighter, so it
          fires. Measured on the 210 entries of the five
          [dev/warmup-fix-runs/after-fix1-stop-log/*/trade_audit.sexp] files
          (pre-#3007, legacy [suggested_stop] key, mapped by the reader): 3%
          fires on all 91 Long [Buffer_fallback] entries (min 5.6%) and 2/70
          Long [Support_floor] entries, and 5% would drop the EQT shape; the
          short split and the full rationale are in
          {!Validator_audit_checks.check_v21}. *)
  stalled_ratchet_min_weeks : int;
      (** V22: the shortest no-stop-move stretch, in weeks (x 7 calendar days,
          inclusive), that flags when at least one correction cycle completed
          inside it. Default [13] — the issue's "held >= 13 weeks", the same
          horizon #2982 measured its stall on (stops held >= 13 weeks raised 0
          of 73 times at close/adjusted >= 1.5). The measured distribution
          behind it is in {!Validator_stall_check.check_v22}. *)
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
  skip_reason : string option; [@sexp.option]
      (** Why rows were skipped, when the check can state it (e.g. V19 with no
          [trade_audit.sexp]). Rendered next to the skip count so a check that
          could not evaluate anything never reads as a bare PASS. [None] — and
          absent from the sexp — for every check that does not set it. *)
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
  audit_absent : string option;
      (** [None] when a [trade_audit.sexp] was loaded (even one that matches no
          trade — that is a broken join V19 must flag). [Some reason] when no
          audit was loaded at all; V19-V23 then skip every row and report
          [reason]. *)
  screens : screen_read list;
      (** Every weekly screen's macro read from [trade_audit.sexp]'s
          [cascade_summaries] (V23), in any order. [[]] when no audit was loaded
          ({!audit_absent} says why) {b or} the loaded audit carries no cascade
          summaries — V23 skips every long in both cases, with a reason. *)
  stop_histories : stop_history list;
      (** One {!stop_history} per [trade_audit.sexp] record, in file order
          (V22). [[]] when no audit was loaded ({!audit_absent} says why). A
          loaded pre-#2986 audit yields one history per record, each with
          [decisions = []] — V22 tells that apart from a position that simply
          has no rows and skips with a different reason. *)
  macro_suspend : Weinstein_strategy.Entry_ticket_suspend_mode.t option;
      (** The run's effective [entry_ticket_macro_suspend] (#2976), read from
          the [overrides] in the run's [params.sexp]
          ({!Validator_run_config.load_macro_suspend}). Picks V23's default
          severity: [Some On_bearish_macro] makes it INVARIANT, anything else
          EXPECTATION. [None] when the run's config could not be read. *)
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
(** An {!inputs} with no trades / positions and always-[None] lookups, so
    [audit_absent] is [Some "no trade_audit.sexp supplied"], no [screens], no
    [stop_histories] and [macro_suspend = None]. Tests override individual
    fields via record update — a test that injects an audit lookup and wants V19
    armed must also set [audit_absent = None]. *)
