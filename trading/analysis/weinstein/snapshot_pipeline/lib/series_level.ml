open Core

module Config = struct
  type t = { enabled : bool; median_close_max : float; min_bars : int }
  [@@deriving sexp, equal]

  let default = { enabled = false; median_close_max = 10_000.0; min_bars = 20 }
end

module Class = struct
  type t = Whole_window | Mixed_scale [@@deriving sexp_of, compare, equal]

  let to_string = function
    | Whole_window -> "whole_window"
    | Mixed_scale -> "mixed_scale"
end

type finding = {
  symbol : string;
  klass : Class.t;
  n_bars : int;
  first_date : Date.t;
  last_date : Date.t;
  median_close : float;
  min_close : float;
  max_close : float;
  n_above : int;
}
[@@deriving sexp_of, compare, equal]

(* A non-finite close is dropped before ANY statistic is taken, not merely
   before the median. [Float.compare] orders nan below every real price, so a
   series carrying a few of them would hand back nan as its own minimum and, at
   enough of them, as its median — writing [nan] into the report. Series_tail
   guards its reference close for the same reason. Dropping them up front keeps
   every reported field describing one consistent set of bars. *)
let _finite_bars bars =
  List.filter bars ~f:(fun (b : Types.Daily_price.t) ->
      Float.is_finite b.close_price)

let _sorted_closes bars =
  let closes =
    Array.of_list_map bars ~f:(fun (b : Types.Daily_price.t) -> b.close_price)
  in
  Array.sort closes ~compare:Float.compare;
  closes

(* The span is the earliest and latest date rather than the first and last
   element, so a caller that hands over unsorted bars gets the same row as one
   that does not. Every other field is order-independent already. *)
let _sorted_dates bars =
  let dates =
    Array.of_list_map bars ~f:(fun (b : Types.Daily_price.t) -> b.date)
  in
  Array.sort dates ~compare:Date.compare;
  dates

(* Identical to [Validator_store_check._v18_median_close], deliberately: the
   build-time and post-run halves of this check must never disagree about the
   same series. Even lengths take the mean of the two central closes. *)
let _median_close (sorted : float array) =
  let n = Array.length sorted in
  let upper = sorted.(n / 2) in
  if n % 2 = 1 then upper else (sorted.((n / 2) - 1) +. upper) /. 2.0

(* [n_above = n_bars] is the whole discriminator between the two classes: it
   says there is no bar at a plausible level anywhere in the stored window, so
   no cut can keep a real segment and neither Series_tail nor Splice_detector
   has a discontinuity to key on. Anything else carries two scales and the seam
   is in-window, where the shape rules can already see it. *)
let _finding (c : Config.t) ~symbol ~closes ~dates ~median =
  let n = Array.length closes in
  let n_above =
    Array.count closes ~f:(fun v -> Float.( > ) v c.median_close_max)
  in
  {
    symbol;
    klass = (if n_above = n then Class.Whole_window else Class.Mixed_scale);
    n_bars = n;
    first_date = dates.(0);
    last_date = dates.(n - 1);
    median_close = median;
    min_close = closes.(0);
    max_close = closes.(n - 1);
    n_above;
  }

(* [Int.max 1] so a zero or negative [min_bars] still cannot ask for the median
   of an empty series; V18's step guard reads the same way. *)
let classify (c : Config.t) ~symbol bars =
  if not c.enabled then None
  else
    let bars = _finite_bars bars in
    if List.length bars < Int.max 1 c.min_bars then None
    else
      let closes = _sorted_closes bars in
      let median = _median_close closes in
      if Float.( <= ) median c.median_close_max then None
      else Some (_finding c ~symbol ~closes ~dates:(_sorted_dates bars) ~median)

let whole_window_symbols findings =
  List.filter_map findings ~f:(fun f ->
      if Class.equal f.klass Class.Whole_window then Some f.symbol else None)

let csv_header =
  "symbol,class,n_bars,first_date,last_date,median_close,min_close,max_close,n_above"

let _fmt_price v = Printf.sprintf "%.4f" v

let _csv_row f =
  String.concat ~sep:","
    [
      f.symbol;
      Class.to_string f.klass;
      Int.to_string f.n_bars;
      Date.to_string f.first_date;
      Date.to_string f.last_date;
      _fmt_price f.median_close;
      _fmt_price f.min_close;
      _fmt_price f.max_close;
      Int.to_string f.n_above;
    ]

let to_csv findings =
  String.concat ~sep:"\n" (csv_header :: List.map findings ~f:_csv_row) ^ "\n"

let _count findings ~klass =
  List.count findings ~f:(fun f -> Class.equal f.klass klass)

let summary findings =
  Printf.sprintf "series_level: %d findings (%d whole_window, %d mixed_scale)"
    (List.length findings)
    (_count findings ~klass:Class.Whole_window)
    (_count findings ~klass:Class.Mixed_scale)
