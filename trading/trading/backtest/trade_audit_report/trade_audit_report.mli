(** Trade-audit markdown renderer.

    Joins the per-trade decision trail captured by {!Backtest.Trade_audit} with
    the round-trip P&L records in [trades.csv]
    ({!Trading_simulation.Metrics.trade_metrics}) and emits a markdown report
    summarising what the strategy decided on each entry, what happened, and how
    the round-trips broke down in aggregate.

    PR-3 of the trade-audit plan ships pure formatting only — no analysis.
    Per-trade ratings (R-multiple, MFE/MAE) and aggregate insights
    (Weinstein-conformance, behavioural metrics) layer on top in PR-4.

    The library is pure: {!load} reads the artefacts off disk, {!render}
    produces a deterministic [t] from already-loaded inputs, {!to_markdown}
    formats it. Tests pin the markdown directly via {!render} + {!to_markdown}
    on synthetic data.

    See [dev/plans/trade-audit-2026-04-28.md] §PR-3. *)

open Core

(** {1 Document model}

    The rendered document has three sections — a scenario header, an aggregate
    summary (best / worst, hit-rate), and a per-trade table. All three are
    computed from the inputs at {!render} time and surfaced on {!t} so callers
    can introspect the report before formatting. *)

type scenario_header = {
  scenario_name : string option;
      (** Scenario directory name when known. [None] when the renderer is driven
          from already-loaded values without a directory context. *)
  period_start : Date.t option;
      (** Inclusive start of the backtest window. [None] when no [Summary.t] is
          available and no trades were rendered. *)
  period_end : Date.t option;  (** Inclusive end of the backtest window. *)
  universe_size : int option;
      (** Universe size from the run summary, when available. *)
  total_round_trips : int;
      (** Number of completed round-trip trades joined in the report. *)
  winners : int;  (** Round-trips with [pnl_dollars > 0]. *)
  losers : int;  (** Round-trips with [pnl_dollars <= 0]. *)
  win_rate_pct : float;
      (** [winners / total_round_trips * 100]. [0.0] when no trades. *)
  total_realized_return_pct : float;
      (** Sum of per-trade [pnl_percent] across the round-trips. Pure arithmetic
          — does not adjust for sequencing or compounding; matches the column
          shown in the per-trade table. *)
}
[@@deriving sexp]
(** Header summary for the scenario as a whole. *)

type best_worst = {
  best : (string * Date.t * float) option;
      (** [(symbol, entry_date, pnl_percent)] of the highest-PnL% round-trip.
          [None] when the trade list is empty. *)
  worst : (string * Date.t * float) option;
      (** [(symbol, entry_date, pnl_percent)] of the lowest-PnL% round-trip.
          [None] when the trade list is empty. *)
}
[@@deriving sexp]
(** Best / worst by realised PnL %. *)

type per_trade_row = {
  symbol : string;
  entry_date : Date.t;
  exit_date : Date.t;
  days_held : int;
  side : Trading_base.Types.position_side;
  entry_price : float;
  exit_price : float;
  pnl_dollars : float;
  pnl_percent : float;
  exit_trigger : string;  (** Lowercase label, e.g. ["stop_loss"]. *)
  entry_stage : Weinstein_types.stage option;
      (** Stage at decision time. [None] when no audit record matches. *)
  entry_rs_trend : Weinstein_types.rs_trend option;
      (** RS trend at decision time. [None] when no audit match. *)
  entry_macro_trend : Weinstein_types.market_trend option;
      (** Macro trend at decision time. [None] when no audit match. *)
  cascade_grade : Weinstein_types.grade option;
      (** Cascade grade at decision time. [None] when no audit match. *)
  cascade_score : int option;
      (** Cascade score at decision time. [None] when no audit match. *)
}
[@@deriving sexp]
(** One row in the per-trade table. Fields up through [exit_trigger] come from
    the [trades.csv] / round-trip side; the trailing audit fields are populated
    when a {!Backtest.Trade_audit.audit_record} matches the round-trip on
    [(symbol, entry_date)]. Audit fields are [None] when no [trade_audit.sexp]
    was found or when the audit collector did not capture this entry (e.g.
    pre-PR-2 outputs). *)

type t = {
  header : scenario_header;
  best_worst : best_worst;
  rows : per_trade_row list;
      (** Sorted by [entry_date] ascending then by [symbol] for stable output
          across runs. *)
}
[@@deriving sexp]
(** A complete trade-audit report ready to format. *)

(** {1 Render + format} *)

val render :
  ?scenario_name:string ->
  ?period_start:Date.t ->
  ?period_end:Date.t ->
  ?universe_size:int ->
  trade_audit:Backtest.Trade_audit.audit_record list ->
  trades:Trading_simulation.Metrics.trade_metrics list ->
  unit ->
  t
(** Build a {!t} from already-loaded inputs.

    Joins [trade_audit] to [trades] by [(symbol, entry_date)]. Trades without a
    matching audit record render with all audit fields set to [None] — this is
    the expected state for pre-PR-2 outputs where the capture sites had not yet
    been wired.

    [scenario_name] populates the report header. [period_start], [period_end],
    [universe_size] are echoed into the header verbatim; when [period_start] /
    [period_end] are omitted they are derived from the trades' min entry-date /
    max exit-date. *)

val to_markdown : t -> string
(** Render [t] to a markdown string. Output is deterministic for a given [t] —
    no timestamps, no environment-dependent fields. The trailing newline is
    included. *)

(** {1 Loading from a scenario output directory} *)

val load : scenario_dir:string -> t
(** Load the trade-audit report from a scenario output directory of the shape
    produced by {!Backtest.Result_writer.write}:

    {v
    <scenario_dir>/
      trades.csv             — round-trip P&L (required)
      trade_audit.sexp       — Trade_audit.audit_record list (optional;
                               absent for pre-PR-2 runs — every row's
                               audit fields will be [None])
      summary.sexp           — period + universe size (optional)
    v}

    [scenario_name] is taken from the basename of [scenario_dir]. Raises
    [Failure] if [trades.csv] is missing or malformed. *)
