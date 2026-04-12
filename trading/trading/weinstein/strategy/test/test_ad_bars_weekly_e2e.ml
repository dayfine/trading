(** End-to-end regression for the A-D bars weekly-cadence pipeline.

    Loads real NYSE breadth CSVs from [data/breadth/] via
    {!Weinstein_strategy.Ad_bars.Unicorn.load}, aggregates them to weekly with
    {!Ad_bars_aggregation.daily_to_weekly}, pairs them against real weekly
    GSPC.INDX bars, and runs {!Macro.analyze} — verifying the new weekly cadence
    contract holds on real data without crashing and that the A-D Line indicator
    is not [Neutral] over a multi-year window (where it would be [Neutral] only
    if there were fewer bars than [ad_min_bars]).

    Skipped when the cached CSV is absent. *)

open Core
open OUnit2
open Matchers

let _breadth_csv_path = "/workspaces/trading-1/data/breadth/nyse_advn.csv"
let _data_dir = "/workspaces/trading-1/data"

(** Slice a weekly bar list to the same date range as the weekly ADL bars, so
    that the lookback windows land on comparable timeframes. *)
let _slice_to_range bars ~start_date ~end_date =
  List.filter bars ~f:(fun (b : Types.Daily_price.t) ->
      Date.compare b.date start_date >= 0 && Date.compare b.date end_date <= 0)

let test_real_breadth_aggregates_and_analyzes _ =
  if not (Stdlib.Sys.file_exists _breadth_csv_path) then
    skip_if true "no cached breadth data";
  (* Load daily ADL from 2018 to end of Unicorn coverage (2020-02-10). *)
  let daily_ad =
    Weinstein_strategy.Ad_bars.Unicorn.load ~data_dir:_data_dir
    |> List.filter ~f:(fun (b : Macro.ad_bar) ->
        Date.compare b.date (Date.of_string "2018-01-01") >= 0)
  in
  let weekly_ad = Ad_bars_aggregation.daily_to_weekly daily_ad in
  (* Weekly aggregation must never produce more bars than the daily input. *)
  assert_that (List.length weekly_ad) (gt (module Int_ord) 0);
  assert_that (List.length weekly_ad < List.length daily_ad) (equal_to true);
  (* Pair with weekly GSPC over the same window. *)
  let weekly_index =
    Test_data_loader.load_weekly_bars ~symbol:"GSPC.INDX"
      ~start_date:(Date.of_string "2018-01-01")
      ~end_date:(Date.of_string "2020-02-10")
  in
  let start_date = (List.hd_exn weekly_ad).Macro.date in
  let end_date = (List.last_exn weekly_ad).Macro.date in
  let weekly_index = _slice_to_range weekly_index ~start_date ~end_date in
  let result =
    Macro.analyze ~config:Macro.default_config ~index_bars:weekly_index
      ~ad_bars:weekly_ad ~global_index_bars:[] ~prior_stage:None ~prior:None
  in
  (* With real data and enough weeks, the A-D Line indicator must have
     enough bars to compute a real divergence signal — its detail must
     not indicate missing/insufficient data. *)
  let ad_line =
    List.find_exn result.indicators ~f:(fun r -> String.(r.name = "A-D Line"))
  in
  let uses_real_data =
    (not (String.is_substring ad_line.detail ~substring:"No A-D data"))
    && not
         (String.is_substring ad_line.detail ~substring:"Insufficient A-D data")
  in
  assert_that uses_real_data (equal_to true)

let () =
  run_test_tt_main
    ("ad_bars_weekly_e2e"
    >::: [
           "weekly-aggregated real breadth flows through Macro.analyze"
           >:: test_real_breadth_aggregates_and_analyzes;
         ])
