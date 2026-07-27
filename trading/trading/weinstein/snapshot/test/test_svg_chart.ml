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
         "render_is_deterministic" >:: test_render_is_deterministic;
         "defaults_are_the_documented_dimensions"
         >:: test_defaults_are_the_documented_dimensions;
       ]

let () = run_test_tt_main suite
