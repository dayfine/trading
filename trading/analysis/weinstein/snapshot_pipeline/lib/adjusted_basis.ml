open Core

(* Split/dividend factor for one bar: [adjusted_close /. close_price], the same
   ratio the chart-side rescale in Svg_series.weekly_bars applies. That copy
   stays private and separate on purpose: Weinstein_snapshot (this module's
   sibling library) deliberately carries no analysis/ dependency (see
   svg_series.mli), so it cannot call this function directly — the formula is
   intentionally duplicated across the layering boundary, not merely
   unswitched-over. Keep both in sync by hand if this formula ever changes.
   A non-positive / NaN raw close admits no factor -> [1.0] (the O/H/L stay raw
   and the close takes [adjusted_close]); a corrupt raw close must not blow up.
   The guard is one-sided (inherited from the chart-side copy): a corrupt
   [adjusted_close] is NOT guarded — see the .mli. *)
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
