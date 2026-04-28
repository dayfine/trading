open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let make_bar date price =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = price;
    high_price = price *. 1.02;
    low_price = price *. 0.98;
    close_price = price;
    adjusted_close = price;
    volume = 1000;
  }

let get_price_of prices symbol =
  List.find_map prices ~f:(fun (sym, bar) ->
      if String.equal sym symbol then Some bar else None)

let empty_get_indicator _symbol _name _period _cadence = None
let empty_positions = String.Map.empty

let empty_portfolio : Trading_strategy.Portfolio_view.t =
  { cash = 100000.0; positions = empty_positions }

let cfg = default_config ~universe:[ "AAPL"; "GSPCX" ] ~index_symbol:"GSPCX"

(* ------------------------------------------------------------------ *)
(* make: produces a STRATEGY module                                     *)
(* ------------------------------------------------------------------ *)

let test_make_produces_strategy _ =
  let (module S) = make cfg in
  assert_that S.name (equal_to "Weinstein")

(* ------------------------------------------------------------------ *)
(* on_market_close: empty universe returns empty transitions           *)
(* ------------------------------------------------------------------ *)

let test_empty_universe_no_transitions _ =
  let cfg = default_config ~universe:[] ~index_symbol:"GSPCX" in
  let (module S) = make cfg in
  let result =
    S.on_market_close ~get_price:(get_price_of [])
      ~get_indicator:empty_get_indicator ~portfolio:empty_portfolio
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun o -> o.Trading_strategy.Strategy_interface.transitions)
          is_empty))

(* ------------------------------------------------------------------ *)
(* on_market_close: no price data returns empty transitions            *)
(* ------------------------------------------------------------------ *)

let test_no_price_data_no_transitions _ =
  let (module S) = make cfg in
  let result =
    S.on_market_close ~get_price:(get_price_of [])
      ~get_indicator:empty_get_indicator ~portfolio:empty_portfolio
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun o -> o.Trading_strategy.Strategy_interface.transitions)
          is_empty))

(* ------------------------------------------------------------------ *)
(* on_market_close: called multiple times stays consistent             *)
(* ------------------------------------------------------------------ *)

let test_multiple_calls_consistent _ =
  let (module S) = make cfg in
  let prices =
    [
      ("GSPCX", make_bar "2024-01-05" 4500.0);
      ("AAPL", make_bar "2024-01-05" 180.0);
    ]
  in
  let get_price = get_price_of prices in
  let result1 =
    S.on_market_close ~get_price ~get_indicator:empty_get_indicator
      ~portfolio:empty_portfolio
  in
  let result2 =
    S.on_market_close ~get_price ~get_indicator:empty_get_indicator
      ~portfolio:empty_portfolio
  in
  assert_that result1 is_ok;
  assert_that result2 is_ok

(* ------------------------------------------------------------------ *)
(* Helpers for position construction                                    *)
(* ------------------------------------------------------------------ *)

let make_holding_pos ticker price date =
  let pos_id = ticker in
  let make_trans kind =
    { Trading_strategy.Position.position_id = pos_id; date; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error _ -> OUnit2.assert_failure "position setup failed"
  in
  let open Trading_strategy.Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol = ticker;
              side = Trading_base.Types.Long;
              target_quantity = 10.0;
              entry_price = price;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = 10.0; fill_price = price }))
    |> unwrap
  in
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

(* ------------------------------------------------------------------ *)
(* initial_stop_states: stop hit emits TriggerExit                     *)
(* ------------------------------------------------------------------ *)

let test_stop_hit_emits_trigger_exit _ =
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  (* Seed a stop at 90.0 so a bar with low=85 crosses it *)
  let stop_state =
    Weinstein_stops.Initial { stop_level = 90.0; reference_level = 95.0 }
  in
  let initial_stop_states = String.Map.singleton ticker stop_state in
  let (module S) = make ~initial_stop_states cfg in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  (* Bar with low below stop level — should trigger exit *)
  let bar =
    { (make_bar "2024-01-12" 95.0) with Types.Daily_price.low_price = 85.0 }
  in
  let result =
    S.on_market_close
      ~get_price:
        (get_price_of
           [ (ticker, bar); ("GSPCX", make_bar "2024-01-12" 4500.0) ])
      ~get_indicator:empty_get_indicator
      ~portfolio:{ cash = 100000.0; positions }
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun o -> o.Trading_strategy.Strategy_interface.transitions)
          (elements_are
             [
               (fun tr ->
                 assert_that tr.Trading_strategy.Position.position_id
                   (equal_to ticker);
                 assert_that tr.Trading_strategy.Position.kind
                   (matching
                      (function
                        | Trading_strategy.Position.TriggerExit _ -> Some ()
                        | _ -> None)
                      (equal_to ())));
             ])))

(* ------------------------------------------------------------------ *)
(* stop hit on non-Friday: stops fire daily, not just on Fridays        *)
(* ------------------------------------------------------------------ *)

let test_stop_fires_on_non_friday _ =
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  let stop_state =
    Weinstein_stops.Initial { stop_level = 90.0; reference_level = 95.0 }
  in
  let initial_stop_states = String.Map.singleton ticker stop_state in
  let (module S) = make ~initial_stop_states cfg in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  (* 2024-01-09 is a Tuesday — stops should still fire *)
  let bar =
    { (make_bar "2024-01-09" 95.0) with Types.Daily_price.low_price = 85.0 }
  in
  let result =
    S.on_market_close
      ~get_price:
        (get_price_of
           [ (ticker, bar); ("GSPCX", make_bar "2024-01-09" 4500.0) ])
      ~get_indicator:empty_get_indicator
      ~portfolio:{ cash = 100000.0; positions }
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun o -> o.Trading_strategy.Strategy_interface.transitions)
          (elements_are
             [
               (fun tr ->
                 assert_that tr.Trading_strategy.Position.position_id
                   (equal_to ticker);
                 assert_that tr.Trading_strategy.Position.kind
                   (matching
                      (function
                        | Trading_strategy.Position.TriggerExit _ -> Some ()
                        | _ -> None)
                      (equal_to ())));
             ])))

