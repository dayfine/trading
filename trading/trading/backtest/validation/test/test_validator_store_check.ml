(** Unit tests for V18 (implausible stored series) — the store-sanity check
    derived from issue #2732's MEL specimen.

    V18's whole risk is false positives: it judges a symbol's entire series
    rather than one decision, so a rule that is even slightly too eager buries
    the real defects under ordinary instruments. Most of what these tests pin is
    therefore what must {b not} flag — a >90% move that actually traded, and an
    ordinary series — plus the one false positive that is accepted {i by design}
    (a legitimately high-priced instrument) and its config escape hatch. *)

open Core
open OUnit2
open Matchers
module Vt = Post_run_validator.Validator_types
module Vc = Post_run_validator.Validator_checks

let _trade ?(entry_date = "2017-01-30") ~symbol () : Vt.trade_row =
  {
    symbol;
    side = "LONG";
    entry_date = Date.of_string entry_date;
    exit_date = Date.of_string "2017-02-08";
    entry_price = 100.0;
    exit_price = 110.0;
    quantity = 1.0;
    exit_trigger = "stop_loss";
    stop_trigger_kind = "gap_down";
    stop_initial_distance_pct = None;
    position_id = None;
    stop_fill_distance_pct = None;
  }

let _open_row ~symbol () : Vt.open_row =
  {
    symbol;
    side = "LONG";
    entry_date = Date.of_string "2017-01-30";
    entry_price = 100.0;
    quantity = 1.0;
  }

let _bar_on ?(volume = 1_000_000) ~date ~close () : Vt.daily_bar =
  {
    date;
    open_price = close;
    high = close;
    low = close;
    close;
    adjusted_close = close;
    volume;
  }

let _bar ?volume ~date ~close () =
  _bar_on ?volume ~date:(Date.of_string date) ~close ()

(* [n] consecutive daily bars from [start], each [close] on [volume]. Calendar
   days rather than trading days: V18 never asks what day of the week a bar
   fell on. *)
let _run ?volume ~start ~n ~close () =
  List.init n ~f:(fun i ->
      _bar_on ?volume ~date:(Date.add_days (Date.of_string start) i) ~close ())

let _bars_of daily : Vt.bars =
  { weekly_dates = [||]; weekly_closes = [||]; daily = Array.of_list daily }

let _store assoc sym =
  List.Assoc.find assoc sym ~equal:String.equal |> Option.map ~f:_bars_of

let _result ~id inputs = Vc.run_check ~id (inputs : Vt.inputs)

let _violations_and_pass n_viol passed =
  all_of
    [
      field (fun (r : Vt.check_result) -> r.n_violations) (equal_to n_viol);
      field (fun (r : Vt.check_result) -> r.passed) (equal_to passed);
    ]

