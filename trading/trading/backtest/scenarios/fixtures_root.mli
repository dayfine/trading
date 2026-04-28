(** Fixtures-root resolution — points at the directory that contains scenario
    fixtures, e.g. [trading/test_data/backtest_scenarios/]. Used by the scenario
    runner to resolve a scenario's [universe_path] field (which is documented as
    "relative to the fixtures root") even when the scenario itself has been
    copied into a per-cell scratch staging directory.

    Two callers:
    - {!Scenario_runner} — receives an optional [--fixtures-root] CLI flag and
      uses [resolve] to combine that with the [TRADING_DATA_DIR] fallback.
    - Tests under [trading/backtest/test/] use [resolve ()] directly with no
      explicit override; the fallback shape works because tests already point
      [TRADING_DATA_DIR] at [trading/test_data/]. *)

val resolve : ?fixtures_root:string -> unit -> string
(** [resolve ?fixtures_root ()] returns an absolute path to the fixtures root.

    - When [fixtures_root] is [Some p], returns [p] unchanged.
    - When omitted, returns
      [Data_path.default_data_dir () / "backtest_scenarios"]. This matches the
      convention "[TRADING_DATA_DIR] points at the [trading/test_data/]
      directory"; tests and perf workflows already use that shape.

    Note: this replaces an older [Fpath.parent + "trading/test_data/..."]
    heuristic that produced doubled-segment paths like
    [.../trading/trading/test_data/backtest_scenarios] when [TRADING_DATA_DIR]
    pointed at [trading/test_data/] instead of the legacy [data/] location. *)
