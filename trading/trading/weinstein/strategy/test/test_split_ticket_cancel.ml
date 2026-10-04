(** Tests for {!Weinstein_strategy.Split_ticket_cancel} (#3075): a resting entry
    ticket whose symbol splits while it rests is cancelled, so its pre-split
    trigger never fills on post-split prices.

    Pinned contracts:
    - flag off: no transitions, the portfolio handed back unchanged, no bar read
      (R1, bit-identical);
    - flag on, 2:1 split on the as-of bar: the resting ticket gets a
      [CancelEntry] with reason [entry_ticket_split_while_resting] and leaves
      the portfolio view; a ticket on a non-split symbol is untouched;
    - the cancel retires the resting buy-stop in the simulator's order manager,
      so the stale trigger cannot fill;
    - partially filled entries and held positions are never cancelled;
    - the cancelled symbol's frozen [E] is released, so it re-pins fresh;
    - end to end through [on_market_close]: the config flag arms the cancel (one
      split cancel, no second clock-TTL cancel for the same ticket), and flag
      off emits no split cancel.

    The specimen shape is AAON-wein-951 on the 26y investor run: a buy-stop
    resting across a split and filling on post-split prices. *)

open OUnit2
open Core
open Matchers
module Split_ticket_cancel = Weinstein_strategy.Split_ticket_cancel
module Entry_freeze = Weinstein_strategy.Entry_freeze
module Bar_reader = Weinstein_strategy.Bar_reader
module Position = Trading_strategy.Position
module Portfolio_view = Trading_strategy.Portfolio_view
module Cancel_handler = Trading_simulation.Cancel_handler
module Orders = Trading_orders

let _date = Date.of_string
let _split_symbol = "SPLT"
let _flat_symbol = "KEEP"
let _split_id = "SPLT-wein-1"
let _flat_id = "KEEP-wein-1"
let _placed = _date "2024-01-05"
let _pre_split_day = _date "2024-03-04"
let _split_day = _date "2024-03-05"

(* The decision-time trigger: a buy-stop at 83.42, the AAON specimen's level.
   After a 2:1 split the stock trades near 50, so the unscaled trigger sits at
   about 167 on the decision's basis. *)
let _trigger = 83.42
let _quantity = 100.0

let _bar ~date ~close ~adjusted_close =
  Types.Daily_price.
    {
      date;
      open_price = close;
      high_price = close;
      low_price = close;
      close_price = close;
      adjusted_close;
      volume = 1_000_000;
      active_through = None;
    }

(* 2:1 split on [_split_day]: the raw close halves, the adjusted close is
   continuous, so the detector reads factor 2. *)
let _split_bars =
  [
    _bar ~date:_pre_split_day ~close:100.0 ~adjusted_close:50.0;
    _bar ~date:_split_day ~close:50.0 ~adjusted_close:50.0;
  ]

(* Ordinary drift, no split. *)
let _flat_bars =
  [
    _bar ~date:_pre_split_day ~close:80.0 ~adjusted_close:80.0;
    _bar ~date:_split_day ~close:80.5 ~adjusted_close:80.5;
  ]

let _bar_reader =
  Bar_reader.of_in_memory_bars
    [ (_split_symbol, _split_bars); (_flat_symbol, _flat_bars) ]

let _position ~id ~symbol ~state : Position.t =
  {
    id;
    symbol;
    side = Position.Long;
    entry_reasoning = Position.ManualDecision { description = "test fixture" };
    exit_reason = None;
    state;
    last_updated = _placed;
    portfolio_lot_ids = [];
  }

let _entering ?(filled_quantity = 0.0) () : Position.position_state =
  Entering
    {
      target_quantity = _quantity;
      entry_price = _trigger;
      filled_quantity;
      created_date = _placed;
    }

let _holding : Position.position_state =
  Holding
    {
      quantity = _quantity;
      entry_price = _trigger;
      entry_date = _placed;
      risk_params =
        {
          stop_loss_price = None;
          take_profit_price = None;
          max_hold_days = None;
        };
    }

(* Two resting tickets: one on the splitting symbol, one on a flat symbol. *)
let _positions ?(split_state = _entering ()) () =
  String.Map.of_alist_exn
    [
      ( _split_id,
        _position ~id:_split_id ~symbol:_split_symbol ~state:split_state );
      ( _flat_id,
        _position ~id:_flat_id ~symbol:_flat_symbol ~state:(_entering ()) );
    ]

let _portfolio ?split_state () : Portfolio_view.t =
  { cash = 1_000_000.0; positions = _positions ?split_state () }

let _run ?(enabled = true) ?(pending_entry_e = Entry_freeze.create ())
    ?(current_date = _split_day) portfolio =
  Split_ticket_cancel.run ~enabled ~pending_entry_e ~bar_reader:_bar_reader
    ~portfolio ~current_date

let _is_split_cancel =
  all_of
    [
      field
        (fun (t : Position.transition) -> t.position_id)
        (equal_to _split_id);
      field (fun (t : Position.transition) -> t.date) (equal_to _split_day);
      field
        (fun (t : Position.transition) -> t.kind)
        (equal_to
           (Position.CancelEntry { reason = Split_ticket_cancel.cancel_reason }));
    ]

(** Flag on, split today: exactly the splitting symbol's ticket is cancelled
    with the split reason, and it leaves the portfolio view handed to the rest
    of the tick. The flat symbol's ticket is untouched. *)
let test_split_cancels_resting_ticket _ =
  let transitions, portfolio = _run (_portfolio ()) in
  assert_that
    (transitions, Map.keys portfolio.positions)
    (all_of
       [
         field fst (elements_are [ _is_split_cancel ]);
         field snd (elements_are [ equal_to _flat_id ]);
       ])

(** The reason token is pinned as a literal: the trade audit persists it
    verbatim, and a [trade_audit.sexp] reader groups ticket deaths by it. *)
let test_cancel_reason_literal _ =
  assert_that Split_ticket_cancel.cancel_reason
    (equal_to "entry_ticket_split_while_resting")

(** {b R1.} Flag off: no transition and the very same portfolio value back, so
    the default path is bit-identical to the pre-#3075 strategy. *)
let test_flag_off_is_noop _ =
  let portfolio = _portfolio () in
  let transitions, after = _run ~enabled:false portfolio in
  assert_that
    (transitions, phys_equal after portfolio)
    (all_of [ field fst is_empty; field snd (equal_to true) ])

(** Flag on, but the as-of bar is not a split day (the series has only one bar
    up to it): nothing is cancelled and the portfolio comes back unchanged. *)
let test_no_split_day_is_noop _ =
  let portfolio = _portfolio () in
  let transitions, after = _run ~current_date:_pre_split_day portfolio in
  assert_that
    (transitions, phys_equal after portfolio)
    (all_of [ field fst is_empty; field snd (equal_to true) ])

(* A manager holding the resting buy-stop behind each ticket. *)
let _order_manager () =
  let manager = Orders.Manager.create () in
  let make id symbol =
    let params : Orders.Create_order.order_params =
      {
        symbol;
        side = Trading_base.Types.Buy;
        order_type = Trading_base.Types.Stop _trigger;
        quantity = _quantity;
        time_in_force = Orders.Types.GTC;
      }
    in
    match Orders.Create_order.create_order ~id params with
    | Ok o -> o
    | Error e -> assert_failure ("order setup failed: " ^ Status.show e)
  in
  let (_ : Status.status list) =
    Orders.Manager.submit_orders manager
      [ make "split-order" _split_symbol; make "flat-order" _flat_symbol ]
  in
  manager

(** The cancel is real: fed to the simulator's
    [Cancel_handler.cancel_resting_entry_orders] (the step that runs before the
    day's transitions are applied), it retires the splitting symbol's resting
    buy-stop, so the stale 83.42 trigger can never fill on post-split prices.
    The flat symbol's order keeps resting. *)
let test_cancel_retires_resting_order _ =
  let portfolio = _portfolio () in
  let transitions, _ = _run portfolio in
  let order_manager = _order_manager () in
  let cancelled =
    Cancel_handler.cancel_resting_entry_orders ~order_manager
      ~positions:portfolio.positions ~transitions
  in
  let active =
    Orders.Manager.list_orders ~filter:ActiveOnly order_manager
    |> List.map ~f:(fun (o : Orders.Types.order) -> o.id)
  in
  assert_that (cancelled, active)
    (all_of
       [
         field fst (elements_are [ equal_to "split-order" ]);
         field snd (elements_are [ equal_to "flat-order" ]);
       ])

(** Only wholly unfilled [Entering] tickets are cancelled: a partially filled
    entry (its shares are booked) and a held position are skipped even when
    their symbol split. *)
let test_partial_and_held_are_skipped _ =
  let always_split ~symbol:_ = Some 2.0 in
  let cancels state =
    Split_ticket_cancel.cancellations
      ~positions:(_positions ~split_state:state ())
      ~split_factor:always_split ~current_date:_split_day
    |> List.map ~f:(fun (t : Position.transition) -> t.position_id)
  in
  assert_that
    (cancels (_entering ~filled_quantity:40.0 ()), cancels _holding)
    (all_of
       [
         field fst (elements_are [ equal_to _flat_id ]);
         field snd (elements_are [ equal_to _flat_id ]);
       ])

(** Minimal candidate carrying only the fields the freeze reads. *)
let _candidate ~ticker ~entry : Screener.scored_candidate =
  let base =
    Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
      ~bars:[] ~benchmark_bars:[] ~prior_stage:None ~as_of_date:_split_day
  in
  {
    ticker;
    analysis = base;
    side = Trading_base.Types.Long;
    sector =
      {
        sector_name = "Tech";
        rating = Screener.Neutral;
        stage = base.stage.stage;
      };
    grade = Weinstein_types.A;
    score = 70;
    suggested_entry = entry;
    suggested_stop = entry *. 0.95;
    risk_pct = 0.05;
    swing_target = None;
    rationale = [];
  }

let _pin_apply pending candidates =
  Entry_freeze.apply ~enabled:true ~pending ~held_set:String.Set.empty
    ~candidates

(** The cancel releases the symbol's frozen [E]: its next qualification pins the
    fresh, post-split level (41.7) instead of reusing the pre-split 83.42.
    Without the release the pin survives the cancelling tick (the symbol is held
    until the transition is applied) and the re-issued ticket would carry the
    stale trigger again. *)
let test_cancel_releases_frozen_entry _ =
  let pending = Entry_freeze.create () in
  let _wk1 =
    _pin_apply pending [ _candidate ~ticker:_split_symbol ~entry:_trigger ]
  in
  let _cancels, _view = _run ~pending_entry_e:pending (_portfolio ()) in
  let later =
    _pin_apply pending [ _candidate ~ticker:_split_symbol ~entry:41.7 ]
  in
  assert_that
    (List.map later ~f:(fun (c : Screener.scored_candidate) ->
         c.suggested_entry))
    (elements_are [ float_equal 41.7 ])

(* ------------------------------------------------------------------ *)
(* End-to-end: the CONFIG flag arms the cancel through the real        *)
(* [on_market_close], not just the direct [Split_ticket_cancel.run].   *)
(* ------------------------------------------------------------------ *)

module FL = Portfolio_risk.Force_liquidation

let _index_symbol = "GSPCX"

(* A Friday, 16 weeks after the ticket was placed on [_placed]. *)
let _e2e_day = _date "2024-04-26"
let _e2e_bar_count = 260

(* Long in-memory series ending on [_e2e_day]: the index rises (so the tick
   runs its screening path), and [_split_symbol]'s adjusted close is continuous
   while its raw close halves on the last bar, a 2:1 split on the as-of day. *)
let _e2e_reader =
  let start_date = Date.add_days _e2e_day (-(_e2e_bar_count - 1)) in
  let series ~split =
    List.init _e2e_bar_count ~f:(fun i ->
        let date = Date.add_days start_date i in
        let adjusted_close = 50.0 +. (Float.of_int i *. 0.1) in
        let raw_factor =
          if split && Date.( < ) date _e2e_day then 2.0 else 1.0
        in
        _bar ~date ~close:(adjusted_close *. raw_factor) ~adjusted_close)
  in
  Bar_reader.of_in_memory_bars
    [
      (_index_symbol, series ~split:false); (_split_symbol, series ~split:true);
    ]

let _e2e_get_price symbol =
  List.last (Bar_reader.daily_bars_for _e2e_reader ~symbol ~as_of:_e2e_day)

(* The clock backstop is armed at 8 weeks, so the 16-week-old ticket would be
   retired by [Entry_ticket_ttl] if it were still in the view that pass sees. *)
let _e2e_config ~cancel_on_split =
  {
    (Weinstein_strategy.default_config ~universe:[ _split_symbol ]
       ~index_symbol:_index_symbol)
    with
    cancel_resting_entry_on_split = cancel_on_split;
    entry_order_max_rest_weeks = 8;
  }

(* Each [CancelEntry] the tick emits, tagged by whether it is the split cancel. *)
let _cancel_tags transitions =
  List.filter_map transitions ~f:(fun (t : Position.transition) ->
      match t.kind with
      | Position.CancelEntry { reason } ->
          let tag =
            if String.equal reason Split_ticket_cancel.cancel_reason then
              "split"
            else "other"
          in
          Some (t.position_id, tag)
      | _ -> None)

(** Drive one real tick through [Internal_for_test.on_market_close] (the path
    [make] wires) with one resting ticket on the splitting symbol, and return
    the tagged cancels it emitted. *)
let _drive ~cancel_on_split =
  Weinstein_strategy.Internal_for_test.on_market_close ~fold_start_date:None
    ~config:(_e2e_config ~cancel_on_split)
    ~ad_bars:[] ~stop_states:(ref String.Map.empty)
    ~last_stop_out_dates:(Hashtbl.create (module String))
    ~prior_macro:(ref Weinstein_types.Neutral)
    ~prior_macro_result:(ref None)
    ~prior_decline_character:(ref Decline_character.Not_declining)
    ~peak_tracker:(FL.Peak_tracker.create ())
    ~bar_reader:_e2e_reader
    ~prior_stages:(Hashtbl.create (module String))
    ~prior_stage_ma_values:(Hashtbl.create (module String))
    ~sector_prior_stages:(Hashtbl.create (module String))
    ~ticker_sectors:(Hashtbl.create (module String))
    ~stage3_streaks:(Hashtbl.create (module String))
    ~laggard_streaks:(Hashtbl.create (module String))
    ~audit_recorder:Weinstein_strategy.Audit_recorder.noop
    ~get_price:_e2e_get_price
    ~get_indicator:(fun _ _ _ _ -> None)
    ~portfolio:
      {
        cash = 1_000_000.0;
        positions =
          String.Map.singleton _split_id
            (_position ~id:_split_id ~symbol:_split_symbol ~state:(_entering ()));
      }
  |> Result.map ~f:(fun (out : Trading_strategy.Strategy_interface.output) ->
      _cancel_tags out.transitions)

(** {b End to end.} The config flag, not just the module's [~enabled] argument,
    arms the cancel in [on_market_close]:
    - flag on: exactly one cancel for the ticket, the split one. The clock
      backstop would also retire this ticket, so the single cancel also pins
      that the cancelled ticket is gone from the view [Entry_ticket_ttl] sees
      (no second [CancelEntry] for the same id);
    - flag off (R1): no split cancel; the clock backstop retires the ticket as
      it did before #3075. *)
let test_config_arms_split_cancel_end_to_end _ =
  assert_that
    (_drive ~cancel_on_split:true, _drive ~cancel_on_split:false)
    (all_of
       [
         field fst
           (is_ok_and_holds (elements_are [ equal_to (_split_id, "split") ]));
         field snd
           (is_ok_and_holds (elements_are [ equal_to (_split_id, "other") ]));
       ])

let suite =
  "split_ticket_cancel"
  >::: [
         "split cancels resting ticket" >:: test_split_cancels_resting_ticket;
         "cancel reason literal" >:: test_cancel_reason_literal;
         "flag off is a no-op" >:: test_flag_off_is_noop;
         "no split day is a no-op" >:: test_no_split_day_is_noop;
         "cancel retires resting order" >:: test_cancel_retires_resting_order;
         "partial and held are skipped" >:: test_partial_and_held_are_skipped;
         "cancel releases frozen entry" >:: test_cancel_releases_frozen_entry;
         "config arms split cancel end to end"
         >:: test_config_arms_split_cancel_end_to_end;
       ]

let () = run_test_tt_main suite
