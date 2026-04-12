(** End-to-end regression for the A-D bars weekly-cadence pipeline.

    Loads real NYSE breadth CSVs from [data/breadth/] via
    {!Weinstein_strategy.Ad_bars.Unicorn.load}, aggregates them to weekly with
    {!Ad_bars_aggregation.daily_to_weekly}, pairs them against real weekly
    GSPC.INDX bars, and runs {!Macro.analyze}.

    Verifies the weekly cadence contract holds end-to-end AND that the A-D Line
    indicator produces semantically correct output on a known-direction
    historical window (2018-01 → 2020-02-10, which is a broadly rising US equity
    market leading up to the COVID peak).

    Skipped when the cached CSV is absent. *)

open Core
open OUnit2
open Matchers

let _breadth_csv_path = "/workspaces/trading-1/data/breadth/nyse_advn.csv"
let _data_dir = "/workspaces/trading-1/data"
let _window_start = Date.of_string "2018-01-01"
let _window_end = Date.of_string "2020-02-10"

(** Slice bars to a date range. *)
let _slice_to_range bars ~start_date ~end_date =
  List.filter bars ~f:(fun (b : Types.Daily_price.t) ->
      Date.compare b.date start_date >= 0 && Date.compare b.date end_date <= 0)

(** Property: weekly aggregation preserves the daily advancing+declining sum
    totals (the aggregation is a pure bucket-sum). *)
let _sum_counts (bars : Macro.ad_bar list) =
  List.fold bars ~init:(0, 0) ~f:(fun (a, d) b ->
      (a + b.advancing, d + b.declining))

(** Property: dates in the weekly output are strictly increasing. *)
let _is_strictly_ascending (bars : Macro.ad_bar list) =
  let rec check = function
    | [] | [ _ ] -> true
    | a :: (b :: _ as rest) ->
        Date.compare a.Macro.date b.Macro.date < 0 && check rest
  in
  check bars

(** Find the A-D Line indicator in a [Macro.result]. Raises if missing. *)
let _find_ad_line (result : Macro.result) =
  List.find_exn result.indicators ~f:(fun r -> String.(r.name = "A-D Line"))

let test_real_breadth_aggregates_and_analyzes _ =
  if not (Stdlib.Sys.file_exists _breadth_csv_path) then
    skip_if true "no cached breadth data";
  (* Load daily ADL from 2018 to end of Unicorn coverage (2020-02-10). *)
  let daily_ad =
    Weinstein_strategy.Ad_bars.Unicorn.load ~data_dir:_data_dir
    |> List.filter ~f:(fun (b : Macro.ad_bar) ->
        Date.compare b.date _window_start >= 0)
  in
  let weekly_ad = Ad_bars_aggregation.daily_to_weekly daily_ad in
  (* ------------------------------------------------------------------ *)
  (* Aggregation invariants                                              *)
  (* ------------------------------------------------------------------ *)
  (* Pure bucket-sum: the total advancing/declining counts across all
     weekly bars must equal the totals across the daily input. *)
  assert_that (_sum_counts weekly_ad) (equal_to (_sum_counts daily_ad));
  (* The output must have strictly fewer bars than the input (weeks
     collapse multiple days) and dates must be strictly ascending. *)
  assert_that (List.length weekly_ad < List.length daily_ad) (equal_to true);
  assert_that (_is_strictly_ascending weekly_ad) (equal_to true);
  (* ------------------------------------------------------------------ *)
  (* Macro.analyze semantic contract                                     *)
  (* ------------------------------------------------------------------ *)
  let weekly_index =
    Test_data_loader.load_weekly_bars ~symbol:"GSPC.INDX"
      ~start_date:_window_start ~end_date:_window_end
  in
  let start_date = (List.hd_exn weekly_ad).Macro.date in
  let end_date = (List.last_exn weekly_ad).Macro.date in
  let weekly_index = _slice_to_range weekly_index ~start_date ~end_date in
  let result =
    Macro.analyze ~config:Macro.default_config ~index_bars:weekly_index
      ~ad_bars:weekly_ad ~global_index_bars:[] ~prior_stage:None ~prior:None
  in
  let ad_line = _find_ad_line result in
  (* Over this 2018-2020 window, a 26-week lookback ending 2020-02-10
     covers Aug 2019 → Feb 2020. GSPC rose from ~2900 to ~3337 during
     that window (+15%), and cumulative NYSE ADL rose with it. Both
     conditions flip the divergence signal to Bullish with the "confirming
     advance" narrative. *)
  assert_that ad_line
    (all_of
       [
         field
           (fun (r : Macro.indicator_reading) -> r.signal)
           (equal_to `Bullish);
         field
           (fun (r : Macro.indicator_reading) -> r.detail)
           (* Substring check — the exact wording is a macro-module
              implementation detail, but "confirming" distinguishes the
              aligned case from the "diverging" alternatives. *)
           (fun detail ->
             assert_that
               (String.is_substring detail ~substring:"confirming")
               (equal_to true));
         field
           (fun (r : Macro.indicator_reading) -> r.weight)
           (* Must match the configured A-D line weight — confirms the
              signal reached the composite with its full weight (not
              zero-weighted by a short-circuit). *)
           (float_equal Macro_types.default_indicator_weights.w_ad_line);
         field
           (fun (r : Macro.indicator_reading) -> r.name)
           (equal_to "A-D Line");
       ]);
  (* Composite confidence must be in the valid (0, 1) range and must be
     strictly positive (A-D line contributed something). *)
  assert_that result.confidence
    (is_between (module Float_ord) ~low:0.0 ~high:1.0)

let () =
  run_test_tt_main
    ("ad_bars_weekly_e2e"
    >::: [
           "weekly-aggregated real breadth flows through Macro.analyze"
           >:: test_real_breadth_aggregates_and_analyzes;
         ])
