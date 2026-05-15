open Core

type fold_actual = {
  fold_name : string;
  variant_label : string;
  total_return_pct : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  calmar_ratio : float;
}
[@@deriving sexp]

(* -------------- helpers -------------- *)

let _variant_labels_in_order (folds : fold_actual list) =
  let seen = Hash_set.create (module String) in
  List.filter_map folds ~f:(fun fa ->
      if Hash_set.mem seen fa.variant_label then None
      else (
        Hash_set.add seen fa.variant_label;
        Some fa.variant_label))

let _fold_names_in_order (folds : fold_actual list) =
  let seen = Hash_set.create (module String) in
  List.filter_map folds ~f:(fun fa ->
      if Hash_set.mem seen fa.fold_name then None
      else (
        Hash_set.add seen fa.fold_name;
        Some fa.fold_name))

let _mean xs =
  let n = List.length xs in
  if n = 0 then Float.nan
  else List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int n

let _stdev xs =
  let n = List.length xs in
  if n < 2 then Float.nan
  else
    let m = _mean xs in
    let s = List.fold xs ~init:0.0 ~f:(fun acc x -> acc +. ((x -. m) ** 2.0)) in
    Float.sqrt (s /. Float.of_int (n - 1))

let _project_metric (gate : Fold_gate.t) (fa : fold_actual) =
  match gate.metric with
  | Sharpe -> fa.sharpe_ratio
  | Calmar -> fa.calmar_ratio
  | TotalReturnPct -> fa.total_return_pct
  | MaxDrawdownPct -> fa.max_drawdown_pct

(* -------------- section renderers -------------- *)

let _render_per_fold_table (folds : fold_actual list) =
  let header =
    "| Fold | Variant | Return % | Sharpe | MaxDD % | Calmar |\n\
     |------|---------|---------:|-------:|--------:|-------:|"
  in
  let rows =
    List.map folds ~f:(fun fa ->
        sprintf "| %s | %s | %.2f | %.3f | %.2f | %.3f |" fa.fold_name
          fa.variant_label fa.total_return_pct fa.sharpe_ratio
          fa.max_drawdown_pct fa.calmar_ratio)
  in
  String.concat ~sep:"\n" (header :: rows)

let _variant_metric_lists (folds : fold_actual list) label =
  List.filter folds ~f:(fun fa -> String.equal fa.variant_label label)

let _render_stability_table (folds : fold_actual list) =
  let header =
    "| Variant | Return % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar \
     (μ ± σ) |\n\
     |---------|-----------------:|---------------:|----------------:|--------------:|"
  in
  let labels = _variant_labels_in_order folds in
  let rows =
    List.map labels ~f:(fun label ->
        let vs = _variant_metric_lists folds label in
        let r = List.map vs ~f:(fun fa -> fa.total_return_pct) in
        let s = List.map vs ~f:(fun fa -> fa.sharpe_ratio) in
        let d = List.map vs ~f:(fun fa -> fa.max_drawdown_pct) in
        let c = List.map vs ~f:(fun fa -> fa.calmar_ratio) in
        sprintf "| %s | %.2f ± %.2f | %.3f ± %.3f | %.2f ± %.2f | %.3f ± %.3f |"
          label (_mean r) (_stdev r) (_mean s) (_stdev s) (_mean d) (_stdev d)
          (_mean c) (_stdev c))
  in
  String.concat ~sep:"\n" (header :: rows)

(** Lookup a fold actual by (fold_name, variant_label). Returns [None] when no
    such measurement exists. *)
let _find_fold_actual (folds : fold_actual list) ~fold_name ~variant_label =
  List.find folds ~f:(fun fa ->
      String.equal fa.fold_name fold_name
      && String.equal fa.variant_label variant_label)

