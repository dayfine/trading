open Core

(* Bounds for the percentile argument, named so the magic-number linter does not
   trip on the [0.0]/[100.0] literals and so the contract is self-documenting. *)
let _pct_min = 0.0
let _pct_max = 100.0

(** Read [sorted] at fractional [rank] via linear interpolation between the
    bracketing integer ranks. When [rank] is an integer, [lo = hi] and
    [frac = 0.0], so this returns [sorted.(rank)] exactly — subsuming the
    no-interpolation case without a branch. [rank] is always in [0, n-1] for the
    callers here. *)
let _interp (sorted : float array) ~rank =
  let lo = Int.of_float (Float.round_down rank) in
  let hi = Int.of_float (Float.round_up rank) in
  let frac = rank -. float_of_int lo in
  sorted.(lo) +. (frac *. (sorted.(hi) -. sorted.(lo)))

(** Linear-interpolation percentile over an ascending [sorted] array. Caller has
    already established [n > 0]. Mirrors NumPy's default ("linear" / type-7):
    rank [r = p/100 * (n - 1)], read between the bracketing ranks. *)
let _percentile_of_sorted (sorted : float array) ~p =
  let n = Array.length sorted in
  if n = 1 then sorted.(0)
  else _interp sorted ~rank:(p /. _pct_max *. float_of_int (n - 1))

let _sorted_array xs =
  let arr = Array.of_list xs in
  Array.sort arr ~compare:Float.compare;
  arr

let percentile xs ~p =
  if Float.( < ) p _pct_min || Float.( > ) p _pct_max then
    invalid_arg
      (Printf.sprintf "percentile: p=%g out of [%g, %g]" p _pct_min _pct_max);
  match xs with
  | [] -> Float.nan
  | _ -> _percentile_of_sorted (_sorted_array xs) ~p

(* Cut points (named so the magic-number linter does not trip and the contract
   is self-documenting). *)
let _p25 = 25.0
let _p50 = 50.0
let _p75 = 75.0
let median xs = percentile xs ~p:_p50

let iqr xs =
  match xs with
  | [] -> Float.nan
  | _ ->
      let sorted = _sorted_array xs in
      _percentile_of_sorted sorted ~p:_p75
      -. _percentile_of_sorted sorted ~p:_p25

type summary = {
  n : int;
  median : float;
  p10 : float;
  iqr : float;
  min : float;
  max : float;
}
[@@deriving sexp, equal]

(* 10th-percentile cut point (pessimistic tail). *)
let _p10 = 10.0

(* Empty-input summary: all-NaN with a zero count. *)
let _empty_summary =
  {
    n = 0;
    median = Float.nan;
    p10 = Float.nan;
    iqr = Float.nan;
    min = Float.nan;
    max = Float.nan;
  }

let summarize xs =
  match xs with
  | [] -> _empty_summary
  | _ ->
      let sorted = _sorted_array xs in
      let n = Array.length sorted in
      let pct p = _percentile_of_sorted sorted ~p in
      {
        n;
        median = pct _p50;
        p10 = pct _p10;
        iqr = pct _p75 -. pct _p25;
        min = sorted.(0);
        max = sorted.(n - 1);
      }
