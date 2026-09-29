(** Tests for V19 (audit join) and V20 (audit price-basis sanity) — issue #3002
    part A ({!Post_run_validator.Validator_audit_checks}). *)

open Core
open OUnit2
open Matchers
module Vt = Post_run_validator.Validator_types
module Vc = Post_run_validator.Validator_checks
module Va = Post_run_validator.Validator_artifacts
module Vr = Post_run_validator.Validator_report

(* ---- builders ---------------------------------------------------------- *)

let trade ?(position_id = None) ?(side = "LONG") ~symbol ~entry_date () :
    Vt.trade_row =
  {
    symbol;
    side;
    entry_date = Date.of_string entry_date;
    exit_date = Date.of_string "2021-06-01";
    entry_price = 100.0;
    exit_price = 100.0;
    quantity = 10.0;
    exit_trigger = "";
    stop_trigger_kind = "";
    stop_initial_distance_pct = None;
    position_id;
    stop_fill_distance_pct = None;
  }

let ctx ?(close_at_decision = None) ?(adjusted_close_at_decision = None)
    ?(ma_value = None) () : Vt.entry_context =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 3; late = false };
    macro_trend = Weinstein_types.Bullish;
    ma_direction = Weinstein_types.Rising;
    resistance_quality = None;
    installed_stop = 90.0;
    suggested_entry = 100.0;
    close_at_decision;
    adjusted_close_at_decision;
    ma_value;
  }

(* An audit entry leg, joined through the real [build_audit_lookup]. *)
let join_row ~position_id ~symbol ~entry_date : Va.audit_join_row =
  {
    position_id;
    symbol;
    entry_date = Date.of_string entry_date;
    context = ctx ();
  }

(* Inputs with a loaded audit: [audit_absent = None] arms V19/V20. *)
let loaded ~trades ~audit =
  { (Vt.empty_inputs ()) with trades; audit; audit_absent = None }

let audit_by_symbol assoc (row : Vt.trade_row) =
  List.Assoc.find assoc row.symbol ~equal:String.equal

let outcome ~n_violations ~n_skipped ~passed =
  all_of
    [
      field
        (fun (r : Vt.check_result) -> r.n_violations)
        (equal_to n_violations);
      field (fun (r : Vt.check_result) -> r.n_skipped) (equal_to n_skipped);
      field (fun (r : Vt.check_result) -> r.passed) (equal_to passed);
    ]

(* ---- V19: audit join on position_id ------------------------------------ *)

(* Firing: a trade whose position_id has no audit entry — the #2989 shape (a
   re-issued suspended ticket). The audit holds an entry for the same symbol
   AND date under a different position_id; the join is on position_id, so the
   symbol|date coincidence must not rescue it. *)
let test_v19_fires_on_missing_position_id _ =
  let audit =
    Va.build_audit_lookup
      [
        join_row ~position_id:"AAA-wein-1" ~symbol:"AAA"
          ~entry_date:"2021-03-05";
        join_row ~position_id:"BBB-wein-2" ~symbol:"BBB"
          ~entry_date:"2021-03-05";
      ]
  in
  let trades =
    [
      trade ~position_id:(Some "AAA-wein-1") ~symbol:"AAA"
        ~entry_date:"2021-03-08" ();
      trade ~position_id:(Some "BBB-wein-9") ~symbol:"BBB"
        ~entry_date:"2021-03-05" ();
    ]
  in
  assert_that
    (Vc.run_check ~id:"V19" (loaded ~trades ~audit))
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
         field (fun (r : Vt.check_result) -> r.severity) (equal_to Vt.Invariant);
         field
           (fun (r : Vt.check_result) -> r.specimens)
           (elements_are
              [
                all_of
                  [
                    field (fun (s : Vt.specimen) -> s.symbol) (equal_to "BBB");
                    field
                      (fun (s : Vt.specimen) -> s.detail)
                      (contains_substring "BBB-wein-9");
                  ];
              ]);
       ])

