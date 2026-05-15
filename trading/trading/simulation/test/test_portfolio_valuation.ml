(** Tests for {!Trading_simulation.Portfolio_valuation}.

    Pins each tier of the four-tier price-resolution chain. The existing
    simulator-level test
    [test_forward_fill_uses_last_known_close_when_held_symbol_has_no_bar] in
    [test_simulator.ml] already covers tier 2 (adapter forward-fill); here we
    add direct unit-level pins for tiers 3 (cache) and 4 (avg-cost) plus the
    multi-step sequence where tier 2 seeds the cache and tier 3 later serves it.

    The fail-loud cash-fallback branch in [compute] is by construction
    unreachable in healthy runs — the chain always produces [Some price] for
    every held position — so there is no runtime test for it. Its contract is
    enforced via code inspection plus the diagnostic message that names the held
    symbols + date when it ever does fire. *)

open Core
open OUnit2
open Matchers

let _date s = Date.of_string s

(* Construct an adapter that returns None for both [get_price] and
   [get_previous_bar] on every call. Used to force the chain past tier 2
   to expose tier 3 and tier 4. *)
let _empty_adapter () =
  Trading_simulation_data.Market_data_adapter.create_with_callbacks
    ~get_price:(fun ~symbol:_ ~date:_ -> None)
    ~get_previous_bar:(fun ~symbol:_ ~date:_ -> None)

(* Construct an adapter where [get_previous_bar] returns a daily price for
   [symbol] with [close_price]. Used to seed the cache via a prior compute
   call. *)
let _adapter_with_prev_bar ~symbol ~close_price =
  let bar : Types.Daily_price.t =
    {
      date = _date "2024-01-02";
      open_price = close_price;
      high_price = close_price;
      low_price = close_price;
      close_price;
      volume = 1000;
      adjusted_close = close_price;
      active_through = None;
    }
  in
  Trading_simulation_data.Market_data_adapter.create_with_callbacks
    ~get_price:(fun ~symbol:_ ~date:_ -> None)
    ~get_previous_bar:(fun ~symbol:s ~date:_ ->
      if String.equal s symbol then Some bar else None)

(* Build a long AAPL portfolio (10 shares @ $100) for valuation tests.
   [Portfolio.apply_single_trade] is the canonical constructor —
   guaranteed to produce well-formed lots and avg-cost. *)
