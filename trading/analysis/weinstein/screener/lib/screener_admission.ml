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

(** [Some (close, breakout, floor)] when the failed-breakout gate is armed and
    both prices are known; [None] when the gate is disabled
    ([tolerance_pct <= 0.0], the default no-op) or either price is unknown —
    absence of data must never invalidate a candidate. *)
let _failed_breakout_levels ~tolerance_pct ~breakout_price ~current_close =
  if Float.(tolerance_pct <= 0.0) then None
  else
    match (breakout_price, current_close) with
    | None, _ | _, None -> None
    | Some bp, Some close -> Some (close, bp, bp *. (1.0 -. tolerance_pct))

let _failed_breakout_message ~close ~breakout ~tolerance_pct ~floor_price =
  Printf.sprintf
    "Failed breakout: close %.2f below breakout %.2f - %.1f%% (%.2f)" close
    breakout (tolerance_pct *. 100.0) floor_price

(* Failed-breakout re-validation. Engineering adaptation, not a book-quoted
   rule: it enforces §4.1 requirement 1 (breakout above resistance) as a
   condition that must still hold at evaluation time. See the .mli for the full
   authority note, including why tolerance_pct must not be set small. *)
let failed_breakout_reason ~tolerance_pct ~breakout_price ~current_close =
  match
    _failed_breakout_levels ~tolerance_pct ~breakout_price ~current_close
  with
  | None -> None
  | Some (close, breakout, floor_price) ->
      if Float.(close >= floor_price) then None
      else
        Some
          (_failed_breakout_message ~close ~breakout ~tolerance_pct ~floor_price)

let passes_failed_breakout ~tolerance_pct ~breakout_price ~current_close =
  Option.is_none
    (failed_breakout_reason ~tolerance_pct ~breakout_price ~current_close)

let _long_passes_failed_breakout ~tolerance_pct (a : Stock_analysis.t) =
  passes_failed_breakout ~tolerance_pct ~breakout_price:a.breakout_price
    ~current_close:a.current_close

let rs_blocks_short = function
  | Some { Rs.trend = Positive_rising | Positive_flat | Bullish_crossover; _ }
    ->
      true
  | _ -> false

