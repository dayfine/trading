open OUnit2
open Matchers
open Trading_base.Types
open Trading_orders.Types

let _t0 = Time_ns_unix.of_string "2024-03-15 09:30:00.123456789Z"

let _make id side order_type status avg =
  {
    id;
    symbol = "AAPL";
    side;
    order_type;
    quantity = 33.333333333333336;
    time_in_force = GTC;
    status;
    filled_quantity = 0.1 +. 0.2;
    avg_fill_price = avg;
    created_at = _t0;
    updated_at = _t0;
  }

let _orders =
  [
    _make "o1" Buy Market Pending None;
    _make "o2" Sell (Limit 123.456789012345) (PartiallyFilled 12.5) (Some 99.99);
    _make "o3" Buy (Stop 50.000000000001) Filled (Some 50.1);
    _make "o4" Sell (StopLimit (49.5, 49.25)) Cancelled None;
    _make "o5" Buy Market (Rejected "no cash") None;
  ]

let test_order_roundtrip _ =
  assert_that
    (List.map (fun o -> o |> sexp_of_order |> order_of_sexp) _orders)
    (equal_to (_orders : order list))

let test_tif_roundtrip _ =
  let all = [ Day; GTC; IOC; FOK ] in
  assert_that
    (List.map
       (fun v -> v |> sexp_of_time_in_force |> time_in_force_of_sexp)
       all)
    (equal_to (all : time_in_force list))

let suite =
  "types_sexp"
  >::: [ "order" >:: test_order_roundtrip; "tif" >:: test_tif_roundtrip ]

let () = run_test_tt_main suite
