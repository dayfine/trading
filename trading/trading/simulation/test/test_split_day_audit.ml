(** Comprehensive trade-by-trade audit harness for the split-day broker model.

    Background. The broker-model split machinery (PRs #658, #662, #664) detects
    splits between consecutive bars on every held symbol and applies the
    detected event to the {b broker portfolio's} position lots. The published
    verification — [test_split_day_mtm.ml] (3 cases) — pins three coarse
    behaviours: portfolio_value continuity through a split, no-op on no-split
    days, and no-op when no position is held. That suite is structurally
    insufficient: it never exercises the cash invariant, never combines the
    split with stop-trigger machinery, never exercises partial sells across a
    split, and never multi-step-reconciles realised P&L through a split-day
    transition.

    The [sp500-2019-2023] regression (post-fix portfolio going negative on AAPL
    split day) was detected only after a 5-year × 491-symbol simulation. This
    harness pins every variant of the cash-accounting + cost-basis + lot-state
    invariant the broker model is responsible for, on small synthetic fixtures
    with hand-computed oracles, so we never again need a 10y × 1000-symbol
    backtest to gain confidence in the broker model.

    {1 Audit invariants}

    Universal invariant (every step of every scenario): cash is non-negative
    (long-only strategy, no leverage). This single check would have caught
    the sp500-2019-2023 regression (negative cash on the AAPL split day).

    Per-scenario invariants (asserted at scenario-relevant steps):
    - On a split day, total cost basis across all lots of the affected symbol
      is preserved exactly (no money created or destroyed; only quantities and
      implicit per-share basis change).
    - [splits_applied] is non-empty {b iff} the bar pair (yesterday, today)
      contains a corporate-action ratio ≥ 1.05.
    - Realised P&L on a post-split sell uses the post-split per-share cost
      basis, not the pre-split one.

    Why [Portfolio.validate] is NOT a universal invariant: that helper
    reconstructs the portfolio from [initial_cash + trade_history], but the
    broker-model split applies via [Split_event.apply_to_portfolio] which
    mutates [positions] without touching [trade_history] (splits are not
    trades). [Portfolio.validate] therefore disagrees with reality on every
    split day by design. Cash invariance is the meaningful universal check.

    {1 Scenario matrix}

    Numbered to match [dev/notes/split-day-broker-model-verification-2026-04-29.md]
    where applicable. Each scenario is a synthetic fixture with a hand-computed
    oracle. Strategy logic is the simplest that exercises the path; we don't
    use Weinstein here — we use bespoke buy/hold/sell strategies that pin
    quantities and dates.

    + No-op split detector when nothing is held (smoke).
    + Forward 4:1 split, held position, no exit. Pin total cost basis across
      the split.
    + Reverse 1:5 split, held position. Verify quantity ÷ 5 and total basis
      preserved.
    + Forward 4:1 split, partial sell BEFORE the split. Remaining-lot total
      basis preserved across the split.
    + Forward 4:1 split, additional buy AFTER the split. Weighted-average cost
      basis includes pre/post-split bars correctly.
    + Two symbols split same day, both held. Cross-symbol independence — each
      lot scales by its own factor.
    + Cash never goes negative through a buy-and-hold-through-split cycle (the
      sp500 regression invariant).
    + Total cost basis preserved across a chain of 4 forward 4:1 splits
      (×4×4×4×4 = ×256 quantity, basis unchanged).
    + Sell ALL after a split. Realised P&L = (post-split price − post-split
      per-share cost) × post-split quantity. Cash ledger reconciles to
      initial — gain/loss only, no phantom value.

    {1 What's pinned vs what's not}

    Pinned: simulator broker-model invariants (the cash/lot ledger).

    {b Not} pinned here: strategy-side [Position.t] split adjustment. That's
    [test_split_day_stop_exit.ml]'s job, since it is a strategy-Map mutation
    that lives on the simulator's [t.positions] field, not on the broker
    portfolio. Several scenarios below WOULD fail if we asserted on the
    strategy [Position.Holding.quantity] post-split — that's the bug the
    sibling debug PR is fixing — but the broker model's own invariants are
    well-defined and we audit those here.

    {1 Pass / fail expectations on current main}

    Scenarios 1, 2, 3, 6, 7, 8 are pure broker-model invariants and pass on
    current main (PR #664). Scenarios 4, 5, 9 audit cross-event invariants
    (sell + split + sell, buy + split + buy, full reconciliation through a
    sell after split) and surface the strategy/broker desync bug. Per the
    dispatch prompt, scenarios that fail on current main are intentional —
    they encode the contract the sibling debug PR's fix must satisfy. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers
module Split_event = Trading_portfolio.Split_event
module Portfolio = Trading_portfolio.Portfolio
module Calculations = Trading_portfolio.Calculations
module Position = Trading_strategy.Position
module Strategy_interface = Trading_strategy.Strategy_interface

(* ------------------------------------------------------------------ *)
(* Test data builders                                                   *)
(* ------------------------------------------------------------------ *)

(* Numeric tolerances. Splits multiply quantities by floats; per-share basis
   divides by the same factor. After ~4 chained ×4 splits the residual
   floating-point error stays below 1e-9 for double precision. We use 1e-6
   for split-day arithmetic and 0.01 for cash / portfolio_value where bars
   are pinned to 1¢ resolution. *)
let _basis_epsilon = 1e-6
let _cash_epsilon = 0.01

let _date s = Date.of_string s

let _make_bar ~date ~open_ ~high ~low ~close ~adjusted_close ~volume =
  Types.Daily_price.
    {
      date;
      open_price = open_;
      high_price = high;
      low_price = low;
      close_price = close;
      adjusted_close;
      volume;
    }

(* ------------------------------------------------------------------ *)
(* Strategy builders                                                    *)
(* ------------------------------------------------------------------ *)

(** Buy [target_quantity] of [symbol] on the first cadence call, then hold
    passively forever. *)
module Make_buy_and_hold (Cfg : sig
  val symbol : string
  val target_quantity : float
end) : Strategy_interface.STRATEGY = struct
  let name = "BuyAndHold"
  let entered = ref false

  let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
    if !entered then Ok { Strategy_interface.transitions = [] }
    else
      match get_price Cfg.symbol with
      | None -> Ok { Strategy_interface.transitions = [] }
      | Some (bar : Types.Daily_price.t) ->
          entered := true;
          let open Position in
          let trans =
            {
              position_id = Cfg.symbol ^ "-hold";
              date = bar.date;
              kind =
                CreateEntering
                  {
                    symbol = Cfg.symbol;
                    side = Long;
                    target_quantity = Cfg.target_quantity;
                    entry_price = bar.close_price;
                    reasoning =
                      TechnicalSignal
                        { indicator = "audit"; description = "buy-and-hold" };
                  };
            }
          in
          Ok { Strategy_interface.transitions = [ trans ] }
end

(** Schedule of dated transitions to emit. The strategy looks up the current
    date on every call and emits any transitions whose date matches. *)
type scheduled_action =
  | Buy of { symbol : string; quantity : float }
  | Sell of { symbol : string; fraction : float }
      (** [fraction] in (0, 1], applied to the lot's current quantity *)

(** Strategy that emits scheduled actions on specific dates. The [actions]
    map is consulted on every call; an empty schedule on a given date emits
    no transitions. *)
module Make_scheduled (Cfg : sig
  val schedule : (Date.t * scheduled_action) list
end) : Strategy_interface.STRATEGY = struct
  let name = "Scheduled"
  let position_counter = ref 0

  let _next_position_id symbol =
    incr position_counter;
    Printf.sprintf "%s-%d" symbol !position_counter

  let _build_buy ~symbol ~quantity ~(bar : Types.Daily_price.t) =
    let open Position in
    let pid = _next_position_id symbol in
    {
      position_id = pid;
      date = bar.date;
      kind =
        CreateEntering
          {
            symbol;
            side = Long;
            target_quantity = quantity;
            entry_price = bar.close_price;
            reasoning =
              TechnicalSignal
                { indicator = "audit"; description = "scheduled-buy" };
          };
    }

  (* Build a Sell transition by finding the held position for [symbol] and
     emitting a TriggerExit on a fraction of its quantity. *)
  let _build_sell ~symbol ~fraction ~(bar : Types.Daily_price.t)
      ~(positions : Position.t Core.String.Map.t) =
    let open Position in
    Map.to_alist positions
    |> List.find_map ~f:(fun (id, pos) ->
           if not (String.equal pos.symbol symbol) then None
           else
             match get_state pos with
             | Holding h ->
                 let exit_qty = h.quantity *. fraction in
                 if Float.(exit_qty <= 0.0) then None
                 else
                   Some
                     {
                       position_id = id;
                       date = bar.date;
                       kind =
                         TriggerExit
                           {
                             exit_reason =
                               SignalReversal
                                 { description = "scheduled-sell" };
                             exit_price = bar.close_price;
                           };
                     }
             | _ -> None)

  (* Find today's date by probing for any symbol in the schedule whose bar
     is available — non-strategy days (weekends/holidays) have no bars and
     we'll emit no transitions. *)
  let _today_date_opt ~(get_price : Strategy_interface.get_price_fn) =
    List.find_map Cfg.schedule ~f:(fun (_, action) ->
        let symbol =
          match action with Buy { symbol; _ } | Sell { symbol; _ } -> symbol
        in
        match get_price symbol with
        | Some (bar : Types.Daily_price.t) -> Some bar.date
        | None -> None)

  let on_market_close ~get_price ~get_indicator:_
      ~(portfolio : Trading_strategy.Portfolio_view.t) =
    match _today_date_opt ~get_price with
    | None -> Ok { Strategy_interface.transitions = [] }
    | Some today ->
        let today_actions =
          List.filter Cfg.schedule ~f:(fun (date, _) -> Date.equal date today)
        in
        let transitions =
          List.filter_map today_actions ~f:(fun (_, action) ->
              match action with
              | Buy { symbol; quantity } -> (
                  match get_price symbol with
                  | None -> None
                  | Some bar -> Some (_build_buy ~symbol ~quantity ~bar))
              | Sell { symbol; fraction } -> (
                  match get_price symbol with
                  | None -> None
                  | Some bar ->
                      _build_sell ~symbol ~fraction ~bar
                        ~positions:portfolio.positions))
        in
        Ok { Strategy_interface.transitions }
end

(* ------------------------------------------------------------------ *)
(* Audit invariants — applied to every step of every scenario          *)
(* ------------------------------------------------------------------ *)

(** Every step's cash must be non-negative (long-only, no leverage). *)
let _assert_cash_non_negative
    (step : Trading_simulation_types.Simulator_types.step_result) =
  assert_that step.portfolio.current_cash (ge (module Float_ord) 0.0)

(** Apply the universal invariants to every step.

    [Portfolio.validate] is intentionally NOT included here: the broker model
    applies a split via [Split_event.apply_to_portfolio], which mutates the
    [positions] field but does NOT add to [trade_history]. This is correct —
    splits are not trades. But [Portfolio.validate] reconstructs the
    portfolio from [initial_cash + trade_history], which by design produces a
    pre-split position set that disagrees with the post-split reality.
    Including [Portfolio.validate] here would falsely fail every split-day
    step. The cash invariant is the meaningful universal check. *)
let _audit_universal_invariants steps =
  List.iter steps ~f:_assert_cash_non_negative

(** Lookup helper. Fail the test with diagnostic on miss. *)
let _step_on ~date steps =
  match
    List.find steps
      ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
        Date.equal s.date date)
  with
  | Some s -> s
  | None ->
      assert_failure
        (Printf.sprintf "no step on %s; have %d steps" (Date.to_string date)
           (List.length steps))

(** Total cost basis across all lots of the position for [symbol] at this step.
    Returns [None] if the symbol is not held. *)
let _total_cost_basis ~symbol
    (step : Trading_simulation_types.Simulator_types.step_result) : float option
    =
  Portfolio.get_position step.portfolio symbol
  |> Option.map ~f:(fun pos -> Calculations.position_cost_basis pos)

(** Total quantity for [symbol] at this step. *)
let _total_quantity ~symbol
    (step : Trading_simulation_types.Simulator_types.step_result) : float option
    =
  Portfolio.get_position step.portfolio symbol
  |> Option.map ~f:(fun pos -> Calculations.position_quantity pos)

(** Configurable test runner. Builds the simulator, runs to completion,
    applies universal invariants, returns the run result for scenario-specific
    assertions. *)
let _run_scenario ~test_name ~symbols_with_data ~strategy
    ~(config : Trading_simulation_types.Simulator_types.config) =
  let result_ref = ref None in
  with_test_data test_name symbols_with_data ~f:(fun data_dir ->
      let symbols = List.map symbols_with_data ~f:fst in
      let deps =
        create_deps ~symbols ~data_dir ~strategy
          ~commission:config.commission ()
      in
      let sim = create_exn ~config ~deps in
      match run sim with
      | Ok r -> result_ref := Some r
      | Error err -> assert_failure ("simulation failed: " ^ Status.show err));
  let result =
    match !result_ref with
    | Some r -> r
    | None -> assert_failure "no result"
  in
  _audit_universal_invariants result.steps;
  result

(* ------------------------------------------------------------------ *)
(* Shared fixtures                                                      *)
(* ------------------------------------------------------------------ *)

(* A 4:1 forward split fixture for AAPL spanning 2020-08-25..2020-09-04.
   The split day is 2020-08-31 (raw drops 4×, adjusted continuous). *)
let _aapl_split_4to1 =
  [
    _make_bar ~date:(_date "2020-08-25") ~open_:498.0 ~high:500.0 ~low:495.0
      ~close:500.0 ~adjusted_close:125.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2020-08-26") ~open_:500.0 ~high:506.0 ~low:498.0
      ~close:504.0 ~adjusted_close:126.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2020-08-27") ~open_:504.0 ~high:508.0 ~low:496.0
      ~close:500.0 ~adjusted_close:125.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2020-08-28") ~open_:500.0 ~high:502.0 ~low:498.0
      ~close:500.0 ~adjusted_close:125.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2020-08-31") ~open_:125.0 ~high:127.0 ~low:124.0
      ~close:125.0 ~adjusted_close:125.0 ~volume:4_000_000;
    _make_bar ~date:(_date "2020-09-01") ~open_:125.0 ~high:126.0 ~low:124.0
      ~close:125.0 ~adjusted_close:125.0 ~volume:4_000_000;
    _make_bar ~date:(_date "2020-09-02") ~open_:125.0 ~high:127.0 ~low:124.0
      ~close:126.0 ~adjusted_close:126.0 ~volume:4_000_000;
    _make_bar ~date:(_date "2020-09-03") ~open_:126.0 ~high:128.0 ~low:125.0
      ~close:127.0 ~adjusted_close:127.0 ~volume:4_000_000;
    _make_bar ~date:(_date "2020-09-04") ~open_:127.0 ~high:128.0 ~low:126.0
      ~close:127.0 ~adjusted_close:127.0 ~volume:4_000_000;
  ]

(* TSLA-like 5:1 forward split same day as AAPL — 2020-08-31. *)
let _tsla_split_5to1 =
  [
    _make_bar ~date:(_date "2020-08-25") ~open_:2050.0 ~high:2060.0 ~low:2040.0
      ~close:2050.0 ~adjusted_close:410.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2020-08-26") ~open_:2050.0 ~high:2070.0 ~low:2040.0
      ~close:2060.0 ~adjusted_close:412.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2020-08-27") ~open_:2060.0 ~high:2080.0 ~low:2050.0
      ~close:2050.0 ~adjusted_close:410.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2020-08-28") ~open_:2050.0 ~high:2060.0 ~low:2040.0
      ~close:2050.0 ~adjusted_close:410.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2020-08-31") ~open_:410.0 ~high:412.0 ~low:408.0
      ~close:410.0 ~adjusted_close:410.0 ~volume:5_000_000;
    _make_bar ~date:(_date "2020-09-01") ~open_:410.0 ~high:412.0 ~low:408.0
      ~close:410.0 ~adjusted_close:410.0 ~volume:5_000_000;
    _make_bar ~date:(_date "2020-09-02") ~open_:410.0 ~high:413.0 ~low:408.0
      ~close:412.0 ~adjusted_close:412.0 ~volume:5_000_000;
    _make_bar ~date:(_date "2020-09-03") ~open_:412.0 ~high:414.0 ~low:410.0
      ~close:413.0 ~adjusted_close:413.0 ~volume:5_000_000;
    _make_bar ~date:(_date "2020-09-04") ~open_:413.0 ~high:415.0 ~low:411.0
      ~close:413.0 ~adjusted_close:413.0 ~volume:5_000_000;
  ]

(* Reverse 1:5 split fixture: raw price multiplied by 5×, adjusted continuous.
   Reverse splits are common in distressed names. *)
let _reverse_1to5_bars =
  [
    _make_bar ~date:(_date "2024-01-02") ~open_:2.0 ~high:2.1 ~low:1.95
      ~close:2.0 ~adjusted_close:10.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2024-01-03") ~open_:2.0 ~high:2.1 ~low:1.95
      ~close:2.0 ~adjusted_close:10.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2024-01-04") ~open_:2.0 ~high:2.1 ~low:1.95
      ~close:2.0 ~adjusted_close:10.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2024-01-05") ~open_:10.0 ~high:10.5 ~low:9.8
      ~close:10.0 ~adjusted_close:10.0 ~volume:200_000;
    _make_bar ~date:(_date "2024-01-08") ~open_:10.0 ~high:10.5 ~low:9.8
      ~close:10.0 ~adjusted_close:10.0 ~volume:200_000;
    _make_bar ~date:(_date "2024-01-09") ~open_:10.0 ~high:10.5 ~low:9.8
      ~close:10.0 ~adjusted_close:10.0 ~volume:200_000;
  ]

(* Chain of 4 successive 4:1 splits in 5 trading days. Total quantity scales
   ×256, total cost basis preserved across all 4. *)
let _chain_4_splits =
  [
    _make_bar ~date:(_date "2024-01-02") ~open_:1024.0 ~high:1030.0 ~low:1020.0
      ~close:1024.0 ~adjusted_close:4.0 ~volume:1_000_000;
    _make_bar ~date:(_date "2024-01-03") ~open_:1024.0 ~high:1030.0 ~low:1020.0
      ~close:1024.0 ~adjusted_close:4.0 ~volume:1_000_000;
    (* Split 1: 4:1. raw 1024 → 256, adj continuous (back-roll: 4 → 4). *)
    _make_bar ~date:(_date "2024-01-04") ~open_:256.0 ~high:260.0 ~low:255.0
      ~close:256.0 ~adjusted_close:4.0 ~volume:4_000_000;
    (* Split 2: 4:1. raw 256 → 64. *)
    _make_bar ~date:(_date "2024-01-05") ~open_:64.0 ~high:65.0 ~low:63.0
      ~close:64.0 ~adjusted_close:4.0 ~volume:16_000_000;
    (* Split 3: 4:1. raw 64 → 16. *)
    _make_bar ~date:(_date "2024-01-08") ~open_:16.0 ~high:16.5 ~low:15.5
      ~close:16.0 ~adjusted_close:4.0 ~volume:64_000_000;
    (* Split 4: 4:1. raw 16 → 4. *)
    _make_bar ~date:(_date "2024-01-09") ~open_:4.0 ~high:4.2 ~low:3.9
      ~close:4.0 ~adjusted_close:4.0 ~volume:256_000_000;
    _make_bar ~date:(_date "2024-01-10") ~open_:4.0 ~high:4.2 ~low:3.9
      ~close:4.0 ~adjusted_close:4.0 ~volume:256_000_000;
  ]

let _zero_commission =
  { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

(* ------------------------------------------------------------------ *)
(* Test 1: Forward 4:1 split, no held position — detector no-op        *)
(* ------------------------------------------------------------------ *)

(** Strategy never enters a position. The split-day bar pair (08-28, 08-31)
    contains an obvious 4× ratio that the detector WOULD report if asked,
    but [_detect_splits_for_held_positions] iterates only over held positions
    and the held set is empty throughout. Every step has [splits_applied=[]]. *)
let test_01_no_op_when_no_position _ =
  let config =
    {
      start_date = _date "2020-08-25";
      end_date = _date "2020-09-05";
      initial_cash = 10_000.0;
      commission = _zero_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let result =
    _run_scenario ~test_name:"audit_01_no_position"
      ~symbols_with_data:[ ("AAPL", _aapl_split_4to1) ]
      ~strategy:(module Noop_strategy)
      ~config
  in
  let split_day_observed =
    List.exists result.steps
      ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
        Date.equal s.date (_date "2020-08-31"))
  in
  assert_that split_day_observed (equal_to true);
  let total_split_events =
    List.fold result.steps ~init:0
      ~f:(fun acc (s : Trading_simulation_types.Simulator_types.step_result) ->
        acc + List.length s.splits_applied)
  in
  assert_that total_split_events (equal_to 0)

(* ------------------------------------------------------------------ *)
(* Test 2: Forward 4:1 split, held position — total basis preserved    *)
(* ------------------------------------------------------------------ *)

(** Strategy buys 100 AAPL at the start; the position survives the split day.
    Pin total cost basis pre-split and post-split — they must match exactly. *)
let test_02_basis_preserved_through_4to1 _ =
  let config =
    {
      start_date = _date "2020-08-25";
      end_date = _date "2020-09-05";
      initial_cash = 100_000.0;
      commission = _zero_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let module Hold = Make_buy_and_hold (struct
    let symbol = "AAPL"
    let target_quantity = 100.0
  end) in
  let result =
    _run_scenario ~test_name:"audit_02_basis_4to1"
      ~symbols_with_data:[ ("AAPL", _aapl_split_4to1) ]
      ~strategy:(module Hold)
      ~config
  in
  (* Pre-split day (2020-08-28, last day before split): position is 100 shares
     filled at 2020-08-26 open=$500. Total basis = 100 × 500 = $50,000. *)
  let pre_split = _step_on ~date:(_date "2020-08-28") result.steps in
  let pre_split_basis = _total_cost_basis ~symbol:"AAPL" pre_split in
  assert_that pre_split_basis
    (is_some_and (float_equal ~epsilon:_basis_epsilon 50_000.0));
  (* Split day (2020-08-31): quantity ×4 (= 400), basis unchanged. *)
  let split_day = _step_on ~date:(_date "2020-08-31") result.steps in
  assert_that (_total_cost_basis ~symbol:"AAPL" split_day)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 50_000.0));
  assert_that (_total_quantity ~symbol:"AAPL" split_day)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 400.0));
  assert_that split_day.splits_applied (size_is 1);
  (* Post-split day (2020-09-01): same. *)
  let post_split = _step_on ~date:(_date "2020-09-01") result.steps in
  assert_that (_total_cost_basis ~symbol:"AAPL" post_split)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 50_000.0));
  assert_that (_total_quantity ~symbol:"AAPL" post_split)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 400.0))

