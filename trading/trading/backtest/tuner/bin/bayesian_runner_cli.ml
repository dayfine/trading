(* CLI flag parsing for bayesian_runner.exe. See bayesian_runner_cli.mli. *)
open Core

let usage_msg =
  "Usage: bayesian_runner.exe --spec <spec.sexp> --out-dir <dir>\n\
  \  [--fixtures-root <path>]\n\
  \  [--parallel N]    (default 1, max 16)\n\
  \  [--walk-forward-spec <spec.sexp> --baseline-aggregate <aggregate.sexp>]\n\
  \  [--fidelity-strategy single|successive_halving]   (default single; \
   successive_halving requires a Tiered walk-forward window_spec)"

(** Selector for {!Tuner_bin.Bayesian_runner_successive_halving} mode. [Single]
    preserves the legacy single-tier behaviour bit-for-bit; [Successive_halving]
    enables M1 T1.2's multi-fidelity promotion loop. Plan:
    [dev/plans/tuning-research-driven-program-v2-2026-05-25.md]. *)
type fidelity_strategy = Single | Successive_halving

let _default_fidelity_strategy = Single

let _parse_fidelity_strategy raw =
  match String.lowercase raw with
  | "single" -> Single
  | "successive_halving" -> Successive_halving
  | other ->
      eprintf
        "Error: --fidelity-strategy expects 'single' or 'successive_halving', \
         got %S\n\
         %s\n"
        other usage_msg;
      Stdlib.exit 1

(** Default [--parallel] value. [1] preserves the pre-#1197 sequential path
    bit-exactly (no fork, no marshal). *)
let _default_parallel = 1

(** Parse and validate the [--parallel N] flag at CLI time. Out-of-range values
    would otherwise surface from inside [Fork_pool.run_parallel] as an
    [Invalid_argument] after the spec has loaded — failing fast at parse time
    gives the operator a clearer error. *)
let _parse_parallel raw =
  let n =
    try Int.of_string raw
    with _ ->
      eprintf "Error: --parallel expects an integer, got %S\n%s\n" raw usage_msg;
      Stdlib.exit 1
  in
  if n < 1 || n > Fork_pool.max_parallel then begin
    eprintf "Error: --parallel must be in [1, %d], got %d\n%s\n"
      Fork_pool.max_parallel n usage_msg;
    Stdlib.exit 1
  end;
  n

(** Label assigned to the best cell when it is re-executed end-to-end for OOS
    validation. Distinct from the [bo-iter-N] labels the evaluator's iteration
    counter emits during the BO loop. *)
let _walk_forward_candidate_label = "bo-iter-best"

(** Synthetic scenario label injected into [bo_log.csv]'s [scenario] column in
    walk-forward mode (the Bayesian spec's own [scenarios] list is empty in
    production walk-forward specs). *)
let _walk_forward_scenarios_label = "walk-forward"

type cli_args = {
  spec_path : string;
  out_dir : string;
  fixtures_root : string option;
  walk_forward_spec_path : string option;
  baseline_aggregate_path : string option;
  parallel : int;
  fidelity_strategy : fidelity_strategy;
}

let parse_args argv =
  let rec loop spec out fixtures wf_spec baseline parallel fidelity = function
    | [] -> (
        match (spec, out) with
        | Some s, Some o ->
            {
              spec_path = s;
              out_dir = o;
              fixtures_root = fixtures;
              walk_forward_spec_path = wf_spec;
              baseline_aggregate_path = baseline;
              parallel = Option.value parallel ~default:_default_parallel;
              fidelity_strategy =
                Option.value fidelity ~default:_default_fidelity_strategy;
            }
        | _ ->
            eprintf "%s\n" usage_msg;
            Stdlib.exit 1)
    | "--spec" :: p :: rest ->
        loop (Some p) out fixtures wf_spec baseline parallel fidelity rest
    | "--out-dir" :: p :: rest ->
        loop spec (Some p) fixtures wf_spec baseline parallel fidelity rest
    | "--fixtures-root" :: p :: rest ->
        loop spec out (Some p) wf_spec baseline parallel fidelity rest
    | "--walk-forward-spec" :: p :: rest ->
        loop spec out fixtures (Some p) baseline parallel fidelity rest
    | "--baseline-aggregate" :: p :: rest ->
        loop spec out fixtures wf_spec (Some p) parallel fidelity rest
    | "--parallel" :: n :: rest ->
        loop spec out fixtures wf_spec baseline
          (Some (_parse_parallel n))
          fidelity rest
    | "--fidelity-strategy" :: raw :: rest ->
        loop spec out fixtures wf_spec baseline parallel
          (Some (_parse_fidelity_strategy raw))
          rest
    | "--help" :: _ | "-h" :: _ ->
        printf "%s\n" usage_msg;
        Stdlib.exit 0
    | unknown :: _ ->
        eprintf "Error: unknown argument %S\n%s\n" unknown usage_msg;
        Stdlib.exit 1
  in
  loop None None None None None None None argv
