(** Issue #3173: a split the detector reads off a large cash dividend is
    rejected when the vendor files show the dividend and no split. Each case
    runs the real {!Types.Split_detector} on a bar pair first, so the factor the
    guard judges is the one the simulator would apply. *)

open Core
open OUnit2
open Matchers
module CA = Corporate_actions
module G = Split_dividend_guard

let _d = Date.of_string

(* A bar with the two fields the detector reads; OHLV mirror the close. *)
let _bar date ~close ~adjusted : Types.Daily_price.t =
  {
    date = _d date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = adjusted;
    volume = 100_000;
    active_through = None;
  }

(* The bar pair a cash dividend [amount] on a prior close [prev_close] leaves:
   the vendor back-rolls the prior adjusted close by [(P - D) / P]. *)
let _dividend_pair ~prev_date ~date ~prev_close ~amount ~close =
  ( _bar prev_date ~close:prev_close ~adjusted:(prev_close -. amount),
    _bar date ~close ~adjusted:close )

let _div ?unadjusted date adjusted : CA.dividend =
  {
    ex_date = _d date;
    unadjusted_amount = unadjusted;
    adjusted_amount = adjusted;
  }

let _split date factor : CA.split = { date = _d date; factor }

(* A guard over in-memory files for one symbol. *)
let _guard ~dividends ~splits =
  G.create
    ~load_dividends:(fun _ -> Ok dividends)
    ~load_splits:(fun _ -> Ok splits)
    ()

(* (detected, after the guard) for [symbol] on the pair. *)
let _detect_then_filter guard ~symbol (prev, curr) =
  let detected = Types.Split_detector.detect_split ~prev ~curr () in
  ( detected,
    G.filter guard ~symbol ~date:curr.Types.Daily_price.date
      ~prev_close:prev.Types.Daily_price.close_price detected )

let _rejected_split =
  all_of
    [ field fst (is_some_and (gt (module Float_ord) 1.0)); field snd is_none ]

let _kept_split factor =
  all_of
    [
      field fst (is_some_and (float_equal factor));
      field snd (is_some_and (float_equal factor));
    ]

let _tdg_pair =
  _dividend_pair ~prev_date:"2013-07-10" ~date:"2013-07-11" ~prev_close:160.80
    ~amount:22.00 ~close:139.50

(* TDG 2013-07-11: $22.00 special, 160.80 / 138.80 = 1.1585 -> 22/19. *)
let test_tdg_special_dividend_rejected _ =
  let guard =
    _guard ~dividends:[ _div "2013-07-11" ~unadjusted:22.0 22.0 ] ~splits:[]
  in
  assert_that
    (_detect_then_filter guard ~symbol:"TDG" _tdg_pair)
    _rejected_split

(* WING 2018-02-08: $3.17 on 48.14 -> 1.0705 -> 15/14. The vendor ex-date is
   one bar before the bar where the adjusted series steps. *)
let test_wing_dividend_one_bar_off_rejected _ =
  let pair =
    _dividend_pair ~prev_date:"2018-02-07" ~date:"2018-02-08" ~prev_close:48.14
      ~amount:3.17 ~close:45.10
  in
  let guard =
    _guard ~dividends:[ _div "2018-02-07" ~unadjusted:3.17 3.17 ] ~splits:[]
  in
  assert_that (_detect_then_filter guard ~symbol:"WING" pair) _rejected_split

(* BCH 2010-03-17: $3.90 on 58.14 -> 1.0719 -> 15/14. No unadjusted amount:
   the adjusted amount is the fallback. *)
let test_bch_dividend_adjusted_amount_fallback_rejected _ =
  let pair =
    _dividend_pair ~prev_date:"2010-03-16" ~date:"2010-03-17" ~prev_close:58.14
      ~amount:3.90 ~close:54.60
  in
  let guard = _guard ~dividends:[ _div "2010-03-17" 3.90 ] ~splits:[] in
  assert_that (_detect_then_filter guard ~symbol:"BCH" pair) _rejected_split

(* AAPL 2020-08-31 4:1 with its vendor split row (and an August dividend far
   outside the window): applied. *)
let test_real_split_with_vendor_row_kept _ =
  let pair =
    ( _bar "2020-08-28" ~close:499.23 ~adjusted:124.81,
      _bar "2020-08-31" ~close:129.04 ~adjusted:129.04 )
  in
  let guard =
    _guard
      ~dividends:[ _div "2020-08-07" ~unadjusted:0.82 0.205 ]
      ~splits:[ _split "2020-08-31" 4.0 ]
  in
  assert_that (_detect_then_filter guard ~symbol:"AAPL" pair) (_kept_split 4.0)

(* A vendor split within the window wins over a matching same-day dividend. *)
let test_vendor_split_beats_same_day_dividend _ =
  let guard =
    _guard
      ~dividends:[ _div "2013-07-11" ~unadjusted:22.0 22.0 ]
      ~splits:[ _split "2013-07-11" (22.0 /. 19.0) ]
  in
  assert_that
    (_detect_then_filter guard ~symbol:"TDG" _tdg_pair)
    (_kept_split (22.0 /. 19.0))

(* A matching dividend on Tue 07-16, three bars after Thu 07-11: outside. *)
let test_dividend_outside_window_kept _ =
  let guard =
    _guard ~dividends:[ _div "2013-07-16" ~unadjusted:22.0 22.0 ] ~splits:[]
  in
  assert_that
    (_detect_then_filter guard ~symbol:"TDG" _tdg_pair)
    (_kept_split (22.0 /. 19.0))

(* A same-day dividend whose implied factor (160.80 / 159.80) is far from the
   detected 22/19 is a different event. *)
