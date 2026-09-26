(** Unit tests for {!Trigger_bar_stop_fill} (issue #2961).

    [select] decides which of a step's freshly generated orders become same-bar
    [Stop] exits; [execute] fills them against the engine's current bars and
    reverts any the engine leaves unfilled to a resting Market order. The
    simulator-level behaviour is pinned in [test_sim_stop_exit_trigger_bar.ml].
*)

open Core
open OUnit2
open Matchers
module Stop_fill = Trading_simulation.Trigger_bar_stop_fill

let _date = Date.of_string "2024-01-04"
let _stop = 96.0

let _ok_exn ~msg = function
  | Ok v -> v
  | Error err -> assert_failure (msg ^ ": " ^ Status.show err)

let _market_order ~id ~side =
  Trading_orders.Create_order.create_order ~id
    {
      symbol = "AAPL";
      side;
      order_type = Trading_base.Types.Market;
      quantity = 10.0;
      time_in_force = Trading_orders.Types.Day;
    }
  |> _ok_exn ~msg:"create_order"

let _bar ~open_price ~low =
  {
    Trading_engine.Types.symbol = "AAPL";
    open_price;
    high_price = 100.5;
    low_price = low;
    close_price = 99.0;
  }

let _exit_transition exit_reason : Trading_strategy.Position.transition =
  {
    position_id = "P1";
    date = _date;
    kind = TriggerExit { exit_reason; exit_price = 95.0 };
  }

let _stop_loss =
  Trading_strategy.Position.StopLoss
    { stop_price = _stop; actual_price = 95.0; loss_percent = 0.0 }

let _select ?(enabled = true) ?(exit_reason = _stop_loss)
    ?(today_bars = [ _bar ~open_price:100.0 ~low:95.0 ]) () =
  Stop_fill.select ~enabled
    ~transitions:[ _exit_transition exit_reason ]
    ~order_links:[ ("O1", "P1") ]
    ~today_bars
    [ _market_order ~id:"O1" ~side:Sell ]

let _order_types (orders : Trading_orders.Types.order list) =
  List.map orders ~f:(fun o -> o.order_type)

(* The (converted, rest) split as order types, for whole-value comparison. *)
let _split_types (converted, rest) = (_order_types converted, _order_types rest)

let test_stop_loss_exit_converts_to_stop_at_the_stop_level _ =
  assert_that
    (_split_types (_select ()))
    (equal_to
       (([ Stop _stop ], [])
         : Trading_base.Types.order_type list
           * Trading_base.Types.order_type list))

let test_disabled_converts_nothing _ =
  assert_that
    (_split_types (_select ~enabled:false ()))
    (equal_to
       (([], [ Market ])
         : Trading_base.Types.order_type list
           * Trading_base.Types.order_type list))

let test_non_stop_loss_exit_stays_market _ =
  assert_that
    (_split_types
       (_select
          ~exit_reason:
            (StrategySignal { label = "force_liquidation"; detail = None })
          ()))
    (equal_to
       (([], [ Market ])
         : Trading_base.Types.order_type list
           * Trading_base.Types.order_type list))

(* A bar that never trades down to the stop (low 97 > 96) cannot fill a resting
   sell-stop, so the exit keeps the next-open Market order. *)
let test_bar_not_reaching_the_stop_stays_market _ =
  assert_that
    (_split_types (_select ~today_bars:[ _bar ~open_price:100.0 ~low:97.0 ] ()))
    (equal_to
       (([], [ Market ])
         : Trading_base.Types.order_type list
           * Trading_base.Types.order_type list))

(* No fresh bar for the symbol this step (e.g. a weekend step): no conversion. *)
let test_no_fresh_bar_stays_market _ =
  assert_that
    (_split_types (_select ~today_bars:[] ()))
    (equal_to
       (([], [ Market ])
         : Trading_base.Types.order_type list
           * Trading_base.Types.order_type list))

(* Engine + manager holding [bar] as the current market, zero costs. *)
let _engine_and_manager bar =
  let engine =
    Trading_engine.Engine.create
      {
        commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
        slippage_bps = 0;
      }
  in
  Trading_engine.Engine.update_market engine [ bar ];
  (engine, Trading_orders.Manager.create ())

let _stop_order () =
  { (_market_order ~id:"O1" ~side:Sell) with order_type = Stop _stop }

(* A gap through the stop fills at the bar's open, dated [date]. *)
let test_execute_fills_a_gap_at_the_open _ =
  let engine, order_manager =
    _engine_and_manager (_bar ~open_price:94.0 ~low:93.0)
  in
  assert_that
    (Stop_fill.execute ~engine ~order_manager ~date:_date [ _stop_order () ])
    (is_ok_and_holds
       (elements_are
          [
            all_of
              [
                field
                  (fun (t : Trading_base.Types.trade) -> t.price)
                  (float_equal 94.0);
                field
                  (fun (t : Trading_base.Types.trade) ->
                    Time_ns_unix.to_date t.timestamp ~zone:Time_float.Zone.utc)
                  (equal_to _date);
              ];
          ]))

(* The fallback: a converted order the engine does not fill is reverted in
   place to an active Market order, so it fills at the next open exactly as
   with the flag off. *)
let test_execute_reverts_an_unfilled_order_to_market _ =
  let engine, order_manager =
    _engine_and_manager (_bar ~open_price:100.0 ~low:97.0)
  in
  let trades =
    Stop_fill.execute ~engine ~order_manager ~date:_date [ _stop_order () ]
  in
  assert_that
    (trades, Trading_orders.Manager.get_order order_manager "O1")
    (all_of
       [
         field fst (is_ok_and_holds (size_is 0));
         field snd
           (is_ok_and_holds
              (all_of
                 [
                   field
                     (fun (o : Trading_orders.Types.order) -> o.order_type)
                     (equal_to (Market : Trading_base.Types.order_type));
                   field
                     (fun (o : Trading_orders.Types.order) -> o.status)
                     (equal_to (Pending : Trading_orders.Types.order_status));
                 ]));
       ])

let test_execute_empty_is_a_no_op _ =
  let engine, order_manager =
    _engine_and_manager (_bar ~open_price:100.0 ~low:95.0)
  in
  assert_that
    (Stop_fill.execute ~engine ~order_manager ~date:_date [])
    (is_ok_and_holds (size_is 0))

let suite =
  "trigger_bar_stop_fill"
  >::: [
         "a StopLoss exit converts to Stop at the stop level"
         >:: test_stop_loss_exit_converts_to_stop_at_the_stop_level;
         "disabled converts nothing" >:: test_disabled_converts_nothing;
         "a non-StopLoss exit stays Market"
         >:: test_non_stop_loss_exit_stays_market;
         "a bar not reaching the stop stays Market"
         >:: test_bar_not_reaching_the_stop_stays_market;
         "no fresh bar stays Market" >:: test_no_fresh_bar_stays_market;
         "execute fills a gap at the open"
         >:: test_execute_fills_a_gap_at_the_open;
         "execute reverts an unfilled order to Market"
         >:: test_execute_reverts_an_unfilled_order_to_market;
         "execute of no orders is a no-op" >:: test_execute_empty_is_a_no_op;
       ]

let () = run_test_tt_main suite
