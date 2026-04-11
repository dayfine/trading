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

let test_strategy_accumulates_configured_symbols _ =
  (* One test for the wiring: sector ETFs and global indices configured in
     the config are queried via get_price on every on_market_close call.
     Regression guard against silent drop-on-the-floor for extra symbols. *)
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
  assert_that unique_calls
    (equal_to [ "AAPL"; "GDAXI.INDX"; "GSPCX"; "N225.INDX"; "XLF"; "XLK" ])

let test_strategy_empty_macro_config_queries_only_universe _ =
  (* Regression guard: default config queries only universe + indices.primary,
     nothing else. If a future change accidentally accumulates for unrelated
     symbols, this test fails. *)
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
  assert_that unique_calls (equal_to [ "AAPL"; "GSPCX" ])

(* Decision-making tests that depend on the screener producing trades under
   Normal conditions (and NOT producing trades under bearish conditions) live
   in [test_weinstein_strategy_smoke.ml]. Direct [on_market_close] calls in
   this file cannot reliably produce entries — the Simulator path is the only
   reliable harness for comparing two macro-input scenarios. *)

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
           "strategy accumulates configured sector ETF and global index bars"
           >:: test_strategy_accumulates_configured_symbols;
           "strategy with empty macro config queries only universe + index"
           >:: test_strategy_empty_macro_config_queries_only_universe;
         ])
