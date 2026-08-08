(** Tests for [sim_entry_fill_next_open] (Fix #1;
    dev/plans/fill-model-faithfulness-2026-08-07.md Workstream C).

    Default-off: a Market ENTRY order that would open ([Entering]) a position is
    held back on any step where its symbol has no fresh bar, so it fills at the
    next fresh trading bar's OPEN instead of the signal bar the engine retains
    across non-trading (weekend/holiday) steps.

    The scenario is a Friday-close decision followed by a weekend gap: OFF fills
    on the following non-trading step against the stale Friday bar (at that
    bar's own open — the current, optimistic basis); ON waits for Monday and
    fills at Monday's open. Only the executed engine fill price/date move — the
    strategy's decision-time [CreateEntering.entry_price] (used for sizing /
    stops) is unchanged in both. *)

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

(* AAPL trades Fri 2024-01-05 (the signal bar) and again Mon 2024-01-08 after a
   weekend gap. The two opens differ (100 vs 120) so the fill basis is
   observable: OFF fills at the stale Friday open (100), ON at the Monday open
   (120). *)
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

let entry_decision_price = 110.0
let entry_quantity = 10.0

(* Emits a single Market [CreateEntering] for AAPL on the first strategy call
   (the Friday 01-05 signal), then never again — isolates the entry-fill timing
   from re-emission. The decision [entry_price] is [entry_decision_price], NOT
   the eventual fill, so the test can show sizing is unaffected by the flag. *)
module Once_entry_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
end = struct
  let name = "OnceEntryMarket"
  let emitted = ref false
  let reset () = emitted := false

  let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
    if !emitted then Ok { Trading_strategy.Strategy_interface.transitions = [] }
    else begin
      emitted := true;
      Ok
        {
          Trading_strategy.Strategy_interface.transitions =
            [
              {
                Trading_strategy.Position.position_id = "AAPL-ONCE";
                date = date_of_string "2024-01-05";
                kind =
                  CreateEntering
                    {
                      symbol = "AAPL";
                      side = Trading_strategy.Position.Long;
                      target_quantity = entry_quantity;
                      entry_price = entry_decision_price;
                      reasoning = ManualDecision { description = "entry test" };
                    };
              };
            ];
        }
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

let run_entry_exn ~name ~sim_entry_fill_next_open =
  Once_entry_strategy.reset ();
  with_test_data name
    [ ("AAPL", entry_gap_prices) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ "AAPL" ] ~data_dir
          ~strategy:(module Once_entry_strategy)
          ~commission:sample_commission ~sim_entry_fill_next_open ()
      in
      let sim = create_exn ~config:entry_config ~deps in
      match run sim with
      | Error err -> failwith ("run failed: " ^ Status.show err)
      | Ok result -> result)

let all_trades result = List.concat_map result.steps ~f:(fun s -> s.trades)

let step_trade_counts result =
  List.map result.steps ~f:(fun s -> List.length s.trades)

(* OFF (default): the Market entry fills on the FIRST post-decision step
   (Sat 01-06) against the retained Friday bar, at that bar's open (100.0). This
   pins the current, optimistic basis — bit-identical to every existing
   baseline. *)
let test_off_fills_at_stale_signal_bar_open _ =
  let result =
    run_entry_exn ~name:"next_open_off" ~sim_entry_fill_next_open:false
  in
  assert_that (all_trades result)
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_base.Types.trade) -> t.symbol)
               (equal_to "AAPL");
             field
               (fun (t : Trading_base.Types.trade) -> t.side)
               (equal_to (Trading_base.Types.Buy : Trading_base.Types.side));
             field
               (fun (t : Trading_base.Types.trade) -> t.price)
               (float_equal 100.0);
           ];
       ]);
  (* Steps: 01-05, 06, 07, 08, 09. Fill lands on the 01-06 step (index 1). *)
  assert_that (step_trade_counts result) (equal_to [ 0; 1; 0; 0; 0 ])

(* ON: the entry is held back across the stale weekend steps and fills at the
   next fresh trading bar's open (Mon 01-08, open 120.0). Both price and date
   move to the next bar. *)
