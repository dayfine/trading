open Core

(* Split/dividend factor for one bar: [adjusted_close /. close_price], the same
   ratio {!Weinstein_snapshot.Svg_series._to_adjusted_basis} applies chart-side.
   A non-positive / NaN raw close admits no factor -> [1.0] (the O/H/L stay raw
   and the close takes [adjusted_close]); a corrupt bar must not blow up. *)
let _factor (b : Types.Daily_price.t) : float =
  if Float.is_nan b.close_price || Float.( <= ) b.close_price 0.0 then 1.0
  else b.adjusted_close /. b.close_price

let to_adjusted_basis (b : Types.Daily_price.t) : Types.Daily_price.t =
  let f = _factor b in
  {
    b with
    open_price = b.open_price *. f;
    high_price = b.high_price *. f;
    low_price = b.low_price *. f;
    close_price = b.adjusted_close;
  }