(* Clean: every trade's position_id has an audit entry (the AAA row joins
   despite its fill-date vs signal-date skew). *)
let test_v19_clean _ =
  let audit =
    Va.build_audit_lookup
      [
        join_row ~position_id:"AAA-wein-1" ~symbol:"AAA"
          ~entry_date:"2021-03-05";
      ]
  in
  let trades =
    [
      trade ~position_id:(Some "AAA-wein-1") ~symbol:"AAA"
        ~entry_date:"2021-03-08" ();
    ]
  in
  assert_that
    (Vc.run_check ~id:"V19" (loaded ~trades ~audit))
    (all_of
       [
         outcome ~n_violations:0 ~n_skipped:0 ~passed:true;
         field (fun (r : Vt.check_result) -> r.skip_reason) is_none;
       ])

(* Absent audit: every row is skipped, with a stated reason — never a bare
   PASS. *)
let test_v19_absent_audit_skips_with_reason _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          trade ~position_id:(Some "AAA-wein-1") ~symbol:"AAA"
            ~entry_date:"2021-03-08" ();
          trade ~position_id:(Some "BBB-wein-2") ~symbol:"BBB"
            ~entry_date:"2021-03-08" ();
        ];
      audit_absent = Some "trade_audit.sexp absent";
    }
  in
  assert_that
    (Vc.run_check ~id:"V19" inputs)
    (all_of
       [
         outcome ~n_violations:0 ~n_skipped:2 ~passed:true;
         field
           (fun (r : Vt.check_result) -> r.skip_reason)
           (is_some_and (equal_to "trade_audit.sexp absent"));
       ])

(* A legacy row (no position_id) has no join key: skipped, and says why. *)
let test_v19_legacy_row_skipped _ =
  let audit = Va.build_audit_lookup [] in
  let trades = [ trade ~symbol:"OLD" ~entry_date:"2021-03-08" () ] in
  assert_that
    (Vc.run_check ~id:"V19" (loaded ~trades ~audit))
    (all_of
       [
         outcome ~n_violations:0 ~n_skipped:1 ~passed:true;
         field
           (fun (r : Vt.check_result) -> r.skip_reason)
           (is_some_and (contains_substring "position_id"));
       ])

(* The skip reason reaches the rendered report line. *)
let test_v19_skip_reason_rendered _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"AAA" ~entry_date:"2021-03-08" () ];
      audit_absent = Some "trade_audit.sexp absent";
    }
  in
  let report : Vt.report =
    {
      checks = [ Vc.run_check ~id:"V19" inputs ];
      audit_join = { matched = 0; total = 1 };
    }
  in
  assert_that (Vr.render_md report)
    (contains_substring
       "V19 INVARIANT PASS (1 skipped: trade_audit.sexp absent)")

(* SHORT round trips are joined exactly like LONG ones: a matched SHORT row
   passes, an unmatched SHORT row fires. *)
let test_v19_short_rows _ =
  let audit =
    Va.build_audit_lookup
      [
        join_row ~position_id:"SSS-wein-1" ~symbol:"SSS"
          ~entry_date:"2021-03-05";
      ]
  in
  let trades =
    [
      trade ~side:"SHORT" ~position_id:(Some "SSS-wein-1") ~symbol:"SSS"
        ~entry_date:"2021-03-08" ();
      trade ~side:"SHORT" ~position_id:(Some "TTT-wein-2") ~symbol:"TTT"
        ~entry_date:"2021-03-08" ();
    ]
  in
  assert_that
    (Vc.run_check ~id:"V19" (loaded ~trades ~audit))
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
         field
           (fun (r : Vt.check_result) ->
             List.map r.specimens ~f:(fun (s : Vt.specimen) -> s.symbol))
           (equal_to [ "TTT" ]);
       ])

(* Dead join: an audit that was loaded but holds no entry matches nothing, so
   every position_id-bearing row fires — none is skipped. *)
