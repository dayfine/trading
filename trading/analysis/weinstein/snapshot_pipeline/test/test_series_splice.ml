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

let _flat n close = List.init n ~f:(fun _ -> close)

(* The short-tail guard is off for the five-bar fixtures below: they pin the
   classification and cut mechanics, and no five-bar series can clear a
   250-trading-day tail. The tests that pin the guard itself set
   [min_kept_bars] explicitly, and the long fixtures use [Config.default]. *)
let _no_guard = { Config.default with min_kept_bars = 1 }

let _apply ?(config = _no_guard) ?(exceptions = Exceptions.empty)
    ?(symbol = "CHS") ~splices bars =
  Series_splice.apply config ~exceptions ~symbol ~splices bars

let _date_is d =
  field (fun (b : Types.Daily_price.t) -> b.date) (equal_to ~cmp:Date.equal d)

let _bars_dated days =
  elements_are (List.map days ~f:(fun i -> _date_is (_day i)))

(* Long fixtures are checked by extent rather than element-by-element: what a
   cut changes is where the series starts and how many bars survive. *)
let _bars_span ~n ~first ~last =
  all_of
    [
      size_is n;
      field (fun bs -> List.hd_exn bs) (_date_is (_day first));
      field (fun bs -> List.last_exn bs) (_date_is (_day last));
    ]

let _finding_is ~klass ~action ~n_findings ~cut_after ~n_dropped ~n_kept =
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
      field (fun (f : Series_splice.finding) -> f.n_kept) (equal_to n_kept);
    ]

let _five = _series [ 10.0; 11.0; 12.0; 40.0; 41.0 ]

(* GES (#2711): 6,805 of 6,848 bars would have gone. A take-private premium on
   the last real day trips the detector's ratio band, so the "later segment" is
   the 10-bar administrative stub and the "earlier issuer" is the company. *)
let _ges = _series (_flat 400 20.0 @ _flat 10 0.05)

(* CHS (#2646): a genuine ticker recycle — both issuers have years of bars. *)
let _chs = _series (_flat 300 12.0 @ _flat 300 47.0)

(* #2711: the blanket cut is retired. A reuse is classified and reported with
   the depth a cut WOULD have, and not one bar is edited. *)
let test_reuse_is_reported_and_left_whole _ =
  assert_that
    (_apply ~splices:[ _day 1; _day 3 ] _five)
    (pair
       (is_some_and (_bars_dated [ 0; 1; 2; 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Kept ~n_findings:2
             ~cut_after:(Some (_day 2))
             ~n_dropped:3 ~n_kept:2)))

(* Splice order is the detector's, not ours: the same two dates reversed (and
   duplicated) must report the same splice point. *)
let test_splices_are_order_and_duplicate_insensitive _ =
  assert_that
    (_apply ~splices:[ _day 3; _day 1; _day 3 ] _five)
    (pair
       (is_some_and (_bars_dated [ 0; 1; 2; 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Kept ~n_findings:2
             ~cut_after:(Some (_day 2))
             ~n_dropped:3 ~n_kept:2)))

(* The cut keeps the LATER segment, so the series' last bar — the delisting
   evidence [active_through] is derived from — is the same before and after. *)
let test_cut_preserves_the_series_end _ =
  assert_that
    (Option.bind
       (fst
          (_apply
             ~exceptions:
               (Exceptions.of_rules [ Exceptions.Cut_at ("CHS", _day 3) ])
             ~splices:[ _day 3 ]
             _five))
       ~f:List.last)
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
             ~n_findings:20 ~cut_after:None ~n_dropped:25 ~n_kept:0)))

(* The boundary is inclusive on the drop side: exactly [max_findings_keep]
   findings is interleaved and dropped, one fewer is a reported reuse. *)
let test_one_below_max_findings_keep_is_a_reported_reuse _ =
  let bars = _series (List.init 25 ~f:(fun i -> 10.0 +. Float.of_int i)) in
  assert_that
    (_apply ~symbol:"ICT" ~splices:(List.init 19 ~f:_day) bars)
    (pair
       (is_some_and (size_is 25))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Kept ~n_findings:19
             ~cut_after:(Some (_day 17))
             ~n_dropped:18 ~n_kept:7)))

