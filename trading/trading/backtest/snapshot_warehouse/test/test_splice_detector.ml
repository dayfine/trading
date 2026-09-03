open Core
open OUnit2
open Matchers
module Sd = Splice_detector

(* ---- builders ---------------------------------------------------------- *)

(* A bar carrying an explicit raw close and adjusted close. The two are equal by
   default (no corporate action in the window), so a fixture only spells out
   [raw] when it is testing the split path, which reads both. *)
let bar ~date ~adj ?raw ?(volume = 1_000_000) () : Types.Daily_price.t =
  let close_price = Option.value raw ~default:adj in
  Types.Daily_price.make ~date:(Date.of_string date) ~open_price:close_price
    ~high_price:close_price ~low_price:close_price ~close_price ~volume
    ~adjusted_close:adj ()

let series symbol bars : Sd.series = { symbol; bars = Array.of_list bars }
let armed = { Sd.Config.default with enabled = true }
let detect ?(config = armed) s = (Sd.detect config [ s ]).findings

(* ---- the #2646 specimen ------------------------------------------------- *)

(* CHS 2004-12-17 -> 2004-12-20: adjusted close 4.0693 -> 15.8803 (x3.902),
   raw close 11.2875 -> 45.16 (x4.001). The adjustment factor barely moves, so
   no split is recoverable — this is a different security under a recycled
   ticker. Volume ~7.4M -> ~1.2M. *)
let chs =
  series "CHS"
    [
      bar ~date:"2004-12-16" ~adj:4.06 ~raw:11.26 ~volume:3_100_000 ();
      bar ~date:"2004-12-17" ~adj:4.0693 ~raw:11.2875 ~volume:7_371_600 ();
      bar ~date:"2004-12-20" ~adj:15.8803 ~raw:45.16 ~volume:1_155_600 ();
    ]

let test_flags_chs_splice _ =
  assert_that (detect chs)
    (elements_are
       [
         all_of
           [
             field (fun (f : Sd.finding) -> f.symbol) (equal_to "CHS");
             field
               (fun (f : Sd.finding) -> f.date)
               (equal_to (Date.of_string "2004-12-20"));
             field
               (fun (f : Sd.finding) -> f.ratio)
               (float_equal ~epsilon:1e-3 3.902);
             field (fun (f : Sd.finding) -> f.prev_volume) (equal_to 7_371_600);
             field (fun (f : Sd.finding) -> f.volume) (equal_to 1_155_600);
           ];
       ])

(* R1: the default config is a no-op — the same series yields nothing. *)
let test_disabled_is_noop _ =
  assert_that (Sd.detect Sd.Config.default [ chs ]).findings (size_is 0)

(* ---- clean series ------------------------------------------------------- *)

let test_clean_series_has_no_findings _ =
  let s =
    series "CALM"
      [
        bar ~date:"2020-06-01" ~adj:10.0 ();
        bar ~date:"2020-06-02" ~adj:11.5 ();
        bar ~date:"2020-06-03" ~adj:9.2 ();
        bar ~date:"2020-06-04" ~adj:14.0 ();
      ]
  in
  assert_that (detect s) (size_is 0)

(* The first bar has no predecessor, so a lone bar can never be a finding
   however extreme its close. *)
let test_single_bar_series_has_no_findings _ =
  assert_that
    (detect (series "LONE" [ bar ~date:"2020-06-01" ~adj:999.0 () ]))
    (size_is 0)

(* ---- splits ------------------------------------------------------------- *)

(* A correctly adjusted 4:1 split: the raw close falls 400 -> 100 while the
   adjusted close is continuous. It is not even a candidate — the adjusted
   ratio is 1.0 — so it stays clean with the split guard DISABLED too, which is
   the property that lets this detector run on the whole warehouse. *)
let adjusted_split =
  series "SPLIT4"
    [
      bar ~date:"2020-08-28" ~adj:100.0 ~raw:400.0 ();
      bar ~date:"2020-08-31" ~adj:100.0 ~raw:100.0 ();
    ]

let test_adjusted_split_is_not_a_candidate _ =
  assert_that (detect adjusted_split) (size_is 0)

let test_adjusted_split_clean_even_without_the_guard _ =
  let config = { armed with skip_split_days = false } in
  assert_that (detect ~config adjusted_split) (size_is 0)

(* A 3:1 split whose back-roll lands one day late: the raw close drifts
   30.0 -> 30.5 while the ADJUSTED close jumps 10.0 -> 30.5 (x3.05). That is a
   candidate by ratio, but raw-vs-adjusted divergence snaps to exactly 3.0, so
   [Split_detector] recovers it and the guard suppresses it. *)
let late_back_roll =
  series "LATE3"
    [
      bar ~date:"2020-08-28" ~adj:10.0 ~raw:30.0 ();
      bar ~date:"2020-08-31" ~adj:30.5 ~raw:30.5 ();
    ]

let test_split_day_suppressed_by_guard _ =
  assert_that (detect late_back_roll) (size_is 0)

(* The same bars with the guard off ARE reported — which is what proves the
   guard, not the ratio band, is doing the suppression above. *)
let test_split_day_reported_without_the_guard _ =
  let config = { armed with skip_split_days = false } in
  assert_that
    (detect ~config late_back_roll)
    (elements_are
       [
         field
           (fun (f : Sd.finding) -> f.ratio)
           (float_equal ~epsilon:1e-3 3.05);
       ])

(* ---- band boundaries ---------------------------------------------------- *)

let two_bar_ratio ~adj_from ~adj_to =
  series "EDGE"
    [
      bar ~date:"2020-06-01" ~adj:adj_from ();
      bar ~date:"2020-06-02" ~adj:adj_to ();
    ]

(* Exactly [max_ratio] (10.0 / 4.0 = 2.5) is inside the band. *)
let test_ratio_at_upper_bound_is_clean _ =
  assert_that (detect (two_bar_ratio ~adj_from:4.0 ~adj_to:10.0)) (size_is 0)

let test_ratio_just_past_upper_bound_flags _ =
  assert_that (detect (two_bar_ratio ~adj_from:4.0 ~adj_to:10.1)) (size_is 1)

(* Exactly [min_ratio] (4.0 / 10.0 = 0.4) is inside the band. *)
let test_ratio_at_lower_bound_is_clean _ =
  assert_that (detect (two_bar_ratio ~adj_from:10.0 ~adj_to:4.0)) (size_is 0)

let test_ratio_just_past_lower_bound_flags _ =
  assert_that (detect (two_bar_ratio ~adj_from:10.0 ~adj_to:3.9)) (size_is 1)

(* The band is config-routed, not a literal: widening the ceiling past the
   3.902 CHS ratio makes the same series clean. *)
let test_band_is_config_routed _ =
  let config = { armed with max_ratio = 5.0 } in
  assert_that (detect ~config chs) (size_is 0)

(* ---- degenerate closes -------------------------------------------------- *)

(* A zero prior adjusted close has no meaningful ratio. It is a data defect of a
   different kind and is passed over rather than reported as a splice. *)
let test_non_positive_prior_close_is_passed_over _ =
  assert_that (detect (two_bar_ratio ~adj_from:0.0 ~adj_to:10.0)) (size_is 0)

(* ---- ordering + rendering ----------------------------------------------- *)

let test_findings_sorted_by_symbol_then_date _ =
  let s sym d =
    series sym [ bar ~date:d ~adj:1.0 (); bar ~date:"2020-07-01" ~adj:9.0 () ]
  in
  let report = Sd.detect armed [ s "ZZZ" "2020-06-01"; s "AAA" "2020-06-01" ] in
  assert_that report.findings
    (elements_are
       [
         field (fun (f : Sd.finding) -> f.symbol) (equal_to "AAA");
         field (fun (f : Sd.finding) -> f.symbol) (equal_to "ZZZ");
       ])

(* The CSV matches the committed #2646 scan's columns + precision byte for
   byte, so a build sidecar can be diffed against
   dev/experiments/arc-rerun-2026-09-01/results/splice-scan.csv directly. *)
let test_to_csv_matches_scan_format _ =
  assert_that
    (Sd.to_csv (Sd.detect armed [ chs ]))
    (equal_to
       "symbol,date,prev_adj_close,adj_close,ratio,prev_volume,volume\n\
        CHS,2004-12-20,4.0693,15.8803,3.902,7371600,1155600\n")

let test_to_csv_of_empty_report_is_header_only _ =
  assert_that
    (Sd.to_csv (Sd.detect Sd.Config.default [ chs ]))
    (equal_to "symbol,date,prev_adj_close,adj_close,ratio,prev_volume,volume\n")

let test_summary_counts_findings_and_symbols _ =
  assert_that
    (Sd.summary (Sd.detect armed [ chs ]))
    (equal_to "splice detector: 1 splice(s) across 1 symbol(s)")

let suite =
  "splice_detector"
  >::: [
         "flags_chs_splice" >:: test_flags_chs_splice;
         "disabled_is_noop" >:: test_disabled_is_noop;
         "clean_series_has_no_findings" >:: test_clean_series_has_no_findings;
         "single_bar_series_has_no_findings"
         >:: test_single_bar_series_has_no_findings;
         "adjusted_split_is_not_a_candidate"
         >:: test_adjusted_split_is_not_a_candidate;
         "adjusted_split_clean_even_without_the_guard"
         >:: test_adjusted_split_clean_even_without_the_guard;
         "split_day_suppressed_by_guard" >:: test_split_day_suppressed_by_guard;
         "split_day_reported_without_the_guard"
         >:: test_split_day_reported_without_the_guard;
         "ratio_at_upper_bound_is_clean" >:: test_ratio_at_upper_bound_is_clean;
         "ratio_just_past_upper_bound_flags"
         >:: test_ratio_just_past_upper_bound_flags;
         "ratio_at_lower_bound_is_clean" >:: test_ratio_at_lower_bound_is_clean;
         "ratio_just_past_lower_bound_flags"
         >:: test_ratio_just_past_lower_bound_flags;
         "band_is_config_routed" >:: test_band_is_config_routed;
         "non_positive_prior_close_is_passed_over"
         >:: test_non_positive_prior_close_is_passed_over;
         "findings_sorted_by_symbol_then_date"
         >:: test_findings_sorted_by_symbol_then_date;
         "to_csv_matches_scan_format" >:: test_to_csv_matches_scan_format;
         "to_csv_of_empty_report_is_header_only"
         >:: test_to_csv_of_empty_report_is_header_only;
         "summary_counts_findings_and_symbols"
         >:: test_summary_counts_findings_and_symbols;
       ]

let () = run_test_tt_main suite
