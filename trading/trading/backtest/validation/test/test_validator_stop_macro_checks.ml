(** Tests for V21 (installed vs screener proxy stop) and V23 (macro-gate bypass
    at fill) — issue #3002 part B ({!Post_run_validator.Validator_audit_checks})
    — plus the artifact plumbing they need: the proxy stop and the per-screen
    macro reads from [trade_audit.sexp], and the run's
    [entry_ticket_macro_suspend] from [params.sexp]
    ({!Post_run_validator.Validator_run_config}). *)

open Core
open OUnit2
open Matchers
module Vt = Post_run_validator.Validator_types
module Vc = Post_run_validator.Validator_checks
module Va = Post_run_validator.Validator_artifacts
module Vr = Post_run_validator.Validator_report
module Rc = Post_run_validator.Validator_run_config
module Mode = Weinstein_strategy.Entry_ticket_suspend_mode

(* ---- builders ---------------------------------------------------------- *)

let trade ?(side = "LONG") ~symbol ~entry_date () : Vt.trade_row =
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
    position_id = None;
    stop_fill_distance_pct = None;
  }

let ctx ~installed_stop ~screener_proxy_stop : Vt.entry_context =
  {
    stage = Weinstein_types.Stage2 { weeks_advancing = 3; late = false };
    macro_trend = Weinstein_types.Bullish;
    ma_direction = Weinstein_types.Rising;
    resistance_quality = None;
    installed_stop;
    screener_proxy_stop;
    suggested_entry = 100.0;
    decision_bar = Vt.no_decision_bar;
  }

let audit_by_symbol assoc (row : Vt.trade_row) =
  List.Assoc.find assoc row.symbol ~equal:String.equal

(* Inputs with a loaded audit (audit_absent = None). *)
let loaded ?(screens = []) ?(audit = []) ?macro_suspend ?config trades =
  {
    (Vt.empty_inputs ?config ()) with
    trades;
    audit = audit_by_symbol audit;
    audit_absent = None;
    screens;
    macro_suspend;
  }

let outcome ~n_violations ~n_skipped ~passed =
  all_of
    [
      field
        (fun (r : Vt.check_result) -> r.n_violations)
        (equal_to n_violations);
      field (fun (r : Vt.check_result) -> r.n_skipped) (equal_to n_skipped);
      field (fun (r : Vt.check_result) -> r.passed) (equal_to passed);
    ]

let specimen_symbols =
  field (fun (r : Vt.check_result) ->
      List.map r.specimens ~f:(fun (s : Vt.specimen) -> s.symbol))

let skip_reason m = field (fun (r : Vt.check_result) -> r.skip_reason) m
let severity m = field (fun (r : Vt.check_result) -> r.severity) m

(* ---- V21: installed stop tighter than the screener proxy stop ---------- *)

(* The #2975 specimen (EQT, pinned in
   [weinstein/strategy/test/test_entry_audit_capture.ml]
   [test_buffer_fallback_installed_stop_ignores_screener_proxy]): E = 23.36,
   screener proxy E * 0.92 = 21.4912, installed Buffer_fallback stop
   E * 0.96 = 22.4256 — 0.9344 / 21.4912 = 4.35% tighter > the 3% default. *)
let eqt = ctx ~installed_stop:22.4256 ~screener_proxy_stop:(Some 21.4912)

let test_v21_fires_on_2975_specimen _ =
  let inputs =
    loaded
      ~audit:[ ("EQT", eqt) ]
      [ trade ~symbol:"EQT" ~entry_date:"2021-03-08" () ]
  in
  assert_that
    (Vc.run_check ~id:"V21" inputs)
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
         severity (equal_to Vt.Expectation);
         field
           (fun (r : Vt.check_result) ->
             List.map r.specimens ~f:(fun (s : Vt.specimen) -> s.detail))
           (elements_are
              [
                all_of
                  [
                    contains_substring "LONG installed_stop 22.4256";
                    contains_substring "screener_proxy_stop 21.4912";
                    contains_substring "4.35% tighter";
                  ];
              ]);
       ])

