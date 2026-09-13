open Core
open OUnit2
open Matchers
module Series_level = Snapshot_pipeline.Series_level
module Config = Series_level.Config
module Class = Series_level.Class

let _d s = Date.of_string s
let _start = _d "2017-01-02"

let _bar ?(volume = 1_000) ~date ~close () =
  Types.Daily_price.make ~date ~open_price:close ~high_price:close
    ~low_price:close ~close_price:close ~volume ~adjusted_close:close ()

(* One bar per calendar day from [start]; the rule keys on close level and bar
   count, never on weekday. *)
let _series ?(start = _start) ?(volume = 1_000) closes =
  List.mapi closes ~f:(fun i close ->
      _bar ~volume ~date:(Date.add_days start i) ~close ())

let _repeat n close = List.init n ~f:(fun _ -> close)

(* Every behavioural test arms the check explicitly, because the shipped default
   is off — which [test_default_config_is_a_no_op] is the pin for. *)
let _armed = { Config.default with enabled = true }

let _classify ?(config = _armed) ~symbol bars =
  Series_level.classify config ~symbol bars

let _classify_exn ?config ~symbol bars =
  match _classify ?config ~symbol bars with
  | Some f -> f
  | None -> assert_failure (symbol ^ ": expected a finding, got none")

let _klass_is klass =
  field
    (fun (f : Series_level.finding) -> f.klass)
    (equal_to ~cmp:Class.equal klass)

let _counts_are ~n_bars ~n_above =
  all_of
    [
      field (fun (f : Series_level.finding) -> f.n_bars) (equal_to n_bars);
      field (fun (f : Series_level.finding) -> f.n_above) (equal_to n_above);
    ]

(* ---- the residual class: an implausible level with no in-window seam ----- *)

(* AGR's mis-scale seam is 2006-07-05 ($73,566 -> $33.94). A build window that
   ENDS before it stores the prefix alone: no terminal run for Series_tail to
   classify, no day-over-day jump for Splice_detector to flag, and both modules
   read the windowed bars. Nothing in the build can see this today — which is
   the whole reason the module exists. *)
let _agr_prefix_window = _series (_repeat 60 73_566.74)

let test_whole_window_is_flagged _ =
  assert_that
    (_classify ~symbol:"AGR" _agr_prefix_window)
    (is_some_and
       (all_of
          [
            _klass_is Class.Whole_window;
            _counts_are ~n_bars:60 ~n_above:60;
            field
              (fun (f : Series_level.finding) -> f.median_close)
              (float_equal 73_566.74);
          ]))

(* ---- the motivating defect, at its real shape ---------------------------- *)

