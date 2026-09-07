(** Unit tests for {!Trading_simulation.Delisted_exit_runner} — the first-class
    exit fired when a held symbol's [active_through] delisting marker passes.

    The selection policy is the whole point of the module (the mechanics are
    shared with {!Trading_simulation.Stale_exit_runner} via
    {!Trading_simulation.Forced_exit}), so these tests pin exactly when it fires
    and at what price:

    - marker passed → exit at the marker day's own close, position gone;
    - marker [None] → nothing happens at all (the R1 no-op that keeps every
      golden bit-identical today, since NO warehouse populates the marker);
    - marker today or in the future → nothing happens (the series is still
      live);
    - no bars today → nothing happens (weekend / holiday, matching
      {!Stale_exit_runner});
    - marker passed but the symbol's bars are unreadable → nothing happens, so
      the position falls through to the stale safety net that flags it;
    - marker day's own bar missing but an earlier bar present → the fallback
      branch realises at that earlier close;
    - marker passed but no matching Holding [Position.t] → the trade lands and
      no transition is reported (the {!Trading_simulation.Forced_exit} claim
      that an observer never hears about an exit that did not happen).

    Ordering against the stale runner, and the ["delisted"] label reaching
    [trades.csv], are pinned one layer up in
    [trading/trading/backtest/test/test_stale_exit_observability.ml].

    Authority: [dev/plans/delisting-data-fix-2026-09-06.md] §"Principle:
    fallbacks are quality flags, not mechanisms". *)

open OUnit2
open Core
open Matchers
module Delisted_exit_runner = Trading_simulation.Delisted_exit_runner
module Position = Trading_strategy.Position
module Portfolio = Trading_portfolio.Portfolio

let _date s = Date.of_string s
let _symbol = "DEAD"
let _live = "KEEP"
let _entry_price = 100.0
let _marker_close = 120.0
let _quantity = 10.0
let _position_id = "DEAD-1"
let _marker = _date "2024-01-10"
let _today = _date "2024-01-15"
let _commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

let _make_bar ~date ~close =
  Types.Daily_price.
    {
      date;
      open_price = close;
      high_price = close;
      low_price = close;
      close_price = close;
      adjusted_close = close;
      volume = 1_000_000;
      active_through = None;
    }

(* [_symbol]'s series ends on the marker day; [_live] still prints. *)
let _bar_table =
  [
    ( _symbol,
      [
        _make_bar ~date:(_date "2024-01-02") ~close:_entry_price;
        _make_bar ~date:_marker ~close:_marker_close;
      ] );
    (_live, [ _make_bar ~date:_today ~close:50.0 ]);
  ]

let _adapter ?(table = _bar_table) () =
  let bars ~symbol =
    List.Assoc.find table symbol ~equal:String.equal |> Option.value ~default:[]
  in
  let get_price ~symbol ~date =
    bars ~symbol
    |> List.find ~f:(fun (b : Types.Daily_price.t) -> Date.equal b.date date)
  in
  let get_previous_bar ~symbol ~date =
    bars ~symbol
    |> List.filter ~f:(fun (b : Types.Daily_price.t) -> Date.( < ) b.date date)
    |> List.last
  in
  Trading_simulation_data.Market_data_adapter.create_with_callbacks ~get_price
    ~get_previous_bar

let _today_bars : Trading_engine.Types.price_bar list =
  [
    {
      symbol = _live;
      open_price = 50.0;
      high_price = 50.0;
      low_price = 50.0;
      close_price = 50.0;
    };
  ]

(* A portfolio holding [_quantity] of [_symbol], bought at [_entry_price]. *)
let _portfolio_with_position () =
  let trade : Trading_base.Types.trade =
    {
      id = "entry";
      order_id = "entry-order";
      symbol = _symbol;
      side = Trading_base.Types.Buy;
      quantity = _quantity;
      price = _entry_price;
      commission = 0.0;
      timestamp = Time_ns_unix.epoch;
    }
  in
  match
    Portfolio.apply_single_trade
      (Portfolio.create ~initial_cash:100_000.0 ())
      trade
  with
  | Ok p -> p
  | Error e -> assert_failure ("portfolio setup failed: " ^ Status.show e)

(* The matching Holding [Position.t], so the runner has a strategy position to
   drive to Closed and transitions to report. *)
let _positions () =
  String.Map.singleton _position_id
    {
      Position.id = _position_id;
      symbol = _symbol;
      side = Position.Long;
      entry_reasoning = Position.ManualDecision { description = "test fixture" };
      exit_reason = None;
      state =
        Position.Holding
          {
            quantity = _quantity;
            entry_price = _entry_price;
            entry_date = _date "2024-01-02";
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          };
      last_updated = _date "2024-01-02";
      portfolio_lot_ids = [];
    }

let _run ?(table = _bar_table) ?(today_bars = _today_bars) ?positions
    ~active_through_for () =
  let positions = Option.value positions ~default:(_positions ()) in
  Delisted_exit_runner.tick ~adapter:(_adapter ~table ()) ~active_through_for
    ~commission:_commission ~date:_today ~today_bars
    ~portfolio:(_portfolio_with_position ())
    ~positions ()

let _always marker _symbol = marker
let _trades (_, _, trades, _) = trades
let _no_marker : string -> Date.t option = _always None

(** Marker passed: exactly one Sell at the marker day's OWN close (not the entry
    price, not an average), tagged with the runner's own order id — no engine
    order can produce it. *)
let test_passed_marker_exits_at_the_last_real_close _ =
  assert_that
    (_trades (_run ~active_through_for:(_always (Some _marker)) ()))
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_base.Types.trade) -> t.symbol)
               (equal_to _symbol);
             field
               (fun (t : Trading_base.Types.trade) -> t.side)
               (equal_to (Trading_base.Types.Sell : Trading_base.Types.side));
             field
               (fun (t : Trading_base.Types.trade) -> t.quantity)
               (float_equal _quantity);
             field
               (fun (t : Trading_base.Types.trade) -> t.price)
               (float_equal _marker_close);
             field
               (fun (t : Trading_base.Types.trade) ->
                 String.is_prefix t.order_id
                   ~prefix:(_symbol ^ "-delisted-exit-order-"))
               (equal_to true);
           ];
       ])

