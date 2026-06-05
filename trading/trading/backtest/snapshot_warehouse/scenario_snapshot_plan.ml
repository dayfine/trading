open Core
module Scenario = Scenario_lib.Scenario
module Runner = Backtest.Runner

type t = {
  all_symbols : string list;
  warmup_start : Date.t;
  end_date : Date.t;
  benchmark_symbol : string;
}
[@@deriving sexp_of]

let derive ~(scenario : Scenario.t) ~universe =
  let start_date = scenario.period.start_date in
  let warmup_days = Runner.warmup_days_for scenario.strategy in
  {
    all_symbols = Runner.all_snapshot_symbols ~universe;
    warmup_start = Date.add_days start_date (-warmup_days);
    end_date = scenario.period.end_date;
    benchmark_symbol = Runner.primary_index_symbol;
  }
