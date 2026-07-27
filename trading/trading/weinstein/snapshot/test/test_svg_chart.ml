(** Tests for {!Svg_chart} — pure SVG sparkline geometry.

    Geometry is pinned by {b exact} coordinate strings rather than "an svg was
    produced", so any change to the projection, the price domain, the volume
    strip or the level lines fails a test rather than silently redrawing the
    chart.

    Every geometry test uses [~width:104 ~height:80], which makes the derived
    numbers whole:
    - plot width = 104 - 2*pad(4) = 96; with n = 3 bars, slot = 32, so the
      column centres are x = 20, 52, 84,
    - price panel height = 80 - 2*pad(4) - gap(3) - volume strip(18) = 51,
      starting at y = 4, so the domain bottom maps to y = 55,
    - the volume strip starts at y = 4 + 51 + 3 = 58 and is 18 tall. *)

open Core
open OUnit2
open Matchers
module Svg_chart = Weinstein_snapshot.Svg_chart

let _test_width = 104
let _test_height = 80
let _base_date = Date.of_string "2020-01-01"

let _bar ?(volume = 100) ?high ?low ~day ~price () : Types.Daily_price.t =
  Types.Daily_price.make
    ~date:(Date.add_days _base_date day)
    ~open_price:price
    ~high_price:(Option.value high ~default:price)
    ~low_price:(Option.value low ~default:price)
    ~close_price:price ~volume ~adjusted_close:price ()

(* Three flat-range bars (high = low = close) so the price domain is exactly
   the set of closes — the geometry arithmetic in the docstring above. *)
let _three_bars =
  [
    _bar ~day:0 ~price:10.0 ();
    _bar ~day:1 ~price:20.0 ~volume:200 ();
    _bar ~day:2 ~price:15.0 ();
  ]

let _render ?band ?(levels = []) bars =
  Svg_chart.render ~width:_test_width ~height:_test_height ?band ~bars ~levels
    ()

let _has_substring substring : string matcher =
  matching
    ~msg:(Printf.sprintf "Expected substring %S" substring)
    (fun s -> if String.is_substring s ~substring then Some () else None)
    __

(* Asserts the needles appear in the given order, each after the previous. *)
let _in_order needles : string matcher =
  matching
    ~msg:
      (Printf.sprintf "Expected in order: %s"
         (String.concat ~sep:" < " needles))
    (fun s ->
      let positions =
        List.map needles ~f:(fun n -> String.substr_index s ~pattern:n)
      in
      match Option.all positions with
      | Some ps when List.is_sorted_strictly ps ~compare:Int.compare -> Some ()
      | _ -> None)
    __

(* Number of non-overlapping occurrences of [needle] in [s]. *)
let _count_occurrences s ~needle =
  List.length (String.substr_index_all s ~may_overlap:false ~pattern:needle)

(* ------- Degenerate inputs ------- *)

let test_no_bars_returns_none _ = assert_that (_render []) is_none

let test_single_bar_returns_none _ =
  (* One point is not a chart — the caller degrades to a chart-less cell. *)
  assert_that (_render [ _bar ~day:0 ~price:10.0 () ]) is_none

let test_two_bars_render _ =
  assert_that
    (_render [ _bar ~day:0 ~price:10.0 (); _bar ~day:1 ~price:11.0 () ])
    (is_some_and (_has_substring "<polyline class=\"px\""))

(* ------- Core geometry ------- *)

let test_polyline_geometry_pinned _ =
  (* Closes 10 / 20 / 15 over a domain of [10, 20]: y(10) = 55, y(20) = 4,
     y(15) = 29.5. x at the three column centres. *)
  assert_that (_render _three_bars)
    (is_some_and
       (_has_substring
          "<polyline class=\"px\" points=\"20.0,55.0 52.0,4.0 84.0,29.5\"/>"))

let test_root_element_pinned _ =
  assert_that (_render _three_bars)
    (is_some_and
       (all_of
          [
            _has_substring
              "<svg class=\"spark\" viewBox=\"0 0 104 80\" width=\"104\" \
               height=\"80\" role=\"img\"";
            _has_substring "aria-label=\"price and volume sparkline, 3 bars\"";
          ]))

