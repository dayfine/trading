(* @large-module: screener cascade integrates multiple analysis passes in a single pipeline *)
open Core
open Weinstein_types

type sector_rating = Strong | Neutral | Weak [@@deriving show, eq, sexp]

type sector_context = {
  sector_name : string;
  rating : sector_rating;
  stage : stage;
}
[@@deriving sexp]

type scoring_weights = {
  w_stage2_breakout : int;
  w_strong_volume : int;
  w_adequate_volume : int;
  w_positive_rs : int;
  w_bullish_rs_crossover : int;
  w_clean_resistance : int;
  w_sector_strong : int;
  w_late_stage2_penalty : int;
}
[@@deriving sexp]

let default_scoring_weights =
  {
    w_stage2_breakout = 30;
    w_strong_volume = 20;
    w_adequate_volume = 10;
    w_positive_rs = 20;
    w_bullish_rs_crossover = 10;
    w_clean_resistance = 15;
    w_sector_strong = 10;
    w_late_stage2_penalty = -15;
  }

type grade_thresholds = { a_plus : int; a : int; b : int; c : int; d : int }
[@@deriving sexp]
(** Score cutoffs for each grade. All are configurable. *)

let default_grade_thresholds = { a_plus = 85; a = 70; b = 55; c = 40; d = 25 }

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
  max_buy_candidates : int;
  max_short_candidates : int;
}
[@@deriving sexp]

