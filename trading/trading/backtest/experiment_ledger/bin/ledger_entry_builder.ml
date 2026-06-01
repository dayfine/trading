open Core
module T = Walk_forward.Walk_forward_types
module EL = Experiment_ledger

type metadata = {
  date : string;
  slug : string;
  hypothesis : string;
  base_scenario : string;
  window_id : string;
  baseline_label : string;
  verdict : EL.verdict;
  notes : string;
}

let hash_map_of_variants (pairs : (string * Sexp.t list) list) :
    (string, string) Hashtbl.t =
  let table = Hashtbl.create (module String) in
  List.iter pairs ~f:(fun (label, overrides) ->
      Hashtbl.set table ~key:label ~data:(EL.config_hash overrides));
  table

(* The four cross-fold means, as [Some fold_aggregate] when every metric is
   finite. A NaN in any mean (degenerate fixture / fold that never traded)
   yields [None] rather than recording a fabricated number — the lib documents
   [None] as the valid "no machine aggregate" case. *)
let _fold_aggregate_of_stability (s : T.variant_stability) :
    EL.fold_aggregate option =
  let mean_sharpe = s.sharpe_ratio.mean in
  let mean_calmar = s.calmar_ratio.mean in
  let mean_return_pct = s.total_return_pct.mean in
  let mean_max_drawdown_pct = s.max_drawdown_pct.mean in
  let all_finite =
    List.for_all
      [ mean_sharpe; mean_calmar; mean_return_pct; mean_max_drawdown_pct ]
      ~f:Float.is_finite
  in
  if all_finite then
    Some { EL.mean_sharpe; mean_calmar; mean_return_pct; mean_max_drawdown_pct }
  else None

let _variant_record_of_stability ~config_hash_for (s : T.variant_stability) :
    EL.variant_record =
  {
    EL.label = s.variant_label;
    config_hash = config_hash_for s.variant_label;
    aggregate = _fold_aggregate_of_stability s;
  }

let build_entry ~(metadata : metadata) ~config_hash_for
    (aggregate : T.aggregate) : EL.entry =
  let variants =
    List.map aggregate.stability
      ~f:(_variant_record_of_stability ~config_hash_for)
  in
  {
    EL.date = metadata.date;
    slug = metadata.slug;
    hypothesis = metadata.hypothesis;
    base_scenario = metadata.base_scenario;
    window_id = metadata.window_id;
    baseline_label = metadata.baseline_label;
    variants;
    verdict = metadata.verdict;
    notes = metadata.notes;
  }
