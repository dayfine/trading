(* @large-module: screener cascade integrates multiple analysis passes in a single pipeline *)
open Core
open Weinstein_types
include Screener_scoring
include Screener_admission
include Screener_ranking

type candidate_params = {
  entry_buffer_pct : float;
  initial_stop_pct : float;
  short_stop_pct : float;
  base_low_proxy_pct : float;
  breakout_fallback_pct : float;
  installed_stop_min_pct : float; [@sexp.default 0.0]
}
[@@deriving sexp]
(** Per-candidate price computation parameters. All configurable.

    [installed_stop_min_pct] is the floor on the placed-stop distance from entry
    — opt-in for the G15-rewire path. Default 0.0 = no floor (the
    [support-floor / fallback-buffer] logic in
    {!Weinstein_stops.compute_initial_stop_with_floor} decides the stop
    unmodified). Sweepers that want wider stops set this to a positive fraction
    (e.g. 0.10 ⇒ stop must sit ≥ 10% from entry). See
    {!Weinstein_stops.widen_initial_to_min_distance}. *)

let default_candidate_params =
  {
    entry_buffer_pct = 0.005;
    initial_stop_pct = 0.08;
    short_stop_pct = 0.08;
    base_low_proxy_pct = 0.15;
    breakout_fallback_pct = 0.05;
    installed_stop_min_pct = 0.0;
  }

type config = {
  weights : scoring_weights;
  grade_thresholds : grade_thresholds;
  candidate_params : candidate_params;
  min_grade : grade;
  candidate_ranking : candidate_ranking; [@sexp.default Alphabetical]
  min_score_override : int option; [@sexp.default None]
  max_score_override : int option; [@sexp.default None]
  volume_ratio_exclude_range : volume_ratio_band option; [@sexp.default None]
  max_buy_candidates : int;
  max_short_candidates : int;
  cascade_post_stop_cooldown_weeks : int; [@sexp.default 0]
  neutral_blocks_longs : bool; [@sexp.default false]
  neutral_blocks_shorts : bool; [@sexp.default false]
  enable_slow_grind_short_gate : bool; [@sexp.default false]
  min_price : float; [@sexp.default 0.0]
  early_stage2_max_weeks : int; [@sexp.default 4]
}
[@@deriving sexp]

let default_config =
  {
    weights = default_scoring_weights;
    grade_thresholds = default_grade_thresholds;
    candidate_params = default_candidate_params;
    min_grade = C;
    candidate_ranking = Alphabetical;
    min_score_override = None;
    max_score_override = None;
    volume_ratio_exclude_range = None;
    max_buy_candidates = 20;
    max_short_candidates = 10;
    cascade_post_stop_cooldown_weeks = 0;
    neutral_blocks_longs = false;
    neutral_blocks_shorts = false;
    enable_slow_grind_short_gate = false;
    min_price = 0.0;
    early_stage2_max_weeks = 4;
  }

type scored_candidate = {
  ticker : string;
  analysis : Stock_analysis.t;
  sector : sector_context;
  side : Trading_base.Types.position_side;
  grade : grade;
  score : int;
  suggested_entry : float;
  suggested_stop : float;
  risk_pct : float;
  swing_target : float option;
  rationale : string list;
}

type cascade_diagnostics = Screener_cascade_diagnostics.t = {
  total_stocks : int;
  candidates_after_held : int;
  macro_trend : market_trend;
  long_macro_admitted : int;
  long_breakout_admitted : int;
  long_sector_admitted : int;
  long_grade_admitted : int;
  long_top_n_admitted : int;
  short_macro_admitted : int;
  short_breakdown_admitted : int;
  short_sector_admitted : int;
  short_rs_hard_gate_admitted : int;
  short_grade_admitted : int;
  short_top_n_admitted : int;
}
[@@deriving sexp]

type result = {
  buy_candidates : scored_candidate list;
  short_candidates : scored_candidate list;
  watchlist : (string * string) list;
  macro_trend : market_trend;
  cascade_diagnostics : cascade_diagnostics;
}

(* ------------------------------------------------------------------ *)
(* Per-candidate filters                                               *)
(* ------------------------------------------------------------------ *)

