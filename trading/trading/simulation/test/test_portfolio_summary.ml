(** Tests for {!Trading_simulation_types.Portfolio_summary}: pin the projection
    from a full {!Trading_portfolio.Portfolio.t}, the empty/with_cash test
    helpers, and the small accessors used by metric computers. *)

open Core
open OUnit2
open Matchers
module Portfolio_summary = Trading_simulation_types.Portfolio_summary

let _date s = Date.of_string s

(** Empty portfolio (no positions, $10,000 cash) projects with no positions and
    [position_value_total = 0.0]. *)
let test_of_portfolio_empty _ =
  let portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10_000.0 ()
  in
  let summary =
    Portfolio_summary.of_portfolio portfolio ~position_value_total:0.0
  in
  assert_that summary
    (all_of
       [
         field
           (fun (s : Portfolio_summary.t) -> s.current_cash)
           (float_equal 10_000.0);
         field
           (fun (s : Portfolio_summary.t) -> s.position_value_total)
           (float_equal 0.0);
         field (fun (s : Portfolio_summary.t) -> s.positions) (elements_are []);
       ])

(** A portfolio with one open long position projects to a single
    [position_summary] with the symbol, signed quantity, and total cost basis.
    The [position_value_total] is supplied by the caller (the simulator) and
    threaded through unchanged. *)
