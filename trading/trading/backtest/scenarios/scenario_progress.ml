open Core
module Backtest_progress = Backtest.Backtest_progress

let default_every_n_fridays = 4

let make_emitter ~scenario_dir ~every_n_fridays =
  let path = Filename.concat scenario_dir "progress.sexp" in
  {
    Backtest_progress.every_n_fridays;
    on_progress =
      (fun progress -> Backtest_progress.write_atomic ~path progress);
  }
