open Core
open OUnit2
open Trading_base.Types
open Trading_portfolio.Types

(* Float comparison with epsilon tolerance *)
let assert_float_equal ?(epsilon = 1e-9) expected actual ~msg =
  let cmp a b = Float.(abs (a - b) < epsilon) in
  assert_equal expected actual ~cmp ~msg

(* Create a trade for testing *)
let make_trade ~id ~order_id ~symbol ~side ~quantity ~price ?(commission = 0.0)
    () =
  {
    id;
    order_id;
    symbol;
    side;
    quantity;
    price;
    commission;
    timestamp = Time_ns_unix.now ();
  }

(* Create a position for testing *)
let make_position ~symbol ~quantity ~avg_cost = { symbol; quantity; avg_cost }
