open Core
open OUnit2
open Matchers
open Universe
module DVB = Dollar_volume_basis
module BR = Composition_bar_reader
module CA = Corporate_actions

let _d s = Date.of_string s

let _bar ?(adjusted_close = 0.0) date close volume : BR.bar =
  { date = _d date; close; adjusted_close; volume }

(* AMZN as stored: raw close, volume restated for the 2022-06-06 20:1 split.
   The two bars around the split day show the raw close jumping 2447 -> 124.79,
   so the split is confirmed. *)
let _amzn_bars =
  [
    _bar "2018-06-14" 1723.86 63_488_299.0;
    _bar "2022-06-03" 2447.0 97_603_319.0;
    _bar "2022-06-06" 124.79 135_268_984.0;
  ]

let _amzn_splits : CA.split list = [ { date = _d "2022-06-06"; factor = 20.0 } ]

(* C as stored: raw close, volume restated for the 2011-05-09 1:10 reverse
   split (4.52 -> 44.16 across the split day). *)
let _c_bars =
  [
    _bar "2010-06-14" 3.88 38_228_780.0;
    _bar "2011-05-06" 4.52 5_131_670.0;
    _bar "2011-05-09" 44.16 49_168_100.0;
  ]

let _c_splits : CA.split list = [ { date = _d "2011-05-09"; factor = 0.1 } ]
let _tol = DVB.default_split_confirm_log_tolerance

let _true_dv bars splits date =
  let applied = DVB.applied_splits DVB.true_dollars_config bars splits in
  let bar =
    List.find_exn bars ~f:(fun (b : BR.bar) -> Date.equal b.date date)
  in
  DVB.bar_dollar_volume DVB.True_dollars ~splits:applied bar

(* AMZN 2018-06-14: stored close * volume is 20x the true figure. *)
let test_amzn_2018_true_dollars _ =
  assert_that
    (_true_dv _amzn_bars _amzn_splits (_d "2018-06-14"))
    (float_equal ~epsilon:1.0 (1723.86 *. 63_488_299.0 /. 20.0))

(* C 2010-06-14: stored close * volume is 1/10 of the true figure. *)
let test_c_2010_true_dollars _ =
  assert_that
    (_true_dv _c_bars _c_splits (_d "2010-06-14"))
    (float_equal ~epsilon:1.0 (3.88 *. 38_228_780.0 /. 0.1))

