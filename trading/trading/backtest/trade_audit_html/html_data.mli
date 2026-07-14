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
}
[@@deriving sexp]
(** One enriched row for the interactive trade table — the report's per-trade
    row plus the [quantity] and [stop_trigger_kind] columns that live only in
    [trades.csv]. *)

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
