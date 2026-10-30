open OUnit2
open Core
open Matchers
open Trading_simulation_types.Simulator_types

let _d = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15
let _t0 = Time_ns_unix.of_string "2024-03-15 09:30:00.123456789Z"

let _order : Trading_orders.Types.order =
  {
    id = "o1";
    symbol = "AAPL";
    side = Buy;
    order_type = Limit 123.456789012345;
    quantity = 10.0;
    time_in_force = Day;
    status = Pending;
    filled_quantity = 0.0;
    avg_fill_price = None;
    created_at = _t0;
    updated_at = _t0;
  }

let _trade : Trading_base.Types.trade =
  {
    id = "t1";
    order_id = "o1";
    symbol = "AAPL";
    side = Sell;
    quantity = 10.0;
    price = 0.1 +. 0.2;
    commission = 1.0000000000001;
    timestamp = _t0;
  }

let _step =
  {
    date = _d;
    portfolio =
      {
        Trading_simulation_types.Portfolio_summary.empty with
        current_cash = 12345.678901234567;
      };
    portfolio_value = 99999.99999999999;
    trades = [ _trade ];
    orders_submitted = [ _order ];
    splits_applied =
      [
        {
          Trading_portfolio.Split_event.symbol = "AAPL";
          date = _d;
          factor = 4.0;
        };
      ];
    benchmark_return = Some (-0.0123456789012);
    had_market_bars = true;
  }

(* [Time_ns_unix.sexp_of_t] reads the local zone, so these tests cannot run
   where /etc/localtime is absent (the CI image). They run in dev containers. *)
let _skip_without_local_zone () =
  skip_if (not (Stdlib.Sys.file_exists "/etc/localtime")) "no /etc/localtime"

let test_roundtrip _ =
  _skip_without_local_zone ();
  assert_that
    (List.map
       [
         _step;
         {
           _step with
           benchmark_return = None;
           trades = [];
           orders_submitted = [];
           splits_applied = [];
           had_market_bars = false;
         };
       ]
       ~f:(fun s -> s |> sexp_of_step_result |> step_result_of_sexp))
    (equal_to
       ([
          _step;
          {
            _step with
            benchmark_return = None;
            trades = [];
            orders_submitted = [];
            splits_applied = [];
            had_market_bars = false;
          };
        ]
         : step_result list))

let suite = "step_result_sexp" >::: [ "roundtrip" >:: test_roundtrip ]
let () = run_test_tt_main suite