(* Book §4.4 rule 2, and level-only is the FAITHFUL reading rather than a
   simplification of it. Rule 3 ("RS crossing from negative to positive
   territory -> A+ bonus signal") cannot conflict, because [_classify_trend]
   emits [Bullish_crossover] only on the [(cur > 1.0, prev > 1.0) = (true,
   false)] arm and [_result_of_history] reports that same float as
   [current_normalized]. So [Bullish_crossover] implies
   [current_normalized > 1.0] as a module invariant — a crossing has already
   LANDED above the line — and a level gate never reaches rule 3's cohort.
   Pinned by [test_bullish_crossover_implies_positive_territory] in the Rs
   suite, so the invariant is guarded mechanically rather than argued here.

   An earlier revision exempted [Bullish_crossover] on the theory that the two
   rules overlap mid-crossing. They do not; the exemption was unreachable and
   its test hand-built a state [Rs] cannot produce. Withdrawn. *)
let rs_blocks_long ~min_rs_normalized = function
  | Some { Rs.current_normalized; _ } ->
      Float.( < ) current_normalized min_rs_normalized
  | None -> false

let count_long_failed_breakouts ~tolerance_pct ~early_stage2_max_weeks
    ~candidates =
  List.count candidates ~f:(fun ((a : Stock_analysis.t), _sector) ->
      Stock_analysis.is_breakout_candidate ~early_stage2_max_weeks a
      && not (_long_passes_failed_breakout ~tolerance_pct a))

type breakout_gate =
  | Price_floor
  | Stage_setup
  | Breakout_volume
  | Rs_declining
  | Failed_breakout
  | Volume_band
[@@deriving sexp, eq, show]

(* Total mapping from the analysis-layer rejection onto this module's gate
   vocabulary. Separate types on purpose: [Stock_analysis] owns the three gates
   inside its own predicate, while [Price_floor] / [Failed_breakout] /
   [Volume_band] are screener-config gates it knows nothing about. A
   constructor added upstream fails to compile here rather than silently
   collapsing into a neighbouring bucket. *)
let _gate_of_rejection : Stock_analysis.breakout_rejection -> breakout_gate =
  function
  | Stage_setup -> Stage_setup
  | Breakout_volume -> Breakout_volume
  | Rs_declining -> Rs_declining

(* First-failing long-side breakout gate, or [None] when the candidate clears
   the whole phase. The order below IS the contract documented on
   {!breakout_gate}; [long_admission]'s [passes_breakout] is [Option.is_none]
   of this, so the boolean cascade and the named sub-reason cannot drift. *)
let _long_setup_gate ~early_stage2_max_weeks a =
  Option.map
    (Stock_analysis.breakout_candidate_rejection ~early_stage2_max_weeks a)
    ~f:_gate_of_rejection

let _long_post_setup_gate ~volume_ratio_exclude_range
    ~failed_breakout_tolerance_pct a =
  if
    not
      (_long_passes_failed_breakout ~tolerance_pct:failed_breakout_tolerance_pct
         a)
  then Some Failed_breakout
  else if not (passes_volume_band ~excl:volume_ratio_exclude_range a) then
    Some Volume_band
  else None

let _long_breakout_gate ~volume_ratio_exclude_range ~min_price
    ~failed_breakout_tolerance_pct ~early_stage2_max_weeks
    (a : Stock_analysis.t) =
  if not (passes_price_floor ~min_price ~price:a.breakout_price) then
    Some Price_floor
  else
    match _long_setup_gate ~early_stage2_max_weeks a with
    | Some gate -> Some gate
    | None ->
        _long_post_setup_gate ~volume_ratio_exclude_range
          ~failed_breakout_tolerance_pct a

(* Short-side mirror. No failed-breakdown re-validation exists, and
   [is_breakdown_candidate] is a single stage predicate with no sub-gates, so
   the short phase can only ever report three of the six constructors. *)
let _short_breakdown_gate ~volume_ratio_exclude_range ~min_price
    (a : Stock_analysis.t) =
  if not (passes_price_floor ~min_price ~price:a.breakdown_price) then
    Some Price_floor
  else if not (Stock_analysis.is_breakdown_candidate a) then Some Stage_setup
  else if not (passes_volume_band ~excl:volume_ratio_exclude_range a) then
    Some Volume_band
  else None

let long_admission ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price
    ~failed_breakout_tolerance_pct ~early_stage2_max_weeks ~min_rs_normalized
    (a, sector) =
  (* Volume-band exclusion, the min-price liquidity floor, and the
     failed-breakout re-validation all fold into the breakout phase: the
     admitted chain stays a three-phase monotone triple while every gate still
     suppresses downstream counts. (The failed-breakout DROP count is reported
     separately by [count_long_failed_breakouts].) The long-side setup price is
     [breakout_price]. [early_stage2_max_weeks] is threaded into both the
     breakout gate and the score so this diagnostic count tracks the same
     early-Stage2 window the live cascade admits on. *)
  let breakout_gate =
    _long_breakout_gate ~volume_ratio_exclude_range ~min_price
      ~failed_breakout_tolerance_pct ~early_stage2_max_weeks a
  in
  let passes_breakout = Option.is_none breakout_gate in
  let passes_sector =
    passes_breakout && not (equal_sector_rating sector.rating Weak)
  in
  (* Book §4.4 rule 2. The short side reports its RS gate as a phase of its own
     ([short_admission] returns a 4-tuple); the long triple is kept as-is so
     the cascade-diagnostics record and every report built on it are untouched,
     which is what lets the [min_rs_normalized = 0.0] default stay a provable
     no-op. The cost is attribution: with the gate armed, its drops land in
     [grade_ok]. See the .mli. *)
  let passes_rs =
    passes_sector && not (rs_blocks_long ~min_rs_normalized a.Stock_analysis.rs)
  in
  let passes_grade =
    if not passes_rs then false
    else
      let score, _ = score_long ~early_stage2_max_weeks ~weights ~sector a in
      passes_score_floor ~thresholds ~min_grade ~min_score_override
        ~max_score_override score
  in
  (breakout_gate, passes_sector, passes_grade)

let _bump n b = if b then n + 1 else n

let count_long_phases ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price
    ~failed_breakout_tolerance_pct ~early_stage2_max_weeks ~min_rs_normalized
    ~candidates =
  (* Partially applied so the fold body stays a two-liner — the gate list is
     long enough that inlining it inside the closure trips the nesting linter. *)
  let admit =
    long_admission ~weights ~thresholds ~min_grade ~min_score_override
      ~max_score_override ~volume_ratio_exclude_range ~min_price
      ~failed_breakout_tolerance_pct ~early_stage2_max_weeks ~min_rs_normalized
  in
  let step (breakout, sector_ok, grade_ok) pair =
    let gate, ps, pg = admit pair in
    (_bump breakout (Option.is_none gate), _bump sector_ok ps, _bump grade_ok pg)
  in
  List.fold candidates ~init:(0, 0, 0) ~f:step

let short_admission ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price (a, sector) =
  (* The short-side setup price is [breakdown_price]; the floor folds into the
     breakdown phase, mirroring [long_admission]. *)
  let breakdown_gate =
    _short_breakdown_gate ~volume_ratio_exclude_range ~min_price a
  in
  let passes_breakdown = Option.is_none breakdown_gate in
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
  (breakdown_gate, passes_sector, passes_rs, passes_grade)

let count_short_phases ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price ~candidates =
  (* Partially applied for the same reason as [count_long_phases]. *)
  let admit =
    short_admission ~weights ~thresholds ~min_grade ~min_score_override
      ~max_score_override ~volume_ratio_exclude_range ~min_price
  in
  let step (breakdown, sector_ok, rs_ok, grade_ok) pair =
    let gate, ps, pr, pg = admit pair in
    ( _bump breakdown (Option.is_none gate),
      _bump sector_ok ps,
      _bump rs_ok pr,
      _bump grade_ok pg )
  in
  List.fold candidates ~init:(0, 0, 0, 0) ~f:step

(** Compute the cascade-diagnostics record for one screen call. Decoupled from
    [screen] so the latter stays within the 50-line linter cap. *)
let diagnostics_for_screen ~weights ~grade_thresholds ~min_grade
    ~min_score_override ~max_score_override ~volume_ratio_exclude_range
    ~min_price ~failed_breakout_tolerance_pct ~early_stage2_max_weeks
    ~min_rs_normalized ~total_stocks ~candidates_after_held ~macro_trend
    ~candidates ~buy_candidates ~short_candidates =
  let long_phases =
    count_long_phases ~weights ~thresholds:grade_thresholds ~min_grade
      ~min_score_override ~max_score_override ~volume_ratio_exclude_range
      ~min_price ~failed_breakout_tolerance_pct ~early_stage2_max_weeks
      ~min_rs_normalized ~candidates
  in
  let long_failed_breakout_dropped =
    count_long_failed_breakouts ~tolerance_pct:failed_breakout_tolerance_pct
      ~early_stage2_max_weeks ~candidates
  in
  let short_phases =
    count_short_phases ~weights ~thresholds:grade_thresholds ~min_grade
      ~min_score_override ~max_score_override ~volume_ratio_exclude_range
      ~min_price ~candidates
  in
  Screener_cascade_diagnostics.build ~total_stocks ~candidates_after_held
    ~macro_trend ~long_phases ~long_failed_breakout_dropped ~short_phases
    ~long_top_n:(List.length buy_candidates)
    ~short_top_n:(List.length short_candidates)
