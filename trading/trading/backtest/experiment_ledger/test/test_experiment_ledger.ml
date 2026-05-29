(** Unit tests for {!Experiment_ledger}.

    Pins the ledger contract: round-trip save/load of an entry; [config_hash]
    stability + equality across logically-equal-but-differently-written override
    blobs and inequality across different configs; the append-only fail-loud on
    [save_entry] overwrite (the PR-1 lesson — every documented [raise] gets a
    test); and the [lookup] / [build_index] / [load_index] dedup round-trip. *)

open OUnit2
open Core
open Matchers
module EL = Experiment_ledger

(* A reusable entry for round-trip + index tests. Two variants: an empty-override
   baseline and a one-knob variant, so [build_index] yields two rows. *)
let _sample_entry =
  {
    EL.date = "2026-05-29";
    slug = "sample-experiment";
    hypothesis = "knob X recovers missed gain";
    base_scenario = "goldens/sample.sexp";
    window_id = "rolling-2010-2026-365-182-31fold";
    baseline_label = "base";
    variants =
      [
        { EL.label = "base"; config_hash = "hashA"; aggregate = None };
        {
          EL.label = "variant";
          config_hash = "hashB";
          aggregate =
            Some
              {
                EL.mean_sharpe = 0.5;
                mean_calmar = 1.2;
                mean_return_pct = 8.1;
                mean_max_drawdown_pct = 12.3;
              };
        };
      ];
    verdict = EL.Reject;
    notes = "lost on every aggregate axis";
  }

(* Catch a [Failure] from [thunk]; returns [true] iff one was raised. *)
let _raises_failure thunk =
  try
    ignore (thunk ());
    false
  with Failure _ -> true

(* ---------- Entry round-trips through save/load ---------- *)

let test_entry_round_trip _ =
  let dir = Filename_unix.temp_dir "ledger_test" "" in
  EL.save_entry ~dir _sample_entry;
  let loaded =
    EL.load_entry
      (Filename.concat dir
         (sprintf "%s-%s.sexp" _sample_entry.date _sample_entry.slug))
  in
  assert_that loaded (equal_to _sample_entry)

(* ---------- save_entry is append-only: raises on overwrite ---------- *)

let test_save_entry_raises_on_overwrite _ =
  let dir = Filename_unix.temp_dir "ledger_test" "" in
  EL.save_entry ~dir _sample_entry;
  assert_that
    (_raises_failure (fun () -> EL.save_entry ~dir _sample_entry))
    (equal_to true)

(* ---------- config_hash: equal for logically-equal blobs ---------- *)

(* The h2-m02 override written two ways: the canonical nested form, and the same
   two knobs in reversed overlay order. Deep-merge makes them logically equal,
   so the effective-config hash must match. *)
let _h2_m02_a =
  [
    Sexp.of_string "((stage3_force_exit_config ((hysteresis_weeks 2))))";
    Sexp.of_string "((stage3_exit_margin_pct 0.02))";
  ]

let _h2_m02_b =
  [
    Sexp.of_string "((stage3_exit_margin_pct 0.02))";
    Sexp.of_string "((stage3_force_exit_config ((hysteresis_weeks 2))))";
  ]

let test_config_hash_equal_for_equivalent_blobs _ =
  assert_that
    (String.equal (EL.config_hash _h2_m02_a) (EL.config_hash _h2_m02_b))
    (equal_to true)

(* ---------- config_hash: different configs hash differently ---------- *)

let test_config_hash_differs_for_different_configs _ =
  let empty = EL.config_hash [] in
  assert_that (String.equal empty (EL.config_hash _h2_m02_a)) (equal_to false)

(* ---------- config_hash: stable across calls ---------- *)

let test_config_hash_stable _ =
  assert_that
    (String.equal (EL.config_hash _h2_m02_a) (EL.config_hash _h2_m02_a))
    (equal_to true)

(* ---------- build_index: one row per (variant, entry) ---------- *)

let test_build_index_one_row_per_variant _ =
  assert_that
    (EL.build_index [ _sample_entry ])
    (elements_are
       [
         equal_to
           ({
              config_hash = "hashA";
              base_scenario = "goldens/sample.sexp";
              window_id = "rolling-2010-2026-365-182-31fold";
              verdict = EL.Reject;
              entry_slug = "sample-experiment";
            }
             : EL.index_row);
         equal_to
           ({
              config_hash = "hashB";
              base_scenario = "goldens/sample.sexp";
              window_id = "rolling-2010-2026-365-182-31fold";
              verdict = EL.Reject;
              entry_slug = "sample-experiment";
            }
             : EL.index_row);
       ])

(* ---------- lookup: hit returns recorded verdict ---------- *)

let test_lookup_hit _ =
  let rows = EL.build_index [ _sample_entry ] in
  assert_that
    (EL.lookup rows ~config_hash:"hashB" ~base_scenario:"goldens/sample.sexp"
       ~window_id:"rolling-2010-2026-365-182-31fold")
    (is_some_and (equal_to EL.Reject))

(* ---------- lookup: miss on unknown hash returns None ---------- *)

let test_lookup_miss _ =
  let rows = EL.build_index [ _sample_entry ] in
  assert_that
    (EL.lookup rows ~config_hash:"unknown-hash"
       ~base_scenario:"goldens/sample.sexp"
       ~window_id:"rolling-2010-2026-365-182-31fold")
    is_none

(* ---------- load_index reads back saved entries (skips index.sexp) ---------- *)

let test_load_index_round_trip _ =
  let dir = Filename_unix.temp_dir "ledger_test" "" in
  EL.save_entry ~dir _sample_entry;
  EL.save_index ~dir [ _sample_entry ];
  assert_that (EL.load_index ~dir) (elements_are [ equal_to _sample_entry ])

let suite =
  "experiment_ledger"
  >::: [
         "entry_round_trip" >:: test_entry_round_trip;
         "save_entry_raises_on_overwrite"
         >:: test_save_entry_raises_on_overwrite;
         "config_hash_equal_for_equivalent_blobs"
         >:: test_config_hash_equal_for_equivalent_blobs;
         "config_hash_differs_for_different_configs"
         >:: test_config_hash_differs_for_different_configs;
         "config_hash_stable" >:: test_config_hash_stable;
         "build_index_one_row_per_variant"
         >:: test_build_index_one_row_per_variant;
         "lookup_hit" >:: test_lookup_hit;
         "lookup_miss" >:: test_lookup_miss;
         "load_index_round_trip" >:: test_load_index_round_trip;
       ]

let () = run_test_tt_main suite