(* ------------------------------------------------------------------ *)
(* bar accumulation: idempotent — same date twice does not duplicate    *)
(* ------------------------------------------------------------------ *)

let _transition_count result =
  match result with
  | Ok (o : Trading_strategy.Strategy_interface.output) ->
      List.length o.transitions
  | Error _ -> -1

let test_bar_accumulation_idempotent _ =
  (* Two strategies: one called once per date, the other called twice on day 1.
     If accumulation is idempotent, both produce the same result on day 2. *)
  let make_env () =
    let (module S) = make cfg in
    (module S : Trading_strategy.Strategy_interface.STRATEGY)
  in
  let (module S1) = make_env () in
  let (module S2) = make_env () in
  let call (module S : Trading_strategy.Strategy_interface.STRATEGY) d =
    let prices = [ ("AAPL", make_bar d 180.0); ("GSPCX", make_bar d 4500.0) ] in
    S.on_market_close ~get_price:(get_price_of prices)
      ~get_indicator:empty_get_indicator ~portfolio:empty_portfolio
  in
  (* S1: day1, day2. S2: day1, day1 (duplicate), day2. *)
  ignore (call (module S1) "2024-01-08" : _ result);
  ignore (call (module S2) "2024-01-08" : _ result);
  ignore (call (module S2) "2024-01-08" : _ result);
  let r1 = _transition_count (call (module S1) "2024-01-09") in
  let r2 = _transition_count (call (module S2) "2024-01-09") in
  (* Same result on day 2 — the duplicate day 1 call had no effect *)
  assert_that r1 (equal_to r2)

(* ------------------------------------------------------------------ *)
(* bar accumulation: multiple days accumulate distinct bars             *)
(* ------------------------------------------------------------------ *)

let test_bar_accumulation_multiple_days _ =
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  let stop_state =
    Weinstein_stops.Initial { stop_level = 150.0; reference_level = 160.0 }
  in
  let initial_stop_states = String.Map.singleton ticker stop_state in
  let (module S) = make ~initial_stop_states cfg in
  let pos = make_holding_pos ticker 170.0 date in
  let positions = String.Map.singleton ticker pos in
  let portfolio : Trading_strategy.Portfolio_view.t =
    { cash = 100000.0; positions }
  in
  (* Three consecutive days with rising price — stop adjusts each day *)
  let days_and_prices =
    [ ("2024-01-08", 175.0); ("2024-01-09", 180.0); ("2024-01-10", 185.0) ]
  in
  let counts =
    List.map days_and_prices ~f:(fun (d, price) ->
        let prices =
          [ (ticker, make_bar d price); ("GSPCX", make_bar d 4500.0) ]
        in
        let result =
          S.on_market_close ~get_price:(get_price_of prices)
            ~get_indicator:empty_get_indicator ~portfolio
        in
        _transition_count result)
  in
  (* Day 1: Initial stop, no raise yet (0 transitions).
     Day 2: bar history now has 2 days; stop adjusts (1 transition).
     Day 3: stop already adjusted, no further raise at this level (0). *)
  assert_that counts (elements_are [ equal_to 0; equal_to 1; equal_to 0 ])

(* ------------------------------------------------------------------ *)
(* simulation date: transition uses bar date, not Date.today            *)
(* ------------------------------------------------------------------ *)

let test_transition_uses_bar_date _ =
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  let stop_state =
    Weinstein_stops.Initial { stop_level = 90.0; reference_level = 95.0 }
  in
  let initial_stop_states = String.Map.singleton ticker stop_state in
  let (module S) = make ~initial_stop_states cfg in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  (* Bar date is 2024-01-12 — transition should use this, not today *)
  let bar_date = "2024-01-12" in
  let bar =
    { (make_bar bar_date 95.0) with Types.Daily_price.low_price = 85.0 }
  in
  let result =
    S.on_market_close
      ~get_price:
        (get_price_of [ (ticker, bar); ("GSPCX", make_bar bar_date 4500.0) ])
      ~get_indicator:empty_get_indicator
      ~portfolio:{ cash = 100000.0; positions }
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun o -> o.Trading_strategy.Strategy_interface.transitions)
          (elements_are
             [
               (fun tr ->
                 assert_that tr.Trading_strategy.Position.date
                   (equal_to (Date.of_string bar_date)));
             ])))

(* ------------------------------------------------------------------ *)
(* Macro-inputs wiring                                                  *)
(* ------------------------------------------------------------------ *)

(** Record-and-return wrapper: build a [get_price] that records every symbol
    lookup into a ref and returns the baseline bar for known symbols. *)
let recording_get_price ~bars_by_symbol ~recorded symbol =
  recorded := symbol :: !recorded;
  List.Assoc.find bars_by_symbol symbol ~equal:String.equal