(** The exit is reported as a ["delisted"] [StrategySignal] naming the marker —
    the value that reaches [trades.csv]'s [exit_trigger] column via
    [Stop_log.record_transitions]. Read off the returned transitions, since the
    Closed position is dropped from the map in the same fold. *)
let test_exit_transition_carries_the_delisted_label _ =
  let _, _, _, transitions =
    _run ~active_through_for:(_always (Some _marker)) ()
  in
  assert_that
    (List.filter_map transitions ~f:(fun (t : Position.transition) ->
         match t.kind with
         | Position.TriggerExit { exit_reason; _ } -> Some exit_reason
         | _ -> None))
    (elements_are
       [
         equal_to
           (Position.StrategySignal
              { label = "delisted"; detail = Some "active_through=2024-01-10" });
       ])

(** ...and the strategy position is driven to Closed and dropped, so the
    strategy never sees a holding in a security that no longer exists. *)
let test_passed_marker_drops_the_strategy_position _ =
  let _, positions, _, _ =
    _run ~active_through_for:(_always (Some _marker)) ()
  in
  assert_that (Map.find positions _position_id) is_none

(** ...and the broker position is flat: cash freed, nothing carried at a stale
    mark. *)
let test_passed_marker_flattens_the_broker_position _ =
  let portfolio, _, _, _ =
    _run ~active_through_for:(_always (Some _marker)) ()
  in
  assert_that
    (List.find portfolio.Portfolio.positions ~f:(fun p ->
         String.equal p.symbol _symbol))
    is_none

(** {b The R1 no-op.} No marker → byte-identical to a run without this module:
    no trade, no transition, the position untouched. This is EVERY run against
    EVERY warehouse built to date, because none populates [active_through]. *)
let test_absent_marker_is_a_no_op _ =
  let portfolio, positions, trades, transitions =
    _run ~active_through_for:_no_marker ()
  in
  assert_that
    (List.length trades, List.length transitions, Map.length positions)
    (equal_to (0, 0, 1));
  assert_that
    (List.count portfolio.Portfolio.positions ~f:(fun p ->
         String.equal p.symbol _symbol))
    (equal_to 1)

