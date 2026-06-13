(** Unit + integration tests for the [enable_short_side] entry gate
    ({!Short_side_gate.combine}).

    Pins the long-only baseline contract that every Cell-E grid / broad-universe
    PIT re-baseline relies on:

    - [enable_short_side = false] → {b zero} short candidates reach the entry
      walk, even when the screener emitted shorts. This is what makes
      [((enable_short_side false))] an honest "long-only" run.
    - [enable_short_side = true] (default) → shorts are admitted, after the
      [short_min_price] economic-margin floor is applied (no-op when
      [short_min_price <= 0.0]).

    {1 Why this file exists}

    The switch used to be an inline [if]/[else] in
    {!Weinstein_strategy_screening.screen_universe} with no dedicated regression
    test — the 2026-06-12 trade-forensics G5 finding ("shorts present in a
    'long' baseline") could not be distinguished between "the run had the flag
    true" and "the gate leaks". These tests pin the gate's contract directly so
    a future refactor cannot silently let shorts leak back into a [false] run,
    and the integration test below pins the same contract end-to-end through
    {!Weinstein_strategy.entries_from_candidates} on the bear-window fixture that
    {e otherwise} produces Short transitions (mirrors
    [test_short_side_bear_window.ml]).

    The spine is untouched: short selling in Stage 3/4 remains Weinstein's
    methodology (see [.claude/rules/weinstein-faithful-core.md]); this only makes
    the existing [enable_short_side] {e off} switch honest and testable. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Candidate builder (mirrors test_short_min_price_gate.ml)            *)
(* ------------------------------------------------------------------ *)

let _make_candidate ~ticker ~side ~suggested_entry : Screener.scored_candidate =
  {
    ticker;
    analysis =
      Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
        ~bars:[] ~benchmark_bars:[] ~prior_stage:None
        ~as_of_date:(Date.of_string "2024-01-01");
    side;
    sector =
      {
        sector_name = "Test";
        rating = Screener.Neutral;
        stage = Stage2 { weeks_advancing = 5; late = false };
      };
    grade = C;
    score = 0;
    suggested_entry;
    suggested_stop = suggested_entry *. 1.08;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [];
  }

let _long ~ticker ~suggested_entry =
  _make_candidate ~ticker ~side:Trading_base.Types.Long ~suggested_entry

let _short ~ticker ~suggested_entry =
  _make_candidate ~ticker ~side:Trading_base.Types.Short ~suggested_entry

let _sides candidates =
  List.map candidates ~f:(fun c -> c.Screener.side)

let _tickers candidates =
  List.map candidates ~f:(fun c -> c.Screener.ticker)

(* ------------------------------------------------------------------ *)
(* Unit tests on Short_side_gate.combine                               *)
(* ------------------------------------------------------------------ *)

(** [enable_short_side = false] drops every short candidate: the combined list
    is exactly [buy_candidates], in order, regardless of how many shorts the
    screener produced. This is the long-only baseline contract. *)
let test_disabled_drops_all_shorts _ =
  let combined =
    Short_side_gate.combine ~enable_short_side:false ~short_min_price:0.0
      ~buy_candidates:[ _long ~ticker:"BULL" ~suggested_entry:50.0 ]
      ~short_candidates:
        [
          _short ~ticker:"BEAR1" ~suggested_entry:40.0;
          _short ~ticker:"BEAR2" ~suggested_entry:30.0;
        ]
  in
  assert_that combined
    (all_of
       [
         field _tickers (elements_are [ equal_to "BULL" ]);
         field
           (fun cs ->
             List.count cs ~f:(fun c ->
                 Trading_base.Types.equal_position_side c.Screener.side
                   Trading_base.Types.Short))
           (equal_to 0);
       ])

(** [enable_short_side = false] with an empty buy list yields an empty combined
    list — no entry path can emit a short. *)
let test_disabled_with_no_longs_is_empty _ =
  let combined =
    Short_side_gate.combine ~enable_short_side:false ~short_min_price:0.0
      ~buy_candidates:[]
      ~short_candidates:[ _short ~ticker:"BEAR" ~suggested_entry:40.0 ]
  in
  assert_that (List.length combined) (equal_to 0)

(** [enable_short_side = true] with the default [short_min_price = 0.0] admits
    all shorts, appended after the longs (order: longs first, then shorts). *)
let test_enabled_admits_shorts_after_longs _ =
  let combined =
    Short_side_gate.combine ~enable_short_side:true ~short_min_price:0.0
      ~buy_candidates:[ _long ~ticker:"BULL" ~suggested_entry:50.0 ]
      ~short_candidates:[ _short ~ticker:"BEAR" ~suggested_entry:40.0 ]
  in
  assert_that combined
    (all_of
       [
         field _tickers (elements_are [ equal_to "BULL"; equal_to "BEAR" ]);
         field _sides
           (elements_are
              [
                equal_to (Trading_base.Types.Long : Trading_base.Types.position_side);
                equal_to
                  (Trading_base.Types.Short : Trading_base.Types.position_side);
              ]);
       ])

(** [enable_short_side = true] with [short_min_price = 17.0] drops the THM-class
    sub-$17 short ($0.69 in the forensics open disaster) while keeping the
    above-floor short — pins that the economic-margin floor is applied when
    shorts are admitted (the [Short_min_price_gate] interaction). *)
let test_enabled_applies_short_min_price_floor _ =
  let combined =
    Short_side_gate.combine ~enable_short_side:true ~short_min_price:17.0
      ~buy_candidates:[ _long ~ticker:"BULL" ~suggested_entry:50.0 ]
      ~short_candidates:
        [
          _short ~ticker:"THM" ~suggested_entry:0.69;
          _short ~ticker:"BEAR" ~suggested_entry:40.0;
        ]
  in
  assert_that combined
    (field _tickers (elements_are [ equal_to "BULL"; equal_to "BEAR" ]))

(* ------------------------------------------------------------------ *)
(* Integration: bear-window fixture through entries_from_candidates    *)
(* (mirrors test_short_side_bear_window.ml so the input is known to    *)
(*  otherwise produce Short transitions)                               *)
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
    active_through = None;
  }