let default_config =
  {
    weights = default_scoring_weights;
    grade_thresholds = default_grade_thresholds;
    candidate_params = default_candidate_params;
    min_grade = C;
    max_buy_candidates = 20;
    max_short_candidates = 10;
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

type result = {
  buy_candidates : scored_candidate list;
  short_candidates : scored_candidate list;
  watchlist : (string * string) list;
  macro_trend : market_trend;
}

(* ------------------------------------------------------------------ *)
(* Scoring signal helpers                                               *)
(* ------------------------------------------------------------------ *)

(** Stage signal for long setups: Stage1→2 transition or early Stage2. *)
let _stage_long_signal ~w ~(a : Stock_analysis.t) =
  match (a.stage.stage, a.prior_stage) with
  | Stage2 _, Some (Stage1 _) ->
      [ (w.w_stage2_breakout, "Stage1→Stage2 breakout") ]
  | Stage2 { weeks_advancing; _ }, _ when weeks_advancing <= 4 ->
      [ (w.w_stage2_breakout / 2, "Early Stage2") ]
  | _ -> []

(** Late Stage2 deceleration penalty. *)
let _late_stage2_signal ~w ~(a : Stock_analysis.t) =
  match a.stage.stage with
  | Stage2 { late = true; _ } ->
      [ (w.w_late_stage2_penalty, "Late Stage2 (penalty)") ]
  | _ -> []

(** Volume confirmation signal. *)
let _volume_signal ~w ~(a : Stock_analysis.t) =
  match a.volume with
  | Some { confirmation = Strong _; _ } ->
      [ (w.w_strong_volume, "Strong volume") ]
  | Some { confirmation = Adequate _; _ } ->
      [ (w.w_adequate_volume, "Adequate volume") ]
  | _ -> []

(** Bullish RS signal for long setups. *)
let _rs_long_signal ~w ~(a : Stock_analysis.t) =
  match a.rs with
  | Some { trend = Bullish_crossover; _ } ->
      [ (w.w_positive_rs + w.w_bullish_rs_crossover, "RS bullish crossover") ]
  | Some { trend = Positive_rising; _ } ->
      [ (w.w_positive_rs, "RS positive & rising") ]
  | Some { trend = Positive_flat; _ } ->
      [ (w.w_positive_rs / 2, "RS positive") ]
  | _ -> []

(** Bearish RS signal for short setups. *)
let _rs_short_signal ~w ~(a : Stock_analysis.t) =
  match a.rs with
  | Some { trend = Bearish_crossover; _ } ->
      [ (w.w_positive_rs + w.w_bullish_rs_crossover, "RS bearish crossover") ]
  | Some { trend = Negative_declining; _ } ->
      [ (w.w_positive_rs, "RS negative & declining") ]
  | Some { trend = Negative_improving; _ } ->
      [ (w.w_positive_rs / 2, "RS negative") ]
  | _ -> []

(** Overhead resistance signal. *)
let _resistance_signal ~w ~(a : Stock_analysis.t) =
  match a.resistance with
  | Some { quality = Virgin_territory; _ } ->
      [ (w.w_clean_resistance, "Virgin territory") ]
  | Some { quality = Clean; _ } -> [ (w.w_clean_resistance, "Clean overhead") ]
  | Some { quality = Moderate_resistance; _ } ->
      [ (w.w_clean_resistance / 2, "Moderate resistance") ]
  | _ -> []

(** Sector bonus/penalty for long setups. *)
let _sector_long_signal ~w ~sector =
  match sector.rating with
  | Strong -> [ (w.w_sector_strong, "Strong sector") ]
  | Neutral -> []
  | Weak -> [ (-w.w_sector_strong, "Weak sector (penalty)") ]

(** Sector bonus/penalty for short setups. *)
let _sector_short_signal ~w ~sector =
  match sector.rating with
  | Weak -> [ (w.w_sector_strong, "Weak sector") ]
  | Neutral -> []
  | Strong -> [ (-w.w_sector_strong, "Strong sector (penalty)") ]

(** Stage signal for short setups: Stage3→4 transition or early Stage4. *)
let _stage_short_signal ~w ~(a : Stock_analysis.t) =
  match (a.stage.stage, a.prior_stage) with
  | Stage4 _, Some (Stage3 _) ->
      [ (w.w_stage2_breakout, "Stage3→Stage4 breakdown") ]
  | Stage4 { weeks_declining }, _ when weeks_declining <= 4 ->
      [ (w.w_stage2_breakout / 2, "Early Stage4") ]
  | _ -> []

(** Reduce a list of (points, label) signals to (total_score, rationale list).
    Zero-point entries are dropped from both the total and the rationale. *)
let _tally signals =
  let non_zero = List.filter signals ~f:(fun (pts, _) -> pts <> 0) in
  (List.sum (module Int) non_zero ~f:fst, List.map non_zero ~f:snd)

(* ------------------------------------------------------------------ *)
(* Scoring                                                              *)
(* ------------------------------------------------------------------ *)

(** Compute a long-side score for a stock analysis. *)
let _score_long ~weights ~sector (a : Stock_analysis.t) : int * string list =
  let w = weights in
  _tally
    (_stage_long_signal ~w ~a @ _late_stage2_signal ~w ~a @ _volume_signal ~w ~a
   @ _rs_long_signal ~w ~a @ _resistance_signal ~w ~a
    @ _sector_long_signal ~w ~sector)

(** Compute a short-side score for a stock analysis. *)
let _score_short ~weights ~sector (a : Stock_analysis.t) : int * string list =
  let w = weights in
  _tally
    (_stage_short_signal ~w ~a @ _rs_short_signal ~w ~a
    @ _sector_short_signal ~w ~sector)

(** Convert score to grade using configurable thresholds. *)
let _grade_of_score ~thresholds score =
  if score >= thresholds.a_plus then A_plus
  else if score >= thresholds.a then A
  else if score >= thresholds.b then B
  else if score >= thresholds.c then C
  else if score >= thresholds.d then D
  else F

(* ------------------------------------------------------------------ *)
(* Price and candidate helpers                                          *)
(* ------------------------------------------------------------------ *)

(** Suggested entry: breakout price plus a configurable buffer. *)
let _suggested_entry ~entry_buffer_pct breakout_price =
  let raw = breakout_price *. (1.0 +. entry_buffer_pct) in
  Float.round_nearest (raw *. 100.0) /. 100.0

(** Long stop: configurable fraction below entry. *)
let _suggested_stop ~initial_stop_pct entry = entry *. (1.0 -. initial_stop_pct)

(** Estimate swing target using simplified Weinstein swing rule: target =
    breakout + (breakout - base_low). *)
let _swing_target ~breakout ~base_low_opt =
  match base_low_opt with
  | None -> None
  | Some base_low ->
      if Float.(breakout > base_low) then
        Some (breakout +. (breakout -. base_low))
      else None

(** Proxy for the prior base low: configurable fraction below the 30-week MA. *)
let _base_low ~base_low_proxy_pct (a : Stock_analysis.t) : float option =
  match a.stage.ma_value with
  | v when Float.(v > 0.0) -> Some (v *. (1.0 -. base_low_proxy_pct))
  | _ -> None

let _build_candidate ~params ~sector ~(a : Stock_analysis.t) ~score ~reasons
    ~thresholds ~is_short : scored_candidate =
  let breakout =
    Option.value a.breakout_price
      ~default:(a.stage.ma_value *. (1.0 +. params.breakout_fallback_pct))
  in
  let entry =
    _suggested_entry ~entry_buffer_pct:params.entry_buffer_pct breakout
  in
  let stop_ =
    if is_short then entry *. (1.0 +. params.short_stop_pct)
    else _suggested_stop ~initial_stop_pct:params.initial_stop_pct entry
  in
  let risk_pct =
    if Float.(entry = 0.0) then 0.0 else Float.abs ((entry -. stop_) /. entry)
  in
  let base_low = _base_low ~base_low_proxy_pct:params.base_low_proxy_pct a in
  let swing =
    if is_short then None else _swing_target ~breakout ~base_low_opt:base_low
  in
  let side : Trading_base.Types.position_side =
    if is_short then Short else Long
  in
  {
    ticker = a.ticker;
    analysis = a;
    sector;
    side;
    grade = _grade_of_score ~thresholds score;
    score;
    suggested_entry = entry;
    suggested_stop = stop_;
    risk_pct;
    swing_target = swing;
    rationale = reasons;
  }

(* ------------------------------------------------------------------ *)
(* Per-candidate filters                                               *)
(* ------------------------------------------------------------------ *)

(** Score, grade, and build a candidate after passing preliminary gates. Returns
    [None] if the grade does not meet [min_grade]. *)
let _score_and_build ~weights ~thresholds ~params ~min_grade ~is_short ~scorer
    ~sector a =
  let score, reasons = scorer ~weights ~sector a in
  let grade = _grade_of_score ~thresholds score in
  if compare_grade grade min_grade > 0 then None
  else
    Some
      (_build_candidate ~params ~sector ~a ~score ~reasons ~thresholds ~is_short)

(** Evaluate one (analysis, sector) pair as a long candidate. Returns [None] if
    excluded by the sector gate, breakout test, or grade floor. *)
let _long_candidate ~weights ~thresholds ~params ~min_grade (a, sector) =
  if equal_sector_rating sector.rating Weak then None
  else if not (Stock_analysis.is_breakout_candidate a) then None
  else
    _score_and_build ~weights ~thresholds ~params ~min_grade ~is_short:false
      ~scorer:_score_long ~sector a

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
    only: grade must meet [min_grade]. *)