(* ------------------------------------------------------------------ *)
(* Test 3: Reverse 1:5 split — quantity divides, basis preserved        *)
(* ------------------------------------------------------------------ *)

(** Buy 500 shares of a $2-stock at $1,000 total cost. After 1:5 reverse split:
    100 shares at $10/share, total cost basis still $1,000. *)
let test_03_reverse_split _ =
  let config =
    {
      start_date = _date "2024-01-02";
      end_date = _date "2024-01-10";
      initial_cash = 5_000.0;
      commission = _zero_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let module Hold = Make_buy_and_hold (struct
    let symbol = "REV"
    let target_quantity = 500.0
  end) in
  let result =
    _run_scenario ~test_name:"audit_03_reverse"
      ~symbols_with_data:[ ("REV", _reverse_1to5_bars) ]
      ~strategy:(module Hold)
      ~config
  in
  (* Pre-split day (2024-01-04): 500 shares at $2/share, total basis $1000. *)
  let pre_split = _step_on ~date:(_date "2024-01-04") result.steps in
  assert_that (_total_cost_basis ~symbol:"REV" pre_split)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 1_000.0));
  assert_that (_total_quantity ~symbol:"REV" pre_split)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 500.0));
  (* Split day (2024-01-05): quantity ÷5 (= 100), basis unchanged. *)
  let split_day = _step_on ~date:(_date "2024-01-05") result.steps in
  assert_that split_day.splits_applied (size_is 1);
  assert_that (_total_quantity ~symbol:"REV" split_day)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 100.0));
  assert_that (_total_cost_basis ~symbol:"REV" split_day)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 1_000.0))