let _weekly_bars prices_and_volumes =
  let base = Date.of_string "2020-01-06" in
  List.mapi prices_and_volumes ~f:(fun i (p, v) ->
      _make_bar ~volume:v (Date.to_string (Date.add_days base (i * 7))) p)

let _rising_bars_with_spike ~n start stop_ ~spike_idx =
  let step = (stop_ -. start) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i ->
      let p = start +. (Float.of_int i *. step) in
      let v = if i = spike_idx then 3000 else 1000 in
      (p, v))
  |> _weekly_bars

let _declining_bars_with_spike ~n start stop_ ~spike_idx =
  let step = (start -. stop_) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i ->
      let p = start -. (Float.of_int i *. step) in
      let v = if i = spike_idx then 3000 else 1000 in
      (p, v))
  |> _weekly_bars

let _as_of = Date.of_string "2024-01-01"

let _analysis ticker prior bars =
  Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker ~bars
    ~benchmark_bars:[] ~prior_stage:prior ~as_of_date:_as_of

let _sector ?(rating = (Screener.Neutral : Screener.sector_rating)) name :
    Screener.sector_context =
  {
    sector_name = name;
    rating;
    stage = Stage2 { weeks_advancing = 5; late = false };
  }

let _sector_map entries =
  let m = Hashtbl.create (module String) in
  List.iter entries ~f:(fun (ticker, sector) ->
      Hashtbl.set m ~key:ticker ~data:sector);
  m

let _empty_portfolio : Trading_strategy.Portfolio_view.t =
  { cash = 100_000.0; positions = String.Map.empty }

let _bar_for_candidate (c : Screener.scored_candidate) =
  ( c.ticker,
    _make_bar (Date.to_string _as_of) c.suggested_entry ~volume:1_000_000 )

let _get_price_of candidates =
  let bars = List.map candidates ~f:_bar_for_candidate in
  fun symbol ->
    List.find_map bars ~f:(fun (sym, bar) ->
        if String.equal sym symbol then Some bar else None)

let _entry_side (t : Trading_strategy.Position.transition) =
  match t.kind with
  | Trading_strategy.Position.CreateEntering { side; _ } -> Some side
  | _ -> None