let test_of_portfolio_with_long_position _ =
  let base = Trading_portfolio.Portfolio.create ~initial_cash:10_000.0 () in
  let buy =
    {
      Trading_base.Types.id = "b1";
      order_id = "o1";
      symbol = "AAPL";
      side = Buy;
      quantity = 10.0;
      price = 100.0;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let portfolio =
    match Trading_portfolio.Portfolio.apply_single_trade base buy with
    | Ok p -> p
    | Error err ->
        OUnit2.assert_failure
          ("failed to build long test portfolio: " ^ Status.show err)
  in
  (* market value at $105 / share = $1,050. *)
  let summary =
    Portfolio_summary.of_portfolio portfolio ~position_value_total:1_050.0
  in
  assert_that summary
    (all_of
       [
         (* current_cash: $10,000 - 10*$100 = $9,000. *)
         field
           (fun (s : Portfolio_summary.t) -> s.current_cash)
           (float_equal 9_000.0);
         field
           (fun (s : Portfolio_summary.t) -> s.position_value_total)
           (float_equal 1_050.0);
         field
           (fun (s : Portfolio_summary.t) -> s.positions)
           (elements_are
              [
                all_of
                  [
                    field
                      (fun (p : Portfolio_summary.position_summary) -> p.symbol)
                      (equal_to "AAPL");
                    field
                      (fun (p : Portfolio_summary.position_summary) ->
                        p.quantity)
                      (float_equal 10.0);
                    (* Cost basis = 10 * $100 = $1,000. *)
                    field
                      (fun (p : Portfolio_summary.position_summary) ->
                        p.cost_basis)
                      (float_equal 1_000.0);
                  ];
              ]);
       ])

(** A short position carries negative quantity and negative cost basis (the
    weighted-cost convention for shorts). *)
let test_of_portfolio_with_short_position _ =
  let base = Trading_portfolio.Portfolio.create ~initial_cash:10_000.0 () in
  let sell =
    {
      Trading_base.Types.id = "s1";
      order_id = "o1";
      symbol = "BEAR";
      side = Sell;
      quantity = 50.0;
      price = 200.0;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let portfolio =
    match Trading_portfolio.Portfolio.apply_single_trade base sell with
    | Ok p -> p
    | Error err ->
        OUnit2.assert_failure
          ("failed to build short test portfolio: " ^ Status.show err)
  in
  let summary =
    Portfolio_summary.of_portfolio portfolio ~position_value_total:(-10_000.0)
  in
  assert_that summary
    (field
       (fun (s : Portfolio_summary.t) -> s.positions)
       (elements_are
          [
            all_of
              [
                field
                  (fun (p : Portfolio_summary.position_summary) -> p.symbol)
                  (equal_to "BEAR");
                (* Signed quantity: shorts are negative. *)
                field
                  (fun (p : Portfolio_summary.position_summary) -> p.quantity)
                  (float_equal (-50.0));
                (* Cost basis is signed: position_quantity * avg_cost =
                   (-50) * $200 = -$10,000. *)
                field
                  (fun (p : Portfolio_summary.position_summary) -> p.cost_basis)
                  (float_equal (-10_000.0));
              ];
          ]))

(** [positions_count] reports the number of open positions. *)
let test_positions_count _ =
  let summary = Portfolio_summary.empty in
  assert_that (Portfolio_summary.positions_count summary) (equal_to 0)

(** [find_position] returns [Some] when the symbol is held, [None] otherwise. *)
let test_find_position _ =
  let base = Trading_portfolio.Portfolio.create ~initial_cash:10_000.0 () in
  let buy =
    {
      Trading_base.Types.id = "b1";
      order_id = "o1";
      symbol = "AAPL";
      side = Buy;
      quantity = 10.0;
      price = 100.0;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let portfolio =
    match Trading_portfolio.Portfolio.apply_single_trade base buy with
    | Ok p -> p
    | Error err -> OUnit2.assert_failure (Status.show err)
  in
  let summary =
    Portfolio_summary.of_portfolio portfolio ~position_value_total:1_050.0
  in
  assert_that
    (Portfolio_summary.find_position summary ~symbol:"AAPL")
    (is_some_and
       (field
          (fun (p : Portfolio_summary.position_summary) -> p.symbol)
          (equal_to "AAPL")));
  assert_that (Portfolio_summary.find_position summary ~symbol:"NVDA") is_none

(** [position_cost_basis_total] sums cost_basis across positions. Used by
    [Portfolio_state_computer] to derive UnrealizedPnl without needing the full
    [Portfolio.t]. *)
let test_position_cost_basis_total _ =
  let base = Trading_portfolio.Portfolio.create ~initial_cash:100_000.0 () in
  let buy =
    {
      Trading_base.Types.id = "b1";
      order_id = "o1";
      symbol = "AAPL";
      side = Buy;
      quantity = 10.0;
      price = 100.0;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let sell =
    {
      Trading_base.Types.id = "s1";
      order_id = "os";
      symbol = "BEAR";
      side = Sell;
      quantity = 50.0;
      price = 200.0;
      commission = 0.0;
      timestamp = Time_ns_unix.now ();
    }
  in
  let portfolio =
    match Trading_portfolio.Portfolio.apply_trades base [ buy; sell ] with
    | Ok p -> p
    | Error err -> OUnit2.assert_failure (Status.show err)
  in
  let summary =
    Portfolio_summary.of_portfolio portfolio ~position_value_total:0.0
  in
  (* +$1,000 (long AAPL) + (-$10,000) (short BEAR) = -$9,000. *)
  assert_that
    (Portfolio_summary.position_cost_basis_total summary)
    (float_equal (-9_000.0))

(** [empty] is a zero-cash placeholder with no positions. *)
let test_empty _ =
  assert_that Portfolio_summary.empty
    (all_of
       [
         field
           (fun (s : Portfolio_summary.t) -> s.current_cash)
           (float_equal 0.0);
         field (fun (s : Portfolio_summary.t) -> s.positions) (elements_are []);
         field
           (fun (s : Portfolio_summary.t) -> s.position_value_total)
           (float_equal 0.0);
       ])

(** [with_cash] is a placeholder with a specific cash value, no positions. *)
let test_with_cash _ =
  assert_that
    (Portfolio_summary.with_cash 50_000.0)
    (all_of
       [
         field
           (fun (s : Portfolio_summary.t) -> s.current_cash)
           (float_equal 50_000.0);
         field (fun (s : Portfolio_summary.t) -> s.positions) (elements_are []);
       ])

let suite =
  "Portfolio_summary tests"
  >::: [
         "of_portfolio empty" >:: test_of_portfolio_empty;
         "of_portfolio long position" >:: test_of_portfolio_with_long_position;
         "of_portfolio short position" >:: test_of_portfolio_with_short_position;
         "positions_count" >:: test_positions_count;
         "find_position" >:: test_find_position;
         "position_cost_basis_total" >:: test_position_cost_basis_total;
         "empty" >:: test_empty;
         "with_cash" >:: test_with_cash;
       ]

let () = run_test_tt_main suite
