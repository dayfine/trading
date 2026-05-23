(* Closed-form univariate least-squares regression with x = 0..n-1.

   This replaces the prior Owl/LAPACK-based implementation, which produced
   non-deterministic float-sum ordering between runs (~1e-8 drift on
   r_squared, ~6.8e-8 on channel-width-equivalent residuals). The math
   below is pure OCaml — every sum is a fixed-order sequential
   Array.fold_left, so the result is bit-identical across cores and
   thread counts. See dayfine/trading#1269 for the original flake. *)

type regression_stats = {
  intercept : float;  (** Y-intercept of the regression line *)
  slope : float;  (** Slope of the regression line *)
  r_squared : float;  (** Coefficient of determination *)
  residual_std : float;  (** Sample standard deviation of residuals (n-1) *)
}
[@@deriving show, eq]

(** Sequential, fixed-order sum over [0, n). Deterministic by construction.
    Used instead of Owl reductions or List.fold_left on a Seq, both of
    which open the door to backend-dependent reordering. *)
let _sum_to n f =
  let s = ref 0.0 in
  for i = 0 to n - 1 do
    s := !s +. f i
  done;
  !s

let calculate_stats y_data =
  let n = Array.length y_data in
  if n < 2 then
    { intercept = 0.0; slope = 0.0; r_squared = 0.0; residual_std = 0.0 }
  else
    let nf = float_of_int n in
    let sum_x = _sum_to n float_of_int in
    let sum_y = _sum_to n (fun i -> y_data.(i)) in
    let sum_xx =
      _sum_to n (fun i ->
          let x = float_of_int i in
          x *. x)
    in
    let sum_xy = _sum_to n (fun i -> float_of_int i *. y_data.(i)) in
    let mean_x = sum_x /. nf in
    let mean_y = sum_y /. nf in
    (* slope = Σ(x_i − x̄)(y_i − ȳ) / Σ(x_i − x̄)² ;
       using the algebraically equivalent computational form keeps both
       sums in the same loop pattern as above. *)
    let denom = sum_xx -. (nf *. mean_x *. mean_x) in
    let slope =
      if denom = 0.0 then 0.0 else (sum_xy -. (nf *. mean_x *. mean_y)) /. denom
    in
    let intercept = mean_y -. (slope *. mean_x) in
    let ss_total =
      _sum_to n (fun i ->
          let d = y_data.(i) -. mean_y in
          d *. d)
    in
    let ss_residual =
      _sum_to n (fun i ->
          let x = float_of_int i in
          let pred = intercept +. (slope *. x) in
          let r = y_data.(i) -. pred in
          r *. r)
    in
    let r_squared =
      if ss_total = 0.0 then 1.0 else 1.0 -. (ss_residual /. ss_total)
    in
    let residual_std =
      if n = 2 then 0.0 else Float.sqrt (ss_residual /. float_of_int (n - 1))
    in
    { intercept; slope; r_squared; residual_std }
