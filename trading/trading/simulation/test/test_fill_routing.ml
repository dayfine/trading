(** Tests for the simulator's side-aware fill routing
    ({!Fill_router.update_positions_from_trades}).

    Routing is by symbol + state + side: Long Entering ← Buy, Long Exiting ←
    Sell, Short Entering ← Sell, Short Exiting ← Buy. The two-sibling scenarios
    (an Entering add and an Exiting original on the same symbol, as scale-in
    produces) pin that a Sell fill reaches the Exiting position and a Buy fill
    reaches the Entering one — state-only routing would send both to Entering.
*)

open Core
open OUnit2
open Matchers
open Trading_strategy.Position
module Fill_router = Trading_simulation.Fill_router

let _date = Date.of_string "2024-03-08"

let _ok_exn ~msg = function
  | Ok v -> v
  | Error err -> assert_failure (msg ^ ": " ^ Status.show err)

let _entering ~id ~symbol ~side ~target_quantity ~entry_price : t =
  let transition =
    {
      position_id = id;
      date = _date;
      kind =
        CreateEntering
          {
            symbol;
            side;
            target_quantity;
            entry_price;
            reasoning = ManualDecision { description = "test" };
          };
    }
  in
  create_entering transition |> _ok_exn ~msg:"create_entering"

let _apply pos kind ~msg =
  apply_transition pos { position_id = pos.id; date = _date; kind }
  |> _ok_exn ~msg

let _holding ~id ~symbol ~side ~quantity ~entry_price : t =
  let pos =
    _entering ~id ~symbol ~side ~target_quantity:quantity ~entry_price
  in
  let pos =
    _apply pos
      (EntryFill { filled_quantity = quantity; fill_price = entry_price })
      ~msg:"entry fill"
  in
  _apply pos
    (EntryComplete
       {
         risk_params =
           {
             stop_loss_price = None;
             take_profit_price = None;
             max_hold_days = None;
           };
       })
    ~msg:"entry complete"

let _exiting ~id ~symbol ~side ~quantity ~entry_price ~exit_price : t =
  let pos = _holding ~id ~symbol ~side ~quantity ~entry_price in
  _apply pos
    (TriggerExit
       {
         exit_reason = SignalReversal { description = "test exit" };
         exit_price;
       })
    ~msg:"trigger exit"

let _positions_of (list : t list) =
  String.Map.of_alist_exn (List.map list ~f:(fun p -> (p.id, p)))

let _trade ~symbol ~(side : Trading_base.Types.side) ~quantity ~price :
    Trading_base.Types.trade =
  {
    id = "trade-1";
    order_id = "order-1";
    symbol;
    side;
    quantity;
    price;
    commission = 0.0;
    timestamp = Time_ns_unix.now ();
  }

let _update ~positions ~trades =
  Fill_router.update_positions_from_trades ~date:_date ~positions ~trades ()
  |> _ok_exn ~msg:"update_positions_from_trades"

(* Sibling pair on one symbol: the original Exiting (sell order open) and an
   add Entering (buy order open) — the state scale-in produces when a stop
   fires while an unfilled add is in flight. *)
let _sibling_positions () =
  _positions_of
    [
      _exiting ~id:"AAPL-orig" ~symbol:"AAPL" ~side:Long ~quantity:10.0
        ~entry_price:100.0 ~exit_price:95.0;
      _entering ~id:"AAPL-add" ~symbol:"AAPL" ~side:Long ~target_quantity:5.0
        ~entry_price:101.0;
    ]

(* ------- Tests ------- *)

let test_sell_fill_routes_to_exiting_sibling _ =
  (* Sell 10 must fill the Exiting original (which closes and is dropped from
     the map), NOT the Entering add — state-only routing would pick Entering
     first and book the sell as an entry fill. *)
  let updated =
    _update ~positions:(_sibling_positions ())
      ~trades:[ _trade ~symbol:"AAPL" ~side:Sell ~quantity:10.0 ~price:95.0 ]
  in
  assert_that updated
    (all_of
       [
         field (fun m -> Map.mem m "AAPL-orig") (equal_to false);
         field
           (fun m -> Map.find m "AAPL-add")
           (is_some_and
              (matching ~msg:"add must still be Entering with no fills"
                 (fun (p : t) ->
                   match get_state p with
                   | Entering e -> Some e.filled_quantity
                   | _ -> None)
                 (float_equal 0.0)));
       ])

let test_buy_fill_routes_to_entering_sibling _ =
  (* Buy 5 must fill the Entering add (→ Holding), leaving the Exiting original
     untouched. *)
  let updated =
    _update ~positions:(_sibling_positions ())
      ~trades:[ _trade ~symbol:"AAPL" ~side:Buy ~quantity:5.0 ~price:101.0 ]
  in
  assert_that updated
    (all_of
       [
         field
           (fun m -> Map.find m "AAPL-add")
           (is_some_and
              (matching ~msg:"add must be Holding its fill"
                 (fun (p : t) ->
                   match get_state p with
                   | Holding h -> Some h.quantity
                   | _ -> None)
                 (float_equal 5.0)));
         field
           (fun m -> Map.find m "AAPL-orig")
           (is_some_and
              (matching ~msg:"original must still be Exiting unfilled"
                 (fun (p : t) ->
                   match get_state p with
                   | Exiting e -> Some e.filled_quantity
                   | _ -> None)
                 (float_equal 0.0)));
       ])