let test_strategy_queries_only_primary_index_via_get_price _ =
  (* Stage 3 PR 3.2 invariant: the strategy reads OHLCV bars from
     [Bar_panels] (panel-backed) rather than [get_price]. The only symbol it
     queries via [get_price] on an empty-portfolio call is the primary index
     — used for day-of-week detection and the current_date fallback.

     Universe tickers, sector ETFs, and global indices are NOT queried via
     [get_price] anymore: their bars come from the panels. Compare against
     the pre-3.2 contract where the strategy iterated every configured symbol
     via [Bar_reader.accumulate ~get_price]. *)
  let base = default_config ~universe:[ "AAPL" ] ~index_symbol:"GSPCX" in
  let cfg =
    {
      base with
      sector_etfs = [ ("XLK", "Technology"); ("XLF", "Financials") ];
      indices =
        {
          primary = base.indices.primary;
          global = [ ("GDAXI.INDX", "DAX"); ("N225.INDX", "Nikkei") ];
        };
    }
  in
  let (module S) = make cfg in
  let bars_by_symbol =
    List.map
      [
        ("AAPL", 180.0);
        ("GSPCX", 4500.0);
        ("XLK", 200.0);
        ("XLF", 40.0);
        ("GDAXI.INDX", 16000.0);
        ("N225.INDX", 33000.0);
      ]
      ~f:(fun (sym, p) -> (sym, make_bar "2024-01-05" p))
  in
  let recorded = ref [] in
  let _ =
    S.on_market_close
      ~get_price:(recording_get_price ~bars_by_symbol ~recorded)
      ~get_indicator:empty_get_indicator ~portfolio:empty_portfolio
  in
  let unique_calls = List.dedup_and_sort !recorded ~compare:String.compare in
  assert_that unique_calls (equal_to [ "GSPCX" ])

let test_strategy_with_default_config_queries_only_primary_index _ =
  (* Default config (no sector ETFs, no globals): same invariant — the
     strategy only queries [get_price] for the primary index. *)
  let (module S) = make cfg in
  let bars_by_symbol =
    [
      ("AAPL", make_bar "2024-01-05" 180.0);
      ("GSPCX", make_bar "2024-01-05" 4500.0);
    ]
  in
  let recorded = ref [] in
  let _ =
    S.on_market_close
      ~get_price:(recording_get_price ~bars_by_symbol ~recorded)
      ~get_indicator:empty_get_indicator ~portfolio:empty_portfolio
  in
  let unique_calls = List.dedup_and_sort !recorded ~compare:String.compare in
  assert_that unique_calls (equal_to [ "GSPCX" ])

(* Decision-making tests that depend on the screener producing trades under
   Normal conditions (and NOT producing trades under bearish conditions) live
   in [test_weinstein_strategy_smoke.ml]. Direct [on_market_close] calls in
   this file cannot reliably produce entries — the Simulator path is the only
   reliable harness for comparing two macro-input scenarios. *)

(* ------------------------------------------------------------------ *)
(* held_symbols: excludes Closed positions                             *)
(* ------------------------------------------------------------------ *)

(** Build a {!Trading_strategy.Position.t} directly at a given lifecycle state.
    Bypasses the transition machinery — we are unit-testing a helper that
    switches on [state], not the state machine itself. *)
let make_pos_at_state ~symbol
    ~(state : Trading_strategy.Position.position_state) :
    Trading_strategy.Position.t =
  {
    id = symbol;
    symbol;
    side = Trading_base.Types.Long;
    entry_reasoning = ManualDecision { description = "test" };
    exit_reason = None;
    state;
    last_updated = Date.of_string "2024-01-05";
    portfolio_lot_ids = [];
  }

let _sample_entering =
  Trading_strategy.Position.Entering
    {
      target_quantity = 10.0;
      entry_price = 100.0;
      filled_quantity = 0.0;
      created_date = Date.of_string "2024-01-05";
    }

let _sample_holding =
  Trading_strategy.Position.Holding
    {
      quantity = 10.0;
      entry_price = 100.0;
      entry_date = Date.of_string "2024-01-05";
      risk_params =
        {
          stop_loss_price = None;
          take_profit_price = None;
          max_hold_days = None;
        };
    }

let _sample_exiting =
  Trading_strategy.Position.Exiting
    {
      quantity = 10.0;
      entry_price = 100.0;
      entry_date = Date.of_string "2024-01-05";
      target_quantity = 10.0;
      exit_price = 110.0;
      filled_quantity = 0.0;
      started_date = Date.of_string "2024-01-10";
    }

let _sample_closed =
  Trading_strategy.Position.Closed
    {
      quantity = 10.0;
      entry_price = 100.0;
      exit_price = 110.0;
      gross_pnl = None;
      entry_date = Date.of_string "2024-01-05";
      exit_date = Date.of_string "2024-01-10";
      days_held = 5;
    }

let _portfolio_of_positions positions : Trading_strategy.Portfolio_view.t =
  let tbl =
    List.fold positions ~init:String.Map.empty ~f:(fun acc p ->
        Map.set acc ~key:p.Trading_strategy.Position.symbol ~data:p)
  in
  { cash = 100000.0; positions = tbl }

let test_held_symbols_excludes_closed _ =
  (* Mixed-state portfolio: Entering, Holding, Exiting are kept; Closed is
     dropped. This is the core bug fix — before, Closed was retained, which
     permanently blacklisted every symbol the strategy had ever traded. *)
  let portfolio =
    _portfolio_of_positions
      [
        make_pos_at_state ~symbol:"AAPL" ~state:_sample_entering;
        make_pos_at_state ~symbol:"MSFT" ~state:_sample_holding;
        make_pos_at_state ~symbol:"GOOG" ~state:_sample_exiting;
        make_pos_at_state ~symbol:"ZZZZ" ~state:_sample_closed;
      ]
  in
  let held = held_symbols portfolio in
  assert_that
    (List.sort held ~compare:String.compare)
    (equal_to [ "AAPL"; "GOOG"; "MSFT" ])

