(** Tests for [sim_exit_fill_next_open] (Fix #1b;
    dev/plans/fill-model-faithfulness-2026-08-07.md Workstream C).

    The simulator advances one {i calendar} day per step, and on a non-trading
    step the engine receives no bars and retains the previous session's bar per
    symbol. So a Market EXIT order created from a Friday-close decision is
    filled on the following Saturday step against the stale Friday bar — at that
    bar's OPEN, a price observed {i before} the decision's close — and the trade
    is re-stamped Saturday. [sim_exit_fill_next_open] holds such an order back
    until the next fresh trading bar, where it fills at that bar's open.

    Default-off, so [off_exit_fills_at_stale_friday_open] pins today's behaviour
    (R1) and [on_exit_fills_at_monday_open] pins the armed behaviour. The exit
    flag is independent of [sim_entry_fill_next_open]:
    [flag_off_is_bit_identical_for_entries] shows arming exits alone leaves
    entry fills exactly where they were, and
    [test_sim_entry_next_open.test_exit_unaffected_when_flag_on] (still green)
    shows the converse. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers

let date_of_string s = Date.of_string s

let make_daily_price ~date ~open_price ~high ~low ~close ~volume =
  Types.Daily_price.
    {
      date;
      open_price;
      high_price = high;
      low_price = low;
      close_price = close;
      volume;
      adjusted_close = close;
      active_through = None;
    }

(* Commission / slippage held at zero so a fill price equals the bar open
   exactly — the assertions pin the fill basis, not the cost model. *)
let sample_commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }
let all_trades result = List.concat_map result.steps ~f:(fun s -> s.trades)

let step_trade_counts result =
  List.map result.steps ~f:(fun s -> List.length s.trades)

let sell_prices result =
  List.filter_map (all_trades result) ~f:(fun (t : Trading_base.Types.trade) ->
      match t.side with Sell -> Some t.price | Buy -> None)

(* ===================== One round trip over one weekend ===================== *)

(* AAPL trades Thu/Fri, then gaps over the weekend to Monday. The three opens
   differ (200 / 210 / 220) so the exit-fill basis is observable: OFF fills the
   Friday-decided exit on the Saturday step at the retained Friday open (210),
   ON waits for Monday and fills at Monday's open (220). *)
let exit_gap_prices =
  [
    make_daily_price
      ~date:(date_of_string "2024-01-04")
      ~open_price:200.0 ~high:203.0 ~low:199.0 ~close:201.0 ~volume:1_000_000;
    make_daily_price
      ~date:(date_of_string "2024-01-05")
      ~open_price:210.0 ~high:215.0 ~low:209.0 ~close:212.0 ~volume:1_000_000;
    make_daily_price
      ~date:(date_of_string "2024-01-08")
      ~open_price:220.0 ~high:224.0 ~low:219.0 ~close:222.0 ~volume:1_000_000;
  ]

(* Enters AAPL once while flat, exits once the position is [Holding], and never
   re-enters — a single clean round trip. Keys off position state (not a call
   counter) so it is robust to fill timing. Mirrors the identically-named module
   in [test_sim_entry_next_open.ml]. *)
module Enter_then_exit_when_held : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
end = struct
  let name = "EnterThenExitWhenHeld"
  let entered = ref false
  let exited = ref false

  let reset () =
    entered := false;
    exited := false

  let _entry =
    {
      Trading_strategy.Position.position_id = "AAPL-EXIT";
      date = date_of_string "2024-01-04";
      kind =
        CreateEntering
          {
            symbol = "AAPL";
            side = Long;
            target_quantity = 5.0;
            entry_price = 201.0;
            reasoning = ManualDecision { description = "exit test" };
          };
    }

  let _exit =
    {
      Trading_strategy.Position.position_id = "AAPL-EXIT";
      date = date_of_string "2024-01-05";
      kind =
        TriggerExit
          {
            exit_reason = SignalReversal { description = "exit test" };
            exit_price = 212.0;
          };
    }

  let _is_holding pos =
    match Trading_strategy.Position.get_state pos with
    | Holding _ -> true
    | _ -> false

  let on_market_close ~get_price:_ ~get_indicator:_
      ~(portfolio : Trading_strategy.Portfolio_view.t) =
    let none = { Trading_strategy.Strategy_interface.transitions = [] } in
    match Map.find portfolio.positions "AAPL-EXIT" with
    | None when not !entered ->
        entered := true;
        Ok { Trading_strategy.Strategy_interface.transitions = [ _entry ] }
    | Some pos when (not !exited) && _is_holding pos ->
        exited := true;
        Ok { Trading_strategy.Strategy_interface.transitions = [ _exit ] }
    | Some _ | None -> Ok none
end

(* Steps run 01-04 .. 01-08 inclusive ([end_date] is exclusive), i.e. Thu, Fri,
   Sat, Sun, Mon. *)
let exit_config =
  {
    start_date = date_of_string "2024-01-04";
    end_date = date_of_string "2024-01-09";
    initial_cash = 100_000.0;
    commission = sample_commission;
    strategy_cadence = Types.Cadence.Daily;
  }

let run_round_trip_exn ~name ~sim_exit_fill_next_open =
  Enter_then_exit_when_held.reset ();
  with_test_data name
    [ ("AAPL", exit_gap_prices) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ "AAPL" ] ~data_dir
          ~strategy:(module Enter_then_exit_when_held)
          ~commission:sample_commission ~sim_exit_fill_next_open ()
      in
      let sim = create_exn ~config:exit_config ~deps in
      match run sim with
      | Error err -> failwith ("run failed: " ^ Status.show err)
      | Ok result -> result)

