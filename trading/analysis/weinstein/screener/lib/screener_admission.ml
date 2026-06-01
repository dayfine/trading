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

let rs_blocks_short = function
  | Some { Rs.trend = Positive_rising | Positive_flat | Bullish_crossover; _ }
    ->
      true
  | _ -> false

let _long_admission ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range (a, sector) =
  (* Volume-band exclusion is folded into breakout phase: keeps the
     cascade-diagnostics record stable (no new counter) while gating downstream
     counts. *)
  let passes_breakout =
    Stock_analysis.is_breakout_candidate a
    && passes_volume_band ~excl:volume_ratio_exclude_range a
  in
  let passes_sector =
    passes_breakout && not (equal_sector_rating sector.rating Weak)
  in
  let passes_grade =
    if not passes_sector then false
    else
      let score, _ = score_long ~weights ~sector a in
      passes_score_floor ~thresholds ~min_grade ~min_score_override
        ~max_score_override score
  in
  (passes_breakout, passes_sector, passes_grade)

let _bump n b = if b then n + 1 else n

let count_long_phases ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~candidates =
  List.fold candidates ~init:(0, 0, 0)
    ~f:(fun (breakout, sector_ok, grade_ok) pair ->
      let pb, ps, pg =
        _long_admission ~weights ~thresholds ~min_grade ~min_score_override
          ~max_score_override ~volume_ratio_exclude_range pair
      in
      (_bump breakout pb, _bump sector_ok ps, _bump grade_ok pg))

let _short_admission ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range (a, sector) =
  let passes_breakdown =
    Stock_analysis.is_breakdown_candidate a
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
    ~max_score_override ~volume_ratio_exclude_range ~candidates =
  List.fold candidates ~init:(0, 0, 0, 0)
    ~f:(fun (breakdown, sector_ok, rs_ok, grade_ok) pair ->
      let pb, ps, pr, pg =
        _short_admission ~weights ~thresholds ~min_grade ~min_score_override
          ~max_score_override ~volume_ratio_exclude_range pair
      in
      (_bump breakdown pb, _bump sector_ok ps, _bump rs_ok pr, _bump grade_ok pg))
