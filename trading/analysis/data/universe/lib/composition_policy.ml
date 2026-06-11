open Core
open Composition_policy_types

(* Stable filter names used in the drop reports. *)
let _filter_dual_class = "dual_class_dedup"
let _filter_reit = "reit_policy"
let _filter_adr_floor = "adr_liquidity_floor"
let _filter_preferred = "preferred_exclusion"

(* A filter splits its input into (kept, dropped) preserving input order.
   [run_filter] wraps that into a [filter_report] over the survivors. *)
let _make_report ~filter ~kept ~dropped =
  { filter; dropped; kept_count = List.length kept }

(* Partition [candidates] by [classify], which tags each candidate as either
   kept (returns [None]) or dropped with a reason (returns [Some reason]).
   Returns [(kept, dropped)] with input order preserved in both. Avoids
   [List.partition_map]'s [Either] argument-order subtleties. *)
let _split (candidates : candidate list)
    ~(classify : candidate -> drop_reason option) =
  let kept_rev, dropped_rev =
    List.fold candidates ~init:([], [])
      ~f:(fun (kept, dropped) (c : candidate) ->
        match classify c with
        | None -> (c :: kept, dropped)
        | Some reason -> (kept, { symbol = c.symbol; reason } :: dropped))
  in
  (List.rev kept_rev, List.rev dropped_rev)

(* ------------------------------------------------------------------ *)
(* Filter 1: dual-class dedup (always active)                          *)
(* ------------------------------------------------------------------ *)

(* For each economic entity (Dual_class.entity_key), keep the first candidate
   encountered — input is rank order, so the first is the most liquid / highest
   rank. Subsequent candidates of the same entity are dropped with a reference
   to the kept symbol. *)
let _dedup_dual_class candidates =
  let seen = Hashtbl.create (module String) in
  _split candidates ~classify:(fun c ->
      let key = Dual_class.entity_key c.symbol in
      match Hashtbl.find seen key with
      | Some kept_symbol -> Some (Dual_class_duplicate { kept_symbol })
      | None ->
          Hashtbl.set seen ~key ~data:c.symbol;
          None)

(* ------------------------------------------------------------------ *)
(* Filter 2: REIT include / exclude                                    *)
(* ------------------------------------------------------------------ *)

let _is_reit ~config c = String.equal c.sector config.reit_sector_label

let _apply_reit_policy ~config candidates =
  match config.reit_policy with
  | Include -> (candidates, [])
  | Exclude ->
      _split candidates ~classify:(fun c ->
          if _is_reit ~config c then Some Reit_excluded else None)

(* ------------------------------------------------------------------ *)
(* Filter 3: ADR / GDR liquidity floor                                 *)
(* ------------------------------------------------------------------ *)

let _is_adr_like c =
  match c.asset_type with Eodhd.Asset_type.ADR | GDR -> true | _ -> false

let _adr_floor_reason ~floor c =
  if _is_adr_like c && Float.( < ) c.avg_dollar_volume floor then
    Some
      (Adr_below_liquidity_floor
         { floor; avg_dollar_volume = c.avg_dollar_volume })
  else None

let _apply_adr_floor ~config candidates =
  match config.adr_min_dollar_volume with
  | None -> (candidates, [])
  | Some floor -> _split candidates ~classify:(_adr_floor_reason ~floor)

(* ------------------------------------------------------------------ *)
(* Filter 4: preferred-stock exclusion                                 *)
(* ------------------------------------------------------------------ *)

let _is_preferred c =
  match c.asset_type with
  | Eodhd.Asset_type.Preferred_stock -> true
  | _ -> false

let _apply_preferred_policy ~config candidates =
  if not config.exclude_preferred then (candidates, [])
  else
    _split candidates ~classify:(fun c ->
        if _is_preferred c then Some Preferred_excluded else None)

(* ------------------------------------------------------------------ *)
(* Pipeline                                                            *)
(* ------------------------------------------------------------------ *)

let apply ~config candidates =
  let kept1, dropped1 = _dedup_dual_class candidates in
  let kept2, dropped2 = _apply_reit_policy ~config kept1 in
  let kept3, dropped3 = _apply_adr_floor ~config kept2 in
  let kept4, dropped4 = _apply_preferred_policy ~config kept3 in
  let reports =
    [
      _make_report ~filter:_filter_dual_class ~kept:kept1 ~dropped:dropped1;
      _make_report ~filter:_filter_reit ~kept:kept2 ~dropped:dropped2;
      _make_report ~filter:_filter_adr_floor ~kept:kept3 ~dropped:dropped3;
      _make_report ~filter:_filter_preferred ~kept:kept4 ~dropped:dropped4;
    ]
  in
  { kept = kept4; reports }
