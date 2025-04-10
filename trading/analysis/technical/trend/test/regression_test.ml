open OUnit2
open Trend_lib.Regression_test

let float_equal ?(epsilon = 0.0001) a b = abs_float (a -. b) < epsilon

let test_perfect_line _ =
  (* Test with a perfect line y = 2x + 1 *)
  let x = [| 0.; 1.; 2.; 3.; 4. |] in
  let y = [| 1.; 3.; 5.; 7.; 9. |] in
  let x_arr = Owl.Dense.Ndarray.S.of_array x [| Array.length x |] in
  let y_arr = Owl.Dense.Ndarray.S.of_array y [| Array.length y |] in

  let intercept, slope = linear_regression x_arr y_arr in
  assert_bool "Intercept should be 1.0" (float_equal 1.0 intercept);
  assert_bool "Slope should be 2.0" (float_equal 2.0 slope);

  (* Test R-squared should be 1.0 for perfect fit *)
  let r2 = r_squared x y in
  assert_bool "R-squared should be 1.0" (float_equal 1.0 r2)

let test_noisy_line _ =
  (* Test with a noisy line around y = x *)
  let x = [| 0.; 1.; 2.; 3.; 4. |] in
  let y = [| 0.1; 0.9; 2.2; 2.8; 4.1 |] in
  let x_arr = Owl.Dense.Ndarray.S.of_array x [| Array.length x |] in
  let y_arr = Owl.Dense.Ndarray.S.of_array y [| Array.length y |] in

  let intercept, slope = linear_regression x_arr y_arr in
  (* Slope should be close to 1 and intercept close to 0 *)
  assert_bool "Slope should be close to 1" (abs_float (slope -. 1.0) < 0.1);
  assert_bool "Intercept should be close to 0" (abs_float intercept < 0.2);

  (* R-squared should be high but less than 1 *)
  let r2 = r_squared x y in
  assert_bool "R-squared should be between 0.95 and 1.0" (r2 > 0.95 && r2 < 1.0)

let test_flat_line _ =
  (* Test with a horizontal line y = 2 *)
  let x = [| 0.; 1.; 2.; 3.; 4. |] in
  let y = [| 2.; 2.; 2.; 2.; 2. |] in
  let x_arr = Owl.Dense.Ndarray.S.of_array x [| Array.length x |] in
  let y_arr = Owl.Dense.Ndarray.S.of_array y [| Array.length y |] in

  let intercept, slope = linear_regression x_arr y_arr in
  assert_bool "Intercept should be 2.0" (float_equal 2.0 intercept);
  assert_bool "Slope should be 0.0" (float_equal 0.0 slope)

let test_prediction _ =
  (* Test prediction with y = 2x + 1 *)
  let x_train = [| 0.; 1.; 2. |] in
  let y_train = [| 1.; 3.; 5. |] in
  let x_arr = Owl.Dense.Ndarray.S.of_array x_train [| Array.length x_train |] in
  let y_arr = Owl.Dense.Ndarray.S.of_array y_train [| Array.length y_train |] in

  let intercept, slope = linear_regression x_arr y_arr in
  let x_test = [| 3.; 4. |] in
  let y_pred =
    predict_values x_test intercept slope |> Owl.Dense.Ndarray.S.to_array
  in

  assert_bool "First prediction should be 7.0" (float_equal 7.0 y_pred.(0));
  assert_bool "Second prediction should be 9.0" (float_equal 9.0 y_pred.(1))

let suite =
  "regression_test"
  >::: [
         "test_perfect_line" >:: test_perfect_line;
         "test_noisy_line" >:: test_noisy_line;
         "test_flat_line" >:: test_flat_line;
         "test_prediction" >:: test_prediction;
       ]

let () = run_test_tt_main suite
