(* @large-module: screener cascade integrates multiple analysis passes in a single pipeline *)
open Core
open Weinstein_types
include Screener_scoring

type candidate_params = {
  entry_buffer_pct : float;
      (** Fraction above breakout price for the suggested entry. Default: 0.005.
      *)
  initial_stop_pct : float;
      (** Fraction below entry for the long initial stop. Default: 0.08. *)
  short_stop_pct : float;
      (** Fraction above entry for the short initial stop. Default: 0.08. *)
  base_low_proxy_pct : float;
      (** Fraction below MA used as proxy for the prior base low. Default: 0.15.
      *)
  breakout_fallback_pct : float;
      (** Fraction above MA used as breakout price when none is detected.
          Default: 0.05. *)
}
[@@deriving sexp]
(** Per-candidate price computation parameters. All configurable. *)

let default_candidate_params =
  {
    entry_buffer_pct = 0.005;
    initial_stop_pct = 0.08;
    short_stop_pct = 0.08;
    base_low_proxy_pct = 0.15;
    breakout_fallback_pct = 0.05;
  }

type config = {
  weights : scoring_weights;
  grade_thresholds : grade_thresholds;
  candidate_params : candidate_params;
  min_grade : grade;
  min_score_override : int option; [@sexp.default None]
  max_score_override : int option; [@sexp.default None]
  max_buy_candidates : int;
  max_short_candidates : int;
  cascade_post_stop_cooldown_weeks : int; [@sexp.default 0]
}
[@@deriving sexp]