(* ------------------------------------------------------------------ *)
(* Test 4: Partial sell BEFORE the split — remaining basis preserved   *)
(* ------------------------------------------------------------------ *)

(** Buy 100 AAPL on 2020-08-25 (fills 08-26), sell 50 on 2020-08-27 (fills
    08-28 at open=$500), hold remaining 50 through the 4:1 split.

    Oracle:
    - Day 08-26 fill: 100 shares × $500 cost = $50,000 basis. Cash $50,000.
    - Day 08-28 sell-fill: 50 × $500 = $25,000 cash recovered. Realised P&L
      = 50 × ($500 − $500) = $0. Remaining 50 shares × $500 = $25,000 basis.
      Cash $75,000.
    - Day 08-31 split: quantity ×4 (= 200), basis unchanged at $25,000.
    - Final: portfolio_value = $75,000 + 200 × $127 = $100,400. *)
let test_04_partial_sell_pre_split _ =
  let config =
    {
      start_date = _date "2020-08-25";
      end_date = _date "2020-09-05";
      initial_cash = 100_000.0;
      commission = _zero_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let module S = Make_scheduled (struct
    let schedule =
      [
        (_date "2020-08-25", Buy { symbol = "AAPL"; quantity = 100.0 });
        (_date "2020-08-27", Sell { symbol = "AAPL"; fraction = 0.5 });
      ]
  end) in
  let result =
    _run_scenario ~test_name:"audit_04_partial_pre"
      ~symbols_with_data:[ ("AAPL", _aapl_split_4to1) ]
      ~strategy:(module S)
      ~config
  in
  (* After sell fills (2020-08-28): 50 shares, basis $25,000. *)
  let post_sell = _step_on ~date:(_date "2020-08-28") result.steps in
  assert_that (_total_quantity ~symbol:"AAPL" post_sell)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 50.0));
  assert_that (_total_cost_basis ~symbol:"AAPL" post_sell)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 25_000.0));
  (* Split day: 50 ×4 = 200 shares, basis unchanged at $25,000. *)
  let split_day = _step_on ~date:(_date "2020-08-31") result.steps in
  assert_that split_day.splits_applied (size_is 1);
  assert_that (_total_quantity ~symbol:"AAPL" split_day)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 200.0));
  assert_that (_total_cost_basis ~symbol:"AAPL" split_day)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 25_000.0))

