open Core
open OUnit2
open Matchers
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let run_deferred d = Async.Thread_safe.block_on_async_exn (fun () -> d)

(** Load daily AAPL bars from the canonical data directory up to [end_date]. *)
let load_aapl ~start_date ~end_date =
  let data_dir = Fpath.to_string (Data_path.default_data_dir ()) in
  let simulation_date = end_date in
  let config : Historical_source.config = { data_dir; simulation_date } in
  let ds = Historical_source.make config in
  let module DS = (val ds : Data_source.DATA_SOURCE) in
  let query : Data_source.bar_query =
    {
      symbol = "AAPL";
      period = Types.Cadence.Daily;
      start_date = Some start_date;
      end_date = Some end_date;
    }
  in
  match run_deferred (DS.get_bars ~query ()) with
  | Ok bars -> bars
  | Error e -> failwith ("load_aapl failed: " ^ Status.show e)

(** Resample daily bars to weekly (complete weeks only). *)
let to_weekly_bars daily =
  Time_period.Conversion.daily_to_weekly ~include_partial_week:false daily

(* ================================================================== *)
(* Stage Classifier                                                     *)
(* ================================================================== *)

(* NOTE: [weeks_advancing] and [weeks_declining] are incremental counters
   designed for use across multiple classify calls. With [prior_stage:None],
   a single classify call always produces 1 (first detected week in the stage),
   regardless of how long the stock has actually been in that stage. The
   meaningful regression signals are [ma_direction] and [above_ma_count]. *)

(* ------------------------------------------------------------------ *)
(* Scenario 1: AAPL Stage 2 — 2023 Bull Run                           *)
(* ------------------------------------------------------------------ *)

(** AAPL rose ~50% in 2023. By 2023-12-29 the 30-week MA was clearly rising and
    price was consistently above it: all 6 confirm_weeks bars should be above
    MA. *)
let test_aapl_stage2_2023_bull_run _ =
  let daily =
    load_aapl
      ~start_date:(Date.of_string "2021-01-01")
      ~end_date:(Date.of_string "2023-12-29")
  in
  let weekly = to_weekly_bars daily in
  let result =
    Stage.classify ~config:Stage.default_config ~bars:weekly ~prior_stage:None
  in
  assert_that result.stage
    (matching ~msg:"Expected Stage2 at 2023-12-29"
       (function
         | Stage2 { weeks_advancing; _ } -> Some weeks_advancing | _ -> None)
       (equal_to 1));
  assert_that result.ma_direction (equal_to Rising);
  assert_that result.above_ma_count (equal_to 6)

(* ------------------------------------------------------------------ *)
(* Scenario 2: AAPL Stage 4 — 2022 Bear Market                        *)
(* ------------------------------------------------------------------ *)

(** AAPL fell ~30% peak-to-trough in 2022. Near the trough (2022-10-14) the
    30-week MA was declining and only 1 of the last 6 confirm_weeks bars was
    above the MA. *)
let test_aapl_stage4_2022_bear_market _ =
  let daily =
    load_aapl
      ~start_date:(Date.of_string "2020-01-01")
      ~end_date:(Date.of_string "2022-10-14")
  in
  let weekly = to_weekly_bars daily in
  let result =
    Stage.classify ~config:Stage.default_config ~bars:weekly ~prior_stage:None
  in
  assert_that result.stage
    (matching ~msg:"Expected Stage4 at 2022-10-14"
       (function
         | Stage4 { weeks_declining } -> Some weeks_declining | _ -> None)
       (equal_to 1));
  assert_that result.ma_direction (equal_to Declining);
  assert_that result.above_ma_count (equal_to 1)

(* ------------------------------------------------------------------ *)
(* Scenario 3: AAPL Stock Analysis — Stage 2 at mid-2023              *)
(* ------------------------------------------------------------------ *)

(** AAPL in early-to-mid 2023 is a clean Stage 2 advance. Verifies that
    [Stock_analysis.analyze] correctly reports Stage 2 with a rising MA and all
    6 confirm_weeks bars above the MA. Uses the full stock_analysis path (not
    just the stage classifier) to exercise the aggregation layer. *)
