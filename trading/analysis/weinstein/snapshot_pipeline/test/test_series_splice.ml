open Core
open OUnit2
open Matchers
module Series_splice = Snapshot_pipeline.Series_splice
module Config = Series_splice.Config
module Exceptions = Series_splice.Exceptions
module Class = Series_splice.Class
module Action = Series_splice.Action

let _d s = Date.of_string s
let _start = _d "2004-12-15"
let _day i = Date.add_days _start i

let _bar ~date ~close =
  Types.Daily_price.make ~date ~open_price:close ~high_price:close
    ~low_price:close ~close_price:close ~volume:1_000 ~adjusted_close:close ()

(* One bar per calendar day from [_start]; the rule keys on splice dates and
   bar order, never on weekday. *)
let _series closes =
  List.mapi closes ~f:(fun i close -> _bar ~date:(_day i) ~close)

let _apply ?(config = Config.default) ?(exceptions = Exceptions.empty)
    ?(symbol = "CHS") ~splices bars =
  Series_splice.apply config ~exceptions ~symbol ~splices bars

let _date_is d =
  field (fun (b : Types.Daily_price.t) -> b.date) (equal_to ~cmp:Date.equal d)

let _bars_dated days =
  elements_are (List.map days ~f:(fun i -> _date_is (_day i)))

let _finding_is ~klass ~action ~n_findings ~cut_after ~n_dropped =
  all_of
    [
      field
        (fun (f : Series_splice.finding) -> f.klass)
        (equal_to ~cmp:Class.equal klass);
      field
        (fun (f : Series_splice.finding) -> f.action)
        (equal_to ~cmp:Action.equal action);
      field
        (fun (f : Series_splice.finding) -> f.n_findings)
        (equal_to n_findings);
      field
        (fun (f : Series_splice.finding) -> f.cut_after)
        (equal_to ~cmp:(Option.equal Date.equal) cut_after);
      field
        (fun (f : Series_splice.finding) -> f.n_dropped)
        (equal_to n_dropped);
    ]

let _five = _series [ 10.0; 11.0; 12.0; 40.0; 41.0 ]

(* CHS (#2646): two findings, 2001-12-19 and 2004-12-20. The series is cut at
   the LAST one, so the earlier issuer's bars go and the later issuer's stay. *)
let test_reuse_cuts_at_the_last_splice _ =
  assert_that
    (_apply ~splices:[ _day 1; _day 3 ] _five)
    (pair
       (is_some_and (_bars_dated [ 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Cut_at ~n_findings:2
             ~cut_after:(Some (_day 2))
             ~n_dropped:3)))

(* Splice order is the detector's, not ours: the same two dates reversed (and
   duplicated) must cut at the same place. *)
let test_splices_are_order_and_duplicate_insensitive _ =
  assert_that
    (_apply ~splices:[ _day 3; _day 1; _day 3 ] _five)
    (pair
       (is_some_and (_bars_dated [ 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Cut_at ~n_findings:2
             ~cut_after:(Some (_day 2))
             ~n_dropped:3)))

(* The cut keeps the LATER segment, so the series' last bar — the delisting
   evidence [active_through] is derived from — is the same before and after. *)
let test_cut_preserves_the_series_end _ =
  assert_that
    (Option.bind (fst (_apply ~splices:[ _day 3 ] _five)) ~f:List.last)
    (is_some_and (_date_is (_day 4)))

(* ICT 589 findings / CLE 412 / MEL 98: two issuers shuffled together, so no
   date splits them and the whole symbol goes. *)
let test_interleaved_series_is_dropped _ =
  let bars = _series (List.init 25 ~f:(fun i -> 10.0 +. Float.of_int i)) in
  assert_that
    (_apply ~symbol:"ICT" ~splices:(List.init 20 ~f:_day) bars)
    (pair is_none
       (is_some_and
          (_finding_is ~klass:Class.Interleaved ~action:Action.Dropped
             ~n_findings:20 ~cut_after:None ~n_dropped:25)))

(* The boundary is inclusive on the drop side: exactly [max_findings_keep]
   findings is interleaved, one fewer is a cuttable reuse. *)
let test_one_below_max_findings_keep_is_cut _ =
  let bars = _series (List.init 25 ~f:(fun i -> 10.0 +. Float.of_int i)) in
  assert_that
    (_apply ~symbol:"ICT" ~splices:(List.init 19 ~f:_day) bars)
    (pair
       (is_some_and (size_is 7))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Cut_at ~n_findings:19
             ~cut_after:(Some (_day 17))
             ~n_dropped:18)))

(* AGR: adjusted 18,737.14 -> 14.41 (raw 73,566 -> 33.94). The earlier segment
   is mis-scaled rather than a different issuer — same cut, distinct class so
   the report names it. *)
