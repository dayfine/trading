(** Runner-path bridge for the {!Fold_health} divergence guard. See
    [fold_health_runner.mli]. *)

open Core

let open_position_count (portfolio : Trading_portfolio.Portfolio.t) =
  List.length portfolio.positions

let divergence_findings ~config (result : Runner.result) =
  Fold_health.check_divergence ~config
    ~n_open_positions:(open_position_count result.final_portfolio)
    ~n_stop_eligible:result.n_stop_eligible_positions
