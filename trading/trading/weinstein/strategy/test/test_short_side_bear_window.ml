(** Bear-window contract regression tests for the short-side strategy path.

    Pins both directions of Weinstein's Ch. 11 bear-market shorting contract at
    the strategy integration level (one layer above the per-screener-rule unit
    tests in [analysis/weinstein/screener/test/test_screener.ml]):

    - {b Suppression}: under [macro_trend = Bearish], the screener must emit
      zero buy candidates even when the stocks list contains otherwise
      qualifying Stage 2 long setups. Cross-feeding into
      {!Weinstein_strategy.entries_from_candidates} must therefore yield zero
      Long {!Trading_strategy.Position.CreateEntering} transitions.
    - {b Emission}: under [macro_trend = Bearish], the screener must emit shorts
      when the stocks list contains Stage 4 breakdown candidates with negative /
      absent RS in non-Strong sectors. Feeding those candidates into
      {!Weinstein_strategy.entries_from_candidates} must produce
      [CreateEntering] transitions whose [side = Short].

    {1 Why this test exists}

    [dev/notes/short-side-real-data-verification-2026-04-27.md] — the real-data
    SP500 5y backtest (PR #612) yields
    {b 0 short trades and 37 long entries opened in 2022 bear} despite
    [Macro.analyze]'s unit-level test on real GSPC bars correctly returning
    [Bearish]. The disconnect lives between [Macro.analyze] and the screener /
    [entries_from_candidates] in the live cascade. The unit tests at the
    screener layer ([test_bearish_macro_no_buys],
    [test_short_candidates_are_short], [test_positive_rs_blocks_short]) pass;
    the strategy-level test [test_weinstein_bearish_index_suppresses_entries] in
    [test_weinstein_strategy_smoke.ml] pins suppression but {b not} emission.

    This file pins both directions of the bear-window contract through the
    public [Screener.screen] -> [Weinstein_strategy.entries_from_candidates]
    seam, so a regression that breaks either suppression or emission is caught
    deterministically without depending on the live cascade's macro plumbing.

    {1 Scope}

    These tests do {b not} reproduce PR #612's live-cascade symptom directly —
    that requires real GSPC bars and the full [Macro.analyze_with_callbacks]
    path through [Panel_callbacks.macro_callbacks_of_weekly_views]. What they
    pin is the {b downstream} contract: given [macro_trend = Bearish] is
    correctly determined, the strategy emits the right transitions. If a future
    change accidentally breaks either direction (e.g., pulling the
    [Bearish -> []] gate out of the screener), this file fails. The live
    cascade's macro-feed bug remains a separate diagnosis (likely in
    [_run_screen]'s [macro_callbacks] construction); when that fix lands, these
    tests still hold. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Synthetic bar helpers (mirror analysis/weinstein/screener/test)     *)
(* ------------------------------------------------------------------ *)

let _make_bar ?(volume = 1000) date adjusted_close =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = adjusted_close;
    high_price = adjusted_close *. 1.02;
    low_price = adjusted_close *. 0.98;
    close_price = adjusted_close;
    adjusted_close;
    volume;
  }

let _weekly_bars_with_volumes prices_and_volumes =
  let base = Date.of_string "2020-01-06" in
  List.mapi prices_and_volumes ~f:(fun i (p, v) ->
      _make_bar ~volume:v (Date.to_string (Date.add_days base (i * 7))) p)

(** Rising weekly bars with a high-volume spike at [spike_idx]. Mirrors
    [rising_bars_with_spike] in [test_screener.ml]. *)
let _rising_bars_with_spike ~n start stop_ ~spike_idx =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i ->
      let p = start +. (Float.of_int i *. step) in
      let v = if i = spike_idx then 3000 else 1000 in
      (p, v))
  |> _weekly_bars_with_volumes

(** Declining weekly bars with a high-volume spike at [spike_idx]. Mirrors
    [declining_bars_with_spike] in [test_screener.ml]. *)
let _declining_bars_with_spike ~n start stop_ ~spike_idx =
  let step = (start -. stop_) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i ->
      let p = start -. (Float.of_int i *. step) in
      let v = if i = spike_idx then 3000 else 1000 in
      (p, v))
  |> _weekly_bars_with_volumes

let _as_of = Date.of_string "2024-01-01"

let _make_analysis ticker prior bars =
  Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker ~bars
    ~benchmark_bars:[] ~prior_stage:prior ~as_of_date:_as_of

let _make_sector ?(rating = (Screener.Neutral : Screener.sector_rating)) name :
    Screener.sector_context =
  {
    sector_name = name;
    rating;
    stage = Stage2 { weeks_advancing = 5; late = false };
  }

let _sector_map_of entries =
  let m = Hashtbl.create (module String) in
  List.iter entries ~f:(fun (ticker, sector) ->
      Hashtbl.set m ~key:ticker ~data:sector);
  m

(* ------------------------------------------------------------------ *)
(* Helpers for the entries_from_candidates seam                         *)
(* ------------------------------------------------------------------ *)

let _empty_portfolio : Trading_strategy.Portfolio_view.t =
  { cash = 100_000.0; positions = String.Map.empty }

let _bar_for_candidate (c : Screener.scored_candidate) =
  ( c.ticker,
    _make_bar (Date.to_string _as_of) c.suggested_entry ~volume:1_000_000 )

