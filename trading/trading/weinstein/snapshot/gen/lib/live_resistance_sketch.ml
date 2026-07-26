open Core
module Resistance_sketch = Snapshot_pipeline.Resistance_sketch

(* Transpose day [i]'s band-major histogram columns [arrays.hist.(cell).(i)]
   (cell [band * n_buckets + bucket]) into the [Resistance_supply.sketch]
   age-band matrix [hist_bands.(band).(bucket)]. Extracted from [_sketch_at] to
   keep that record literal within the nesting limit. *)
let _hist_bands_at ~(arrays : Resistance_sketch.t) ~i =
  let n_bands = Resistance_supply.n_age_bands in
  let n_buckets = Array.length arrays.hist / n_bands in
  let cell ~band ~bucket = arrays.hist.((band * n_buckets) + bucket).(i) in
  Array.init n_bands ~f:(fun band ->
      Array.init n_buckets ~f:(fun bucket -> cell ~band ~bucket))

(* Extract one day's scalar sketch (day index [i]) from the per-day sketch
   columns. The anchor is the bar's raw close (the same value the snapshot
   [Close] column stores — see [Resistance_sketch_reader]). *)
let _sketch_at ~(arrays : Resistance_sketch.t)
    ~(bars : Types.Daily_price.t array) ~i : Resistance_supply.sketch =
  {
    Resistance_supply.max_high_130w = arrays.max_high_130w.(i);
    max_high_260w = arrays.max_high_260w.(i);
    max_high_520w = arrays.max_high_520w.(i);
    bars_seen = arrays.bars_seen.(i);
    hist_bands = _hist_bands_at ~arrays ~i;
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
