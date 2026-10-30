open OUnit2
open Matchers
open Trading_engine.Types

let test_roundtrip _ =
  let bars =
    [
      {
        symbol = "AAPL";
        open_price = 123.456789012345;
        high_price = 125.000000000001;
        low_price = 0.1 +. 0.2;
        close_price = 124.99999999999999;
      };
      {
        symbol = "X";
        open_price = 1.0;
        high_price = 1.0;
        low_price = 1.0;
        close_price = 1.0;
      };
    ]
  in
  assert_that
    (List.map (fun b -> b |> sexp_of_price_bar |> price_bar_of_sexp) bars)
    (equal_to (bars : price_bar list))

let suite = "price_bar_sexp" >::: [ "roundtrip" >:: test_roundtrip ]
let () = run_test_tt_main suite