(* AGR: adjusted 18,737.14 -> 14.41 (raw 73,566 -> 33.94). The earlier segment
   is a mis-scale artefact rather than a different company, so this class still
   cuts by rule where a reuse does not. *)
let test_agr_prefix_misscale_is_cut_by_rule _ =
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
             ~n_dropped:2 ~n_kept:2)))

let test_clean_series_is_untouched_and_unreported _ =
  assert_that (_apply ~splices:[] _five)
    (pair (is_some_and (_bars_dated [ 0; 1; 2; 3; 4 ])) is_none)

(* [-no-splice-action]: #2649's behaviour. Classified and reported, nothing
   edited — and the report still names the splice point. *)
let test_report_only_classifies_without_editing _ =
  assert_that
    (_apply
       ~config:{ _no_guard with act = false }
       ~splices:[ _day 1; _day 3 ]
       _five)
    (pair
       (is_some_and (_bars_dated [ 0; 1; 2; 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Kept ~n_findings:2
             ~cut_after:(Some (_day 2))
             ~n_dropped:3 ~n_kept:2)))

(* A reviewer's veto of the one class that still cuts by rule. *)
let test_keep_exception_overrides_the_misscale_cut _ =
  assert_that
    (_apply ~symbol:"AGR"
       ~exceptions:(Exceptions.of_rules [ Exceptions.Keep "AGR" ])
       ~splices:[ _day 2 ]
       (_series [ 73566.0; 70000.0; 33.94; 34.0 ]))
    (pair
       (is_some_and (_bars_dated [ 0; 1; 2; 3 ]))
       (is_some_and
          (_finding_is ~klass:Class.Prefix_misscale
             ~action:Action.Kept_by_exception ~n_findings:1
             ~cut_after:(Some (_day 1))
             ~n_dropped:2 ~n_kept:2)))

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
             ~n_findings:0 ~cut_after:None ~n_dropped:5 ~n_kept:0)))

(* #2711: an exceptions entry is the ONLY way a reuse is cut, and it may name a
   date the detector never flagged. *)
let test_cut_at_exception_is_the_only_way_a_reuse_cuts _ =
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
             ~n_dropped:1 ~n_kept:4)))

(* The short-tail guard catches a cut past the end of the series: nothing left
   is the extreme short tail, and the symbol is stored whole. *)
let test_cut_past_the_series_end_is_refused _ =
  assert_that
    (_apply
       ~exceptions:(Exceptions.of_rules [ Exceptions.Cut_at ("CHS", _day 99) ])
       ~splices:[ _day 3 ]
       _five)
    (pair
       (is_some_and (_bars_dated [ 0; 1; 2; 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Cut_refused_short_tail
             ~n_findings:1
             ~cut_after:(Some (_day 4))
             ~n_dropped:5 ~n_kept:0)))

(* With the guard switched off, a cut that leaves nothing degenerates to a drop
   rather than writing a zero-bar manifest entry. *)
let test_cut_past_the_series_end_drops_when_the_guard_is_off _ =
  assert_that
    (_apply
       ~config:{ _no_guard with min_kept_bars = 0 }
       ~exceptions:(Exceptions.of_rules [ Exceptions.Cut_at ("CHS", _day 99) ])
       ~splices:[ _day 3 ]
       _five)
    (pair is_none
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Dropped ~n_findings:1
             ~cut_after:(Some (_day 4))
             ~n_dropped:5 ~n_kept:0)))

let test_keep_from_is_inclusive_of_its_own_date _ =
  assert_that (Series_splice.keep_from (_day 3) _five) (_bars_dated [ 3; 4 ])

(* The plan the scanner hands the builder carries only the cuts that actually
   happened — a report-only reuse and a refused cut must plan nothing. *)
let test_cut_plan_and_dropped_symbols_read_the_actions _ =
  let findings =
    List.filter_map
      [
        ( _no_guard,
          "CHS",
          Exceptions.of_rules [ Exceptions.Cut_at ("CHS", _day 3) ],
          [ _day 3 ] );
        (_no_guard, "PFSW", Exceptions.empty, [ _day 3 ]);
        ( Config.default,
          "GES",
          Exceptions.of_rules [ Exceptions.Cut_at ("GES", _day 3) ],
          [ _day 3 ] );
        (_no_guard, "ICT", Exceptions.empty, List.init 20 ~f:_day);
      ]
      ~f:(fun (config, symbol, exceptions, splices) ->
        snd (_apply ~config ~symbol ~exceptions ~splices _five))
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
   still names the splice point. *)
