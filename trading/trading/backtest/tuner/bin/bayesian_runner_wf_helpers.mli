(** Walk-forward-mode helpers for [bayesian_runner.exe], extracted from the
    executable's entry module. *)

val walk_forward_candidate_label : string
(** Label assigned to the best cell when it is re-executed end-to-end for OOS
    validation. *)

val load_aggregate : string -> Walk_forward.Walk_forward_report.aggregate
(** Load an [aggregate.sexp] file; fails with a descriptive message on error. *)

val wf_spec_with_placeholder_scenario :
  Bayesian_runner_spec.t -> Bayesian_runner_spec.t
(** Give a walk-forward spec a one-element placeholder [scenarios] list so the
    [bo_log.csv] writer does not raise. *)

val execute_best_cell_walk_forward :
  ?int_keys:string list ->
  best_params:(string * float) list ->
  walk_forward_spec:Walk_forward.Spec.t ->
  base:Scenario_lib.Scenario.t ->
  fixtures_root:string ->
  parallel:int ->
  unit ->
  Walk_forward.Walk_forward_report.fold_actual list
(** Re-execute the walk-forward sweep for the BO's best cell (baseline vs
    candidate) and return the per-fold rows for OOS validation. *)

val write_oos_report :
  out_dir:string ->
  oos_result:Bayesian_runner_oos_validator.oos_result ->
  spec_path:string ->
  baseline_label:string ->
  unit
(** Write [oos_report.md] under [out_dir] and log the verdict. *)
