open Core
open OUnit2
open Matchers
module RL = Apply_composition_policy_runner_lib
module CPT = Universe.Composition_policy_types
module Snapshot = Universe.Snapshot

(* ---------------------------------------------------------------------- *)
(* Fixtures                                                                *)
(* ---------------------------------------------------------------------- *)

let _tmp suffix = Stdlib.Filename.temp_file "acp_test_" ("_" ^ suffix)

let _snapshot_entry ?(weight = 0.25) ?(sector = "Tech") symbol : Snapshot.entry
    =
  { symbol; weight; sector; synthetic = false; avg_dollar_volume = None }

(* A symbol_types.sexp in the canonical Asset_type_enrichment shape, written by
   hand so the test does not cross dune-project boundaries. Each (symbol,
   asset_type_sexp) maps to a [Listed _] entry. *)
let _write_symbol_types ~path entries =
  let body =
    List.map entries ~f:(fun (sym, at) ->
        Printf.sprintf
          "    ((symbol %s) (asset_type (Listed %s)) (exchange \"\"))" sym at)
    |> String.concat ~sep:"\n"
  in
  Out_channel.write_all path
    ~data:
      ("((generated_at 2020-05-30)\n (source_endpoints ())\n (symbols (\n"
     ^ body ^ ")))\n")

let _save_snapshot ~path snapshot =
  match Snapshot.save snapshot ~path with
  | Ok () -> ()
  | Error err -> assert_failure ("snapshot save failed: " ^ Status.show err)

(* ---------------------------------------------------------------------- *)
(* run — end-to-end load / apply / write                                   *)
(* ---------------------------------------------------------------------- *)

(* GOOGL+GOOG dual-class + one Real Estate name. With reit_policy=Exclude the
   filtered snapshot keeps GOOGL + the non-REIT, drops GOOG (dual) + SPG (REIT);
   the report text records both. *)
let test_run_filters_and_writes _ =
  let snapshot : Snapshot.t =
    {
      date = Date.create_exn ~y:2020 ~m:Month.May ~d:31;
      method_ = Composition_from_individuals;
      size = 4;
      entries =
        [
          _snapshot_entry "GOOGL";
          _snapshot_entry "GOOG";
          _snapshot_entry "AAPL";
          _snapshot_entry ~sector:"Real Estate" "SPG";
        ];
      aggregate_period_return = 0.0;
    }
  in
  let snapshot_path = _tmp "in.sexp" in
  _save_snapshot ~path:snapshot_path snapshot;
  let symbol_types_path = _tmp "types.sexp" in
  _write_symbol_types ~path:symbol_types_path
    [ ("GOOGL", "\"Common Stock\""); ("AAPL", "\"Common Stock\"") ];
  let out_snapshot_path = _tmp "out.sexp" in
  let out_report_path = _tmp "report.txt" in
  let config = { CPT.default_config with reit_policy = CPT.Exclude } in
  let result =
    RL.run ~snapshot_path ~symbol_types_path ~config ~out_snapshot_path
      ~out_report_path
  in
  List.iter
    [ snapshot_path; symbol_types_path; out_snapshot_path; out_report_path ]
    ~f:(fun p -> try Stdlib.Sys.remove p with _ -> ());
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field (fun r -> r.RL.input_count) (equal_to 4);
            field (fun r -> r.RL.kept_count) (equal_to 2);
            field
              (fun r ->
                String.is_substring r.RL.report_text
                  ~substring:"GOOG: dual-class duplicate of GOOGL")
              (equal_to true);
            field
              (fun r ->
                String.is_substring r.RL.report_text
                  ~substring:"SPG: REIT excluded")
              (equal_to true);
          ]))

(* The written filtered snapshot reloads with only the kept members + updated
   size. *)
let test_run_filtered_snapshot_reloads _ =
  let snapshot : Snapshot.t =
    {
      date = Date.create_exn ~y:2020 ~m:Month.May ~d:31;
      method_ = Composition_from_individuals;
      size = 2;
      entries = [ _snapshot_entry "BRK-B"; _snapshot_entry "BRK-A" ];
      aggregate_period_return = 0.0;
    }
  in
  let snapshot_path = _tmp "in2.sexp" in
  _save_snapshot ~path:snapshot_path snapshot;
  let symbol_types_path = _tmp "types2.sexp" in
  _write_symbol_types ~path:symbol_types_path [ ("BRK-B", "\"Common Stock\"") ];
  let out_snapshot_path = _tmp "out2.sexp" in
  let out_report_path = _tmp "report2.txt" in
  ignore
    (RL.run ~snapshot_path ~symbol_types_path ~config:CPT.default_config
       ~out_snapshot_path ~out_report_path
      : RL.result Status.status_or);
  let reloaded = Snapshot.load ~path:out_snapshot_path in
  List.iter
    [ snapshot_path; symbol_types_path; out_snapshot_path; out_report_path ]
    ~f:(fun p -> try Stdlib.Sys.remove p with _ -> ());
  assert_that reloaded
    (is_ok_and_holds
       (all_of
          [
            field (fun s -> s.Snapshot.size) (equal_to 1);
            field
              (fun s ->
                List.map s.Snapshot.entries ~f:(fun e -> e.Snapshot.symbol))
              (elements_are [ equal_to "BRK-B" ]);
          ]))

(* Default config on a clean pool is an identity transform (no member removed).
   This pins the data-layer "default = current behaviour" invariant end-to-end. *)
let test_run_default_config_is_identity _ =
  let snapshot : Snapshot.t =
    {
      date = Date.create_exn ~y:2020 ~m:Month.May ~d:31;
      method_ = Composition_from_individuals;
      size = 3;
      entries =
        [
          _snapshot_entry "AAPL";
          _snapshot_entry "MSFT";
          _snapshot_entry ~sector:"Real Estate" "SPG";
        ];
      aggregate_period_return = 0.0;
    }
  in
  let snapshot_path = _tmp "in3.sexp" in
  _save_snapshot ~path:snapshot_path snapshot;
  let symbol_types_path = _tmp "types3.sexp" in
  _write_symbol_types ~path:symbol_types_path [];
  let out_snapshot_path = _tmp "out3.sexp" in
  let out_report_path = _tmp "report3.txt" in
  let result =
    RL.run ~snapshot_path ~symbol_types_path ~config:CPT.default_config
      ~out_snapshot_path ~out_report_path
  in
  List.iter
    [ snapshot_path; symbol_types_path; out_snapshot_path; out_report_path ]
    ~f:(fun p -> try Stdlib.Sys.remove p with _ -> ());
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field (fun r -> r.RL.input_count) (equal_to 3);
            field (fun r -> r.RL.kept_count) (equal_to 3);
          ]))

let suite =
  "Apply_composition_policy_runner_lib"
  >::: [
         "test_run_filters_and_writes" >:: test_run_filters_and_writes;
         "test_run_filtered_snapshot_reloads"
         >:: test_run_filtered_snapshot_reloads;
         "test_run_default_config_is_identity"
         >:: test_run_default_config_is_identity;
       ]

let () = run_test_tt_main suite
