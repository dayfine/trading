open Core
open OUnit2
open Matchers
module Series_tail = Snapshot_pipeline.Series_tail
module Config = Series_tail.Config
module Class = Series_tail.Class
module Action = Series_tail.Action

let _d s = Date.of_string s
let _start = _d "2021-10-04"

let _bar ~date ~close =
  Types.Daily_price.make ~date ~open_price:close ~high_price:close
    ~low_price:close ~close_price:close ~volume:1_000 ~adjusted_close:close ()

(* One bar per calendar day from [start]; the rule keys on close shape and bar
   order, never on weekday. *)
let _series ?(start = _start) closes =
  List.mapi closes ~f:(fun i close -> _bar ~date:(Date.add_days start i) ~close)

let _repeat n close = List.init n ~f:(fun _ -> close)

let _apply ?(config = Config.default)
    ?(exceptions = Series_tail.Exceptions.empty) ~symbol bars =
  Series_tail.apply config ~exceptions ~symbol bars

let _date_is d =
  field (fun (b : Types.Daily_price.t) -> b.date) (equal_to ~cmp:Date.equal d)

let _dates_are (bars : Types.Daily_price.t list) =
  elements_are (List.map bars ~f:(fun b -> _date_is b.date))

(* "Unchanged" means element-for-element identity, not merely the same length:
   [size_is] witnesses identity only while the module's sole edit is a suffix
   drop, and PR-B routes rescaling onto this same path. Same idiom as
   [test_adjusted_basis.ml: test_equal_closes_is_bitwise_identity]. *)
let _unchanged bars = equal_to ~cmp:(List.equal Types.Daily_price.equal) bars

let _finding_is ~klass ~action ~n_stub ~cut_after =
  all_of
    [
      field
        (fun (f : Series_tail.finding) -> f.klass)
        (equal_to ~cmp:Class.equal klass);
      field
        (fun (f : Series_tail.finding) -> f.action)
        (equal_to ~cmp:Action.equal action);
      field (fun (f : Series_tail.finding) -> f.n_stub) (equal_to n_stub);
      field
        (fun (f : Series_tail.finding) -> f.cut_after)
        (equal_to ~cmp:Date.equal cut_after);
    ]

