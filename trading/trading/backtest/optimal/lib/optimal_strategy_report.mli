(** Phase D of the optimal-strategy counterfactual: pure markdown renderer.

    Takes the actual run's round-trips + summary plus the two counterfactual
    variants (Constrained, Relaxed_macro) produced by the
    {!Optimal_portfolio_filler} and emits a markdown string suitable for writing
    to [<output_dir>/optimal_strategy.md].

    {1 Output shape}

    The rendered markdown is composed of, in order:

    - {b Run header.} Period, universe size, scenario name, and a loud
      disclaimer that the counterfactual uses look-ahead and is unrealizable.
    - {b Headline comparison table.} Actual vs Constrained vs Relaxed-macro,
      with a Δ column relative to the Constrained variant. Rows: Total return,
      Win rate, MaxDD, Sharpe, Profit factor, Round-trips, Avg R-multiple.
    - {b Per-Friday divergence table.} For each Friday where the actual and
      Constrained-counterfactual picks differ: the actual picks (symbols +
      sizes), the counterfactual picks, and the top-3 candidates the actual
      could have picked but didn't (with realized R-multiples).
    - {b Trades the actual missed.} Entries the counterfactual took that the
      actual didn't, ranked by realized P&L. Cascade-rejection reasons (when
      provided) are flagged inline.
    - {b Implications.} A short narrative summary keyed off the magnitude of
      [optimal_total_return / actual_total_return].

    {1 Purity}

    Pure function. Every input is a value; every output is the same string for
    the same input. No I/O, no time dependence, no environment lookups.

    See [dev/plans/optimal-strategy-counterfactual-2026-04-28.md] §Phase D. *)

open Core

type variant_pack = {
  round_trips : Optimal_types.optimal_round_trip list;
  summary : Optimal_types.optimal_summary;
}
(** A single counterfactual variant's round-trips + headline summary. {!render}
    consumes one of these per variant (Constrained, Relaxed_macro). *)

type actual_run = {
  scenario_name : string;
      (** Display name for the run (e.g. ["sp500-2019-2023"]). Surfaces in the
          run header. *)
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
  initial_cash : float;
  final_portfolio_value : float;
      (** Mark-to-market portfolio value at [end_date]. Used to derive the
          actual run's total-return percentage for the headline comparison. *)
  round_trips : Trading_simulation.Metrics.trade_metrics list;
      (** Round-trips extracted from the actual run's trades.csv equivalent. *)
  win_rate_pct : float;
      (** Already-aggregated win rate from the actual run's [actual.sexp] (range
          [0.0, 100.0]). Sourced from [Metric_set]'s [WinRate] entry. *)
  sharpe_ratio : float;  (** Sharpe from the actual run's [actual.sexp]. *)
  max_drawdown_pct : float;
      (** MaxDD from the actual run's [actual.sexp] (positive number, range
          [0.0, 100.0]). *)
  profit_factor : float;
      (** Profit factor from the actual run's summary. [Float.infinity] when the
          actual had no losers; [Float.nan] when not computed. *)
  cascade_rejections : (string * string) list;
      (** Optional [(symbol, reason)] pairs harvested from the trade-audit's
          per-Friday cascade summaries / rejection diagnostics. The renderer
          looks up missed-trade symbols in this list to attach a one-line
          rejection reason; entries with no match render without a reason.

          Empty list is the unwired-capture default (no audit available, or
          audit empty). *)
}
(** Bundle of actual-run inputs the renderer consumes. Built by the binary from
    [trades.csv] + [summary.sexp] + (optionally) [trade_audit.sexp]. *)

type input = {
  actual : actual_run;
  constrained : variant_pack;
      (** Counterfactual variant honouring the macro gate. *)
  relaxed_macro : variant_pack;
      (** Counterfactual variant ignoring the macro gate. *)
}
(** Inputs for {!render}. *)

val render : input -> string
(** [render input] returns the full markdown document.

    The output is deterministic for a given [input] — no timestamps, no random
    sampling, no environment-dependent fields. Ends with a single trailing
    newline. *)