let test_high_and_low_widen_the_domain _ =
  (* Same closes as [_three_bars] but bar 0 dips to a low of 5: the domain
     becomes [5, 20], so every close is projected higher up the panel —
     y(10) = 4 + 51*(1 - 5/15) = 38.0, y(15) = 21.0. Pins that the domain reads
     bar highs/lows, not just closes. *)
  let bars =
    [
      _bar ~day:0 ~price:10.0 ~low:5.0 ();
      _bar ~day:1 ~price:20.0 ~volume:200 ();
      _bar ~day:2 ~price:15.0 ();
    ]
  in
  assert_that (_render bars)
    (is_some_and
       (_has_substring
          "<polyline class=\"px\" points=\"20.0,38.0 52.0,4.0 84.0,21.0\"/>"))

let test_level_below_price_range_is_inside_the_viewbox _ =
  (* A stop at 5 sits below every bar (lows are 10). The domain must absorb it
     — becoming [5, 20] — so the stop line lands on the panel floor (y = 55)
     and the closes shift up exactly as in the high/low test. A domain that
     ignored levels would place the stop at y = 59.1, below the price panel. *)
  let levels = [ { Svg_chart.label = "stop"; price = 5.0; kind = Stop } ] in
  assert_that
    (_render ~levels _three_bars)
    (is_some_and
       (all_of
          [
            _has_substring
              "<line class=\"lvl lvl-stop\" x1=\"4.0\" y1=\"55.0\" \
               x2=\"100.0\" y2=\"55.0\">";
            _has_substring "points=\"20.0,38.0 52.0,4.0 84.0,21.0\"";
          ]))

let test_flat_series_has_finite_coordinates _ =
  (* Every price identical → a zero-width domain. It is padded, so the line
     sits mid-panel and no coordinate is nan / inf. *)
  let bars =
    [
      _bar ~day:0 ~price:10.0 ();
      _bar ~day:1 ~price:10.0 ();
      _bar ~day:2 ~price:10.0 ();
    ]
  in
  assert_that (_render bars)
    (is_some_and
       (all_of
          [
            _has_substring "points=\"20.0,29.5 52.0,29.5 84.0,29.5\"";
            not_ ~msg:"no nan coordinates" (_has_substring "nan");
            not_ ~msg:"no inf coordinates" (_has_substring "inf");
          ]))

(* ------- Levels ------- *)

let test_level_kinds_map_to_classes _ =
  let levels =
    [
      { Svg_chart.label = "entry"; price = 20.0; kind = Entry };
      { Svg_chart.label = "stop"; price = 10.0; kind = Stop };
      { Svg_chart.label = "ma"; price = 15.0; kind = Reference };
    ]
  in
  assert_that
    (_render ~levels _three_bars)
    (is_some_and
       (all_of
          [
            _has_substring "class=\"lvl lvl-entry\"";
            _has_substring "class=\"lvl lvl-stop\"";
            _has_substring "class=\"lvl lvl-ref\"";
          ]))

let test_level_label_is_escaped_in_title_and_aria _ =
  let levels =
    [ { Svg_chart.label = "stop <\"x\">"; price = 10.0; kind = Stop } ]
  in
  assert_that
    (_render ~levels _three_bars)
    (is_some_and
       (all_of
          [
            _has_substring "<title>stop &lt;&quot;x&quot;&gt;</title>";
            _has_substring
              "aria-label=\"price and volume sparkline, 3 bars; levels: stop \
               &lt;&quot;x&quot;&gt;\"";
            not_ ~msg:"no raw angle bracket from the label"
              (_has_substring "stop <\"x\">");
          ]))

let test_no_levels_renders_no_level_lines _ =
  assert_that (_render _three_bars)
    (is_some_and (not_ ~msg:"no level lines" (_has_substring "class=\"lvl")))

(* ------- Band ------- *)

let test_band_rect_pinned _ =
  (* Band across [15, 20]: y(20) = 4, y(15) = 29.5 → a 25.5-tall rect at y = 4,
     spanning the full 96-wide plot from x = 4. *)
  assert_that
    (_render ~band:(15.0, 20.0) _three_bars)
    (is_some_and
       (_has_substring
          "<rect class=\"band\" x=\"4.0\" y=\"4.0\" width=\"96.0\" \
           height=\"25.5\"/>"))