(* STMP: real through 2021-10-04 at $329.61, then $0.045 / $0.04 / $0.03 to the
   end of the series (issue #2672's motivating case). *)
let test_stmp_stub_tail_truncated _ =
  assert_that
    (_apply ~symbol:"STMP" (_series [ 329.61; 0.045; 0.04; 0.03 ]))
    (pair
       (elements_are [ _date_is _start ])
       (elements_are
          [
            _finding_is ~klass:Class.Stub_tail ~action:Action.Truncated
              ~n_stub:3 ~cut_after:_start;
          ]))

(* WDR: 29 bars at $0.27 after a $24.98 cash deal — longer than STMP's run but
   still inside the 60-bar cap, so still a stub. *)
let test_wdr_stub_tail_truncated _ =
  assert_that
    (_apply ~symbol:"WDR" (_series (24.98 :: _repeat 29 0.27)))
    (pair
       (elements_are [ _date_is _start ])
       (elements_are
          [
            _finding_is ~klass:Class.Stub_tail ~action:Action.Truncated
              ~n_stub:29 ~cut_after:_start;
          ]))

(* AGR: the last "real" close is $73,566 and the 4,653 bars below it are the
   genuine series. A bare ratio walk-back would delete every one of them. The
   mis-scale gate outranks the length gate, which this 200-bar run also
   trips. *)
let test_agr_prefix_misscale_kept _ =
  let bars = _series (73_566.0 :: _repeat 200 33.94) in
  assert_that
    (_apply ~symbol:"AGR" bars)
    (pair (_unchanged bars)
       (elements_are
          [
            _finding_is ~klass:Class.Prefix_misscale ~action:Action.Kept
              ~n_stub:200 ~cut_after:_start;
          ]))

(* MEL: $8,900 then 21 bars at $11.72 — a mis-scaled prefix whose run is also
   priced well above the $1 stub floor. *)
let test_mel_prefix_misscale_kept _ =
  let bars = _series (8_900.0 :: _repeat 21 11.72) in
  assert_that
    (_apply ~symbol:"MEL" bars)
    (pair (_unchanged bars)
       (elements_are
          [
            _finding_is ~klass:Class.Prefix_misscale ~action:Action.Kept
              ~n_stub:21 ~cut_after:_start;
          ]))

(* Same shape below the mis-scale threshold: $100 then $2 prints. Short enough
   and low enough on ratio, but the run's own prints are real money, so the
   absolute-price floor keeps it. *)
let test_high_priced_tail_kept _ =
  let bars = _series [ 100.0; 2.0; 2.1; 1.9 ] in
  assert_that
    (_apply ~symbol:"HIGH" bars)
    (pair (_unchanged bars)
       (elements_are
          [
            _finding_is ~klass:Class.High_price_tail ~action:Action.Kept
              ~n_stub:3 ~cut_after:_start;
          ]))

(* 100 penny bars after $50: past the 60-bar cap, so ticker reuse or a genuine
   multi-month collapse — reported, never truncated. *)
let test_long_low_tail_kept _ =
  let bars = _series (50.0 :: _repeat 100 0.10) in
  assert_that
    (_apply ~symbol:"LONG" bars)
    (pair (_unchanged bars)
       (elements_are
          [
            _finding_is ~klass:Class.Long_low_tail ~action:Action.Kept
              ~n_stub:100 ~cut_after:_start;
          ]))

(* A genuine -60% crash whose series keeps printing near the new level: no
   suffix is below 5% of the close before it, so nothing is flagged at all. *)
let test_genuine_crash_untouched _ =
  let bars = _series [ 100.0; 40.0; 41.0; 39.0; 42.0 ] in
  assert_that (_apply ~symbol:"CRASH" bars) (pair (_unchanged bars) is_empty)

(* A NaN close inside the terminal run makes the run's suffix maximum unbounded,
   so nothing below the reference is ever found: no finding, no truncation.
   ([_dates_are] rather than [_unchanged] because NaN <> NaN under [equal].) *)
let test_nan_inside_run_kept _ =
  let bars = _series [ 329.61; 0.045; 0.04; Float.nan ] in
  assert_that (_apply ~symbol:"NANRUN" bars) (pair (_dates_are bars) is_empty)

(* The other position a NaN can occupy: the close a candidate run is measured
   AGAINST. [Float.nan] maps to [infinity] and [ratio *. infinity = infinity],
   so without the finiteness guard every finite bar after it would read as a
   stub and the report would carry [nan] as [last_real_close]. *)
let test_nan_reference_starts_no_run _ =
  let bars = _series [ 329.61; 0.045; Float.nan; 0.03 ] in
  assert_that (_apply ~symbol:"NANREF" bars) (pair (_dates_are bars) is_empty)

(* ANCR: 2000-08-01 at $66.68, then a single bar 2016-01-27 at $2.07. The bar
   is BOTH a (high-priced, hence kept) terminal run and a stray print; the
   stray pass drops it, so the series ends at its real last trade. *)
let test_ancr_stray_bar_dropped _ =
  let real_end = Date.add_days _start 1 in
  let bars =
    _series [ 66.0; 66.68 ]
    @ [ _bar ~date:(Date.add_days _start 5_650) ~close:2.07 ]
  in
  assert_that
    (_apply ~symbol:"ANCR" bars)
    (pair
       (_unchanged (List.take bars 2))
       (elements_are
          [
            _finding_is ~klass:Class.High_price_tail ~action:Action.Kept
              ~n_stub:1 ~cut_after:real_end;
            _finding_is ~klass:Class.Stray_bar ~action:Action.Stray_dropped
              ~n_stub:1 ~cut_after:real_end;
          ]))

(* A stray bar that is not also a stub (price continues at the same level)
   produces the stray finding alone. *)
let test_stray_bar_alone _ =
  let real_end = Date.add_days _start 1 in
  let bars =
    _series [ 66.0; 66.68 ]
    @ [ _bar ~date:(Date.add_days _start 5_650) ~close:65.0 ]
  in
  assert_that
    (_apply ~symbol:"LATE" bars)
    (pair
       (_unchanged (List.take bars 2))
       (elements_are
          [
            _finding_is ~klass:Class.Stray_bar ~action:Action.Stray_dropped
              ~n_stub:1 ~cut_after:real_end;
          ]))

(* A symbol in the committed exceptions file is reported but never edited. *)
let test_exception_keeps_stub_tail _ =
  let bars = _series [ 329.61; 0.045; 0.04; 0.03 ] in
  assert_that
    (_apply
       ~exceptions:(Series_tail.Exceptions.of_symbols [ "STMP" ])
       ~symbol:"STMP" bars)
    (pair (_unchanged bars)
       (elements_are
          [
            _finding_is ~klass:Class.Stub_tail ~action:Action.Kept_by_exception
              ~n_stub:3 ~cut_after:_start;
          ]))

let _edits_off =
  {
    Config.stub = { Config.default.stub with truncate = false };
    stray = { Config.default.stray with drop = false };
  }

(* [-no-stub-truncation] / [-no-stray-drop]: detection and reporting still run,
   the bars come back identical. *)
let test_edits_off_is_identity _ =
  let bars =
    _series [ 329.61; 0.045; 0.04; 0.03 ]
    @ [ _bar ~date:(Date.add_days _start 5_650) ~close:0.02 ]
  in
  assert_that
    (_apply ~config:_edits_off ~symbol:"STMP" bars)
    (pair (_unchanged bars)
       (elements_are
          [
            _finding_is ~klass:Class.Stub_tail ~action:Action.Kept ~n_stub:4
              ~cut_after:_start;
            _finding_is ~klass:Class.Stray_bar ~action:Action.Kept ~n_stub:1
              ~cut_after:(Date.add_days _start 3);
          ]))

let test_short_series_unchanged _ =
  let bars = _series [ 12.5 ] in
  assert_that (_apply ~symbol:"ONE" bars) (pair (_unchanged bars) is_empty)

let test_classify_is_report_only _ =
  assert_that
    (Series_tail.classify Config.default ~symbol:"STMP"
       (_series [ 329.61; 0.045; 0.04; 0.03 ]))
    (elements_are
       [
         _finding_is ~klass:Class.Stub_tail ~action:Action.Truncated ~n_stub:3
           ~cut_after:_start;
       ])

let test_csv_and_summary _ =
  let findings =
    Series_tail.classify Config.default ~symbol:"STMP"
      (_series [ 329.61; 0.045; 0.04; 0.03 ])
  in
  assert_that
    (Series_tail.to_csv findings)
    (all_of
       [
         contains_substring Series_tail.csv_header;
         contains_substring "STMP,stub_tail,2021-10-04,329.6100,3,";
         contains_substring ",truncated\n";
       ])

(* [terminal_runs.csv] is written even when the build finds nothing: a
   header-only file is the positive evidence that the scan ran. *)
let test_empty_csv_is_header_only _ =
  assert_that (Series_tail.to_csv []) (equal_to (Series_tail.csv_header ^ "\n"))

(* The veto list itself: [of_symbols] is the view {!Build_runner} hands this
   module after parsing the [keep_tail] section. The on-disk parse is pinned
   next to that parser, in [test_build_runner_exceptions.ml]. *)
let test_exceptions_membership _ =
  let t = Series_tail.Exceptions.of_symbols [ "STMP"; "WDR" ] in
  assert_that
    (List.map [ "STMP"; "WDR"; "HIBB" ] ~f:(fun symbol ->
         Series_tail.Exceptions.mem t ~symbol))
    (elements_are [ equal_to true; equal_to true; equal_to false ])

let test_summary_counts _ =
  assert_that
    (Series_tail.summary
       (Series_tail.classify Config.default ~symbol:"STMP"
          (_series [ 329.61; 0.045; 0.04; 0.03 ])))
    (contains_substring "1 findings (1 truncated, 0 stray_dropped, 0 kept")

let suite =
  "series_tail"
  >::: [
         "stmp_stub_tail_truncated" >:: test_stmp_stub_tail_truncated;
         "wdr_stub_tail_truncated" >:: test_wdr_stub_tail_truncated;
         "agr_prefix_misscale_kept" >:: test_agr_prefix_misscale_kept;
         "mel_prefix_misscale_kept" >:: test_mel_prefix_misscale_kept;
         "high_priced_tail_kept" >:: test_high_priced_tail_kept;
         "long_low_tail_kept" >:: test_long_low_tail_kept;
         "genuine_crash_untouched" >:: test_genuine_crash_untouched;
         "nan_inside_run_kept" >:: test_nan_inside_run_kept;
         "nan_reference_starts_no_run" >:: test_nan_reference_starts_no_run;
         "ancr_stray_bar_dropped" >:: test_ancr_stray_bar_dropped;
         "stray_bar_alone" >:: test_stray_bar_alone;
         "exception_keeps_stub_tail" >:: test_exception_keeps_stub_tail;
         "edits_off_is_identity" >:: test_edits_off_is_identity;
         "short_series_unchanged" >:: test_short_series_unchanged;
         "classify_is_report_only" >:: test_classify_is_report_only;
         "csv_and_summary" >:: test_csv_and_summary;
         "empty_csv_is_header_only" >:: test_empty_csv_is_header_only;
         "summary_counts" >:: test_summary_counts;
         "exceptions_membership" >:: test_exceptions_membership;
       ]

let () = run_test_tt_main suite
