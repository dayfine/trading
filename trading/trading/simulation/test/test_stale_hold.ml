(** Pins {!Trading_simulation.Stale_hold}'s detector + log + sexp roundtrip
    contracts.

    Specifically guards against re-regression of the equity-curve truncation bug
    fixed in this PR — when a held position's underlying symbol stops emitting
    bars (a corporate action the strategy did not anticipate, e.g. the ANDV→MPC
    merger of 2018-10-01), the simulator must not silently pretend the symbol is
    still trading. The detector emits one event per (held position, step) pair
    while the position remains stale; the log aggregates them across the run. *)

open Core
open OUnit2
open Matchers
module Stale_hold = Trading_simulation.Stale_hold

let _date = Date.of_string

(** Build an in-memory [Market_data_adapter.t] backed by a fixed
    [(symbol, date) -> price] table. [get_previous_bar] returns the most recent
    bar strictly before [date] for the symbol. *)
let _adapter_of_table ~(table : (string * Date.t * float) list) =
  let by_symbol = Hashtbl.create (module String) in
  List.iter table ~f:(fun (sym, d, p) ->
      let xs = Hashtbl.find by_symbol sym |> Option.value ~default:[] in
      Hashtbl.set by_symbol ~key:sym ~data:((d, p) :: xs));
  Hashtbl.map_inplace by_symbol ~f:(fun bars ->
      List.sort bars ~compare:(fun (a, _) (b, _) -> Date.compare a b));
  let bar_of date price : Types.Daily_price.t =
    {
      date;
      open_price = price;
      high_price = price;
      low_price = price;
      close_price = price;
      adjusted_close = price;
      volume = 1_000;
      active_through = None;
    }
  in
  let get_price ~symbol ~date =
    match Hashtbl.find by_symbol symbol with
    | None -> None
    | Some bars ->
        List.find bars ~f:(fun (d, _) -> Date.equal d date)
        |> Option.map ~f:(fun (d, p) -> bar_of d p)
  in
  let get_previous_bar ~symbol ~date =
    match Hashtbl.find by_symbol symbol with
    | None -> None
    | Some bars ->
        List.filter bars ~f:(fun (d, _) -> Date.( < ) d date)
        |> List.last
        |> Option.map ~f:(fun (d, p) -> bar_of d p)
  in
  Trading_simulation_data.Market_data_adapter.create_with_callbacks ~get_price
    ~get_previous_bar

let _portfolio_with_position ~symbol ~quantity ~entry_price ~entry_date :
    Trading_portfolio.Portfolio.t =
  let initial = Trading_portfolio.Portfolio.create ~initial_cash:100_000.0 () in
  let trade : Trading_base.Types.trade =
    {
      id = symbol ^ "-trade-1";
      order_id = symbol ^ "-order-1";
      symbol;
      side = Trading_base.Types.Buy;
      quantity;
      price = entry_price;
      commission = 0.0;
      timestamp =
        Time_ns_unix.of_date_ofday ~zone:Time_float.Zone.utc entry_date
          Time_ns_unix.Ofday.start_of_day;
    }
  in
  match Trading_portfolio.Portfolio.apply_single_trade initial trade with
  | Ok p -> p
  | Error err -> assert_failure ("apply_single_trade failed: " ^ Status.show err)

let _today_bar ~symbol ~price : Trading_engine.Types.price_bar =
  {
    symbol;
    open_price = price;
    high_price = price;
    low_price = price;
    close_price = price;
  }

(* -------------------------------------------------------------------- *)
(* Detector — single position scenarios                                  *)
(* -------------------------------------------------------------------- *)

let test_detect_no_held_positions _ =
  let portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:100_000.0 ()
  in
  let adapter = _adapter_of_table ~table:[] in
  let events =
    Stale_hold.detect_stale ~adapter ~date:(_date "2024-01-15") ~portfolio
      ~today_bars:[] ~config:Stale_hold.default_config
  in
  assert_that events (size_is 0)