let _build_candidate ~params ~sector ~(a : Stock_analysis.t) ~score ~reasons
    ~thresholds ~is_short : scored_candidate =
  let breakout =
    Option.value a.breakout_price
      ~default:(a.stage.ma_value *. (1.0 +. params.breakout_fallback_pct))
  in
  let entry =
    suggested_entry ~entry_buffer_pct:params.entry_buffer_pct breakout
  in
  let stop_ =
    if is_short then entry *. (1.0 +. params.short_stop_pct)
    else suggested_stop ~initial_stop_pct:params.initial_stop_pct entry
  in
  let risk_pct =
    if Float.(entry = 0.0) then 0.0 else Float.abs ((entry -. stop_) /. entry)
  in
  let base_low_val = base_low ~base_low_proxy_pct:params.base_low_proxy_pct a in
  let swing =
    if is_short then None else swing_target ~breakout ~base_low_opt:base_low_val
  in
  let side : Trading_base.Types.position_side =
    if is_short then Short else Long
  in
  {
    ticker = a.ticker;
    analysis = a;
    sector;
    side;
    grade = grade_of_score ~thresholds score;
    score;
    suggested_entry = entry;
    suggested_stop = stop_;
    risk_pct;
    swing_target = swing;
    rationale = reasons;
  }

(** Score, grade, and build a candidate after passing preliminary gates. Returns
    [None] if [score] does not pass {!Screener_admission.passes_score_floor}. *)
let _score_and_build ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~is_short ~scorer ~sector a =
  let score, reasons = scorer ~weights ~sector a in
  if
    not
      (passes_score_floor ~thresholds ~min_grade ~min_score_override
         ~max_score_override score)
  then None
  else
    Some
      (_build_candidate ~params ~sector ~a ~score ~reasons ~thresholds ~is_short)

(** Evaluate one (analysis, sector) pair as a long candidate. Returns [None] if
    excluded by the price floor, sector gate, breakout test, volume band, or
    score floor. *)
let _long_candidate ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price
    ~early_stage2_max_weeks (a, sector) =
  if not (passes_price_floor ~min_price ~price:a.Stock_analysis.breakout_price)
  then None
  else if equal_sector_rating sector.rating Weak then None
  else if not (Stock_analysis.is_breakout_candidate ~early_stage2_max_weeks a)
  then None
  else if not (passes_volume_band ~excl:volume_ratio_exclude_range a) then None
  else
    _score_and_build ~weights ~thresholds ~params ~min_grade ~min_score_override
      ~max_score_override ~is_short:false
      ~scorer:(score_long ~early_stage2_max_weeks)
      ~sector a

(** Evaluate one (analysis, sector) pair as a short candidate. Bearish/Neutral
    only: score must pass {!Screener_admission.passes_score_floor}. *)
let _short_candidate ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price (a, sector) =
  if not (passes_price_floor ~min_price ~price:a.Stock_analysis.breakdown_price)
  then None
  else if equal_sector_rating sector.rating Strong then None
  else if not (Stock_analysis.is_breakdown_candidate a) then None
  else if rs_blocks_short a.Stock_analysis.rs then None
  else if not (passes_volume_band ~excl:volume_ratio_exclude_range a) then None
  else
    _score_and_build ~weights ~thresholds ~params ~min_grade ~min_score_override
      ~max_score_override ~is_short:true ~scorer:score_short ~sector a

(** Check watchlist eligibility after the breakout gate. Returns [None] if the
    ticker is already in [buy_candidates] or the grade is above C/D. *)
let _check_watchlist_grade ~thresholds ~buy_candidates ~score
    (sa : Stock_analysis.t) =
  let grade = grade_of_score ~thresholds score in
  let in_buy_list =
    List.exists buy_candidates ~f:(fun c -> String.(c.ticker = sa.ticker))
  in
  if in_buy_list then None
  else if equal_grade grade C || equal_grade grade D then
    Some
      ( sa.ticker,
        Printf.sprintf "Grade %s, score %d" (grade_to_string grade) score )
  else None

(** Evaluate one (analysis, sector) pair as a watchlist entry. Included when it
    is a grade-C or grade-D breakout candidate not already in [buy_candidates].
*)
let _watchlist_entry ~weights ~thresholds ~early_stage2_max_weeks
    ~buy_candidates (sa, sector) =
  if not (Stock_analysis.is_breakout_candidate ~early_stage2_max_weeks sa) then
    None
  else
    let score, _ = score_long ~early_stage2_max_weeks ~weights ~sector sa in
    _check_watchlist_grade ~thresholds ~buy_candidates ~score sa

(* ------------------------------------------------------------------ *)
(* Evaluate + sort + cap                                               *)
(* ------------------------------------------------------------------ *)

