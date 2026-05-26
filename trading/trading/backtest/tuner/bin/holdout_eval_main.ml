(** CLI wrapper for {!Tuner_bin.Holdout_eval}.

    Loads a BO checkpoint, identifies the best observation, re-runs that
    candidate against the walk-forward executor restricted to the holdout folds
    (as declared in the BO spec's [holdout_folds] field), and writes a markdown
    report.

    Usage:

    {v
      holdout_eval_main.exe --checkpoint <bo_checkpoint.sexp>
                            --walk-forward-spec <spec.sexp>
                            --out <report.md>
                            [--fixtures-root <path>]
                            [--baseline-aggregate <aggregate.sexp>]
                            [--parallel N]   (default 1, max 16)
    v}

    See {!Tuner_bin.Holdout_eval}'s [.mli] for flag semantics. *)

open Core
module Scenario = Scenario_lib.Scenario
module Fixtures_root = Scenario_lib.Fixtures_root
module Reader = Tuner_bin.Bo_checkpoint_reader
module Holdout = Tuner_bin.Holdout_eval
module Spec = Tuner_bin.Bayesian_runner_spec
module Wf_spec = Walk_forward.Spec
module Wf_window = Walk_forward.Window_spec
module Wf_executor = Walk_forward.Walk_forward_executor
module Wf_report = Walk_forward.Walk_forward_report
module Wf_runner = Walk_forward.Walk_forward_runner
module Wf_types = Walk_forward.Walk_forward_types
module GS = Tuner.Grid_search

let _usage_msg =
  "Usage: holdout_eval_main.exe --checkpoint <bo_checkpoint.sexp>\n\
  \  --walk-forward-spec <spec.sexp>\n\
  \  --out <report.md>\n\
  \  [--fixtures-root <path>]\n\
  \  [--baseline-aggregate <aggregate.sexp>]\n\
  \  [--parallel N]   (default 1, max 16)"

let _default_parallel = 1

(** Label assigned to the candidate variant in the synthetic two-variant
    walk-forward spec. Matches the convention {!Bayesian_runner}'s OOS
    re-execution uses, so the markdown report's labels line up with anyone who's
    already familiar with the BO runner's outputs. *)
let _candidate_label = "bo-iter-best"

type cli_args = {
  checkpoint_path : string;
  walk_forward_spec_path : string;
  out_path : string;
  fixtures_root : string option;
  baseline_aggregate_path : string option;
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
  let rec loop ckpt wf out fixtures baseline parallel = function
    | [] -> (
        match (ckpt, wf, out) with
        | Some c, Some w, Some o ->
            {
              checkpoint_path = c;
              walk_forward_spec_path = w;
              out_path = o;
              fixtures_root = fixtures;
              baseline_aggregate_path = baseline;
              parallel = Option.value parallel ~default:_default_parallel;
            }
        | _ ->
            eprintf "%s\n" _usage_msg;
            Stdlib.exit 1)
    | "--checkpoint" :: p :: rest ->
        loop (Some p) wf out fixtures baseline parallel rest
    | "--walk-forward-spec" :: p :: rest ->
        loop ckpt (Some p) out fixtures baseline parallel rest
    | "--out" :: p :: rest ->
        loop ckpt wf (Some p) fixtures baseline parallel rest
    | "--fixtures-root" :: p :: rest ->
        loop ckpt wf out (Some p) baseline parallel rest
    | "--baseline-aggregate" :: p :: rest ->
        loop ckpt wf out fixtures (Some p) parallel rest
    | "--parallel" :: raw :: rest ->
        loop ckpt wf out fixtures baseline (Some (_parse_parallel raw)) rest
    | ("--help" | "-h") :: _ ->
        printf "%s\n" _usage_msg;
        Stdlib.exit 0
    | unknown :: _ ->
        eprintf "Error: unknown argument %S\n%s\n" unknown _usage_msg;
        Stdlib.exit 1
  in
  loop None None None None None None argv

(** Filter a walk-forward spec's fold list to the holdout subset (1-indexed) by
    replacing [window_spec] with an [Explicit] list of just those folds. All
    other spec fields pass through unchanged. *)
let _restrict_spec_to_holdout ~(holdout_folds : int list) (spec : Wf_spec.t) :
    Wf_spec.t =
  let all_folds = Wf_window.generate spec.window_spec in
  let holdout_set = Int.Set.of_list holdout_folds in
  let selected =
    List.filteri all_folds ~f:(fun i _ -> Set.mem holdout_set (i + 1))
  in
  if List.is_empty selected then
    failwithf
      "holdout_eval: no folds match holdout positions [%s] (spec generated %d \
       folds)"
      (String.concat ~sep:" " (List.map holdout_folds ~f:Int.to_string))
      (List.length all_folds) ();
  let explicit =
    List.map selected ~f:(fun (f : Wf_window.fold) : Wf_window.explicit_fold ->
        {
          name = f.name;
          train_period = f.train_period;
          test_period = f.test_period;
        })
  in
  { spec with window_spec = Wf_window.Explicit explicit }

(** Two-variant spec: baseline (empty overrides) + the BO's best cell. The
    baseline variant's label is read off the original walk-forward spec. *)
let _build_two_variant_spec ~(baseline_label : string)
    ~(candidate_label : string) ~(parameters : (string * float) list)
    ~(int_keys : string list) ~(template : Wf_spec.t) : Wf_spec.t =
  let baseline : Wf_runner.variant =
    { label = baseline_label; overrides = [] }
  in
  let candidate : Wf_runner.variant =
    {
      label = candidate_label;
      overrides = GS.cell_to_overrides ~int_keys parameters;
    }
  in
  { template with variants = [ baseline; candidate ] }

(** Load the optional baseline aggregate. Returns [None] when [path] is [None];
    raises [Failure] if the path is supplied but cannot be parsed. *)
let _load_optional_aggregate path =
  match path with
  | None -> None
  | Some p ->
      Some
        (try Wf_report.aggregate_of_sexp (Sexp.load_sexp p)
         with exn ->
           failwithf "holdout_eval: failed to load --baseline-aggregate %s: %s"
             p (Exn.to_string exn) ())

let _baseline_stab_for ~label (aggregate : Wf_types.aggregate option) =
  Option.bind aggregate ~f:(fun agg ->
      List.find agg.stability ~f:(fun s -> String.equal s.variant_label label))

let _run (args : cli_args) =
  let checkpoint = Reader.load args.checkpoint_path in
  let best, best_idx =
    match
      (Reader.best_iteration checkpoint, Reader.best_iteration_index checkpoint)
    with
    | Some it, Some idx -> (it, idx)
    | _ ->
        failwithf
          "holdout_eval: checkpoint %s contains zero iterations — nothing to \
           evaluate"
          args.checkpoint_path ()
  in
  let holdout_folds =
    match checkpoint.spec.holdout_folds with
    | Some xs when not (List.is_empty xs) -> xs
    | _ ->
        failwithf
          "holdout_eval: checkpoint's spec has no [holdout_folds] declared; \
           cannot pick a holdout subset"
          ()
  in
  eprintf
    "[holdout_eval] best at iter %d with score %.6f; %d holdout folds: [%s]\n%!"
    best_idx best.metric
    (List.length holdout_folds)
    (String.concat ~sep:" " (List.map holdout_folds ~f:Int.to_string));
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:args.fixtures_root ()
  in
  let template = Wf_spec.load args.walk_forward_spec_path in
  let base_path = Filename.concat fixtures_root template.base_scenario in
  let base = Scenario.load base_path in
  let holdout_template = _restrict_spec_to_holdout ~holdout_folds template in
  let baseline_label = template.baseline_label in
  let spec =
    _build_two_variant_spec ~baseline_label ~candidate_label:_candidate_label
      ~parameters:best.parameters ~int_keys:checkpoint.spec.int_keys
      ~template:holdout_template
  in
  eprintf
    "[holdout_eval] executing walk-forward on holdout subset (parallel=%d, %d \
     folds × 2 variants)\n\
     %!"
    args.parallel
    (List.length holdout_folds);
  let result =
    Wf_executor.execute_spec ~base ~spec ~fixtures_root
      ~progress:Wf_executor.noop_progress ~parallel:args.parallel ()
  in
  let report =
    Holdout.build_report ~candidate_label:_candidate_label ~baseline_label
      ~holdout_folds ~best_iteration_index:best_idx
      ~best_iteration_score:best.metric ~fold_actuals:result.fold_actuals
  in
  let baseline_aggregate =
    _load_optional_aggregate args.baseline_aggregate_path
  in
  let baseline_stab =
    _baseline_stab_for ~label:baseline_label baseline_aggregate
  in
  let baseline_all_fold_mean_sharpe =
    Option.map baseline_stab ~f:(fun s -> s.sharpe_ratio.mean)
  in
  let baseline_all_fold_mean_max_drawdown_pct =
    Option.map baseline_stab ~f:(fun s -> s.max_drawdown_pct.mean)
  in
  let markdown =
    Holdout.render_report report ~checkpoint_path:args.checkpoint_path
      ~walk_forward_spec_path:args.walk_forward_spec_path
      ~baseline_aggregate_path:args.baseline_aggregate_path
      ~baseline_all_fold_mean_sharpe ~baseline_all_fold_mean_max_drawdown_pct
  in
  Out_channel.write_all args.out_path ~data:markdown;
  eprintf "[holdout_eval] wrote %s (verdict=%s, mean Δ Sharpe=%.6f)\n%!"
    args.out_path
    (Holdout.show_verdict report.verdict)
    report.mean_paired_sharpe_delta

let () =
  let argv = Array.to_list (Sys.get_argv ()) |> List.tl_exn in
  let args = _parse_args argv in
  _run args