let test_band_bounds_order_is_irrelevant _ =
  assert_that
    (_render ~band:(20.0, 15.0) _three_bars)
    (is_some_and
       (_has_substring
          "<rect class=\"band\" x=\"4.0\" y=\"4.0\" width=\"96.0\" \
           height=\"25.5\"/>"))

let test_no_band_renders_no_band_rect _ =
  assert_that (_render _three_bars)
    (is_some_and (not_ ~msg:"no band rect" (_has_substring "class=\"band\"")))

let test_band_widens_the_domain _ =
  (* A band reaching down to 5 widens the domain the same way a level does. *)
  assert_that
    (_render ~band:(5.0, 20.0) _three_bars)
    (is_some_and (_has_substring "points=\"20.0,38.0 52.0,4.0 84.0,21.0\""))

(* ------- Volume strip ------- *)

let test_volume_rects_one_per_bar_pinned _ =
  (* Volumes 100 / 200 / 100 → the first bar is half the strip: height 9,
     y = 58 + 18 - 9 = 67. Width = 0.7 * slot(32) = 22.4, centred on x = 20. *)
  let svg = Option.value_exn (_render _three_bars) in
  assert_that svg
    (all_of
       [
         _has_substring
           "<rect class=\"vol\" x=\"8.8\" y=\"67.0\" width=\"22.4\" \
            height=\"9.0\"/>";
         _has_substring
           "<rect class=\"vol\" x=\"40.8\" y=\"58.0\" width=\"22.4\" \
            height=\"18.0\"/>";
       ]);
  assert_that (_count_occurrences svg ~needle:"class=\"vol\"") (equal_to 3)

let test_zero_volume_renders_no_volume_rects _ =
  let bars =
    [
      _bar ~day:0 ~price:10.0 ~volume:0 (); _bar ~day:1 ~price:20.0 ~volume:0 ();
    ]
  in
  assert_that (_render bars)
    (is_some_and
       (not_ ~msg:"no volume rects when the column is all zero"
          (_has_substring "class=\"vol\"")))

(* ------- Window truncation ------- *)

let test_window_truncated_to_the_most_recent_max_bars _ =
  (* 200 bars with close = low = high = index. Only the last [max_bars] are
     drawn, so the domain floor is 200 - 90 = 110: a level at 110 lands on the
     panel floor. Had the FIRST 90 bars been kept the domain would start at 0
     and that level would sit above the panel top. *)
  let bars =
    List.init 200 ~f:(fun i -> _bar ~day:i ~price:(Float.of_int i) ())
  in
  let levels =
    [ { Svg_chart.label = "floor"; price = 110.0; kind = Reference } ]
  in
  let svg = Option.value_exn (_render ~levels bars) in
  assert_that svg
    (all_of
       [
         _has_substring
           (Printf.sprintf "aria-label=\"price and volume sparkline, %d bars"
              Svg_chart.max_bars);
         _has_substring "y1=\"55.0\"";
       ]);
  assert_that
    (_count_occurrences svg ~needle:"class=\"vol\"")
    (equal_to Svg_chart.max_bars)

(* ------- Moving average ------- *)

(* Height 59 makes the price panel exactly 30 units tall (59 - 2*4 - 3 - 18), so
   every projected y below is exact at one decimal. *)
let _ma_height = 59

let _rising =
  [
    _bar ~day:0 ~price:10.0 ();
    _bar ~day:1 ~price:20.0 ();
    _bar ~day:2 ~price:30.0 ();
  ]

