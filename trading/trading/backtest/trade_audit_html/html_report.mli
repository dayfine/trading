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

(** Which close column a mark must be drawn from.

    This is an {e argument to} the mark supplier rather than a property of it,
    on purpose. {!load} derives two series from marks and they need opposite
    bases (spelled out under [bar_close] below). A supplier cannot pick
    correctly on its own, because the choice follows from arithmetic that lives
    in this module, not at the call site. Passing the requirement down per
    request leaves the supplier one job — honour it — and honouring it means
    matching on this variant, so neither branch can be dropped silently.

    A supplier that writes [~basis:_] and serves one column for both requests is
    wrong for one of the two series, whichever column it picks; that mistake is
    at least visible in the supplier's own source. The previous single-basis
    callback made it invisible at both ends, which is the defect follow-up G4 in
    [dev/status/support-floor-stops.md] exists to close. *)
type price_basis =
  | Adjusted
      (** The split- and dividend-adjusted close column (the snapshot's
          [Adjusted_close] cell). *)
  | Raw
      (** The as-traded close column (the snapshot's [Close] cell) — the basis
          the run's own fills, share counts, and NAV are recorded on. *)

val load :
  ?bar_close:
    (basis:price_basis -> symbol:string -> as_of:Date.t -> float option) ->
  ?weekly_series:
    (symbol:string -> n:int -> as_of:Date.t -> (Date.t * float) array) ->
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

    [bar_close ~basis ~symbol ~as_of] resolves a symbol's close at or before a
    date (last-known ≤ date), {b on the basis it is asked for}. When supplied,
    the benchmark and capital-utilization series are computed; when omitted,
    both are dropped and the HTML renders strategy-only. [benchmark_symbol]
    defaults to ["SPY"], [benchmark_label] to ["SPY TR"].

    The two series ask for different bases, and each is only correct on the one
    it asks for:

    - {b benchmark → {!Adjusted}.} Every point divides a mark by an earlier mark
      of the same symbol. On the raw column a split inside the run reads as a
      price move the benchmark never made — the G14 pathology relocated to the
      reporting layer.
    - {b capital utilization → {!Raw}.} Every term multiplies a mark by a share
      count and divides by NAV. The share count (from [trades.csv] /
      [open_positions.csv]) and the NAV (from [equity_curve.csv], which marks
      positions at the raw close) are both as-traded, so an adjusted mark
      rescales the term by the symbol's split/dividend factor from the mark date
      to the snapshot's last date. Dividends alone make that large: measured on
      [trading/test_data], KO on 2016-03-01 has [adjusted/raw = 0.7253] (−27.5%,
      with no split at all), JNJ 0.7596 (−24.0%), AAPL on 2015-01-02 0.2215
      (−77.9%).

    Serving one column for both requests therefore mis-states one chart or the
    other; there is no single basis that is right for both. Returning [None] is
    always safe — the benchmark then drops the whole series (it requires every
    curve date to resolve) and utilization skips that position for that date.

    [weekly_series ~symbol ~n ~as_of] returns up to [n] weekly [(date, close)]
    bars ending at/before [as_of] (the {!Weinstein_strategy.Bar_reader}
    weekly-view shape). When supplied, every trade row carries a
    {!Html_data.trade_series} (price + WMA30 + stop levels, entry−1y → exit+6mo)
    and the HTML renders an expandable per-trade chart; when omitted, [series]
    is [None] and rows render chart-less. *)
