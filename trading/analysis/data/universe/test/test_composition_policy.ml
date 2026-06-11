open Core
open OUnit2
open Matchers
open Universe
module CP = Composition_policy
module CPT = Composition_policy_types

(* ---------------------------------------------------------------------- *)
(* Fixture builder                                                         *)
(* ---------------------------------------------------------------------- *)

let _candidate ?(asset_type = Eodhd.Asset_type.Common_stock) ?(sector = "Tech")
    ?(avg_dollar_volume = 1_000_000.0) ~rank symbol : CPT.candidate =
  { symbol; asset_type; sector; avg_dollar_volume; rank }

(* Extract surviving symbols in order. *)
let _kept_symbols (r : CPT.result) = List.map r.kept ~f:(fun c -> c.CPT.symbol)

(* Find a report by filter name. *)
let _report (r : CPT.result) name =
  List.find_exn r.reports ~f:(fun rep -> String.equal rep.CPT.filter name)

let _dropped_symbols (rep : CPT.filter_report) =
  List.map rep.dropped ~f:(fun d -> d.CPT.symbol)

(* ---------------------------------------------------------------------- *)
(* Default config = no-op on a clean (no dual-class) pool                  *)
(* ---------------------------------------------------------------------- *)

(* A pool with no dual-class pairs, default config: every candidate survives
   in input order; no filter dropped anything. *)
let test_default_config_passes_clean_pool_through _ =
  let candidates =
    [
      _candidate ~rank:0 "AAPL";
      _candidate ~rank:1 "MSFT";
      _candidate ~asset_type:Eodhd.Asset_type.ADR ~rank:2 "TSM";
      _candidate ~sector:"Real Estate" ~rank:3 "SPG";
      _candidate ~asset_type:Eodhd.Asset_type.Preferred_stock ~rank:4 "BAC-PL";
    ]
  in
  let result = CP.apply ~config:CPT.default_config candidates in
  assert_that result
    (all_of
       [
         field _kept_symbols
           (elements_are
              [
                equal_to "AAPL";
                equal_to "MSFT";
                equal_to "TSM";
                equal_to "SPG";
                equal_to "BAC-PL";
              ]);
         field
           (fun r -> List.map r.CPT.reports ~f:(fun rep -> rep.CPT.filter))
           (elements_are
              [
                equal_to "dual_class_dedup";
                equal_to "reit_policy";
                equal_to "adr_liquidity_floor";
                equal_to "preferred_exclusion";
              ]);
       ])

(* ---------------------------------------------------------------------- *)
(* Filter 1: dual-class dedup (always active)                              *)
(* ---------------------------------------------------------------------- *)

(* GOOGL ranked above GOOG: keep GOOGL (higher rank / more liquid), drop GOOG
   with a reference to the kept symbol. Active even under the default config. *)
let test_dual_class_keeps_higher_ranked _ =
  let candidates =
    [
      _candidate ~rank:0 ~avg_dollar_volume:5e8 "GOOGL";
      _candidate ~rank:1 "AAPL";
      _candidate ~rank:2 ~avg_dollar_volume:2e8 "GOOG";
    ]
  in
  let result = CP.apply ~config:CPT.default_config candidates in
  assert_that result
    (all_of
       [
         field _kept_symbols
           (elements_are [ equal_to "GOOGL"; equal_to "AAPL" ]);
         field
           (fun r -> _dropped_symbols (_report r "dual_class_dedup"))
           (elements_are [ equal_to "GOOG" ]);
       ])

(* The drop reason records WHICH symbol the duplicate collapsed into. *)
let test_dual_class_drop_reason_names_kept_symbol _ =
  let candidates = [ _candidate ~rank:0 "BRK-B"; _candidate ~rank:1 "BRK-A" ] in
  let result = CP.apply ~config:CPT.default_config candidates in
  assert_that (_report result "dual_class_dedup").dropped
    (elements_are
       [
         equal_to
           ({
              symbol = "BRK-A";
              reason = CPT.Dual_class_duplicate { kept_symbol = "BRK-B" };
            }
             : CPT.drop);
       ])

(* ---------------------------------------------------------------------- *)
(* Filter 2: REIT exclude                                                  *)
(* ---------------------------------------------------------------------- *)

