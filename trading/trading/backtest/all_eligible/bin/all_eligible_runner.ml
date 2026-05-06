(** All-eligible trade-grading diagnostic binary.

    Thin CLI wrapper over
    {!Backtest_all_eligible.All_eligible_runner.run_with_args}. See the runner
    module's docstrings for the pipeline.

    {1 Usage}

    {[
      all_eligible_runner.exe \
        --scenario trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp \
        [--out-dir <path>] \
        [--entry-dollars 5000.0] \
        [--return-buckets -0.5,0.0,0.5] \
        [--config-overrides '((some_key value))']
    ]} *)

open Core

let () =
  let args =
    Backtest_all_eligible.All_eligible_runner.parse_argv (Sys.get_argv ())
  in
  Backtest_all_eligible.All_eligible_runner.run_with_args args
