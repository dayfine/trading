open Core

type t = {
  dates : Date.t array;
  cum_int : int array;
  cum_float : float array;
  momentum_period : int;
}

let of_weekly_ad_bars ~momentum_period (ad_bars : Macro.ad_bar list) : t =
  let n = List.length ad_bars in
  let dates = Array.create ~len:n Date.unix_epoch in
  let cum_int = Array.create ~len:n 0 in
  let running = ref 0 in
  List.iteri ad_bars ~f:(fun j (bar : Macro.ad_bar) ->
      running := !running + bar.advancing - bar.declining;
      dates.(j) <- bar.date;
      cum_int.(j) <- !running);
  let cum_float = Array.map cum_int ~f:Float.of_int in
  { dates; cum_int; cum_float; momentum_period }

let length t = Array.length t.dates

(* Count of bars with [date <= as_of]. [dates] is ascending, so this is an
   upper-bound search — the exact prefix length
   {!Macro_inputs.ad_bars_at_or_before} produces. Binary search keeps the
   per-tick cost O(log n) instead of the O(n) list filter it replaces. *)
let _count_at_or_before t ~as_of =
  let lo = ref 0 and hi = ref (Array.length t.dates) in
  while !lo < !hi do
    let mid = !lo + ((!hi - !lo) / 2) in
    if Date.( <= ) t.dates.(mid) as_of then lo := mid + 1 else hi := mid
  done;
  !lo

(* [get_cumulative_ad] over the prefix [0, k). [week_offset:0] = newest in the
   prefix (index [k-1]); reproduces the [_get_from_float_array] indexing of the
   old [_build_cumulative_ad_array]-over-the-filtered-prefix path. *)
let _get_cumulative_ad t ~k ~week_offset =
  let idx = k - 1 - week_offset in
  if idx >= 0 && idx < k then Some t.cum_float.(idx) else None

(* [get_ad_momentum_ma] over the prefix [0, k). Only [week_offset:0] is
   consumed; the int sum of the last [min momentum_period k] A-D nets is the
   telescoped difference of cumulatives, divided by float [period] — the exact
   int-then-float boundary of the old [_compute_momentum_ma_scalar]. *)
let _get_ad_momentum_ma t ~k ~week_offset =
  if week_offset <> 0 then None
  else if k = 0 then None
  else
    let period = min t.momentum_period k in
    let lo = k - 1 - period in
    let sum = t.cum_int.(k - 1) - if lo >= 0 then t.cum_int.(lo) else 0 in
    Some (Float.of_int sum /. Float.of_int period)

let callbacks_at t ~as_of =
  let k = _count_at_or_before t ~as_of in
  ( _get_cumulative_ad t ~k,
    fun ~week_offset -> _get_ad_momentum_ma t ~k ~week_offset )

module Internal_for_test = struct
  let count_at_or_before = _count_at_or_before
end