let default_config =
  {
    weights = default_scoring_weights;
    grade_thresholds = default_grade_thresholds;
    candidate_params = default_candidate_params;
    min_grade = C;
    min_score_override = None;
    max_score_override = None;
    max_buy_candidates = 20;
    max_short_candidates = 10;
    cascade_post_stop_cooldown_weeks = 0;
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

type cascade_diagnostics = {
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

(** Score gate: [true] iff [score] passes both the configured floor and the
    optional ceiling. [min_score_override = Some n] makes the floor [score >= n]
    and bypasses {!min_grade}; [None] (default) uses the grade-derived floor.
    [max_score_override = Some m] adds a strict [score < m] ceiling.

    Single source of truth so the score-and-build path and the
    diagnostics-counting predicates can't drift. *)
let _passes_score_floor ~thresholds ~min_grade ~min_score_override
    ~max_score_override score =
  (match min_score_override with
    | Some n -> score >= n
    | None -> compare_grade (grade_of_score ~thresholds score) min_grade <= 0)
  && match max_score_override with Some m -> score < m | None -> true

(** Score, grade, and build a candidate after passing preliminary gates. Returns
    [None] if [score] does not pass {!_passes_score_floor}. *)
let _score_and_build ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~is_short ~scorer ~sector a =
  let score, reasons = scorer ~weights ~sector a in
  if
    not
      (_passes_score_floor ~thresholds ~min_grade ~min_score_override
         ~max_score_override score)
  then None
  else
    Some
      (_build_candidate ~params ~sector ~a ~score ~reasons ~thresholds ~is_short)

(** Evaluate one (analysis, sector) pair as a long candidate. Returns [None] if
    excluded by the sector gate, breakout test, or score floor. *)
let _long_candidate ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override (a, sector) =
  if equal_sector_rating sector.rating Weak then None
  else if not (Stock_analysis.is_breakout_candidate a) then None
  else
    _score_and_build ~weights ~thresholds ~params ~min_grade ~min_score_override
      ~max_score_override ~is_short:false ~scorer:score_long ~sector a

(** Hard gate per Weinstein Ch. 11: never short a stock with strong relative
    strength, even if it breaks down. Rejects candidates whose RS trend is
    positive ([Positive_rising], [Positive_flat], [Bullish_crossover]).
    [Negative_improving] stays eligible — the stock is still rated negative
    overall and the scorer reflects the weaker signal. Absent RS data is treated
    as not-strong (doesn't block shorts). *)
let _rs_blocks_short = function
  | Some { Rs.trend = Positive_rising | Positive_flat | Bullish_crossover; _ }
    ->
      true
  | _ -> false

(** Evaluate one (analysis, sector) pair as a short candidate. Bearish/Neutral
    only: score must pass {!_passes_score_floor}. *)
let _short_candidate ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override (a, sector) =
  if equal_sector_rating sector.rating Strong then None
  else if not (Stock_analysis.is_breakdown_candidate a) then None
  else if _rs_blocks_short a.Stock_analysis.rs then None
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
let _watchlist_entry ~weights ~thresholds ~buy_candidates (sa, sector) =
  if not (Stock_analysis.is_breakout_candidate sa) then None
  else
    let score, _ = score_long ~weights ~sector sa in
    _check_watchlist_grade ~thresholds ~buy_candidates ~score sa

(* ------------------------------------------------------------------ *)
(* Evaluate + sort + cap                                               *)
(* ------------------------------------------------------------------ *)

let _top_n n lst =
  (* Secondary sort by ticker breaks score ties deterministically. Without
     it, [List.sort]'s stability depends on the input ordering — which in
     turn depends on Hashtbl iteration order, and that diverges between
     macOS and Linux. A G15-step-3 panel-golden CI failure surfaced this:
     local regenerated more round_trips than GHA produced, with the diff
     being a tied-score candidate that landed on either side of a
     cash-budget boundary depending on its position in the sorted list. *)
  List.sort lst ~compare:(fun a b ->
      let by_score = Int.compare b.score a.score in
      if by_score <> 0 then by_score else String.compare a.ticker b.ticker)
  |> fun l -> List.sub l ~pos:0 ~len:(min n (List.length l))

(** Long-side admission predicates: per-pair, returns one bool per phase that
    actually got evaluated. Phases short-circuit (a [false] earlier means later
    bools are [false]) so [(true, true, true)] means the pair passed all three
    gates. *)
let _long_admission ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override (a, sector) =
  let passes_breakout = Stock_analysis.is_breakout_candidate a in
  let passes_sector =
    passes_breakout && not (equal_sector_rating sector.rating Weak)
  in
  let passes_grade =
    if not passes_sector then false
    else
      let score, _ = score_long ~weights ~sector a in
      _passes_score_floor ~thresholds ~min_grade ~min_score_override
        ~max_score_override score
  in
  (passes_breakout, passes_sector, passes_grade)

(** Bump the counter by one when [b] is [true]. *)
let _bump n b = if b then n + 1 else n

(** Long-side phase counts for the cascade-diagnostics record. Folds the
    per-pair predicate triple into running counts. *)
let _count_long_phases ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~candidates =
  List.fold candidates ~init:(0, 0, 0)
    ~f:(fun (breakout, sector_ok, grade_ok) pair ->
      let pb, ps, pg =
        _long_admission ~weights ~thresholds ~min_grade ~min_score_override
          ~max_score_override pair
      in
      (_bump breakout pb, _bump sector_ok ps, _bump grade_ok pg))

(** Short-side admission predicates. Mirrors [_long_admission] with the RS hard
    gate inserted between sector and grade — see [_short_candidate]. *)
let _short_admission ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override (a, sector) =
  let passes_breakdown = Stock_analysis.is_breakdown_candidate a in
  let passes_sector =
    passes_breakdown && not (equal_sector_rating sector.rating Strong)
  in
  let passes_rs = passes_sector && not (_rs_blocks_short a.Stock_analysis.rs) in
  let passes_grade =
    if not passes_rs then false
    else
      let score, _ = score_short ~weights ~sector a in
      _passes_score_floor ~thresholds ~min_grade ~min_score_override
        ~max_score_override score
  in
  (passes_breakdown, passes_sector, passes_rs, passes_grade)

(** Short-side phase counts mirroring [_count_long_phases]. *)
let _count_short_phases ~weights ~thresholds ~min_grade ~min_score_override
    ~max_score_override ~candidates =
  List.fold candidates ~init:(0, 0, 0, 0)
    ~f:(fun (breakdown, sector_ok, rs_ok, grade_ok) pair ->
      let pb, ps, pr, pg =
        _short_admission ~weights ~thresholds ~min_grade ~min_score_override
          ~max_score_override pair
      in
      (_bump breakdown pb, _bump sector_ok ps, _bump rs_ok pr, _bump grade_ok pg))

(** Apply [candidate_fn] to each pair, drop [None]s, sort by score, and cap at
    [max_n]. Shared by the long and short evaluation paths. *)
let _filter_and_cap ~candidate_fn ~max_n candidates =
  List.filter_map candidates ~f:candidate_fn |> _top_n max_n

(** Filter, score, grade, sort, and cap long candidates. *)
let _evaluate_longs ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~max_buy_candidates ~candidates ~macro_trend :
    scored_candidate list =
  match macro_trend with
  | Bearish -> []
  | Bullish | Neutral ->
      let candidate_fn =
        _long_candidate ~weights ~thresholds ~params ~min_grade
          ~min_score_override ~max_score_override
      in
      _filter_and_cap ~candidate_fn ~max_n:max_buy_candidates candidates

(** Filter, score, grade, sort, and cap short candidates. *)
let _evaluate_shorts ~weights ~thresholds ~params ~min_grade ~min_score_override
    ~max_score_override ~max_short_candidates ~candidates ~macro_trend :
    scored_candidate list =
  match macro_trend with
  | Bullish -> []
  | Bearish | Neutral ->
      let candidate_fn =
        _short_candidate ~weights ~thresholds ~params ~min_grade
          ~min_score_override ~max_score_override
      in
      _filter_and_cap ~candidate_fn ~max_n:max_short_candidates candidates

(** Build watchlist: breakout candidates with grade C/D not in the buy list.
    Empty when buys are inactive (Bearish market). *)
let _build_watchlist ~weights ~thresholds ~candidates ~buy_candidates
    ~buys_active : (string * string) list =
  if not buys_active then []
  else
    List.filter_map candidates
      ~f:(_watchlist_entry ~weights ~thresholds ~buy_candidates)

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

(** Build the cascade-diagnostics record from the per-side phase counts and the
    final top-N counts. Pure projection. *)
let _build_cascade_diagnostics ~total_stocks ~candidates_after_held ~macro_trend
    ~long_phases ~short_phases ~buy_candidates ~short_candidates =
  let long_breakout, long_sector, long_grade = long_phases in
  let short_breakdown, short_sector, short_rs, short_grade = short_phases in
  let long_macro_admitted =
    match macro_trend with
    | Bearish -> 0
    | Bullish | Neutral -> candidates_after_held
  in
  let short_macro_admitted =
    match macro_trend with
    | Bullish -> 0
    | Bearish | Neutral -> candidates_after_held
  in
  (* When the macro gate closes the side, downstream phase counts collapse to
     0 — the screener never evaluates them. The fold above runs over all
     candidates regardless of macro, so we reset here to keep the post-macro
     phases consistent with what the screener actually emitted. *)
  let zero_if (gate : int) (n : int) = if gate = 0 then 0 else n in
  {
    total_stocks;
    candidates_after_held;
    macro_trend;
    long_macro_admitted;
    long_breakout_admitted = zero_if long_macro_admitted long_breakout;
    long_sector_admitted = zero_if long_macro_admitted long_sector;
    long_grade_admitted = zero_if long_macro_admitted long_grade;
    long_top_n_admitted = List.length buy_candidates;
    short_macro_admitted;
    short_breakdown_admitted = zero_if short_macro_admitted short_breakdown;
    short_sector_admitted = zero_if short_macro_admitted short_sector;
    short_rs_hard_gate_admitted = zero_if short_macro_admitted short_rs;
    short_grade_admitted = zero_if short_macro_admitted short_grade;
    short_top_n_admitted = List.length short_candidates;
  }

(** Compute the cascade-diagnostics record for one screen call. Decoupled from
    [screen] so the latter stays within the 50-line linter cap. *)
let _diagnostics_for_screen ~weights ~grade_thresholds ~min_grade
    ~min_score_override ~max_score_override ~total_stocks ~candidates_after_held
    ~macro_trend ~candidates ~buy_candidates ~short_candidates =
  let long_phases =
    _count_long_phases ~weights ~thresholds:grade_thresholds ~min_grade
      ~min_score_override ~max_score_override ~candidates
  in
  let short_phases =
    _count_short_phases ~weights ~thresholds:grade_thresholds ~min_grade
      ~min_score_override ~max_score_override ~candidates
  in
  _build_cascade_diagnostics ~total_stocks ~candidates_after_held ~macro_trend
    ~long_phases ~short_phases ~buy_candidates ~short_candidates

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

(** Single-pass filter that drops [held] and [cooldown] symbols and resolves
    each survivor's sector context. Was a chained [filter |> map] allocating two
    lists; the [filter_map] keeps just one. Runs every Friday over the full
    screened universe (potentially thousands of symbols). *)
let _prepare_candidates ~stocks ~held_set ~cooldown_set ~sector_map =
  List.filter_map stocks ~f:(fun (a : Stock_analysis.t) ->
      if Set.mem held_set a.ticker then None
      else if Set.mem cooldown_set a.ticker then None
      else Some (a, _resolve_sector ~sector_map a.ticker))

let _screen ~config ~macro_trend ~sector_map ~stocks ~held_tickers ~cooldown_set
    : result =
  let held_set = String.Set.of_list held_tickers in
  let {
    weights;
    grade_thresholds;
    candidate_params;
    min_grade;
    min_score_override;
    max_score_override;
    max_buy_candidates;
    max_short_candidates;
    cascade_post_stop_cooldown_weeks = _;
  } =
    config
  in
  let buys_active =
    match macro_trend with Bullish | Neutral -> true | Bearish -> false
  in
  let total_stocks = List.length stocks in
  let candidates =
    _prepare_candidates ~stocks ~held_set ~cooldown_set ~sector_map
  in
  let candidates_after_held = List.length candidates in
  let buy_candidates =
    _evaluate_longs ~weights ~thresholds:grade_thresholds
      ~params:candidate_params ~min_grade ~min_score_override
      ~max_score_override ~max_buy_candidates ~candidates ~macro_trend
  in
  let short_candidates =
    _evaluate_shorts ~weights ~thresholds:grade_thresholds
      ~params:candidate_params ~min_grade ~min_score_override
      ~max_score_override ~max_short_candidates ~candidates ~macro_trend
  in
  {
    buy_candidates;
    short_candidates;
    watchlist =
      _build_watchlist ~weights ~thresholds:grade_thresholds ~candidates
        ~buy_candidates ~buys_active;
    macro_trend;
    cascade_diagnostics =
      _diagnostics_for_screen ~weights ~grade_thresholds ~min_grade
        ~min_score_override ~max_score_override ~total_stocks
        ~candidates_after_held ~macro_trend ~candidates ~buy_candidates
        ~short_candidates;
  }

let screen ~config ~macro_trend ~sector_map ~stocks ~held_tickers : result =
  _screen ~config ~macro_trend ~sector_map ~stocks ~held_tickers
    ~cooldown_set:String.Set.empty

let screen_with_cooldown ~config ~macro_trend ~sector_map ~stocks ~held_tickers
    ~as_of ~last_stop_out_dates : result =
  let cooldown_set =
    _cooldown_block_set ~cooldown_weeks:config.cascade_post_stop_cooldown_weeks
      ~as_of ~last_stop_out_dates
  in
  _screen ~config ~macro_trend ~sector_map ~stocks ~held_tickers ~cooldown_set
