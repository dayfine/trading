open Core
module Resistance_sketch = Snapshot_pipeline.Resistance_sketch

(* Extract one day's scalar sketch (day index [i]) from the per-day sketch
   columns. The column-major band-major histogram [arrays.hist.(cell).(i)] is
   transposed into the [Resistance_supply.sketch.hist_bands] age-band matrix
   ([hist_bands.(band).(bucket)], cell [band * n_buckets + bucket]), and the
   anchor is the bar's raw close (the same value the snapshot [Close] column
   stores — see [Resistance_sketch_reader]). *)
let _sketch_at ~(arrays : Resistance_sketch.t)
    ~(bars : Types.Daily_price.t array) ~i : Resistance_supply.sketch =
  let n_bands = Resistance_supply.n_age_bands in
  let n_buckets = Array.length arrays.hist / n_bands in
  {
    Resistance_supply.max_high_130w = arrays.max_high_130w.(i);
    max_high_260w = arrays.max_high_260w.(i);
    max_high_520w = arrays.max_high_520w.(i);
    bars_seen = arrays.bars_seen.(i);
    hist_bands =
      Array.init n_bands ~f:(fun band ->
          Array.init n_buckets ~f:(fun bucket ->
              arrays.hist.((band * n_buckets) + bucket).(i)));
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