let test_inconsistent_dividend_amount_kept _ =
  let guard =
    _guard ~dividends:[ _div "2013-07-11" ~unadjusted:1.0 1.0 ] ~splits:[]
  in
  assert_that
    (_detect_then_filter guard ~symbol:"TDG" _tdg_pair)
    (_kept_split (22.0 /. 19.0))

(* Missing files: the split is kept, the symbol counted once, loaded once. *)
let test_missing_files_keep_split_and_count _ =
  let loads = ref 0 in
  let guard =
    G.create
      ~load_dividends:(fun _ ->
        incr loads;
        Status.error_not_found "no dividends.csv")
      ~load_splits:(fun _ -> Ok [])
      ()
  in
  let first = _detect_then_filter guard ~symbol:"TDG" _tdg_pair in
  let second = _detect_then_filter guard ~symbol:"TDG" _tdg_pair in
  assert_that
    (first, second, G.counts guard, !loads)
    (all_of
       [
         field (fun (a, _, _, _) -> a) (_kept_split (22.0 /. 19.0));
         field (fun (_, b, _, _) -> b) (_kept_split (22.0 /. 19.0));
         field
           (fun (_, _, c, _) -> c)
           (equal_to ({ rejected = 0; no_files = 1 } : G.counts));
         field (fun (_, _, _, n) -> n) (equal_to 1);
       ])

(* An unreadable splits file is treated like a missing one. *)
let test_unreadable_file_keeps_split _ =
  let guard =
    G.create
      ~load_dividends:(fun _ -> Ok [ _div "2013-07-11" ~unadjusted:22.0 22.0 ])
      ~load_splits:(fun _ -> Status.error_invalid_argument "bad row")
      ()
  in
  let result = _detect_then_filter guard ~symbol:"TDG" _tdg_pair in
  assert_that
    (result, G.counts guard)
    (all_of
       [
         field fst (_kept_split (22.0 /. 19.0));
         field snd (equal_to ({ rejected = 0; no_files = 1 } : G.counts));
       ])

(* No detected split: no file is read. *)
let test_no_detection_reads_nothing _ =
  let loads = ref 0 in
  let guard =
    G.create
      ~load_dividends:(fun _ ->
        incr loads;
        Ok [])
      ~load_splits:(fun _ ->
        incr loads;
        Ok [])
      ()
  in
  let result =
    G.filter guard ~symbol:"TDG" ~date:(_d "2013-07-11") ~prev_close:160.80 None
  in
  assert_that (result, !loads)
    (all_of [ field fst is_none; field snd (equal_to 0) ])

(* The simulator and the strategy both ask about one event: counted once. *)
let test_rejection_counted_once_per_event _ =
  let guard =
    _guard ~dividends:[ _div "2013-07-11" ~unadjusted:22.0 22.0 ] ~splits:[]
  in
  ignore (_detect_then_filter guard ~symbol:"TDG" _tdg_pair : _ * _);
  ignore (_detect_then_filter guard ~symbol:"TDG" _tdg_pair : _ * _);
  assert_that (G.counts guard)
    (equal_to ({ rejected = 1; no_files = 0 } : G.counts))

let test_implied_factor_bounds _ =
  assert_that
    ( G.implied_factor ~prev_close:160.80 ~amount:22.0,
      G.implied_factor ~prev_close:10.0 ~amount:0.0,
      G.implied_factor ~prev_close:10.0 ~amount:10.0 )
    (all_of
       [
         field
           (fun (a, _, _) -> a)
           (is_some_and (float_equal (160.80 /. 138.80)));
         field (fun (_, b, _) -> b) is_none;
         field (fun (_, _, c) -> c) is_none;
       ])

(* [of_data_dir] reads the files [Corporate_actions] writes. *)
let test_of_data_dir_reads_vendor_files _ =
  let data_dir = Fpath.v (Filename_unix.temp_dir "split_dividend_guard_" "") in
  let written =
    Result.bind
      (CA.write_dividends ~data_dir "TDG"
         [ _div "2013-07-11" ~unadjusted:22.0 22.0 ])
      ~f:(fun () -> CA.write_splits ~data_dir "TDG" [])
  in
  let guard = G.of_data_dir ~data_dir () in
  assert_that
    (written, _detect_then_filter guard ~symbol:"TDG" _tdg_pair)
    (all_of [ field fst is_ok; field snd _rejected_split ])

let suite =
  "split_dividend_guard"
  >::: [
         "tdg special dividend rejected" >:: test_tdg_special_dividend_rejected;
         "wing dividend one bar off rejected"
         >:: test_wing_dividend_one_bar_off_rejected;
         "bch dividend adjusted amount fallback rejected"
         >:: test_bch_dividend_adjusted_amount_fallback_rejected;
         "real split with vendor row kept"
         >:: test_real_split_with_vendor_row_kept;
         "vendor split beats same day dividend"
         >:: test_vendor_split_beats_same_day_dividend;
         "dividend outside window kept" >:: test_dividend_outside_window_kept;
         "inconsistent dividend amount kept"
         >:: test_inconsistent_dividend_amount_kept;
         "missing files keep split and count"
         >:: test_missing_files_keep_split_and_count;
         "unreadable file keeps split" >:: test_unreadable_file_keeps_split;
         "no detection reads nothing" >:: test_no_detection_reads_nothing;
         "rejection counted once per event"
         >:: test_rejection_counted_once_per_event;
         "implied factor bounds" >:: test_implied_factor_bounds;
         "of_data_dir reads vendor files"
         >:: test_of_data_dir_reads_vendor_files;
       ]

let () = run_test_tt_main suite