let test_detect_held_position_with_today_bar_is_not_stale _ =
  let portfolio =
    _portfolio_with_position ~symbol:"AAPL" ~quantity:10.0 ~entry_price:100.0
      ~entry_date:(_date "2024-01-02")
  in
  let adapter =
    _adapter_of_table
      ~table:
        [
          ("AAPL", _date "2024-01-15", 110.0);
          ("AAPL", _date "2024-01-02", 100.0);
        ]
  in
  let events =
    Stale_hold.detect_stale ~adapter ~date:(_date "2024-01-15") ~portfolio
      ~today_bars:[ _today_bar ~symbol:"AAPL" ~price:110.0 ]
      ~config:Stale_hold.default_config
  in
  assert_that events (size_is 0)

let test_detect_held_position_with_recent_prior_bar_is_not_stale _ =
  (* Symbol has no bar today, but last bar is only 2 days ago — under the
     default K=5 threshold. Not stale. *)
  let portfolio =
    _portfolio_with_position ~symbol:"AAPL" ~quantity:10.0 ~entry_price:100.0
      ~entry_date:(_date "2024-01-02")
  in
  let adapter =
    _adapter_of_table ~table:[ ("AAPL", _date "2024-01-13", 105.0) ]
  in
  let events =
    Stale_hold.detect_stale ~adapter ~date:(_date "2024-01-15") ~portfolio
      ~today_bars:[] ~config:Stale_hold.default_config
  in
  assert_that events (size_is 0)

let test_detect_held_position_with_stale_prior_bar_emits_event _ =
  (* Symbol last had a bar 7 days ago — over the default K=5 threshold.
     One event with the last-known close + the per-position metadata. *)
  let portfolio =
    _portfolio_with_position ~symbol:"ANDV" ~quantity:100.0 ~entry_price:80.0
      ~entry_date:(_date "2018-06-01")
  in
  let adapter =
    _adapter_of_table ~table:[ ("ANDV", _date "2018-09-28", 153.46) ]
  in
  let events =
    Stale_hold.detect_stale ~adapter ~date:(_date "2018-10-05") ~portfolio
      ~today_bars:[] ~config:Stale_hold.default_config
  in
  assert_that events
    (elements_are
       [
         all_of
           [
             field (fun (e : Stale_hold.event) -> e.symbol) (equal_to "ANDV");
             field
               (fun (e : Stale_hold.event) -> e.last_bar_date)
               (equal_to (_date "2018-09-28"));
             field
               (fun (e : Stale_hold.event) -> e.last_close)
               (float_equal 153.46);
             field
               (fun (e : Stale_hold.event) -> e.days_since_last_bar)
               (equal_to 7);
             field
               (fun (e : Stale_hold.event) -> e.quantity)
               (float_equal 100.0);
             field
               (fun (e : Stale_hold.event) -> e.cost_basis)
               (float_equal 8000.0);
           ];
       ])

let test_detect_held_position_with_no_prior_bar_is_dropped _ =
  (* Symbol has no bars at all in the adapter — not stale (it's never been
     seen, which the detector treats as "we have no signal", not "stale").
     The downstream forward-fill in [_compute_portfolio_value] will fall
     through to cash-only valuation for this case. *)
  let portfolio =
    _portfolio_with_position ~symbol:"GHOST" ~quantity:1.0 ~entry_price:1.0
      ~entry_date:(_date "2024-01-02")
  in
  let adapter = _adapter_of_table ~table:[] in
  let events =
    Stale_hold.detect_stale ~adapter ~date:(_date "2024-02-01") ~portfolio
      ~today_bars:[] ~config:Stale_hold.default_config
  in
  assert_that events (size_is 0)

let test_detect_disabled_returns_no_events _ =
  let portfolio =
    _portfolio_with_position ~symbol:"ANDV" ~quantity:100.0 ~entry_price:80.0
      ~entry_date:(_date "2018-06-01")
  in
  let adapter =
    _adapter_of_table ~table:[ ("ANDV", _date "2018-09-28", 153.46) ]
  in
  let config = { Stale_hold.enabled = false; stale_after_days = 5 } in
  let events =
    Stale_hold.detect_stale ~adapter ~date:(_date "2018-10-05") ~portfolio
      ~today_bars:[] ~config
  in
  assert_that events (size_is 0)

(* -------------------------------------------------------------------- *)
(* Log + persistence                                                     *)
(* -------------------------------------------------------------------- *)