let test_held_symbols_empty_when_all_closed _ =
  (* Regression guard: a portfolio with only Closed positions (e.g. end of a
     long backtest where every entry has long since exited) must return no
     held symbols — otherwise the strategy starves new entries. *)
  let portfolio =
    _portfolio_of_positions
      [
        make_pos_at_state ~symbol:"AAPL" ~state:_sample_closed;
        make_pos_at_state ~symbol:"MSFT" ~state:_sample_closed;
        make_pos_at_state ~symbol:"GOOG" ~state:_sample_closed;
      ]
  in
  assert_that (held_symbols portfolio) is_empty

(* ------------------------------------------------------------------ *)
(* entries_from_candidates: short-side entry                           *)
(* ------------------------------------------------------------------ *)

(** Minimal [Stock_analysis.t] fixture — only fields the entry pipeline reads.
    The screener cascade itself is tested separately; here we inject a
    [Screener.scored_candidate] directly into [entries_from_candidates] to
    verify the downstream behaviour for shorts. *)
let make_scored_candidate ~ticker ~side ~entry ~stop ~grade =
  let open Weinstein_types in
  let stub_stage : Stage.result =
    {
      stage = Stage4 { weeks_declining = 2 };
      ma_value = entry *. 1.2;
      ma_direction = Declining;
      ma_slope_pct = -0.02;
      transition =
        Some (Stage3 { weeks_topping = 8 }, Stage4 { weeks_declining = 2 });
      above_ma_count = 0;
    }
  in
  let stub_analysis : Stock_analysis.t =
    {
      ticker;
      stage = stub_stage;
      rs = None;
      volume = None;
      breakout_price = Some entry;
      breakdown_price = None;
      resistance = None;
      support = None;
      prior_stage = Some (Stage3 { weeks_topping = 8 });
      as_of_date = Date.of_string "2024-01-05";
    }
  in
  let stub_sector : Screener.sector_context =
    { sector_name = "Energy"; rating = Weak; stage = stub_analysis.stage.stage }
  in
  {
    Screener.ticker;
    analysis = stub_analysis;
    sector = stub_sector;
    side;
    grade;
    score = 30;
    suggested_entry = entry;
    suggested_stop = stop;
    risk_pct = Float.abs ((entry -. stop) /. entry);
    swing_target = None;
    rationale = [ "test" ];
  }

(** End-to-end slice from [Screener.scored_candidate] with [side = Short] to a
    [CreateEntering] transition. Proves the entry pipeline now produces shorts —
    prior to the short-side wiring this path was effectively unreachable because
    [_make_entry_transition] hardcoded [Long]. *)
let test_entries_from_candidates_emits_short _ =
  let cfg = default_config ~universe:[ "XYZ" ] ~index_symbol:"GSPCX" in
  let stop_states = ref String.Map.empty in
  let bar_reader = Bar_reader.empty () in
  (* Short: entry 80, stop 88 (above entry). *)
  let cand =
    make_scored_candidate ~ticker:"XYZ" ~side:Trading_base.Types.Short
      ~entry:80.0 ~stop:88.0 ~grade:Weinstein_types.C
  in
  let portfolio : Trading_strategy.Portfolio_view.t =
    { cash = 100_000.0; positions = String.Map.empty }
  in
  let get_price = get_price_of [ ("XYZ", make_bar "2024-01-05" 80.0) ] in
  let transitions =
    entries_from_candidates ~config:cfg ~candidates:[ cand ] ~stop_states
      ~bar_reader ~portfolio ~get_price
      ~current_date:(Date.of_string "2024-01-05")
  in
  assert_that transitions
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_strategy.Position.transition) -> t.position_id)
               (matching
                  (fun id ->
                    if String.is_prefix id ~prefix:"XYZ-wein-" then Some ()
                    else None)
                  (equal_to ()));
             field
               (fun (t : Trading_strategy.Position.transition) -> t.kind)
               (matching
                  (function
                    | Trading_strategy.Position.CreateEntering { side; _ } ->
                        Some side
                    | _ -> None)
                  (equal_to Trading_base.Types.Short));
           ];
       ])

(** Long-side parity: same pipeline with [side = Long] produces a Long
    transition. Regression guard against accidentally crossing sides when
    threading [cand.side]. *)
let test_entries_from_candidates_emits_long _ =
  let cfg = default_config ~universe:[ "XYZ" ] ~index_symbol:"GSPCX" in
  let stop_states = ref String.Map.empty in
  let bar_reader = Bar_reader.empty () in
  (* Long: entry 100, stop 92 (below entry). *)
  let cand =
    make_scored_candidate ~ticker:"XYZ" ~side:Trading_base.Types.Long
      ~entry:100.0 ~stop:92.0 ~grade:Weinstein_types.C
  in
  let portfolio : Trading_strategy.Portfolio_view.t =
    { cash = 100_000.0; positions = String.Map.empty }
  in
  let get_price = get_price_of [ ("XYZ", make_bar "2024-01-05" 100.0) ] in
  let transitions =
    entries_from_candidates ~config:cfg ~candidates:[ cand ] ~stop_states
      ~bar_reader ~portfolio ~get_price
      ~current_date:(Date.of_string "2024-01-05")
  in
  assert_that transitions
    (elements_are
       [
         field
           (fun (t : Trading_strategy.Position.transition) -> t.kind)
           (matching
              (function
                | Trading_strategy.Position.CreateEntering { side; _ } ->
                    Some side
                | _ -> None)
              (equal_to Trading_base.Types.Long));
       ])

(* ------------------------------------------------------------------ *)
(* Stage 4-5 PR-A: lazy stage filter — survivors_for_screening         *)
(* ------------------------------------------------------------------ *)

(** Build a Friday-anchored series of weekly bars. *)
let _make_friday_bars ~start_friday ~n ~start_price ~step =
  List.init n ~f:(fun i ->
      let date = Date.add_days start_friday (i * 7) in
      let price = start_price +. (Float.of_int i *. step) in
      {
        Types.Daily_price.date;
        open_price = price;
        high_price = price *. 1.01;
        low_price = price *. 0.99;
        close_price = price;
        adjusted_close = price;
        volume = 1_000_000;
      })

