(** Tests for the {!Scenario_lib.Universe_snapshot} bridge — converting
    custom-universe goldens ({!Universe.Snapshot.t}) into the [(symbol, sector)]
    pair list shape {!Universe_file.load} consumes.

    Three behavioural contracts to pin:
    - Composition snapshots (real symbols) project cleanly to pairs.
    - Decomposition snapshots (all synthetic) surface as [Failed_precondition]
      rather than silently producing an empty list.
    - Mixed composition/synthetic snapshots drop synthetic entries and keep the
      real ones. *)

open OUnit2
open Core
open Matchers
module Universe_snapshot = Scenario_lib.Universe_snapshot
module Snapshot = Universe.Snapshot

let _make_entry ~symbol ~sector ~synthetic : Snapshot.entry =
  { symbol; weight = 0.01; sector; synthetic }

let _make_snapshot ~method_ entries : Snapshot.t =
  {
    date = Date.create_exn ~y:2019 ~m:May ~d:31;
    method_;
    size = List.length entries;
    entries;
    aggregate_period_return = 0.10;
  }

let _write_snapshot_tmp snapshot =
  let path = Stdlib.Filename.temp_file "universe_snapshot_test_" ".sexp" in
  match Snapshot.save snapshot ~path with
  | Ok () -> path
  | Error err -> assert_failure ("Snapshot.save failed: " ^ Status.show err)

let test_composition_projects_to_pairs _ =
  let snapshot =
    _make_snapshot ~method_:Composition_from_individuals
      [
        _make_entry ~symbol:"AAPL" ~sector:"Information Technology"
          ~synthetic:false;
        _make_entry ~symbol:"JPM" ~sector:"Financials" ~synthetic:false;
        _make_entry ~symbol:"XOM" ~sector:"Energy" ~synthetic:false;
      ]
  in
  let path = _write_snapshot_tmp snapshot in
  let result = Universe_snapshot.load_path_as_pairs ~path in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            equal_to ("AAPL", "Information Technology");
            equal_to ("JPM", "Financials");
            equal_to ("XOM", "Energy");
          ]))

let test_pure_decomposition_errors _ =
  let snapshot =
    _make_snapshot
      ~method_:
        (Decomposition_from_index
           {
             anchor = `Shiller_sp_composite;
             factor_skeleton = `French_5_industry;
           })
      [
        _make_entry ~symbol:"SYNTH_HiTec_0001" ~sector:"HiTec" ~synthetic:true;
        _make_entry ~symbol:"SYNTH_Cnsmr_0001" ~sector:"Cnsmr" ~synthetic:true;
      ]
  in
  let path = _write_snapshot_tmp snapshot in
  let result = Universe_snapshot.load_path_as_pairs ~path in
  assert_that result
    (matching ~msg:"expected Failed_precondition error"
       (function
         | Error (s : Status.t)
           when Status.equal_code s.code Status.Failed_precondition ->
             Some ()
         | _ -> None)
       (equal_to ()))

let test_mixed_keeps_real_drops_synthetic _ =
  let snapshot =
    _make_snapshot ~method_:Composition_from_individuals
      [
        _make_entry ~symbol:"AAPL" ~sector:"Information Technology"
          ~synthetic:false;
        _make_entry ~symbol:"SYNTH_HiTec_0001" ~sector:"HiTec" ~synthetic:true;
        _make_entry ~symbol:"JPM" ~sector:"Financials" ~synthetic:false;
      ]
  in
  let path = _write_snapshot_tmp snapshot in
  let result = Universe_snapshot.load_path_as_pairs ~path in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            equal_to ("AAPL", "Information Technology");
            equal_to ("JPM", "Financials");
          ]))

let test_universe_file_load_falls_back_to_snapshot _ =
  (* The headline integration: a Universe_file.load on a snapshot path
     auto-falls-back through the new bridge, returning a [Pinned] value. *)
  let snapshot =
    _make_snapshot ~method_:Composition_from_individuals
      [
        _make_entry ~symbol:"AAPL" ~sector:"Information Technology"
          ~synthetic:false;
        _make_entry ~symbol:"JPM" ~sector:"Financials" ~synthetic:false;
      ]
  in
  let path = _write_snapshot_tmp snapshot in
  assert_that
    (Scenario_lib.Universe_file.load path)
    (matching ~msg:"expected Pinned"
       (function Scenario_lib.Universe_file.Pinned xs -> Some xs | _ -> None)
       (elements_are
          [
            equal_to
              ({ symbol = "AAPL"; sector = "Information Technology" }
                : Scenario_lib.Universe_file.pinned_entry);
            equal_to
              ({ symbol = "JPM"; sector = "Financials" }
                : Scenario_lib.Universe_file.pinned_entry);
          ]))

(** Smoke test against a committed composition golden: load + convert + check
    cardinality. Pinned to top-500-1998.sexp (the earliest non-synthetic
    universe in the goldens-custom-universe set). *)
let _composition_goldens_root () =
  let rec walk_up dir tries_left =
    if tries_left = 0 then None
    else
      let candidate =
        Filename.concat dir
          "trading/test_data/goldens-custom-universe/composition"
      in
      if try Stdlib.Sys.is_directory candidate with _ -> false then
        Some candidate
      else
        let parent = Filename.dirname dir in
        if String.equal parent dir then None else walk_up parent (tries_left - 1)
  in
  walk_up (Stdlib.Sys.getcwd ()) 10

let test_committed_composition_golden_loads _ =
  match _composition_goldens_root () with
  | None ->
      assert_failure
        (sprintf "composition goldens dir not found from cwd=%s"
           (Stdlib.Sys.getcwd ()))
  | Some root ->
      let path = Filename.concat root "top-500-1998.sexp" in
      let result = Universe_snapshot.load_path_as_pairs ~path in
      assert_that result (is_ok_and_holds (size_is 500))

let suite =
  "Universe_snapshot"
  >::: [
         "composition projects to (symbol, sector) pairs"
         >:: test_composition_projects_to_pairs;
         "pure decomposition errors with Failed_precondition"
         >:: test_pure_decomposition_errors;
         "mixed snapshot drops synthetic, keeps real entries"
         >:: test_mixed_keeps_real_drops_synthetic;
         "Universe_file.load falls back to snapshot decoder"
         >:: test_universe_file_load_falls_back_to_snapshot;
         "committed top-500-1998 composition golden loads"
         >:: test_committed_composition_golden_loads;
       ]

let () = run_test_tt_main suite