let test_reit_exclude_drops_real_estate _ =
  let candidates =
    [
      _candidate ~rank:0 "AAPL";
      _candidate ~sector:"Real Estate" ~rank:1 "SPG";
      _candidate ~sector:"Real Estate" ~rank:2 "O";
    ]
  in
  let config = { CPT.default_config with reit_policy = CPT.Exclude } in
  let result = CP.apply ~config candidates in
  assert_that result
    (all_of
       [
         field _kept_symbols (elements_are [ equal_to "AAPL" ]);
         field
           (fun r -> _dropped_symbols (_report r "reit_policy"))
           (elements_are [ equal_to "SPG"; equal_to "O" ]);
       ])

(* ---------------------------------------------------------------------- *)
(* Filter 3: ADR liquidity floor                                           *)
(* ---------------------------------------------------------------------- *)

(* Floor drops only ADR/GDR below it; a low-volume common stock is untouched. *)
let test_adr_floor_drops_small_adr_only _ =
  let candidates =
    [
      _candidate ~asset_type:Eodhd.Asset_type.ADR ~avg_dollar_volume:5e8 ~rank:0
        "TSM";
      _candidate ~asset_type:Eodhd.Asset_type.ADR ~avg_dollar_volume:1e5 ~rank:1
        "SMLADR";
      _candidate ~asset_type:Eodhd.Asset_type.Common_stock
        ~avg_dollar_volume:1e5 ~rank:2 "SMLCOM";
    ]
  in
  let config = { CPT.default_config with adr_min_dollar_volume = Some 1e6 } in
  let result = CP.apply ~config candidates in
  assert_that result
    (all_of
       [
         field _kept_symbols
           (elements_are [ equal_to "TSM"; equal_to "SMLCOM" ]);
         field
           (fun r -> _dropped_symbols (_report r "adr_liquidity_floor"))
           (elements_are [ equal_to "SMLADR" ]);
       ])

(* ---------------------------------------------------------------------- *)
(* Filter 4: preferred exclusion                                           *)
(* ---------------------------------------------------------------------- *)

let test_preferred_exclusion_drops_preferred _ =
  let candidates =
    [
      _candidate ~rank:0 "AAPL";
      _candidate ~asset_type:Eodhd.Asset_type.Preferred_stock ~rank:1 "BAC-PL";
    ]
  in
  let config = { CPT.default_config with exclude_preferred = true } in
  let result = CP.apply ~config candidates in
  assert_that result
    (all_of
       [
         field _kept_symbols (elements_are [ equal_to "AAPL" ]);
         field
           (fun r -> _dropped_symbols (_report r "preferred_exclusion"))
           (elements_are [ equal_to "BAC-PL" ]);
       ])

(* ---------------------------------------------------------------------- *)
(* Determinism                                                             *)
(* ---------------------------------------------------------------------- *)

let test_apply_is_deterministic _ =
  let candidates =
    [
      _candidate ~rank:0 "GOOGL";
      _candidate ~sector:"Real Estate" ~rank:1 "SPG";
      _candidate ~rank:2 "GOOG";
    ]
  in
  let config = { CPT.default_config with reit_policy = CPT.Exclude } in
  let r1 = CP.apply ~config candidates in
  let r2 = CP.apply ~config candidates in
  assert_that r2 (equal_to r1)

let suite =
  "Composition_policy"
  >::: [
         "test_default_config_passes_clean_pool_through"
         >:: test_default_config_passes_clean_pool_through;
         "test_dual_class_keeps_higher_ranked"
         >:: test_dual_class_keeps_higher_ranked;
         "test_dual_class_drop_reason_names_kept_symbol"
         >:: test_dual_class_drop_reason_names_kept_symbol;
         "test_reit_exclude_drops_real_estate"
         >:: test_reit_exclude_drops_real_estate;
         "test_adr_floor_drops_small_adr_only"
         >:: test_adr_floor_drops_small_adr_only;
         "test_preferred_exclusion_drops_preferred"
         >:: test_preferred_exclusion_drops_preferred;
         "test_apply_is_deterministic" >:: test_apply_is_deterministic;
       ]

let () = run_test_tt_main suite
