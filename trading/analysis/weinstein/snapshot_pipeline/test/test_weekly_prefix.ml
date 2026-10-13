open OUnit2
open Core
open Matchers
module Weekly_prefix = Snapshot_pipeline.Weekly_prefix

let _bar date close =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = close +. 1.0;
    low_price = close -. 1.0;
    close_price = close;
    volume = 1_000;
    adjusted_close = close;
    active_through = None;
  }

(* Weekdays 2001-12-24 .. 2002-01-11, skipping the 12-25 and 01-01 holidays.
   ISO weeks: 2001-W52 (12-24..12-28), 2002-W01 (12-31..01-04), 2002-W02
   (01-07..01-11). *)
let _year_crossing_bars () =
  let start = Date.of_string "2001-12-24" in
  List.init 19 ~f:(fun i -> Date.add_days start i)
  |> List.filter ~f:(fun d ->
      Date.is_weekday d
      && (not (Date.equal d (Date.of_string "2001-12-25")))
      && not (Date.equal d (Date.of_string "2002-01-01")))
  |> List.mapi ~f:(fun i d -> _bar d (Float.of_int (i + 10)))

let test_year_crossing_week_is_one_finalized_bar _ =
  let prefix = Weekly_prefix.build (Array.of_list (_year_crossing_bars ())) in
  assert_that
    (Array.to_list prefix.finalized)
    (elements_are
       [
         field
           (fun (b : Types.Daily_price.t) -> b.date)
           (equal_to (Date.of_string "2001-12-28"));
         field
           (fun (b : Types.Daily_price.t) -> b.date)
           (equal_to (Date.of_string "2002-01-04"));
       ])

let test_year_crossing_matches_daily_to_weekly _ =
  (* Bit-identity with [Time_period.Conversion.daily_to_weekly]: the last-day
     window must equal a fresh conversion of the whole series. *)
  let bars = _year_crossing_bars () in
  let prefix = Weekly_prefix.build (Array.of_list bars) in
  assert_that
    (Weekly_prefix.window_for_day prefix
       ~day_idx:(List.length bars - 1)
       ~lookback:100)
    (equal_to
       (Time_period.Conversion.daily_to_weekly ~include_partial_week:true bars
         : Types.Daily_price.t list))

let suite =
  "Weekly_prefix tests"
  >::: [
         "year-crossing ISO week is one finalized bar"
         >:: test_year_crossing_week_is_one_finalized_bar;
         "year-crossing window matches daily_to_weekly"
         >:: test_year_crossing_matches_daily_to_weekly;
       ]

let () = run_test_tt_main suite