(* The motivating series, shrunk: MEL's ~$175k plateau with the 12.2 print on
   zero volume dropped into the middle of it, then the plateau resumes. Both
   V18 rules fire on this one series, which is exactly what #2732 describes. *)
let _mel_series =
  _run ~start:"2017-01-02" ~n:30 ~close:175_002.0 ~volume:500 ()
  @ [ _bar ~date:"2017-02-08" ~close:12.2 ~volume:0 () ]
  @ _run ~start:"2017-02-09" ~n:30 ~close:176_500.0 ~volume:500 ()

let _mel_inputs () =
  {
    (Vt.empty_inputs ()) with
    trades = [ _trade ~symbol:"MEL" () ];
    bars = _store [ ("MEL", _mel_series) ];
  }

(* ---- the motivating defect --------------------------------------------- *)

(** #2732 itself: the series is flagged, once. *)
let test_v18_flags_the_mel_series _ =
  assert_that
    (_result ~id:"V18" (_mel_inputs ()))
    (_violations_and_pass 1 false)

(** The specimen makes the defect {b visible} — the symbol, the median close and
    the offending bar's date, close and volume. A finding that said only "V18: 1
    violation" would send the reader back to the warehouse to rediscover what
    the check already knew. *)
let test_v18_specimen_names_the_median_and_the_offending_bar _ =
  let detail_has s (sp : Vt.specimen) =
    String.is_substring sp.detail ~substring:s
  in
  assert_that
    (_result ~id:"V18" (_mel_inputs ()))
    (field
       (fun (r : Vt.check_result) -> r.specimens)
       (elements_are
          [
            all_of
              [
                field (fun (s : Vt.specimen) -> s.symbol) (equal_to "MEL");
                field
                  (fun (s : Vt.specimen) -> s.entry_date)
                  (equal_to "2017-01-30");
                field (detail_has "median close 175002.00") (equal_to true);
                field (detail_has "above the 10000.00 ceiling") (equal_to true);
                field (detail_has "bar 2017-02-08 close 12.20") (equal_to true);
                field (detail_has "on volume 0") (equal_to true);
              ];
          ]))

(** The unit of evaluation is the SYMBOL, not the trade: three MEL tickets are
    one finding, not three copies of it crowding the 10-specimen cap. The
    specimen is keyed to the {b earliest} of the entry dates. *)
let test_v18_reports_one_row_per_symbol_not_per_trade _ =
  let inputs =
    {
      (_mel_inputs ()) with
      trades =
        [
          _trade ~symbol:"MEL" ~entry_date:"2017-03-01" ();
          _trade ~symbol:"MEL" ~entry_date:"2017-01-30" ();
          _trade ~symbol:"MEL" ~entry_date:"2017-05-04" ();
        ];
    }
  in
  assert_that (_result ~id:"V18" inputs)
    (all_of
       [
         _violations_and_pass 1 false;
         field
           (fun (r : Vt.check_result) -> r.specimens)
           (elements_are
              [
                field
                  (fun (s : Vt.specimen) -> s.entry_date)
                  (equal_to "2017-01-30");
              ]);
       ])

(** A position still held at run end is exposed to a bad series exactly as much
    as one already round-tripped, so open positions are subjects too. *)
let test_v18_covers_a_symbol_held_only_as_an_open_position _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      open_positions = [ _open_row ~symbol:"MEL" () ];
      bars = _store [ ("MEL", _mel_series) ];
    }
  in
  assert_that (_result ~id:"V18" inputs) (_violations_and_pass 1 false)

(* ---- the phantom-print rule, on its own -------------------------------- *)

(** The zero-volume rule stands alone: an ordinarily-priced $40 series with a
    single untraded $2 print flags, even though its median is unremarkable. This
    is the half of V18 that would have caught the 12.2 bar had MEL's level been
    plausible. *)
let test_v18_flags_a_phantom_print_in_an_ordinary_series _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"NORM" () ];
      bars =
        _store
          [
            ( "NORM",
              _run ~start:"2017-01-02" ~n:30 ~close:40.0 ()
              @ [ _bar ~date:"2017-02-08" ~close:2.0 ~volume:0 () ]
              @ _run ~start:"2017-02-09" ~n:10 ~close:40.0 () );
          ];
    }
  in
  assert_that (_result ~id:"V18" inputs) (_violations_and_pass 1 false)

(** {b The load-bearing negative.} The same -95% move {i on real volume} does
    not flag. Takeovers, biotech readouts and missed reverse splits all move a
    stock that far in a day and all of them trade; only a move nobody
    participated in is the feed rather than the market. Without this exclusion
    V18 would flag a large slice of every broad-universe run. *)
let test_v18_does_not_flag_a_large_move_on_real_volume _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"TAKEOVER" () ];
      bars =
        _store
          [
            ( "TAKEOVER",
              _run ~start:"2017-01-02" ~n:30 ~close:40.0 ()
              @ [ _bar ~date:"2017-02-08" ~close:2.0 ~volume:4_000_000 () ]
              @ _run ~start:"2017-02-09" ~n:10 ~close:2.0 () );
          ];
    }
  in
  assert_that (_result ~id:"V18" inputs) (_violations_and_pass 0 true)

(** An ordinary series — normal level, every bar traded — passes. If this ever
    flags, the check is noise. *)
let test_v18_passes_an_ordinary_series _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"NORM" () ];
      bars = _store [ ("NORM", _run ~start:"2017-01-02" ~n:60 ~close:41.5 ()) ];
    }
  in
  assert_that (_result ~id:"V18" inputs) (_violations_and_pass 0 true)

(* ---- the level rule, and the false positive it accepts ------------------ *)

(* BRK.A: monotonically climbing, every bar traded, no phantom print — a real
   instrument whose only unusual property is its price. *)
let _brk_a_series =
  List.init 60 ~f:(fun i ->
      _bar_on ~volume:350
        ~date:(Date.add_days (Date.of_string "2017-01-02") i)
        ~close:(250_000.0 +. (1_000.0 *. Float.of_int i))
        ())

(** {b The accepted false positive, pinned.} A legitimately high-priced
    instrument DOES flag on the level rule — its median close is above any
    ceiling low enough to catch MEL, and no test on the price series alone
    separates "expensive share class" from "mis-mapped listing". This is why V18
    is an EXPECTATION: it asks a human, it does not fail the run. The test
    exists so the behaviour is a decision on record rather than a surprise. *)