let test_v19_dead_join_fires_on_every_keyed_row _ =
  let trades =
    [
      trade ~position_id:(Some "AAA-wein-1") ~symbol:"AAA"
        ~entry_date:"2021-03-08" ();
      trade ~position_id:(Some "BBB-wein-2") ~symbol:"BBB"
        ~entry_date:"2021-03-08" ();
      trade ~side:"SHORT" ~position_id:(Some "CCC-wein-3") ~symbol:"CCC"
        ~entry_date:"2021-03-08" ();
    ]
  in
  assert_that
    (Vc.run_check ~id:"V19" (loaded ~trades ~audit:(Va.build_audit_lookup [])))
    (outcome ~n_violations:3 ~n_skipped:0 ~passed:false)

(* ---- V20: close / ma_value basis band ---------------------------------- *)

let v20 assoc =
  let trades =
    List.map assoc ~f:(fun (symbol, _) ->
        trade ~symbol ~entry_date:"2021-04-23" ())
  in
  Vc.run_check ~id:"V20" (loaded ~trades ~audit:(audit_by_symbol assoc))

(* Firing specimen: NVDA 2021-04-23 as recorded before #2973 — raw close
   610.61 vs adjusted MA 13.67 (numbers from issue #2973, quoted in the
   [Trade_audit.entry_decision.adjusted_close_at_decision] docstring). A
   pre-#2973 file carries no adjusted close, so V20 reads the raw one. *)
let test_v20_fires_on_nvda_basis_mix _ =
  assert_that
    (v20
       [
         ("NVDA", ctx ~close_at_decision:(Some 610.61) ~ma_value:(Some 13.67) ());
       ])
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
         field
           (fun (r : Vt.check_result) -> r.specimens)
           (elements_are
              [
                field
                  (fun (s : Vt.specimen) -> s.detail)
                  (contains_substring "close_at_decision (raw) 610.61");
              ]);
       ])

(* Clean: the same decision with the #2973 adjusted close present. 15.27 is
   610.61 / 40 (NVDA's later 4:1 and 10:1 splits); V20 prefers the adjusted
   field, so the raw 610.61 riding alongside does not fire. *)
let test_v20_clean_with_adjusted_close _ =
  assert_that
    (v20
       [
         ( "NVDA",
           ctx ~close_at_decision:(Some 610.61)
             ~adjusted_close_at_decision:(Some 15.27) ~ma_value:(Some 13.67) ()
         );
       ])
    (outcome ~n_violations:0 ~n_skipped:0 ~passed:true)

(* Band edges at MA 100 (default band [0.2, 5]): the bounds themselves and
   just-inside values pass; just-outside values on either side fire. *)
let test_v20_band_boundaries _ =
  let at close =
    ctx ~adjusted_close_at_decision:(Some close) ~ma_value:(Some 100.0) ()
  in
  assert_that
    (v20
       [
         ("LO_EDGE", at 20.0);
         ("LO_IN", at 21.0);
         ("LO_OUT", at 19.0);
         ("HI_EDGE", at 500.0);
         ("HI_IN", at 499.0);
         ("HI_OUT", at 501.0);
       ])
    (all_of
       [
         outcome ~n_violations:2 ~n_skipped:0 ~passed:false;
         field
           (fun (r : Vt.check_result) ->
             List.map r.specimens ~f:(fun (s : Vt.specimen) -> s.symbol))
           (equal_to [ "LO_OUT"; "HI_OUT" ]);
       ])

(* ma_value missing or 0, or no close at all: skipped and counted, never a
   violation. *)
let test_v20_skips_unevaluable _ =
  assert_that
    (v20
       [
         ("NO_MA", ctx ~close_at_decision:(Some 610.61) ());
         ( "ZERO_MA",
           ctx ~close_at_decision:(Some 610.61) ~ma_value:(Some 0.0) () );
         ("NO_CLOSE", ctx ~ma_value:(Some 13.67) ());
       ])
    (outcome ~n_violations:0 ~n_skipped:3 ~passed:true)

(* Absent audit: V20 skips every row with the stated reason. *)
let test_v20_absent_audit_skips_with_reason _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"NVDA" ~entry_date:"2021-04-23" () ];
    }
  in
  assert_that
    (Vc.run_check ~id:"V20" inputs)
    (all_of
       [
         outcome ~n_violations:0 ~n_skipped:1 ~passed:true;
         field (fun (r : Vt.check_result) -> r.skip_reason) (is_some_and __);
       ])