(* ------------------------------------------------------------------ *)
(* Test 5: Additional buy AFTER the split — weighted-avg basis correct *)
(* ------------------------------------------------------------------ *)

(** Buy 100 AAPL on 2020-08-25 (fills 08-26 at $500), hold through split,
    then buy 100 more on 2020-09-01 (fills 09-02 at post-split $125).

    Oracle:
    - Pre-split: 100 shares, basis $50,000.
    - Split day (08-31): 400 shares (×4), basis $50,000 unchanged. Implied
      per-share basis $125.
    - Post-split second buy fills 2020-09-02: +100 shares at $125 = $12,500
      additional basis. Total: 500 shares, basis $50,000 + $12,500 = $62,500.
      Implied per-share basis $125. *)
let test_05_additional_buy_post_split _ =
  let config =
    {
      start_date = _date "2020-08-25";
      end_date = _date "2020-09-05";
      initial_cash = 100_000.0;
      commission = _zero_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let module S = Make_scheduled (struct
    let schedule =
      [
        (_date "2020-08-25", Buy { symbol = "AAPL"; quantity = 100.0 });
        (_date "2020-09-01", Buy { symbol = "AAPL"; quantity = 100.0 });
      ]
  end) in
  let result =
    _run_scenario ~test_name:"audit_05_additional_post"
      ~symbols_with_data:[ ("AAPL", _aapl_split_4to1) ]
      ~strategy:(module S)
      ~config
  in
  (* Day 09-02 (second buy fills at $125): expect 500 shares total, basis
     $62,500. *)
  let post_buy = _step_on ~date:(_date "2020-09-02") result.steps in
  assert_that (_total_quantity ~symbol:"AAPL" post_buy)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 500.0));
  assert_that (_total_cost_basis ~symbol:"AAPL" post_buy)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 62_500.0))

