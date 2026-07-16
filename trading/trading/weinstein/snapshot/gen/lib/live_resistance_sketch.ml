open Core
module Resistance_sketch = Snapshot_pipeline.Resistance_sketch

(* Extract one day's scalar sketch (day index [i]) from the per-day sketch
   columns. The column-major histogram [arrays.hist.(k).(i)] is transposed to
   the per-bucket vector [Resistance_supply.sketch.hist], and the anchor is the
   bar's raw close (the same value the snapshot [Close] column stores — see
   [Resistance_sketch_reader]). *)
let _sketch_at ~(arrays : Resistance_sketch.t)
    ~(bars : Types.Daily_price.t array) ~i : Resistance_supply.sketch =
  {
    Resistance_supply.max_high_130w = arrays.max_high_130w.(i);
    max_high_260w = arrays.max_high_260w.(i);
    max_high_520w = arrays.max_high_520w.(i);
    bars_seen = arrays.bars_seen.(i);
    hist = Array.map arrays.hist ~f:(fun col -> col.(i));
    anchor_close = bars.(i).Types.Daily_price.close_price;
  }

let of_daily_bars (daily_bars : Types.Daily_price.t list) :
    Resistance_supply.sketch option =
  let bars = Array.of_list daily_bars in
  let n = Array.length bars in
  if n = 0 then None
  else
    let arrays =
      Resistance_sketch.compute_windowed ~deep_bars:[||] ~bars_arr:bars
    in
    Some (_sketch_at ~arrays ~bars ~i:(n - 1))