(** Project a {!scored_candidate} onto the {!Screener_ranking.rankable} the
    comparator needs (score / ticker / analysis). *)
let _rankable_of_candidate (c : scored_candidate) : Screener_ranking.rankable =
  { score = c.score; ticker = c.ticker; analysis = c.analysis }

(** Full ranking comparator: primary [score] descending, then the [ranking]
    tiebreak among equal scores (see {!Screener_ranking.candidate_ranking}).
    Adapts each candidate to {!Screener_ranking.rankable} and delegates. Exposed
    so the ordering contract is unit-testable in isolation of the cascade. *)
let compare_for_ranking ranking a b =
  Screener_ranking.compare_rankable ranking (_rankable_of_candidate a)
    (_rankable_of_candidate b)

let _top_n ~ranking n lst =
  (* Secondary sort breaks score ties deterministically. Without it,
     [List.sort]'s stability depends on the input ordering — which in turn
     depends on Hashtbl iteration order, and that diverges between macOS and
     Linux. A G15-step-3 panel-golden CI failure surfaced this: local
     regenerated more round_trips than GHA produced, with the diff being a
     tied-score candidate that landed on either side of a cash-budget boundary
     depending on its position in the sorted list. The [Alphabetical] mode
     (default) preserves the original ticker-only tiebreak bit-for-bit; the
     [Quality] mode breaks ties by RS magnitude / earliness / volume, falling
     back to ticker so the order stays fully deterministic. *)
  List.sort lst ~compare:(compare_for_ranking ranking) |> fun l ->
  List.sub l ~pos:0 ~len:(min n (List.length l))

(** Apply [candidate_fn] to each pair, drop [None]s, sort by score (tiebroken
    per [ranking]), and cap at [max_n]. Shared by the long and short evaluation
    paths. *)
let _filter_and_cap ~ranking ~candidate_fn ~max_n candidates =
  List.filter_map candidates ~f:candidate_fn |> _top_n ~ranking max_n

(** Whether the macro tape admits new long entries.

    [neutral_blocks_longs] defaults to [false] = the historical gate (longs
    admitted under both [Bullish] and [Neutral]; blocked only under [Bearish]).
    When [true], [Neutral] also blocks longs — only [Bullish] admits. This
    tightens Weinstein's unconditional macro gate so a non-confirmed ([Neutral])
    tape no longer admits buys. The short-side gate is unaffected. *)
let _longs_admitted_by_macro ~neutral_blocks_longs macro_trend =
  match macro_trend with
  | Bearish -> false
  | Neutral -> not neutral_blocks_longs
  | Bullish -> true

(** Whether the macro tape admits new short entries.

    Mirror of {!_longs_admitted_by_macro} for the short side.
    [neutral_blocks_shorts] defaults to [false] = the historical gate (shorts
    admitted under both [Bearish] and [Neutral]; blocked only under [Bullish]).
    When [true], [Neutral] also blocks shorts — only [Bearish] admits. This
    tightens the short side to Weinstein's confirmed-bear rule
    (weinstein-book-reference.md §Short-Selling Rules: short only in a confirmed
    bear market), so a non-confirmed ([Neutral]) chop tape — exactly where
    shorts get squeezed — no longer admits shorts. The long-side gate is
    unaffected. *)
let _shorts_admitted_by_macro ~neutral_blocks_shorts macro_trend =
  match macro_trend with
  | Bullish -> false
  | Neutral -> not neutral_blocks_shorts
  | Bearish -> true

(** Filter, score, grade, sort, and cap long candidates. *)
let _evaluate_longs ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price
    ~early_stage2_max_weeks ~max_buy_candidates ~neutral_blocks_longs ~ranking
    ~candidates ~macro_trend : scored_candidate list =
  if not (_longs_admitted_by_macro ~neutral_blocks_longs macro_trend) then []
  else
    let candidate_fn =
      _long_candidate ~weights ~thresholds ~params ~min_grade
        ~min_score_override ~max_score_override ~volume_ratio_exclude_range
        ~min_price ~early_stage2_max_weeks
    in
    _filter_and_cap ~ranking ~candidate_fn ~max_n:max_buy_candidates candidates

