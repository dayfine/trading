(** Live order path (issue #2984): a live tick driven through real [stop_states]
    snapshots puts a protective broker stop on every newly filled position and
    forwards a tightening that emits no transition. *)

open OUnit2
open Core
open Matchers
open Trading_strategy

let _date = Date.of_string "2024-01-05"

(* One long AAPL position, 50 shares, as it stands after this tick. *)
let _holding =
  {
    Position.id = "AAPL-1";
    symbol = "AAPL";
    side = Position.Long;
    entry_reasoning =
      Position.TechnicalSignal { indicator = "SMA30"; description = "stage 2" };
    exit_reason = None;
    state =
      Position.Holding
        {
          quantity = 50.0;
          entry_price = 150.0;
          entry_date = _date;
          risk_params =
            {
              Position.stop_loss_price = None;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
    last_updated = _date;
    portfolio_lot_ids = [];
  }

let _entry_complete =
  {
    Position.position_id = "AAPL-1";
    date = _date;
    kind =
      Position.EntryComplete
        {
          risk_params =
            {
              Position.stop_loss_price = None;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
  }

(* The one protective stop the broker should hold for [_holding]. *)
let _is_sell_stop_at level =
  all_of
    [
      field
        (fun (o : Weinstein_order_gen.suggested_order) -> o.ticker)
        (equal_to "AAPL");
      field
        (fun (o : Weinstein_order_gen.suggested_order) -> o.side)
        (equal_to Trading_base.Types.Sell);
      field
        (fun (o : Weinstein_order_gen.suggested_order) -> o.order_type)
        (equal_to (Trading_base.Types.Stop level));
      field
        (fun (o : Weinstein_order_gen.suggested_order) -> o.shares)
        (equal_to 50);
    ]

(* Entry fill. The strategy installs the initial stop when it places the entry,
   so the level is already in [stop_states] and does not move on the fill tick.
   The fill alone must put that stop at the broker. *)
let test_entry_fill_places_installed_stop _ =
  let stop_states =
    ref
      (String.Map.singleton "AAPL"
         (Weinstein_stops.Initial
            { stop_level = 140.0; reference_level = 150.0 }))
  in
  let orders =
    Weinstein_live_orders.run_tick ~stop_states (fun () ->
        {
          Weinstein_live_orders.transitions = [ _entry_complete ];
          positions_after = [ _holding ];
        })
  in
  assert_that orders (elements_are [ _is_sell_stop_at 140.0 ])

(* A trailing state the stop machine tightens on the next bar: price stalls
   near its 130 high, the MA flattens and the stage turns to Stage 3. Taken from
   the stops regression [stage3_tightening] after its first two bars. *)
let _bar ~close ~low ~high =
  {
    Types.Daily_price.date = _date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

let _step_machine state (close, low, high, ma, ma_direction, stage) =
  Weinstein_stops.update ~config:Weinstein_stops.default_config
    ~side:Trading_base.Types.Long ~state ~current_bar:(_bar ~close ~low ~high)
    ~ma_value:ma ~ma_direction ~stage

let _stage2 = Weinstein_types.Stage2 { weeks_advancing = 4; late = false }

let _pre_tightening_state =
  let start =
    Weinstein_stops.Trailing
      {
        stop_level = 110.0;
        last_correction_extreme = 115.0;
        last_trend_extreme = 130.0;
        ma_at_last_adjustment = 118.0;
        correction_count = 2;
        correction_observed_since_reset = true;
      }
  in
  List.fold
    [
      (133.0, 130.0, 135.0, 122.0, Weinstein_types.Rising, _stage2);
      (131.0, 128.0, 134.0, 123.0, Weinstein_types.Rising, _stage2);
    ]
    ~init:start
    ~f:(fun state step -> fst (_step_machine state step))

let _tightening_bar =
  ( 129.0,
    126.0,
    131.0,
    123.0,
    Weinstein_types.Flat,
    Weinstein_types.Stage3 { weeks_topping = 3 } )

(* Tightening. The live tick advances the strategy's own [stop_states] through
   the real stop machine; the machine tightens and the strategy emits no
   transition. The order path must still move the broker stop to the new
   level. *)
let test_tightening_without_transition_modifies_stop _ =
  let stop_states = ref (String.Map.singleton "AAPL" _pre_tightening_state) in
  let event = ref Weinstein_stops.No_change in
  let orders =
    Weinstein_live_orders.run_tick ~stop_states (fun () ->
        let state, ev =
          _step_machine (Map.find_exn !stop_states "AAPL") _tightening_bar
        in
        stop_states := Map.set !stop_states ~key:"AAPL" ~data:state;
        event := ev;
        {
          Weinstein_live_orders.transitions = [];
          positions_after = [ _holding ];
        })
  in
  assert_that !event
    (matching ~msg:"Expected the machine to tighten"
       (function Weinstein_stops.Entered_tightening _ -> Some () | _ -> None)
       (equal_to ()));
  assert_that orders (elements_are [ _is_sell_stop_at 126.72 ])

(* A tick where nothing moves sends nothing: no fill, no transition, the level
   unchanged. The sync must not re-send the working stop every tick. *)
let test_quiet_tick_sends_nothing _ =
  let stop_states =
    ref
      (String.Map.singleton "AAPL"
         (Weinstein_stops.Initial
            { stop_level = 140.0; reference_level = 150.0 }))
  in
  let orders =
    Weinstein_live_orders.run_tick ~stop_states (fun () ->
        {
          Weinstein_live_orders.transitions = [];
          positions_after = [ _holding ];
        })
  in
  assert_that orders is_empty

let suite =
  "weinstein_live_orders"
  >::: [
         "entry fill places the installed stop"
         >:: test_entry_fill_places_installed_stop;
         "tightening without a transition modifies the stop"
         >:: test_tightening_without_transition_modifies_stop;
         "quiet tick sends nothing" >:: test_quiet_tick_sends_nothing;
       ]

let () = run_test_tt_main suite
