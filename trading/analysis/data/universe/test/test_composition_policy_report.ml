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

let _entry ?(weight = 0.1) ?(sector = "Tech") ?avg_dollar_volume symbol :
    Snapshot.entry =
  { symbol; weight; sector; synthetic = false; avg_dollar_volume }

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

(* The entry's own [avg_dollar_volume] flows into the candidate, so the ADR
   floor fires: the ADR entry below the floor is dropped, the one above is kept.
   No [?dollar_volume] map is passed — the volumes come from the snapshot. *)
let test_adr_floor_fires_from_entry_volume _ =
  let snapshot =
    _snapshot
      [
        _entry "AAPL" ~avg_dollar_volume:5e9;
        _entry "TSM" ~avg_dollar_volume:2e9 (* above floor → kept *);
        _entry "ADRX" ~avg_dollar_volume:1e6 (* below floor → dropped *);
      ]
  in
  let asset_type = Hashtbl.create (module String) in
  Hashtbl.set asset_type ~key:"TSM" ~data:Eodhd.Asset_type.ADR;
  Hashtbl.set asset_type ~key:"ADRX" ~data:Eodhd.Asset_type.ADR;
  let equity_like = Hashtbl.create (module String) in
  let candidates =
    CPR.candidates_of_snapshot snapshot ~equity_like ~asset_type ()
  in
  let config = { CPT.default_config with adr_min_dollar_volume = Some 1e9 } in
  assert_that
    (CP.apply ~config candidates)
    (field
       (fun r -> List.map r.CPT.kept ~f:(fun c -> c.CPT.symbol))
       (elements_are [ equal_to "AAPL"; equal_to "TSM" ]))

(* An explicit [?dollar_volume] map overrides the entry's own volume: ADRX's
   entry volume is below the floor, but the override map lifts it above, so it
   is kept. *)
let test_dollar_volume_map_overrides_entry _ =
  let snapshot =
    _snapshot
      [
        _entry "AAPL" ~avg_dollar_volume:5e9;
        _entry "ADRX" ~avg_dollar_volume:1e6;
      ]
  in
  let asset_type = Hashtbl.create (module String) in
  Hashtbl.set asset_type ~key:"ADRX" ~data:Eodhd.Asset_type.ADR;
  let equity_like = Hashtbl.create (module String) in
  let dollar_volume = Hashtbl.create (module String) in
  Hashtbl.set dollar_volume ~key:"ADRX" ~data:5e9;
  let candidates =
    CPR.candidates_of_snapshot snapshot ~equity_like ~asset_type ~dollar_volume
      ()
  in
  let config = { CPT.default_config with adr_min_dollar_volume = Some 1e9 } in
  assert_that
    (CP.apply ~config candidates)
    (field
       (fun r -> List.map r.CPT.kept ~f:(fun c -> c.CPT.symbol))
       (elements_are [ equal_to "AAPL"; equal_to "ADRX" ]))

(* An entry with [avg_dollar_volume = None] and no map override falls back to
   [+inf], so the ADR floor cannot drop it (conservative default preserved). *)
let test_none_entry_volume_defaults_infinity _ =
  let snapshot = _snapshot [ _entry "AAPL"; _entry "TSM" ] in
  let asset_type = Hashtbl.create (module String) in
  Hashtbl.set asset_type ~key:"TSM" ~data:Eodhd.Asset_type.ADR;
  let equity_like = Hashtbl.create (module String) in
  let candidates =
    CPR.candidates_of_snapshot snapshot ~equity_like ~asset_type ()
  in
  let config = { CPT.default_config with adr_min_dollar_volume = Some 1e9 } in
  assert_that
    (CP.apply ~config candidates)
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
         "test_adr_floor_fires_from_entry_volume"
         >:: test_adr_floor_fires_from_entry_volume;
         "test_dollar_volume_map_overrides_entry"
         >:: test_dollar_volume_map_overrides_entry;
         "test_none_entry_volume_defaults_infinity"
         >:: test_none_entry_volume_defaults_infinity;
         "test_render_reports_contains_filters_and_totals"
         >:: test_render_reports_contains_filters_and_totals;
       ]

let () = run_test_tt_main suite
