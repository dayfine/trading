(** Unit tests for {!Ledger_entry_builder} + the {!Experiment_ledger} save path
    behind the [write_ledger_entry] CLI.

    Pins the entry-construction contract on an in-memory walk-forward aggregate:
    variant labels + verdict carry through, finite metric means become a [Some]
    fold_aggregate while a NaN-mean variant records [None], a supplied
    config-hash map populates the per-variant hash, and the built entry round
    -trips through [save_entry]/[load_entry] while preserving the append-only
    overwrite guarantee. *)

open OUnit2
open Core
open Matchers
module T = Walk_forward.Walk_forward_types
module EL = Experiment_ledger
module B = Ledger_entry_builder

(* All four ranked metrics in one cell; [stdev]/[min]/[max] are irrelevant to the
   builder (it reads only [.mean]) so they are filled with the same value. *)
let _stats mean : T.per_metric_stats =
  { mean; stdev = mean; min = mean; max = mean }

let _stability ~label ~sharpe ~calmar ~return_pct ~maxdd : T.variant_stability =
  {
    variant_label = label;
    total_return_pct = _stats return_pct;
    sharpe_ratio = _stats sharpe;
    max_drawdown_pct = _stats maxdd;
    calmar_ratio = _stats calmar;
    cagr_pct = _stats return_pct;
    avg_holding_days = T.nan_per_metric_stats;
  }

(* A two-variant aggregate: a finite baseline and a finite knob variant. *)
let _aggregate : T.aggregate =
  {
    fold_count = 31;
    baseline_label = "baseline";
    metric_label = "Sharpe";
    stability =
      [
        _stability ~label:"baseline" ~sharpe:0.68 ~calmar:2.04 ~return_pct:16.7
          ~maxdd:11.1;
        _stability ~label:"knob=1" ~sharpe:0.66 ~calmar:2.02 ~return_pct:16.5
          ~maxdd:11.2;
      ];
    sensitivity = [];
    verdicts = [];
  }

let _metadata : B.metadata =
  {
    date = "2026-06-01";
    slug = "builder-test";
    hypothesis = "knob=1 recovers missed gain";
    base_scenario = "goldens/sample.sexp";
    window_id = "rolling-2010-2026-365-182-31fold";
    baseline_label = "baseline";
    verdict = EL.Reject;
    notes = "lost on every axis";
  }

let _config_hash_for = function
  | "baseline" -> "hashA"
  | "knob=1" -> "hashB"
  | _ -> ""

(* ---------- build_entry: labels, hashes, verdict, aggregates ---------- *)

let test_build_entry_maps_variants _ =
  let entry =
    B.build_entry ~metadata:_metadata ~config_hash_for:_config_hash_for
      _aggregate
  in
  assert_that entry
    (all_of
       [
         field (fun (e : EL.entry) -> e.verdict) (equal_to EL.Reject);
         field (fun (e : EL.entry) -> e.slug) (equal_to "builder-test");
         field
           (fun (e : EL.entry) -> e.variants)
           (elements_are
              [
                equal_to
                  ({
                     label = "baseline";
                     config_hash = "hashA";
                     aggregate =
                       Some
                         {
                           mean_sharpe = 0.68;
                           mean_calmar = 2.04;
                           mean_return_pct = 16.7;
                           mean_max_drawdown_pct = 11.1;
                         };
                   }
                    : EL.variant_record);
                equal_to
                  ({
                     label = "knob=1";
                     config_hash = "hashB";
                     aggregate =
                       Some
                         {
                           mean_sharpe = 0.66;
                           mean_calmar = 2.02;
                           mean_return_pct = 16.5;
                           mean_max_drawdown_pct = 11.2;
                         };
                   }
                    : EL.variant_record);
              ]);
       ])

(* ---------- build_entry: NaN mean records [None], not a fabricated value ---- *)

let test_build_entry_nan_mean_is_none _ =
  let aggregate =
    {
      _aggregate with
      stability =
        [
          _stability ~label:"empty-fold" ~sharpe:Float.nan ~calmar:2.0
            ~return_pct:1.0 ~maxdd:1.0;
        ];
    }
  in
  let entry =
    B.build_entry ~metadata:_metadata ~config_hash_for:_config_hash_for
      aggregate
  in
  assert_that entry
    (field
       (fun (e : EL.entry) -> e.variants)
       (elements_are
          [ field (fun (v : EL.variant_record) -> v.aggregate) is_none ]))

(* ---------- build_entry: unknown label gets empty hash ---------- *)

let test_build_entry_unknown_label_empty_hash _ =
  let entry =
    B.build_entry ~metadata:_metadata ~config_hash_for:(fun _ -> "") _aggregate
  in
  assert_that entry
    (field
       (fun (e : EL.entry) -> e.variants)
       (elements_are
          [
            field (fun (v : EL.variant_record) -> v.config_hash) (equal_to "");
            field (fun (v : EL.variant_record) -> v.config_hash) (equal_to "");
          ]))

(* ---------- hash_map_of_variants: hashes match config_hash ---------- *)

let test_hash_map_matches_config_hash _ =
  let overrides = [ Sexp.of_string "((stage3_exit_margin_pct 0.02))" ] in
  let table = B.hash_map_of_variants [ ("v", overrides) ] in
  assert_that (Hashtbl.find table "v")
    (is_some_and (equal_to (EL.config_hash overrides)))

(* ---------- save_entry: writes <date>-<slug>.sexp + round-trips ---------- *)

let test_save_entry_round_trip _ =
  let dir = Filename_unix.temp_dir "ledger_builder_test" "" in
  let entry =
    B.build_entry ~metadata:_metadata ~config_hash_for:_config_hash_for
      _aggregate
  in
  EL.save_entry ~dir entry;
  let loaded =
    EL.load_entry (Filename.concat dir "2026-06-01-builder-test.sexp")
  in
  assert_that loaded (equal_to entry)

(* ---------- save_entry: append-only, raises on overwrite ---------- *)

let _raises_failure thunk =
  try
    ignore (thunk ());
    false
  with Failure _ -> true

let test_save_entry_raises_on_overwrite _ =
  let dir = Filename_unix.temp_dir "ledger_builder_test" "" in
  let entry =
    B.build_entry ~metadata:_metadata ~config_hash_for:_config_hash_for
      _aggregate
  in
  EL.save_entry ~dir entry;
  assert_that
    (_raises_failure (fun () -> EL.save_entry ~dir entry))
    (equal_to true)

let suite =
  "ledger_entry_builder"
  >::: [
         "build_entry_maps_variants" >:: test_build_entry_maps_variants;
         "build_entry_nan_mean_is_none" >:: test_build_entry_nan_mean_is_none;
         "build_entry_unknown_label_empty_hash"
         >:: test_build_entry_unknown_label_empty_hash;
         "hash_map_matches_config_hash" >:: test_hash_map_matches_config_hash;
         "save_entry_round_trip" >:: test_save_entry_round_trip;
         "save_entry_raises_on_overwrite"
         >:: test_save_entry_raises_on_overwrite;
       ]

let () = run_test_tt_main suite
