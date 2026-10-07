(** Issue #3173, simulator side: {!Trading_simulation.Split_handler} drops a
    detected split that {!Split_dividend_guard} identifies as a vendor cash
    dividend, so a held position gains no phantom shares; with no guard (the
    default, flag off) every detected split is applied as before. *)

open OUnit2
open Core
open Matchers
module Split_handler = Trading_simulation.Split_handler
module Adapter = Trading_simulation_data.Market_data_adapter
module CA = Corporate_actions
module Position = Trading_strategy.Position

let _bar date ~close ~adjusted : Types.Daily_price.t =
  {
    date = Date.of_string date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = adjusted;
    volume = 1_000_000;
    active_through = None;
  }

(* A two-bar adapter for one symbol: [curr] on its date, [prev] before it. *)
let _adapter ~prev ~(curr : Types.Daily_price.t) =
  Adapter.create_with_callbacks
    ~get_price:(fun ~symbol:_ ~date ->
      Option.some_if (Date.equal date curr.date) curr)
    ~get_previous_bar:(fun ~symbol:_ ~date ->
      Option.some_if (Date.equal date curr.date) prev)

(* TDG 2013-07-11: $22.00 special on 160.80, read by the detector as 22/19. *)
let _tdg_prev = _bar "2013-07-10" ~close:160.80 ~adjusted:138.80
let _tdg_curr = _bar "2013-07-11" ~close:139.50 ~adjusted:139.50

let _guard ~dividends ~splits =
  Split_dividend_guard.create
    ~load_dividends:(fun _ -> Ok dividends)
    ~load_splits:(fun _ -> Ok splits)
    ()

let _tdg_guard () =
  _guard
    ~dividends:
      [
        {
          CA.ex_date = Date.of_string "2013-07-11";
          unadjusted_amount = Some 22.0;
          adjusted_amount = 22.0;
        };
      ]
    ~splits:[]

let _detect ?split_guard ~symbol ~prev ~curr () =
  Split_handler.detect_for_symbol ?split_guard ~adapter:(_adapter ~prev ~curr)
    ~date:curr.Types.Daily_price.date ~symbol ()

(* Flag off: no guard, the pre-#3173 behaviour (the phantom 22/19 split). *)
let test_no_guard_applies_detected_split _ =
  assert_that
    (_detect ~symbol:"TDG" ~prev:_tdg_prev ~curr:_tdg_curr ())
    (is_some_and
       (field
          (fun (e : Trading_portfolio.Split_event.t) -> e.factor)
          (float_equal (22.0 /. 19.0))))

let test_guard_drops_dividend_split _ =
  assert_that
    (_detect ~split_guard:(_tdg_guard ()) ~symbol:"TDG" ~prev:_tdg_prev
       ~curr:_tdg_curr ())
    is_none

let test_guard_keeps_vendor_split _ =
  let guard =
    _guard ~dividends:[]
      ~splits:[ { CA.date = Date.of_string "2020-08-31"; factor = 4.0 } ]
  in
  assert_that
    (_detect ~split_guard:guard ~symbol:"AAPL"
       ~prev:(_bar "2020-08-28" ~close:499.23 ~adjusted:124.81)
       ~curr:(_bar "2020-08-31" ~close:129.04 ~adjusted:129.04)
       ())
    (is_some_and
       (field
          (fun (e : Trading_portfolio.Split_event.t) -> e.factor)
          (float_equal 4.0)))

(* A TDG long of 100 shares bought at the 2013-07-10 close, held in both the
   broker portfolio and the strategy-side position map: the state the daily
   split step ({!Split_handler.detect_and_apply}) scales. *)
let _tdg_shares = 100.0

let _tdg_held_portfolio () =
  let buy =
    {
      Trading_base.Types.id = "t1";
      order_id = "o1";
      symbol = "TDG";
      side = Buy;
      quantity = _tdg_shares;
      price = _tdg_prev.close_price;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  match
    Trading_portfolio.Portfolio.apply_trades
      (Trading_portfolio.Portfolio.create ~initial_cash:100_000.0 ())
      [ buy ]
  with
  | Ok p -> p
  | Error err -> assert_failure ("TDG portfolio: " ^ Status.show err)

let _tdg_held_positions () : Position.t String.Map.t =
  String.Map.singleton "tdg-1"
    {
      Position.id = "tdg-1";
      symbol = "TDG";
      side = Position.Long;
      entry_reasoning = Position.ManualDecision { description = "test fixture" };
      exit_reason = None;
      state =
        Position.Holding
          {
            quantity = _tdg_shares;
            entry_price = _tdg_prev.close_price;
            entry_date = _tdg_prev.date;
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          };
      last_updated = _tdg_prev.date;
      portfolio_lot_ids = [];
    }

let _detect_and_apply ?split_guard () =
  Split_handler.detect_and_apply ?split_guard
    ~adapter:(_adapter ~prev:_tdg_prev ~curr:_tdg_curr)
    ~date:_tdg_curr.date ~portfolio:(_tdg_held_portfolio ())
    ~positions:(_tdg_held_positions ()) ()

let _lot_quantity portfolio =
  Option.map
    (Trading_portfolio.Portfolio.get_position portfolio "TDG")
    ~f:Trading_portfolio.Calculations.position_quantity

let _holding_quantity positions =
  Option.bind (Map.find positions "tdg-1") ~f:(fun (p : Position.t) ->
      match p.state with
      | Position.Holding { quantity; _ } -> Some quantity
      | _ -> None)

(* Both views of the held TDG position after the daily split step: the broker
   lot quantity, the strategy-side Holding quantity and the event count. *)
let _held_after ~shares ~events =
  all_of
    [
      field
        (fun (portfolio, _, _) -> _lot_quantity portfolio)
        (is_some_and (float_equal shares));
      field
        (fun (_, positions, _) -> _holding_quantity positions)
        (is_some_and (float_equal shares));
      field (fun (_, _, evs) -> List.length evs) (equal_to events);
    ]

(* Flag off: the daily split step scales both views by the phantom 22/19. *)
let test_detect_and_apply_no_guard_scales_held _ =
  assert_that (_detect_and_apply ())
    (_held_after ~shares:(_tdg_shares *. 22.0 /. 19.0) ~events:1)

(* Guard on: the daily split step forwards the guard, so the held TDG position
   keeps 100 shares in both views and no event is emitted. *)
let test_detect_and_apply_guard_keeps_held _ =
  assert_that
    (_detect_and_apply ~split_guard:(_tdg_guard ()) ())
    (_held_after ~shares:_tdg_shares ~events:0)

let suite =
  "split_handler_dividend_guard"
  >::: [
         "no guard applies detected split"
         >:: test_no_guard_applies_detected_split;
         "guard drops dividend split" >:: test_guard_drops_dividend_split;
         "guard keeps vendor split" >:: test_guard_keeps_vendor_split;
         "detect_and_apply no guard scales held position"
         >:: test_detect_and_apply_no_guard_scales_held;
         "detect_and_apply guard keeps held position"
         >:: test_detect_and_apply_guard_keeps_held;
       ]

let () = run_test_tt_main suite
