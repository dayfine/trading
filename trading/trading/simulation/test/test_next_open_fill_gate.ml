(** Unit tests for {!Next_open_fill_gate.make}'s routing predicate.

    The gate decides, per resting Market order, whether that order must wait for
    the next fresh bar. It routes by (symbol, position state, side) rather than
    by state alone, and the case that distinguishes the two is a scale-in
    sibling pair: an [Entering] add and an [Exiting] original on ONE symbol,
    each with its own resting order of the opposite side. State-only routing
    would treat both orders as belonging to whichever state matched first, so
    arming one class would silently defer the other class's order too — a
    different fill date and price in any armed run.

    These tests pin the side conjunct directly: with exactly one class armed and
    no fresh bar, the armed class's order is held while the sibling's order
    still passes. Dropping [expected_side] from [_is_routing_match] fails both
    directions. Mirrors the analogous {!Fill_router} guard pinned in
    [test_fill_routing.ml]. *)

open Core
open OUnit2
open Matchers
open Trading_strategy.Position
module Gate = Trading_simulation.Next_open_fill_gate

let _date = Date.of_string "2024-03-08"
let _symbol = "AAPL"

let _ok_exn ~msg = function
  | Ok v -> v
  | Error err -> assert_failure (msg ^ ": " ^ Status.show err)

let _entering ~id ~side ~target_quantity ~entry_price : t =
  create_entering
    {
      position_id = id;
      date = _date;
      kind =
        CreateEntering
          {
            symbol = _symbol;
            side;
            target_quantity;
            entry_price;
            reasoning = ManualDecision { description = "gate test" };
          };
    }
  |> _ok_exn ~msg:"create_entering"

let _apply pos kind ~msg =
  apply_transition pos { position_id = pos.id; date = _date; kind }
  |> _ok_exn ~msg

let _exiting ~id ~side ~quantity ~entry_price ~exit_price : t =
  let pos = _entering ~id ~side ~target_quantity:quantity ~entry_price in
  let pos =
    _apply pos
      (EntryFill { filled_quantity = quantity; fill_price = entry_price })
      ~msg:"entry fill"
  in
  let pos =
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
  in
  _apply pos
    (TriggerExit
       {
         exit_reason = SignalReversal { description = "gate test exit" };
         exit_price;
       })
    ~msg:"trigger exit"

(* The scale-in shape: the original Long is [Exiting] (resting Sell) while an
   add on the SAME symbol is still [Entering] (resting Buy). *)
let _sibling_positions () =
  String.Map.of_alist_exn
    (List.map
       [
         _exiting ~id:"AAPL-orig" ~side:Long ~quantity:10.0 ~entry_price:100.0
           ~exit_price:95.0;
         _entering ~id:"AAPL-add" ~side:Long ~target_quantity:5.0
           ~entry_price:101.0;
       ]
       ~f:(fun p -> (p.id, p)))

let _market_order ~id ~(side : Trading_base.Types.side) ~quantity :
    Trading_orders.Types.order =
  {
    id;
    symbol = _symbol;
    side;
    order_type = Trading_base.Types.Market;
    quantity;
    time_in_force = GTC;
    status = Pending;
    filled_quantity = 0.0;
    avg_fill_price = None;
    created_at = Time_ns_unix.now ();
    updated_at = Time_ns_unix.now ();
  }

(* The exit's resting order (Sell, closing the Long original) and the add's
   resting order (Buy, opening the Long add). *)
let _sell_exit_order = _market_order ~id:"ord-exit" ~side:Sell ~quantity:10.0
let _buy_entry_order = _market_order ~id:"ord-entry" ~side:Buy ~quantity:5.0

let _fresh_bar : Trading_engine.Types.price_bar =
  {
    symbol = _symbol;
    open_price = 96.0;
    high_price = 99.0;
    low_price = 95.0;
    close_price = 98.0;
  }

(* [true] = the order may fill on this step; [false] = held for the next fresh
   bar. Labelled so a failure names which order moved. *)
let _decisions ~defer_entries ~defer_exits ~today_bars =
  let can_fill =
    Gate.make ~defer_entries ~defer_exits ~positions:(_sibling_positions ())
      ~today_bars
  in
  [
    ("sell/exit", can_fill _sell_exit_order);
    ("buy/entry", can_fill _buy_entry_order);
  ]

(* ------- Tests ------- *)

let test_exits_armed_defers_only_the_sell _ =
  (* Exits armed, entries not, no fresh bar: the Sell waits for the next fresh
     bar; the sibling add's Buy is in an unarmed class and still fills. Without
     the side conjunct the Buy also matches the Exiting original by symbol +
     state and would be deferred. *)
  assert_that
    (_decisions ~defer_entries:false ~defer_exits:true ~today_bars:[])
    (equal_to [ ("sell/exit", false); ("buy/entry", true) ])

let test_entries_armed_defers_only_the_buy _ =
  (* The mirror: entries armed, exits not. The Buy waits; the Sell still fills.
     Without the side conjunct the Sell matches the Entering add and would be
     deferred. *)
  assert_that
    (_decisions ~defer_entries:true ~defer_exits:false ~today_bars:[])
    (equal_to [ ("sell/exit", true); ("buy/entry", false) ])

let test_fresh_bar_lets_both_siblings_fill _ =
  (* Control: deferral is driven by bar freshness, not by arming alone. With a
     fresh bar for the symbol, both orders fill even with both classes armed. *)
  assert_that
    (_decisions ~defer_entries:true ~defer_exits:true ~today_bars:[ _fresh_bar ])
    (equal_to [ ("sell/exit", true); ("buy/entry", true) ])

let suite =
  "next_open_fill_gate"
  >::: [
         "exits armed defers only the sibling Sell"
         >:: test_exits_armed_defers_only_the_sell;
         "entries armed defers only the sibling Buy"
         >:: test_entries_armed_defers_only_the_buy;
         "a fresh bar lets both siblings fill"
         >:: test_fresh_bar_lets_both_siblings_fill;
       ]

let () = run_test_tt_main suite