let test_moving_average_polyline_pinned _ =
  (* Closes 10 / 20 / 30 over a domain of [10, 30]: y(10) = 34, y(20) = 19,
     y(30) = 4. A 2-bar average is undefined at index 0 and equals 15 / 25 at
     indices 1 / 2 — y(15) = 26.5, y(25) = 11.5. *)
  assert_that
    (Svg_chart.render ~width:_test_width ~height:_ma_height ~ma_period:2
       ~bars:_rising ~levels:[] ())
    (is_some_and
       (all_of
          [
            _has_substring
              "<polyline class=\"px\" points=\"20.0,34.0 52.0,19.0 84.0,4.0\"/>";
            _has_substring
              "<polyline class=\"ma\" points=\"52.0,26.5 84.0,11.5\"/>";
            _has_substring
              "aria-label=\"price and volume sparkline, 3 bars; 2-period \
               moving average\"";
          ]))

let test_no_ma_period_emits_no_average _ =
  assert_that
    (Svg_chart.render ~width:_test_width ~height:_ma_height ~bars:_rising
       ~levels:[] ())
    (is_some_and
       (all_of
          [
            not_ ~msg:"no average polyline without ?ma_period"
              (_has_substring "class=\"ma\"");
            not_ ~msg:"no average in the aria-label either"
              (_has_substring "moving average");
          ]))

(* The .mli promises a non-positive period is EXACTLY the omitted case — same
   bytes, aria-label included. Whole-render EQUALITY is the assertion that makes
   that the pinned claim: leaving the period in the aria-label (which announced
   a "0-period moving average" that was never drawn, because [_sma] suppressed
   the polyline while [_aria_label] did not) satisfies every negative substring
   one would think to write, and fails this. It also pins the byte-identity that
   justifies leaving every pre-existing coordinate assertion in this file
   un-re-pinned. *)
let test_non_positive_ma_period_is_exactly_the_omitted_case _ =
  let render ?ma_period () =
    Svg_chart.render ~width:_test_width ~height:_ma_height ?ma_period
      ~bars:_rising ~levels:[] ()
  in
  assert_that (render ~ma_period:0 ()) (equal_to (render ()));
  assert_that (render ~ma_period:(-5) ()) (equal_to (render ()))

let test_ma_period_longer_than_the_series_emits_no_polyline _ =
  (* Three bars, period 3: exactly one point is defined, and one point is not a
     line. *)
  assert_that
    (Svg_chart.render ~width:_test_width ~height:_ma_height ~ma_period:3
       ~bars:_rising ~levels:[] ())
    (is_some_and
       (not_ ~msg:"a single defined point is not a polyline"
          (_has_substring "class=\"ma\"")))

let test_ma_is_computed_over_the_whole_series_not_the_window _ =
  (* 92 bars with [max_bars] = 90: the window drops the first two. A 3-bar
     average computed over the WINDOW would be undefined for its first two
     marks and start at x = 6.7; computed over the whole series it is defined at
     the window's very first mark, x = 4.5 — the same x the price line starts
     at. That difference is the whole point of the contract. *)
  let bars =
    List.init 92 ~f:(fun i -> _bar ~day:i ~price:(Float.of_int i) ())
  in
  let svg =
    Option.value_exn
      (Svg_chart.render ~width:_test_width ~height:_ma_height ~ma_period:3 ~bars
         ~levels:[] ())
  in
  assert_that svg
    (all_of
       [
         _has_substring "<polyline class=\"px\" points=\"4.5,";
         _has_substring "<polyline class=\"ma\" points=\"4.5,";
       ])

let test_ma_widens_the_domain _ =
  (* Because the average is computed over the WHOLE series, its value at the
     window's left edge can carry pre-window closes far outside the window's own
     price range. 92 bars: the first two at 1000, the remaining 90 at 10. The
     window is those last 90 — a flat series at 10 — but the 3-bar average at
     its first mark is (1000 + 1000 + 10) / 3 = 670. Unless the domain absorbs
     the average, that mark is drawn outside the viewBox. With it, 670 is the
     domain ceiling (y = 4, the panel top) and 10 the floor (y = 34). *)
  let bars =
    List.init 92 ~f:(fun i ->
        _bar ~day:i ~price:(if i < 2 then 1000.0 else 10.0) ())
  in
  assert_that
    (Svg_chart.render ~width:_test_width ~height:_ma_height ~ma_period:3 ~bars
       ~levels:[] ())
    (is_some_and
       (all_of
          [
            _has_substring "<polyline class=\"ma\" points=\"4.5,4.0 ";
            _has_substring "<polyline class=\"px\" points=\"4.5,34.0 ";
          ]))

