open Owl
module Arr = Dense.Ndarray.S
module Linalg = Linalg.S

type regression_stats = {
  intercept : float;  (** Y-intercept of the regression line *)
  slope : float;  (** Slope of the regression line *)
  r_squared : float;  (** Coefficient of determination *)
  residual_std : float;  (** Standard deviation of residuals *)
}

let calculate_stats x_data y_data =
  (* Check for minimum points *)
  let n = Array.length x_data in
  if n < 2 then
    { intercept = 0.; slope = 0.; r_squared = 0.; residual_std = 0. }
  else
    (* Convert inputs to 2D arrays *)
    let x = Arr.of_array x_data [| n; 1 |] in
    let y = Arr.of_array y_data [| n; 1 |] in

    (* Perform regression with intercept *)
    let intercept, slope = Linalg.linreg x y in

    (* Calculate predictions and residuals *)
    let predicted = Arr.map (fun x -> intercept +. (slope *. x)) x in
    let residuals = Arr.(y - predicted) in

    (* Calculate R-squared *)
    let y_mean = Arr.mean' y in
    let y_mean_arr = Arr.create [| n |] y_mean in
    let ss_total = Arr.(sum' (sqr (y - y_mean_arr))) in
    let ss_residual = Arr.(sum' (sqr residuals)) in
    let r_squared =
      if ss_total = 0. then 1. else 1. -. (ss_residual /. ss_total)
    in

    (* Calculate residual standard deviation *)
    let residual_std =
      if n = 2 then 0.  (* For 2 points, std dev is always 0 *)
      else Stats.std (Arr.to_array residuals)
    in

    { intercept; slope; r_squared; residual_std }

let predict ~intercept ~slope x = intercept +. (slope *. x)

let predict_values x intercept slope =
  let x = Arr.of_array x [| Array.length x |] in
  Arr.map (fun xi -> intercept +. (slope *. xi)) x