let test_report_only_ignores_a_drop_exception _ =
  assert_that
    (_apply
       ~config:{ _no_guard with act = false }
       ~exceptions:(Exceptions.of_rules [ Exceptions.Drop "CHS" ])
       ~splices:[ _day 3 ]
       _five)
    (pair
       (is_some_and (_bars_dated [ 0; 1; 2; 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Kept ~n_findings:1
             ~cut_after:(Some (_day 2))
             ~n_dropped:3 ~n_kept:2)))

(* Same guard, the other overriding rule: a [Cut_at] a reviewer recorded must
   not move a single bar while the pass is report-only. The symbol is [Clean],
   so the row exists only because an exception names it — and with no splice
   there is no cut point, hence no depth to report. *)
let test_report_only_ignores_a_cut_at_exception _ =
  assert_that
    (_apply
       ~config:{ _no_guard with act = false }
       ~exceptions:(Exceptions.of_rules [ Exceptions.Cut_at ("CHS", _day 1) ])
       ~splices:[] _five)
    (pair
       (is_some_and (_bars_dated [ 0; 1; 2; 3; 4 ]))
       (is_some_and
          (_finding_is ~klass:Class.Clean ~action:Action.Kept ~n_findings:0
             ~cut_after:None ~n_dropped:0 ~n_kept:5)))

(* "A symbol named twice keeps the last rule" — an operator appends a
   correction rather than deleting the line above it. *)
let test_of_rules_keeps_the_last_rule_for_a_symbol _ =
  assert_that
    (Exceptions.find
       (Exceptions.of_rules [ Exceptions.Keep "CHS"; Exceptions.Drop "CHS" ])
       ~symbol:"CHS")
    (is_some_and (equal_to ~cmp:Exceptions.equal_rule (Exceptions.Drop "CHS")))

(* #2711, the motivating shape: GES's "splice" is a take-private premium on the
   last real day, so the rule must classify it, report the 400-bar depth, and
   leave the company alone. *)
let test_ges_terminal_event_is_reported_not_cut _ =
  assert_that
    (_apply ~config:Config.default ~symbol:"GES" ~splices:[ _day 400 ] _ges)
    (pair
       (is_some_and (_bars_span ~n:410 ~first:0 ~last:409))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Kept ~n_findings:1
             ~cut_after:(Some (_day 399))
             ~n_dropped:400 ~n_kept:10)))

(* Even a reviewer's explicit [cut_at] cannot delete the company: a 10-bar
   later segment is a delisting stub, which is [Series_tail]'s domain. *)
let test_ges_cut_at_exception_is_refused_by_the_short_tail_guard _ =
  assert_that
    (_apply ~config:Config.default ~symbol:"GES"
       ~exceptions:(Exceptions.of_rules [ Exceptions.Cut_at ("GES", _day 400) ])
       ~splices:[ _day 400 ]
       _ges)
    (pair
       (is_some_and (_bars_span ~n:410 ~first:0 ~last:409))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Cut_refused_short_tail
             ~n_findings:1
             ~cut_after:(Some (_day 399))
             ~n_dropped:400 ~n_kept:10)))

(* CHS is the real reuse: both issuers have years of bars, so the guard has no
   objection — but the default is still report-only. *)
let test_chs_real_reuse_is_reported_by_default _ =
  assert_that
    (_apply ~config:Config.default ~symbol:"CHS" ~splices:[ _day 300 ] _chs)
    (pair
       (is_some_and (_bars_span ~n:600 ~first:0 ~last:599))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Kept ~n_findings:1
             ~cut_after:(Some (_day 299))
             ~n_dropped:300 ~n_kept:300)))

let test_chs_cuts_under_a_cut_at_exception _ =
  assert_that
    (_apply ~config:Config.default ~symbol:"CHS"
       ~exceptions:(Exceptions.of_rules [ Exceptions.Cut_at ("CHS", _day 300) ])
       ~splices:[ _day 300 ]
       _chs)
    (pair
       (is_some_and (_bars_span ~n:300 ~first:300 ~last:599))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Cut_by_exception
             ~n_findings:1
             ~cut_after:(Some (_day 299))
             ~n_dropped:300 ~n_kept:300)))