let test_v18_flags_a_legitimately_high_priced_instrument _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"BRK-A" () ];
      bars = _store [ ("BRK-A", _brk_a_series) ];
    }
  in
  assert_that (_result ~id:"V18" inputs) (_violations_and_pass 1 false)

(** ...and the escape hatch for it: raising [store_median_close_max] above the
    instrument's level silences the level rule without disabling the check, so
    the phantom-print half keeps running for that run. *)
let test_v18_median_ceiling_comes_from_config _ =
  let config =
    { Vt.default_config with store_median_close_max = 1_000_000.0 }
  in
  let inputs =
    {
      (Vt.empty_inputs ~config ()) with
      trades = [ _trade ~symbol:"BRK-A" () ];
      bars = _store [ ("BRK-A", _brk_a_series) ];
    }
  in
  assert_that (_result ~id:"V18" inputs) (_violations_and_pass 0 true)

(** The move threshold is config too: an 80% untraded move passes at the default
    90 and flags once the threshold drops below it. *)
let test_v18_move_threshold_comes_from_config _ =
  let series =
    _run ~start:"2017-01-02" ~n:30 ~close:100.0 ()
    @ [ _bar ~date:"2017-02-08" ~close:20.0 ~volume:0 () ]
  in
  let inputs_at config =
    {
      (Vt.empty_inputs ~config ()) with
      trades = [ _trade ~symbol:"DIP" () ];
      bars = _store [ ("DIP", series) ];
    }
  in
  assert_that
    (_result ~id:"V18" (inputs_at Vt.default_config))
    (_violations_and_pass 0 true);
  assert_that
    (_result ~id:"V18"
       (inputs_at { Vt.default_config with store_zero_volume_move_pct = 70.0 }))
    (_violations_and_pass 1 false)

(** The volume floor is config as well: MEL's phantom prints sit on volumes of
    0-1,000, so raising [store_zero_volume_max] catches the near-untraded ones
    the default ([0]) deliberately lets past. *)
let test_v18_zero_volume_ceiling_comes_from_config _ =
  let series =
    _run ~start:"2017-01-02" ~n:30 ~close:100.0 ()
    @ [ _bar ~date:"2017-02-08" ~close:2.0 ~volume:40 () ]
  in
  let inputs_at config =
    {
      (Vt.empty_inputs ~config ()) with
      trades = [ _trade ~symbol:"THIN" () ];
      bars = _store [ ("THIN", series) ];
    }
  in
  assert_that
    (_result ~id:"V18" (inputs_at Vt.default_config))
    (_violations_and_pass 0 true);
  assert_that
    (_result ~id:"V18"
       (inputs_at { Vt.default_config with store_zero_volume_max = 100 }))
    (_violations_and_pass 1 false)

(* ---- skips ------------------------------------------------------------- *)

(** A symbol absent from the bar store is un-evaluable, so it is skipped and
    counted rather than passed — the skip count measures what the check could
    not read. *)
let test_v18_skips_a_symbol_absent_from_the_store _ =
  let inputs =
    { (Vt.empty_inputs ()) with trades = [ _trade ~symbol:"GHOST" () ] }
  in
  assert_that (_result ~id:"V18" inputs)
    (all_of
       [
         field (fun (r : Vt.check_result) -> r.n_skipped) (equal_to 1);
         _violations_and_pass 0 true;
       ])

(** A series too short to judge is skipped, not passed: a median over five bars
    is not evidence the series is sane, and a silent pass would make the
    un-evaluable case invisible in the report. *)
let test_v18_skips_a_series_shorter_than_the_bar_floor _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"SHORT" () ];
      bars =
        _store [ ("SHORT", _run ~start:"2017-01-02" ~n:5 ~close:175_002.0 ()) ];
    }
  in
  assert_that (_result ~id:"V18" inputs)
    (all_of
       [
         field (fun (r : Vt.check_result) -> r.n_skipped) (equal_to 1);
         _violations_and_pass 0 true;
       ])

(** ...and the floor is config: the same five-bar series is judged, and flagged,
    once [store_min_bars] drops to it. *)
let test_v18_bar_floor_comes_from_config _ =
  let config = { Vt.default_config with store_min_bars = 5 } in
  let inputs =
    {
      (Vt.empty_inputs ~config ()) with
      trades = [ _trade ~symbol:"SHORT" () ];
      bars =
        _store [ ("SHORT", _run ~start:"2017-01-02" ~n:5 ~close:175_002.0 ()) ];
    }
  in
  assert_that (_result ~id:"V18" inputs) (_violations_and_pass 1 false)