let test_both_fills_same_tick_route_independently _ =
  (* Buy 5 + Sell 10 in one batch: add completes to Holding, original closes
     (dropped). *)
  let updated =
    _update ~positions:(_sibling_positions ())
      ~trades:
        [
          _trade ~symbol:"AAPL" ~side:Buy ~quantity:5.0 ~price:101.0;
          _trade ~symbol:"AAPL" ~side:Sell ~quantity:10.0 ~price:95.0;
        ]
  in
  assert_that updated
    (all_of
       [
         field (fun m -> Map.mem m "AAPL-orig") (equal_to false);
         field
           (fun m -> Map.find m "AAPL-add")
           (is_some_and
              (matching ~msg:"add must be Holding"
                 (fun (p : t) ->
                   match get_state p with
                   | Holding h -> Some h.quantity
                   | _ -> None)
                 (float_equal 5.0)));
       ])

let test_single_long_entry_fill_regression _ =
  (* Baseline behavior unchanged: one Long Entering + Buy → Holding. *)
  let positions =
    _positions_of
      [
        _entering ~id:"MSFT-1" ~symbol:"MSFT" ~side:Long ~target_quantity:8.0
          ~entry_price:200.0;
      ]
  in
  let updated =
    _update ~positions
      ~trades:[ _trade ~symbol:"MSFT" ~side:Buy ~quantity:8.0 ~price:200.5 ]
  in
  assert_that
    (Map.find updated "MSFT-1")
    (is_some_and
       (matching ~msg:"entry filled to Holding"
          (fun (p : t) ->
            match get_state p with Holding h -> Some h.quantity | _ -> None)
          (float_equal 8.0)))

let test_short_entry_fills_on_sell _ =
  (* A short enters with a Sell (sell-to-open). *)
  let positions =
    _positions_of
      [
        _entering ~id:"TSLA-1" ~symbol:"TSLA" ~side:Short ~target_quantity:4.0
          ~entry_price:250.0;
      ]
  in
  let updated =
    _update ~positions
      ~trades:[ _trade ~symbol:"TSLA" ~side:Sell ~quantity:4.0 ~price:249.0 ]
  in
  assert_that
    (Map.find updated "TSLA-1")
    (is_some_and
       (matching ~msg:"short entry filled to Holding"
          (fun (p : t) ->
            match get_state p with Holding h -> Some h.quantity | _ -> None)
          (float_equal 4.0)))

let test_side_mismatched_fill_is_ignored _ =
  (* Only a Long Entering (buy order) exists; a Sell trade matches no open
     order and must leave positions unchanged. *)
  let positions =
    _positions_of
      [
        _entering ~id:"NVDA-1" ~symbol:"NVDA" ~side:Long ~target_quantity:3.0
          ~entry_price:500.0;
      ]
  in
  let updated =
    _update ~positions
      ~trades:[ _trade ~symbol:"NVDA" ~side:Sell ~quantity:3.0 ~price:499.0 ]
  in
  assert_that
    (Map.find updated "NVDA-1")
    (is_some_and
       (matching ~msg:"entering position untouched"
          (fun (p : t) ->
            match get_state p with
            | Entering e -> Some e.filled_quantity
            | _ -> None)
          (float_equal 0.0)))

let test_same_state_siblings_route_by_order_link _ =
  (* The scale-in fold-001 crash shape: BOTH siblings exit on their shared stop
     in one tick — two same-symbol Exiting-Long positions (targets 7398 and
     2011) with two sell fills. The (symbol, state, side) heuristic routes the
     first id-ordered match ("WTW-add" < "WTW-orig") and overflows its target;
     the order_links table must route each fill to exactly its own position. *)
  let positions =
    _positions_of
      [
        _exiting ~id:"WTW-orig" ~symbol:"WTW" ~side:Long ~quantity:7398.0
          ~entry_price:20.0 ~exit_price:25.0;
        _exiting ~id:"WTW-add" ~symbol:"WTW" ~side:Long ~quantity:2011.0
          ~entry_price:24.0 ~exit_price:25.0;
      ]
  in
  let order_links = String.Table.create () in
  Hashtbl.set order_links ~key:"ord-big" ~data:"WTW-orig";
  Hashtbl.set order_links ~key:"ord-small" ~data:"WTW-add";
  let trade ~order_id ~quantity =
    { (_trade ~symbol:"WTW" ~side:Sell ~quantity ~price:25.0) with order_id }
  in
  let updated =
    Fill_router.update_positions_from_trades ~order_links ~date:_date ~positions
      ~trades:
        [
          trade ~order_id:"ord-big" ~quantity:7398.0;
          trade ~order_id:"ord-small" ~quantity:2011.0;
        ]
      ()
    |> _ok_exn ~msg:"linked routing"
  in
  (* Both exits complete: both positions close and drop from the map. *)
  assert_that (Map.is_empty updated) (equal_to true)

let suite =
  "fill_routing"
  >::: [
         "sell_fill_routes_to_exiting_sibling"
         >:: test_sell_fill_routes_to_exiting_sibling;
         "buy_fill_routes_to_entering_sibling"
         >:: test_buy_fill_routes_to_entering_sibling;
         "both_fills_same_tick_route_independently"
         >:: test_both_fills_same_tick_route_independently;
         "single_long_entry_fill_regression"
         >:: test_single_long_entry_fill_regression;
         "short_entry_fills_on_sell" >:: test_short_entry_fills_on_sell;
         "side_mismatched_fill_is_ignored"
         >:: test_side_mismatched_fill_is_ignored;
         "same_state_siblings_route_by_order_link"
         >:: test_same_state_siblings_route_by_order_link;
       ]

let () = run_test_tt_main suite