(* The split day already trades on the post-split share count: F excludes the
   split's own factor, so the stored product is the true figure. *)
let test_split_day_not_divided _ =
  assert_that
    (_true_dv _amzn_bars _amzn_splits (_d "2022-06-06"))
    (float_equal (124.79 *. 135_268_984.0))

let test_legacy_basis_ignores_splits _ =
  let bar = List.hd_exn _amzn_bars in
  assert_that
    (DVB.bar_dollar_volume DVB.Close_times_volume ~splits:_amzn_splits bar)
    (float_equal (1723.86 *. 63_488_299.0))

(* A vendor split the raw close never shows (RTN 2001-05-14, factor 0.05,
   close 29.41 -> 29.64) is not applied. *)
let test_unconfirmed_split_ignored _ =
  let bars =
    [ _bar "2001-05-11" 29.41 975_000.0; _bar "2001-05-14" 29.64 1e6 ]
  in
  let splits : CA.split list = [ { date = _d "2001-05-14"; factor = 0.05 } ] in
  assert_that
    (DVB.applied_splits DVB.true_dollars_config bars splits)
    (size_is 0)

(* Splits dated after the last bar or before the first bar are not applied. *)
let test_split_off_the_bars_ignored _ =
  let splits : CA.split list =
    [
      { date = _d "2030-01-02"; factor = 2.0 };
      { date = _d "2000-01-03"; factor = 2.0 };
    ]
  in
  assert_that
    (DVB.applied_splits DVB.true_dollars_config _amzn_bars splits)
    (size_is 0)

(* A vendor date on a Saturday (2022-06-04) and one a bar late (2022-06-07)
   are both re-dated to the bar whose close jumps (2022-06-06); with no search
   the late one is dropped. *)
let test_misdated_split_redated_to_jump _ =
  let late : CA.split list = [ { date = _d "2022-06-07"; factor = 20.0 } ] in
  let saturday : CA.split list =
    [ { date = _d "2022-06-04"; factor = 20.0 } ]
  in
  let bars = _amzn_bars @ [ _bar "2022-06-07" 123.0 85_156_711.0 ] in
  let applied ~search_bars s =
    DVB.applied_splits
      { DVB.true_dollars_config with split_search_bars = search_bars }
      bars s
  in
  assert_that
    ( applied ~search_bars:2 late,
      applied ~search_bars:2 saturday,
      applied ~search_bars:0 late )
    (equal_to
       ((_amzn_splits, _amzn_splits, [])
         : CA.split list * CA.split list * CA.split list))

(* OHGI-shaped 1:1500 reverse split: close 0.0001 -> 0.15. [after_volume] is
   the volume on and after the split day, 10 bars each side. *)
let _reverse_split_bars ~after_volume =
  let day i = Date.add_days (_d "2006-07-01") i in
  List.init 20 ~f:(fun i ->
      let close, volume =
        if i < 10 then (0.0001, 1.5e8) else (0.15, after_volume)
      in
      ({ date = day i; close; adjusted_close = close; volume } : BR.bar))

let _reverse_split : CA.split =
  { date = Date.add_days (_d "2006-07-01") 10; factor = 1.0 /. 1500.0 }

(* Raw volume (falls 1500x with the share count): share 1.0, not restated,
   split dropped. Restated volume (flat): share 0.0, split applied. *)
let test_volume_restatement_decides_split _ =
  let raw = _reverse_split_bars ~after_volume:1e5 in
  let restated = _reverse_split_bars ~after_volume:1.5e8 in
  let cfg = DVB.true_dollars_config in
  assert_that
    ( DVB.volume_jump_share cfg raw _reverse_split,
      DVB.volume_jump_share cfg restated _reverse_split,
      DVB.applied_splits cfg raw [ _reverse_split ],
      DVB.applied_splits cfg restated [ _reverse_split ] )
    (all_of
       [
         field (fun (a, _, _, _) -> a) (is_some_and (float_equal 1.0));
         field (fun (_, b, _, _) -> b) (is_some_and (float_equal 0.0));
         field (fun (_, _, c, _) -> c) (size_is 0);
         field (fun (_, _, _, d) -> d) (size_is 1);
       ])

(* A 2:1 split is below the 3:1 threshold: assumed restated even when its
   volume doubles. *)
let test_small_split_assumed_restated _ =
  let bars =
    List.init 20 ~f:(fun i ->
        let close, volume = if i < 10 then (100.0, 1e6) else (50.0, 2e6) in
        ({
           date = Date.add_days (_d "2020-01-01") i;
           close;
           adjusted_close = close;
           volume;
         }
          : BR.bar))
  in
  let split : CA.split = { date = _d "2020-01-11"; factor = 2.0 } in
  assert_that
    (DVB.volume_restated DVB.true_dollars_config bars split)
    (equal_to true)

let test_split_divisor_products _ =
  let splits : CA.split list =
    [
      { date = _d "2000-01-03"; factor = 2.0 };
      { date = _d "2010-01-04"; factor = 3.0 };
    ]
  in
  assert_that
    ( DVB.split_divisor ~splits (_d "1999-12-31"),
      DVB.split_divisor ~splits (_d "2000-01-03"),
      DVB.split_divisor ~splits (_d "2010-01-04") )
    (equal_to ((6.0, 3.0, 1.0) : float * float * float))

let test_confirms_split_rejects_non_positive_close _ =
  assert_that
    (DVB.confirms_split ~log_tolerance:_tol ~prev_close:0.0 ~close:1.0 2.0)
    (equal_to false)

(* Window of three bars, one of which prints $4.2 trillion (the COMP_old
   shape): under the true-dollar basis it is rejected and listed, and the
   average is over the other two. *)
let _junk_window =
  [
    _bar "2019-05-28" 10.0 1_000_000.0;
    _bar "2019-05-29" 14_000.0 300_000_000.0;
    _bar "2019-05-30" 10.0 3_000_000.0;
  ]

let _score config =
  DVB.score_window config ~splits:[] ~date:(_d "2019-05-31")
    ~trailing_window_days:60 ~min_window_bars:2 _junk_window

let test_junk_bar_rejected _ =
  assert_that
    (_score DVB.true_dollars_config)
    (all_of
       [
         field
           (fun (s : DVB.window_score) -> s.avg)
           (is_some_and (float_equal 2e7));
         field
           (fun (s : DVB.window_score) ->
             List.map s.rejected ~f:(fun ((b : BR.bar), _) -> b.date))
           (elements_are [ equal_to (_d "2019-05-29") ]);
       ])

(* The legacy basis keeps every bar (the committed lists' behaviour). *)
let test_legacy_keeps_junk_bar _ =
  assert_that (_score DVB.legacy_config)
    (all_of
       [
         field
           (fun (s : DVB.window_score) -> s.avg)
           (is_some_and (float_equal ((1e7 +. 4.2e12 +. 3e7) /. 3.0)));
         field (fun (s : DVB.window_score) -> s.rejected) (size_is 0);
       ])

(* Rejection can leave too few bars: the symbol then has no score. *)
let test_rejection_below_min_bars_gives_none _ =
  let s =
    DVB.score_window DVB.true_dollars_config ~splits:[] ~date:(_d "2019-05-31")
      ~trailing_window_days:60 ~min_window_bars:3 _junk_window
  in
  assert_that s.avg is_none

let _tmp_dir () =
  let dir = Stdlib.Filename.temp_file "dvb_test_" ".d" in
  Stdlib.Sys.remove dir;
  Core_unix.mkdir_p dir;
  dir

(* No splits.csv: [None] under the true basis (the caller scores with F = 1
   and counts it); the legacy basis never reads the disk. *)
let test_missing_splits_file _ =
  let root = _tmp_dir () in
  assert_that
    ( DVB.read_applied_splits DVB.true_dollars_config ~bars_root:root "AMZN"
        _amzn_bars,
      DVB.read_applied_splits DVB.legacy_config ~bars_root:root "AMZN"
        _amzn_bars )
    (all_of [ field fst is_none; field snd (is_some_and (size_is 0)) ])

let test_reads_and_confirms_splits_file _ =
  let root = _tmp_dir () in
  let written = CA.write_splits ~data_dir:(Fpath.v root) "AMZN" _amzn_splits in
  assert_that
    ( written,
      DVB.read_applied_splits DVB.true_dollars_config ~bars_root:root "AMZN"
        _amzn_bars )
    (all_of
       [
         field fst is_ok;
         field snd (is_some_and (equal_to (_amzn_splits : CA.split list)));
       ])

let suite =
  "Dollar_volume_basis"
  >::: [
         "test_amzn_2018_true_dollars" >:: test_amzn_2018_true_dollars;
         "test_c_2010_true_dollars" >:: test_c_2010_true_dollars;
         "test_split_day_not_divided" >:: test_split_day_not_divided;
         "test_legacy_basis_ignores_splits" >:: test_legacy_basis_ignores_splits;
         "test_unconfirmed_split_ignored" >:: test_unconfirmed_split_ignored;
         "test_split_off_the_bars_ignored" >:: test_split_off_the_bars_ignored;
         "test_misdated_split_redated_to_jump"
         >:: test_misdated_split_redated_to_jump;
         "test_volume_restatement_decides_split"
         >:: test_volume_restatement_decides_split;
         "test_small_split_assumed_restated"
         >:: test_small_split_assumed_restated;
         "test_split_divisor_products" >:: test_split_divisor_products;
         "test_confirms_split_rejects_non_positive_close"
         >:: test_confirms_split_rejects_non_positive_close;
         "test_junk_bar_rejected" >:: test_junk_bar_rejected;
         "test_legacy_keeps_junk_bar" >:: test_legacy_keeps_junk_bar;
         "test_rejection_below_min_bars_gives_none"
         >:: test_rejection_below_min_bars_gives_none;
         "test_missing_splits_file" >:: test_missing_splits_file;
         "test_reads_and_confirms_splits_file"
         >:: test_reads_and_confirms_splits_file;
       ]

let () = run_test_tt_main suite
