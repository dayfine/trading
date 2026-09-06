open Core

let trading_days_per_week = 5

type t = {
  dates : Date.t array;
  pct_above_ma : float array;
  new_lows_pct : float array;
}

let _pct ~part ~whole =
  if whole <= 0 then 0.0 else Float.of_int part *. 100.0 /. Float.of_int whole

let of_daily_bars (bars : Macro_types.breadth_bar list) : t =
  let arr = Array.of_list bars in
  {
    dates = Array.map arr ~f:(fun (b : Macro_types.breadth_bar) -> b.date);
    pct_above_ma =
      Array.map arr ~f:(fun (b : Macro_types.breadth_bar) ->
          _pct ~part:b.above_ma_count ~whole:b.universe_count);
    new_lows_pct =
      Array.map arr ~f:(fun (b : Macro_types.breadth_bar) ->
          _pct ~part:b.new_lows ~whole:b.universe_count);
  }

let length t = Array.length t.dates

(* Count of rows with [date <= as_of]. [dates] is ascending, so this is an
   upper-bound binary search — the point-in-time cutoff, in O(log n). *)
let _count_at_or_before t ~as_of =
  let lo = ref 0 and hi = ref (Array.length t.dates) in
  while !lo < !hi do
    let mid = !lo + ((!hi - !lo) / 2) in
    if Date.( <= ) t.dates.(mid) as_of then lo := mid + 1 else hi := mid
  done;
  !lo

(* Read [arr] at [week_offset] weeks back from the newest row in the prefix
   [0, k). Offset 0 = index [k-1]; each further week steps back
   [trading_days_per_week] rows. *)
let _get_at arr ~k ~week_offset =
  let idx = k - 1 - (week_offset * trading_days_per_week) in
  if idx >= 0 && idx < k then Some arr.(idx) else None

let callbacks_at t ~as_of =
  let k = _count_at_or_before t ~as_of in
  ( (fun ~week_offset -> _get_at t.pct_above_ma ~k ~week_offset),
    fun ~week_offset -> _get_at t.new_lows_pct ~k ~week_offset )

module Internal_for_test = struct
  let count_at_or_before = _count_at_or_before
end
