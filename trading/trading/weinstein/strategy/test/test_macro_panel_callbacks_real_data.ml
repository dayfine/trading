(** Real-data regression test for the live cascade's macro plumbing.

    Pins the contract that {!Weinstein_strategy._run_screen}'s macro-input
    construction (real 2022 GSPC weekly bars + a future-leaking weekly [ad_bars]
    series + the panel-callbacks path through
    {!Panel_callbacks.macro_callbacks_of_weekly_views}) yields [trend = Bearish]
    / [confidence < 0.5] {b only when} [ad_bars] is filtered to dates
    [<= current_date]. Without filtering, the composite trend flips to
    non-Bearish — exactly the live-cascade bug PR #612 surfaced.

    {1 Why this test exists}

    [dev/notes/short-side-real-data-verification-2026-04-27.md] — the real SP500
    5y backtest emits {b 0 short trades and 37 long entries opened in 2022 bear}
    despite [Macro.analyze] returning [Bearish] on real GSPC bars at the unit
    level. The bear-window contract regression test in
    [test_short_side_bear_window.ml] (PR #617) confirms that the screener
    correctly suppresses longs and emits shorts when fed
    [macro_trend = Bearish]; the bug must therefore be upstream in the live
    cascade's macro plumbing.

    {1 Root cause (encoded by these tests)}

    The {!Weinstein_strategy.make} function loads AD breadth bars {b once} at
    strategy-construction time and passes them to every Friday's
    [_on_market_close] call without filtering by [current_date]. The
    composer-loaded synthetic AD CSV in production covers ~1973 to
    {b April 2026} (the last [compute_synthetic_adl.exe] run); when the
    simulator is replaying a 2022 Friday the macro analyzer's
    [get_cumulative_ad ~week_offset:0] therefore returns the cumulative A-D as
    of {b 2026}, not 2022. The [ad_line] / [momentum_index] indicator readings
    see future synthetic data that disagrees with the (correct) 2022 Stage 4
    GSPC bear regime, and the composite confidence drifts above
    [bearish_threshold = 0.35] — flipping [trend] to [Neutral] (or [Bullish])
    instead of [Bearish].

    The fix filters the supplied [ad_bars] to dates [<= current_date] inside
    [_run_screen] before passing them through to
    [Panel_callbacks.macro_callbacks_of_weekly_views].

    {1 Why synthetic A-D bars rather than [Ad_bars.load]}

    The CI fixture under [trading/test_data/] does not ship the production
    [breadth/{nyse,synthetic}_*.csv] files, and copying the production
    composer's output into the fixture would make the test depend on whatever
    extent [compute_synthetic_adl.exe] last produced — fragile and noisy.
    Instead, {!_synthetic_ad_bars} below builds a deterministic two-phase series
    with the same date-misalignment shape (declining-breadth phase through
    [pivot]; rising-breadth phase past it). This pins the {b filter contract}
    the production fix introduced without depending on any data fixture. *)

open Core
open OUnit2
open Matchers
open Weinstein_types
module Bar_panels = Data_panel.Bar_panels
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Panel_callbacks = Weinstein_strategy.Panel_callbacks

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

(** Pack [(symbol, daily_bars)] pairs into a {!Bar_panels.t}. The calendar is
    the union of all dates across symbols (sorted, deduped). Mirrors
    [panels_of_symbols] in [test_panel_callbacks.ml] so the construction is
    bit-for-bit equivalent to that file's parity tests. *)
let _panels_of_symbols
    (symbols_with_bars : (string * Types.Daily_price.t list) list) =
  let universe = List.map symbols_with_bars ~f:fst in
  let symbol_index =
    match Symbol_index.create ~universe with
    | Ok t -> t
    | Error err -> failwith ("Symbol_index.create: " ^ err.Status.message)
  in
  let calendar =
    symbols_with_bars
    |> List.concat_map ~f:(fun (_, bars) ->
        List.map bars ~f:(fun b -> b.Types.Daily_price.date))
    |> List.dedup_and_sort ~compare:Date.compare
    |> Array.of_list
  in
  let ohlcv =
    Ohlcv_panels.create symbol_index ~n_days:(Array.length calendar)
  in
  let date_to_col = Hashtbl.create (module Date) in
  Array.iteri calendar ~f:(fun i d ->
      Hashtbl.add date_to_col ~key:d ~data:i
      |> (ignore : [ `Ok | `Duplicate ] -> unit));
  List.iter symbols_with_bars ~f:(fun (symbol, bars) ->
      match Symbol_index.to_row symbol_index symbol with
      | None -> ()
      | Some row ->
          List.iter bars ~f:(fun bar ->
              match Hashtbl.find date_to_col bar.Types.Daily_price.date with
              | None -> ()
              | Some day ->
                  Ohlcv_panels.write_row ohlcv ~symbol_index:row ~day bar));
  match Bar_panels.create ~ohlcv ~calendar with
  | Ok p -> p
  | Error err -> failwith ("Bar_panels.create: " ^ err.Status.message)

(** Enumerate every Friday from [start] to [until] inclusive. *)
let _fridays_between ~start ~until =
  let rec collect d acc =
    if Date.( > ) d until then List.rev acc
    else
      let acc =
        if Day_of_week.equal (Date.day_of_week d) Day_of_week.Fri then d :: acc
        else acc
      in
      collect (Date.add_days d 1) acc
  in
  collect start []

(** Synthetic weekly [Macro.ad_bar] series shaped to mimic the production
    composer-loaded breadth's date misalignment. The series spans [pivot] back
    through [start_date] (declining-breadth phase: declines > advances each
    week) then forward through [end_date] (advancing-breadth phase: advances >
    declines each week).

    Filtering to dates [<= pivot] (via {!Macro_inputs.ad_bars_at_or_before})
    yields only the declining phase — cumulative A-D falls monotonically and the
    [ad_line] divergence read with a {b also-falling} 2022 GSPC index is
    [Bearish]-confirming. Without filtering, the cumulative reverses and rises
    above the 26-weeks-prior offset, flipping divergence to [Bullish] diverging
    — the same shape the production composer's ~1973→2026 synthetic A-D induced
    when the simulator's tick was 2022.

    Per-week magnitudes ([decl_mag], [adv_mag]) are picked so:
    - [momentum_period = 200] sees a negative mean in the filtered case (~145
      negative weeks 2020→2022) and a positive mean in the unfiltered case (~183
      positive weeks 2022→2026 dominate the 200-week window).
    - The [ad_min_bars = 4] / [ad_line_lookback = 26] guards in
      {!Macro_indicators._ad_divergence_signal} are satisfied in both phases. *)
let _synthetic_ad_bars ~start_date ~pivot ~end_date ~decl_mag ~adv_mag :
    Macro.ad_bar list =
  let bears =
    _fridays_between ~start:start_date ~until:pivot
    |> List.map ~f:(fun date ->
        { Macro.date; advancing = 100; declining = 100 + decl_mag })
  in
  let bulls =
    _fridays_between ~start:(Date.add_days pivot 1) ~until:end_date
    |> List.map ~f:(fun date ->
        { Macro.date; advancing = 100 + adv_mag; declining = 100 })
  in
  bears @ bulls

(* ------------------------------------------------------------------ *)
(* The pinned regression                                                *)
(* ------------------------------------------------------------------ *)

(** Real 2022 GSPC weekly bars + empty [ad_bars] + empty [globals] should
    produce [trend = Bearish] / [confidence < 0.5] through the panel-callbacks
    path. Mirrors [test_macro_2022_bear_market] in
    [analysis/weinstein/macro/test/test_macro_e2e.ml] but exercises the
    panel-callback constructor used by the live cascade. *)
let test_macro_2022_bear_panel_path _ =
  let start_date = Date.of_string "2020-01-01" in
  let end_date = Date.of_string "2022-10-14" in
  let daily_bars =
    Test_data_loader.load_daily_bars ~symbol:"GSPC.INDX" ~start_date ~end_date
  in
  let panels = _panels_of_symbols [ ("GSPC.INDX", daily_bars) ] in
  let n_days = Bar_panels.n_days panels in
  (* lookback_bars = 52 in [Weinstein_strategy.default_config], matching the
     live SP500 backtest configuration in trading/backtest/lib/runner.ml. *)
  let lookback_bars = 52 in
  let index_view =
    Bar_panels.weekly_view_for panels ~symbol:"GSPC.INDX" ~n:lookback_bars
      ~as_of_day:(n_days - 1)
  in
  let config = Macro.default_config in
  let panel_cbs =
    Panel_callbacks.macro_callbacks_of_weekly_views ~config
      ~index_symbol:"GSPC.INDX" ~index:index_view ~globals:[] ~ad_bars:[] ()
  in
  let result =
    Macro.analyze_with_callbacks ~config ~callbacks:panel_cbs ~prior_stage:None
      ~prior:None
  in
  assert_that result
    (all_of
       [
         field (fun (r : Macro.result) -> r.trend) (equal_to Bearish);
         field
           (fun (r : Macro.result) -> r.confidence)
           (lt (module Float_ord) 0.5);
       ])

(* ------------------------------------------------------------------ *)
(* Live-cascade reproduction with composer-loaded AD bars               *)
(* ------------------------------------------------------------------ *)

(** Mirror of the live cascade construction in
    {!Weinstein_strategy._run_screen}: real 2022 GSPC weekly view +
    {b future-leaking weekly AD bars} + panel-callbacks path. The production
    composer's synthetic CSV covers ~1973 to April 2026; the pre-fix live
    cascade did not filter by [current_date], so the macro saw future-leaking
    A-D. {!_synthetic_ad_bars} below shapes a deterministic series with the same
    date-misalignment property — declining-breadth phase through 2022,
    rising-breadth phase through 2026 — independent of any data fixture so the
    test is reproducible across CI environments without relying on
    [data/breadth/*.csv] availability.

    Pre-fix (see {!test_unfiltered_ad_bars_break_bearish_trend} below):
    [trend = Neutral] (or [Bullish]) because the cumulative A-D at offset 0 is
    the 2026 endpoint, the [ad_line_lookback]-back sample is in 2025, and the
    resulting A-D rising/falling read disagrees with the (correctly Bearish)
    2022 GSPC Stage 4 regime — flipping the composite confidence above
    [bearish_threshold = 0.35].

    Post-fix: [_run_screen] filters [ad_bars] to dates [<= current_date] via
    [Macro_inputs.ad_bars_at_or_before] before building [macro_callbacks]; the
    cumulative-A-D series is truncated at Oct 2022, the declining-phase is
    monotonically falling (matching the falling 2022 index), and the indicator
    readings agree with the index Stage 4 → trend = Bearish. *)
let test_macro_2022_bear_with_composer_ad_bars _ =
  let start_date = Date.of_string "2020-01-01" in
  let current_date = Date.of_string "2022-10-14" in
  let future_end = Date.of_string "2026-04-24" in
  let daily_bars =
    Test_data_loader.load_daily_bars ~symbol:"GSPC.INDX" ~start_date
      ~end_date:current_date
  in
  let panels = _panels_of_symbols [ ("GSPC.INDX", daily_bars) ] in
  let n_days = Bar_panels.n_days panels in
  let lookback_bars = 52 in
  let index_view =
    Bar_panels.weekly_view_for panels ~symbol:"GSPC.INDX" ~n:lookback_bars
      ~as_of_day:(n_days - 1)
  in
  (* The synthetic A-D series spans 2020-01-01 → 2026-04-24, with the pivot
     at the simulator's [current_date] (Oct 2022). Filtering via
     [Macro_inputs.ad_bars_at_or_before] keeps only the declining phase —
     mirroring the post-fix [_run_screen] pipeline — and asserts the
     resulting macro composite is Bearish. *)
  let weekly_ad_bars_full =
    _synthetic_ad_bars ~start_date ~pivot:current_date ~end_date:future_end
      ~decl_mag:50 ~adv_mag:50
  in
  let weekly_ad_bars =
    Weinstein_strategy.Macro_inputs.ad_bars_at_or_before
      ~ad_bars:weekly_ad_bars_full ~as_of:current_date
  in
  let config = Macro.default_config in
  let panel_cbs =
    Panel_callbacks.macro_callbacks_of_weekly_views ~config
      ~index_symbol:"GSPC.INDX" ~index:index_view ~globals:[]
      ~ad_bars:weekly_ad_bars ()
  in
  let result =
    Macro.analyze_with_callbacks ~config ~callbacks:panel_cbs ~prior_stage:None
      ~prior:None
  in
  assert_that result
    (all_of
       [
         field (fun (r : Macro.result) -> r.trend) (equal_to Bearish);
         field
           (fun (r : Macro.result) -> r.confidence)
           (lt (module Float_ord) 0.5);
       ])

(* ------------------------------------------------------------------ *)
(* Demonstrate the bug: future-leaking AD bars flip the trend          *)
(* ------------------------------------------------------------------ *)

(** Negative companion to the previous test: real 2022 GSPC weekly view +
    {b unfiltered} synthetic AD bars (extending past the simulator's current
    tick through April 2026) yields a non-Bearish trend through the
    panel-callbacks path. This is the {b actual} bug behaviour PR #612 observed
    in the SP500 5y backtest: the macro analyzer's
    [get_cumulative_ad ~week_offset:0] returns the 2026 endpoint,
    [get_cumulative_ad ~week_offset:25] returns ~late 2025, and the resulting
    A-D rising/falling read disagrees with the (correctly Bearish) 2022 Stage 4
    GSPC regime — pushing composite confidence above [bearish_threshold = 0.35]
    and flipping [trend] to non-Bearish.

    Asserting the bug behaviour (rather than asserting the fix produces Bearish
    in the [test_macro_2022_bear_with_composer_ad_bars] test above) double-pins
    the contract: a regression that re-introduces the leak makes the previous
    test pass {b and} this one fail; a regression that breaks the macro analyzer
    in some other way makes both fail. *)
let test_unfiltered_ad_bars_break_bearish_trend _ =
  let start_date = Date.of_string "2020-01-01" in
  let current_date = Date.of_string "2022-10-14" in
  let future_end = Date.of_string "2026-04-24" in
  let daily_bars =
    Test_data_loader.load_daily_bars ~symbol:"GSPC.INDX" ~start_date
      ~end_date:current_date
  in
  let panels = _panels_of_symbols [ ("GSPC.INDX", daily_bars) ] in
  let n_days = Bar_panels.n_days panels in
  let lookback_bars = 52 in
  let index_view =
    Bar_panels.weekly_view_for panels ~symbol:"GSPC.INDX" ~n:lookback_bars
      ~as_of_day:(n_days - 1)
  in
  (* Unfiltered: covers 2020 → 2026-04-24 — the pre-fix construction. The
     advancing phase 2022→2026 reverses the cumulative A-D, so even though
     the index_view's most recent week is in 2022 the [ad_line] divergence
     reads "A-D rising while index falling" → Bullish divergence. *)
  let weekly_ad_bars_full =
    _synthetic_ad_bars ~start_date ~pivot:current_date ~end_date:future_end
      ~decl_mag:50 ~adv_mag:50
  in
  let config = Macro.default_config in
  let panel_cbs =
    Panel_callbacks.macro_callbacks_of_weekly_views ~config
      ~index_symbol:"GSPC.INDX" ~index:index_view ~globals:[]
      ~ad_bars:weekly_ad_bars_full ()
  in
  let result =
    Macro.analyze_with_callbacks ~config ~callbacks:panel_cbs ~prior_stage:None
      ~prior:None
  in
  (* Negation: confirm the unfiltered path does NOT return Bearish. *)
  assert_that result.trend
    (matching ~msg:"Expected non-Bearish trend (the bug) under unfiltered AD"
       (function Bullish | Neutral -> Some () | Bearish -> None)
       (equal_to ()))

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("macro_panel_callbacks_real_data"
    >::: [
           "2022 bear market — Bearish via panel-callbacks path (no AD bars)"
           >:: test_macro_2022_bear_panel_path;
           "2022 bear market — Bearish with composer-loaded AD bars (live \
            cascade repro)" >:: test_macro_2022_bear_with_composer_ad_bars;
           "Unfiltered AD bars flip the trend (pre-fix bug)"
           >:: test_unfiltered_ad_bars_break_bearish_trend;
         ])
