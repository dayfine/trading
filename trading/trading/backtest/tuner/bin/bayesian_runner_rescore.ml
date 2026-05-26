open Core
module Wf = Walk_forward.Walk_forward_types
module Scoring = Bayesian_runner_scoring

(* ---------- on-disk shapes ---------- *)

type candidate = {
  label : string;
  parameters : (string * float) list;
  fold_actuals : Wf.fold_actual list;
}
[@@deriving sexp]

type bo_rescore_input = {
  schema_version : int;
  candidates : candidate list;
}
[@@deriving sexp]

let current_schema_version = 1

(* ---------- report shapes ---------- *)

type candidate_rescore = {
  label : string;
  parameters : (string * float) list;
  mean_delta : float;
  stdev_delta : float;
  n_matched : int;
}
[@@deriving sexp]

type verdict = Pass | Fail [@@deriving sexp]

type report = {
  candidates : candidate_rescore list;
  spread : float;
  min_spread : float;
  verdict : verdict;
}
[@@deriving sexp]

(* ---------- named constants (extract magic numbers) ---------- *)

let historical_flat_surface = 0.81
let flat_surface_multiplier = 5.0
let default_min_spread = historical_flat_surface *. flat_surface_multiplier

(* ---------- file loaders ---------- *)

let load_input (path : string) : bo_rescore_input =
  let sexp = Sexp.load_sexp path in
  let parsed = bo_rescore_input_of_sexp sexp in
  if parsed.schema_version <> current_schema_version then
    failwithf
      "bayesian_runner_rescore.load_input: schema_version mismatch for %s — \
       file=%d, current=%d"
      path parsed.schema_version current_schema_version ()
  else parsed

let load_baseline_fold_actuals (path : string) : Wf.fold_actual list =
  let sexp = Sexp.load_sexp path in
  match sexp with
  | Sexp.List items -> List.map items ~f:Wf.fold_actual_of_sexp
  | Sexp.Atom _ ->
      failwithf
        "bayesian_runner_rescore.load_baseline_fold_actuals: expected a \
         top-level sexp list of fold_actual records in %s"
        path ()

(* ---------- pure computation ---------- *)

let rescore_candidate (cand : candidate)
    ~(baseline_fold_actuals : Wf.fold_actual list)
    ~(metric : [ `Sharpe | `Total_return_pct | `Calmar | `CAGR ]) :
    candidate_rescore =
  let stats =
    Scoring.paired_delta ~candidate_actuals:cand.fold_actuals
      ~baseline_actuals:baseline_fold_actuals ~metric
  in
  {
    label = cand.label;
    parameters = cand.parameters;
    mean_delta = stats.mean_delta;
    stdev_delta = stats.stdev_delta;
    n_matched = stats.n_matched;
  }

let spread_of (xs : float list) : float =
  match xs with
  | [] -> 0.0
  | first :: rest ->
      let min_v, max_v =
        List.fold rest ~init:(first, first) ~f:(fun (lo, hi) x ->
            (Float.min lo x, Float.max hi x))
      in
      max_v -. min_v

let _verdict_of_spread ~spread ~min_spread =
  if Float.( > ) spread min_spread then Pass else Fail

let build_report ~(input : bo_rescore_input)
    ~(baseline_fold_actuals : Wf.fold_actual list)
    ~(metric : [ `Sharpe | `Total_return_pct | `Calmar | `CAGR ])
    ~(min_spread : float) : report =
  let rescored =
    List.map input.candidates ~f:(fun cand ->
        rescore_candidate cand ~baseline_fold_actuals ~metric)
  in
  let means = List.map rescored ~f:(fun r -> r.mean_delta) in
  let spread = spread_of means in
  let verdict = _verdict_of_spread ~spread ~min_spread in
  { candidates = rescored; spread; min_spread; verdict }

(* ---------- markdown rendering ---------- *)

let _metric_label = function
  | `Sharpe -> "Sharpe"
  | `Total_return_pct -> "TotalReturn"
  | `Calmar -> "Calmar"
  | `CAGR -> "CAGR"

let _verdict_label = function Pass -> "PASS" | Fail -> "FAIL"

let _parameters_to_string params =
  List.map params ~f:(fun (k, v) -> sprintf "%s=%.6g" k v)
  |> String.concat ~sep:" "

let _candidate_row (r : candidate_rescore) : string =
  sprintf "| %s | %s | %.6f | %.6f | %d |\n" r.label
    (_parameters_to_string r.parameters)
    r.mean_delta r.stdev_delta r.n_matched

let report_to_markdown (report : report)
    ~(metric : [ `Sharpe | `Total_return_pct | `Calmar | `CAGR ]) : string =
  let buf = Buffer.create 512 in
  Buffer.add_string buf "# Paired-\xCE\x94 re-score report\n\n";
  Buffer.add_string buf (sprintf "Metric: %s\n" (_metric_label metric));
  Buffer.add_string buf
    (sprintf "Verdict: %s (threshold: spread > %.6f)\n\n"
       (_verdict_label report.verdict)
       report.min_spread);
  Buffer.add_string buf
    "| Candidate | parameters | mean \xCE\x94 | stdev \xCE\x94 | n_matched |\n";
  Buffer.add_string buf "| --- | --- | --- | --- | --- |\n";
  List.iter report.candidates ~f:(fun r ->
      Buffer.add_string buf (_candidate_row r));
  Buffer.add_string buf "\n## Spread\n";
  Buffer.add_string buf
    (sprintf "max(mean \xCE\x94) - min(mean \xCE\x94) = %.6f\n" report.spread);
  Buffer.add_string buf
    (sprintf "Historical flat-surface spread: %.2f (v3\xE2\x80\x93v6 \
              absolute-Sharpe scoring).\n"
       historical_flat_surface);
  Buffer.add_string buf
    (sprintf
       "Acceptance gate: spread > %.6f (= %g \xC3\x97 %.2f by default).\n"
       report.min_spread flat_surface_multiplier historical_flat_surface);
  Buffer.contents buf
