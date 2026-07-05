open Core
open Weinstein_types
open Screener_scoring

type volume_ratio_band = { low : float; high : float } [@@deriving sexp]

let passes_score_floor ~thresholds ~min_grade ~min_score_override
    ~max_score_override score =
  (match min_score_override with
    | Some n -> score >= n
    | None -> compare_grade (grade_of_score ~thresholds score) min_grade <= 0)
  && match max_score_override with Some m -> score < m | None -> true

let passes_volume_band ~excl (a : Stock_analysis.t) =
  match (excl, a.volume) with
  | None, _ | _, None -> true
  | Some { low; high }, Some v ->
      let r = v.Volume.volume_ratio in
      not Float.(low <= r && r < high)

let passes_price_floor ~min_price ~price =
  (* Liquidity floor: disabled when [min_price <= 0.0] (the default no-op).
     Otherwise the candidate's setup price ([breakout_price] for longs,
     [breakdown_price] for shorts) must be known and at/above the floor; an
     unknown price ([None]) is REJECTED under a positive floor since liquidity
     can't be verified. *)
  if Float.(min_price <= 0.0) then true
  else match price with Some p -> Float.(p >= min_price) | None -> false

let rs_blocks_short = function
  | Some { Rs.trend = Positive_rising | Positive_flat | Bullish_crossover; _ }
    ->
      true
  | _ -> false

let _long_admission ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price
    ~early_stage2_max_weeks (a, sector) =
  (* Volume-band exclusion and the min-price liquidity floor are folded into the
     breakout phase: keeps the cascade-diagnostics record stable (no new
     counter) while gating downstream counts. The long-side setup price is
     [breakout_price]. [early_stage2_max_weeks] is threaded into both the
     breakout gate and the score so this diagnostic count tracks the same
     early-Stage2 window the live cascade admits on. *)
  let passes_breakout =
    passes_price_floor ~min_price ~price:a.Stock_analysis.breakout_price
    && Stock_analysis.is_breakout_candidate ~early_stage2_max_weeks a
    && passes_volume_band ~excl:volume_ratio_exclude_range a
  in
  let passes_sector =
    passes_breakout && not (equal_sector_rating sector.rating Weak)
  in
  let passes_grade =
    if not passes_sector then false
    else
      let score, _ = score_long ~early_stage2_max_weeks ~weights ~sector a in
      passes_score_floor ~thresholds ~min_grade ~min_score_override
        ~max_score_override score
  in
  (passes_breakout, passes_sector, passes_grade)

let _bump n b = if b then n + 1 else n

let count_long_phases ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price
    ~early_stage2_max_weeks ~candidates =
  List.fold candidates ~init:(0, 0, 0)
    ~f:(fun (breakout, sector_ok, grade_ok) pair ->
      let pb, ps, pg =
        _long_admission ~weights ~thresholds ~min_grade ~min_score_override
          ~max_score_override ~volume_ratio_exclude_range ~min_price
          ~early_stage2_max_weeks pair
      in
      (_bump breakout pb, _bump sector_ok ps, _bump grade_ok pg))

let _short_admission ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price (a, sector) =
  (* The short-side setup price is [breakdown_price]; the floor folds into the
     breakdown phase, mirroring [_long_admission]. *)
  let passes_breakdown =
    passes_price_floor ~min_price ~price:a.Stock_analysis.breakdown_price
    && Stock_analysis.is_breakdown_candidate a
    && passes_volume_band ~excl:volume_ratio_exclude_range a
  in
  let passes_sector =
    passes_breakdown && not (equal_sector_rating sector.rating Strong)
  in
  let passes_rs = passes_sector && not (rs_blocks_short a.Stock_analysis.rs) in
  let passes_grade =
    if not passes_rs then false
    else
      let score, _ = score_short ~weights ~sector a in
      passes_score_floor ~thresholds ~min_grade ~min_score_override
        ~max_score_override score
  in
  (passes_breakdown, passes_sector, passes_rs, passes_grade)

let count_short_phases ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price ~candidates =
  List.fold candidates ~init:(0, 0, 0, 0)
    ~f:(fun (breakdown, sector_ok, rs_ok, grade_ok) pair ->
      let pb, ps, pr, pg =
        _short_admission ~weights ~thresholds ~min_grade ~min_score_override
          ~max_score_override ~volume_ratio_exclude_range ~min_price pair
      in
      (_bump breakdown pb, _bump sector_ok ps, _bump rs_ok pr, _bump grade_ok pg))
