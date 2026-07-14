(** Shared data vocabulary for the interactive trade-audit report.

    The record types the loader ({!Html_report.load}) assembles and the renderer
    ({!Html_render.render}) serializes. Kept in their own module so both the
    render and load layers depend on them without a cycle. *)

open Core

type open_position = {
  symbol : string;
  entry_date : Date.t;
  entry_price : float;
  quantity : float;
  mark : float;  (** Final mark (from [final_prices.csv]); [0.0] when absent. *)
  value : float;  (** [mark * quantity]. *)
  unrealized : float;
      (** [(mark - entry_price) * quantity] for longs; sign-flipped for shorts.
      *)
  gain_pct : float;  (** Percentage move from entry to mark, sign per side. *)
}
[@@deriving sexp]
(** One end-of-run open position, marked at its final price. *)

type trade_series = {
  dates : Date.t list;  (** Weekly bar dates, entry−52w .. exit+26w. *)
  closes : float list;  (** Adjusted weekly closes, aligned to [dates]. *)
  wma30 : float list;
      (** 30-bar linearly-weighted MA of [closes] (the Weinstein weekly WMA30),
          aligned to [dates]; [Float.nan] where fewer than 30 prior bars exist
          (rendered as a gap). *)
  entry_idx : int;  (** Index into [dates] of the first bar >= entry date. *)
  exit_idx : int;  (** Index into [dates] of the first bar >= exit date. *)
  entry_stop : float option;  (** Initial stop from trades.csv, when present. *)
  exit_stop : float option;  (** Stop level at exit, when present. *)
}
[@@deriving sexp]
(** Per-trade weekly chart series: enough to draw the price line, the WMA30
    trend line, the stop levels, and the shaded holding window from one year
    before entry to six months after exit. *)

type trade_row = {
  symbol : string;
  entry_date : Date.t;
  exit_date : Date.t;
  days_held : int;
  entry_price : float;
  exit_price : float;
  quantity : float;
  pnl_dollars : float;
  pnl_percent : float;
  exit_trigger : string;  (** Lowercase label; empty when unknown. *)
  stage : string;  (** Entry-stage label; empty when no audit match. *)
  stop_kind : string;
      (** [stop_trigger_kind] from trades.csv; empty when none. *)
  cascade_score : int option;
  quality : Trade_audit_report.Trade_score.t option;
      (** Composite trade-quality score (0-100 + grade + components). [None]
          when the trade has no matching audit rating. *)
  series : trade_series option;
      (** Chart series; [None] when no bar source was supplied. *)
}
[@@deriving sexp]
(** One enriched row for the interactive trade table — the report's per-trade
    row plus the [quantity] and [stop_trigger_kind] columns that live only in
    [trades.csv], the composite quality score, and the per-trade chart series.
*)

type kpi_tile = { label : string; value : string; sub : string; hero : bool }
[@@deriving sexp]
(** One KPI tile. [value] / [sub] are fully-formatted strings computed from the
    run data — never hardcoded. [hero] highlights the headline tile. *)

type data = {
  scenario_name : string;
  subtitle : string;
  initial_cash : float;
  final_nav : float;
  curve : (Date.t * float) list;
      (** Strategy NAV, downsampled to ~weekly for the chart. *)
  benchmark : (Date.t * float) list option;
      (** Benchmark series indexed to [initial_cash] at the first curve date,
          aligned to the [curve] dates. [None] when no bar source / data. *)
  benchmark_label : string;
  utilization : float list option;
      (** Per-curve-point percentage of NAV deployed in open positions. [None]
          when no bar source was supplied (chart omitted gracefully). *)
  opens : open_position list;
  stale_held : string list;
  kpis : kpi_tile list;
  analysis : Trade_audit_report.analysis option;
      (** Behavioural / conformance / decision-quality aggregates, reused
          verbatim from the report for the summary panels. *)
  trades : trade_row list;
}
[@@deriving sexp]
(** Everything {!Html_render.render} needs. Assembled by {!Html_report.load};
    can be built directly in tests. *)