(** Pack [(symbol, bars)] pairs into a {!Bar_panels.t}. The calendar is the
    union of all dates (sorted, deduped). Mirrors the helper in
    {!test_panel_callbacks.ml}. *)
let _panels_of_symbols
    (symbols_with_bars : (string * Types.Daily_price.t list) list) =
  let universe = List.map symbols_with_bars ~f:fst in
  let symbol_index =
    match Data_panel.Symbol_index.create ~universe with
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
    Data_panel.Ohlcv_panels.create symbol_index ~n_days:(Array.length calendar)
  in
  let date_to_col = Hashtbl.create (module Date) in
  Array.iteri calendar ~f:(fun i d ->
      Hashtbl.add date_to_col ~key:d ~data:i
      |> (ignore : [ `Ok | `Duplicate ] -> unit));
  List.iter symbols_with_bars ~f:(fun (symbol, bars) ->
      match Data_panel.Symbol_index.to_row symbol_index symbol with
      | None -> ()
      | Some row ->
          List.iter bars ~f:(fun bar ->
              match Hashtbl.find date_to_col bar.Types.Daily_price.date with
              | None -> ()
              | Some day ->
                  Data_panel.Ohlcv_panels.write_row ohlcv ~symbol_index:row ~day
                    bar));
  match Data_panel.Bar_panels.create ~ohlcv ~calendar with
  | Ok p -> p
  | Error err -> failwith ("Bar_panels.create: " ^ err.Status.message)

(** Build a 60-week Friday-anchored series with the given start_price + step.
    Positive [step] yields a Stage2-classifying series (rising MA, price above
    MA); negative [step] yields a Stage4 series. *)
let _trending_series ~start_friday ~start_price ~step =
  _make_friday_bars ~start_friday ~n:60 ~start_price ~step

let test_survivors_for_screening_filters_by_stage _ =
  (* Universe of four symbols: two rising (Stage2-survivors), two declining
     (Stage4-survivors). The filter currently drops only Stage1 / Stage3, so
     all four trend-in-one-direction symbols must survive. *)
  let start_friday = Date.of_string "2024-01-05" in
  let rising_a = _trending_series ~start_friday ~start_price:50.0 ~step:0.8 in
  let rising_b = _trending_series ~start_friday ~start_price:60.0 ~step:1.0 in
  let declining_a =
    _trending_series ~start_friday ~start_price:200.0 ~step:(-1.5)
  in
  let declining_b =
    _trending_series ~start_friday ~start_price:180.0 ~step:(-1.0)
  in
  let panels =
    _panels_of_symbols
      [
        ("RISE_A", rising_a);
        ("RISE_B", rising_b);
        ("FALL_A", declining_a);
        ("FALL_B", declining_b);
      ]
  in
  let bar_reader = Bar_reader.of_panels panels in
  let cfg =
    default_config
      ~universe:[ "RISE_A"; "RISE_B"; "FALL_A"; "FALL_B" ]
      ~index_symbol:"GSPCX"
  in
  let prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  (* Use the panel's last date as the screening day — guaranteed to land in
     the calendar so [weekly_view_for] returns a non-empty view. *)
  let last_date =
    let n = Data_panel.Bar_panels.n_days panels in
    let cal_view =
      Data_panel.Bar_panels.weekly_view_for panels ~symbol:"RISE_A" ~n:1
        ~as_of_day:(n - 1)
    in
    cal_view.dates.(cal_view.n - 1)
  in
  let survivors =
    survivors_for_screening ~config:cfg ~bar_reader ~prior_stages
      ~current_date:last_date ()
  in
  let survivor_tickers =
    List.map survivors ~f:(fun (ticker, _, _) -> ticker)
    |> List.sort ~compare:String.compare
  in
  (* All four trending series classify into Stage2 / Stage4 — none drop. *)
  assert_that survivor_tickers
    (equal_to [ "FALL_A"; "FALL_B"; "RISE_A"; "RISE_B" ])

let test_survivors_for_screening_drops_stage1_and_stage3 _ =
  (* Build symbols whose stage classification falls into Stage1 / Stage3.
     [Stage1] = decline-then-flat (basing); [Stage3] = rise-then-flat
     (topping). The filter must drop them. *)
  let start_friday = Date.of_string "2024-01-05" in
  let make_dates ~n =
    List.init n ~f:(fun i -> Date.add_days start_friday (i * 7))
  in
  let bars_of_prices prices =
    List.map2_exn
      (make_dates ~n:(List.length prices))
      prices
      ~f:(fun date p ->
        {
          Types.Daily_price.date;
          open_price = p;
          high_price = p *. 1.01;
          low_price = p *. 0.99;
          close_price = p;
          adjusted_close = p;
          volume = 1_000_000;
        })
  in
  (* Stage1: 15 weeks declining 100 → 86, then 50 weeks flat at 85. *)
  let stage1_bars =
    let declining = List.init 15 ~f:(fun i -> 100.0 -. Float.of_int i) in
    let flat = List.init 50 ~f:(fun _ -> 85.0) in
    bars_of_prices (declining @ flat)
  in
  (* Stage3: 15 weeks rising 50 → 64, then 50 weeks flat at 65. *)
  let stage3_bars =
    let rising = List.init 15 ~f:(fun i -> 50.0 +. Float.of_int i) in
    let flat = List.init 50 ~f:(fun _ -> 65.0) in
    bars_of_prices (rising @ flat)
  in
  (* One Stage4 control to confirm filter survives at least one symbol. *)
  let stage4_bars =
    _trending_series ~start_friday ~start_price:200.0 ~step:(-1.5)
  in
  let panels =
    _panels_of_symbols
      [ ("BASE", stage1_bars); ("TOP", stage3_bars); ("DECLINE", stage4_bars) ]
  in
  let bar_reader = Bar_reader.of_panels panels in
  let cfg =
    default_config ~universe:[ "BASE"; "TOP"; "DECLINE" ] ~index_symbol:"GSPCX"
  in
  (* Seed prior stages so the classifier disambiguates Stage1 (prior Stage4)
     from Stage3 (prior Stage2). *)
  let prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.of_alist_exn
      (module String)
      [
        ("BASE", Weinstein_types.Stage4 { weeks_declining = 10 });
        ("TOP", Weinstein_types.Stage2 { weeks_advancing = 10; late = false });
      ]
  in
  let last_date =
    let n = Data_panel.Bar_panels.n_days panels in
    let cal_view =
      Data_panel.Bar_panels.weekly_view_for panels ~symbol:"DECLINE" ~n:1
        ~as_of_day:(n - 1)
    in
    cal_view.dates.(cal_view.n - 1)
  in
  let survivors =
    survivors_for_screening ~config:cfg ~bar_reader ~prior_stages
      ~current_date:last_date ()
  in
  let survivor_tickers = List.map survivors ~f:(fun (ticker, _, _) -> ticker) in
  (* Only DECLINE (Stage4) passes; BASE (Stage1) and TOP (Stage3) drop. *)
  assert_that survivor_tickers (equal_to [ "DECLINE" ])

