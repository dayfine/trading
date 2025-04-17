open OUnit2
open Trend.Regression

let test_linear_regression _ =
  (* Test with y = 2x (perfect line) *)
  let y = [| 0.; 2.; 4.; 6.; 8.; 10. |] in
  let stats = calculate_stats y in
  assert_equal ~printer:show_regression_stats stats
    { intercept = 0.0; slope = 2.0; r_squared = 1.0; residual_std = 0.0 }

let test_r_squared _ =
  (* Test with slightly noisy data *)
  let y = [| 2.1; 3.8; 6.2; 7.9; 9.8 |] in
  let stats = calculate_stats y in
  assert_bool "R-squared should be close to 1.0" (stats.r_squared > 0.99)

let test_perfect_line _ =
  (* Test with a perfect line y = 2x + 1 *)
  let y = [| 1.; 3.; 5.; 7.; 9. |] in
  let stats = calculate_stats y in
  assert_equal ~printer:show_regression_stats stats
    { intercept = 1.0; slope = 2.0; r_squared = 1.0; residual_std = 0.0 }

let suite =
  "regression"
  >::: [
         "test_linear_regression" >:: test_linear_regression;
         "test_r_squared" >:: test_r_squared;
         "test_perfect_line" >:: test_perfect_line;
       ]

let () = run_test_tt_main suite