(* Clean: a support-floor stop within 1% of the proxy, on the tight side. *)
let test_v21_clean _ =
  let inputs =
    loaded
      ~audit:
        [ ("OK", ctx ~installed_stop:92.5 ~screener_proxy_stop:(Some 92.0)) ]
      [ trade ~symbol:"OK" ~entry_date:"2021-03-08" () ]
  in
  assert_that
    (Vc.run_check ~id:"V21" inputs)
    (outcome ~n_violations:0 ~n_skipped:0 ~passed:true)

(* A stop LOOSER than the proxy by the EQT distance (0.9344, 4.35% of the proxy)
   never fires: LONG below the proxy, SHORT above it — more risk per share, so
   a smaller position. Nor does a far looser LONG support floor (the usual case:
   base low well under 8%). *)
let test_v21_looser_does_not_fire _ =
  let proxy = Some 21.4912 in
  let audit =
    [
      ( "L_LOOSE",
        ctx ~installed_stop:(21.4912 -. 0.9344) ~screener_proxy_stop:proxy );
      ( "S_LOOSE",
        ctx ~installed_stop:(21.4912 +. 0.9344) ~screener_proxy_stop:proxy );
      ("DEEP_FLOOR", ctx ~installed_stop:50.0 ~screener_proxy_stop:(Some 92.0));
    ]
  in
  let trades =
    [
      trade ~symbol:"L_LOOSE" ~entry_date:"2021-03-08" ();
      trade ~side:"SHORT" ~symbol:"S_LOOSE" ~entry_date:"2021-03-08" ();
      trade ~symbol:"DEEP_FLOOR" ~entry_date:"2021-03-08" ();
    ]
  in
  assert_that
    (Vc.run_check ~id:"V21" (loaded ~audit trades))
    (outcome ~n_violations:0 ~n_skipped:0 ~passed:true)

(* Strict threshold on the tight side only. LONG, proxy 100: 103.0 (exactly 3%
   tighter) passes, 103.1 fires; 96.9 (3.1% looser) passes. *)
let test_v21_long_boundaries _ =
  let at installed =
    ctx ~installed_stop:installed ~screener_proxy_stop:(Some 100.0)
  in
  let audit =
    [
      ("TIGHT_AT", at 103.0); ("TIGHT_PAST", at 103.1); ("LOOSE_PAST", at 96.9);
    ]
  in
  let trades =
    List.map audit ~f:(fun (symbol, _) ->
        trade ~symbol ~entry_date:"2021-03-08" ())
  in
  assert_that
    (Vc.run_check ~id:"V21" (loaded ~audit trades))
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
         specimen_symbols (equal_to [ "TIGHT_PAST" ]);
       ])

(* The denominator is the proxy, not E (4.00%) or the installed stop (4.17%):
   EQT's 4.348% tightening fires at a 4.25% threshold and passes at 4.35%. *)
let test_v21_denominator_is_proxy _ =
  let run pct =
    let config =
      { Vt.default_config with installed_tighter_than_proxy_max_pct = pct }
    in
    (Vc.run_check ~id:"V21"
       (loaded ~config
          ~audit:[ ("EQT", eqt) ]
          [ trade ~symbol:"EQT" ~entry_date:"2021-03-08" () ]))
      .n_violations
  in
  assert_that (run 0.0425, run 0.0435) (equal_to (1, 0))

(* SHORT mirror: a short's proxy sits ABOVE E ([entry * (1 + short_stop_pct)]),
   so tighter = lower. Proxy 100: 97.0 (exactly 3% tighter) passes, 96.9 fires,
   and 103.1 (3.1% looser, above the proxy) passes — the LONG reading of the
   same numbers (see the boundaries test) flags 103.1 and passes 96.9. *)
let test_v21_short_mirror _ =
  let at installed =
    ctx ~installed_stop:installed ~screener_proxy_stop:(Some 100.0)
  in
  let audit =
    [
      ("S_TIGHT_AT", at 97.0); ("S_TIGHT_PAST", at 96.9); ("S_LOOSE", at 103.1);
    ]
  in
  let trades =
    List.map audit ~f:(fun (symbol, _) ->
        trade ~side:"SHORT" ~symbol ~entry_date:"2021-03-08" ())
  in
  assert_that
    (Vc.run_check ~id:"V21" (loaded ~audit trades))
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
         specimen_symbols (equal_to [ "S_TIGHT_PAST" ]);
       ])