(** Stage 4-5 PR-A counter test: in a Stage-4-heavy universe, the number of full
    {!Stock_analysis} analyses (Phase 2) must equal the survivor count, NOT the
    loaded universe size. We exercise this via [survivors_for_screening] — Phase
    2 in [_screen_universe] is a [List.map] over [survivors], so the survivor
    list length is mathematically equivalent to the Phase 2 call count.

    Pre-PR-A: every loaded symbol paid the full callback bundle + analyze cost.
    Post-PR-A: only survivors do. The win is proportional to (loaded -
    survivors). *)
let test_phase2_call_count_equals_survivor_count _ =
  (* Six-symbol universe: two Stage4 (survive), two Stage1 (drop), two Stage3
     (drop). Post-PR-A only the two Stage4 symbols pay the full
     [Stock_analysis] cost; pre-PR-A all six did. *)
  let start_friday = Date.of_string "2024-01-05" in
  let make_dates ~n =
    List.init n ~f:(fun i -> Date.add_days start_friday (i * 7))
  in
  let bars_of_prices prices =
    List.map2_exn
      (make_dates ~n:(List.length prices))
      prices
      ~f:(fun date p ->
        {
          Types.Daily_price.date;
          open_price = p;
          high_price = p *. 1.01;
          low_price = p *. 0.99;
          close_price = p;
          adjusted_close = p;
          volume = 1_000_000;
        })
  in
  let stage1_bars _seed =
    let declining = List.init 15 ~f:(fun i -> 100.0 -. Float.of_int i) in
    let flat = List.init 50 ~f:(fun _ -> 85.0) in
    bars_of_prices (declining @ flat)
  in
  let stage3_bars _seed =
    let rising = List.init 15 ~f:(fun i -> 50.0 +. Float.of_int i) in
    let flat = List.init 50 ~f:(fun _ -> 65.0) in
    bars_of_prices (rising @ flat)
  in
  let stage4_bars seed =
    _trending_series ~start_friday ~start_price:(200.0 +. seed) ~step:(-1.5)
  in
  let panels =
    _panels_of_symbols
      [
        ("BASE_A", stage1_bars 0.0);
        ("BASE_B", stage1_bars 1.0);
        ("TOP_A", stage3_bars 0.0);
        ("TOP_B", stage3_bars 1.0);
        ("DECLINE_A", stage4_bars 0.0);
        ("DECLINE_B", stage4_bars 5.0);
      ]
  in
  let bar_reader = Bar_reader.of_panels panels in
  let cfg =
    default_config
      ~universe:
        [ "BASE_A"; "BASE_B"; "TOP_A"; "TOP_B"; "DECLINE_A"; "DECLINE_B" ]
      ~index_symbol:"GSPCX"
  in
  let prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.of_alist_exn
      (module String)
      [
        ("BASE_A", Weinstein_types.Stage4 { weeks_declining = 10 });
        ("BASE_B", Weinstein_types.Stage4 { weeks_declining = 10 });
        ("TOP_A", Weinstein_types.Stage2 { weeks_advancing = 10; late = false });
        ("TOP_B", Weinstein_types.Stage2 { weeks_advancing = 10; late = false });
      ]
  in
  let last_date =
    let n = Data_panel.Bar_panels.n_days panels in
    let cal_view =
      Data_panel.Bar_panels.weekly_view_for panels ~symbol:"DECLINE_A" ~n:1
        ~as_of_day:(n - 1)
    in
    cal_view.dates.(cal_view.n - 1)
  in
  let loaded_count = List.length cfg.universe in
  let survivors =
    survivors_for_screening ~config:cfg ~bar_reader ~prior_stages
      ~current_date:last_date ()
  in
  let survivor_count = List.length survivors in
  assert_that (loaded_count, survivor_count) (equal_to ((6, 2) : int * int))

(* ------------------------------------------------------------------ *)
(* Stage 4-5 PR-B: sector pre-filter — survivors_for_screening          *)
(* ------------------------------------------------------------------ *)

(** Build a sector_map entry with the given rating for [ticker] under
    [sector_name]. *)
let _make_sector_entry ~ticker:_ ~sector_name ~rating =
  ( sector_name,
    {
      Screener.sector_name;
      rating;
      stage = Weinstein_types.Stage1 { weeks_in_base = 0 };
    } )

