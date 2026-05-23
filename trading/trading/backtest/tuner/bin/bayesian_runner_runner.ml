open Core
module BO = Tuner.Bayesian_opt
module GS = Tuner.Grid_search
module Metric_types = Trading_simulation_types.Metric_types

(** Reason the BO ask/tell loop terminated. Surfaced on {!result} so callers
    (and tests) can detect early-stop without re-reading [convergence.md]. *)
type stop_reason = Budget_exhausted | Early_stopped of { iter : int }

type result = {
  best_params : (string * float) list;
  best_score : float;
  observations : BO.observation list;
  per_iteration_metrics : Metric_types.metric_set list list;
  stop_reason : stop_reason;
}

type evaluator =
  parameters:(string * float) list -> float * Metric_types.metric_set list

(** {1 Checkpoint state}

    [bo_checkpoint.sexp] is written atomically under [out_dir] after every
    [observe] call. On a subsequent [run_and_write] against the same [out_dir],
    the file is loaded and the BO state is reconstructed by replaying the saved
    observations through {!Tuner.Bayesian_opt.observe} — advancing the RNG
    identically to the original run via discarded
    {!Tuner.Bayesian_opt.suggest_next} calls.

    The on-disk shape is private to this module; consumers should treat
    [bo_checkpoint.sexp] as an opaque resume token. *)

type _saved_iteration = {
  parameters : (string * float) list;
  metric : float;
  per_scenario_metrics : Metric_types.metric_set list;
}
[@@deriving sexp]

type _checkpoint = {
  schema_version : int;
  spec : Bayesian_runner_spec.t;
  iterations : _saved_iteration list;
}
[@@deriving sexp]

let _checkpoint_schema_version = 1
let _checkpoint_filename = "bo_checkpoint.sexp"

(** RNG-mismatch tolerance: replayed {!_suggest} must reproduce each saved
    parameter to within this many ULP. Pinned tight (1e-12) so any
    non-determinism — lib upgrade, threading, NaN handling — fails loud. *)
let _replay_epsilon = 1e-12

let _checkpoint_path out_dir = Filename.concat out_dir _checkpoint_filename

let _save_checkpoint ~out_dir ~checkpoint =
  let path = _checkpoint_path out_dir in
  let tmp = path ^ ".tmp" in
  Out_channel.with_file tmp ~f:(fun oc ->
      Out_channel.output_string oc
        (Sexp.to_string_hum (sexp_of__checkpoint checkpoint));
      Out_channel.output_string oc "\n");
  Sys_unix.rename tmp path

let _load_checkpoint_if_exists out_dir =
  let path = _checkpoint_path out_dir in
  if Sys_unix.file_exists_exn path then
    Some (_checkpoint_of_sexp (Sexp.load_sexp path))
  else None

(** Project a spec into the form compared for resume-equality. Excludes
    [total_budget] so a partial run can be resumed under a larger (or smaller)
    budget — the search surface, RNG, scenarios, and objective are what must
    stay constant; the budget only governs when the loop stops. *)
let _spec_for_resume_check (spec : Bayesian_runner_spec.t) =
  { spec with total_budget = 0 }

let _validate_checkpoint ~ck ~spec =
  if ck.schema_version <> _checkpoint_schema_version then
    failwithf "checkpoint schema mismatch — found version %d, expected %d"
      ck.schema_version _checkpoint_schema_version ();
  let expected = Bayesian_runner_spec.sexp_of_t (_spec_for_resume_check spec) in
  let found = Bayesian_runner_spec.sexp_of_t (_spec_for_resume_check ck.spec) in
  if not (Sexp.equal expected found) then
    failwith
      "checkpoint spec mismatch — delete bo_checkpoint.sexp to start over"

(** {1 BO loop} *)

let _suggest spec bo =
  match spec.Bayesian_runner_spec.n_acquisition_candidates with
  | None -> BO.suggest_next bo
  | Some n -> BO.suggest_next_with_candidates bo ~n_candidates:n

let _params_match a b =
  match List.zip a b with
  | Unequal_lengths -> false
  | Ok pairs ->
      List.for_all pairs ~f:(fun ((ka, va), (kb, vb)) ->
          String.equal ka kb && Float.(abs (va -. vb) <= _replay_epsilon))

let _verify_replay ~iter ~replayed ~saved =
  if not (_params_match replayed saved) then
    failwithf "resume RNG mismatch at iter %d" iter ()

(** Re-create the BO state by replaying each saved observation through
    {!BO.observe} after discarding a {!_suggest} call (which advances the RNG
    identically to the original run). The replayed [_suggest] must reproduce the
    saved [parameters] within {!_replay_epsilon}; mismatch aborts with [Failure]
    so silent non-determinism surfaces as a hard failure rather than a corrupted
    resume. *)
let _replay_to_state spec iterations =
  let config = Bayesian_runner_spec.to_bo_config spec in
  let initial = BO.create config in
  List.foldi iterations ~init:initial ~f:(fun i bo it ->
      let replayed = _suggest spec bo in
      _verify_replay ~iter:i ~replayed ~saved:it.parameters;
      BO.observe bo { parameters = it.parameters; metric = it.metric })