(** A marker dated TODAY does not fire: the comparison is strict, so the marker
    day's own bar is still tradeable when it arrives. *)
let test_marker_dated_today_does_not_exit _ =
  assert_that
    (_trades (_run ~active_through_for:(_always (Some _today)) ()))
    (size_is 0)

(** A marker in the future does not fire either — the series is still live. *)
let test_future_marker_does_not_exit _ =
  assert_that
    (_trades
       (_run ~active_through_for:(_always (Some (_date "2024-02-01"))) ()))
    (size_is 0)

(** No bars anywhere today (weekend / holiday) → no exit, matching
    {!Stale_exit_runner}'s false-positive guard. *)
let test_no_bars_today_is_a_no_op _ =
  assert_that
    (_trades
       (_run ~today_bars:[] ~active_through_for:(_always (Some _marker)) ()))
    (size_is 0)

(** Marker passed but the symbol has NO readable bars: the runner declines to
    invent a price and leaves the position alone, so it falls through to
    {!Stale_exit_runner} and is flagged as the warehouse defect it is. *)
let test_unpriceable_symbol_is_left_for_the_stale_net _ =
  assert_that
    (_trades
       (_run
          ~table:[ (_live, [ _make_bar ~date:_today ~close:50.0 ]) ]
          ~active_through_for:(_always (Some _marker)) ()))
    (size_is 0)

(** The second price-resolution branch: the marker day's own bar is missing from
    the store, so the runner falls back to [get_previous_bar] and realises at
    the last bar it can actually see — here the 2024-01-02 close, not the marker
    close and not an invented price. Branch 1 (marker bar present) and the
    total-miss fall-through are pinned above and below; this is the middle. *)
let test_missing_marker_bar_falls_back_to_the_previous_bar _ =
  assert_that
    (_trades
       (_run
          ~table:
            [
              (_symbol, [ _make_bar ~date:(_date "2024-01-02") ~close:95.0 ]);
              (_live, [ _make_bar ~date:_today ~close:50.0 ]);
            ]
          ~active_through_for:(_always (Some _marker)) ()))
    (elements_are
       [
         field
           (fun (t : Trading_base.Types.trade) -> t.price)
           (float_equal 95.0);
       ])

(** {!Trading_simulation.Forced_exit.apply_all}'s second rejection claim, seen
    through this runner: with no matching Holding [Position.t], the synthetic
    trade still lands — the portfolio, not the strategy map, is the source of
    truth for realised P&L — but NO transition is reported, so an observer is
    never told about an exit the strategy never had. *)
let test_missing_strategy_position_trades_but_reports_no_transition _ =
  let _, _, trades, transitions =
    _run ~positions:String.Map.empty
      ~active_through_for:(_always (Some _marker)) ()
  in
  assert_that (List.length trades, List.length transitions) (equal_to (1, 0))

let suite =
  "delisted_exit_runner"
  >::: [
         "passed marker exits at the last real close"
         >:: test_passed_marker_exits_at_the_last_real_close;
         "exit transition carries the delisted label"
         >:: test_exit_transition_carries_the_delisted_label;
         "passed marker drops the strategy position"
         >:: test_passed_marker_drops_the_strategy_position;
         "passed marker flattens the broker position"
         >:: test_passed_marker_flattens_the_broker_position;
         "absent marker is a no-op" >:: test_absent_marker_is_a_no_op;
         "marker dated today does not exit"
         >:: test_marker_dated_today_does_not_exit;
         "future marker does not exit" >:: test_future_marker_does_not_exit;
         "no bars today is a no-op" >:: test_no_bars_today_is_a_no_op;
         "unpriceable symbol is left for the stale net"
         >:: test_unpriceable_symbol_is_left_for_the_stale_net;
         "missing marker bar falls back to the previous bar"
         >:: test_missing_marker_bar_falls_back_to_the_previous_bar;
         "missing strategy position trades but reports no transition"
         >:: test_missing_strategy_position_trades_but_reports_no_transition;
       ]

let () = run_test_tt_main suite