let _sample_event ~symbol ~date : Stale_hold.event =
  {
    symbol;
    date;
    last_bar_date = Date.add_days date (-7);
    last_close = 100.0;
    days_since_last_bar = 7;
    quantity = 100.0;
    cost_basis = 10_000.0;
  }

let test_log_records_events_in_chronological_order _ =
  let log = Stale_hold.Log.create () in
  Stale_hold.Log.record log
    (_sample_event ~symbol:"BBB" ~date:(_date "2024-02-01"));
  Stale_hold.Log.record log
    (_sample_event ~symbol:"AAA" ~date:(_date "2024-01-15"));
  Stale_hold.Log.record log
    (_sample_event ~symbol:"AAA" ~date:(_date "2024-02-01"));
  assert_that
    (Stale_hold.Log.events log)
    (elements_are
       [
         field
           (fun (e : Stale_hold.event) -> e.date)
           (equal_to (_date "2024-01-15"));
         field (fun (e : Stale_hold.event) -> e.symbol) (equal_to "AAA");
         field (fun (e : Stale_hold.event) -> e.symbol) (equal_to "BBB");
       ])

let test_log_distinct_symbols_dedupes _ =
  let log = Stale_hold.Log.create () in
  Stale_hold.Log.record log
    (_sample_event ~symbol:"BBB" ~date:(_date "2024-02-01"));
  Stale_hold.Log.record log
    (_sample_event ~symbol:"AAA" ~date:(_date "2024-01-15"));
  Stale_hold.Log.record log
    (_sample_event ~symbol:"AAA" ~date:(_date "2024-02-01"));
  assert_that
    (Stale_hold.Log.distinct_symbols log)
    (elements_are [ equal_to "AAA"; equal_to "BBB" ])

let test_save_sexp_skips_empty_log _ =
  let log = Stale_hold.Log.create () in
  let path = Filename_unix.temp_file "stale_hold_empty_" ".sexp" in
  (* Pre-create the path so we can verify save_sexp leaves it untouched. *)
  Out_channel.write_all path ~data:"PRE-EXISTING";
  Stale_hold.save_sexp ~path log;
  assert_that (In_channel.read_all path) (equal_to "PRE-EXISTING")

let test_save_then_load_sexp_roundtrip _ =
  let log = Stale_hold.Log.create () in
  let ev1 = _sample_event ~symbol:"ANDV" ~date:(_date "2018-10-05") in
  let ev2 = _sample_event ~symbol:"PX" ~date:(_date "2018-11-01") in
  Stale_hold.Log.record log ev1;
  Stale_hold.Log.record log ev2;
  let path = Filename_unix.temp_file "stale_hold_roundtrip_" ".sexp" in
  Stale_hold.save_sexp ~path log;
  let loaded = Stale_hold.load_sexp path in
  assert_that loaded
    (elements_are
       [
         field (fun (e : Stale_hold.event) -> e.symbol) (equal_to "ANDV");
         field (fun (e : Stale_hold.event) -> e.symbol) (equal_to "PX");
       ])

let suite =
  "Stale_hold"
  >::: [
         "detect: no held positions" >:: test_detect_no_held_positions;
         "detect: held position with today's bar is not stale"
         >:: test_detect_held_position_with_today_bar_is_not_stale;
         "detect: held position with recent prior bar is not stale"
         >:: test_detect_held_position_with_recent_prior_bar_is_not_stale;
         "detect: held position past staleness threshold emits event"
         >:: test_detect_held_position_with_stale_prior_bar_emits_event;
         "detect: held position with no prior bar is dropped"
         >:: test_detect_held_position_with_no_prior_bar_is_dropped;
         "detect: enabled=false suppresses all events"
         >:: test_detect_disabled_returns_no_events;
         "log: events returned in chronological order"
         >:: test_log_records_events_in_chronological_order;
         "log: distinct_symbols dedupes" >:: test_log_distinct_symbols_dedupes;
         "save_sexp: empty log leaves path untouched"
         >:: test_save_sexp_skips_empty_log;
         "save_sexp + load_sexp roundtrip"
         >:: test_save_then_load_sexp_roundtrip;
       ]

let () = run_test_tt_main suite