(* OFF (the default): the exit decided at Friday's close fills on the FIRST
   post-decision step (Sat 01-06, index 2) against the retained Friday bar, at
   that bar's open (210.0) — a price that predates the decision. This documents
   today's behaviour and is the R1 pin. The entry is undeferred either way: it
   was decided Thursday and Friday's bar is fresh, so it fills at 210.0 on
   index 1. *)
let test_off_exit_fills_at_stale_friday_open _ =
  let result =
    run_round_trip_exn ~name:"exit_next_open_off" ~sim_exit_fill_next_open:false
  in
  assert_that (step_trade_counts result) (equal_to [ 0; 1; 1; 0; 0 ]);
  assert_that (sell_prices result) (elements_are [ float_equal 210.0 ])

(* ON: the same exit is held back across the stale Sat/Sun steps and fills at
   the next fresh trading bar's open (Mon 01-08, open 220.0, index 4). Both the
   fill price and the trade's date move to a day the market was actually
   open. *)
let test_on_exit_fills_at_monday_open _ =
  let result =
    run_round_trip_exn ~name:"exit_next_open_on" ~sim_exit_fill_next_open:true
  in
  assert_that (step_trade_counts result) (equal_to [ 0; 1; 0; 0; 1 ]);
  assert_that (sell_prices result) (elements_are [ float_equal 220.0 ])

(* ===================== Entries untouched by the exit flag ================== *)

