open Core

(* ------------------------------------------------------------------ *)
(* Defaults                                                             *)
(* ------------------------------------------------------------------ *)

(* Minimum |split_factor -. 1.0| to treat the day as a split candidate.
   Splits are always >= 1.5x or <= 0.67x; dividends are typically < 1%. A
   5% band cleanly separates the two while leaving headroom for thin-bar
   noise on illiquid names. *)
let default_dividend_threshold = 0.05

(* Tolerance when matching the raw ratio against [N/M]. Floating-point
   ratios from real EODHD bars are accurate to several decimals; 1e-3 is
   tight enough to reject coincidences and loose enough to accept
   real-world numerical noise. *)
let default_rational_snap_tolerance = 1e-3

(* Largest denominator considered when snapping. Real splits are tiny
   rationals — 4:1, 1:5, 3:2, 2:3, 1:10, 1:20. 20 is comfortably above
   anything we expect to see in practice. *)
let default_max_denominator = 20

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

(* Guard against degenerate bars: zero or negative prices break the
   ratio computation and shouldn't ever appear in real data. We treat
   them as "no detectable split" rather than raising — a bad bar in the
   feed is not the detector's problem. *)
let _is_positive x = Float.( > ) x 0.0

let _has_valid_prices ~(prev : Daily_price.t) ~(curr : Daily_price.t) =
  _is_positive prev.close_price
  && _is_positive curr.close_price
  && _is_positive prev.adjusted_close
  && _is_positive curr.adjusted_close

(* Snap [x] to the nearest rational [N/M] with [1 <= M <= max_denominator]
   and any positive [N], requiring [|x -. N/M| <= tolerance]. Returns the
   matched rational as a float, or [None] if no candidate is within
   tolerance. We pick the smallest denominator that works (lowest
   complexity), matching how splits are conventionally written. *)
let _snap_to_rational ~tolerance ~max_denominator x =
  let best = ref None in
  for m = 1 to max_denominator do
    let n = Float.round_nearest (x *. Float.of_int m) in
    let candidate = n /. Float.of_int m in
    if Float.( <= ) (Float.abs (x -. candidate)) tolerance then
      match !best with None -> best := Some candidate | Some _ -> ()
  done;
  !best

(* ------------------------------------------------------------------ *)
(* Detection                                                            *)
(* ------------------------------------------------------------------ *)

let detect_split ?(dividend_threshold = default_dividend_threshold)
    ?(rational_snap_tolerance = default_rational_snap_tolerance)
    ?(max_denominator = default_max_denominator) ~(prev : Daily_price.t)
    ~(curr : Daily_price.t) () =
  if not (_has_valid_prices ~prev ~curr) then None
  else
    let raw_ratio = curr.close_price /. prev.close_price in
    let adj_ratio = curr.adjusted_close /. prev.adjusted_close in
    if Float.( = ) raw_ratio 0.0 then None
    else
      let split_factor = adj_ratio /. raw_ratio in
      if Float.( <= ) (Float.abs (split_factor -. 1.0)) dividend_threshold then
        None
      else
        _snap_to_rational ~tolerance:rational_snap_tolerance ~max_denominator
          split_factor
