(** Strategy-level regression tests for the force-liquidation halt-and-resume
    contract (PR #695, qc-behavioral B1).

    The bug pinned here: [Weinstein_strategy._on_market_close] previously
    short-circuited on [halted = true] before invoking the macro analyser, so
    [prior_macro] was never refreshed once the portfolio-floor halt fired.
    [_maybe_reset_halt] was gated on [not halted] downstream of the
    short-circuit, so the halt latched permanently — contradicting the .mli
    claim that the halt clears when macro flips off [Bearish].

    The fix splits [_run_screen] into a cheap [_run_macro_only] pass and an
    expensive [_run_screen_after_macro] pass; the macro pass and
    [_maybe_reset_halt] now run on every Friday including halted Fridays, so the
    halt-reset fires the moment macro recovers.

    These tests drive [Internal_for_test.on_market_close] directly so the
    halt-and-resume sequencing is observable without going through {!make}'s
    closure. *)

open Core
open OUnit2
open Matchers
open Weinstein_strategy
open Weinstein_types
module Bar_panels = Data_panel.Bar_panels
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module FL = Portfolio_risk.Force_liquidation

(* ------------------------------------------------------------------ *)
(* Helpers — minimal panel-backed bar reader on a single index symbol  *)
(* ------------------------------------------------------------------ *)

let _make_daily_bar ~date ~price =
  {
    Types.Daily_price.date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1_000_000;
  }

(** Build [n] consecutive daily bars (one per calendar day) starting at
    [start_date], with prices walking by [step] per day. The strategy reads
    weekly views on top of the daily panel; producing one daily bar per day
    gives the weekly aggregator a clean sequence to bucket. *)
let _make_daily_bars ~start_date ~n ~start_price ~step =
  List.init n ~f:(fun i ->
      let date = Date.add_days start_date i in
      let price = start_price +. (Float.of_int i *. step) in
      _make_daily_bar ~date ~price)

(** Build a [Bar_panels.t] from [(symbol, daily_bars)] pairs. Mirrors the
    construction used by [test_panel_callbacks.ml]. *)
let _panels_of_symbols
    (symbols_with_bars : (string * Types.Daily_price.t list) list) =
  let universe = List.map symbols_with_bars ~f:fst in
  let symbol_index =
    match Symbol_index.create ~universe with
    | Ok t -> t
    | Error err -> assert_failure ("Symbol_index.create: " ^ err.Status.message)
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
  | Error err -> assert_failure ("Bar_panels.create: " ^ err.Status.message)

(** Find a Friday close to [start_date] (i.e. the next Friday on or after). *)
let _next_friday d =
  let rec go d =
    if Day_of_week.equal (Date.day_of_week d) Day_of_week.Fri then d
    else go (Date.add_days d 1)
  in
  go d

type _strategy_state = {
  stop_states : Weinstein_stops.stop_state String.Map.t ref;
  prior_macro : market_trend ref;
  prior_macro_result : Macro.result option ref;
  peak_tracker : FL.Peak_tracker.t;
  prior_stages : stage Hashtbl.M(String).t;
  sector_prior_stages : stage Hashtbl.M(String).t;
  ticker_sectors : (string, string) Hashtbl.t;
  bar_reader : Bar_reader.t;
}
(** Build a fresh closure-state bundle that mirrors what {!make} constructs
    internally. Returns [(state, get_price)] where [state] holds the mutable
    refs used by {!Internal_for_test.on_market_close}. *)

let _fresh_state ~bar_reader =
  {
    stop_states = ref String.Map.empty;
    prior_macro = ref Neutral;
    prior_macro_result = ref None;
    peak_tracker = FL.Peak_tracker.create ();
    prior_stages = Hashtbl.create (module String);
    sector_prior_stages = Hashtbl.create (module String);
    ticker_sectors = Hashtbl.create (module String);
    bar_reader;
  }

(** Wrap [Bar_reader.daily_bars_for state.bar_reader] into the
    [Strategy_interface.get_price_fn] shape expected by [_on_market_close]. *)
let _get_price_of_state state ~current_date symbol =
  match
    Bar_reader.daily_bars_for state.bar_reader ~symbol ~as_of:current_date
  with
  | [] -> None
  | bars -> List.last bars

let _drive_tick state ~config ~current_date ~portfolio =
  Internal_for_test.on_market_close ~config ~ad_bars:[]
    ~stop_states:state.stop_states ~prior_macro:state.prior_macro
    ~prior_macro_result:state.prior_macro_result
    ~peak_tracker:state.peak_tracker ~bar_reader:state.bar_reader
    ~prior_stages:state.prior_stages
    ~sector_prior_stages:state.sector_prior_stages
    ~ticker_sectors:state.ticker_sectors ~audit_recorder:Audit_recorder.noop
    ~get_price:(_get_price_of_state state ~current_date)
    ~get_indicator:(fun _ _ _ _ -> None)
    ~portfolio

(* ------------------------------------------------------------------ *)
(* Direct-unit pinning of _maybe_reset_halt                            *)
(* ------------------------------------------------------------------ *)

(** Pins the macro-flip semantics of {!Internal_for_test.maybe_reset_halt}. The
    halt clears when macro is [Bullish] or [Neutral]; stays armed under
    [Bearish]. *)
let test_maybe_reset_halt_clears_on_non_bearish _ =
  let pt = FL.Peak_tracker.create () in
  FL.Peak_tracker.mark_halted pt;
  Internal_for_test.maybe_reset_halt ~peak_tracker:pt ~macro_trend:Bullish;
  assert_that (FL.Peak_tracker.halt_state pt) (equal_to FL.Active)

let test_maybe_reset_halt_clears_on_neutral _ =
  let pt = FL.Peak_tracker.create () in
  FL.Peak_tracker.mark_halted pt;
  Internal_for_test.maybe_reset_halt ~peak_tracker:pt ~macro_trend:Neutral;
  assert_that (FL.Peak_tracker.halt_state pt) (equal_to FL.Active)

let test_maybe_reset_halt_persists_under_bearish _ =
  let pt = FL.Peak_tracker.create () in
  FL.Peak_tracker.mark_halted pt;
  Internal_for_test.maybe_reset_halt ~peak_tracker:pt ~macro_trend:Bearish;
  assert_that (FL.Peak_tracker.halt_state pt) (equal_to FL.Halted)

(* ------------------------------------------------------------------ *)
(* End-to-end halt-resume regression                                    *)
(* ------------------------------------------------------------------ *)

let _index_symbol = "GSPCX"

(** Build a panel-backed bar reader with a steadily-rising index series of
    [n_days] bars ending on or before [end_date]. The trend is strongly upward
    (1% daily gain); over 30+ weeks of weekly aggregation this drives the macro
    analyser away from [Bearish] under empty AD bars + empty globals. *)
let _rising_index_reader ~end_date =
  let n_days = 260 in
  (* ~52 weeks of trading days *)
  let start_date = Date.add_days end_date (-(n_days - 1)) in
  let bars =
    _make_daily_bars ~start_date ~n:n_days ~start_price:100.0 ~step:1.0
  in
  let panels = _panels_of_symbols [ (_index_symbol, bars) ] in
  Bar_reader.of_panels panels

(** B1 regression: the halt-reset fires on Friday even when the peak tracker
    enters the tick already in [Halted]. Pre-fix [_on_market_close] returned
    [entry_transitions = []] AND skipped [_maybe_reset_halt] entirely (gated on
    [not halted]); the halt latched permanently. Post-fix the macro pass runs
    unconditionally on Friday and [_maybe_reset_halt] consults the fresh trend,
    flipping the halt back to [Active] when macro is no longer [Bearish]. *)
let test_halt_resets_after_macro_flip _ =
  let current_date = _next_friday (Date.of_string "2024-04-26") in
  let bar_reader = _rising_index_reader ~end_date:current_date in
  let state = _fresh_state ~bar_reader in
  (* Prime the pump: halt is active before the tick. *)
  FL.Peak_tracker.mark_halted state.peak_tracker;
  assert_that
    (FL.Peak_tracker.halt_state state.peak_tracker)
    (equal_to FL.Halted);
  let config =
    Weinstein_strategy.default_config ~universe:[] ~index_symbol:_index_symbol
  in
  let portfolio : Trading_strategy.Portfolio_view.t =
    { cash = 100_000.0; positions = String.Map.empty }
  in
  let result = _drive_tick state ~config ~current_date ~portfolio in
  (* Tick must succeed cleanly even with the halt active. *)
  assert_that result is_ok;
  (* The rising-index series produces a non-Bearish macro trend; the halt
     therefore clears. Pre-fix, macro was never refreshed and the halt
     remained Halted. *)
  assert_that
    (FL.Peak_tracker.halt_state state.peak_tracker)
    (equal_to FL.Active);
  (* prior_macro must reflect the just-computed trend (not the initial
     Neutral default). The rising series hits Bullish under the panel-
     callbacks macro pipeline. *)
  assert_that !(state.prior_macro)
    (matching ~msg:"Expected non-Bearish macro after rising index"
       (function Bearish -> None | t -> Some t)
       (equal_to Bullish))

(** Symmetric: the halt persists when macro stays [Bearish]. Pinned via a
    declining index series — the macro analyser returns [Bearish] under a
    monotonically falling 30-week MA. The halt does NOT clear, even though the
    macro pass ran. *)
let test_halt_persists_when_macro_stays_bearish _ =
  let current_date = _next_friday (Date.of_string "2024-04-26") in
  let n_days = 260 in
  let start_date = Date.add_days current_date (-(n_days - 1)) in
  let bars =
    _make_daily_bars ~start_date ~n:n_days ~start_price:200.0 ~step:(-0.5)
  in
  let panels = _panels_of_symbols [ (_index_symbol, bars) ] in
  let bar_reader = Bar_reader.of_panels panels in
  let state = _fresh_state ~bar_reader in
  FL.Peak_tracker.mark_halted state.peak_tracker;
  let config =
    Weinstein_strategy.default_config ~universe:[] ~index_symbol:_index_symbol
  in
  let portfolio : Trading_strategy.Portfolio_view.t =
    { cash = 100_000.0; positions = String.Map.empty }
  in
  let result = _drive_tick state ~config ~current_date ~portfolio in
  assert_that result is_ok;
  assert_that
    (FL.Peak_tracker.halt_state state.peak_tracker)
    (equal_to FL.Halted);
  assert_that !(state.prior_macro) (equal_to Bearish)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "force_liquidation_strategy"
  >::: [
         "maybe_reset_halt clears on Bullish"
         >:: test_maybe_reset_halt_clears_on_non_bearish;
         "maybe_reset_halt clears on Neutral"
         >:: test_maybe_reset_halt_clears_on_neutral;
         "maybe_reset_halt persists under Bearish"
         >:: test_maybe_reset_halt_persists_under_bearish;
         "halt resets after macro flip on Friday tick"
         >:: test_halt_resets_after_macro_flip;
         "halt persists when macro stays Bearish"
         >:: test_halt_persists_when_macro_stays_bearish;
       ]

let () = run_test_tt_main suite
