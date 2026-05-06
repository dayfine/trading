(** Selector for which trading strategy {!Backtest.Runner.run_backtest}
    instantiates.

    Issue #882. The backtest runner historically hardcoded
    [Weinstein_strategy.make]; this selector lets a scenario file pick a
    different strategy (e.g. {!Trading_strategy.Bah_benchmark_strategy} for a
    Buy-and-Hold-SPY benchmark). The selector is plumbed through {!Scenario.t}
    -> {!Backtest.Runner.run_backtest} -> {!Panel_runner.run}; the runner's
    per-strategy [make] is dispatched in {!Panel_runner}.

    The variant is intentionally small — adding a new strategy means adding one
    constructor here and one match arm in {!Panel_runner._build_strategy} (plus,
    for any strategy that has its own config record, a sexp serialiser). *)

type t =
  | Weinstein
      (** Default. Constructs {!Weinstein_strategy.make} with the runner's
          deps-loaded config (sector map, AD bars, sector ETFs, etc.). All
          existing scenarios that omit the [strategy] field deserialise to this
          constructor — back-compat with every pre-#882 scenario. *)
  | Bah_benchmark of { symbol : string }
      (** Buy-and-Hold benchmark on a single symbol. Constructs
          {!Trading_strategy.Bah_benchmark_strategy.make} with [{ symbol }]. On
          day 1 the strategy buys [floor(initial_cash / close_price)] shares;
          never sells.

          The runner still loads its standard universe / sector-map / AD-bars
          machinery for this branch — wasted work for BAH but cheap when the
          universe is one symbol, and avoids forking a separate runner surface.
          The configurable [symbol] must be present in the scenario's universe
          so the snapshot builder loads its CSV; see [universes/spy-only.sexp]
          for the canonical fixture. *)
[@@deriving sexp, eq, show]

val default : t
(** [Weinstein]. Used as the [@sexp.default] for {!Scenario.t}'s [strategy]
    field so existing scenarios deserialise unchanged. *)

val name : t -> string
(** Human-readable label for diagnostics, e.g. ["Weinstein"] or
    ["Bah_benchmark(SPY)"]. *)