let _running_best_so_far rev_obs =
  let observations = List.rev rev_obs in
  let _, rev_running =
    List.fold observations ~init:(Float.neg_infinity, [])
      ~f:(fun (running, acc) (obs : BO.observation) ->
        let next = Float.max running obs.metric in
        (next, next :: acc))
  in
  List.rev rev_running

(** Run the BO ask/tell loop from an arbitrary starting BO state, accumulating
    [(observation, per-scenario metric sets)] in evaluation order. Calls
    [on_observation] after every successful [observe] so the caller can persist
    a checkpoint to disk before the next iteration begins. Honours the optional
    [early_stop_config] on the BO config. *)
let _run_loop spec ~evaluator ~initial_bo ~prior_obs ~prior_metric_sets
    ~iter_offset ~on_observation =
  let config = Bayesian_runner_spec.to_bo_config spec in
  let early_stop_cfg = config.early_stop_config in
  let initial_random = config.initial_random in
  let iters_left = spec.total_budget - iter_offset in
  let prior_rev_obs = List.rev prior_obs in
  let prior_rev_metrics = List.rev prior_metric_sets in
  let rec loop bo iter_idx iters_left rev_obs rev_metrics =
    if iters_left <= 0 then
      (bo, List.rev rev_obs, List.rev rev_metrics, Budget_exhausted)
    else
      match early_stop_cfg with
      | Some cfg
        when BO.should_early_stop cfg ~initial_random
               ~running_best:(_running_best_so_far rev_obs) ->
          ( bo,
            List.rev rev_obs,
            List.rev rev_metrics,
            Early_stopped { iter = iter_idx } )
      | _ ->
          let parameters = _suggest spec bo in
          let metric, per_scenario = evaluator ~parameters in
          let obs = { BO.parameters; metric } in
          let bo = BO.observe bo obs in
          on_observation ~obs ~per_scenario;
          loop bo (iter_idx + 1) (iters_left - 1) (obs :: rev_obs)
            (per_scenario :: rev_metrics)
  in
  loop initial_bo iter_offset iters_left prior_rev_obs prior_rev_metrics

(** {1 Output writers} *)

let _all_metric_types = Backtest.Comparison.all_metric_types

let _format_metric_value metrics mt =
  match Map.find metrics mt with Some v -> sprintf "%.6f" v | None -> ""

let _quote_csv_field s =
  if
    String.exists s ~f:(fun c ->
        Char.equal c ',' || Char.equal c '"' || Char.equal c '\n')
  then "\"" ^ String.substr_replace_all s ~pattern:"\"" ~with_:"\"\"" ^ "\""
  else s

let _csv_line fields =
  String.concat ~sep:"," (List.map fields ~f:_quote_csv_field) ^ "\n"

let _csv_header ~param_keys ~objective =
  let metric_labels =
    List.map _all_metric_types ~f:Backtest.Comparison.metric_label
  in
  let objective_col = "objective_" ^ GS.objective_label objective in
  ("iter" :: param_keys) @ ("scenario" :: metric_labels) @ [ objective_col ]

let _csv_row ~iter ~scenario ~parameters ~metrics ~objective_value =
  let param_values = List.map parameters ~f:(fun (_, v) -> sprintf "%.17g" v) in
  let metric_values =
    List.map _all_metric_types ~f:(_format_metric_value metrics)
  in
  (sprintf "%d" iter :: param_values)
  @ (scenario :: metric_values)
  @ [ sprintf "%.6f" objective_value ]

let _write_bo_log ~output_path ~spec ~objective ~observations
    ~per_iteration_metrics =
  let param_keys = List.map spec.Bayesian_runner_spec.bounds ~f:fst in
  Out_channel.with_file output_path ~f:(fun oc ->
      Out_channel.output_string oc
        (_csv_line (_csv_header ~param_keys ~objective));
      List.iteri (List.zip_exn observations per_iteration_metrics)
        ~f:(fun i ((obs : BO.observation), metric_sets) ->
          List.iter2_exn spec.scenarios metric_sets ~f:(fun scenario metrics ->
              let row =
                _csv_row ~iter:i ~scenario ~parameters:obs.parameters ~metrics
                  ~objective_value:obs.metric
              in
              Out_channel.output_string oc (_csv_line row))))

let _write_best_sexp ?(int_keys = []) ~output_path ~best_params () =
  let sexps = GS.cell_to_overrides ~int_keys best_params in
  let combined = Sexp.List sexps in
  Out_channel.with_file output_path ~f:(fun oc ->
      Out_channel.output_string oc (Sexp.to_string_hum combined);
      Out_channel.output_string oc "\n")

let _convergence_title objective =
  sprintf
    "# Convergence report (objective: `%s`)\n\n\
     Running-best objective across the BO ask/tell loop. The [score] column is \
     the metric for that iteration's suggestion; [running_best] is the best \
     score seen so far up to and including that iteration.\n\n\
     | Iter | Score | Running best |\n\
     |---|---|---|\n"
    (GS.objective_label objective)

