(** Per-trade ratings, behavioural metrics, and Weinstein-conformance scoring.

    PR-4 of the trade-audit plan layers analysis on top of the raw decision
    trail captured by {!Backtest.Trade_audit} (PR-1) and the round-trip P&L in
    [trades.csv]. The module is pure: every function takes an audit record +
    matching trade metric and emits a derived value.

    Three concerns live here:

    - {b Per-trade quantitative ratings} — R-multiple, MFE %, MAE %, and
      hold-time anomaly. Standard Weinstein-style risk metrics (R-multiple is
      "PnL in units of initial risk" — see weinstein-book-reference.md §5).
    - {b 4 behavioural metrics} — over-trading concentration, exit-winners-too-
      early gap, exit-losers-too-late stop-discipline, and entering-losers-too-
      often quartile breakdown. Each yields a numeric summary plus a list of
      outlier trades.
    - {b Weinstein conformance rules R1–R8} — pass/fail/N-A per trade against
      the book's hard rules (no-Stage-4-longs, volume confirmation, macro
      alignment, etc.). Rolls up to a [weinstein_score] in [[0, 1]] per trade
      and a per-rule violation count across the run.

    The aggregator is parameterised by a configurable {!config} record so
    threshold knobs (over-trading bench, MFE-gap, R-multiple loss bound,
    recent-plunge window) live next to their meaning, not as magic numbers in
    the renderer.

    See [dev/plans/trade-audit-2026-04-28.md] §PR-4. *)

open Core
module TA = Backtest.Trade_audit

(** {1 Configuration} *)