let test_chs_drops_under_a_drop_exception _ =
  assert_that
    (_apply ~config:Config.default ~symbol:"CHS"
       ~exceptions:(Exceptions.of_rules [ Exceptions.Drop "CHS" ])
       ~splices:[ _day 300 ]
       _chs)
    (pair is_none
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Dropped_by_exception
             ~n_findings:1
             ~cut_after:(Some (_day 299))
             ~n_dropped:600 ~n_kept:0)))

(* The guard covers the rule's own cut too: a mis-scaled prefix followed by a
   ten-bar tail is not worth keeping either. *)
let test_prefix_misscale_with_a_short_tail_is_refused _ =
  assert_that
    (_apply ~config:Config.default ~symbol:"AGR"
       ~splices:[ _day 300 ]
       (_series (_flat 300 73566.0 @ _flat 10 33.94)))
    (pair
       (is_some_and (_bars_span ~n:310 ~first:0 ~last:309))
       (is_some_and
          (_finding_is ~klass:Class.Prefix_misscale
             ~action:Action.Cut_refused_short_tail ~n_findings:1
             ~cut_after:(Some (_day 299))
             ~n_dropped:300 ~n_kept:10)))

(* The boundary is inclusive: exactly [min_kept_bars] survives the guard. *)
let test_exactly_min_kept_bars_is_cut _ =
  assert_that
    (_apply ~config:Config.default ~symbol:"CHS"
       ~exceptions:(Exceptions.of_rules [ Exceptions.Cut_at ("CHS", _day 350) ])
       ~splices:[ _day 300 ]
       _chs)
    (pair
       (is_some_and (_bars_span ~n:250 ~first:350 ~last:599))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Cut_by_exception
             ~n_findings:1
             ~cut_after:(Some (_day 349))
             ~n_dropped:350 ~n_kept:250)))

let test_one_below_min_kept_bars_is_refused _ =
  assert_that
    (_apply ~config:Config.default ~symbol:"CHS"
       ~exceptions:(Exceptions.of_rules [ Exceptions.Cut_at ("CHS", _day 351) ])
       ~splices:[ _day 300 ]
       _chs)
    (pair
       (is_some_and (_bars_span ~n:600 ~first:0 ~last:599))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Cut_refused_short_tail
             ~n_findings:1
             ~cut_after:(Some (_day 350))
             ~n_dropped:351 ~n_kept:249)))