(** True iff [variant] strictly beats [baseline] on the named fold, per the
    gate's metric direction (higher-is-better vs drawdown). *)
let _variant_beats_baseline ~(gate : Fold_gate.t) ~hib ~folds ~baseline_label
    ~variant_label ~fold_name =
  let b = _find_fold_actual folds ~fold_name ~variant_label:baseline_label in
  let v = _find_fold_actual folds ~fold_name ~variant_label in
  match (b, v) with
  | Some b, Some v ->
      let bv = _project_metric gate b in
      let vv = _project_metric gate v in
      if hib then Float.(vv > bv) else Float.(vv < bv)
  | _ -> false

let _wins_for_variant ~gate ~hib ~folds ~baseline_label ~variant_label =
  let fold_names = _fold_names_in_order folds in
  List.count fold_names ~f:(fun fold_name ->
      _variant_beats_baseline ~gate ~hib ~folds ~baseline_label ~variant_label
        ~fold_name)

let _wins_per_variant_on_metric (folds : fold_actual list)
    ~(baseline_label : string) ~(gate : Fold_gate.t) =
  let labels = _variant_labels_in_order folds in
  let hib = Fold_gate.higher_is_better gate.metric in
  List.filter labels ~f:(fun l -> not (String.equal l baseline_label))
  |> List.map ~f:(fun variant_label ->
      let wins =
        _wins_for_variant ~gate ~hib ~folds ~baseline_label ~variant_label
      in
      (variant_label, wins))

let _metric_str (gate : Fold_gate.t) =
  match gate.metric with
  | Sharpe -> "Sharpe"
  | Calmar -> "Calmar"
  | TotalReturnPct -> "TotalReturn%"
  | MaxDrawdownPct -> "MaxDD%"

let _render_sensitivity_table ~baseline_label ~(gate : Fold_gate.t)
    (folds : fold_actual list) =
  let n = List.length (_fold_names_in_order folds) in
  let header =
    sprintf
      "Variant wins per fold on **%s** (vs baseline `%s`, %d folds total):\n\n\
       | Variant | Wins | of |\n\
       |---------|-----:|---:|"
      (_metric_str gate) baseline_label n
  in
  let rows =
    _wins_per_variant_on_metric folds ~baseline_label ~gate
    |> List.map ~f:(fun (label, wins) ->
        sprintf "| %s | %d | %d |" label wins n)
  in
  String.concat ~sep:"\n" (header :: rows)

(** Build one [Fold_gate.fold_result] for the (baseline, variant) pair on the
    named fold. Returns [None] when either side's measurement is missing. *)
let _fold_result_for_one ~(gate : Fold_gate.t) ~folds ~baseline_label
    ~variant_label ~fold_name : Fold_gate.fold_result option =
  let b = _find_fold_actual folds ~fold_name ~variant_label:baseline_label in
  let v = _find_fold_actual folds ~fold_name ~variant_label in
  match (b, v) with
  | Some b, Some v ->
      let baseline_score = _project_metric gate b in
      let variant_score = _project_metric gate v in
      Some { fold_name; variant_score; baseline_score }
  | _ -> None

(** Build [Fold_gate.fold_result] list for a single (variant vs baseline)
    pairing. Returns folds in baseline-side ordering — anchors on the unique
    fold-name list. *)
let _fold_results_for_pair (folds : fold_actual list) ~baseline_label
    ~variant_label ~gate =
  let fold_names = _fold_names_in_order folds in
  List.filter_map fold_names ~f:(fun fold_name ->
      _fold_result_for_one ~gate ~folds ~baseline_label ~variant_label
        ~fold_name)

let _render_verdict_for_variant ~(gate : Fold_gate.t) ~variant_label
    fold_results =
  let n_folds = List.length fold_results in
  if n_folds <> gate.n then
    sprintf "- **%s**: SKIPPED — measured %d folds but gate expects %d"
      variant_label n_folds gate.n
  else
    match Fold_gate.evaluate gate fold_results with
    | Fold_gate.Pass { wins; n } ->
        sprintf "- **%s**: PASS (%d / %d wins, Δ≤%.4f satisfied)" variant_label
          wins n gate.worst_delta
    | Fold_gate.Fail { wins; n; worst_fold; worst_gap; reason } ->
        sprintf
          "- **%s**: FAIL (%d / %d wins; worst fold `%s` gap %.4f). Reason: %s"
          variant_label wins n worst_fold worst_gap reason

let _render_verdict_block ~baseline_label ~(gate : Fold_gate.t)
    (folds : fold_actual list) =
  let labels = _variant_labels_in_order folds in
  let non_baseline =
    List.filter labels ~f:(fun l -> not (String.equal l baseline_label))
  in
  let header =
    sprintf
      "Gate: variant wins ≥%d of %d folds on **%s** vs baseline `%s`, no fold \
       worse by Δ>%.4f.\n"
      gate.m gate.n (_metric_str gate) baseline_label gate.worst_delta
  in
  let lines =
    List.map non_baseline ~f:(fun variant_label ->
        let frs =
          _fold_results_for_pair folds ~baseline_label ~variant_label ~gate
        in
        _render_verdict_for_variant ~gate ~variant_label frs)
  in
  String.concat ~sep:"\n" (header :: lines)

(* -------------- top-level render -------------- *)

let _validate ~baseline_label folds =
  if List.is_empty folds then
    failwith "Walk_forward_report.render: fold_actuals must be non-empty";
  let labels = _variant_labels_in_order folds in
  if not (List.mem labels baseline_label ~equal:String.equal) then
    failwith
      (sprintf
         "Walk_forward_report.render: baseline_label %S not present in \
          fold_actuals (labels: %s)"
         baseline_label
         (String.concat ~sep:", " labels))

let render ~baseline_label ~(gate : Fold_gate.t)
    ~(fold_actuals : fold_actual list) =
  _validate ~baseline_label fold_actuals;
  let per_fold = _render_per_fold_table fold_actuals in
  let stability = _render_stability_table fold_actuals in
  let sensitivity =
    _render_sensitivity_table ~baseline_label ~gate fold_actuals
  in
  let verdict = _render_verdict_block ~baseline_label ~gate fold_actuals in
  String.concat ~sep:"\n\n"
    [
      "# Walk-forward CV report";
      "## 1. Per-fold metrics";
      per_fold;
      "## 2. Stability (mean ± stdev across folds)";
      stability;
      "## 3. Cross-fold sensitivity";
      sensitivity;
      "## 4. Go/no-go verdict";
      verdict;
    ]
