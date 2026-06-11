open Core
open OUnit2
open Matchers
open Universe
module CPR = Composition_policy_report
module CP = Composition_policy
module CPT = Composition_policy_types

(* ---------------------------------------------------------------------- *)
(* candidates_of_snapshot                                                  *)
(* ---------------------------------------------------------------------- *)

let _entry ?(weight = 0.1) ?(sector = "Tech") symbol : Snapshot.entry =
  { symbol; weight; sector; synthetic = false }

let _snapshot entries : Snapshot.t =
  {
    date = Date.create_exn ~y:2020 ~m:Month.May ~d:31;
    method_ = Composition_from_individuals;
    size = List.length entries;
    entries;
    aggregate_period_return = 0.0;
  }

(* rank follows entry order; sector taken from the entry; asset_type from the
   provided map (default Common_stock); dollar_volume defaults to infinity. *)
let test_candidates_rank_and_metadata _ =
  let snapshot =
    _snapshot
      [ _entry "AAPL"; _entry ~sector:"Real Estate" "SPG"; _entry "TSM" ]
  in
  let asset_type = Hashtbl.create (module String) in
  Hashtbl.set asset_type ~key:"TSM" ~data:Eodhd.Asset_type.ADR;
  let equity_like = Hashtbl.create (module String) in
  let candidates =
    CPR.candidates_of_snapshot snapshot ~equity_like ~asset_type ()
  in
  assert_that candidates
    (elements_are
       [
         equal_to
           ({
              symbol = "AAPL";
              asset_type = Eodhd.Asset_type.Common_stock;
              sector = "Tech";
              avg_dollar_volume = Float.infinity;
              rank = 0;
            }
             : CPT.candidate);
         equal_to
           ({
              symbol = "SPG";
              asset_type = Eodhd.Asset_type.Common_stock;
              sector = "Real Estate";
              avg_dollar_volume = Float.infinity;
              rank = 1;
            }
             : CPT.candidate);
         equal_to
           ({
              symbol = "TSM";
              asset_type = Eodhd.Asset_type.ADR;
              sector = "Tech";
              avg_dollar_volume = Float.infinity;
              rank = 2;
            }
             : CPT.candidate);
       ])

(* With no dollar_volume map, the ADR floor cannot drop (volume = infinity). *)
let test_adr_floor_inert_without_volume _ =
  let snapshot = _snapshot [ _entry "AAPL"; _entry "TSM" ] in
  let asset_type = Hashtbl.create (module String) in
  Hashtbl.set asset_type ~key:"TSM" ~data:Eodhd.Asset_type.ADR;
  let equity_like = Hashtbl.create (module String) in
  let candidates =
    CPR.candidates_of_snapshot snapshot ~equity_like ~asset_type ()
  in
  let config = { CPT.default_config with adr_min_dollar_volume = Some 1e9 } in
  let result = CP.apply ~config candidates in
  assert_that result
    (field
       (fun r -> List.map r.CPT.kept ~f:(fun c -> c.CPT.symbol))
       (elements_are [ equal_to "AAPL"; equal_to "TSM" ]))

(* ---------------------------------------------------------------------- *)
(* render_reports                                                          *)
(* ---------------------------------------------------------------------- *)

(* The rendered text names each filter, its kept-count, every dropped symbol
   with a reason, and a totals line. *)
let test_render_reports_contains_filters_and_totals _ =
  let candidates =
    [
      ({
         symbol = "GOOGL";
         asset_type = Eodhd.Asset_type.Common_stock;
         sector = "Tech";
         avg_dollar_volume = 5e8;
         rank = 0;
       }
        : CPT.candidate);
      {
        symbol = "GOOG";
        asset_type = Eodhd.Asset_type.Common_stock;
        sector = "Tech";
        avg_dollar_volume = 2e8;
        rank = 1;
      };
      {
        symbol = "SPG";
        asset_type = Eodhd.Asset_type.Common_stock;
        sector = "Real Estate";
        avg_dollar_volume = 1e8;
        rank = 2;
      };
    ]
  in
  let config = { CPT.default_config with reit_policy = CPT.Exclude } in
  let text = CPR.render_reports (CP.apply ~config candidates) in
  let contains substr = String.is_substring text ~substring:substr in
  assert_that
    (List.for_all
       [
         "dual_class_dedup";
         "GOOG: dual-class duplicate of GOOGL";
         "reit_policy";
         "SPG: REIT excluded";
         "TOTAL: kept 1, dropped 2";
       ]
       ~f:contains)
    (equal_to true)

let suite =
  "Composition_policy_report"
  >::: [
         "test_candidates_rank_and_metadata"
         >:: test_candidates_rank_and_metadata;
         "test_adr_floor_inert_without_volume"
         >:: test_adr_floor_inert_without_volume;
         "test_render_reports_contains_filters_and_totals"
         >:: test_render_reports_contains_filters_and_totals;
       ]

let () = run_test_tt_main suite