(* Each un-evaluable shape is skipped and counted, never a violation — even
   where the values would fire if read (legacy 0.0 vs a proxy of 92). *)
let test_v21_skips_unevaluable _ =
  let audit =
    [
      ("LEGACY", ctx ~installed_stop:0.0 ~screener_proxy_stop:(Some 92.0));
      ("NO_PROXY", ctx ~installed_stop:50.0 ~screener_proxy_stop:None);
      ("ZERO_PROXY", ctx ~installed_stop:50.0 ~screener_proxy_stop:(Some 0.0));
    ]
  in
  let trades =
    List.map [ "LEGACY"; "NO_PROXY"; "ZERO_PROXY"; "NO_AUDIT" ]
      ~f:(fun symbol -> trade ~symbol ~entry_date:"2021-03-08" ())
  in
  assert_that
    (Vc.run_check ~id:"V21" (loaded ~audit trades))
    (all_of
       [
         outcome ~n_violations:0 ~n_skipped:4 ~passed:true;
         skip_reason (is_some_and (contains_substring "screener_proxy_stop"));
       ])

(* No audit loaded: every row skipped with the load reason. *)
let test_v21_absent_audit_skips_with_reason _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"EQT" ~entry_date:"2021-03-08" () ];
      audit = audit_by_symbol [ ("EQT", eqt) ];
      audit_absent = Some "trade_audit.sexp absent";
    }
  in
  assert_that
    (Vc.run_check ~id:"V21" inputs)
    (all_of
       [
         outcome ~n_violations:0 ~n_skipped:1 ~passed:true;
         skip_reason (is_some_and (equal_to "trade_audit.sexp absent"));
       ])

(* ---- V23: long fill after a Bearish screen ----------------------------- *)

let screen date trend : Vt.screen_read =
  { screen_date = Date.of_string date; screen_macro_trend = trend }

(* The #2976 shape (26y walkthrough: 103 of 724 fills landed after a Bearish
   screen, from tickets placed in a Bullish/Neutral tape): placed on the
   Bullish 2020-02-21 screen, the tape reads Bearish on 2020-02-28, and the
   ticket still fills on 2020-03-02. *)
let feb_2020 =
  [
    screen "2020-02-21" Weinstein_types.Bullish;
    screen "2020-02-28" Weinstein_types.Bearish;
  ]

let test_v23_fires_on_2976_shape _ =
  let inputs =
    loaded ~screens:feb_2020 [ trade ~symbol:"TKT" ~entry_date:"2020-03-02" () ]
  in
  assert_that
    (Vc.run_check ~id:"V23" inputs)
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
         field
           (fun (r : Vt.check_result) ->
             List.map r.specimens ~f:(fun (s : Vt.specimen) -> s.detail))
           (elements_are
              [
                equal_to
                  "filled 2020-03-02 after the 2020-02-28 screen read Bearish";
              ]);
       ])

(* Clean: filled after the Bullish placement screen and before the Bearish
   one — only a screen strictly before the fill counts. *)
let test_v23_clean _ =
  let inputs =
    loaded ~screens:feb_2020 [ trade ~symbol:"TKT" ~entry_date:"2020-02-24" () ]
  in
  assert_that
    (Vc.run_check ~id:"V23" inputs)
    (outcome ~n_violations:0 ~n_skipped:0 ~passed:true)

(* A fill dated on the Bearish screen Friday traded before that screen ran
   (the screen is at the close), so the Bullish 02-21 screen governs it. *)
