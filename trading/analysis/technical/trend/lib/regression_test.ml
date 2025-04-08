open Owl
module Arr = Dense.Ndarray.S
module Linalg = Linalg.S

(* Simple linear regression wrapper *)
let linear_regression x y =
  (* Convert inputs to 2D arrays *)
  let n = (Arr.shape x).(0) in
  let x = Arr.reshape x [|n; 1|] in
  let y = Arr.reshape y [|n; 1|] in

  (* Perform regression with intercept *)
  let (intercept, slope) = Linalg.linreg x y in
  (intercept, slope)

(* Predict values using regression coefficients *)
let predict_values x intercept slope =
  let x = Arr.of_array x [|Array.length x|] in
  Arr.map (fun xi -> intercept +. slope *. xi) x

(* Calculate R-squared *)
let r_squared x y =
  let n = Array.length x in
  let x = Arr.of_array x [|n|] in
  let y = Arr.of_array y [|n|] in

  let (intercept, slope) = linear_regression x y in
  let y_pred = predict_values (Arr.to_array x) intercept slope in

  let y_mean = Arr.mean' y in
  let ss_total = Arr.(sum' (sqr (y - (create [|n|] y_mean)))) in
  let ss_residual = Arr.(sum' (sqr (y - y_pred))) in

  if ss_total = 0. then 1. else 1. -. (ss_residual /. ss_total)