(** A non-positive prior close admits no ratio, so the phantom rule cannot
    evaluate that pair. With nothing else found the symbol is skipped rather
    than passed — same discipline as V13 and V15. The $0.00 bar itself carries
    volume, so it is clean on its own pair and only the bar {i after} it is
    un-evaluable; that is what isolates this branch. *)
let test_v18_skips_a_series_with_an_unevaluable_pair _ =
  let series =
    _run ~start:"2017-01-02" ~n:30 ~close:40.0 ()
    @ [ _bar ~date:"2017-02-01" ~close:0.0 () ]
    @ [ _bar ~date:"2017-02-02" ~close:40.0 ~volume:0 () ]
  in
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"ZEROED" () ];
      bars = _store [ ("ZEROED", series) ];
    }
  in
  assert_that (_result ~id:"V18" inputs)
    (all_of
       [
         field (fun (r : Vt.check_result) -> r.n_skipped) (equal_to 1);
         _violations_and_pass 0 true;
       ])

(** A violation outranks an un-evaluable pair: the same zeroed series at a
    mis-scaled level is reported, not skipped. Otherwise one bad bar could hide
    a whole mis-mapped listing. *)
let test_v18_reports_rather_than_skips_when_the_level_rule_fires _ =
  let series =
    _run ~start:"2017-01-02" ~n:30 ~close:175_002.0 ()
    @ [ _bar ~date:"2017-02-01" ~close:0.0 () ]
    @ [ _bar ~date:"2017-02-02" ~close:175_002.0 ~volume:0 () ]
  in
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ _trade ~symbol:"ZEROED" () ];
      bars = _store [ ("ZEROED", series) ];
    }
  in
  assert_that (_result ~id:"V18" inputs)
    (all_of
       [
         field (fun (r : Vt.check_result) -> r.n_skipped) (equal_to 0);
         _violations_and_pass 1 false;
       ])

(* ---- registry wiring --------------------------------------------------- *)

(** V18 is registered as an EXPECTATION, so a flagged store never hard-fails a
    run — the classification the whole check hinges on. *)
let test_v18_is_registered_as_an_expectation _ =
  assert_that
    (_result ~id:"V18" (Vt.empty_inputs ()))
    (field (fun (r : Vt.check_result) -> r.severity) (equal_to Vt.Expectation))

let suite =
  "validator_store_check"
  >::: [
         "v18 flags the mel series" >:: test_v18_flags_the_mel_series;
         "v18 specimen names the median and the offending bar"
         >:: test_v18_specimen_names_the_median_and_the_offending_bar;
         "v18 reports one row per symbol not per trade"
         >:: test_v18_reports_one_row_per_symbol_not_per_trade;
         "v18 covers a symbol held only as an open position"
         >:: test_v18_covers_a_symbol_held_only_as_an_open_position;
         "v18 flags a phantom print in an ordinary series"
         >:: test_v18_flags_a_phantom_print_in_an_ordinary_series;
         "v18 does not flag a large move on real volume"
         >:: test_v18_does_not_flag_a_large_move_on_real_volume;
         "v18 passes an ordinary series" >:: test_v18_passes_an_ordinary_series;
         "v18 flags a legitimately high priced instrument"
         >:: test_v18_flags_a_legitimately_high_priced_instrument;
         "v18 median ceiling comes from config"
         >:: test_v18_median_ceiling_comes_from_config;
         "v18 move threshold comes from config"
         >:: test_v18_move_threshold_comes_from_config;
         "v18 zero volume ceiling comes from config"
         >:: test_v18_zero_volume_ceiling_comes_from_config;
         "v18 skips a symbol absent from the store"
         >:: test_v18_skips_a_symbol_absent_from_the_store;
         "v18 skips a series shorter than the bar floor"
         >:: test_v18_skips_a_series_shorter_than_the_bar_floor;
         "v18 bar floor comes from config"
         >:: test_v18_bar_floor_comes_from_config;
         "v18 skips a series with an unevaluable pair"
         >:: test_v18_skips_a_series_with_an_unevaluable_pair;
         "v18 reports rather than skips when the level rule fires"
         >:: test_v18_reports_rather_than_skips_when_the_level_rule_fires;
         "v18 is registered as an expectation"
         >:: test_v18_is_registered_as_an_expectation;
       ]

let () = run_test_tt_main suite