(* MEL as stored in the top-3000-2000 vintage (#2732): the bulk above $167k with
   a handful of $8-12 prints mixed in. The median sits in the artefact so the
   series is flagged, and the low prints make it Mixed_scale — the class where
   the shape rules CAN also see the defect, so a reviewer should read
   terminal_runs.csv / splice_actions.csv before reaching for a drop. *)
let _mel_window = _series (_repeat 50 172_140.0 @ _repeat 10 12.20)

let test_mel_shape_is_flagged_as_mixed_scale _ =
  assert_that
    (_classify ~symbol:"MEL" _mel_window)
    (is_some_and
       (all_of
          [
            _klass_is Class.Mixed_scale;
            _counts_are ~n_bars:60 ~n_above:50;
            field
              (fun (f : Series_level.finding) -> f.min_close)
              (float_equal 12.20);
            field
              (fun (f : Series_level.finding) -> f.max_close)
              (float_equal 172_140.0);
          ]))

(* ---- what must NOT be flagged ------------------------------------------- *)

let test_an_ordinary_series_is_not_flagged _ =
  assert_that (_classify ~symbol:"NORM" (_series (_repeat 60 41.5))) is_none

(** The shipped default is [enabled = false], so an unarmed build gets [None]
    without reading a bar and every existing warehouse and golden is
    bit-identical. Pinned on the series that most loudly WOULD flag. *)
let test_default_config_is_a_no_op _ =
  assert_that
    (Series_level.classify Config.default ~symbol:"MEL" _mel_window)
    is_none

(** A median over a handful of bars is not evidence a series is sane, so a short
    series is not classified at all — even one made entirely of $172k prints. *)
let test_short_series_is_not_classified _ =
  assert_that (_classify ~symbol:"MEL" (_series (_repeat 19 172_140.0))) is_none;
  assert_that
    (_classify ~symbol:"MEL" (_series (_repeat 20 172_140.0)))
    (is_some_and (_counts_are ~n_bars:20 ~n_above:20))

(** Median, not mean, and the difference is load-bearing: one $1M print drags
    the mean of an otherwise $50 series above the ceiling, and the rule is about
    whether the BULK of the series is mis-scaled. (A single bad print is
    V15/Splice_detector's question, not this module's.) *)
let test_one_outlier_bar_does_not_flag_the_series _ =
  assert_that
    (_classify ~symbol:"SPIKE" (_series (_repeat 59 50.0 @ [ 1_000_000.0 ])))
    is_none

(** V18's phantom-print rule is deliberately NOT reimplemented here: a bar
    moving >90% against its predecessor has a ratio far outside
    [Splice_detector]'s [[0.4, 2.5]] band, so the splice pass already reports
    every such bar and carries the volume that tells a reuse from a repricing.
    Only the LEVEL half was ever the residual, and this test pins the
    non-coverage so it reads as a decision rather than an omission. *)
let test_zero_volume_collapse_is_not_this_modules_business _ =
  let series =
    _series (_repeat 59 100.0)
    @ [ _bar ~volume:0 ~date:(_d "2017-03-03") ~close:2.0 () ]
  in
  assert_that (_classify ~symbol:"DIP" series) is_none

(* ---- the accepted false positive, inherited from V18 -------------------- *)

(* BRK.A: monotonically climbing, every bar traded, no seam — a real instrument
   whose only unusual property is its price. *)
let _brk_a_series =
  _series (List.init 60 ~f:(fun i -> 250_000.0 +. (1_000.0 *. Float.of_int i)))

(** {b The accepted false positive, pinned.} A legitimately expensive instrument
    DOES flag, exactly as it does in V18 — no test on the price series alone
    separates "expensive share class" from "mis-mapped listing". It lands in
    [Whole_window], the class with no cut available, which is precisely why this
    module reports and never edits: an automatic drop here would delete a real
    company. The narrowing that would have suppressed it — require a large
    max/min ratio — was argued down in V18's review on false-negative grounds,
    and [test_whole_window_is_flagged] is the case that proves that argument
    right: a uniformly mis-scaled series has a max/min ratio near 1.0 too. *)
let test_a_legitimately_expensive_instrument_flags _ =
  assert_that
    (_classify ~symbol:"BRK-A" _brk_a_series)
    (is_some_and (_klass_is Class.Whole_window))

(** ...and the escape hatch for it: the ceiling is config, so raising it above
    the instrument's level silences the rule for that build without disabling
    the check for every other symbol. *)
let test_ceiling_comes_from_config _ =
  let config = { _armed with Config.median_close_max = 1_000_000.0 } in
  assert_that (_classify ~config ~symbol:"BRK-A" _brk_a_series) is_none;
  assert_that (_classify ~config ~symbol:"MEL" _mel_window) is_none

(* ---- statistics hygiene ------------------------------------------------- *)

(** A non-finite close is excluded from EVERY field, not merely from the median:
    [Float.compare] orders nan below every real price, so leaving them in would
    report nan as the series minimum. The span therefore describes the
    finite-close bars too — here bars 1..25, not the nan-padded 0..29. *)
let test_non_finite_closes_are_excluded_from_every_field _ =
  let closes = (Float.nan :: _repeat 25 73_566.74) @ _repeat 4 Float.nan in
  assert_that
    (_classify ~symbol:"NANNY" (_series closes))
    (is_some_and
       (all_of
          [
            _klass_is Class.Whole_window;
            _counts_are ~n_bars:25 ~n_above:25;
            field
              (fun (f : Series_level.finding) -> f.first_date)
              (equal_to ~cmp:Date.equal (_d "2017-01-03"));
            field
              (fun (f : Series_level.finding) -> f.last_date)
              (equal_to ~cmp:Date.equal (_d "2017-01-27"));
            field
              (fun (f : Series_level.finding) -> f.min_close)
              (float_equal 73_566.74);
          ]))

(** Bar order does not change the row: the statistics are order-independent and
    the span is the earliest and latest date rather than the first and last
    element. A caller that hands over unsorted bars cannot get a different
    answer from one that does not. *)
let test_bar_order_does_not_change_the_finding _ =
  assert_that
    (_classify ~symbol:"MEL" (List.rev _mel_window))
    (is_some_and
       (equal_to ~cmp:Series_level.equal_finding
          (_classify_exn ~symbol:"MEL" _mel_window)))

(* ---- the report --------------------------------------------------------- *)

let _report_findings =
  [
    _classify_exn ~symbol:"SYMA" (_series (_repeat 20 50_000.0));
    _classify_exn ~symbol:"SYMB"
      (_series ~start:(_d "2018-01-02") (_repeat 15 50_000.0 @ _repeat 5 20.0));
  ]

let test_to_csv_renders_every_column _ =
  assert_that
    (Series_level.to_csv _report_findings)
    (equal_to
       (Series_level.csv_header
      ^ "\n\
         SYMA,whole_window,20,2017-01-02,2017-01-21,50000.0000,50000.0000,50000.0000,20\n\
         SYMB,mixed_scale,20,2018-01-02,2018-01-21,50000.0000,20.0000,50000.0000,15\n"
       ))

(** An empty report renders as the header alone — positive evidence that the
    pass ran and found nothing, rather than an absent file. *)
let test_empty_report_is_the_header_alone _ =
  assert_that (Series_level.to_csv [])
    (equal_to (Series_level.csv_header ^ "\n"))

let test_summary_counts_each_class _ =
  assert_that
    (Series_level.summary _report_findings)
    (equal_to "series_level: 2 findings (1 whole_window, 1 mixed_scale)")

(** The drop candidates, separated out: [Whole_window] is the only class a
    reviewer can act on without first reading another module's report. *)
let test_whole_window_symbols_are_the_drop_candidates _ =
  assert_that
    (Series_level.whole_window_symbols _report_findings)
    (elements_are [ equal_to "SYMA" ])

let suite =
  "series_level"
  >::: [
         "whole window is flagged" >:: test_whole_window_is_flagged;
         "mel shape is flagged as mixed scale"
         >:: test_mel_shape_is_flagged_as_mixed_scale;
         "an ordinary series is not flagged"
         >:: test_an_ordinary_series_is_not_flagged;
         "default config is a no op" >:: test_default_config_is_a_no_op;
         "short series is not classified"
         >:: test_short_series_is_not_classified;
         "one outlier bar does not flag the series"
         >:: test_one_outlier_bar_does_not_flag_the_series;
         "zero volume collapse is not this modules business"
         >:: test_zero_volume_collapse_is_not_this_modules_business;
         "a legitimately expensive instrument flags"
         >:: test_a_legitimately_expensive_instrument_flags;
         "ceiling comes from config" >:: test_ceiling_comes_from_config;
         "non finite closes are excluded from every field"
         >:: test_non_finite_closes_are_excluded_from_every_field;
         "bar order does not change the finding"
         >:: test_bar_order_does_not_change_the_finding;
         "to csv renders every column" >:: test_to_csv_renders_every_column;
         "empty report is the header alone"
         >:: test_empty_report_is_the_header_alone;
         "summary counts each class" >:: test_summary_counts_each_class;
         "whole window symbols are the drop candidates"
         >:: test_whole_window_symbols_are_the_drop_candidates;
       ]

let () = run_test_tt_main suite
