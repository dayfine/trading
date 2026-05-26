open Core
module PC = Tuner.Proxy_calibration_lib
module Wf = Walk_forward.Walk_forward_types

(* ----------------- metric_arg ---------------------------------------- *)

type metric_arg = Sharpe | TotalReturn | Calmar | CAGR | MaxDrawdown
[@@deriving show, eq]

let default_variant_label = "cell-E"

let _usage_msg =
  "Usage: proxy_calibration.exe --cheap <fold_actuals.sexp> --expensive \
   <fold_actuals.sexp> [--metric sharpe|totalreturn|calmar|cagr|maxdrawdown] \
   [--threshold <float>] [--variant <label>] [--out <markdown_path>]"

let metric_arg_of_string s =
  match String.lowercase s with
  | "sharpe" -> Sharpe
  | "totalreturn" | "total_return" | "total-return" -> TotalReturn
  | "calmar" -> Calmar
  | "cagr" -> CAGR
  | "maxdrawdown" | "max_drawdown" | "max-drawdown" -> MaxDrawdown
  | other -> failwith (Printf.sprintf "unknown metric: %S" other)

let metric_arg_to_lib = function
  | Sharpe -> `Sharpe
  | TotalReturn -> `Total_return_pct
  | Calmar -> `Calmar
  | CAGR -> `CAGR
  | MaxDrawdown -> `Max_drawdown_pct

let metric_label = function
  | Sharpe -> "sharpe_ratio"
  | TotalReturn -> "total_return_pct"
  | Calmar -> "calmar_ratio"
  | CAGR -> "cagr_pct"
  | MaxDrawdown -> "max_drawdown_pct"

(* ----------------- cli_args ------------------------------------------ *)

type cli_args = {
  cheap_path : string;
  expensive_path : string;
  metric : metric_arg;
  threshold : float;
  variant_label : string;
  out_path : string option;
}
[@@deriving show, eq]

let _min_matched_folds = 2

let parse_args (argv : string list) : cli_args =
  let rec loop cheap expensive metric threshold variant out_path = function
    | [] -> (
        match (cheap, expensive) with
        | Some c, Some e ->
            {
              cheap_path = c;
              expensive_path = e;
              metric = Option.value metric ~default:Sharpe;
              threshold =
                Option.value threshold ~default:PC.acceptance_threshold;
              variant_label =
                Option.value variant ~default:default_variant_label;
              out_path;
            }
        | _ ->
            failwith
              ("proxy_calibration: --cheap and --expensive are required; "
             ^ _usage_msg))
    | "--cheap" :: p :: rest ->
        loop (Some p) expensive metric threshold variant out_path rest
    | "--expensive" :: p :: rest ->
        loop cheap (Some p) metric threshold variant out_path rest
    | "--metric" :: m :: rest ->
        loop cheap expensive
          (Some (metric_arg_of_string m))
          threshold variant out_path rest
    | "--threshold" :: t :: rest ->
        loop cheap expensive metric
          (Some (Float.of_string t))
          variant out_path rest
    | "--variant" :: v :: rest ->
        loop cheap expensive metric threshold (Some v) out_path rest
    | "--out" :: p :: rest ->
        loop cheap expensive metric threshold variant (Some p) rest
    | ("--help" | "-h") :: _ ->
        printf "%s\n" _usage_msg;
        Stdlib.exit 0
    | unknown :: _ ->
        failwith (Printf.sprintf "unknown argument: %S\n%s" unknown _usage_msg)
  in
  loop None None None None None None argv

(* ----------------- I/O ----------------------------------------------- *)

let load_fold_actuals (path : string) : Wf.fold_actual list =
  if not (Sys_unix.file_exists_exn path) then
    failwith (Printf.sprintf "fold_actuals file not found: %s" path)
  else
    let sexp = Sexp.load_sexp path in
    match sexp with
    | List items -> List.map items ~f:Wf.fold_actual_of_sexp
    | _ ->
        failwith
          (Printf.sprintf
             "fold_actuals file %s: top-level sexp must be a list, got an atom"
             path)

(* ----------------- markdown rendering --------------------------------- *)

let _format_pair_row (p : PC.fold_pair) : string =
  Printf.sprintf "| %s | %.6f | %.6f | %.6f |" p.fold_name p.cheap p.expensive
    (p.cheap -. p.expensive)

let render_markdown ~(cheap_path : string) ~(expensive_path : string)
    ~(metric : metric_arg) ~(threshold : float) ~(variant_label : string)
    ~(pairs : PC.fold_pair list) ~(rho : float) ~(verdict : PC.verdict) : string
    =
  let n = List.length pairs in
  let verdict_str =
    match verdict with PC.Pass -> "PASS" | PC.Fail -> "FAIL"
  in
  let header =
    Printf.sprintf
      "# Proxy-fidelity calibration\n\n\
       - **Cheap proxy:** `%s`\n\
       - **Expensive set:** `%s`\n\
       - **Variant:** `%s`\n\
       - **Metric:** `%s`\n\
       - **Threshold:** %.4f\n\
       - **Matched folds:** %d\n\
       - **Spearman ρ:** %.6f\n\
       - **Verdict:** %s\n\n"
      cheap_path expensive_path variant_label (metric_label metric) threshold n
      rho verdict_str
  in
  let table_header =
    "| fold_name | cheap | expensive | Δ (cheap - expensive) |\n\
     |-----------|-------|-----------|-----------------------|\n"
  in
  let table_body =
    String.concat ~sep:"\n" (List.map pairs ~f:_format_pair_row)
  in
  header ^ table_header ^ table_body ^ "\n"

(* ----------------- run + main ----------------------------------------- *)

type run_result = {
  pairs : PC.fold_pair list;
  rho : float;
  verdict : PC.verdict;
  report : string;
}

let run_calibration (args : cli_args) : run_result =
  let cheap = load_fold_actuals args.cheap_path in
  let expensive = load_fold_actuals args.expensive_path in
  let pairs =
    PC.matched_pairs ~variant_label:args.variant_label ~cheap_actuals:cheap
      ~expensive_actuals:expensive
      ~metric:(metric_arg_to_lib args.metric)
      ()
  in
  let n = List.length pairs in
  if n < _min_matched_folds then
    failwith
      (Printf.sprintf
         "proxy_calibration: need >=%d matched folds (got %d) — cheap and \
          expensive runs must share fold_names for variant_label=%S"
         _min_matched_folds n args.variant_label);
  let xs = List.map pairs ~f:(fun p -> p.cheap) |> Array.of_list in
  let ys = List.map pairs ~f:(fun p -> p.expensive) |> Array.of_list in
  let rho = PC.spearman_rho xs ys in
  let verdict = PC.classify ~threshold:args.threshold ~rho in
  let report =
    render_markdown ~cheap_path:args.cheap_path
      ~expensive_path:args.expensive_path ~metric:args.metric
      ~threshold:args.threshold ~variant_label:args.variant_label ~pairs ~rho
      ~verdict
  in
  { pairs; rho; verdict; report }

let main () =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let args = parse_args argv in
  let result = run_calibration args in
  eprintf
    "[proxy_calibration] matched=%d rho=%.6f threshold=%.4f verdict=%s\n%!"
    (List.length result.pairs) result.rho args.threshold
    (match result.verdict with PC.Pass -> "PASS" | PC.Fail -> "FAIL");
  (match args.out_path with
  | None -> printf "%s" result.report
  | Some p ->
      Out_channel.write_all p ~data:result.report;
      eprintf "[proxy_calibration] wrote %s\n%!" p);
  match result.verdict with
  | PC.Pass -> Stdlib.exit 0
  | PC.Fail -> Stdlib.exit 1
