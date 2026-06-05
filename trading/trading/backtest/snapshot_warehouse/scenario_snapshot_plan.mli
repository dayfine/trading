(** Pure derivation of the snapshot-warehouse build parameters a backtest
    scenario needs to run correctly in snapshot mode.

    {!Build_scenario_snapshots} resolves a scenario's universe from disk, then
    calls {!derive} to compute the two things a hand-built warehouse routinely
    gets wrong:

    1. The {b warmup-windowed date range}:
    [warmup_start = scenario.start_date - Backtest.Runner.warmup_days_for
     scenario.strategy]. The stage classifier is path-dependent on the
    indicator-series start, so a too-wide or too-narrow window silently changes
    results. 2. The {b complete symbol set}: the scenario's resolved universe
    {e plus} the primary index {e plus} the global macro indices {e plus} the
    SPDR sector ETFs — exactly {!Backtest.Runner.all_snapshot_symbols}. Omitting
    the auxiliary symbols leaves the macro / relative-strength columns
    degenerate and the strategy produces zero trades.

    Keeping the derivation pure (scenario + resolved-universe → plan, no
    filesystem) makes it unit-testable. *)

open Core

type t = {
  all_symbols : string list;
      (** Deduped, sorted union of the resolved universe, the primary index, the
          global macro indices, and the SPDR sector ETFs —
          {!Backtest.Runner.all_snapshot_symbols} applied to [universe]. The
          warehouse must cover every one of these for the run to reproduce. *)
  warmup_start : Date.t;
      (** [scenario.start_date - Backtest.Runner.warmup_days_for
           scenario.strategy]: the inclusive lower bar-window bound to pass to
          {!Build_runner.build} as [start_date] (NOT the scenario's
          [start_date]). *)
  end_date : Date.t;  (** The scenario's [period.end_date], passed through. *)
  benchmark_symbol : string;
      (** The primary index ({!Backtest.Runner.primary_index_symbol}), staged as
          the warehouse benchmark so RS / macro columns are populated. *)
}
[@@deriving sexp_of]

val derive : scenario:Scenario_lib.Scenario.t -> universe:string list -> t
(** [derive ~scenario ~universe] computes the build plan. [universe] is the
    scenario's already-resolved trading symbols (the keys of the sector-map
    override produced from [scenario.universe_path], with synthetics dropped).
    The warmup window is derived from [scenario.strategy] and
    [scenario.period.start_date]; the symbol set from [universe] via
    {!Backtest.Runner.all_snapshot_symbols}; the benchmark from
    {!Backtest.Runner.primary_index_symbol}. *)
