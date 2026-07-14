(** Self-contained interactive HTML report for a trade-audit run — public
    facade.

    Companion to {!Trade_audit_report} (the markdown renderer). Where the
    markdown output is a static document, this emits a single self-contained
    HTML file — inline CSS + JS, no external requests, renders under a strict
    CSP — with an interactive NAV-vs-benchmark log chart, a capital-utilization
    area chart, an open-positions table, behavioural / conformance panels, and a
    sortable / filterable full-trade table.

    The module reuses {!Trade_audit_report}'s already-computed aggregates: the
    per-trade rows, the behavioural metrics, the Weinstein-conformance rollup,
    and the decision-quality matrix all come from a {!Trade_audit_report.t} —
    this module never re-derives them. It adds only the presentation layer
    ({!Html_render}) plus the extra on-disk series the markdown path does not
    read ({!Html_sources}: equity curve, open positions, final prices, summary
    KPIs, and — when a bar source is supplied — the benchmark and utilization
    series).

    The data vocabulary ({!type:data} and friends) is re-exported from
    {!Html_data}; {!render} is pure; {!load} assembles a {!type:data} from a
    scenario output directory. *)

open Core

include module type of Html_data
(** @inline *)

val render : data -> string
(** Serialize a {!type:data} to a complete self-contained HTML document.
    Deterministic for a given input — no timestamps. *)

val load :
  ?bar_close:(symbol:string -> as_of:Date.t -> float option) ->
  ?benchmark_symbol:string ->
  ?benchmark_label:string ->
  report:Trade_audit_report.t ->
  scenario_dir:string ->
  unit ->
  data
(** Assemble a {!type:data} from a scenario output directory of the shape
    produced by {!Backtest.Result_writer.write}. [report] is the already-loaded
    {!Trade_audit_report.t} for the same directory (reused for rows + analysis +
    header, so aggregates are not recomputed).

    Reads (beyond what the report already consumed): [equity_curve.csv],
    [open_positions.csv], [final_prices.csv], [summary.sexp] KPIs, and
    [trades.csv] (for the per-row [quantity] / [stop_trigger_kind] columns).

    [bar_close ~symbol ~as_of] resolves a symbol's adjusted close at or before a
    date (last-known ≤ date). When supplied, the benchmark and capital-
    utilization series are computed; when omitted, both are dropped and the HTML
    renders strategy-only. [benchmark_symbol] defaults to ["SPY"],
    [benchmark_label] to ["SPY TR"]. *)
