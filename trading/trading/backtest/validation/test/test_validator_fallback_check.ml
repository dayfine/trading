(** Unit tests for V16 (fallback exits) + V17 (stale entry bars) — the
    quality-flag half of the post-run validator.

    Both encode one principle ([dev/plans/delisting-data-fix-2026-09-06.md]
    §"Principle: fallbacks are quality flags, not mechanisms"): a safety-net
    exit should never happen, and every instance is a worklist item, not a
    strategy result. So what these tests pin is mostly what does {b not} count —
    a check that flagged ordinary trades, or routine delistings, would bury the
    real defects it exists to surface. *)

open Core
open OUnit2
open Matchers
module Vt = Post_run_validator.Validator_types
module Vc = Post_run_validator.Validator_checks
module Vf = Post_run_validator.Validator_fallback_check
module Vr = Post_run_validator.Validator_report

let _trade ?(exit_trigger = "") ?(entry_date = "2020-01-03")
    ?(exit_date = "2020-06-01") ~symbol () : Vt.trade_row =
  {
    symbol;
    side = "LONG";
    entry_date = Date.of_string entry_date;
    exit_date = Date.of_string exit_date;
    entry_price = 100.0;
    exit_price = 110.0;
    quantity = 100.0;
    exit_trigger;
    stop_trigger_kind = "";
    stop_initial_distance_pct = None;
    position_id = None;
    stop_fill_distance_pct = None;
  }

let _flat_bar (d, c) : Vt.daily_bar =
  {
    date = Date.of_string d;
    open_price = c;
    high = c;
    low = c;
    close = c;
    adjusted_close = c;
    volume = 1000;
  }

let _with_daily pairs : Vt.bars =
  {
    weekly_dates = [||];
    weekly_closes = [||];
    daily = Array.of_list_map pairs ~f:_flat_bar;
  }

let _bars_of assoc sym = List.Assoc.find assoc sym ~equal:String.equal
let _result ~id inputs = Vc.run_check ~id (inputs : Vt.inputs)

let _violations_and_pass n_viol passed =
  all_of
    [
      field (fun (r : Vt.check_result) -> r.n_violations) (equal_to n_viol);
      field (fun (r : Vt.check_result) -> r.passed) (equal_to passed);
    ]

(* ---- V16 --------------------------------------------------------------- *)

(** The motivating mix: one [stale_force_exit] and one [margin_call] are both
    fallbacks and both counted; the ordinary [stop_loss] alongside them is not.
    Two findings, count two. *)
let test_v16_counts_each_fallback_exit _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          _trade ~symbol:"WLL1" ~exit_trigger:"stale_force_exit" ();
          _trade ~symbol:"LEVERED" ~exit_trigger:"margin_call" ();
          _trade ~symbol:"NORMAL" ~exit_trigger:"stop_loss" ();
        ];
    }
  in
  assert_that (_result ~id:"V16" inputs) (_violations_and_pass 2 false)

(** A run whose every exit came from a strategy rule passes with nothing to
    report — the target state. *)
let test_v16_passes_a_run_with_no_fallbacks _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          _trade ~symbol:"A" ~exit_trigger:"stop_loss" ();
          _trade ~symbol:"B" ~exit_trigger:"stage3_force_exit" ();
          _trade ~symbol:"C" ~exit_trigger:"end_of_period" ();
        ];
    }
  in
  assert_that (_result ~id:"V16" inputs) (_violations_and_pass 0 true)

(** {b The load-bearing exclusion.} A ["delisted"] exit is an EXPECTED corporate
    action — since {!Trading_simulation.Delisted_exit_runner} the marked case
    never reaches the stale net at all. Counting it would bury the real defects
    under routine delistings, which is the failure this whole check exists to
    end. *)
let test_v16_does_not_count_a_delisted_exit _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"AZPN" ~exit_trigger:"delisted" () ];
    }
  in
  assert_that (_result ~id:"V16" inputs) (_violations_and_pass 0 true)

(** Every fallback label in the default list is recognised. Written as one trade
    per label so a label silently dropped from the default shows up as a count,
    not as a pass. *)