let _mixed_stocks_and_sector_map () =
  let long_bars = _rising_bars_with_spike ~n:35 50.0 100.0 ~spike_idx:31 in
  let long_stock =
    _analysis "BULL" (Some (Stage1 { weeks_in_base = 12 })) long_bars
  in
  let short_bars = _declining_bars_with_spike ~n:60 100.0 30.0 ~spike_idx:55 in
  let short_stock =
    _analysis "BEAR" (Some (Stage3 { weeks_topping = 8 })) short_bars
  in
  let sector_map =
    _sector_map
      [
        ("BULL", _sector ~rating:Strong "Tech");
        ("BEAR", _sector ~rating:Weak "Energy");
      ]
  in
  ([ long_stock; short_stock ], sector_map)

(** The decisive regression: feed the SAME bearish-macro screener output the
    [test_short_side_bear_window.ml] emission test uses — known to produce Short
    transitions — but route the candidate assembly through
    {!Short_side_gate.combine} with [enable_short_side = false]. The combined
    list must contain no short candidate, so
    {!Weinstein_strategy.entries_from_candidates} emits {b zero} Short
    transitions. This pins the long-only baseline contract end-to-end. *)
let test_disabled_suppresses_short_transitions_e2e _ =
  let stocks, sector_map = _mixed_stocks_and_sector_map () in
  let screen_result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Bearish
      ~sector_map ~stocks ~held_tickers:[]
  in
  let candidates =
    Short_side_gate.combine ~enable_short_side:false ~short_min_price:0.0
      ~buy_candidates:screen_result.Screener.buy_candidates
      ~short_candidates:screen_result.Screener.short_candidates
  in
  let cfg = default_config ~universe:[ "BULL"; "BEAR" ] ~index_symbol:"GSPCX" in
  let stop_states = ref String.Map.empty in
  let bar_reader = Bar_reader.empty () in
  let transitions =
    entries_from_candidates ~config:cfg ~candidates ~stop_states ~bar_reader
      ~portfolio:_empty_portfolio
      ~get_price:(_get_price_of candidates)
      ~current_date:_as_of ()
  in
  let short_sides =
    List.filter_map transitions ~f:_entry_side
    |> List.filter ~f:(fun s ->
           Trading_base.Types.equal_position_side s Trading_base.Types.Short)
  in
  assert_that (List.length short_sides) (equal_to 0)

(** Companion to the above: with [enable_short_side = true] the SAME fixture
    {e does} emit at least one Short transition (and no Longs, since the macro
    gate suppresses longs under Bearish). Confirms the suppression test above is
    pinning a real behaviour change, not a fixture that produced no shorts to
    begin with. *)
let test_enabled_emits_short_transitions_e2e _ =
  let stocks, sector_map = _mixed_stocks_and_sector_map () in
  let screen_result =
    Screener.screen ~config:Screener.default_config ~macro_trend:Bearish
      ~sector_map ~stocks ~held_tickers:[]
  in
  let candidates =
    Short_side_gate.combine ~enable_short_side:true ~short_min_price:0.0
      ~buy_candidates:screen_result.Screener.buy_candidates
      ~short_candidates:screen_result.Screener.short_candidates
  in
  let cfg = default_config ~universe:[ "BULL"; "BEAR" ] ~index_symbol:"GSPCX" in
  let stop_states = ref String.Map.empty in
  let bar_reader = Bar_reader.empty () in
  let transitions =
    entries_from_candidates ~config:cfg ~candidates ~stop_states ~bar_reader
      ~portfolio:_empty_portfolio
      ~get_price:(_get_price_of candidates)
      ~current_date:_as_of ()
  in
  let sides = List.filter_map transitions ~f:_entry_side in
  assert_that sides
    (elements_are
       [
         equal_to (Trading_base.Types.Short : Trading_base.Types.position_side);
       ])

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("short_side_gate"
    >::: [
           "disabled drops all shorts" >:: test_disabled_drops_all_shorts;
           "disabled with no longs is empty"
           >:: test_disabled_with_no_longs_is_empty;
           "enabled admits shorts after longs"
           >:: test_enabled_admits_shorts_after_longs;
           "enabled applies short_min_price floor"
           >:: test_enabled_applies_short_min_price_floor;
           "disabled suppresses short transitions e2e"
           >:: test_disabled_suppresses_short_transitions_e2e;
           "enabled emits short transitions e2e"
           >:: test_enabled_emits_short_transitions_e2e;
         ])
