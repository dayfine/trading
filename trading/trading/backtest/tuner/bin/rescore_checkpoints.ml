(** CLI for re-scoring an existing BO sweep output with paired-Δ.

    Plan: [dev/plans/tuning-research-driven-program-v2-2026-05-25.md] §M1 T1.5.

    Reads:

    - [--input <bo_rescore_input.sexp>] — per-iteration candidate parameters +
      per-fold actuals (shape
      {!Tuner_bin.Bayesian_runner_rescore.bo_rescore_input}).
    - [--baseline <fold_actuals.sexp>] — Cell-E baseline's per-fold actuals
      (same shape as walk_forward_runner's [fold_actuals.sexp] output).

    Emits a markdown report (stdout by default; [--out <path>] redirects)
    containing:

    - per-candidate (label, parameters, mean Δ, stdev Δ, n_matched);
    - overall spread = max(mean Δ) - min(mean Δ);
    - PASS / FAIL verdict against [--min-spread] (default 4.05 = 5 × 0.81).

    Usage:

    {v
      rescore_checkpoints.exe --input <bo_rescore_input.sexp>
                              --baseline <fold_actuals.sexp>
                              [--metric Sharpe|TotalReturn|Calmar|CAGR]
                              [--min-spread <float>]
                              [--out <path>]
    v}

    {b Production-run procedure (local-only):} the v4/v6 production
    [bo_checkpoint.sexp] files at
    [/Users/difan/Projects/trading-1/.sweep-output/<sweep-name>/] do {b not}
    persist per-fold actuals — only the aggregated per-iter score. T1.5
    therefore requires an upstream adapter (out of scope for this PR) that
    re-emits each iteration's walk-forward CV with [fold_actuals] captured,
    serialised to the [bo_rescore_input] shape documented in the lib's
    {!Tuner_bin.Bayesian_runner_rescore} module. See
    [dev/notes/t1-5-rescore-procedure-2026-05-26.md] for the local-run
    incantation. *)

open Core
module Rescore = Tuner_bin.Bayesian_runner_rescore

let _usage_msg =
  "Usage: rescore_checkpoints.exe --input <bo_rescore_input.sexp>\n\
  \  --baseline <fold_actuals.sexp>\n\
  \  [--metric Sharpe|TotalReturn|Calmar|CAGR]   (default Sharpe)\n\
  \  [--min-spread <float>]                       (default 4.05 = 5 × 0.81)\n\
  \  [--out <path>]                               (default stdout)"

type cli_args = {
  input_path : string;
  baseline_path : string;
  metric : [ `Sharpe | `Total_return_pct | `Calmar | `CAGR ];
  min_spread : float;
  out_path : string option;
}

let _default_metric : [ `Sharpe | `Total_return_pct | `Calmar | `CAGR ] =
  `Sharpe

let _parse_metric raw =
  match String.lowercase raw with
  | "sharpe" -> `Sharpe
  | "totalreturn" | "total_return" | "total_return_pct" -> `Total_return_pct
  | "calmar" -> `Calmar
  | "cagr" -> `CAGR
  | other ->
      eprintf
        "Error: --metric expects 'Sharpe' | 'TotalReturn' | 'Calmar' | 'CAGR', \
         got %S\n\
         %s\n"
        other _usage_msg;
      Stdlib.exit 1

let _parse_float raw =
  try Float.of_string raw
  with _ ->
    eprintf "Error: expected float, got %S\n%s\n" raw _usage_msg;
    Stdlib.exit 1

let _parse_args argv =
  let rec loop input baseline metric min_spread out = function
    | [] -> (
        match (input, baseline) with
        | Some i, Some b ->
            {
              input_path = i;
              baseline_path = b;
              metric = Option.value metric ~default:_default_metric;
              min_spread =
                Option.value min_spread ~default:Rescore.default_min_spread;
              out_path = out;
            }
        | _ ->
            eprintf "%s\n" _usage_msg;
            Stdlib.exit 1)
    | "--input" :: p :: rest ->
        loop (Some p) baseline metric min_spread out rest
    | "--baseline" :: p :: rest ->
        loop input (Some p) metric min_spread out rest
    | "--metric" :: raw :: rest ->
        loop input baseline (Some (_parse_metric raw)) min_spread out rest
    | "--min-spread" :: raw :: rest ->
        loop input baseline metric (Some (_parse_float raw)) out rest
    | "--out" :: p :: rest ->
        loop input baseline metric min_spread (Some p) rest
    | ("--help" | "-h") :: _ ->
        printf "%s\n" _usage_msg;
        Stdlib.exit 0
    | unknown :: _ ->
        eprintf "Error: unknown argument %S\n%s\n" unknown _usage_msg;
        Stdlib.exit 1
  in
  loop None None None None None argv

let _emit_report ~out_path markdown =
  match out_path with
  | None -> printf "%s" markdown
  | Some path ->
      Out_channel.write_all path ~data:markdown;
      eprintf "[rescore_checkpoints] wrote %s\n%!" path

let _verdict_label = function Rescore.Pass -> "PASS" | Rescore.Fail -> "FAIL"

let _run (args : cli_args) =
  let input = Rescore.load_input args.input_path in
  let baseline_fold_actuals =
    Rescore.load_baseline_fold_actuals args.baseline_path
  in
  let report =
    Rescore.build_report ~input ~baseline_fold_actuals ~metric:args.metric
      ~min_spread:args.min_spread
  in
  eprintf
    "[rescore_checkpoints] candidates=%d spread=%.6f min_spread=%.6f verdict=%s\n\
     %!"
    (List.length report.candidates)
    report.spread report.min_spread
    (_verdict_label report.verdict);
  let markdown = Rescore.report_to_markdown report ~metric:args.metric in
  _emit_report ~out_path:args.out_path markdown

let () =
  let argv = Array.to_list (Sys.get_argv ()) |> List.tl_exn in
  let args = _parse_args argv in
  _run args