(* ------------------------------------------------------------------ *)
(* Test 6: Two symbols split same day — cross-symbol independence       *)
(* ------------------------------------------------------------------ *)

(** Buy 100 AAPL + 50 TSLA pre-split. AAPL splits 4:1 and TSLA splits 5:1
    on the same day. Each symbol's lots scale by its own factor; the other
    symbol is untouched. *)
let test_06_two_symbols_split_same_day _ =
  let config =
    {
      start_date = _date "2020-08-25";
      end_date = _date "2020-09-05";
      initial_cash = 200_000.0;
      commission = _zero_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let module S = Make_scheduled (struct
    let schedule =
      [
        (_date "2020-08-25", Buy { symbol = "AAPL"; quantity = 100.0 });
        (_date "2020-08-25", Buy { symbol = "TSLA"; quantity = 50.0 });
      ]
  end) in
  let result =
    _run_scenario ~test_name:"audit_06_two_symbols"
      ~symbols_with_data:
        [ ("AAPL", _aapl_split_4to1); ("TSLA", _tsla_split_5to1) ]
      ~strategy:(module S)
      ~config
  in
  let split_day = _step_on ~date:(_date "2020-08-31") result.steps in
  (* Both symbols' splits detected and applied. *)
  assert_that split_day.splits_applied (size_is 2);
  (* AAPL: 100 × 4 = 400 shares, basis 100 × $500 = $50,000. *)
  assert_that (_total_quantity ~symbol:"AAPL" split_day)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 400.0));
  assert_that (_total_cost_basis ~symbol:"AAPL" split_day)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 50_000.0));
  (* TSLA: 50 × 5 = 250 shares, basis 50 × $2,050 = $102,500. *)
  assert_that (_total_quantity ~symbol:"TSLA" split_day)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 250.0));
  assert_that (_total_cost_basis ~symbol:"TSLA" split_day)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 102_500.0))