(** Build a [sector_map : (string, sector_context) Hashtbl.t] from a list of
    [(ticker, rating)] pairs. Each ticker gets its own one-off sector. *)
let _sector_map_of_pairs (pairs : (string * Screener.sector_rating) list) =
  let map = Hashtbl.create (module String) in
  List.iter pairs ~f:(fun (ticker, rating) ->
      let _name, ctx =
        _make_sector_entry ~ticker ~sector_name:(ticker ^ "_sector") ~rating
      in
      Hashtbl.set map ~key:ticker ~data:ctx);
  map

let test_survivors_for_screening_sector_filter_drops_weak_long _ =
  (* Universe: two Stage2 symbols. RISE_STRONG sits in a Strong sector
     (passes). RISE_WEAK sits in a Weak sector (drops — screener's
     [_long_candidate] would reject it on the same rating). *)
  let start_friday = Date.of_string "2024-01-05" in
  let rising_strong =
    _trending_series ~start_friday ~start_price:50.0 ~step:0.8
  in
  let rising_weak =
    _trending_series ~start_friday ~start_price:60.0 ~step:1.0
  in
  let panels =
    _panels_of_symbols
      [ ("RISE_STRONG", rising_strong); ("RISE_WEAK", rising_weak) ]
  in
  let bar_reader = Bar_reader.of_panels panels in
  let cfg =
    default_config
      ~universe:[ "RISE_STRONG"; "RISE_WEAK" ]
      ~index_symbol:"GSPCX"
  in
  let prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let last_date =
    let n = Data_panel.Bar_panels.n_days panels in
    let cal_view =
      Data_panel.Bar_panels.weekly_view_for panels ~symbol:"RISE_STRONG" ~n:1
        ~as_of_day:(n - 1)
    in
    cal_view.dates.(cal_view.n - 1)
  in
  let sector_map =
    _sector_map_of_pairs
      [ ("RISE_STRONG", Screener.Strong); ("RISE_WEAK", Screener.Weak) ]
  in
  let survivors =
    survivors_for_screening ~sector_map ~config:cfg ~bar_reader ~prior_stages
      ~current_date:last_date ()
  in
  let survivor_tickers = List.map survivors ~f:(fun (ticker, _, _) -> ticker) in
  assert_that survivor_tickers (equal_to [ "RISE_STRONG" ])

