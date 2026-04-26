(** Selector for the bar-loading strategy used by {!Backtest.Runner}.

    Lives in its own tiny library so that both [backtest] (the runner) and
    [scenario_lib] (the scenario sexp parser) can reference the same type
    without introducing a circular dependency between them.

    After Stage 3 PR 3.3 of the columnar data-shape redesign deleted the Tiered
    runner + [Bar_loader] subsystem, only [Legacy] and [Panel] remain. Both
    paths build [Data_panel.Bar_panels] up-front from CSV; the difference
    between them is incidental (Legacy uses the simulator's per-symbol bar
    loaders for [get_price] visibility, Panel additionally maintains
    panel-backed indicator caches for the strategy's [get_indicator_fn]). *)

type t =
  | Legacy
      (** Pre-existing path: [Backtest.Runner] materializes every universe
          symbol's bars up-front via [Simulator.create]'s per-symbol bar
          loaders. Memory grows with universe size; current production
          behaviour. *)
  | Panel
      (** Stage 1 of the columnar data-shape redesign (see
          [dev/plans/columnar-data-shape-2026-04-25.md]). Builds [Ohlcv_panels]
          + [Indicator_panels] over the universe and supplies the strategy with
            a panel-backed [get_indicator_fn]. The Weinstein strategy reads
            OHLCV bars from {!Data_panel.Bar_panels} (populated up-front from
            CSV at runner start). *)
[@@deriving sexp, show, eq]

val of_string : string -> t
(** Accepts ["legacy"] / ["panel"] (case-insensitive). Raises [Failure] on any
    other input. Used by the [--loader-strategy] CLI flag parser in
    [backtest_runner]. For the reverse direction (value → string, e.g. for log
    formatting) use the ppx-derived [show] / [pp]. *)
