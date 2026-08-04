(** Runner-path bridge for the {!Fold_health} divergence guard. See
    [fold_health_runner.mli]. *)

open Core

let open_position_count (portfolio : Trading_portfolio.Portfolio.t) =
  List.length portfolio.positions

let divergence_findings ~config (result : Runner.result) =
  Fold_health.check_divergence ~config
    ~n_open_positions:(open_position_count result.final_portfolio)
    ~n_stop_eligible:result.n_stop_eligible_positions

let all_findings ~config (result : Runner.result) =
  let summary = result.summary in
  let equity_curve =
    List.map result.steps
      ~f:(fun (st : Trading_simulation_types.Simulator_types.step_result) ->
        st.portfolio_value)
  in
  Fold_health.check ~config ~initial_cash:summary.initial_cash
    ~final_portfolio_value:summary.final_portfolio_value
    ~n_round_trips:summary.n_round_trips ~n_steps:summary.n_steps ~equity_curve
  @ divergence_findings ~config result

let emit ?(config = Fold_health.default_config) ~output_dir
    (result : Runner.result) =
  let findings = all_findings ~config result in
  List.iter findings ~f:(fun f ->
      eprintf "WARN: fold-health: %s\n%!" (Fold_health.finding_to_string f));
  Sexp.save_hum
    (Filename.concat output_dir "fold_health.sexp")
    ([%sexp_of: Fold_health.finding list] findings)