(* ------- Annotations ------- *)

(* Width 156 leaves a 36-unit plot once the 112-unit label gutter is reserved
   (156 - 2*4 - 112), so with 3 bars the column centres are 10 / 22 / 34 and the
   labels start at x = 4 + 36 + 6 = 46. *)
let _annotate_width = 156

let _annotate ?(levels = []) bars =
  Svg_chart.render ~width:_annotate_width ~height:_ma_height ~annotate:true
    ~bars ~levels ()

let _tight_levels =
  [
    { Svg_chart.label = "entry"; price = 20.0; kind = Entry };
    { Svg_chart.label = "stop"; price = 19.0; kind = Stop };
  ]

let test_annotate_nudges_colliding_labels_apart _ =
  (* Domain [10, 20] over a 30-unit panel: y(20) = 4.0, y(19) = 7.0. Natural
     baselines are 7.5 and 10.5 — 3 units apart, which overprints. The stop is
     pushed to 7.5 + 12 = 19.5. The entry, being first, is untouched. *)
  assert_that
    (_annotate ~levels:_tight_levels _three_bars)
    (is_some_and
       (all_of
          [
            _has_substring
              "<text class=\"lvl-label lvl-label-entry\" x=\"46.0\" \
               y=\"7.5\">entry</text>";
            _has_substring
              "<text class=\"lvl-label lvl-label-stop\" x=\"46.0\" \
               y=\"19.5\">stop</text>";
          ]))