(* ------------------------------------------------------------------ *)
(* Test 7: Cash never goes negative through buy-and-hold-through-split *)
(* ------------------------------------------------------------------ *)

(** The sp500-2019-2023 regression manifested as negative portfolio value on
    2020-08-31 — the AAPL split day. Pin the cash invariant explicitly across
    every step of a 4:1 split scenario.

    The universal invariant [_assert_cash_non_negative] already runs against
    every step, so this test is a smoke check that the whole AAPL-split
    sequence completes without any step violating the long-only cash rule. *)
let test_07_cash_non_negative_through_split _ =
  let config =
    {
      start_date = _date "2020-08-25";
      end_date = _date "2020-09-05";
      initial_cash = 100_000.0;
      commission = _zero_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let module Hold = Make_buy_and_hold (struct
    let symbol = "AAPL"
    let target_quantity = 100.0
  end) in
  let result =
    _run_scenario ~test_name:"audit_07_cash"
      ~symbols_with_data:[ ("AAPL", _aapl_split_4to1) ]
      ~strategy:(module Hold)
      ~config
  in
  (* In addition to the universal check, pin the exact final cash: bought
     100 shares at $500 open on 08-26, never sold, so cash = $50,000 at
     every step from 08-26 onward. *)
  let final = List.last_exn result.steps in
  assert_that final.portfolio.current_cash
    (float_equal ~epsilon:_cash_epsilon 50_000.0)

(* ------------------------------------------------------------------ *)
(* Test 8: Chain of 4 4:1 splits — total basis preserved across all    *)
(* ------------------------------------------------------------------ *)

(** 4 successive 4:1 splits on consecutive trading days. Initial buy: 1 share
    at $1,024. After 4 splits: 1 × 4^4 = 256 shares. Basis = $1,024 throughout
    (modulo floating-point precision, which we pin at 1e-6). *)
let test_08_chained_splits _ =
  let config =
    {
      start_date = _date "2024-01-02";
      end_date = _date "2024-01-11";
      initial_cash = 5_000.0;
      commission = _zero_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let module Hold = Make_buy_and_hold (struct
    let symbol = "CHN"
    let target_quantity = 1.0
  end) in
  let result =
    _run_scenario ~test_name:"audit_08_chain"
      ~symbols_with_data:[ ("CHN", _chain_4_splits) ]
      ~strategy:(module Hold)
      ~config
  in
  (* After all 4 splits (final step at 2024-01-10): qty = 1 × 4^4 = 256,
     basis still $1,024. *)
  let final = List.last_exn result.steps in
  assert_that (_total_quantity ~symbol:"CHN" final)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 256.0));
  assert_that (_total_cost_basis ~symbol:"CHN" final)
    (is_some_and (float_equal ~epsilon:_basis_epsilon 1_024.0));
  (* Across the whole run we should observe exactly 4 split events. *)
  let total_splits =
    List.fold result.steps ~init:0
      ~f:(fun acc (s : Trading_simulation_types.Simulator_types.step_result) ->
        acc + List.length s.splits_applied)
  in
  assert_that total_splits (equal_to 4)