let test_survivors_for_screening_sector_filter_drops_strong_short _ =
  (* Universe: two Stage4 symbols. FALL_WEAK sits in a Weak sector
     (passes — screener's [_short_candidate] accepts Weak/Neutral).
     FALL_STRONG sits in a Strong sector (drops — screener's
     [_short_candidate] rejects on Strong rating). *)
  let start_friday = Date.of_string "2024-01-05" in
  let declining_weak =
    _trending_series ~start_friday ~start_price:200.0 ~step:(-1.5)
  in
  let declining_strong =
    _trending_series ~start_friday ~start_price:180.0 ~step:(-1.0)
  in
  let panels =
    _panels_of_symbols
      [ ("FALL_WEAK", declining_weak); ("FALL_STRONG", declining_strong) ]
  in
  let bar_reader = Bar_reader.of_panels panels in
  let cfg =
    default_config
      ~universe:[ "FALL_WEAK"; "FALL_STRONG" ]
      ~index_symbol:"GSPCX"
  in
  let prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let last_date =
    let n = Data_panel.Bar_panels.n_days panels in
    let cal_view =
      Data_panel.Bar_panels.weekly_view_for panels ~symbol:"FALL_WEAK" ~n:1
        ~as_of_day:(n - 1)
    in
    cal_view.dates.(cal_view.n - 1)
  in
  let sector_map =
    _sector_map_of_pairs
      [ ("FALL_WEAK", Screener.Weak); ("FALL_STRONG", Screener.Strong) ]
  in
  let survivors =
    survivors_for_screening ~sector_map ~config:cfg ~bar_reader ~prior_stages
      ~current_date:last_date ()
  in
  let survivor_tickers = List.map survivors ~f:(fun (ticker, _, _) -> ticker) in
  assert_that survivor_tickers (equal_to [ "FALL_WEAK" ])

let test_survivors_for_screening_sector_filter_unknown_ticker_passes _ =
  (* Tickers absent from the sector_map default to PASS — matches
     [Screener._resolve_sector]'s [Neutral] fallback. *)
  let start_friday = Date.of_string "2024-01-05" in
  let rising = _trending_series ~start_friday ~start_price:50.0 ~step:0.8 in
  let panels = _panels_of_symbols [ ("UNKNOWN", rising) ] in
  let bar_reader = Bar_reader.of_panels panels in
  let cfg = default_config ~universe:[ "UNKNOWN" ] ~index_symbol:"GSPCX" in
  let prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let last_date =
    let n = Data_panel.Bar_panels.n_days panels in
    let cal_view =
      Data_panel.Bar_panels.weekly_view_for panels ~symbol:"UNKNOWN" ~n:1
        ~as_of_day:(n - 1)
    in
    cal_view.dates.(cal_view.n - 1)
  in
  (* Empty sector_map: every ticker is "unknown" → all PASS. *)
  let sector_map = Hashtbl.create (module String) in
  let survivors =
    survivors_for_screening ~sector_map ~config:cfg ~bar_reader ~prior_stages
      ~current_date:last_date ()
  in
  let survivor_tickers = List.map survivors ~f:(fun (ticker, _, _) -> ticker) in
  assert_that survivor_tickers (equal_to [ "UNKNOWN" ])

(** PR-B counter test: assert the (loaded, stage_pass, sector_pass) triple
    monotonically narrows. The test runs [survivors_for_screening] twice on the
    same fixture — once without [sector_map] (yields [stage_pass]) and once with
    (yields [sector_pass]) — so we can read both counts directly without
    instrumenting the screener loop. *)
let test_survivors_for_screening_pr_b_counter _ =
  (* Six-symbol universe: two Stage2-strong, two Stage2-weak, two Stage4-mixed
     (one Strong-sector → drop, one Weak-sector → pass). Stage4 in Strong
     sector: drops; Stage4 in Weak sector: passes. *)
  let start_friday = Date.of_string "2024-01-05" in
  let rising seed =
    _trending_series ~start_friday ~start_price:(50.0 +. seed) ~step:0.8
  in
  let declining seed =
    _trending_series ~start_friday ~start_price:(200.0 +. seed) ~step:(-1.5)
  in
  let panels =
    _panels_of_symbols
      [
        ("RISE_STRONG_A", rising 0.0);
        ("RISE_STRONG_B", rising 1.0);
        ("RISE_WEAK_A", rising 2.0);
        ("RISE_WEAK_B", rising 3.0);
        ("FALL_STRONG", declining 0.0);
        ("FALL_WEAK", declining 1.0);
      ]
  in
  let bar_reader = Bar_reader.of_panels panels in
  let cfg =
    default_config
      ~universe:
        [
          "RISE_STRONG_A";
          "RISE_STRONG_B";
          "RISE_WEAK_A";
          "RISE_WEAK_B";
          "FALL_STRONG";
          "FALL_WEAK";
        ]
      ~index_symbol:"GSPCX"
  in
  let last_date =
    let n = Data_panel.Bar_panels.n_days panels in
    let cal_view =
      Data_panel.Bar_panels.weekly_view_for panels ~symbol:"RISE_STRONG_A" ~n:1
        ~as_of_day:(n - 1)
    in
    cal_view.dates.(cal_view.n - 1)
  in
  let sector_map =
    _sector_map_of_pairs
      [
        ("RISE_STRONG_A", Screener.Strong);
        ("RISE_STRONG_B", Screener.Strong);
        ("RISE_WEAK_A", Screener.Weak);
        ("RISE_WEAK_B", Screener.Weak);
        ("FALL_STRONG", Screener.Strong);
        ("FALL_WEAK", Screener.Weak);
      ]
  in
  let loaded = List.length cfg.universe in
  (* First pass: no sector_map → stage-only filter. Use a fresh prior_stages
     each time so the two calls don't interact. *)
  let stage_pass =
    let prior_stages = Hashtbl.create (module String) in
    survivors_for_screening ~config:cfg ~bar_reader ~prior_stages
      ~current_date:last_date ()
    |> List.length
  in
  let sector_pass_survivors =
    let prior_stages = Hashtbl.create (module String) in
    survivors_for_screening ~sector_map ~config:cfg ~bar_reader ~prior_stages
      ~current_date:last_date ()
  in
  let sector_pass = List.length sector_pass_survivors in
  let surviving_tickers =
    List.map sector_pass_survivors ~f:(fun (ticker, _, _) -> ticker)
    |> List.sort ~compare:String.compare
  in
  assert_that
    (loaded, stage_pass, sector_pass)
    (equal_to ((6, 6, 3) : int * int * int));
  assert_that surviving_tickers
    (equal_to [ "FALL_WEAK"; "RISE_STRONG_A"; "RISE_STRONG_B" ])

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("weinstein_strategy"
    >::: [
           "make produces strategy" >:: test_make_produces_strategy;
           "empty universe no transitions"
           >:: test_empty_universe_no_transitions;
           "no price data no transitions" >:: test_no_price_data_no_transitions;
           "multiple calls consistent" >:: test_multiple_calls_consistent;
           "stop hit emits trigger exit" >:: test_stop_hit_emits_trigger_exit;
           "stop fires on non-Friday" >:: test_stop_fires_on_non_friday;
           "bar accumulation idempotent" >:: test_bar_accumulation_idempotent;
           "bar accumulation multiple days"
           >:: test_bar_accumulation_multiple_days;
           "transition uses bar date" >:: test_transition_uses_bar_date;
           "strategy queries only primary index via get_price"
           >:: test_strategy_queries_only_primary_index_via_get_price;
           "strategy with default config queries only primary index"
           >:: test_strategy_with_default_config_queries_only_primary_index;
           "held_symbols excludes Closed positions"
           >:: test_held_symbols_excludes_closed;
           "held_symbols empty when all positions Closed"
           >:: test_held_symbols_empty_when_all_closed;
           "entries_from_candidates emits Short transition for Short candidate"
           >:: test_entries_from_candidates_emits_short;
           "entries_from_candidates emits Long transition for Long candidate"
           >:: test_entries_from_candidates_emits_long;
           "survivors_for_screening filters by stage"
           >:: test_survivors_for_screening_filters_by_stage;
           "survivors_for_screening drops Stage1 and Stage3"
           >:: test_survivors_for_screening_drops_stage1_and_stage3;
           "phase 2 call count equals survivor count, not loaded count"
           >:: test_phase2_call_count_equals_survivor_count;
           "PR-B sector filter drops Weak-sector longs"
           >:: test_survivors_for_screening_sector_filter_drops_weak_long;
           "PR-B sector filter drops Strong-sector shorts"
           >:: test_survivors_for_screening_sector_filter_drops_strong_short;
           "PR-B sector filter: ticker absent from sector_map passes"
           >:: test_survivors_for_screening_sector_filter_unknown_ticker_passes;
           "PR-B counter test: (loaded, stage_pass, sector_pass) narrows"
           >:: test_survivors_for_screening_pr_b_counter;
         ])