type config = {
  trades_per_year_warn : int;
      (** Over-trading threshold (a). Trade counts above this are flagged in the
          report's behavioural section. *)
  concentrated_burst_window_days : int;
      (** Over-trading concentration window (a). A trade is "in a burst" if
          another trade in the same symbol opened within this many days of it.
      *)
  exit_early_mfe_fraction : float;
      (** Exit-winners-too-early threshold (b). A winner is flagged when its
          realised pnl% sits below [mfe% * exit_early_mfe_fraction]. Default 0.5
          means "left at least half the table". *)
  loser_r_multiple_threshold : float;
      (** Exit-losers-too-late threshold (c). A loser is flagged as
          "stop-discipline failure" when [|realized_R| > threshold]. Default 1.5
          means "lost \xe2\x89\xa51.5 R when the initial stop was 1 R". *)
  loser_mae_to_realized_ratio : float;
      (** Exit-losers-too-late drawdown ratio (c). Flagged when a loser's MAE is
          at least [ratio * |realized_R|]. Default 1.5. *)
  recent_plunge_lookback_days : int;
      (** Weinstein R6 lookback (recent-plunge avoidance). Default 30. *)
  recent_plunge_min_drop_pct : float;
      (** Weinstein R6 minimum drop magnitude (e.g. 0.10 = 10%). Default 0.10.
      *)
  recent_plunge_proximity_days : int;
      (** Weinstein R6 max days between drop and entry. Default 5. *)
  volume_confirmation_min_ratio : float;
      (** Weinstein R2 minimum volume ratio for full-credit pass. Default 2.0.
          Trades with volume in [\[1.5, ratio\)] register as marginal rather
          than fail. *)
}
[@@deriving sexp]
(** All knobs in one place — no magic numbers in the analysis layer. *)

val default_config : config
(** Conservative defaults — book-aligned where the book is explicit (R2 = 2.0x
    volume per Ch. 4; R6 = recent-plunge 10% in 30d, 5d proximity), tunable
    where the book is silent (over-trading bench = 50/year). *)

(** {1 Per-trade ratings} *)

type hold_time_anomaly =
  | Stopped_immediately
      (** [days_held \xe2\x89\xa4 3] — likely whipsaw stop-out. *)
  | Held_indefinitely
      (** [days_held \xe2\x89\xa5 365] — strategy never re-evaluated. *)
  | Normal  (** Any other hold duration. *)
[@@deriving sexp, eq]

(** Trade outcome from realised P&L sign. [pnl_dollars > 0] is [Win];
    [pnl_dollars \xe2\x89\xa4 0] is [Loss]. *)
type outcome = Win | Loss [@@deriving sexp, eq]

type rating = {
  symbol : string;
  entry_date : Date.t;
  r_multiple : float;
      (** [pnl_dollars / initial_risk_dollars]. [Float.nan] when
          [initial_risk_dollars] is non-positive (degenerate stop placement at-
          or-above entry). *)
  mfe_pct : float;
      (** Max favourable excursion as a fraction of entry price. Sourced from
          the audit record's [exit_decision]. *)
  mae_pct : float;
      (** Max adverse excursion as a fraction of entry price (negative for
          losing intratrades). *)
  hold_time_anomaly : hold_time_anomaly;
  outcome : outcome;
  weinstein_score : float;
      (** Fraction of applicable Weinstein rules passed by this trade.
          [[0.0, 1.0]]. NA rules (e.g. R5 short-rules on a long trade) drop out
          of both numerator and denominator. *)
}
[@@deriving sexp]
(** Per-trade derived metrics. One {!rating} per round-trip in the run. *)

(** {1 Weinstein conformance rules} *)

type rule_outcome =
  | Pass  (** Rule applies and the trade satisfies it. *)
  | Fail  (** Rule applies and the trade violates it. *)
  | Marginal
      (** Rule applies but only weakly — e.g. R2 with volume in [\[1.5, 2.0\)]
          (acceptable but below book's clean-pass bar). Counts as 0.5 toward the
          per-trade [weinstein_score]. *)
  | Not_applicable
      (** Rule does not apply (e.g. short-side rule on a long trade). Drops from
          the [weinstein_score] denominator. *)
[@@deriving sexp, eq]

type rule_id =
  | R1_long_above_30w_ma_flat_or_rising
      (** Long entry above 30w MA AND MA flat-or-rising at entry. Book §1, §4.1.
      *)
  | R2_long_breakout_volume_2x
      (** Long entry on a Stage-2 breakout with volume \xe2\x89\xa52x avg. Book
          §4.2. *)
  | R3_no_long_in_stage_4
      (** CRITICAL: never long in Stage 4. Book §1 ("Never buy or hold in Stage
          4"). *)
  | R4_short_below_30w_ma_flat_or_falling
      (** Short entry below 30w MA AND MA flat-or-falling. Book §6.1. *)
  | R5_short_stage_4_breakdown
      (** Short entry is a Stage-4 breakdown. Book §6.1. *)
  | R6_no_recent_plunge
      (** Don't enter within [config.recent_plunge_proximity_days] of a
          [config.recent_plunge_min_drop_pct] drop within
          [config.recent_plunge_lookback_days]. *)
  | R7_exit_on_stage_3_to_4
      (** Stop discipline — must exit when stage transitions Stage3 \xe2\x86\x92
          Stage4. Book §5.4. *)
  | R8_macro_alignment
      (** Bullish macro for longs, bearish macro for shorts. Book §2 / §6.1. *)
[@@deriving sexp, eq]

type rule_evaluation = { rule : rule_id; outcome : rule_outcome }
[@@deriving sexp]

val all_rules : rule_id list
(** Canonical ordering of the eight rules — used for stable report output and
    for iterating in tests. *)

val rule_label : rule_id -> string
(** Short human-readable label like ["R3"] for compact report rows. *)

val rule_description : rule_id -> string
(** One-line description of the rule and its book authority. *)

val evaluate_rules : config:config -> TA.audit_record -> rule_evaluation list
(** Apply all eight rules to a single audit record, returning per-rule outcomes.
    Rules that don't apply (e.g. R5 short-rules on a long trade) yield
    {!Not_applicable}. The returned list is in {!all_rules} order. *)

val score_of_rules : rule_evaluation list -> float
(** Roll up rule outcomes into a per-trade score in [[0, 1]]. [Pass] counts 1,
    [Marginal] counts 0.5, [Fail] counts 0; [Not_applicable] is excluded from
    both numerator and denominator. Returns [Float.nan] when every rule is N/A
    (no applicable rules — pathological trade). *)

(** {1 Per-trade rating} *)

val rate :
  config:config ->
  TA.audit_record ->
  Trading_simulation.Metrics.trade_metrics ->
  rating
(** Compute the per-trade rating for a single (audit, trade) pair. The trade
    metric supplies the realised P&L sign (Win/Loss); the audit record supplies
    the initial risk, MFE, MAE, and rule-evaluation inputs. *)

(** {1 Behavioural metrics — the 4 user-requested aggregates} *)

type outlier_trade = { symbol : string; entry_date : Date.t; metric : string }
[@@deriving sexp]
(** A flagged trade in a behavioural-metric outlier list. [metric] carries the
    one-line "what went wrong" text. *)

type over_trading = {
  total_trades : int;
  trades_per_year : float;
      (** [total_trades / years_observed]. [Float.nan] when the period collapses
          to a single day. *)
  exceeds_threshold : bool;
      (** [trades_per_year > config.trades_per_year_warn]. *)
  concentrated_burst_pct : float;
      (** Fraction in [[0, 100]] of trades that sit within
          [config.concentrated_burst_window_days] of another trade in the same
          symbol. *)
  outliers : outlier_trade list;
      (** Trades within the burst window of another trade for the same symbol.
      *)
}
[@@deriving sexp]
(** (a) Over-trading detection. *)

type exit_winners_too_early = {
  winners_evaluated : int;
  flagged_count : int;
      (** Count of winners whose realised pnl% sits below
          [config.exit_early_mfe_fraction \xc3\x97 mfe_pct]. *)
  avg_left_on_table_pct : float;
      (** Average gap [mfe_pct - realized_pct] across all winners (not just
          flagged). Reported as a percentage (e.g. 4.5 for 4.5 percentage
          points). [0.0] when no winners. *)
  outliers : outlier_trade list;
}
[@@deriving sexp]
(** (b) Exit-winners-too-early. *)

type exit_losers_too_late = {
  losers_evaluated : int;
  flagged_count : int;
      (** Losers where [|r_multiple| > config.loser_r_multiple_threshold] OR
          [|mae_R| \xe2\x89\xa5 config.loser_mae_to_realized_ratio \xc3\x97
           |realized_R|]. *)
  stop_discipline_pct : float;
      (** Fraction in [[0, 100]] of losers that exited within 1 R of the initial
          stop ([|r_multiple| \xe2\x89\xa4 1.0]). *)
  outliers : outlier_trade list;
}
[@@deriving sexp]
(** (c) Exit-losers-too-late. *)

type cascade_quartile = Q1_top | Q2 | Q3 | Q4_bottom [@@deriving sexp, eq]

type cascade_quartile_stat = {
  quartile : cascade_quartile;
  trade_count : int;
  win_count : int;
  win_rate_pct : float;
}
[@@deriving sexp]

type entering_losers_often = {
  per_quartile : cascade_quartile_stat list;
      (** Win rate per cascade-score quartile. Quartiles are computed from the
          observed score distribution at runtime — Q1_top holds the highest
          scores. *)
  flagged_count : int;
      (** Sum of trades in the bottom-quartile that were also losers (cascade
          mis-scoring) plus top-quartile losers (systematic blind spot). *)
  outliers : outlier_trade list;
}
[@@deriving sexp]
(** (d) Entering-losers-too-often. Bucketing trades by cascade-score quartile
    surfaces both directions of the calibration error: low scores winning
    (under-rated) and high scores losing (blind spots). *)

type behavioral_metrics = {
  over_trading : over_trading;
  exit_winners_too_early : exit_winners_too_early;
  exit_losers_too_late : exit_losers_too_late;
  entering_losers_often : entering_losers_often;
}
[@@deriving sexp]
(** Composite of the four behavioural metrics. *)

(** {1 Weinstein-conformance aggregate} *)

type rule_violation_summary = {
  rule : rule_id;
  fail_count : int;
  marginal_count : int;
  applicable_count : int;
      (** Trades for which the rule was applicable (Pass + Marginal + Fail).
          Denominator for the per-rule pass-rate. *)
  pass_rate_pct : float;
      (** [[0, 100]]. Fraction of applicable trades that strictly Passed. [0.0]
          when [applicable_count = 0]. *)
}
[@@deriving sexp]

type weinstein_aggregate = {
  per_rule : rule_violation_summary list;
      (** One entry per {!rule_id}, in {!all_rules} order. *)
  spirit_score : float;
      (** Average of per-trade [weinstein_score] across the run, in [[0, 1]].
          [Float.nan] when no trades. *)
  trades_with_critical_violation : outlier_trade list;
      (** Trades that {b failed} a critical rule — currently
          [R3_no_long_in_stage_4]. *)
}
[@@deriving sexp]
(** Run-level rollup of Weinstein conformance. *)

(** {1 Decision-quality matrix} *)

type decision_quality_matrix = {
  per_quartile : cascade_quartile_stat list;
      (** Same shape as [entering_losers_often.per_quartile] — duplicated here
          as the canonical "decision quality" view of the run, ranked by
          [r_multiple] rather than cascade_score. *)
  total_trades : int;
  overall_win_rate_pct : float;
}
[@@deriving sexp]

(** {1 Computation entry-points} *)

val rate_all :
  config:config ->
  audit:TA.audit_record list ->
  trades:Trading_simulation.Metrics.trade_metrics list ->
  rating list
(** Compute one {!rating} per (audit, trade) pair joined by
    [(symbol, entry_date)]. Trades with no matching audit record are skipped —
    the per-trade table in {!Trade_audit_report} retains them for traceability,
    but ratings need the audit's risk/MFE/MAE inputs to compute. *)

val behavioral_metrics_of :
  config:config ->
  ratings:rating list ->
  audit:TA.audit_record list ->
  trades:Trading_simulation.Metrics.trade_metrics list ->
  behavioral_metrics
(** Aggregate the four behavioural metrics from per-trade ratings + audit
    records. The audit list is used to read entry/exit dates for the
    over-trading window; trades supply the period span. *)

val weinstein_aggregate_of :
  config:config ->
  ratings:rating list ->
  audit:TA.audit_record list ->
  weinstein_aggregate
(** Roll per-trade rule evaluations into per-rule pass-rate + spirit score. *)

val decision_quality_matrix_of : ratings:rating list -> decision_quality_matrix
(** Bucket ratings into [r_multiple]-descending quartiles and compute win rate
    by quartile. *)

(** {1 Markdown formatting helpers} *)

val format_behavioral_section : behavioral_metrics -> string list
(** Return the markdown lines for the "Behavioural metrics" report section. The
    result is line-oriented (no trailing newline on each entry); the renderer
    joins with ["\n"]. *)

val format_weinstein_section : weinstein_aggregate -> string list
(** Return the markdown lines for the "Weinstein conformance" report section. *)

val format_decision_quality_section : decision_quality_matrix -> string list
(** Return the markdown lines for the "Decision quality" report section. *)

val format_per_trade_extras : ratings:rating list -> string list
(** Return the markdown lines for the "Per-trade ratings" auxiliary table — one
    row per rating with R-multiple / MFE / MAE / weinstein_score. The main
    per-trade table in {!Trade_audit_report} is left intact; this table is
    appended below it for the rating columns that don't fit there without
    overwhelming the row width. *)
