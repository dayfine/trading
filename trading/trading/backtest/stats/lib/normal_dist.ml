open Core

let cdf z = 0.5 *. (1.0 +. Owl.Maths.erf (z /. Float.sqrt 2.0))

let inv_cdf p =
  if Float.(p <= 0.0) || Float.(p >= 1.0) then
    invalid_arg
      (Printf.sprintf "Normal_dist.inv_cdf: p must be in (0, 1), got %.17g" p);
  Float.sqrt 2.0 *. Owl.Maths.erfinv ((2.0 *. p) -. 1.0)