(* AAPL trades Fri 2024-01-05 (the signal bar) and again Mon 2024-01-08 after a
   weekend gap. Same fixture as [test_sim_entry_next_open]'s entry scenario. *)
let entry_gap_prices =
  [
    make_daily_price
      ~date:(date_of_string "2024-01-05")
      ~open_price:100.0 ~high:112.0 ~low:99.0 ~close:110.0 ~volume:1_000_000;
    make_daily_price
      ~date:(date_of_string "2024-01-08")
      ~open_price:120.0 ~high:126.0 ~low:119.0 ~close:125.0 ~volume:1_000_000;
    make_daily_price
      ~date:(date_of_string "2024-01-09")
      ~open_price:125.0 ~high:127.0 ~low:124.0 ~close:126.0 ~volume:1_000_000;
  ]

(* Emits a single Market [CreateEntering] for AAPL on the first strategy call
   (the Friday 01-05 signal), then never again — the position never reaches
   [Exiting], so the exit gate must never see it. *)
module Once_entry_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
end = struct
  let name = "OnceEntryMarket"
  let emitted = ref false
  let reset () = emitted := false

  let _entry =
    {
      Trading_strategy.Position.position_id = "AAPL-ONCE";
      date = date_of_string "2024-01-05";
      kind =
        CreateEntering
          {
            symbol = "AAPL";
            side = Long;
            target_quantity = 10.0;
            entry_price = 110.0;
            reasoning = ManualDecision { description = "entry test" };
          };
    }

  let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
    if !emitted then Ok { Trading_strategy.Strategy_interface.transitions = [] }
    else begin
      emitted := true;
      Ok { Trading_strategy.Strategy_interface.transitions = [ _entry ] }
    end
end

let entry_config =
  {
    start_date = date_of_string "2024-01-05";
    end_date = date_of_string "2024-01-10";
    initial_cash = 100_000.0;
    commission = sample_commission;
    strategy_cadence = Types.Cadence.Daily;
  }

(* Arming the EXIT flag alone leaves entry fills exactly where the default puts
   them: the Friday-decided Market entry still fills on the stale Sat 01-06 step
   (index 1) at the retained Friday open (100.0), identical to
   [test_sim_entry_next_open.test_off_fills_at_stale_signal_bar_open]. The two
   flags are independent knobs. *)
let test_flag_off_is_bit_identical_for_entries _ =
  Once_entry_strategy.reset ();
  let result =
    with_test_data "exit_next_open_entry_unaffected"
      [ ("AAPL", entry_gap_prices) ]
      ~f:(fun data_dir ->
        let deps =
          create_deps ~symbols:[ "AAPL" ] ~data_dir
            ~strategy:(module Once_entry_strategy)
            ~commission:sample_commission ~sim_entry_fill_next_open:false
            ~sim_exit_fill_next_open:true ()
        in
        let sim = create_exn ~config:entry_config ~deps in
        match run sim with
        | Error err -> failwith ("run failed: " ^ Status.show err)
        | Ok r -> r)
  in
  assert_that (step_trade_counts result) (equal_to [ 0; 1; 0; 0; 0 ]);
  assert_that
    (List.map (all_trades result) ~f:(fun (t : Trading_base.Types.trade) ->
         t.price))
    (elements_are [ float_equal 100.0 ])

(* ============ Invariant: no fill is dated on a day without a bar =========== *)

(* Two round trips over a calendar containing two weekends AND a mid-week hole
   (no Wed 2024-01-10 bar). Each of the three fills is forced across one of the
   gaps: entry #1 across the first weekend, exit #1 across the mid-week hole,
   entry #2 across the second weekend. *)
let multi_week_prices =
  [
    make_daily_price
      ~date:(date_of_string "2024-01-04")
      ~open_price:100.0 ~high:104.0 ~low:99.0 ~close:101.0 ~volume:1_000_000;
    make_daily_price
      ~date:(date_of_string "2024-01-05")
      ~open_price:102.0 ~high:106.0 ~low:101.0 ~close:103.0 ~volume:1_000_000;
    make_daily_price
      ~date:(date_of_string "2024-01-08")
      ~open_price:110.0 ~high:114.0 ~low:109.0 ~close:111.0 ~volume:1_000_000;
    make_daily_price
      ~date:(date_of_string "2024-01-09")
      ~open_price:112.0 ~high:116.0 ~low:111.0 ~close:113.0 ~volume:1_000_000;
    (* No bar on Wed 2024-01-10 — a mid-week trading hole. *)
    make_daily_price
      ~date:(date_of_string "2024-01-11")
      ~open_price:120.0 ~high:124.0 ~low:119.0 ~close:121.0 ~volume:1_000_000;
    make_daily_price
      ~date:(date_of_string "2024-01-12")
      ~open_price:122.0 ~high:126.0 ~low:121.0 ~close:123.0 ~volume:1_000_000;
    make_daily_price
      ~date:(date_of_string "2024-01-15")
      ~open_price:130.0 ~high:134.0 ~low:129.0 ~close:131.0 ~volume:1_000_000;
    make_daily_price
      ~date:(date_of_string "2024-01-16")
      ~open_price:132.0 ~high:136.0 ~low:131.0 ~close:133.0 ~volume:1_000_000;
  ]

let multi_week_bar_dates =
  Date.Set.of_list
    (List.map multi_week_prices ~f:(fun (p : Types.Daily_price.t) -> p.date))

let _make_entry ~position_id ~date ~entry_price =
  {
    Trading_strategy.Position.position_id;
    date;
    kind =
      CreateEntering
        {
          symbol = "AAPL";
          side = Long;
          target_quantity = 5.0;
          entry_price;
          reasoning = ManualDecision { description = "multi-week entry" };
        };
  }

let _make_exit ~position_id ~date ~exit_price =
  {
    Trading_strategy.Position.position_id;
    date;
    kind =
      TriggerExit
        {
          exit_reason = SignalReversal { description = "multi-week exit" };
          exit_price;
        };
  }

(* Scripted by strategy-call index over the 13 calendar steps 01-04 .. 01-16, so
   each decision lands on a known date: call 2 = Fri 01-05, call 6 = Tue 01-09,
   call 9 = Fri 01-12. Every decision is followed by at least one barless step,
   so with both flags on every fill must be deferred to the next fresh bar. *)
module Scripted_round_trips : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
end = struct
  let name = "ScriptedRoundTrips"
  let call_count = ref 0
  let reset () = call_count := 0

  let _script =
    Int.Map.of_alist_exn
      [
        ( 2,
          _make_entry ~position_id:"AAPL-1"
            ~date:(date_of_string "2024-01-05")
            ~entry_price:103.0 );
        ( 6,
          _make_exit ~position_id:"AAPL-1"
            ~date:(date_of_string "2024-01-09")
            ~exit_price:113.0 );
        ( 9,
          _make_entry ~position_id:"AAPL-2"
            ~date:(date_of_string "2024-01-12")
            ~entry_price:123.0 );
      ]

  let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
    Int.incr call_count;
    let transitions = Option.to_list (Map.find _script !call_count) in
    Ok { Trading_strategy.Strategy_interface.transitions }
end

let multi_week_config =
  {
    start_date = date_of_string "2024-01-04";
    end_date = date_of_string "2024-01-17";
    initial_cash = 100_000.0;
    commission = sample_commission;
    strategy_cadence = Types.Cadence.Daily;
  }

(* A trade's date is the simulated step date ({!Fill_date_stamp.restamp} stamps
   the fill's timestamp with it at UTC start-of-day), so reading it back through
   the timestamp is what a downstream artifact consumer sees. *)
let trade_dates result =
  List.map (all_trades result) ~f:(fun (t : Trading_base.Types.trade) ->
      Time_ns_unix.to_date t.timestamp ~zone:Time_float.Zone.utc)

(* The integration invariant Fix #1 + #1b together buy: with both flags on, NO
   fill is stamped on a calendar day the symbol had no bar. The three fills land
   on Mon 01-08 (entry #1, across the first weekend), Thu 01-11 (exit #1, across
   the mid-week hole) and Mon 01-15 (entry #2, across the second weekend), each
   at that bar's open. Pinning the exact dates + prices also keeps the
   no-barless-date check from passing vacuously on zero trades. *)
let test_on_no_trade_is_dated_on_a_day_without_a_bar _ =
  Scripted_round_trips.reset ();
  let result =
    with_test_data "exit_next_open_multi_week"
      [ ("AAPL", multi_week_prices) ]
      ~f:(fun data_dir ->
        let deps =
          create_deps ~symbols:[ "AAPL" ] ~data_dir
            ~strategy:(module Scripted_round_trips)
            ~commission:sample_commission ~sim_entry_fill_next_open:true
            ~sim_exit_fill_next_open:true ()
        in
        let sim = create_exn ~config:multi_week_config ~deps in
        match run sim with
        | Error err -> failwith ("run failed: " ^ Status.show err)
        | Ok r -> r)
  in
  assert_that
    (List.filter_map (trade_dates result) ~f:(fun d ->
         if Set.mem multi_week_bar_dates d then None
         else Some (Date.to_string d)))
    (equal_to ([] : string list));
  assert_that
    (List.map (trade_dates result) ~f:Date.to_string)
    (equal_to [ "2024-01-08"; "2024-01-11"; "2024-01-15" ]);
  assert_that
    (List.map (all_trades result) ~f:(fun (t : Trading_base.Types.trade) ->
         t.price))
    (elements_are [ float_equal 110.0; float_equal 120.0; float_equal 130.0 ])

let suite =
  "sim_exit_fill_next_open"
  >::: [
         "OFF fills the exit at the stale Friday open"
         >:: test_off_exit_fills_at_stale_friday_open;
         "ON fills the exit at the next fresh (Monday) open"
         >:: test_on_exit_fills_at_monday_open;
         "the exit flag leaves entry fills bit-identical"
         >:: test_flag_off_is_bit_identical_for_entries;
         "with both flags on, no trade is dated on a barless day"
         >:: test_on_no_trade_is_dated_on_a_day_without_a_bar;
       ]

let () = run_test_tt_main suite
