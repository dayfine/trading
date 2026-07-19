open Core
open Weinstein_types

(* Age bands (lever f), youngest first, locked to [Snapshot_schema] band
   boundaries [0-26w / 26-78w / 78-130w / 130-520w]. Bands 0..[_n_recent_bands-1]
   union to the pre-lever-f trailing-130w histogram window; band 3 is the
   130-520w extension, weighted 0 by default so scoring is unchanged. *)
let n_age_bands = 4
let _n_recent_bands = 3

type sketch = {
  max_high_130w : float;
  max_high_260w : float;
  max_high_520w : float;
  bars_seen : float;
  hist_bands : float array array;
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
  band_weight_0_26w : float; [@sexp.default 1.0]
  band_weight_26_78w : float; [@sexp.default 1.0]
  band_weight_78_130w : float; [@sexp.default 1.0]
  band_weight_130_520w : float; [@sexp.default 0.0]
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
    (* No-op defaults (experiment-flag-discipline R1): the three 0-130w bands
       weighted 1.0 and the 130-520w band 0.0 collapses the age-banded histogram
       back to the pre-lever-f age-blind 130w histogram, bit-identically. *)
    band_weight_0_26w = 1.0;
    band_weight_26_78w = 1.0;
    band_weight_78_130w = 1.0;
    band_weight_130_520w = 0.0;
  }

let _band_weights (config : config) =
  [|
    config.band_weight_0_26w;
    config.band_weight_26_78w;
    config.band_weight_78_130w;
    config.band_weight_130_520w;
  |]

(* Pack a legacy age-blind histogram (the v3 warehouse / pre-lever-f shape) into
   the age-banded layout: all mass in the youngest band, the rest zero. With
   [default_config] band weights ([1;1;1;0]) the collapsed effective histogram
   equals [flat] exactly, so a v3 warehouse scores bit-identically. *)
let hist_bands_of_legacy flat =
  let n = Array.length flat in
  Array.init n_age_bands ~f:(fun b ->
      if b = 0 then Array.copy flat else Array.create ~len:n 0.0)

(* Collapse the age-banded histogram into one effective per-bucket vector by
   applying the per-band config weights: [effective.(k) = Σ_b w_b * bands_b.(k)].
   Non-finite cells count as 0 (same guard the per-bucket scorer applies). *)
let _effective_hist ~(config : config) ~hist_bands =
  let weights = _band_weights config in
  let n_buckets =
    Array.fold hist_bands ~init:0 ~f:(fun acc band ->
        Int.max acc (Array.length band))
  in
  let eff = Array.create ~len:n_buckets 0.0 in
  Array.iteri hist_bands ~f:(fun b band ->
      let w = if b < Array.length weights then weights.(b) else 0.0 in
      Array.iteri band ~f:(fun k c ->
          let c = if Float.is_finite c then c else 0.0 in
          eff.(k) <- eff.(k) +. (w *. c)));
  eff

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
  let effective = _effective_hist ~config ~hist_bands:sketch.hist_bands in
  let k_min =
    _first_bucket ~n_buckets:(Array.length effective)
      ~anchor:sketch.anchor_close ~breakout:breakout_price
  in
  let weighted, max_bucket = _recent_supply ~config ~hist:effective ~k_min in
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

(* The virgin verdict in isolation: the same finiteness guards [analyze] applies
   before scoring, plus the [>=] test [_quality_of] uses for [Virgin_territory].
   No scoring config, no insufficient-history degradation — the whole question
   is "new high ground over the 520-week window?". *)
let is_virgin ~(sketch : sketch) ~breakout_price =
  _sketch_is_finite sketch
  && Float.is_finite breakout_price
  && Float.(breakout_price >= sketch.max_high_520w)

(* Closing-basis "new high ground": no weekly bar in the trailing 130-week
   histogram window (age bands 0..[_n_recent_bands-1], which union to that
   window) sits at/above the current close — every recent-band bin is 0. The
   130-520w band is ignored, keeping this predicate bit-identical to its
   pre-lever-f 130w semantics (and to a v3 warehouse whose mass all lands in
   band 0). Weight-independent by design — a structural emptiness test, not a
   scoring measure. Robust to the own-week-high artifact that makes [is_virgin]
   unsatisfiable on a close-anchored breakout price (see .mli — AXTI
   2026-01-06). A non-finite bin fails the [= 0.0] test, so no explicit
   finiteness check on the bins is needed. *)
let is_clear_of_supply ~(sketch : sketch) =
  _sketch_is_finite sketch
  && Float.(sketch.bars_seen > 0.0)
  && Array.for_alli sketch.hist_bands ~f:(fun b band ->
      b >= _n_recent_bands
      || Array.for_all band ~f:(fun count -> Float.(count = 0.0)))
