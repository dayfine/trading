(** Walk-forward CV runner — wires [Window_spec] + [Walk_forward_runner] +
    [Walk_forward_report] to {!Backtest.Runner.run_backtest} via
    {!Walk_forward.Walk_forward_executor}.

    Reads a top-level sexp spec describing:
    - [base_scenario] — path to the base scenario sexp file
    - [window_spec] — {!Walk_forward.Window_spec.t}
    - [variants] — list of {!Walk_forward.Walk_forward_runner.variant}
    - [baseline_label] — which variant is the baseline for the report
    - [gate] — {!Walk_forward.Fold_gate.t}

    Writes [fold_actuals.sexp], [walk_forward_report.md], and [aggregate.sexp]
    under [--out-dir].

    Usage:
    {v
      walk_forward_runner.exe --spec <spec.sexp> --out-dir <dir>
                              [--fixtures-root <path>]
                              [--parallel N]    (default 1, max 16)
    v}

    This binary is the integration seam for Phase 3: the Bayesian optimizer
    consumes the same harness with variant-overrides chosen by the BO loop
    instead of hard-coded in the spec. The per-fold execution loop lives in
    {!Walk_forward.Walk_forward_executor.execute_spec} so the tuner can drive it
    without spawning a subprocess. *)

open Core
module Scenario = Scenario_lib.Scenario
module Fixtures_root = Scenario_lib.Fixtures_root
module WS = Walk_forward.Window_spec
module Report = Walk_forward.Walk_forward_report
module Spec = Walk_forward.Spec
module Executor = Walk_forward.Walk_forward_executor

(* -------------- argument parsing -------------- *)

(** Default [--parallel] value. [1] preserves the pre-#1197 sequential path
    bit-exactly (no fork, no marshal). *)
let _default_parallel = 1

type cli_args = {
  spec_path : string;
  out_dir : string;
  fixtures_root : string option;
  parallel : int;
}

let _usage_msg =
  "Usage: walk_forward_runner.exe --spec <spec.sexp> --out-dir <dir> \
   [--fixtures-root <path>] [--parallel N]"

(** Parse and validate the [--parallel N] flag at CLI time. Out-of-range values
    would otherwise surface from inside [Fork_pool.run_parallel] as an
    [Invalid_argument] after the spec has loaded — failing fast at parse time
    gives the operator a clearer error. *)
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
  let rec loop spec out fixtures parallel = function
    | [] -> (
        match (spec, out) with
        | Some s, Some o ->
            {
              spec_path = s;
              out_dir = o;
              fixtures_root = fixtures;
              parallel = Option.value parallel ~default:_default_parallel;
            }
        | _ ->
            eprintf "%s\n" _usage_msg;
            Stdlib.exit 1)
    | "--spec" :: p :: rest -> loop (Some p) out fixtures parallel rest
    | "--out-dir" :: p :: rest -> loop spec (Some p) fixtures parallel rest
    | "--fixtures-root" :: p :: rest -> loop spec out (Some p) parallel rest
    | "--parallel" :: n :: rest ->
        loop spec out fixtures (Some (_parse_parallel n)) rest
    | ("--help" | "-h") :: _ ->
        printf "%s\n" _usage_msg;
        Stdlib.exit 0
    | unknown :: _ ->
        eprintf "Error: unknown argument %S\n%s\n" unknown _usage_msg;
        Stdlib.exit 1
  in
  loop None None None None argv

(* -------------- output writers -------------- *)

let _stderr_progress : Executor.progress_callback =
 fun ~variant_label ~fold_name ~test_start ~test_end ->
  eprintf "[walk_forward] running variant=%s fold=%s [%s..%s]\n%!" variant_label
    fold_name
    (Date.to_string test_start)
    (Date.to_string test_end)

let _write_fold_actuals ~out_dir (fold_actuals : Report.fold_actual list) =
  let sexp = Sexp.List (List.map fold_actuals ~f:Report.sexp_of_fold_actual) in
  let path = Filename.concat out_dir "fold_actuals.sexp" in
  Sexp.save_hum path sexp;
  eprintf "[walk_forward] wrote %s\n%!" path

let _write_report ~out_dir ~(spec : Spec.t)
    (fold_actuals : Report.fold_actual list) =
  let md =
    Report.render ~baseline_label:spec.baseline_label ~gate:spec.gate
      ~fold_actuals
  in
  let path = Filename.concat out_dir "walk_forward_report.md" in
  Out_channel.write_all path ~data:md;
  eprintf "[walk_forward] wrote %s\n%!" path

(** Persist the structured aggregate so Phase 3 (Bayesian optimizer) can consume
    it directly without parsing the markdown report. *)
let _write_aggregate ~out_dir (aggregate : Report.aggregate) =
  let path = Filename.concat out_dir "aggregate.sexp" in
  Sexp.save_hum path (Report.sexp_of_aggregate aggregate);
  eprintf "[walk_forward] wrote %s\n%!" path

(* -------------- main -------------- *)

let _main () =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let args = _parse_args argv in
  let spec = Spec.load args.spec_path in
  Core_unix.mkdir_p args.out_dir;
  let fixtures_root =
    Fixtures_root.resolve ?fixtures_root:args.fixtures_root ()
  in
  let base = Scenario.load spec.base_scenario in
  eprintf
    "[walk_forward] spec=%s base=%s baseline=%s variants=%d folds=%d parallel=%d\n\
     %!"
    args.spec_path spec.base_scenario spec.baseline_label
    (List.length spec.variants)
    (List.length (WS.generate spec.window_spec))
    args.parallel;
  let result =
    Executor.execute_spec ~base ~spec ~fixtures_root ~progress:_stderr_progress
      ~parallel:args.parallel ()
  in
  _write_fold_actuals ~out_dir:args.out_dir result.fold_actuals;
  _write_report ~out_dir:args.out_dir ~spec result.fold_actuals;
  _write_aggregate ~out_dir:args.out_dir result.aggregate;
  eprintf "[walk_forward] done\n%!"

let () = _main ()