(* ------------------------------------------------------------------ *)
(* Test 9: Sell ALL after split — cash + basis reconciliation           *)
(* ------------------------------------------------------------------ *)

(** End-to-end reconciliation through a sell after a split. Buy 100 AAPL
    on 2020-08-25 (fills 08-26 at $500, basis $50,000, cash $50,000). Hold
    through the 4:1 split (now 400 shares × $125 implied basis, total basis
    $50,000, cash $50,000). Sell 100% on 2020-09-02 (fills 09-03 at open $126,
    yields 400 × $126 = $50,400 cash, realised P&L = 400 × ($126 − $125) =
    $400). Final cash = $50,000 + $50,400 = $100,400. Final position: empty.

    {b The point of this test} is that the broker model's split-time lot
    adjustment must produce the {e exact} per-share basis ($125) for the
    realised-P&L computation on the post-split sell. If the simulator failed
    to scale the lots, the per-share basis would still be $500 and the sell
    would compute realised P&L = 400 × ($126 − $500) = −$149,600 — a phantom
    catastrophic loss exactly mirroring the sp500 regression.

    This test verifies the broker-model's per-lot basis post-split. The
    strategy-side [Position.t] desync (separate bug, owned by the sibling
    debug PR) shows up as either a Status error from the simulator (if the
    strategy's stale Holding.quantity makes [order_generator] build a
    400-share sell against a 400-share lot — works) or as orphaned shares
    (if the strategy emits a 100-share exit against a 400-share lot — bug).
    Here we use [Make_scheduled] which calls [_build_sell] using the
    {b live strategy-side Holding.quantity}; if the strategy's [Position.t]
    is stale on 2020-09-02 (qty = 100 instead of 400), the sell will only
    drain 100 shares, leaving 300 orphans — exactly the regression. The
    final-cash assertion catches this. *)
