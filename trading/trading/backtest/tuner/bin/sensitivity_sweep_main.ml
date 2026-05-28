(** CLI wrapper for {!Tuner_bin.Sensitivity_sweep}.

    Loads a BO checkpoint + baseline aggregate, generates ±5% / ±10%
    perturbations of each knob at the best cell, runs each through the
    walk-forward executor, scores each via
    {!Tuner_bin.Bayesian_runner_scoring.score_cell_with_penalty}, and writes a
    markdown report flagging knobs whose perturbations drop the score by more
    than 50% of the best cell's improvement over baseline.

    Usage:

    {v
      sensitivity_sweep_main.exe --checkpoint <bo_checkpoint.sexp>
                                 --walk-forward-spec <spec.sexp>
                                 --baseline-aggregate <aggregate.sexp>
                                 --out <report.md>
                                 [--fixtures-root <path>]
                                 [--parallel N]   (default 1, max 16)
    v}

    See {!Tuner_bin.Sensitivity_sweep}'s [.mli] for the algorithm + the per-
    knob perturbation set. *)

open Core
module Scenario = Scenario_lib.Scenario
module Fixtures_root = Scenario_lib.Fixtures_root
module Reader = Tuner_bin.Bo_checkpoint_reader
module Sweep = Tuner_bin.Sensitivity_sweep
module Spec = Tuner_bin.Bayesian_runner_spec
module Scoring = Tuner_bin.Bayesian_runner_scoring
module Wf_spec = Walk_forward.Spec
module Wf_executor = Walk_forward.Walk_forward_executor
module Wf_report = Walk_forward.Walk_forward_report
module Wf_types = Walk_forward.Walk_forward_types
module GS = Tuner.Grid_search

let _usage_msg =
  "Usage: sensitivity_sweep_main.exe --checkpoint <bo_checkpoint.sexp>\n\
  \  --walk-forward-spec <spec.sexp>\n\
  \  --baseline-aggregate <aggregate.sexp>\n\
  \  --out <report.md>\n\
  \  [--fixtures-root <path>]\n\
  \  [--parallel N]   (default 1, max 16)"

let _default_parallel = 1
let _baseline_label_for_run = "baseline"

(** Label assigned to the unperturbed best cell when re-executed for the
    baseline-score data point. *)
let _best_label_for_run = "bo-iter-best"

(** Label-prefix for perturbation candidates. Suffix per-perturbation is
    "knob-N-pct-M" so executor logs and the markdown table line up. *)
let _candidate_label_prefix = "sensitivity"

type cli_args = {
  checkpoint_path : string;
  walk_forward_spec_path : string;
  baseline_aggregate_path : string;
  out_path : string;
  fixtures_root : string option;
  parallel : int;
}

let _parse_parallel raw =
  let n =
    try Int.of_string raw
    with _ ->
      eprintf "Error: --parallel expects an integer, got %S\n%s\n" raw
        _usage_msg;
      Stdlib.exit 1
  in
  if n < 1 || n > Fork_pool.max_parallel then begin
    eprintf "Error: --parallel must be in [1, %d], got %d\n%s\n"
      Fork_pool.max_parallel n _usage_msg;
    Stdlib.exit 1
  end;
  n

let _parse_args argv =
  let rec loop ckpt wf baseline out fixtures parallel = function
    | [] -> (
        match (ckpt, wf, baseline, out) with
        | Some c, Some w, Some b, Some o ->
            {
              checkpoint_path = c;
              walk_forward_spec_path = w;
              baseline_aggregate_path = b;
              out_path = o;
              fixtures_root = fixtures;
              parallel = Option.value parallel ~default:_default_parallel;
            }
        | _ ->
            eprintf "%s\n" _usage_msg;
            Stdlib.exit 1)
    | "--checkpoint" :: p :: rest ->
        loop (Some p) wf baseline out fixtures parallel rest
    | "--walk-forward-spec" :: p :: rest ->
        loop ckpt (Some p) baseline out fixtures parallel rest
    | "--baseline-aggregate" :: p :: rest ->
        loop ckpt wf (Some p) out fixtures parallel rest
    | "--out" :: p :: rest ->
        loop ckpt wf baseline (Some p) fixtures parallel rest
    | "--fixtures-root" :: p :: rest ->
        loop ckpt wf baseline out (Some p) parallel rest
    | "--parallel" :: raw :: rest ->
        loop ckpt wf baseline out fixtures (Some (_parse_parallel raw)) rest
    | ("--help" | "-h") :: _ ->
        printf "%s\n" _usage_msg;
        Stdlib.exit 0
    | unknown :: _ ->
        eprintf "Error: unknown argument %S\n%s\n" unknown _usage_msg;
        Stdlib.exit 1
  in
  loop None None None None None None argv

let _load_aggregate path =
  try Wf_report.aggregate_of_sexp (Sexp.load_sexp path)
  with exn ->
    failwithf "sensitivity_sweep: failed to load aggregate %s: %s" path
      (Exn.to_string exn) ()

let _run_one ~base ~template ~fixtures_root ~parallel ~label ~overrides :
    Wf_types.aggregate =
  let spec =
    Sweep.build_spec_with_baseline ~candidate_label:label
      ~candidate_overrides:overrides ~template
  in
  let result =
    Wf_executor.execute_spec ~base ~spec ~fixtures_root
      ~progress:Wf_executor.noop_progress ~parallel ()
  in
  result.aggregate

let _score_aggregate ~candidate_label ~baseline_label ~candidate_aggregate
    ~baseline_aggregate ~objective ~gate_penalty_value ~parameters : float =
  let result =
    Scoring.score_cell_with_penalty ~gate_penalty_value ~parameters
      ~candidate_label ~baseline_label ~candidate_aggregate ~baseline_aggregate
      ~objective
  in
  match result with
  | Ok s -> s
  | Error err ->
      failwithf "sensitivity_sweep: scoring failed for %S: %s" candidate_label
        (Status.show err) ()