(* The depth a reviewer reads out of the sidecar instead of re-deriving it from
   the bar store (#2711 item 3): non-zero under [-no-splice-action] too. *)
let test_report_only_carries_the_would_be_cut_depth _ =
  assert_that
    (_apply
       ~config:{ Config.default with act = false }
       ~symbol:"CHS"
       ~splices:[ _day 300 ]
       _chs)
    (pair
       (is_some_and (_bars_span ~n:600 ~first:0 ~last:599))
       (is_some_and
          (_finding_is ~klass:Class.Reuse ~action:Action.Kept ~n_findings:1
             ~cut_after:(Some (_day 299))
             ~n_dropped:300 ~n_kept:300)))

(* One trading year, the documented default the guard is calibrated to. *)
let test_default_min_kept_bars_is_one_trading_year _ =
  assert_that Config.default.min_kept_bars (equal_to 250)

let test_csv_renders_the_documented_columns _ =
  assert_that
    (Series_splice.to_csv
       (List.filter_map
          [
            ("CHS", _no_guard, [ _day 3 ]);
            ("AGR", _no_guard, [ _day 2 ]);
            ("ICT", _no_guard, List.init 20 ~f:_day);
          ]
          ~f:(fun (symbol, config, splices) ->
            snd
              (_apply ~config ~symbol ~splices
                 (_series [ 73566.0; 70000.0; 33.94; 34.0; 35.0 ])))))
    (equal_to
       (Series_splice.csv_header
      ^ "\n\
         CHS,reuse,1,2004-12-17,3,2,kept\n\
         AGR,prefix_misscale,1,2004-12-16,2,3,cut_at\n\
         ICT,interleaved,20,,5,0,dropped\n"))

let test_empty_csv_is_the_header_alone _ =
  assert_that (Series_splice.to_csv [])
    (equal_to (Series_splice.csv_header ^ "\n"))

let test_summary_counts_by_action _ =
  assert_that
    (Series_splice.summary
       (List.filter_map
          [
            ("CHS", _no_guard, Exceptions.empty, [ _day 3 ]);
            ("AGR", _no_guard, Exceptions.empty, [ _day 2 ]);
            ("ICT", _no_guard, Exceptions.empty, List.init 20 ~f:_day);
            ( "GES",
              Config.default,
              Exceptions.of_rules [ Exceptions.Cut_at ("GES", _day 3) ],
              [ _day 3 ] );
          ]
          ~f:(fun (symbol, config, exceptions, splices) ->
            snd
              (_apply ~config ~symbol ~exceptions ~splices
                 (_series [ 73566.0; 70000.0; 33.94; 34.0; 35.0 ])))))
    (equal_to
       "series_splice: 4 findings (1 dropped, 1 cut_at, 1 kept, 1 refused, 0 \
        by_exception)")

let suite =
  "series_splice"
  >::: [
         "reuse_is_reported_and_left_whole"
         >:: test_reuse_is_reported_and_left_whole;
         "splices_are_order_and_duplicate_insensitive"
         >:: test_splices_are_order_and_duplicate_insensitive;
         "cut_preserves_the_series_end" >:: test_cut_preserves_the_series_end;
         "interleaved_series_is_dropped" >:: test_interleaved_series_is_dropped;
         "one_below_max_findings_keep_is_a_reported_reuse"
         >:: test_one_below_max_findings_keep_is_a_reported_reuse;
         "agr_prefix_misscale_is_cut_by_rule"
         >:: test_agr_prefix_misscale_is_cut_by_rule;
         "clean_series_is_untouched_and_unreported"
         >:: test_clean_series_is_untouched_and_unreported;
         "report_only_classifies_without_editing"
         >:: test_report_only_classifies_without_editing;
         "keep_exception_overrides_the_misscale_cut"
         >:: test_keep_exception_overrides_the_misscale_cut;
         "drop_exception_overrides_a_clean_series"
         >:: test_drop_exception_overrides_a_clean_series;
         "cut_at_exception_is_the_only_way_a_reuse_cuts"
         >:: test_cut_at_exception_is_the_only_way_a_reuse_cuts;
         "cut_past_the_series_end_is_refused"
         >:: test_cut_past_the_series_end_is_refused;
         "cut_past_the_series_end_drops_when_the_guard_is_off"
         >:: test_cut_past_the_series_end_drops_when_the_guard_is_off;
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
         "ges_terminal_event_is_reported_not_cut"
         >:: test_ges_terminal_event_is_reported_not_cut;
         "ges_cut_at_exception_is_refused_by_the_short_tail_guard"
         >:: test_ges_cut_at_exception_is_refused_by_the_short_tail_guard;
         "chs_real_reuse_is_reported_by_default"
         >:: test_chs_real_reuse_is_reported_by_default;
         "chs_cuts_under_a_cut_at_exception"
         >:: test_chs_cuts_under_a_cut_at_exception;
         "chs_drops_under_a_drop_exception"
         >:: test_chs_drops_under_a_drop_exception;
         "prefix_misscale_with_a_short_tail_is_refused"
         >:: test_prefix_misscale_with_a_short_tail_is_refused;
         "exactly_min_kept_bars_is_cut" >:: test_exactly_min_kept_bars_is_cut;
         "one_below_min_kept_bars_is_refused"
         >:: test_one_below_min_kept_bars_is_refused;
         "report_only_carries_the_would_be_cut_depth"
         >:: test_report_only_carries_the_would_be_cut_depth;
         "default_min_kept_bars_is_one_trading_year"
         >:: test_default_min_kept_bars_is_one_trading_year;
         "csv_renders_the_documented_columns"
         >:: test_csv_renders_the_documented_columns;
         "empty_csv_is_the_header_alone" >:: test_empty_csv_is_the_header_alone;
         "summary_counts_by_action" >:: test_summary_counts_by_action;
       ]

let () = run_test_tt_main suite
