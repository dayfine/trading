open Core

type params = {
  spike_mult : float;
  median_window : int;
  revert_frac : float;
  price_ceiling : float;
}
[@@deriving sexp_of]

let default_params =
  {
    spike_mult = 5.0;
    median_window = 5;
    revert_frac = 0.5;
    price_ceiling = 5.0;
  }

type bar = { date : Core.Date.t; close : float } [@@deriving sexp_of]

type hit = {
  date : Core.Date.t;
  prev_close : float;
  spike_close : float;
  next_close : float;
  ratio : float;
}
[@@deriving sexp_of, equal]

(* Median of a non-empty float list; [None] when empty. Even length averages the
   two central order statistics. *)
let _median = function
  | [] -> None
  | xs ->
      let sorted = Array.of_list (List.sort xs ~compare:Float.compare) in
      let n = Array.length sorted in
      if n % 2 = 1 then Some sorted.(n / 2)
      else Some ((sorted.((n / 2) - 1) +. sorted.(n / 2)) /. 2.0)

(* Median close over the [±k] bars around [t], excluding [t] itself, clamped to
   the array bounds. *)
let _surrounding_median bars ~t ~k =
  let n = Array.length bars in
  let lo = Int.max 0 (t - k) in
  let hi = Int.min (n - 1) (t + k) in
  List.range lo (hi + 1)
  |> List.filter_map ~f:(fun j -> if j = t then None else Some bars.(j).close)
  |> _median

(* The three spike-revert predicates, split out so [_check_index] reads as a
   flat conjunction rather than nested conditionals. *)
let _below_ceiling ~params ~median = Float.(median < params.price_ceiling)

let _is_spike ~params ~median ~close =
  Float.(close >= params.spike_mult *. median)

let _reverts ~params ~close ~next_close =
  Float.(next_close <= params.revert_frac *. close)

(* Build the hit record for a qualifying spike bar [t] (guaranteed to have a
   successor). [prev_close] is [Float.nan] when [t] is the first bar. *)
let _make_hit bars ~t ~median =
  let close = bars.(t).close in
  {
    date = bars.(t).date;
    prev_close = (if t > 0 then bars.(t - 1).close else Float.nan);
    spike_close = close;
    next_close = bars.(t + 1).close;
    ratio = close /. median;
  }

(* Test bar [t] (guaranteed to have a successor) against the spike-revert
   criteria; returns the hit when it qualifies. *)
let _check_index bars ~params ~t =
  match _surrounding_median bars ~t ~k:params.median_window with
  | None -> None
  | Some median ->
      let close = bars.(t).close in
      let next_close = bars.(t + 1).close in
      Option.some_if
        (_below_ceiling ~params ~median
        && _is_spike ~params ~median ~close
        && _reverts ~params ~close ~next_close)
        (_make_hit bars ~t ~median)

let detect ~params bars =
  let n = Array.length bars in
  (* Last bar has no successor to check the revert against. *)
  List.range 0 (Int.max 0 (n - 1))
  |> List.filter_map ~f:(fun t -> _check_index bars ~params ~t)
