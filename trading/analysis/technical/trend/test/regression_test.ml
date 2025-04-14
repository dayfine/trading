open OUnit2
open Trend.Regression

let float_equal ?(epsilon = 0.0001) a b = abs_float (a -. b) < epsilon

let test_linear_regression _ =
  let x = [| 1.; 2.; 3.; 4.; 5. |] in
  let y = [| 2.; 4.; 6.; 8.; 10. |] in
  let stats = calculate_stats x y in
  assert_equal ~msg:"Slope should be 2.0" ~cmp:float_equal 2.0 stats.slope;
  assert_equal ~msg:"Intercept should be 0.0" ~cmp:float_equal 0.0
    stats.intercept;
  assert_equal ~msg:"R-squared should be 1.0" ~cmp:float_equal 1.0
    stats.r_squared

let test_r_squared _ =
  let x = [| 1.; 2.; 3.; 4.; 5. |] in
  let y = [| 2.1; 3.8; 6.2; 7.9; 9.8 |] in
  let stats = calculate_stats x y in
  assert_bool "R-squared should be close to 1.0" (stats.r_squared > 0.99)

let test_perfect_line _ =
  (* Test with a perfect line y = 2x + 1 *)
  let x = [| 0.; 1.; 2.; 3.; 4. |] in
  let y = [| 1.; 3.; 5.; 7.; 9. |] in
  let stats = calculate_stats x y in
  assert_equal ~msg:"Slope should be 2.0" ~cmp:float_equal 2.0 stats.slope;
  assert_equal ~msg:"Intercept should be 1.0" ~cmp:float_equal 1.0
    stats.intercept;
  assert_equal ~msg:"R-squared should be 1.0" ~cmp:float_equal 1.0
    stats.r_squared

let test_predict _ =
  let x = [| 1.; 2.; 3.; 4.; 5. |] in
  let y = [| 2.; 4.; 6.; 8.; 10. |] in
  let stats = calculate_stats x y in
  let predicted = predict ~intercept:stats.intercept ~slope:stats.slope 3.0 in
  assert_equal ~msg:"Prediction should be 6.0" ~cmp:float_equal 6.0 predicted

let suite =
  "regression"
  >::: [
         "test_linear_regression" >:: test_linear_regression;
         "test_r_squared" >:: test_r_squared;
         "test_perfect_line" >:: test_perfect_line;
         "test_predict" >:: test_predict;
       ]

let () = run_test_tt_main suite