let test_v16_recognises_every_default_fallback_label _ =
  let labels = (Vt.default_config : Vt.check_config).fallback_exit_labels in
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        List.mapi labels ~f:(fun i label ->
            _trade ~symbol:(sprintf "S%d" i) ~exit_trigger:label ());
    }
  in
  assert_that (_result ~id:"V16" inputs)
    (_violations_and_pass (List.length labels) false)

(** The specimen names the trigger and both dates, so a reader can chase the row
    in the warehouse without re-running the backtest. *)
let test_v16_specimen_names_the_trigger_and_dates _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          _trade ~symbol:"CY" ~exit_trigger:"stale_force_exit"
            ~entry_date:"2020-04-18" ~exit_date:"2020-04-20" ();
        ];
    }
  in
  assert_that (_result ~id:"V16" inputs)
    (field
       (fun (r : Vt.check_result) -> r.specimens)
       (elements_are
          [
            all_of
              [
                field (fun (s : Vt.specimen) -> s.symbol) (equal_to "CY");
                field
                  (fun (s : Vt.specimen) -> s.entry_date)
                  (equal_to "2020-04-18");
                field
                  (fun (s : Vt.specimen) ->
                    String.is_prefix s.detail ~prefix:"stale_force_exit exit ")
                  (equal_to true);
              ];
          ]))

(** The count the [QUALITY-FLAG] line reads. Zero prints nothing at all, so the
    line's presence in a log is itself the signal. *)
let test_quality_flag_line_reports_the_v16_count _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          _trade ~symbol:"WLL1" ~exit_trigger:"stale_force_exit" ();
          _trade ~symbol:"LEVERED" ~exit_trigger:"buyin_stress" ();
        ];
    }
  in
  assert_that
    (Vr.quality_flag_line (Vc.validate inputs))
    (is_some_and (equal_to "QUALITY-FLAG: 2 fallback exits (V16)"))

(** ...and a clean run yields no line. *)
let test_quality_flag_line_is_absent_when_clean _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"A" ~exit_trigger:"stop_loss" () ];
    }
  in
  assert_that (Vr.quality_flag_line (Vc.validate inputs)) is_none

(** The count helper reads [0] off a report where V16 was disabled, rather than
    raising or inventing a number. *)
let test_fallback_exit_count_is_zero_when_v16_disabled _ =
  let config = { Vt.default_config with disabled_checks = [ "V16" ] } in
  let inputs =
    {
      (Vt.empty_inputs ~config ()) with
      trades = [ _trade ~symbol:"WLL1" ~exit_trigger:"stale_force_exit" () ];
    }
  in
  assert_that (Vf.fallback_exit_count (Vc.validate inputs)) (equal_to 0)

(* ---- V17 --------------------------------------------------------------- *)

(** The motivating specimen, on its {b real} dates: the canonical 26y record
    entered CY on 2020-04-18 and again on 2020-04-25 against a series whose last
    bar is 2020-04-15. At the default [stale_entry_days = 7] the two split — the
    first is 3 days stale (an ordinary long weekend, so it passes), the second
    is 10 days stale and is reported. Exactly one violation, and it is the
    second entry. *)
let test_v17_flags_the_second_cy_entry_at_the_default _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades =
        [
          _trade ~symbol:"CY" ~entry_date:"2020-04-18" ();
          _trade ~symbol:"CY" ~entry_date:"2020-04-25" ();
        ];
      bars =
        _bars_of
          [
            ("CY", _with_daily [ ("2020-04-14", 23.8); ("2020-04-15", 23.82) ]);
          ];
    }
  in
  assert_that (_result ~id:"V17" inputs)
    (all_of
       [
         field (fun (r : Vt.check_result) -> r.n_violations) (equal_to 1);
         field (fun (r : Vt.check_result) -> r.passed) (equal_to false);
         field
           (fun (r : Vt.check_result) -> r.specimens)
           (elements_are
              [
                field
                  (fun (s : Vt.specimen) -> s.entry_date)
                  (equal_to "2020-04-25");
              ]);
       ])

(** The comparison is strict, and deliberately so: a gap of exactly
    [stale_entry_days] passes. 2020-04-22 against a last bar of 2020-04-15 is 7
    days — the boundary — and must not be reported, or the default would sit
    {e on} the specimen it was chosen to stay below rather than under it. *)
