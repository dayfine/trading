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
  | Spy_only_weinstein of {
      symbol : string;
      ma_period_weeks : int; [@sexp.default 30]
      enable_stage4_short : bool; [@sexp.default false]
    }
      (** Single-instrument Weinstein stage-timing reference strategy on
          [symbol] (default [SPY]). Constructs
          {!Weinstein_strategy.Spy_only_weinstein_strategy.make} with the
          runner's [bar_reader] (it reads the symbol's own weekly + daily bars
          for stage classification and the trailing-stop support floor). Like
          {!Bah_benchmark}, the runner's universe / sector-map / AD-bars
          machinery is loaded but unused; [symbol] must be present in the
          scenario's universe.

          [ma_period_weeks] is the primary tunable dial (per
          [.claude/rules/weinstein-faithful-core.md] — the MA period is the
          documented investor/trader dial). It sets the stage-classifier moving
          average period in weeks. [30] (the [@sexp.default]) is Weinstein's
          investor preset, so every pre-existing scenario that omits the field
          deserialises bit-identically to it; [10] is the faster trader preset.
          The strategy spine (Stage-2-only entry, Stage 3/4 exit, stop below
          base) is untouched by this dial — only the MA window, and the
          proportional weekly-bar lookback derived from it, change.

          [enable_stage4_short] turns the Stage-4 short leg on ([false] default
          = long/flat, bit-identical to the pre-short-leg strategy; every
          pre-existing scenario that omits the field deserialises to it). When
          [true] the strategy goes short in Stage 4 instead of sitting flat — a
          faithful Weinstein adaptation (he shorts Stage-4 declines), gated as a
          default-off testbed dial per
          [.claude/rules/experiment-flag-discipline.md]. See
          {!Weinstein_strategy.Spy_only_weinstein_strategy.config} for the short
          mechanics. *)
  | Sector_rotation_weinstein of {
      k : int; [@sexp.default 1]
      ma_period_weeks : int; [@sexp.default 30]
      enable_macro_gate : bool; [@sexp.default false]
      use_scenario_universe : bool; [@sexp.default false]
      sector_cap : int option; [@sexp.default None]
    }
      (** Sector-rotation Weinstein stage-timing reference strategy — the
          multi-symbol generalization of {!Spy_only_weinstein}. Constructs
          {!Weinstein_strategy.Sector_rotation_weinstein_strategy.make} with the
          runner's [bar_reader]. Each Friday it classifies every tradable SPDR
          sector ETF on its own weekly bars, keeps only the Stage-2 names, ranks
          them by relative strength vs SPY, and holds the top [k]; held names
          that leave the top-[k] set or roll into Stage 3/4 exit to flat, and a
          per-symbol Weinstein trailing stop is checked daily. Long/flat only —
          no shorting, no portfolio-risk sizing (cash is equal-weighted across
          the entry slots filled each Friday). The default tradable symbols are
          the 11 SPDR sector ETFs and the benchmark is SPY; all must be present
          in the scenario's universe so the bar reader loads their bars (SPY is
          the RS benchmark and is never traded). See
          {!Weinstein_strategy.Sector_rotation_weinstein_strategy.config}.

          [k] ([@sexp.default 1]) is the maximum number of concurrent holdings.
          [ma_period_weeks] ([@sexp.default 30], the investor preset) is the
          Weinstein-faithful MA dial (per
          [.claude/rules/weinstein-faithful-core.md]); [10] is the trader
          preset. [enable_macro_gate] ([@sexp.default false]) turns on the
          broad-tape macro gate: when SPY itself is in Stage 4, new sector buys
          are blocked and held sectors are forced flat (Weinstein spine item 6,
          omitted from the bare testbed to isolate selection). Default-off keeps
          every pre-existing sector scenario bit-identical; it is a searchable
          dial per [.claude/rules/experiment-flag-discipline.md].

          [use_scenario_universe] ([@sexp.default false]) selects the tradable
          universe. When [false] (default) the strategy trades the hardcoded 11
          SPDR sector ETFs (its [default_symbols]), so every pre-existing sector
          scenario is bit-identical. When [true] the panel builder instead
          points the strategy at the scenario's own universe (the keys of the
          runner's loaded [ticker_sectors], i.e. every symbol with a snapshot),
          excluding the benchmark symbol so the never-trade-the-benchmark
          invariant holds. This lets the sector-rotation carrier run on an
          arbitrary scenario universe (e.g. a PIT S&P 500 snapshot) rather than
          only the SPDR sectors.

          [sector_cap] ([@sexp.default None]) is an optional per-GICS-sector
          concentration cap on the weekly rotation. When [Some n], at most [n]
          held symbols may share a GICS sector among the RS-ranked Stage-2 picks
          (the builder supplies the symbol→sector lookup from the runner's
          [ticker_sectors]; an unmapped symbol is its own singleton sector,
          never capped). [None] (default) = uncapped top-[k], bit-identical. A
          diversification constraint only — the spine ordering is untouched; a
          searchable default-off dial per
          [.claude/rules/experiment-flag-discipline.md] and faithful per
          [.claude/rules/weinstein-faithful-core.md].

          The strategy spine (Stage-2-only entry, Stage 3/4 exit, stop below
          base, RS for selection) is untouched by all dials. *)
[@@deriving sexp, eq, show]

val default : t
(** [Weinstein]. Used as the [@sexp.default] for {!Scenario.t}'s [strategy]
    field so existing scenarios deserialise unchanged. *)

val name : t -> string
(** Human-readable label for diagnostics, e.g. ["Weinstein"] or
    ["Bah_benchmark(SPY)"]. *)