(* ---- load_audit: absent vs unreadable vs empty ------------------------- *)

(* Write [contents] to a fresh temp file, run [f] on its path, then remove it. *)
let with_temp_file contents ~f =
  let path = Stdlib.Filename.temp_file "trade_audit" ".sexp" in
  Out_channel.write_all path ~data:contents;
  Exn.protect ~f:(fun () -> f path) ~finally:(fun () -> Stdlib.Sys.remove path)

let load_error m = matching ~msg:"Expected Error" Result.error m

(* No file at the path: Error, with the "absent" reason. *)
let test_load_audit_missing_is_absent _ =
  let path =
    Stdlib.Filename.concat
      (Stdlib.Filename.get_temp_dir_name ())
      "no-such-dir-3002/trade_audit.sexp"
  in
  assert_that (Va.load_audit path)
    (load_error (equal_to "trade_audit.sexp absent"))

(* A file that exists but is not a readable sexp: Error, with the
   "unreadable: <exn>" reason — distinct from "absent". *)
let test_load_audit_broken_is_unreadable _ =
  with_temp_file "((unbalanced" ~f:(fun path ->
      assert_that (Va.load_audit path)
        (load_error
           (all_of
              [
                contains_substring "trade_audit.sexp unreadable: ";
                not_ (contains_substring "absent");
              ])))

(* A valid sexp holding no parseable record: Ok of an empty lookup (a dead
   join V19 flags), not Error. *)
let test_load_audit_empty_is_ok_empty_lookup _ =
  let row =
    trade ~position_id:(Some "AAA-wein-1") ~symbol:"AAA"
      ~entry_date:"2021-03-08" ()
  in
  with_temp_file "()" ~f:(fun path ->
      assert_that (Va.load_audit path)
        (matching ~msg:"Expected Ok" Result.ok
           (field (fun lookup -> lookup row) is_none)))

(* Registration: both ids are in the report order after V18. *)
let test_registered _ =
  assert_that (List.drop Vc.all_check_ids 17) (equal_to [ "V18"; "V19"; "V20" ])

let suite =
  "validator_audit_checks"
  >::: [
         "v19 fires on missing position_id"
         >:: test_v19_fires_on_missing_position_id;
         "v19 clean" >:: test_v19_clean;
         "v19 absent audit skips with reason"
         >:: test_v19_absent_audit_skips_with_reason;
         "v19 legacy row skipped" >:: test_v19_legacy_row_skipped;
         "v19 skip reason rendered" >:: test_v19_skip_reason_rendered;
         "v19 short rows" >:: test_v19_short_rows;
         "v19 dead join fires on every keyed row"
         >:: test_v19_dead_join_fires_on_every_keyed_row;
         "load_audit missing is absent" >:: test_load_audit_missing_is_absent;
         "load_audit broken is unreadable"
         >:: test_load_audit_broken_is_unreadable;
         "load_audit empty is ok empty lookup"
         >:: test_load_audit_empty_is_ok_empty_lookup;
         "v20 fires on NVDA basis mix" >:: test_v20_fires_on_nvda_basis_mix;
         "v20 clean with adjusted close" >:: test_v20_clean_with_adjusted_close;
         "v20 band boundaries" >:: test_v20_band_boundaries;
         "v20 skips unevaluable" >:: test_v20_skips_unevaluable;
         "v20 absent audit skips with reason"
         >:: test_v20_absent_audit_skips_with_reason;
         "registered" >:: test_registered;
       ]

let () = run_test_tt_main suite