(** Filter, score, grade, sort, and cap short candidates.

    Two default-off gates tighten short admission toward Weinstein's
    confirmed-bear short rule:
    - [neutral_blocks_shorts]: when [true], a [Neutral] tape no longer admits
      shorts (see {!_shorts_admitted_by_macro}).
    - [enable_slow_grind_short_gate]: when [true], shorts are admitted only when
      the current index decline is a slow grind ([decline_is_slow_grind]).
      [decline_is_slow_grind] is computed by the caller (the strategy lib, which
      owns the macro/decline-character classification) and passed in as a plain
      bool so this lib stays macro-agnostic. When the gate is [false] (default)
      the bool is ignored entirely — bit-identical to the prior behaviour. *)
let _evaluate_shorts ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~volume_ratio_exclude_range ~min_price
    ~max_short_candidates ~neutral_blocks_shorts ~enable_slow_grind_short_gate
    ~ranking ~decline_is_slow_grind ~candidates ~macro_trend :
    scored_candidate list =
  let macro_admits =
    _shorts_admitted_by_macro ~neutral_blocks_shorts macro_trend
  in
  let slow_grind_admits =
    (not enable_slow_grind_short_gate) || decline_is_slow_grind
  in
  if not (macro_admits && slow_grind_admits) then []
  else
    let candidate_fn =
      _short_candidate ~weights ~thresholds ~params ~min_grade
        ~min_score_override ~max_score_override ~volume_ratio_exclude_range
        ~min_price
    in
    _filter_and_cap ~ranking ~candidate_fn ~max_n:max_short_candidates
      candidates

(** Build watchlist: breakout candidates with grade C/D not in the buy list.
    Empty when buys are inactive (Bearish market). *)
let _build_watchlist ~weights ~thresholds ~early_stage2_max_weeks ~candidates
    ~buy_candidates ~buys_active : (string * string) list =
  if not buys_active then []
  else
    List.filter_map candidates
      ~f:
        (_watchlist_entry ~weights ~thresholds ~early_stage2_max_weeks
           ~buy_candidates)

(* ------------------------------------------------------------------ *)
(* Main screener                                                        *)
(* ------------------------------------------------------------------ *)

(** Look up sector context for a ticker, defaulting to Neutral/Unknown. *)
let _resolve_sector ~sector_map ticker =
  Option.value
    (Hashtbl.find sector_map ticker)
    ~default:
      {
        sector_name = "Unknown";
        rating = Neutral;
        stage = Stage1 { weeks_in_base = 0 };
      }

(** Compute the cascade-diagnostics record for one screen call. Decoupled from
    [screen] so the latter stays within the 50-line linter cap. *)
let _diagnostics_for_screen ~weights ~grade_thresholds ~min_grade
    ~min_score_override ~max_score_override ~volume_ratio_exclude_range
    ~min_price ~early_stage2_max_weeks ~total_stocks ~candidates_after_held
    ~macro_trend ~candidates ~buy_candidates ~short_candidates =
  let long_phases =
    count_long_phases ~weights ~thresholds:grade_thresholds ~min_grade
      ~min_score_override ~max_score_override ~volume_ratio_exclude_range
      ~min_price ~early_stage2_max_weeks ~candidates
  in
  let short_phases =
    count_short_phases ~weights ~thresholds:grade_thresholds ~min_grade
      ~min_score_override ~max_score_override ~volume_ratio_exclude_range
      ~min_price ~candidates
  in
  Screener_cascade_diagnostics.build ~total_stocks ~candidates_after_held
    ~macro_trend ~long_phases ~short_phases
    ~long_top_n:(List.length buy_candidates)
    ~short_top_n:(List.length short_candidates)

(** Build the per-symbol cooldown set: tickers whose last stop-out is within
    [cooldown_weeks] of [as_of] are blocked from the cascade. Returns an empty
    set when the gate is disabled ([cooldown_weeks <= 0] or empty
    [last_stop_out_dates]) — preserves bit-equality with the pre-gate behaviour.
*)
let _cooldown_block_set ~cooldown_weeks ~as_of ~last_stop_out_dates =
  if cooldown_weeks <= 0 then String.Set.empty
  else
    let cooldown_days = cooldown_weeks * 7 in
    List.filter_map last_stop_out_dates ~f:(fun (ticker, stop_date) ->
        let elapsed = Date.diff as_of stop_date in
        if elapsed < cooldown_days then Some ticker else None)
    |> String.Set.of_list

(** Single-pass filter dropping [held], [cooldown], and non-member symbols.
    [is_member] defaults to always-true via [screen]; [screen_with_cooldown]
    wires it from [?membership_at] closed over [as_of]. *)