let test_annotate_leaves_well_separated_labels_alone _ =
  (* Same chart, stop at 10 instead of 19: y(10) = 34.0, baseline 37.5, which
     already clears the entry's 7.5 by far more than the minimum gap. *)
  let levels =
    [
      { Svg_chart.label = "entry"; price = 20.0; kind = Entry };
      { Svg_chart.label = "stop"; price = 10.0; kind = Stop };
    ]
  in
  assert_that
    (_annotate ~levels _three_bars)
    (is_some_and
       (all_of
          [
            _has_substring "lvl-label-entry\" x=\"46.0\" y=\"7.5\"";
            _has_substring "lvl-label-stop\" x=\"46.0\" y=\"37.5\"";
          ]))

let test_annotate_emits_the_last_close_marker _ =
  (* Last bar closes at 15 on 2020-01-03 (day 2 from [_base_date]); x is the
     last column centre, y(15) = 19.0. *)
  assert_that (_annotate _three_bars)
    (is_some_and
       (_has_substring
          "<circle class=\"last\" cx=\"34.0\" cy=\"19.0\" \
           r=\"3.5\"><title>last close 15.00 (2020-01-03)</title></circle>"))

let test_annotate_labels_keep_the_callers_level_order _ =
  (* The stop is nudged BELOW the entry in y, but the markup order still follows
     the caller's list — a reader diffing the output sees a stable document. *)
  assert_that
    (_annotate ~levels:_tight_levels _three_bars)
    (is_some_and (_in_order [ "lvl-label-entry"; "lvl-label-stop" ]))

let test_annotate_labels_are_escaped _ =
  let levels =
    [ { Svg_chart.label = "<b>entry</b>"; price = 20.0; kind = Entry } ]
  in
  assert_that
    (_annotate ~levels _three_bars)
    (is_some_and
       (all_of
          [
            _has_substring ">&lt;b&gt;entry&lt;/b&gt;</text>";
            not_ ~msg:"no raw markup from a level label"
              (_has_substring "<b>entry</b>");
          ]))

let test_default_is_unannotated _ =
  (* The default leaves both the geometry and the output exactly as they were
     before ?annotate existed: no gutter (the plot still spans the full width,
     so the column centres are 20 / 52 / 84 rather than the annotated ones), no
     labels, no marker. *)
  let levels = [ { Svg_chart.label = "entry"; price = 20.0; kind = Entry } ] in
  assert_that
    (Svg_chart.render ~width:_test_width ~height:_ma_height ~bars:_three_bars
       ~levels ())
    (is_some_and
       (all_of
          [
            _has_substring "points=\"20.0,34.0";
            not_ ~msg:"no level labels by default" (_has_substring "lvl-label");
            not_ ~msg:"no last-close marker by default"
              (_has_substring "class=\"last\"");
          ]))

(* ------- Determinism ------- *)

let test_render_is_deterministic _ =
  let levels = [ { Svg_chart.label = "entry"; price = 20.0; kind = Entry } ] in
  let first = _render ~band:(10.0, 20.0) ~levels _three_bars in
  let second = _render ~band:(10.0, 20.0) ~levels _three_bars in
  assert_that first (equal_to second)

let test_defaults_are_the_documented_dimensions _ =
  assert_that
    (Svg_chart.render ~bars:_three_bars ~levels:[] ())
    (is_some_and
       (_has_substring
          (Printf.sprintf "viewBox=\"0 0 %d %d\"" Svg_chart.default_width
             Svg_chart.default_height)))

let suite =
  "svg_chart"
  >::: [
         "no_bars_returns_none" >:: test_no_bars_returns_none;
         "single_bar_returns_none" >:: test_single_bar_returns_none;
         "two_bars_render" >:: test_two_bars_render;
         "polyline_geometry_pinned" >:: test_polyline_geometry_pinned;
         "root_element_pinned" >:: test_root_element_pinned;
         "high_and_low_widen_the_domain" >:: test_high_and_low_widen_the_domain;
         "level_below_price_range_is_inside_the_viewbox"
         >:: test_level_below_price_range_is_inside_the_viewbox;
         "flat_series_has_finite_coordinates"
         >:: test_flat_series_has_finite_coordinates;
         "level_kinds_map_to_classes" >:: test_level_kinds_map_to_classes;
         "level_label_is_escaped_in_title_and_aria"
         >:: test_level_label_is_escaped_in_title_and_aria;
         "no_levels_renders_no_level_lines"
         >:: test_no_levels_renders_no_level_lines;
         "band_rect_pinned" >:: test_band_rect_pinned;
         "band_bounds_order_is_irrelevant"
         >:: test_band_bounds_order_is_irrelevant;
         "no_band_renders_no_band_rect" >:: test_no_band_renders_no_band_rect;
         "band_widens_the_domain" >:: test_band_widens_the_domain;
         "volume_rects_one_per_bar_pinned"
         >:: test_volume_rects_one_per_bar_pinned;
         "zero_volume_renders_no_volume_rects"
         >:: test_zero_volume_renders_no_volume_rects;
         "window_truncated_to_the_most_recent_max_bars"
         >:: test_window_truncated_to_the_most_recent_max_bars;
         "moving_average_polyline_pinned"
         >:: test_moving_average_polyline_pinned;
         "no_ma_period_emits_no_average" >:: test_no_ma_period_emits_no_average;
         "non_positive_ma_period_is_exactly_the_omitted_case"
         >:: test_non_positive_ma_period_is_exactly_the_omitted_case;
         "ma_period_longer_than_the_series_emits_no_polyline"
         >:: test_ma_period_longer_than_the_series_emits_no_polyline;
         "ma_is_computed_over_the_whole_series_not_the_window"
         >:: test_ma_is_computed_over_the_whole_series_not_the_window;
         "ma_widens_the_domain" >:: test_ma_widens_the_domain;
         "annotate_nudges_colliding_labels_apart"
         >:: test_annotate_nudges_colliding_labels_apart;
         "annotate_leaves_well_separated_labels_alone"
         >:: test_annotate_leaves_well_separated_labels_alone;
         "annotate_emits_the_last_close_marker"
         >:: test_annotate_emits_the_last_close_marker;
         "annotate_labels_keep_the_callers_level_order"
         >:: test_annotate_labels_keep_the_callers_level_order;
         "annotate_labels_are_escaped" >:: test_annotate_labels_are_escaped;
         "default_is_unannotated" >:: test_default_is_unannotated;
         "render_is_deterministic" >:: test_render_is_deterministic;
         "defaults_are_the_documented_dimensions"
         >:: test_defaults_are_the_documented_dimensions;
       ]

let () = run_test_tt_main suite