let test_aapl_stock_analysis_stage2_mid_2023 _ =
  let as_of = Date.of_string "2023-06-30" in
  let daily =
    load_aapl
      ~start_date:(Date.of_string "2021-01-01")
      ~end_date:(Date.of_string "2023-06-30")
  in
  let weekly = to_weekly_bars daily in
  let analysis =
    Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker:"AAPL"
      ~bars:weekly ~benchmark_bars:[] ~prior_stage:None ~as_of_date:as_of
  in
  assert_that analysis.stage.stage
    (matching ~msg:"Expected Stage2 at 2023-06-30"
       (function
         | Stage2 { weeks_advancing; _ } -> Some weeks_advancing | _ -> None)
       (equal_to 1));
  assert_that analysis.stage.ma_direction (equal_to Rising);
  assert_that analysis.stage.above_ma_count (equal_to 6)

(* ------------------------------------------------------------------ *)
(* Scenario 4: AAPL Stage 2 — 2019 Pre-COVID                          *)
(* ------------------------------------------------------------------ *)

(** AAPL doubled from early-2019 lows into late 2019. A different bull market
    regime from the 2023 scenario — tests regime independence. *)
let test_aapl_stage2_2019_precovid _ =
  let daily =
    load_aapl
      ~start_date:(Date.of_string "2017-01-01")
      ~end_date:(Date.of_string "2019-11-29")
  in
  let weekly = to_weekly_bars daily in
  let result =
    Stage.classify ~config:Stage.default_config ~bars:weekly ~prior_stage:None
  in
  assert_that result.stage
    (matching ~msg:"Expected Stage2 at 2019-11-29"
       (function
         | Stage2 { weeks_advancing; _ } -> Some weeks_advancing | _ -> None)
       (equal_to 1));
  assert_that result.ma_direction (equal_to Rising);
  assert_that result.above_ma_count (equal_to 6)

(* ------------------------------------------------------------------ *)
(* Scenario 5: AAPL COVID Crash — 2020-03-20                          *)
(* ------------------------------------------------------------------ *)

(** AAPL fell ~35% in five weeks (Feb-Mar 2020). The COVID crash was so sharp
    and brief that the 30-week MA never turned declining — it remained Flat. At
    the trough, price had been below the MA for most of the confirm window:
    [above_ma_count] = 3 (exactly half of [confirm_weeks] = 6). Stage resolves
    to Stage1 (Flat MA with no clear prior context). *)
let test_aapl_covid_crash_2020 _ =
  let daily =
    load_aapl
      ~start_date:(Date.of_string "2018-01-01")
      ~end_date:(Date.of_string "2020-03-20")
  in
  let weekly = to_weekly_bars daily in
  let result =
    Stage.classify ~config:Stage.default_config ~bars:weekly ~prior_stage:None
  in
  assert_that result.stage
    (matching ~msg:"Expected Stage1 at COVID trough (MA Flat, not yet Stage4)"
       (function Stage1 _ -> Some () | _ -> None)
       (equal_to ()));
  assert_that result.ma_direction (equal_to Flat);
  assert_that result.above_ma_count (equal_to 3)

(* ------------------------------------------------------------------ *)
(* Scenario 6: AAPL AI-Era Bull — 2024-06-28                          *)
(* ------------------------------------------------------------------ *)

(** AAPL participated in the AI-driven tech rally of 2024. Tests a third
    distinct bull period with a different MA history from 2023. *)
let test_aapl_stage2_2024_ai_era _ =
  let daily =
    load_aapl
      ~start_date:(Date.of_string "2022-01-01")
      ~end_date:(Date.of_string "2024-06-28")
  in
  let weekly = to_weekly_bars daily in
  let result =
    Stage.classify ~config:Stage.default_config ~bars:weekly ~prior_stage:None
  in
  assert_that result.stage
    (matching ~msg:"Expected Stage2 at 2024-06-28"
       (function
         | Stage2 { weeks_advancing; _ } -> Some weeks_advancing | _ -> None)
       (equal_to 1));
  assert_that result.ma_direction (equal_to Rising);
  assert_that result.above_ma_count (equal_to 6)

(* ================================================================== *)
(* Screener                                                             *)
(* ================================================================== *)

(* ------------------------------------------------------------------ *)
(* Scenario 8: Macro gate — Bearish blocks buys; Stage2 stock is not  *)
(*             a short candidate                                        *)
(* ------------------------------------------------------------------ *)

(** When macro is [Bearish], the screener gates out all buy candidates.
    [Bearish] macro also enables short candidates — but AAPL at 2023-06-30 is in
    Stage 2 (rising MA, price above MA), so it passes no short-side criteria and
    [short_candidates] is also empty. The test uses AAPL as a deliberately
    strong Stage 2 stock to confirm both gates fire as expected. *)