(** Stream a running-best line per observation. *)
let _write_convergence_rows oc observations =
  let _running =
    List.foldi observations ~init:Float.neg_infinity ~f:(fun i running obs ->
        let new_running = Float.max running obs.BO.metric in
        Out_channel.output_string oc
          (sprintf "| %d | %.6f | %.6f |\n" i obs.metric new_running);
        new_running)
  in
  ()

(** Tail line emitted by {!_write_convergence_md} that records the reason the BO
    loop terminated. Stable greppable shape so tooling can detect early stops
    without reparsing the table. *)
let _stop_reason_line = function
  | Budget_exhausted -> "\n(stop_reason budget_exhausted)\n"
  | Early_stopped { iter } ->
      sprintf "\n(stop_reason early_stopped (iter %d))\n" iter

let _write_convergence_md ~output_path ~objective ~observations ~stop_reason =
  Out_channel.with_file output_path ~f:(fun oc ->
      Out_channel.output_string oc (_convergence_title objective);
      _write_convergence_rows oc observations;
      Out_channel.output_string oc (_stop_reason_line stop_reason))

(** {1 Top-level} *)

let _result_of bo observations per_iteration_metrics stop_reason =
  match BO.best bo with
  | Some best ->
      {
        best_params = best.parameters;
        best_score = best.metric;
        observations;
        per_iteration_metrics;
        stop_reason;
      }
  | None ->
      {
        best_params = [];
        best_score = Float.neg_infinity;
        observations;
        per_iteration_metrics;
        stop_reason;
      }

(** Resume-or-fresh: if a valid checkpoint exists under [out_dir], reconstruct
    BO state from it; otherwise start from a fresh [BO.create]. Returns
    [(initial_bo, prior_obs, prior_metric_sets, iter_offset)]. *)
let _load_or_init spec ~out_dir =
  match _load_checkpoint_if_exists out_dir with
  | None ->
      let bo = BO.create (Bayesian_runner_spec.to_bo_config spec) in
      (bo, [], [], 0)
  | Some ck ->
      _validate_checkpoint ~ck ~spec;
      let bo = _replay_to_state spec ck.iterations in
      let prior_obs =
        List.map ck.iterations ~f:(fun it ->
            { BO.parameters = it.parameters; metric = it.metric })
      in
      let prior_metrics =
        List.map ck.iterations ~f:(fun it -> it.per_scenario_metrics)
      in
      (bo, prior_obs, prior_metrics, List.length ck.iterations)

(** Build the streaming on-observation callback. Each call appends the new
    iteration to [iterations_ref] (kept in reverse for O(1) prepend) and
    persists the full checkpoint atomically. *)
let _make_checkpoint_writer ~out_dir ~spec ~iterations_ref =
 fun ~(obs : BO.observation) ~per_scenario ->
  let saved =
    {
      parameters = obs.parameters;
      metric = obs.metric;
      per_scenario_metrics = per_scenario;
    }
  in
  iterations_ref := saved :: !iterations_ref;
  let checkpoint =
    {
      schema_version = _checkpoint_schema_version;
      spec;
      iterations = List.rev !iterations_ref;
    }
  in
  _save_checkpoint ~out_dir ~checkpoint

let _initial_iterations_rev ~prior_obs ~prior_metric_sets =
  List.rev
    (List.map2_exn prior_obs prior_metric_sets
       ~f:(fun (obs : BO.observation) per_scenario_metrics ->
         {
           parameters = obs.parameters;
           metric = obs.metric;
           per_scenario_metrics;
         }))

let run_and_write ~(spec : Bayesian_runner_spec.t) ~out_dir ~evaluator =
  Core_unix.mkdir_p out_dir;
  let objective = Bayesian_runner_spec.to_grid_objective spec.objective in
  let initial_bo, prior_obs, prior_metric_sets, iter_offset =
    _load_or_init spec ~out_dir
  in
  let iterations_ref =
    ref (_initial_iterations_rev ~prior_obs ~prior_metric_sets)
  in
  let on_observation = _make_checkpoint_writer ~out_dir ~spec ~iterations_ref in
  let bo, observations, per_iteration_metrics, stop_reason =
    _run_loop spec ~evaluator ~initial_bo ~prior_obs ~prior_metric_sets
      ~iter_offset ~on_observation
  in
  let result = _result_of bo observations per_iteration_metrics stop_reason in
  let log_path = Filename.concat out_dir "bo_log.csv" in
  let best_path = Filename.concat out_dir "best.sexp" in
  let conv_path = Filename.concat out_dir "convergence.md" in
  _write_bo_log ~output_path:log_path ~spec ~objective ~observations
    ~per_iteration_metrics;
  _write_best_sexp ~int_keys:spec.int_keys ~output_path:best_path
    ~best_params:result.best_params ();
  _write_convergence_md ~output_path:conv_path ~objective ~observations
    ~stop_reason;
  result