let test_v23_same_day_screen_does_not_count _ =
  let inputs =
    loaded ~screens:feb_2020 [ trade ~symbol:"TKT" ~entry_date:"2020-02-28" () ]
  in
  assert_that
    (Vc.run_check ~id:"V23" inputs)
    (outcome ~n_violations:0 ~n_skipped:0 ~passed:true)

(* The LATEST screen before the fill decides, whatever order the screens are
   supplied in: a Bearish read two weeks back that has since cleared passes; a
   Bullish read two weeks back since turned Bearish fires. *)
let test_v23_latest_screen_decides _ =
  let screens =
    [
      screen "2020-03-06" Weinstein_types.Bearish;
      screen "2020-02-21" Weinstein_types.Bearish;
      screen "2020-02-28" Weinstein_types.Neutral;
      screen "2020-02-14" Weinstein_types.Bullish;
    ]
  in
  let trades =
    [
      trade ~symbol:"CLEARED" ~entry_date:"2020-03-02" ();
      trade ~symbol:"TURNED" ~entry_date:"2020-03-09" ();
    ]
  in
  assert_that
    (Vc.run_check ~id:"V23" (loaded ~screens trades))
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
         specimen_symbols (equal_to [ "TURNED" ]);
       ])

(* SHORT rows are out of V23's population: neither a violation nor a skip,
   even after a Bearish screen. *)
let test_v23_short_rows_not_evaluated _ =
  let inputs =
    loaded ~screens:feb_2020
      [ trade ~side:"SHORT" ~symbol:"SHRT" ~entry_date:"2020-03-02" () ]
  in
  assert_that
    (Vc.run_check ~id:"V23" inputs)
    (outcome ~n_violations:0 ~n_skipped:0 ~passed:true)

(* A long filled before the first recorded screen has nothing to read. *)
let test_v23_fill_before_first_screen_skipped _ =
  let inputs =
    loaded ~screens:feb_2020
      [ trade ~symbol:"EARLY" ~entry_date:"2020-02-18" () ]
  in
  assert_that
    (Vc.run_check ~id:"V23" inputs)
    (all_of
       [
         outcome ~n_violations:0 ~n_skipped:1 ~passed:true;
         skip_reason (is_some_and (contains_substring "first recorded screen"));
       ])

(* Audit loaded but no cascade summaries: every long skipped, with a reason
   distinct from the absent-audit one. *)
let test_v23_no_screens_skips_with_reason _ =
  let trades =
    [
      trade ~symbol:"A" ~entry_date:"2020-03-02" ();
      trade ~symbol:"B" ~entry_date:"2020-03-02" ();
      trade ~side:"SHORT" ~symbol:"S" ~entry_date:"2020-03-02" ();
    ]
  in
  assert_that
    (Vc.run_check ~id:"V23" (loaded trades))
    (all_of
       [
         outcome ~n_violations:0 ~n_skipped:2 ~passed:true;
         skip_reason
           (is_some_and
              (equal_to "trade_audit.sexp carries no cascade_summaries"));
       ])

(* No audit loaded: every long skipped with the load reason — even when a
   screens list is (inconsistently) supplied. *)
let test_v23_absent_audit_skips_with_reason _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade ~symbol:"TKT" ~entry_date:"2020-03-02" () ];
      screens = feb_2020;
      audit_absent = Some "trade_audit.sexp absent";
    }
  in
  assert_that
    (Vc.run_check ~id:"V23" inputs)
    (all_of
       [
         outcome ~n_violations:0 ~n_skipped:1 ~passed:true;
         skip_reason (is_some_and (equal_to "trade_audit.sexp absent"));
       ])