let _label_for ~(index : int) ~(pct : float) : string =
  sprintf "%s-knob-%03d-pct-%+.0f" _candidate_label_prefix index (pct *. 100.0)

(** Re-execute the unperturbed best cell to get the "true" best_score under the
    current scoring formula (rather than trusting [Reader.best_iteration] which
    carries the metric the BO recorded at run-time — may differ if the scorer
    formula has changed since). *)
let _execute_best_cell ~base ~template ~fixtures_root ~parallel
    ~(best_params : (string * float) list) ~(int_keys : string list) :
    Wf_types.aggregate =
  let overrides = GS.cell_to_overrides ~int_keys best_params in
  _run_one ~base ~template ~fixtures_root ~parallel ~label:_best_label_for_run
    ~overrides

let _execute_perturbation ~base ~template ~fixtures_root ~parallel
    ~(int_keys : string list) ~(index : int) (p : Sweep.perturbation) :
    string * Wf_types.aggregate =
  let label = _label_for ~index ~pct:p.pct in
  let overrides = GS.cell_to_overrides ~int_keys p.parameters in
  let aggregate =
    _run_one ~base ~template ~fixtures_root ~parallel ~label ~overrides
  in
  (label, aggregate)

let _score_perturbations ~perturbations ~base ~template ~fixtures_root ~parallel
    ~int_keys ~baseline_aggregate ~baseline_label ~objective ~gate_penalty_value
    : float list =
  List.mapi perturbations ~f:(fun index (p : Sweep.perturbation) ->
      eprintf
        "[sensitivity_sweep] running perturbation %d/%d (knob %S, pct %+.0f%%)\n\
         %!"
        (index + 1)
        (List.length perturbations)
        p.knob (p.pct *. 100.0);
      let label, candidate_aggregate =
        _execute_perturbation ~base ~template ~fixtures_root ~parallel ~int_keys
          ~index p
      in
      _score_aggregate ~candidate_label:label ~baseline_label
        ~candidate_aggregate ~baseline_aggregate ~objective ~gate_penalty_value
        ~parameters:p.parameters)

let _run (args : cli_args) =
  let checkpoint = Reader.load args.checkpoint_path in
  let best, best_idx =
    match
      (Reader.best_iteration checkpoint, Reader.best_iteration_index checkpoint)
    with
    | Some it, Some idx -> (it, idx)
    | _ ->
        failwithf
          "sensitivity_sweep: checkpoint %s contains zero iterations — nothing \
           to evaluate"
          args.checkpoint_path ()
  in
  let bounds = checkpoint.spec.bounds in
  let int_keys = checkpoint.spec.int_keys in
  let objective = Spec.to_grid_objective checkpoint.spec.objective in
  let gate_penalty_value =
    Option.value checkpoint.spec.gate_penalty_value ~default:10.0
  in
  let perturbations =
    Sweep.generate_perturbations ~best_params:best.parameters ~bounds
  in
  eprintf
    "[sensitivity_sweep] best at iter %d (recorded score %.6f); generated %d \
     perturbations across %d knobs\n\
     %!"
    best_idx best.metric
    (List.length perturbations)
    (List.length best.parameters);
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:args.fixtures_root ()
  in
  let template = Wf_spec.load args.walk_forward_spec_path in
  let baseline_label = template.baseline_label in
  let base_path = Filename.concat fixtures_root template.base_scenario in
  let base = Scenario.load base_path in
  let baseline_aggregate = _load_aggregate args.baseline_aggregate_path in
  eprintf "[sensitivity_sweep] re-executing unperturbed best cell\n%!";
  let best_aggregate =
    _execute_best_cell ~base ~template ~fixtures_root ~parallel:args.parallel
      ~best_params:best.parameters ~int_keys
  in
  let best_score =
    _score_aggregate ~candidate_label:_best_label_for_run ~baseline_label
      ~candidate_aggregate:best_aggregate ~baseline_aggregate ~objective
      ~gate_penalty_value ~parameters:best.parameters
  in
  let baseline_score =
    _score_aggregate ~candidate_label:baseline_label ~baseline_label
      ~candidate_aggregate:baseline_aggregate ~baseline_aggregate ~objective
      ~gate_penalty_value ~parameters:[]
  in
  let scores =
    _score_perturbations ~perturbations ~base ~template ~fixtures_root
      ~parallel:args.parallel ~int_keys ~baseline_aggregate ~baseline_label
      ~objective ~gate_penalty_value
  in
  let rows =
    Sweep.build_rows ~best_score ~baseline_score ~perturbations ~scores
  in
  let report : Sweep.report =
    {
      candidate_label_prefix = _candidate_label_prefix;
      baseline_label;
      best_iteration_index = best_idx;
      best_score;
      baseline_score;
      rows;
    }
  in
  let md =
    Sweep.render_report report ~checkpoint_path:args.checkpoint_path
      ~walk_forward_spec_path:args.walk_forward_spec_path
      ~baseline_aggregate_path:args.baseline_aggregate_path
  in
  Out_channel.write_all args.out_path ~data:md;
  let sensitive_count = List.count rows ~f:(fun r -> r.sensitive) in
  eprintf
    "[sensitivity_sweep] wrote %s (best_score=%.6f, baseline_score=%.6f, \
     sensitive_rows=%d/%d)\n\
     %!"
    args.out_path best_score baseline_score sensitive_count (List.length rows)

let () =
  let argv = Array.to_list (Sys.get_argv ()) |> List.tl_exn in
  let args = _parse_args argv in
  _run args
