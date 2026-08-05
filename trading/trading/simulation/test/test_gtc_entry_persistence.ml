(** Pins the simulator's *existing* persistence contract for order-generator
    StopLimit entry orders (the #2158 do-not-chase entry fill model).

    Pre-audit finding (2026-08-04,
    dev/notes/gtc-entry-persistence-preaudit-2026-08-04.md): an unfilled
    StopLimit entry order emitted by {!Order_generator} does NOT expire at the
    end of its submission day. Neither {!Trading_orders.Manager} nor
    {!Trading_engine.Engine} acts on the order's [time_in_force = Day] field (it
    is inert metadata); an unfilled order stays [Pending] in the manager and the
    engine fills it on the first later bar that trades through the trigger
    (within the do-not-chase cap). Fill routing survives the per-step
    [order_links] reset via {!Fill_router}'s (symbol, state, side) heuristic
    fallback, because the position remains [Entering] until the fill.

    This behaviour is equivalent to a Good-Till-Cancelled entry today — it was
    previously unpinned and had been mis-described as "Day orders expire". These
    tests lock it in so any future change (e.g. adding a genuine Day-expiry
    default, or a cancel-on-candidacy-loss lifecycle) is a deliberate, visible
    diff rather than a silent one. *)

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

let entry_price = 160.0

(* Below the entry trigger (E=160) for the first three bars, then the Jan-5 bar
   trades up through E (high=165). *)
let prices =
  [
    make_daily_price
      ~date:(date_of_string "2024-01-02")
      ~open_price:150.0 ~high:152.0 ~low:149.0 ~close:151.0 ~volume:1000000;
    make_daily_price
      ~date:(date_of_string "2024-01-03")
      ~open_price:151.0 ~high:153.0 ~low:150.0 ~close:152.0 ~volume:1000000;
    make_daily_price
      ~date:(date_of_string "2024-01-04")
      ~open_price:152.0 ~high:154.0 ~low:151.0 ~close:153.0 ~volume:1000000;
    make_daily_price
      ~date:(date_of_string "2024-01-05")
      ~open_price:153.0 ~high:165.0 ~low:152.0 ~close:164.0 ~volume:1000000;
    make_daily_price
      ~date:(date_of_string "2024-01-08")
      ~open_price:164.0 ~high:166.0 ~low:162.0 ~close:165.0 ~volume:1000000;
  ]

let sample_commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

let make_create_entering ~position_id : Trading_strategy.Position.transition =
  {
    position_id;
    date = date_of_string "2024-01-02";
    kind =
      CreateEntering
        {
          symbol = "AAPL";
          side = Long;
          target_quantity = 10.0;
          entry_price;
          reasoning = ManualDecision { description = "persistence test" };
        };
  }

(** Emits [CreateEntering] for AAPL exactly once (on the first call), then never
    again. Isolates the order-lifecycle question from any re-emission. *)
module Once_entry_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
end = struct
  let name = "OnceEntry"
  let emitted = ref false
  let reset () = emitted := false

  let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
    if !emitted then Ok { Trading_strategy.Strategy_interface.transitions = [] }
    else begin
      emitted := true;
      Ok
        {
          Trading_strategy.Strategy_interface.transitions =
            [ make_create_entering ~position_id:"AAPL-ONCE" ];
        }
    end
end

(** Re-runs every call and re-emits [CreateEntering] only when no position
    already exists for the symbol — mirrors the real Weinstein strategy's
    [Entry_walk.held_symbols] suppression (an Entering/Holding/Exiting position
    removes the symbol from the candidate set). *)
module Reemit_if_not_held_strategy :
  Trading_strategy.Strategy_interface.STRATEGY = struct
  let name = "ReemitIfNotHeld"

  let _has_position positions =
    Map.exists positions ~f:(fun (p : Trading_strategy.Position.t) ->
        String.equal p.symbol "AAPL")

  let on_market_close ~get_price:_ ~get_indicator:_
      ~(portfolio : Trading_strategy.Portfolio_view.t) =
    if _has_position portfolio.positions then
      Ok { Trading_strategy.Strategy_interface.transitions = [] }
    else
      Ok
        {
          Trading_strategy.Strategy_interface.transitions =
            [ make_create_entering ~position_id:"AAPL-REEMIT" ];
        }
end

let config =
  {
    start_date = date_of_string "2024-01-02";
    end_date = date_of_string "2024-01-09";
    initial_cash = 100000.0;
    commission = sample_commission;
    strategy_cadence = Types.Cadence.Daily;
  }

let run_exn ~name ~strategy =
  with_test_data name
    [ ("AAPL", prices) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ "AAPL" ] ~data_dir ~strategy
          ~commission:sample_commission ~entry_extension_max_pct:15.0 ()
      in
      let sim = Test_helpers.create_exn ~config ~deps in
      match run sim with
      | Error err -> failwith ("run failed: " ^ Status.show err)
      | Ok result -> result)

(* Every fill trade across the run, in chronological step order. *)
let all_trades result = List.concat_map result.steps ~f:(fun s -> s.trades)

(* The StopLimit resting from day 1 fills on Jan 5 — the first bar to trade
   through E=160 — at a price between the trigger (160) and the do-not-chase cap
   (E * 1.15 = 184). Exactly one entry Buy for the whole run. *)
let assert_single_later_cross_fill result =
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
               (fun (t : Trading_base.Types.trade) -> t.quantity)
               (float_equal 10.0);
             field
               (fun (t : Trading_base.Types.trade) -> t.price)
               (is_between
                  (module Float_ord)
                  ~low:entry_price ~high:(entry_price *. 1.15));
           ];
       ])

(* The fill lands on the Jan-5 step, not on any of the three sub-trigger days
   before it and not on the days after. *)
let assert_fill_is_on_cross_day result =
  assert_that
    (List.map result.steps ~f:(fun s -> List.length s.trades))
    (equal_to [ 0; 0; 0; 1; 0; 0; 0 ])

let test_unfilled_stoplimit_persists_and_fills_on_later_cross _ =
  Once_entry_strategy.reset ();
  let result =
    run_exn ~name:"gtc_entry_persistence_once"
      ~strategy:(module Once_entry_strategy)
  in
  assert_single_later_cross_fill result;
  assert_fill_is_on_cross_day result

let test_entering_position_suppresses_reemission_yet_order_persists _ =
  let result =
    run_exn ~name:"gtc_entry_persistence_reemit"
      ~strategy:(module Reemit_if_not_held_strategy)
  in
  (* Exactly one entry order is submitted (day 1); the Entering position
     suppresses re-emission on every later day, yet the single resting order
     still persists and fills the Jan-5 cross. *)
  assert_that
    (List.map result.steps ~f:(fun s -> List.length s.orders_submitted))
    (equal_to [ 1; 0; 0; 0; 0; 0; 0 ]);
  assert_single_later_cross_fill result;
  assert_fill_is_on_cross_day result

let suite =
  "GTC entry persistence"
  >::: [
         "unfilled StopLimit persists and fills on the later cross"
         >:: test_unfilled_stoplimit_persists_and_fills_on_later_cross;
         "Entering position suppresses re-emission yet the resting order \
          persists"
         >:: test_entering_position_suppresses_reemission_yet_order_persists;
       ]

let () = run_test_tt_main suite
