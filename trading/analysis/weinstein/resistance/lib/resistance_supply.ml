open Core
open Weinstein_types

type sketch = {
  max_high_130w : float;
  max_high_260w : float;
  max_high_520w : float;
  bars_seen : float;
  hist : float array;
  anchor_close : float;
}

type config = {
  proximity_decay : float;
  saturation_bars : float;
  recent_far_floor : float;
  stale_mid_floor : float;
  stale_old_floor : float;
  min_history_bars : int;
  insufficient_score : float;
  heavy_resistance_bars : int;
  moderate_resistance_bars : int;
}
[@@deriving sexp]

let default_config =
  {
    proximity_decay = 0.7;
    saturation_bars = 8.0;
    (* v1 heavy-zone bar count *)
    recent_far_floor = 0.4;
    stale_mid_floor = 0.25;
    stale_old_floor = 0.1;
    min_history_bars = 0;
    insufficient_score = 0.5;
    heavy_resistance_bars = 8;
    moderate_resistance_bars = 3;
  }

type result = {
  score : float;
  recent_weighted_bars : float;
  quality : overhead_quality;
}

let _sketch_is_finite (s : sketch) =
  Float.is_finite s.max_high_130w
  && Float.is_finite s.max_high_260w
  && Float.is_finite s.max_high_520w
  && Float.is_finite s.bars_seen
  && Float.is_finite s.anchor_close
  && Float.(s.anchor_close > 0.0)

(* Bucket index for a breakout/anchor ratio: ceil(n * log2 ratio), clamped
   at 0; a non-finite result (degenerate ratio) degrades to bucket 0. *)
let _bucket_of_ratio ~n_buckets ~ratio =
  let raw =
    Float.round_up (Float.of_int n_buckets *. Float.log ratio /. Float.log 2.0)
  in
  if Float.is_finite raw then Int.max 0 (Int.of_float raw) else 0

(* First histogram bucket whose whole band sits at or above the breakout.
   Bucket [k] spans [anchor * 2^(k/n), ...): k_min = ceil(n * log2(B / C)),
   clamped at 0 (a breakout below the anchor sees every bucket). *)
let _first_bucket ~n_buckets ~anchor ~breakout =
  if Float.(breakout <= anchor) then 0
  else _bucket_of_ratio ~n_buckets ~ratio:(breakout /. anchor)

(* Proximity-weighted bar mass and max single-bucket count over buckets
   [k_min ..]: weight decays multiplicatively per bucket above [k_min]. *)
let _recent_supply ~(config : config) ~hist ~k_min =
  let weighted = ref 0.0 in
  let max_bucket = ref 0.0 in
  let w = ref 1.0 in
  for k = k_min to Array.length hist - 1 do
    let count = if Float.is_finite hist.(k) then hist.(k) else 0.0 in
    weighted := !weighted +. (count *. !w);
    max_bucket := Float.max !max_bucket count;
    w := !w *. config.proximity_decay
  done;
  (!weighted, !max_bucket)

(* Virgin test uses [>=]: v1 is virgin iff no weekly high STRICTLY exceeds
   the breakout, i.e. [max_high <= breakout] — bit-equal at the tie. *)
let _quality_of ~(config : config) ~(sketch : sketch) ~breakout_price
    ~max_bucket =
  if Float.(breakout_price >= sketch.max_high_520w) then Virgin_territory
  else if Float.(max_bucket >= Float.of_int config.heavy_resistance_bars) then
    Heavy_resistance
  else if Float.(max_bucket >= Float.of_int config.moderate_resistance_bars)
  then Moderate_resistance
  else Clean

(* Horizon floor for overhead the histogram cannot see: nearest overhead age
   decides the floor (recent-but-far > 130-260w > 260-520w); virgin gets no
   floor. *)
let _horizon_floor ~(config : config) ~(sketch : sketch) ~breakout_price =
  if Float.(breakout_price <= sketch.max_high_130w) then config.recent_far_floor
  else if Float.(breakout_price <= sketch.max_high_260w) then
    config.stale_mid_floor
  else if Float.(breakout_price <= sketch.max_high_520w) then
    config.stale_old_floor
  else 0.0

let _insufficient ~(config : config) =
  {
    score = config.insufficient_score;
    recent_weighted_bars = 0.0;
    quality = Insufficient_history;
  }

let _scored ~(config : config) ~(sketch : sketch) ~breakout_price =
  let k_min =
    _first_bucket ~n_buckets:(Array.length sketch.hist)
      ~anchor:sketch.anchor_close ~breakout:breakout_price
  in
  let weighted, max_bucket = _recent_supply ~config ~hist:sketch.hist ~k_min in
  let quality = _quality_of ~config ~sketch ~breakout_price ~max_bucket in
  let score =
    (* When the histogram holds mass at/above the breakout it speaks for
       itself; the horizon floors only cover overhead the histogram cannot
       see (older than 130w, or more than one doubling above). *)
    match quality with
    | Virgin_territory -> 0.0
    | _ when Float.(weighted > 0.0) ->
        Float.min 1.0 (weighted /. config.saturation_bars)
    | _ -> _horizon_floor ~config ~sketch ~breakout_price
  in
  { score; recent_weighted_bars = weighted; quality }

let analyze ~(config : config) ~(sketch : sketch) ~breakout_price =
  if
    (not (_sketch_is_finite sketch))
    || (not (Float.is_finite breakout_price))
    || Float.(sketch.bars_seen < Float.of_int config.min_history_bars)
  then _insufficient ~config
  else _scored ~config ~sketch ~breakout_price