let test_on_fills_at_next_fresh_open _ =
  let result =
    run_entry_exn ~name:"next_open_on" ~sim_entry_fill_next_open:true
  in
  assert_that (all_trades result)
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_base.Types.trade) -> t.symbol)
               (equal_to "AAPL");
             field
               (fun (t : Trading_base.Types.trade) -> t.side)
               (equal_to (Trading_base.Types.Buy : Trading_base.Types.side));
             field
               (fun (t : Trading_base.Types.trade) -> t.price)
               (float_equal 120.0);
           ];
       ]);
  (* Fill lands on the 01-08 step (index 3), not the 01-06 stale step. *)
  assert_that (step_trade_counts result) (equal_to [ 0; 0; 0; 1; 0 ])

(* Sizing basis is unchanged by the flag: the position is sized at the
   decision-time [entry_price] (110.0, [entry_quantity] shares), while only the
   realized cash outlay follows the moved fill (100.0 OFF vs 120.0 ON). Pinning
   both final cashes shows the fill basis moved by exactly the two opens'
   difference on the same 10 shares. *)
let test_flag_moves_only_the_fill_basis _ =
  let off =
    run_entry_exn ~name:"next_open_cash_off" ~sim_entry_fill_next_open:false
  in
  let on =
    run_entry_exn ~name:"next_open_cash_on" ~sim_entry_fill_next_open:true
  in
  assert_that off.final_portfolio.current_cash
    (float_equal (100_000.0 -. (entry_quantity *. 100.0)));
  assert_that on.final_portfolio.current_cash
    (float_equal (100_000.0 -. (entry_quantity *. 120.0)))

(* ===================== Exits unaffected when flag ON ===================== *)

(* AAPL trades Thu/Fri, then gaps over the weekend. A held position's exit order
   is submitted Friday and must fill on the following stale step (Sat) — the
   next-open gate applies to entries only, so exits are untouched even with the
   flag ON. *)
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

(* Enters AAPL once while flat, then exits once the position is [Holding], and
   never re-enters — a single clean round trip. Keys off position state (not a
   call counter) so it is robust to fill timing. *)
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

let exit_config =
  {
    start_date = date_of_string "2024-01-04";
    end_date = date_of_string "2024-01-09";
    initial_cash = 100_000.0;
    commission = sample_commission;
    strategy_cadence = Types.Cadence.Daily;
  }

(* With the flag ON, the exit market Sell (submitted Fri 01-05) still fills on
   the stale Sat 01-06 step at the retained Friday open (210.0): the gate defers
   Market ENTRIES only, so exits are unaffected. Two trades total — the Thu
   entry (a fresh next-day fill, so undeferred) and the exit. *)
let test_exit_unaffected_when_flag_on _ =
  Enter_then_exit_when_held.reset ();
  let result =
    with_test_data "next_open_exit_on"
      [ ("AAPL", exit_gap_prices) ]
      ~f:(fun data_dir ->
        let deps =
          create_deps ~symbols:[ "AAPL" ] ~data_dir
            ~strategy:(module Enter_then_exit_when_held)
            ~commission:sample_commission ~sim_entry_fill_next_open:true ()
        in
        let sim = create_exn ~config:exit_config ~deps in
        match run sim with
        | Error err -> failwith ("run failed: " ^ Status.show err)
        | Ok r -> r)
  in
  (* Entry Buy on Fri 01-05 (index 1) at the fresh open 210; exit Sell on the
     stale Sat 01-06 step (index 2) at the retained Friday open 210. The exit
     fills on the stale step despite the flag being on — the gate defers Market
     ENTRIES only. *)
  assert_that (step_trade_counts result) (equal_to [ 0; 1; 1; 0; 0 ]);
  assert_that
    (List.filter_map (all_trades result) ~f:(fun t ->
         match t.Trading_base.Types.side with
         | Trading_base.Types.Sell -> Some t.price
         | Trading_base.Types.Buy -> None))
    (elements_are [ float_equal 210.0 ])

let suite =
  "sim_entry_fill_next_open"
  >::: [
         "OFF fills at the stale signal-bar open"
         >:: test_off_fills_at_stale_signal_bar_open;
         "ON fills at the next fresh bar open"
         >:: test_on_fills_at_next_fresh_open;
         "flag moves only the fill basis, not sizing"
         >:: test_flag_moves_only_the_fill_basis;
         "exit orders are unaffected when the flag is on"
         >:: test_exit_unaffected_when_flag_on;
       ]

let () = run_test_tt_main suite