let _get_price_of_candidates candidates =
  let bars = List.map candidates ~f:_bar_for_candidate in
  fun symbol ->
    List.find_map bars ~f:(fun (sym, bar) ->
        if String.equal sym symbol then Some bar else None)

let _entry_side (t : Trading_strategy.Position.transition) =
  match t.kind with
  | Trading_strategy.Position.CreateEntering { side; _ } -> Some side
  | _ -> None

(* ------------------------------------------------------------------ *)
(* Stocks list: a Stage 2 long-eligible + a Stage 4 short-eligible      *)
(* ------------------------------------------------------------------ *)

(** Build the canonical mixed-stocks fixture: one Stage 2 breakout candidate
    that would otherwise pass the long cascade, and one Stage 4 breakdown
    candidate that should pass the short cascade. Sectors are set so neither is
    blocked by the sector gate (Stage 2 in Strong sector, Stage 4 in Weak sector
    — the screener's default rules). Mirrors the bar shapes already used by
    [test_screener.ml] so the per-cascade unit tests there serve as the
    cross-reference for "these inputs are individually valid". *)
let _mixed_stocks_and_sector_map () =
  let long_bars = _rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let long_stock =
    _make_analysis "BULL" (Some (Stage1 { weeks_in_base = 12 })) long_bars
  in
  let short_bars = _declining_bars_with_spike ~n:60 100.0 30.0 ~spike_idx:55 in
  let short_stock =
    _make_analysis "BEAR" (Some (Stage3 { weeks_topping = 8 })) short_bars
  in
  let sector_map =
    _sector_map_of
      [
        ("BULL", _make_sector ~rating:Strong "Tech");
        ("BEAR", _make_sector ~rating:Weak "Energy");
      ]
  in
  ([ long_stock; short_stock ], sector_map)

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

(** Direction 1: under [macro_trend = Bearish] the screener emits zero buy
    candidates, even when the stocks list contains a Stage 2 setup that would
    otherwise grade. Confirms the macro gate suppresses longs when the bear
    branch is active. *)
let test_bearish_macro_suppresses_long_candidates _ =
  let stocks, sector_map = _mixed_stocks_and_sector_map () in
  let result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Bearish
      ~sector_map ~stocks ~held_tickers:[]
  in
  assert_that result
    (all_of
       [
         field (fun r -> r.Screener.macro_trend) (equal_to Bearish);
         field (fun r -> r.Screener.buy_candidates) is_empty;
       ])

(** Direction 2: under [macro_trend = Bearish] the screener emits at least one
    short candidate (the Stage 4 setup with absent RS in a Weak sector).
    Confirms the bear branch actively produces shorts rather than just
    suppressing longs. *)
let test_bearish_macro_emits_short_candidates _ =
  let stocks, sector_map = _mixed_stocks_and_sector_map () in
  let result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Bearish
      ~sector_map ~stocks ~held_tickers:[]
  in
  assert_that result
    (all_of
       [
         field (fun r -> r.Screener.macro_trend) (equal_to Bearish);
         field
           (fun r -> List.length r.Screener.short_candidates)
           (gt (module Int_ord) 0);
         field
           (fun r ->
             List.map r.Screener.short_candidates ~f:(fun c -> c.Screener.side))
           (elements_are
              [
                equal_to
                  (Trading_base.Types.Short : Trading_base.Types.position_side);
              ]);
         field
           (fun r ->
             List.map r.Screener.short_candidates ~f:(fun c ->
                 c.Screener.ticker))
           (elements_are [ equal_to "BEAR" ]);
       ])

(** End-to-end seam: feed the bearish-macro screener output into
    {!Weinstein_strategy.entries_from_candidates} and assert every emitted
    transition is a [CreateEntering] with [side = Short]. This is the key
    integration test — a regression that lets long entries leak into the bear
    branch (the symptom in dev/notes/short-side-real-data-verification-
    2026-04-27.md) fails this test deterministically. *)
let test_bearish_macro_emits_only_short_transitions _ =
  let stocks, sector_map = _mixed_stocks_and_sector_map () in
  let screen_result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Bearish
      ~sector_map ~stocks ~held_tickers:[]
  in
  let candidates =
    screen_result.Screener.buy_candidates
    @ screen_result.Screener.short_candidates
  in
  let cfg = default_config ~universe:[ "BULL"; "BEAR" ] ~index_symbol:"GSPCX" in
  let stop_states = ref String.Map.empty in
  let bar_reader = Bar_reader.empty () in
  let transitions =
    entries_from_candidates ~config:cfg ~candidates ~stop_states ~bar_reader
      ~portfolio:_empty_portfolio
      ~get_price:(_get_price_of_candidates candidates)
      ~current_date:_as_of ()
  in
  let sides = List.filter_map transitions ~f:_entry_side in
  assert_that
    (List.length transitions, sides)
    (all_of
       [
         field (fun (n, _) -> n) (gt (module Int_ord) 0);
         field
           (fun (_, ss) -> ss)
           (elements_are
              [
                equal_to
                  (Trading_base.Types.Short : Trading_base.Types.position_side);
              ]);
       ])

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("short_side_bear_window"
    >::: [
           "Bearish macro suppresses long candidates"
           >:: test_bearish_macro_suppresses_long_candidates;
           "Bearish macro emits short candidates"
           >:: test_bearish_macro_emits_short_candidates;
           "entries_from_candidates emits only Short transitions under Bearish"
           >:: test_bearish_macro_emits_only_short_transitions;
         ])