(* ---- V23 severity: the run's entry_ticket_macro_suspend ---------------- *)

let v23_severity ?config macro_suspend =
  (Vc.run_check ~id:"V23"
     (loaded ?config ?macro_suspend ~screens:feb_2020
        [ trade ~symbol:"TKT" ~entry_date:"2020-03-02" () ]))
    .severity

let test_v23_severity_follows_macro_suspend _ =
  assert_that
    [
      v23_severity (Some Mode.On_bearish_macro);
      v23_severity (Some Mode.Off);
      v23_severity (Some Mode.On_index_stage4);
      v23_severity None;
    ]
    (equal_to [ Vt.Invariant; Vt.Expectation; Vt.Expectation; Vt.Expectation ])

(* [severity_overrides] beats the config-derived default in both directions. *)
let test_v23_severity_override_wins _ =
  let with_override sev =
    { Vt.default_config with severity_overrides = [ ("V23", sev) ] }
  in
  assert_that
    ( v23_severity ~config:(with_override "INVARIANT") None,
      v23_severity
        ~config:(with_override "EXPECTATION")
        (Some Mode.On_bearish_macro) )
    (equal_to (Vt.Invariant, Vt.Expectation))

(* ---- Validator_run_config: params.sexp -> entry_ticket_macro_suspend --- *)

let params s = Rc.macro_suspend_of_params (Sexp.of_string s)

let test_params_default_without_override _ =
  assert_that
    ( params "((code_version abc) (start_date 2020-01-02))",
      params "((code_version abc) (overrides (((initial_stop_buffer 1.02)))))"
    )
    (equal_to (Some Mode.Off, Some Mode.Off))

let test_params_override_read _ =
  assert_that
    (params
       "((code_version abc) (overrides (((initial_stop_buffer 1.02)) \
        ((entry_ticket_macro_suspend On_bearish_macro)))))")
    (equal_to (Some Mode.On_bearish_macro))

(* Overlays deep-merge left to right, so the last one naming the knob wins. *)
let test_params_last_overlay_wins _ =
  assert_that
    ( params
        "((overrides (((entry_ticket_macro_suspend On_bearish_macro)) \
         ((entry_ticket_macro_suspend On_index_stage4)) ((ma_period 40)))))",
      params
        "((overrides (((entry_ticket_macro_suspend Off)) \
         ((entry_ticket_macro_suspend On_bearish_macro)))))" )
    (equal_to (Some Mode.On_index_stage4, Some Mode.On_bearish_macro))

(* An unparseable value is unknown, not a guess. *)
let test_params_bad_value_is_unknown _ =
  assert_that
    (params "((overrides (((entry_ticket_macro_suspend Sometimes)))))")
    is_none

(* Write [contents] to a fresh temp file, run [f] on its path, then remove it. *)
let with_temp_file ?(suffix = ".sexp") contents ~f =
  let path = Stdlib.Filename.temp_file "validator" suffix in
  Out_channel.write_all path ~data:contents;
  Exn.protect ~f:(fun () -> f path) ~finally:(fun () -> Stdlib.Sys.remove path)

let test_load_macro_suspend_file_modes _ =
  let missing =
    Stdlib.Filename.concat
      (Stdlib.Filename.get_temp_dir_name ())
      "no-such-dir-3002b/params.sexp"
  in
  let read s = with_temp_file s ~f:Rc.load_macro_suspend in
  assert_that
    ( Rc.load_macro_suspend missing,
      read "((unbalanced",
      read "((overrides (((entry_ticket_macro_suspend On_bearish_macro)))))" )
    (equal_to (None, None, Some Mode.On_bearish_macro))

(* ---- load_audit: proxy stop + screens off real-shaped files ------------ *)

(* A pre-#2975 record literal, trimmed from a real artefact
   ([dev/warmup-fix-runs/after-fix1-stop-log/bull-2019h2/trade_audit.sexp],
   AAPL 2019-06-21) — the same literal
   [backtest/test/test_trade_audit.ml] pins the legacy-key codec with. The
   proxy is under the legacy key [suggested_stop]. *)
let legacy_record =
  {|((entry
     ((symbol AAPL) (entry_date 2019-06-21) (position_id AAPL-wein-61)
      (macro_trend Bullish) (macro_confidence 1) (macro_indicators ())
      (stage (Stage2 (weeks_advancing 1) (late false))) (ma_direction Rising)
      (ma_slope_pct 0.017967958275741824) (rs_trend ()) (rs_value ())
      (volume_quality ((Adequate 1.7052120350790312))) (volume_ratio (1.71))
      (resistance_quality (Clean)) (support_quality (Virgin_territory))
      (sector_name "Information Technology") (sector_rating Strong)
      (cascade_score 65) (cascade_grade B) (cascade_score_components ())
      (cascade_rationale ("Adequate volume"))
      (side Long) (suggested_entry 211.17) (suggested_stop 194.2764)
      (installed_stop 163.4592) (stop_floor_kind Support_floor)
      (risk_pct 0.079999999999999974) (initial_position_value 130291.89)
      (initial_risk_dollars 29437.563599999987)
      (alternatives_considered ())))
    (exit_ ()))|}

let current_record =
  String.substr_replace_all legacy_record ~pattern:"suggested_stop"
    ~with_:"screener_proxy_stop"

let summary date trend =
  sprintf
    "((date %s) (total_stocks 10) (candidates_after_held 10) (macro_trend %s) \
     (long_macro_admitted 0) (long_breakout_admitted 0) (long_sector_admitted \
     0) (long_grade_admitted 0) (long_top_n_admitted 0) (short_macro_admitted \
     0) (short_breakdown_admitted 0) (short_sector_admitted 0) \
     (short_rs_hard_gate_admitted 0) (short_grade_admitted 0) \
     (short_top_n_admitted 0) (entered 0))"
    date trend

let blob ~record ~summaries =
  sprintf "((audit_records (%s)) (cascade_summaries (%s)))" record
    (String.concat ~sep:" " summaries)

let aapl = trade ~symbol:"AAPL" ~entry_date:"2019-06-21" ()

let proxy_of_loaded =
  field
    (fun (a : Va.loaded_audit) ->
      Option.bind (a.lookup aapl) ~f:(fun (c : Vt.entry_context) ->
          c.screener_proxy_stop))
    (is_some_and (float_equal 194.2764))

(* Both key spellings populate [screener_proxy_stop]; the blob's cascade
   summaries become screens, the bare legacy list yields none. *)
let test_load_audit_reads_proxy_and_screens _ =
  let load s = with_temp_file s ~f:Va.load_audit in
  let ok m = matching ~msg:"Expected Ok" Result.ok m in
  let screens =
    field (fun (a : Va.loaded_audit) ->
        List.map a.screens ~f:(fun (s : Vt.screen_read) ->
            (Date.to_string s.screen_date, s.screen_macro_trend)))
  in
  assert_that
    ( load ("(" ^ legacy_record ^ ")"),
      load
        (blob ~record:current_record
           ~summaries:
             [ summary "2019-06-14" "Bullish"; summary "2019-06-21" "Bearish" ])
    )
    (all_of
       [
         field fst (ok (all_of [ proxy_of_loaded; screens (size_is 0) ]));
         field snd
           (ok
              (all_of
                 [
                   proxy_of_loaded;
                   screens
                     (equal_to
                        [
                          ("2019-06-14", Weinstein_types.Bullish);
                          ("2019-06-21", Weinstein_types.Bearish);
                        ]);
                 ]));
       ])

(* ---- end to end: Validator_report.run over a run directory ------------- *)

(* A 21-cell trades.csv row: symbol, side, entry/exit dates, prices, qty; the
   rest blank (legacy-compatible). *)
let trades_csv rows =
  let row (symbol, entry_date) =
    sprintf "%s,LONG,%s,2020-06-01,,100,110,10,,,,,,,,,,,,," symbol entry_date
  in
  String.concat ~sep:"\n" ("header" :: List.map rows ~f:row) ^ "\n"

(* Remove [path] and, for a directory, everything under it. The bar loader
   creates per-symbol subdirectories under the data dir, so this is recursive. *)
let rec remove_tree path =
  if Stdlib.Sys.is_directory path then (
    Array.iter (Stdlib.Sys.readdir path) ~f:(fun n ->
        remove_tree (Stdlib.Filename.concat path n));
    Stdlib.Sys.rmdir path)
  else Stdlib.Sys.remove path

let with_run_dir files ~f =
  let dir = Stdlib.Filename.temp_dir "validator_run" "" in
  List.iter files ~f:(fun (name, data) ->
      Out_channel.write_all (Stdlib.Filename.concat dir name) ~data);
  let out = Stdlib.Filename.concat dir "report" in
  Exn.protect ~f:(fun () -> f ~dir ~out) ~finally:(fun () -> remove_tree dir)

let find_check id (report : Vt.report) =
  List.find report.checks ~f:(fun (c : Vt.check_result) -> String.equal c.id id)

(* params.sexp arms On_bearish_macro and the audit blob's screens read Bearish
   on 2020-02-28: the fill on 2020-03-02 fires V23 as an INVARIANT, and the
   fill on 2020-02-24 passes — the wiring from the run directory. *)
let test_report_run_wires_params_and_screens _ =
  let files =
    [
      ("trades.csv", trades_csv [ ("TKT", "2020-03-02"); ("OK", "2020-02-24") ]);
      ( "trade_audit.sexp",
        blob ~record:current_record
          ~summaries:
            [ summary "2020-02-21" "Bullish"; summary "2020-02-28" "Bearish" ]
      );
      ( "params.sexp",
        "((code_version abc) (overrides (((entry_ticket_macro_suspend \
         On_bearish_macro)))))" );
    ]
  in
  let report =
    with_run_dir files ~f:(fun ~dir ~out ->
        Vr.run ~run_dir:dir ~data_dir:dir ~config:Vt.default_config ~out ())
  in
  assert_that (find_check "V23" report)
    (is_some_and
       (all_of
          [
            outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
            severity (equal_to Vt.Invariant);
            specimen_symbols (equal_to [ "TKT" ]);
          ]))

let suite =
  "validator_stop_macro_checks"
  >::: [
         "v21 fires on #2975 specimen" >:: test_v21_fires_on_2975_specimen;
         "v21 clean" >:: test_v21_clean;
         "v21 looser does not fire" >:: test_v21_looser_does_not_fire;
         "v21 long boundaries" >:: test_v21_long_boundaries;
         "v21 denominator is proxy" >:: test_v21_denominator_is_proxy;
         "v21 short mirror" >:: test_v21_short_mirror;
         "v21 skips unevaluable" >:: test_v21_skips_unevaluable;
         "v21 absent audit skips with reason"
         >:: test_v21_absent_audit_skips_with_reason;
         "v23 fires on #2976 shape" >:: test_v23_fires_on_2976_shape;
         "v23 clean" >:: test_v23_clean;
         "v23 same-day screen does not count"
         >:: test_v23_same_day_screen_does_not_count;
         "v23 latest screen decides" >:: test_v23_latest_screen_decides;
         "v23 short rows not evaluated" >:: test_v23_short_rows_not_evaluated;
         "v23 fill before first screen skipped"
         >:: test_v23_fill_before_first_screen_skipped;
         "v23 no screens skips with reason"
         >:: test_v23_no_screens_skips_with_reason;
         "v23 absent audit skips with reason"
         >:: test_v23_absent_audit_skips_with_reason;
         "v23 severity follows macro_suspend"
         >:: test_v23_severity_follows_macro_suspend;
         "v23 severity override wins" >:: test_v23_severity_override_wins;
         "params default without override"
         >:: test_params_default_without_override;
         "params override read" >:: test_params_override_read;
         "params last overlay wins" >:: test_params_last_overlay_wins;
         "params bad value is unknown" >:: test_params_bad_value_is_unknown;
         "load_macro_suspend file modes" >:: test_load_macro_suspend_file_modes;
         "load_audit reads proxy and screens"
         >:: test_load_audit_reads_proxy_and_screens;
         "report run wires params and screens"
         >:: test_report_run_wires_params_and_screens;
       ]

let () = run_test_tt_main suite