let _short_candidate ~weights ~thresholds ~params ~min_grade (a, sector) =
  if equal_sector_rating sector.rating Strong then None
  else if not (Stock_analysis.is_breakdown_candidate a) then None
  else if _rs_blocks_short a.Stock_analysis.rs then None
  else
    _score_and_build ~weights ~thresholds ~params ~min_grade ~is_short:true
      ~scorer:_score_short ~sector a

(** Check watchlist eligibility after the breakout gate. Returns [None] if the
    ticker is already in [buy_candidates] or the grade is above C/D. *)
let _check_watchlist_grade ~thresholds ~buy_candidates ~score
    (sa : Stock_analysis.t) =
  let grade = _grade_of_score ~thresholds score in
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
    let score, _ = _score_long ~weights ~sector sa in
    _check_watchlist_grade ~thresholds ~buy_candidates ~score sa

(* ------------------------------------------------------------------ *)
(* Evaluate + sort + cap                                               *)
(* ------------------------------------------------------------------ *)

let _top_n n lst =
  List.sort lst ~compare:(fun a b -> Int.compare b.score a.score) |> fun l ->
  List.sub l ~pos:0 ~len:(min n (List.length l))

(** Filter, score, grade, sort, and cap long candidates. *)
let _evaluate_longs ~weights ~thresholds ~params ~min_grade ~max_buy_candidates
    ~candidates ~macro_trend : scored_candidate list =
  match macro_trend with
  | Bearish -> []
  | Bullish | Neutral ->
      candidates
      |> List.filter_map
           ~f:(_long_candidate ~weights ~thresholds ~params ~min_grade)
      |> _top_n max_buy_candidates

(** Filter, score, grade, sort, and cap short candidates. *)
let _evaluate_shorts ~weights ~thresholds ~params ~min_grade
    ~max_short_candidates ~candidates ~macro_trend : scored_candidate list =
  match macro_trend with
  | Bullish -> []
  | Bearish | Neutral ->
      candidates
      |> List.filter_map
           ~f:(_short_candidate ~weights ~thresholds ~params ~min_grade)
      |> _top_n max_short_candidates

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

let screen ~config ~macro_trend ~sector_map ~stocks ~held_tickers : result =
  let held_set = String.Set.of_list held_tickers in
  let {
    weights;
    grade_thresholds;
    candidate_params;
    min_grade;
    max_buy_candidates;
    max_short_candidates;
  } =
    config
  in
  let buys_active =
    match macro_trend with Bullish | Neutral -> true | Bearish -> false
  in
  let candidates =
    stocks
    |> List.filter ~f:(fun (a : Stock_analysis.t) ->
        not (Set.mem held_set a.ticker))
    |> List.map ~f:(fun (a : Stock_analysis.t) ->
        (a, _resolve_sector ~sector_map a.ticker))
  in
  let buy_candidates =
    _evaluate_longs ~weights ~thresholds:grade_thresholds
      ~params:candidate_params ~min_grade ~max_buy_candidates ~candidates
      ~macro_trend
  in
  let short_candidates =
    _evaluate_shorts ~weights ~thresholds:grade_thresholds
      ~params:candidate_params ~min_grade ~max_short_candidates ~candidates
      ~macro_trend
  in
  let watchlist =
    _build_watchlist ~weights ~thresholds:grade_thresholds ~candidates
      ~buy_candidates ~buys_active
  in
  { buy_candidates; short_candidates; watchlist; macro_trend }
