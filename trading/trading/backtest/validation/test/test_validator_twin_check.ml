(** V6 twin positions (issue #3035): the share-class-group source alongside the
    original rename-twin source, the missing-map report, and the wiring from
    [Validator_report.run]'s [data_dir] to the committed [share_classes.sexp].
*)

open Core
open OUnit2
open Matchers
module Vt = Post_run_validator.Validator_types
module Vc = Post_run_validator.Validator_checks
module Vr = Post_run_validator.Validator_report
module Tw = Post_run_validator.Validator_twin_check
module Scm = Weinstein_strategy.Share_class_map

(* ---- builders ---------------------------------------------------------- *)

let _map = Scm.of_groups [ [ "GOOG"; "GOOGL" ]; [ "FWONA"; "FWONK" ] ]

let trade ?(side = "LONG") ?(entry_price = 100.0) ?(exit_price = 110.0) ~symbol
    ~entry_date ~exit_date () : Vt.trade_row =
  {
    symbol;
    side;
    entry_date = Date.of_string entry_date;
    exit_date = Date.of_string exit_date;
    entry_price;
    exit_price;
    quantity = 100.0;
    exit_trigger = "";
    stop_trigger_kind = "";
    stop_initial_distance_pct = None;
    position_id = None;
    stop_fill_distance_pct = None;
  }

let open_row ~symbol ~entry_date : Vt.open_row =
  {
    symbol;
    side = "LONG";
    entry_date = Date.of_string entry_date;
    entry_price = 100.0;
    quantity = 100.0;
  }

let inputs ?(share_classes = Ok _map) ?(open_positions = []) trades =
  { (Vt.empty_inputs ()) with trades; open_positions; share_classes }

let v6 i = Vc.run_check ~id:"V6" i

let outcome ~n ~passed =
  all_of
    [
      field (fun (r : Vt.check_result) -> r.n_violations) (equal_to n);
      field (fun (r : Vt.check_result) -> r.passed) (equal_to passed);
    ]

let specimen_symbols m =
  field
    (fun (r : Vt.check_result) ->
      List.map r.specimens ~f:(fun (s : Vt.specimen) -> s.symbol))
    m

let skip_reason m = field (fun (r : Vt.check_result) -> r.skip_reason) m

(* The inv5-investor-s1-v11 specimen: FWONK entered 2023-03-27, FWONA
   2023-04-03, both held until 2023-06-05 — different dates and prices, so the
   rename-twin pass alone never matched them. *)
let _fwonk =
  trade ~symbol:"FWONK" ~entry_date:"2023-03-27" ~exit_date:"2023-06-05" ()

let _fwona ?(entry_date = "2023-04-03") ?(exit_date = "2023-06-05") () =
  trade ~symbol:"FWONA" ~entry_date ~exit_date ~entry_price:73.0
    ~exit_price:68.0 ()

(* GOOG/GOOGL booked as identical twins: both passes match this pair. *)
let _goog_twin symbol =
  trade ~symbol ~entry_date:"2025-01-03" ~exit_date:"2025-03-07"
    ~entry_price:190.0 ~exit_price:175.0 ()

(* ---- share-class source ------------------------------------------------ *)

let test_fwon_overlap_is_violation _ =
  assert_that
    (v6 (inputs [ _fwonk; _fwona () ]))
    (all_of
       [
         outcome ~n:1 ~passed:false;
         specimen_symbols (equal_to [ "FWONK" ]);
         field
           (fun (r : Vt.check_result) ->
             List.map r.specimens ~f:(fun (s : Vt.specimen) -> s.detail))
           (elements_are
              [
                equal_to
                  "share-class overlap: FWONK/FWONA held together \
                   2023-04-03..2023-06-05";
              ]);
         skip_reason is_none;
       ])

(* FWONK closed before FWONA opened, and a same-day exit-and-rotate into the
   sibling class: neither is two classes held at once. *)
let test_fwon_non_overlapping_is_clean _ =
  let fwonk_early =
    trade ~symbol:"FWONK" ~entry_date:"2023-01-09" ~exit_date:"2023-03-31" ()
  in
  let fwonk_rotated =
    trade ~symbol:"FWONK" ~entry_date:"2023-06-05" ~exit_date:"2023-08-01" ()
  in
  assert_that
    (v6 (inputs [ fwonk_early; _fwona (); fwonk_rotated ]))
    (outcome ~n:0 ~passed:true)

(* An open FWONA position (held past run end) overlaps a closed FWONK trade. *)
let test_open_position_overlap_is_violation _ =
  assert_that
    (v6
       (inputs
          ~open_positions:[ open_row ~symbol:"FWONA" ~entry_date:"2023-05-01" ]
          [ _fwonk ]))
    (all_of
       [ outcome ~n:1 ~passed:false; specimen_symbols (equal_to [ "FWONK" ]) ])

(* A long in one class and a short in the other is a pair trade, not doubled
   exposure. *)
let test_opposite_sides_are_clean _ =
  let short_fwona =
    trade ~side:"SHORT" ~symbol:"FWONA" ~entry_date:"2023-04-03"
      ~exit_date:"2023-06-05" ()
  in
  assert_that (v6 (inputs [ _fwonk; short_fwona ])) (outcome ~n:0 ~passed:true)

(* GOOG/GOOGL is both a rename twin and a share-class pair: still ONE
   violation, not one per source. *)
let test_goog_twin_counted_once _ =
  assert_that
    (v6 (inputs [ _goog_twin "GOOG"; _goog_twin "GOOGL" ]))
    (outcome ~n:1 ~passed:false)

(* Both issuers in one run: the #3035 done-when shape (GOOG + FWON = 2). *)
let test_goog_and_fwon_are_two_violations _ =
  assert_that
    (v6 (inputs [ _goog_twin "GOOG"; _goog_twin "GOOGL"; _fwonk; _fwona () ]))
    (outcome ~n:2 ~passed:false)

let test_unrelated_symbols_unaffected _ =
  let t symbol entry_price =
    trade ~symbol ~entry_date:"2023-03-27" ~exit_date:"2023-06-05" ~entry_price
      ()
  in
  assert_that
    (v6 (inputs [ t "AAPL" 150.0; t "MSFT" 280.0; t "FWONK" 60.0 ]))
    (outcome ~n:0 ~passed:true)

(* ---- missing map ------------------------------------------------------- *)

let _missing = Error "share-class map not found at /nowhere/share_classes.sexp"

(* No map: FWON goes unseen, but the result says why rather than reading as a
   clean V6; the rename-twin pass still catches GOOG/GOOGL. *)
let test_missing_map_reported _ =
  assert_that
    (v6
       (inputs ~share_classes:_missing
          [ _goog_twin "GOOG"; _goog_twin "GOOGL"; _fwonk; _fwona () ]))
    (all_of
       [
         outcome ~n:1 ~passed:false;
         skip_reason
           (is_some_and
              (equal_to
                 "share-class source unavailable, rename-twin pass only: \
                  share-class map not found at /nowhere/share_classes.sexp"));
       ])

let test_missing_map_rendered _ =
  let report : Vt.report =
    {
      checks = [ v6 (inputs ~share_classes:_missing [ _fwonk; _fwona () ]) ];
      audit_join = { matched = 0; total = 2 };
    }
  in
  assert_that (Vr.render_md report)
    (contains_substring
       "V6 INVARIANT PASS (share-class source unavailable, rename-twin pass \
        only:")

let test_load_missing_file_is_error _ =
  assert_that
    (Tw.load_share_classes ~data_dir:"/nonexistent-dir")
    (matching ~msg:"Expected Error"
       (function Error reason -> Some reason | Ok _ -> None)
       (contains_substring "/nonexistent-dir/share_classes.sexp"))

(* The committed map (TRADING_DATA_DIR = trading/test_data) groups FWONA with
   FWONK and GOOG with GOOGL. *)
let test_committed_map_groups_fwon _ =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  assert_that
    (Tw.load_share_classes ~data_dir)
    (matching ~msg:"Expected Ok map"
       (function Ok m -> Some m | Error _ -> None)
       (field
          (fun m ->
            ( Scm.group_of m "FWONA",
              Scm.group_of m "FWONK",
              Scm.group_of m "GOOG",
              Scm.group_of m "GOOGL" ))
          (equal_to (Some "FWONA", Some "FWONA", Some "GOOG", Some "GOOG"))))

(* ---- end to end: Validator_report.run reads data_dir/share_classes.sexp -- *)

(* trades.csv columns: symbol, side, entry, exit, _, entry_price, exit_price,
   quantity, then the optional trailing columns left empty. *)
let _csv_row (symbol, entry, entry_price, exit_price) =
  sprintf "%s,LONG,%s,2023-06-05,,%s,%s,100,,,,,,,,,,,,," symbol entry
    entry_price exit_price

let _trades_csv =
  String.concat ~sep:"\n"
    ("header"
    :: List.map ~f:_csv_row
         [
           ("FWONK", "2023-03-27", "60", "66");
           ("FWONA", "2023-04-03", "73", "68");
         ])
  ^ "\n"

let rec _remove_tree path =
  if Stdlib.Sys.is_directory path then (
    Array.iter (Stdlib.Sys.readdir path) ~f:(fun n ->
        _remove_tree (Stdlib.Filename.concat path n));
    Stdlib.Sys.rmdir path)
  else Stdlib.Sys.remove path

let _run_v6 files =
  let dir = Stdlib.Filename.temp_dir "validator_twin" "" in
  List.iter files ~f:(fun (name, data) ->
      Out_channel.write_all (Stdlib.Filename.concat dir name) ~data);
  let out = Stdlib.Filename.concat dir "report" in
  Exn.protect
    ~f:(fun () ->
      Vr.run ~run_dir:dir ~data_dir:dir ~config:Vt.default_config ~out
      |> fun (r : Vt.report) ->
      List.find r.checks ~f:(fun c -> String.equal c.id "V6"))
    ~finally:(fun () -> _remove_tree dir)

let test_run_reads_map_from_data_dir _ =
  assert_that
    (_run_v6
       [
         ("trades.csv", _trades_csv); (Scm.default_file_name, "((FWONA FWONK))");
       ])
    (is_some_and (all_of [ outcome ~n:1 ~passed:false; skip_reason is_none ]))

let test_run_without_map_reports_it _ =
  assert_that
    (_run_v6 [ ("trades.csv", _trades_csv) ])
    (is_some_and
       (all_of
          [
            outcome ~n:0 ~passed:true;
            skip_reason
              (is_some_and
                 (contains_substring "share-class source unavailable"));
          ]))

let suite =
  "validator_twin_check"
  >::: [
         "fwon overlap is a violation" >:: test_fwon_overlap_is_violation;
         "fwon non-overlapping is clean" >:: test_fwon_non_overlapping_is_clean;
         "open position overlap is a violation"
         >:: test_open_position_overlap_is_violation;
         "opposite sides are clean" >:: test_opposite_sides_are_clean;
         "goog twin counted once" >:: test_goog_twin_counted_once;
         "goog and fwon are two violations"
         >:: test_goog_and_fwon_are_two_violations;
         "unrelated symbols unaffected" >:: test_unrelated_symbols_unaffected;
         "missing map reported" >:: test_missing_map_reported;
         "missing map rendered" >:: test_missing_map_rendered;
         "load missing file is error" >:: test_load_missing_file_is_error;
         "committed map groups fwon" >:: test_committed_map_groups_fwon;
         "run reads map from data_dir" >:: test_run_reads_map_from_data_dir;
         "run without map reports it" >:: test_run_without_map_reports_it;
       ]

let () = run_test_tt_main suite