let test_macro_gate_bearish_no_buys _ =
  let as_of = Date.of_string "2023-06-30" in
  let daily =
    load_aapl
      ~start_date:(Date.of_string "2021-01-01")
      ~end_date:(Date.of_string "2023-06-30")
  in
  let weekly = to_weekly_bars daily in
  let analysis =
    Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker:"AAPL"
      ~bars:weekly ~benchmark_bars:[] ~prior_stage:None ~as_of_date:as_of
  in
  let sector_map = Hashtbl.create (module String) in
  let result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Bearish
      ~sector_map ~stocks:[ analysis ] ~held_tickers:[]
  in
  assert_that result.buy_candidates is_empty;
  assert_that result.short_candidates is_empty

(* ------------------------------------------------------------------ *)
(* Scenario 9: Stage 4 stock with negative RS appears as short         *)
(*             candidate under Neutral macro                            *)
(* ------------------------------------------------------------------ *)

(** AAPL at 2022-10-14 was in Stage 4 (MA declining, price below MA). Paired
    with a synthetic benchmark that rose +10% over the same period, the RS is
    Negative_declining. With [prior_stage = Stage3] (simulating the immediately
    preceding topping phase), the screener recognises a Stage3→Stage4 breakdown
    — the highest-conviction short setup in Weinstein's methodology. Under a
    [Neutral] macro (shorts active, buys inactive), AAPL appears in
    [short_candidates] with grade C. *)
let test_stage4_aapl_is_short_candidate _ =
  let daily =
    load_aapl
      ~start_date:(Date.of_string "2020-01-01")
      ~end_date:(Date.of_string "2022-10-14")
  in
  let weekly = to_weekly_bars daily in
  (* Synthetic benchmark matching weekly dates, rising +10% —
     AAPL fell ~30% over this period, giving Negative_declining RS. *)
  let n = List.length weekly in
  let benchmark_bars =
    List.mapi weekly ~f:(fun i bar ->
        let price =
          100.0 *. (1.0 +. (Float.of_int i *. 0.10 /. Float.of_int (n - 1)))
        in
        {
          bar with
          Types.Daily_price.open_price = price;
          high_price = price;
          low_price = price;
          close_price = price;
          adjusted_close = price;
        })
  in
  let as_of = Date.of_string "2022-10-14" in
  (* prior_stage = Stage3 simulates the week before breakdown, activating
     the Stage3→Stage4 scoring path (full 30-point stage signal vs. 15
     for early-Stage4 alone, which would fall below min_grade C). *)
  let prior_stage = Some (Stage3 { weeks_topping = 5 }) in
  let analysis =
    Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker:"AAPL"
      ~bars:weekly ~benchmark_bars ~prior_stage ~as_of_date:as_of
  in
  let sector_map = Hashtbl.create (module String) in
  let result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Neutral
      ~sector_map ~stocks:[ analysis ] ~held_tickers:[]
  in
  assert_that result.buy_candidates is_empty;
  assert_that result.short_candidates
    (elements_are
       [
         (fun c ->
           assert_that c.Screener.ticker (equal_to "AAPL");
           assert_that c.grade
             (matching ~msg:"Expected grade C or better"
                (function C | B | A | A_plus -> Some () | _ -> None)
                (equal_to ())));
       ])

(* ------------------------------------------------------------------ *)
(* Test suite                                                           *)
(* ------------------------------------------------------------------ *)

let suite =
  "screener_regression"
  >::: [
         (* Stage Classifier *)
         "aapl_stage2_2023_bull_run" >:: test_aapl_stage2_2023_bull_run;
         "aapl_stage4_2022_bear_market" >:: test_aapl_stage4_2022_bear_market;
         "aapl_stock_analysis_stage2_mid_2023"
         >:: test_aapl_stock_analysis_stage2_mid_2023;
         "aapl_stage2_2019_precovid" >:: test_aapl_stage2_2019_precovid;
         "aapl_covid_crash_2020" >:: test_aapl_covid_crash_2020;
         "aapl_stage2_2024_ai_era" >:: test_aapl_stage2_2024_ai_era;
         (* Screener *)
         "macro_gate_bearish_no_buys" >:: test_macro_gate_bearish_no_buys;
         "stage4_aapl_is_short_candidate"
         >:: test_stage4_aapl_is_short_candidate;
       ]

let () = run_test_tt_main suite
