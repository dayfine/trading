open Core
include Walk_forward_types

(* -------------- ordering helpers -------------- *)

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

(* -------------- summary stats -------------- *)

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

let _min_or_nan xs =
  match xs with
  | [] -> Float.nan
  | x :: rest -> List.fold rest ~init:x ~f:Float.min

let _max_or_nan xs =
  match xs with
  | [] -> Float.nan
  | x :: rest -> List.fold rest ~init:x ~f:Float.max

let _stats xs : per_metric_stats =
  {
    mean = _mean xs;
    stdev = _stdev xs;
    min = _min_or_nan xs;
    max = _max_or_nan xs;
  }

(* -------------- gate-metric projection -------------- *)

let _project_metric (gate : Fold_gate.t) (fa : fold_actual) =
  match gate.metric with
  | Sharpe -> fa.sharpe_ratio
  | Calmar -> fa.calmar_ratio
  | TotalReturnPct -> fa.total_return_pct
  | MaxDrawdownPct -> fa.max_drawdown_pct

let _metric_str (gate : Fold_gate.t) =
  match gate.metric with
  | Sharpe -> "Sharpe"
  | Calmar -> "Calmar"
  | TotalReturnPct -> "TotalReturn%"
  | MaxDrawdownPct -> "MaxDD%"

(* -------------- stability + fold-pair helpers -------------- *)

let _stability_for_variant (folds : fold_actual list) label : variant_stability
    =
  let vs =
    List.filter folds ~f:(fun fa -> String.equal fa.variant_label label)
  in
  {
    variant_label = label;
    total_return_pct = _stats (List.map vs ~f:(fun fa -> fa.total_return_pct));
    sharpe_ratio = _stats (List.map vs ~f:(fun fa -> fa.sharpe_ratio));
    max_drawdown_pct = _stats (List.map vs ~f:(fun fa -> fa.max_drawdown_pct));
    calmar_ratio = _stats (List.map vs ~f:(fun fa -> fa.calmar_ratio));
  }

let _find_fold_actual (folds : fold_actual list) ~fold_name ~variant_label =
  List.find folds ~f:(fun fa ->
      String.equal fa.fold_name fold_name
      && String.equal fa.variant_label variant_label)

let _fold_result_for_one (folds : fold_actual list) ~gate ~baseline_label
    ~variant_label ~fold_name : Fold_gate.fold_result option =
  let b = _find_fold_actual folds ~fold_name ~variant_label:baseline_label in
  let v = _find_fold_actual folds ~fold_name ~variant_label in
  match (b, v) with
  | Some b, Some v ->
      Some
        ({
           fold_name;
           variant_score = _project_metric gate v;
           baseline_score = _project_metric gate b;
         }
          : Fold_gate.fold_result)
  | _ -> None

let _fold_results_for_pair (folds : fold_actual list) ~baseline_label
    ~variant_label ~gate : Fold_gate.fold_result list =
  _fold_names_in_order folds
  |> List.filter_map ~f:(fun fold_name ->
      _fold_result_for_one folds ~gate ~baseline_label ~variant_label ~fold_name)

let _wins_for_variant ~(gate : Fold_gate.t) frs =
  let hib = Fold_gate.higher_is_better gate.metric in
  List.count frs ~f:(fun (fr : Fold_gate.fold_result) ->
      if hib then Float.(fr.variant_score > fr.baseline_score)
      else Float.(fr.variant_score < fr.baseline_score))

(* -------------- top-level compute -------------- *)

let _validate ~baseline_label folds =
  if List.is_empty folds then
    failwith "Walk_forward_report.compute: fold_actuals must be non-empty";
  let labels = _variant_labels_in_order folds in
  if not (List.mem labels baseline_label ~equal:String.equal) then
    failwith
      (sprintf
         "Walk_forward_report.compute: baseline_label %S not present in \
          fold_actuals (labels: %s)"
         baseline_label
         (String.concat ~sep:", " labels))

let _mismatch_verdict ~(gate : Fold_gate.t) frs : Fold_gate.verdict =
  Fail
    {
      wins = _wins_for_variant ~gate frs;
      n = List.length frs;
      worst_fold = "";
      worst_gap = Float.nan;
      reason =
        sprintf "fold-pair count mismatch: measured %d, gate expects %d"
          (List.length frs) gate.n;
    }

let _verdict_for_variant ~(gate : Fold_gate.t) ~variant_label frs =
  let verdict =
    if List.length frs <> gate.n then _mismatch_verdict ~gate frs
    else Fold_gate.evaluate gate frs
  in
  (variant_label, verdict)

let _is_non_baseline ~baseline_label l = not (String.equal l baseline_label)

let _pair_one fold_actuals ~baseline_label ~gate variant_label =
  let frs =
    _fold_results_for_pair fold_actuals ~baseline_label ~variant_label ~gate
  in
  (variant_label, frs)

let _pair_results_per_variant ~baseline_label ~gate ~labels fold_actuals =
  labels
  |> List.filter ~f:(_is_non_baseline ~baseline_label)
  |> List.map ~f:(_pair_one fold_actuals ~baseline_label ~gate)

let _sensitivity_from_pairs ~gate pair_results : variant_sensitivity list =
  List.map pair_results ~f:(fun (variant_label, frs) ->
      { variant_label; wins_on_gate_metric = _wins_for_variant ~gate frs })

let _verdicts_from_pairs ~gate pair_results =
  List.map pair_results ~f:(fun (variant_label, frs) ->
      _verdict_for_variant ~gate ~variant_label frs)

let compute ~baseline_label ~(gate : Fold_gate.t)
    ~(fold_actuals : fold_actual list) : aggregate =
  _validate ~baseline_label fold_actuals;
  let labels = _variant_labels_in_order fold_actuals in
  let pair_results =
    _pair_results_per_variant ~baseline_label ~gate ~labels fold_actuals
  in
  {
    fold_count = List.length (_fold_names_in_order fold_actuals);
    baseline_label;
    metric_label = _metric_str gate;
    stability = List.map labels ~f:(_stability_for_variant fold_actuals);
    sensitivity = _sensitivity_from_pairs ~gate pair_results;
    verdicts = _verdicts_from_pairs ~gate pair_results;
  }

let render ~baseline_label ~(gate : Fold_gate.t)
    ~(fold_actuals : fold_actual list) =
  let agg = compute ~baseline_label ~gate ~fold_actuals in
  Walk_forward_render.to_markdown ~gate ~fold_actuals agg