let _aapl_long_portfolio ~initial_cash ~qty ~price =
  let base = Trading_portfolio.Portfolio.create ~initial_cash () in
  let buy : Trading_base.Types.trade =
    {
      id = "b1";
      order_id = "o1";
      symbol = "AAPL";
      side = Buy;
      quantity = qty;
      price;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  match Trading_portfolio.Portfolio.apply_single_trade base buy with
  | Ok p -> p
  | Error err ->
      OUnit2.assert_failure
        ("failed to build long test portfolio: " ^ Status.show err)

(** Tier 3 (cache): when today has no bar AND [get_previous_bar] returns [None],
    a previously-cached close is used and [valuation_failure_count] does NOT
    increment. *)
let test_tier3_cache_serves_held_position_when_adapter_silent _ =
  let adapter = _empty_adapter () in
  let portfolio =
    _aapl_long_portfolio ~initial_cash:10_000.0 ~qty:10.0 ~price:100.0
  in
  (* Pre-seed the cache with a stale-but-valid AAPL close ($120). *)
  let last_known_prices = String.Table.create () in
  Hashtbl.set last_known_prices ~key:"AAPL" ~data:120.0;
  let valuation_failure_count = ref 0 in
  let nav =
    Trading_simulation.Portfolio_valuation.compute ~adapter
      ~date:(_date "2024-01-10") ~portfolio ~today_bars:[] ~last_known_prices
      ~valuation_failure_count
  in
  (* Cash = 10,000 - 10*100 = 9,000. NAV = 9,000 + 10*120 = 10,200. *)
  assert_that nav (float_equal 10_200.0);
  assert_that !valuation_failure_count (equal_to 0)

(** Tier 4 (avg-cost): when today has no bar, [get_previous_bar] returns [None],
    and the cache is empty, the position's avg cost basis is used and
    [valuation_failure_count] increments by exactly 1. *)
let test_tier4_avg_cost_increments_failure_counter _ =
  let adapter = _empty_adapter () in
  let portfolio =
    _aapl_long_portfolio ~initial_cash:10_000.0 ~qty:10.0 ~price:100.0
  in
  let last_known_prices = String.Table.create () in
  let valuation_failure_count = ref 0 in
  let nav =
    Trading_simulation.Portfolio_valuation.compute ~adapter
      ~date:(_date "2024-01-10") ~portfolio ~today_bars:[] ~last_known_prices
      ~valuation_failure_count
  in
  (* avg-cost = $100 per share; NAV = 9,000 + 10*100 = 10,000. *)
  assert_that nav (float_equal 10_000.0);
  assert_that !valuation_failure_count (equal_to 1);
  (* Avg-cost is also cached, so a repeat compute at the same date does NOT
     re-increment the failure counter (cache hit on tier 3 — but the cache
     was populated by tier 4's [_cache_price] side-effect). *)
  let _nav2 =
    Trading_simulation.Portfolio_valuation.compute ~adapter
      ~date:(_date "2024-01-11") ~portfolio ~today_bars:[] ~last_known_prices
      ~valuation_failure_count
  in
  assert_that !valuation_failure_count (equal_to 1)

(** Tier 2 → Tier 3 sequence: a first compute resolves via [get_previous_bar]
    and populates the cache; a second compute at a later date (now with the
    adapter returning [None]) hits the cache, not avg-cost, and leaves
    [valuation_failure_count] at 0. This pins the cache as the correct fallback
    when the adapter loses access to the symbol mid-run. *)
let test_cache_populated_by_tier2_is_consulted_later _ =
  let adapter_with_bar =
    _adapter_with_prev_bar ~symbol:"AAPL" ~close_price:150.0
  in
  let adapter_silent = _empty_adapter () in
  let portfolio =
    _aapl_long_portfolio ~initial_cash:10_000.0 ~qty:10.0 ~price:100.0
  in
  let last_known_prices = String.Table.create () in
  let valuation_failure_count = ref 0 in
  (* First step: tier-2 adapter forward-fill seeds the cache. *)
  let nav1 =
    Trading_simulation.Portfolio_valuation.compute ~adapter:adapter_with_bar
      ~date:(_date "2024-01-03") ~portfolio ~today_bars:[] ~last_known_prices
      ~valuation_failure_count
  in
  (* NAV = 9,000 + 10*150 = 10,500. *)
  assert_that nav1 (float_equal 10_500.0);
  assert_that !valuation_failure_count (equal_to 0);
  (* Second step: adapter goes silent (delisted from dataset).  Cache must
     still serve the same $150 close. *)
  let nav2 =
    Trading_simulation.Portfolio_valuation.compute ~adapter:adapter_silent
      ~date:(_date "2024-01-04") ~portfolio ~today_bars:[] ~last_known_prices
      ~valuation_failure_count
  in
  assert_that nav2 (float_equal 10_500.0);
  assert_that !valuation_failure_count (equal_to 0)

(** Empty portfolio: NAV is trivially [current_cash], with no failure counter
    increments and no raise. Pins that the fail-loud branch is reserved for the
    chain's invariant being broken, not for the legitimate "no positions" case.
*)
let test_no_held_positions_returns_cash_only_no_raise _ =
  let adapter = _empty_adapter () in
  let portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10_000.0 ()
  in
  let last_known_prices = String.Table.create () in
  let valuation_failure_count = ref 0 in
  let nav =
    Trading_simulation.Portfolio_valuation.compute ~adapter
      ~date:(_date "2024-01-10") ~portfolio ~today_bars:[] ~last_known_prices
      ~valuation_failure_count
  in
  assert_that nav (float_equal 10_000.0);
  assert_that !valuation_failure_count (equal_to 0)

let suite =
  "Portfolio_valuation Tests"
  >::: [
         "tier-3 cache serves held position when adapter is silent"
         >:: test_tier3_cache_serves_held_position_when_adapter_silent;
         "tier-4 avg-cost increments valuation_failure_count exactly once"
         >:: test_tier4_avg_cost_increments_failure_counter;
         "cache populated by tier-2 forward-fill is consulted on later steps"
         >:: test_cache_populated_by_tier2_is_consulted_later;
         "no held positions: NAV = current_cash, no raise"
         >:: test_no_held_positions_returns_cash_only_no_raise;
       ]

let () = run_test_tt_main suite