let test_09_sell_all_after_split _ =
  let config =
    {
      start_date = _date "2020-08-25";
      end_date = _date "2020-09-05";
      initial_cash = 100_000.0;
      commission = _zero_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let module S = Make_scheduled (struct
    let schedule =
      [
        (_date "2020-08-25", Buy { symbol = "AAPL"; quantity = 100.0 });
        (_date "2020-09-02", Sell { symbol = "AAPL"; fraction = 1.0 });
      ]
  end) in
  let result =
    _run_scenario ~test_name:"audit_09_sell_all"
      ~symbols_with_data:[ ("AAPL", _aapl_split_4to1) ]
      ~strategy:(module S)
      ~config
  in
  (* After the sell fills (2020-09-03): no positions, cash = $100,400. *)
  let post_sell = _step_on ~date:(_date "2020-09-03") result.steps in
  assert_that post_sell.portfolio.positions (size_is 0);
  assert_that post_sell.portfolio.current_cash
    (float_equal ~epsilon:_cash_epsilon 100_400.0)

(* ------------------------------------------------------------------ *)

let suite =
  "split_day_audit"
  >::: [
         "01_no_op_when_no_position" >:: test_01_no_op_when_no_position;
         "02_basis_preserved_through_4to1"
         >:: test_02_basis_preserved_through_4to1;
         "03_reverse_split" >:: test_03_reverse_split;
         "04_partial_sell_pre_split" >:: test_04_partial_sell_pre_split;
         "05_additional_buy_post_split" >:: test_05_additional_buy_post_split;
         "06_two_symbols_split_same_day" >:: test_06_two_symbols_split_same_day;
         "07_cash_non_negative_through_split"
         >:: test_07_cash_non_negative_through_split;
         "08_chained_splits" >:: test_08_chained_splits;
         "09_sell_all_after_split" >:: test_09_sell_all_after_split;
       ]

let () = run_test_tt_main suite