let test_agr_prefix_misscale_is_cut_and_named _ =
  assert_that
    (_apply ~symbol:"AGR"
       ~splices:[ _day 2 ]
       (_series [ 73566.0; 70000.0; 33.94; 34.0 ]))
    (pair
       (is_some_and (_bars_dated [ 2; 3 ]))
       (is_some_and
          (_finding_is ~klass:Class.Prefix_misscale ~action:Action.Cut_at
             ~n_findings:1
             ~cut_after:(Some (_day 1))
             ~n_dropped:2)))

let test_clean_series_is_untouched_and_unreported _ =
  assert_that (_apply ~splices:[] _five)
    (pair (is_some_and (_bars_dated [ 0; 1; 2; 3; 4 ])) is_none)

(* [-no-splice-action]: #2649's behaviour. Classified and reported, nothing
   edited — and the report still names the cut an armed build would make. *)
let test_report_only_classifies_without_editing _ =
  assert_that
    (_apply
       ~config:{ Config.default with act = false }
       ~splices:[ _day 1; _day 3 ]
       _five)
    (pair
       (is_some_and (_bars_dated [ 0; 1; 2; 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Kept ~n_findings:2
             ~cut_after:(Some (_day 2))
             ~n_dropped:0)))

let test_keep_exception_overrides_the_cut _ =
  assert_that
    (_apply
       ~exceptions:(Exceptions.of_rules [ Exceptions.Keep "CHS" ])
       ~splices:[ _day 3 ]
       _five)
    (pair
       (is_some_and (_bars_dated [ 0; 1; 2; 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Kept_by_exception
             ~n_findings:1
             ~cut_after:(Some (_day 2))
             ~n_dropped:0)))

(* A reviewer may drop a symbol the rule would have kept — including one with
   no splices at all, which is why a [Clean] symbol still gets a report row
   when an exception names it. *)
let test_drop_exception_overrides_a_clean_series _ =
  assert_that
    (_apply
       ~exceptions:(Exceptions.of_rules [ Exceptions.Drop "CHS" ])
       ~splices:[] _five)
    (pair is_none
       (is_some_and
          (_finding_is ~klass:Class.Clean ~action:Action.Dropped_by_exception
             ~n_findings:0 ~cut_after:None ~n_dropped:5)))

let test_cut_at_exception_overrides_the_rules_date _ =
  assert_that
    (_apply
       ~exceptions:(Exceptions.of_rules [ Exceptions.Cut_at ("CHS", _day 1) ])
       ~splices:[ _day 3 ]
       _five)
    (pair
       (is_some_and (_bars_dated [ 1; 2; 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Cut_by_exception
             ~n_findings:1
             ~cut_after:(Some (_day 0))
             ~n_dropped:1)))

(* A zero-bar manifest entry is exactly what the drop rule exists to avoid, so
   a cut past the end of the series drops the symbol instead. *)
let test_cut_past_the_series_end_drops_the_symbol _ =
  assert_that
    (_apply
       ~exceptions:(Exceptions.of_rules [ Exceptions.Cut_at ("CHS", _day 99) ])
       ~splices:[ _day 3 ]
       _five)
    (pair is_none
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Cut_by_exception
             ~n_findings:1
             ~cut_after:(Some (_day 4))
             ~n_dropped:5)))

let test_keep_from_is_inclusive_of_its_own_date _ =
  assert_that (Series_splice.keep_from (_day 3) _five) (_bars_dated [ 3; 4 ])

(* The plan the scanner hands the builder carries only the cuts that actually
   happened — a report-only run must plan nothing. *)
let test_cut_plan_and_dropped_symbols_read_the_actions _ =
  let findings =
    List.filter_map
      [
        (Config.default, "CHS", [ _day 3 ]);
        ({ Config.default with act = false }, "PFSW", [ _day 3 ]);
        (Config.default, "ICT", List.init 20 ~f:_day);
      ]
      ~f:(fun (config, symbol, splices) ->
        snd (_apply ~config ~symbol ~splices _five))
  in
  assert_that
    ( Map.to_alist (Series_splice.cut_plan findings),
      Series_splice.dropped_symbols findings )
    (pair
       (elements_are
          [ pair (equal_to "CHS") (equal_to ~cmp:Date.equal (_day 3)) ])
       (elements_are [ equal_to "ICT" ]))

(* [act = false] short-circuits AHEAD of the exceptions lookup. Without that
   guard a [-no-splice-action] run would honour [Drop CHS] and delete the
   symbol, breaking "not one bar changed" for the report-only mode. The report
   still names the cut the rule would have made. *)
let test_report_only_ignores_a_drop_exception _ =
  assert_that
    (_apply
       ~config:{ Config.default with act = false }
       ~exceptions:(Exceptions.of_rules [ Exceptions.Drop "CHS" ])
       ~splices:[ _day 3 ]
       _five)
    (pair
       (is_some_and (_bars_dated [ 0; 1; 2; 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Kept ~n_findings:1
             ~cut_after:(Some (_day 2))
             ~n_dropped:0)))

(* Same guard, the other overriding rule: a [Cut_at] a reviewer recorded must
   not move a single bar while the pass is report-only. The symbol is [Clean],
   so the row exists only because an exception names it. *)
let test_report_only_ignores_a_cut_at_exception _ =
  assert_that
    (_apply
       ~config:{ Config.default with act = false }
       ~exceptions:(Exceptions.of_rules [ Exceptions.Cut_at ("CHS", _day 1) ])
       ~splices:[] _five)
    (pair
       (is_some_and (_bars_dated [ 0; 1; 2; 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Clean ~action:Action.Kept ~n_findings:0
             ~cut_after:None ~n_dropped:0)))

(* "A symbol named twice keeps the last rule" — an operator appends a
   correction rather than deleting the line above it. *)
let test_of_rules_keeps_the_last_rule_for_a_symbol _ =
  assert_that
    (Exceptions.find
       (Exceptions.of_rules [ Exceptions.Keep "CHS"; Exceptions.Drop "CHS" ])
       ~symbol:"CHS")
    (is_some_and (equal_to ~cmp:Exceptions.equal_rule (Exceptions.Drop "CHS")))

let test_csv_renders_the_documented_columns _ =
  assert_that
    (Series_splice.to_csv
       (List.filter_map
          [ ("CHS", [ _day 3 ]); ("ICT", List.init 20 ~f:_day) ]
          ~f:(fun (symbol, splices) -> snd (_apply ~symbol ~splices _five))))
    (equal_to
       (Series_splice.csv_header
      ^ "\nCHS,reuse,1,2004-12-17,3,cut_at\nICT,interleaved,20,,5,dropped\n"))

let test_empty_csv_is_the_header_alone _ =
  assert_that (Series_splice.to_csv [])
    (equal_to (Series_splice.csv_header ^ "\n"))

let test_summary_counts_by_action _ =
  assert_that
    (Series_splice.summary
       (List.filter_map
          [
            ("CHS", [ _day 3 ]);
            ("ICT", List.init 20 ~f:_day);
            ("AGR", [ _day 2 ]);
          ]
          ~f:(fun (symbol, splices) -> snd (_apply ~symbol ~splices _five))))
    (equal_to
       "series_splice: 3 findings (1 dropped, 2 cut_at, 0 kept, 0 by_exception)")

let suite =
  "series_splice"
  >::: [
         "reuse_cuts_at_the_last_splice" >:: test_reuse_cuts_at_the_last_splice;
         "splices_are_order_and_duplicate_insensitive"
         >:: test_splices_are_order_and_duplicate_insensitive;
         "cut_preserves_the_series_end" >:: test_cut_preserves_the_series_end;
         "interleaved_series_is_dropped" >:: test_interleaved_series_is_dropped;
         "one_below_max_findings_keep_is_cut"
         >:: test_one_below_max_findings_keep_is_cut;
         "agr_prefix_misscale_is_cut_and_named"
         >:: test_agr_prefix_misscale_is_cut_and_named;
         "clean_series_is_untouched_and_unreported"
         >:: test_clean_series_is_untouched_and_unreported;
         "report_only_classifies_without_editing"
         >:: test_report_only_classifies_without_editing;
         "keep_exception_overrides_the_cut"
         >:: test_keep_exception_overrides_the_cut;
         "drop_exception_overrides_a_clean_series"
         >:: test_drop_exception_overrides_a_clean_series;
         "cut_at_exception_overrides_the_rules_date"
         >:: test_cut_at_exception_overrides_the_rules_date;
         "cut_past_the_series_end_drops_the_symbol"
         >:: test_cut_past_the_series_end_drops_the_symbol;
         "keep_from_is_inclusive_of_its_own_date"
         >:: test_keep_from_is_inclusive_of_its_own_date;
         "cut_plan_and_dropped_symbols_read_the_actions"
         >:: test_cut_plan_and_dropped_symbols_read_the_actions;
         "report_only_ignores_a_drop_exception"
         >:: test_report_only_ignores_a_drop_exception;
         "report_only_ignores_a_cut_at_exception"
         >:: test_report_only_ignores_a_cut_at_exception;
         "of_rules_keeps_the_last_rule_for_a_symbol"
         >:: test_of_rules_keeps_the_last_rule_for_a_symbol;
         "csv_renders_the_documented_columns"
         >:: test_csv_renders_the_documented_columns;
         "empty_csv_is_the_header_alone" >:: test_empty_csv_is_the_header_alone;
         "summary_counts_by_action" >:: test_summary_counts_by_action;
       ]

let () = run_test_tt_main suite
