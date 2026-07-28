open OUnit2
open Core
open Matchers
module Weekly_sidetable_builder = Snapshot_pipeline.Weekly_sidetable_builder
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable
module Conversion = Time_period.Conversion

let _bar ~date ?(close = 5.0) ?high ?low () =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = Option.value high ~default:(close +. 1.0);
    low_price = Option.value low ~default:(close -. 1.0);
    close_price = close;
    volume = 1_000;
    adjusted_close = close;
    active_through = None;
  }

(* Monday anchor so calendar weeks align with ISO weeks (mirrors the
   resistance-sketch test). *)
let _week_start = Date.of_string "2000-01-03"
let _day ~w ~d = Date.add_days _week_start ((7 * w) + d)

(* [n_weeks] Mon-Fri weeks; every bar of week [w] carries a distinct
   (high, low) so the weekly aggregate high/low are exactly (6+w, 4-.w). *)
let _weeks_bars ~n_weeks =
  List.init n_weeks ~f:(fun w ->
      let high = 6.0 +. Float.of_int w and low = 4.0 -. Float.of_int w in
      List.init 5 ~f:(fun d -> _bar ~date:(_day ~w ~d) ~high ~low ()))
  |> List.concat

(* The canonical weekly aggregation the sketch consumes, mapped to entries. *)
let _expected_of bars : Weekly_sidetable.entry list =
  Conversion.daily_to_weekly ~include_partial_week:true bars
  |> List.map ~f:(fun (b : Types.Daily_price.t) ->
      {
        Weekly_sidetable.week_end_date = b.date;
        mid = (b.high_price +. b.low_price) /. 2.0;
        high = b.high_price;
      })

(* ----- equality with the pipeline's own weekly aggregation ----- *)

let test_matches_daily_to_weekly_no_deep _ =
  let bars = _weeks_bars ~n_weeks:6 in
  assert_that
    (Weekly_sidetable_builder.of_bars ~deep_bars:[] ~bars)
    (elements_are (List.map (_expected_of bars) ~f:equal_to))

let test_matches_daily_to_weekly_with_deep _ =
  let deep_bars = _weeks_bars ~n_weeks:4 in
  let bars =
    List.init 15 ~f:(fun i ->
        _bar ~date:(_day ~w:(4 + (i / 5)) ~d:(i mod 5)) ())
  in
  assert_that
    (Weekly_sidetable_builder.of_bars ~deep_bars ~bars)
    (elements_are (List.map (_expected_of (deep_bars @ bars)) ~f:equal_to))

(* ----- raw-high basis: high is the weekly RAW high, mid is (H+L)/2 ----- *)

let test_raw_high_and_mid_basis _ =
  (* Single full week, distinct highs/lows across its days; the mid-week peak
     high (9.0) must set the entry high, NOT the last (close-derived) bar. *)
  let bars =
    [
      _bar ~date:(_day ~w:0 ~d:0) ~high:7.0 ~low:3.0 ();
      _bar ~date:(_day ~w:0 ~d:1) ~high:9.0 ~low:2.0 ();
      _bar ~date:(_day ~w:0 ~d:2) ~high:8.0 ~low:5.0 ();
    ]
  in
  assert_that
    (Weekly_sidetable_builder.of_bars ~deep_bars:[] ~bars)
    (elements_are
       [
         all_of
           [
             field
               (fun (e : Weekly_sidetable.entry) -> e.high)
               (float_equal 9.0);
             field
               (fun (e : Weekly_sidetable.entry) -> e.mid)
               (float_equal ((9.0 +. 2.0) /. 2.0));
             field
               (fun (e : Weekly_sidetable.entry) -> e.week_end_date)
               (equal_to (_day ~w:0 ~d:2));
           ];
       ])

(* ----- trailing entry is the partial current week as of the last bar ----- *)

let test_trailing_partial_week_included _ =
  (* One full week + a 2-day partial second week. The result has one entry per
     week; the last entry's week_end_date is the partial week's last day. *)
  let bars =
    _weeks_bars ~n_weeks:1
    @ [ _bar ~date:(_day ~w:1 ~d:0) (); _bar ~date:(_day ~w:1 ~d:1) () ]
  in
  let entries = Weekly_sidetable_builder.of_bars ~deep_bars:[] ~bars in
  assert_that (List.last entries)
    (is_some_and
       (field
          (fun (e : Weekly_sidetable.entry) -> e.week_end_date)
          (equal_to (_day ~w:1 ~d:1))))

(* ----- adjusted basis: a split inside the window lands on one scale (#2133) -----

   A raw-close bar with a distinct [adjusted_close]. A 4:1 forward split means
   pre-split raw prices are 4x the adjusted; the builder rescales onto the
   adjusted basis, so pre-split weekly high/mid land on the SAME scale as the
   post-split weeks (not 4x above them). *)
let _adj_bar ~date ~close ~high ~low ~adjusted_close () : Types.Daily_price.t =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    volume = 1_000;
    adjusted_close;
    active_through = None;
  }

let test_split_rescaled_to_adjusted_basis _ =
  (* Week 0 pre-split: raw ~100-104, adjusted_close 25 (factor 0.25) -> rescaled
     weekly high 26, mid 25. Week 1 post-split: raw ~25-26, adjusted_close 25
     (factor 1) -> weekly high 26, mid 25. Without the rescale, week 0's entry
     high would be the raw 104 — a phantom supply wall 4x above the real one. *)
  let week ~w ~raw_close ~raw_high ~raw_low ~adj =
    List.init 5 ~f:(fun d ->
        _adj_bar ~date:(_day ~w ~d) ~close:raw_close ~high:raw_high ~low:raw_low
          ~adjusted_close:adj ())
  in
  let bars =
    week ~w:0 ~raw_close:100.0 ~raw_high:104.0 ~raw_low:96.0 ~adj:25.0
    @ week ~w:1 ~raw_close:25.0 ~raw_high:26.0 ~raw_low:24.0 ~adj:25.0
  in
  assert_that
    (Weekly_sidetable_builder.of_bars ~deep_bars:[] ~bars)
    (elements_are
       [
         all_of
           [
             field
               (fun (e : Weekly_sidetable.entry) -> e.high)
               (float_equal 26.0);
             field
               (fun (e : Weekly_sidetable.entry) -> e.mid)
               (float_equal 25.0);
           ];
         all_of
           [
             field
               (fun (e : Weekly_sidetable.entry) -> e.high)
               (float_equal 26.0);
             field
               (fun (e : Weekly_sidetable.entry) -> e.mid)
               (float_equal 25.0);
           ];
       ])

(* ----- empty input ----- *)

let test_empty _ =
  assert_that
    (Weekly_sidetable_builder.of_bars ~deep_bars:[] ~bars:[])
    (size_is 0)

let suite =
  "weekly_sidetable_builder"
  >::: [
         "matches daily_to_weekly (no deep)"
         >:: test_matches_daily_to_weekly_no_deep;
         "matches daily_to_weekly (with deep)"
         >:: test_matches_daily_to_weekly_with_deep;
         "raw high + mid basis" >:: test_raw_high_and_mid_basis;
         "split rescaled to adjusted basis"
         >:: test_split_rescaled_to_adjusted_basis;
         "trailing partial week included"
         >:: test_trailing_partial_week_included;
         "empty input" >:: test_empty;
       ]

let () = run_test_tt_main suite
