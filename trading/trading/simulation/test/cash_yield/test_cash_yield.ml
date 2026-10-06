(** Tests for {!Trading_simulation_cash_yield.Cash_yield} (issue #3137 part 1):
    ACT/360 accrual on positive cash, the fee floor, forward-filled series, the
    loud pre-series error, and the interest base (no interest on negative cash,
    borrowed cash or short proceeds). *)

open OUnit2
open Core
open Matchers
module Cash_yield = Trading_simulation_cash_yield.Cash_yield
module Portfolio = Trading_portfolio.Portfolio

let _date = Date.of_string
let _portfolio ~cash = Portfolio.create ~initial_cash:cash ()

(* 3.6 %/yr with no fee is exactly 1 bp per day under ACT/360. *)
let _one_bp_a_day = Cash_yield.constant ~rate_pct:3.6 ~fee_bp:0.0

let _short_sale ~symbol ~quantity ~price : Trading_base.Types.trade =
  {
    id = "t1";
    order_id = "o1";
    symbol;
    side = Sell;
    quantity;
    price;
    commission = 0.0;
    timestamp = Time_ns_unix.now ();
  }

let _ok_exn = function Ok v -> v | Error e -> failwith (Status.show e)

let test_constant_accrual_one_day _ =
  assert_that
    (Cash_yield.accrue _one_bp_a_day ~date:(_date "2020-01-02")
       (_portfolio ~cash:1_000_000.0))
    (is_ok_and_holds
       (pair
          (field
             (fun (p : Portfolio.t) -> p.current_cash)
             (float_equal 1_000_100.0))
          (float_equal 100.0)))

(* Four calendar days stepped through an accrual armed from day 2: day 1 earns
   nothing (warmup), days 2-4 compound daily into cash. *)
let test_accrual_over_fixed_cash_path _ =
  let acc =
    Cash_yield.Accrual.create _one_bp_a_day ~start_date:(_date "2020-01-02")
  in
  let final =
    List.fold [ "2020-01-01"; "2020-01-02"; "2020-01-03"; "2020-01-04" ]
      ~init:(_portfolio ~cash:1_000_000.0) ~f:(fun p d ->
        _ok_exn (Cash_yield.Accrual.step (Some acc) ~date:(_date d) p))
  in
  let expected = 1_000_000.0 *. ((1.0001 ** 3.0) -. 1.0) in
  assert_that
    (final.current_cash, Cash_yield.Accrual.total acc)
    (pair
       (float_equal ~epsilon:1e-6 (1_000_000.0 +. expected))
       (float_equal ~epsilon:1e-6 expected))

let test_unarmed_step_is_identity _ =
  let p = _portfolio ~cash:1_000_000.0 in
  assert_that
    (Cash_yield.Accrual.step None ~date:(_date "2020-01-02") p)
    (is_ok_and_holds (equal_to ~cmp:Portfolio.equal p))

let test_fee_is_netted_and_floored_at_zero _ =
  let low = Cash_yield.constant ~rate_pct:0.05 ~fee_bp:10.0 in
  let normal = Cash_yield.constant ~rate_pct:4.0 ~fee_bp:10.0 in
  assert_that
    ( Cash_yield.net_annual_pct low (_date "2020-01-02"),
      Cash_yield.net_annual_pct normal (_date "2020-01-02") )
    (pair
       (is_ok_and_holds (float_equal 0.0))
       (is_ok_and_holds (float_equal 3.9)))

let test_negative_cash_accrues_nothing _ =
  let p = { (_portfolio ~cash:1_000.0) with current_cash = -500.0 } in
  assert_that
    (Cash_yield.accrue _one_bp_a_day ~date:(_date "2020-01-02") p)
    (is_ok_and_holds
       (pair
          (field
             (fun (p : Portfolio.t) -> p.current_cash)
             (float_equal (-500.0)))
          (float_equal 0.0)))

let test_base_excludes_margin_debit _ =
  let p = { (_portfolio ~cash:1_000.0) with long_margin_debit = 400.0 } in
  assert_that (Cash_yield.interest_base p) (float_equal 600.0)

let test_base_excludes_short_proceeds _ =
  let p =
    _ok_exn
      (Portfolio.apply_single_trade (_portfolio ~cash:1_000.0)
         (_short_sale ~symbol:"XYZ" ~quantity:10.0 ~price:20.0))
  in
  assert_that
    (p.current_cash, Cash_yield.interest_base p)
    (pair (float_equal 1_200.0) (float_equal 1_000.0))

let _fixture_series () =
  _ok_exn
    (Cash_yield.of_series
       [ (_date "2020-01-06", 5.0); (_date "2020-01-02", 3.0) ]
       ~fee_bp:10.0)

let test_series_forward_fills _ =
  let s = _fixture_series () in
  assert_that
    (List.map
       [ "2020-01-02"; "2020-01-04"; "2020-01-05"; "2020-01-06"; "2020-02-01" ]
       ~f:(fun d -> Cash_yield.net_annual_pct s (_date d)))
    (elements_are
       [
         is_ok_and_holds (float_equal 2.9);
         is_ok_and_holds (float_equal 2.9);
         is_ok_and_holds (float_equal 2.9);
         is_ok_and_holds (float_equal 4.9);
         is_ok_and_holds (float_equal 4.9);
       ])

let test_date_before_series_is_error _ =
  assert_that
    (Cash_yield.accrue (_fixture_series ()) ~date:(_date "2020-01-01")
       (_portfolio ~cash:1_000.0))
    (is_error_with Status.Invalid_argument)

let test_period_rate_sums_calendar_days _ =
  (* Fri 01-03 -> Mon 01-06: Sat + Sun at 2.9 %, Mon at 4.9 %. *)
  assert_that
    (Cash_yield.period_rate (_fixture_series ()) ~from_:(_date "2020-01-03")
       ~to_:(_date "2020-01-06"))
    (is_ok_and_holds (float_equal (((2.0 *. 2.9) +. 4.9) /. 100.0 /. 360.0)))

let test_parse_csv_skips_header_and_missing _ =
  assert_that
    (Cash_yield.parse_series_csv
       "observation_date,DTB3\n\
        2020-01-02,3.00\n\
        2020-01-03,.\n\
        2020-01-06,\n\
        2020-01-07,5.5\n")
    (is_ok_and_holds
       (elements_are
          [
            equal_to (_date "2020-01-02", 3.0);
            equal_to (_date "2020-01-07", 5.5);
          ]))

let test_parse_csv_rejects_malformed_row _ =
  assert_that
    (Cash_yield.parse_series_csv "2020-01-02,3.00\n2020-01-03,abc\n")
    (is_error_with Status.Invalid_argument)

let test_resolve_sources _ =
  assert_that
    ( Cash_yield.resolve No_yield ~fee_bp:10.0 ~data_dir:".",
      Cash_yield.resolve (Series "dtb3_fixture.csv") ~fee_bp:10.0 ~data_dir:".",
      Cash_yield.resolve (Series "no_such_file.csv") ~fee_bp:10.0 ~data_dir:"."
    )
    (all_of
       [
         field (fun (a, _, _) -> a) (is_ok_and_holds is_none);
         field
           (fun (_, b, _) ->
             Result.map b
               ~f:
                 (Option.map ~f:(fun s ->
                      Cash_yield.net_annual_pct s (_date "2020-01-07"))))
           (is_ok_and_holds (is_some_and (is_ok_and_holds (float_equal 4.9))));
         field (fun (_, _, c) -> c) is_error;
       ])

let test_source_sexp_round_trip _ =
  assert_that
    (List.map [ "No_yield"; "(Constant 4.5)"; "(Series macro/x.csv)" ]
       ~f:(fun s -> Cash_yield.source_of_sexp (Sexp.of_string s)))
    (elements_are
       [
         equal_to Cash_yield.No_yield;
         equal_to (Cash_yield.Constant 4.5);
         equal_to (Cash_yield.Series "macro/x.csv");
       ])

let suite =
  "cash_yield"
  >::: [
         "constant accrual, one day" >:: test_constant_accrual_one_day;
         "accrual over a fixed cash path" >:: test_accrual_over_fixed_cash_path;
         "unarmed step is identity" >:: test_unarmed_step_is_identity;
         "fee netted, floored at 0" >:: test_fee_is_netted_and_floored_at_zero;
         "negative cash accrues nothing" >:: test_negative_cash_accrues_nothing;
         "base excludes margin debit" >:: test_base_excludes_margin_debit;
         "base excludes short proceeds" >:: test_base_excludes_short_proceeds;
         "series forward-fills" >:: test_series_forward_fills;
         "date before series is an error" >:: test_date_before_series_is_error;
         "period rate sums calendar days"
         >:: test_period_rate_sums_calendar_days;
         "csv skips header and missing"
         >:: test_parse_csv_skips_header_and_missing;
         "csv rejects malformed row" >:: test_parse_csv_rejects_malformed_row;
         "resolve sources" >:: test_resolve_sources;
         "source sexp round trip" >:: test_source_sexp_round_trip;
       ]

let () = run_test_tt_main suite