let test_v17_passes_a_gap_exactly_at_the_threshold _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"CY" ~entry_date:"2020-04-22" () ];
      bars = _bars_of [ ("CY", _with_daily [ ("2020-04-15", 23.82) ]) ];
    }
  in
  assert_that (_result ~id:"V17" inputs) (_violations_and_pass 0 true)

(** An entry filled on a bar the symbol actually printed passes — the ordinary
    case, which must not flag or the check is noise. *)
let test_v17_passes_a_fill_on_a_live_bar _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"LIVE" ~entry_date:"2020-01-03" () ];
      bars =
        _bars_of
          [
            ( "LIVE",
              _with_daily [ ("2020-01-02", 100.0); ("2020-01-03", 101.0) ] );
          ];
    }
  in
  assert_that (_result ~id:"V17" inputs) (_violations_and_pass 0 true)

(** The threshold is config, not a constant: the same 3-day-stale entry that
    passes at the default flags at [stale_entry_days = 2]. *)
let test_v17_threshold_comes_from_config _ =
  let config = { Vt.default_config with stale_entry_days = 2 } in
  let inputs =
    {
      (Vt.empty_inputs ~config ()) with
      trades = [ _trade ~symbol:"CY" ~entry_date:"2020-04-18" () ];
      bars = _bars_of [ ("CY", _with_daily [ ("2020-04-15", 23.82) ]) ];
    }
  in
  assert_that (_result ~id:"V17" inputs) (_violations_and_pass 1 false)

(** A symbol absent from the bar store is un-evaluable, so it is skipped rather
    than flagged — the skip count measures what the check could not read. *)
let test_v17_skips_a_symbol_with_no_bars _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"GHOST" ~entry_date:"2020-01-03" () ];
    }
  in
  assert_that (_result ~id:"V17" inputs)
    (all_of
       [
         field (fun (r : Vt.check_result) -> r.n_skipped) (equal_to 1);
         field (fun (r : Vt.check_result) -> r.passed) (equal_to true);
       ])

(** Every stored bar postdating the entry is also un-evaluable: there is no
    "most recent bar at or before the fill" to age. Skip, not flag. *)
let test_v17_skips_when_every_bar_postdates_the_entry _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"LATE" ~entry_date:"2020-01-03" () ];
      bars = _bars_of [ ("LATE", _with_daily [ ("2020-02-03", 50.0) ]) ];
    }
  in
  assert_that (_result ~id:"V17" inputs)
    (field (fun (r : Vt.check_result) -> r.n_skipped) (equal_to 1))

let suite =
  "validator_fallback_check"
  >::: [
         "v16 counts each fallback exit" >:: test_v16_counts_each_fallback_exit;
         "v16 passes a run with no fallbacks"
         >:: test_v16_passes_a_run_with_no_fallbacks;
         "v16 does not count a delisted exit"
         >:: test_v16_does_not_count_a_delisted_exit;
         "v16 recognises every default fallback label"
         >:: test_v16_recognises_every_default_fallback_label;
         "v16 specimen names the trigger and dates"
         >:: test_v16_specimen_names_the_trigger_and_dates;
         "quality flag line reports the v16 count"
         >:: test_quality_flag_line_reports_the_v16_count;
         "quality flag line is absent when clean"
         >:: test_quality_flag_line_is_absent_when_clean;
         "fallback exit count is zero when v16 disabled"
         >:: test_fallback_exit_count_is_zero_when_v16_disabled;
         "v17 flags the second cy entry at the default"
         >:: test_v17_flags_the_second_cy_entry_at_the_default;
         "v17 passes a gap exactly at the threshold"
         >:: test_v17_passes_a_gap_exactly_at_the_threshold;
         "v17 passes a fill on a live bar"
         >:: test_v17_passes_a_fill_on_a_live_bar;
         "v17 threshold comes from config"
         >:: test_v17_threshold_comes_from_config;
         "v17 skips a symbol with no bars"
         >:: test_v17_skips_a_symbol_with_no_bars;
         "v17 skips when every bar postdates the entry"
         >:: test_v17_skips_when_every_bar_postdates_the_entry;
       ]

let () = run_test_tt_main suite
