open Core
module GS = Tuner.Grid_search

let run_and_write ~(spec : Grid_search_spec.t) ~out_dir ~evaluator =
  Core_unix.mkdir_p out_dir;
  let objective = Grid_search_spec.to_grid_objective spec.objective in
  let params = Grid_search_spec.to_grid_param_spec spec.params in
  let result = GS.run params ~scenarios:spec.scenarios ~objective ~evaluator in
  let sensitivity = GS.compute_sensitivity params result in
  let csv_path = Filename.concat out_dir "grid.csv" in
  let best_path = Filename.concat out_dir "best.sexp" in
  let sens_path = Filename.concat out_dir "sensitivity.md" in
  GS.write_csv ~output_path:csv_path ~objective result;
  GS.write_best_sexp ~output_path:best_path result;
  GS.write_sensitivity_md ~output_path:sens_path ~objective sensitivity;
  result