let _prepare_candidates ~stocks ~held_set ~cooldown_set ~sector_map ~is_member =
  List.filter_map stocks ~f:(fun (a : Stock_analysis.t) ->
      if Set.mem held_set a.ticker then None
      else if Set.mem cooldown_set a.ticker then None
      else if not (is_member a.ticker) then None
      else Some (a, _resolve_sector ~sector_map a.ticker))

(** Evaluate the long and short cascade paths for one screen call. Returns
    [(buy_candidates, short_candidates)]; decoupled from [_screen] so the latter
    stays within the 50-line linter cap. *)
let _evaluate_candidates ~config ~decline_is_slow_grind ~candidates ~macro_trend
    =
  let buy_candidates =
    _evaluate_longs ~weights:config.weights ~thresholds:config.grade_thresholds
      ~params:config.candidate_params ~min_grade:config.min_grade
      ~min_score_override:config.min_score_override
      ~max_score_override:config.max_score_override
      ~volume_ratio_exclude_range:config.volume_ratio_exclude_range
      ~min_price:config.min_price
      ~early_stage2_max_weeks:config.early_stage2_max_weeks
      ~max_buy_candidates:config.max_buy_candidates
      ~neutral_blocks_longs:config.neutral_blocks_longs
      ~ranking:config.candidate_ranking ~candidates ~macro_trend
  in
  let short_candidates =
    _evaluate_shorts ~weights:config.weights ~thresholds:config.grade_thresholds
      ~params:config.candidate_params ~min_grade:config.min_grade
      ~min_score_override:config.min_score_override
      ~max_score_override:config.max_score_override
      ~volume_ratio_exclude_range:config.volume_ratio_exclude_range
      ~min_price:config.min_price
      ~max_short_candidates:config.max_short_candidates
      ~neutral_blocks_shorts:config.neutral_blocks_shorts
      ~enable_slow_grind_short_gate:config.enable_slow_grind_short_gate
      ~ranking:config.candidate_ranking ~decline_is_slow_grind ~candidates
      ~macro_trend
  in
  (buy_candidates, short_candidates)

let _screen ~config ~decline_is_slow_grind ~macro_trend ~sector_map ~stocks
    ~held_tickers ~cooldown_set ~is_member : result =
  let held_set = String.Set.of_list held_tickers in
  let buys_active =
    _longs_admitted_by_macro ~neutral_blocks_longs:config.neutral_blocks_longs
      macro_trend
  in
  let total_stocks = List.length stocks in
  let candidates =
    _prepare_candidates ~stocks ~held_set ~cooldown_set ~sector_map ~is_member
  in
  let candidates_after_held = List.length candidates in
  let buy_candidates, short_candidates =
    _evaluate_candidates ~config ~decline_is_slow_grind ~candidates ~macro_trend
  in
  {
    buy_candidates;
    short_candidates;
    watchlist =
      _build_watchlist ~weights:config.weights
        ~thresholds:config.grade_thresholds
        ~early_stage2_max_weeks:config.early_stage2_max_weeks ~candidates
        ~buy_candidates ~buys_active;
    macro_trend;
    cascade_diagnostics =
      _diagnostics_for_screen ~weights:config.weights
        ~grade_thresholds:config.grade_thresholds ~min_grade:config.min_grade
        ~min_score_override:config.min_score_override
        ~max_score_override:config.max_score_override
        ~volume_ratio_exclude_range:config.volume_ratio_exclude_range
        ~min_price:config.min_price
        ~early_stage2_max_weeks:config.early_stage2_max_weeks ~total_stocks
        ~candidates_after_held ~macro_trend ~candidates ~buy_candidates
        ~short_candidates;
  }

let screen ~config ~macro_trend ~sector_map ~stocks ~held_tickers : result =
  _screen ~config ~decline_is_slow_grind:true ~macro_trend ~sector_map ~stocks
    ~held_tickers ~cooldown_set:String.Set.empty ~is_member:(fun _ -> true)

let screen_with_cooldown ?membership_at ?(decline_is_slow_grind = true) ~config
    ~macro_trend ~sector_map ~stocks ~held_tickers ~as_of ~last_stop_out_dates
    () : result =
  let cooldown_set =
    _cooldown_block_set ~cooldown_weeks:config.cascade_post_stop_cooldown_weeks
      ~as_of ~last_stop_out_dates
  in
  let is_member ticker =
    match membership_at with None -> true | Some m -> m ticker as_of
  in
  _screen ~config ~decline_is_slow_grind ~macro_trend ~sector_map ~stocks
    ~held_tickers ~cooldown_set ~is_member
