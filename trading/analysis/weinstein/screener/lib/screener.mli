(** Weinstein cascade screener.

    Applies a three-level filter (macro → sector → stock) and returns ranked
    buy/short candidates with grades and suggested entry/stop.

    Cascade rules (from design doc): 1. MACRO GATE: Bearish market → no new
    buys. Bullish market → no new shorts (except A+ setups). Neutral → both
    active. 2. SECTOR FILTER: Stock in a Weak sector → excluded from buys. Stock
    in a Strong sector → excluded from shorts. 3. SCORING: Additive weighted
    score from config weights. 4. FILTER + SORT: Remove below min_grade. Remove
    already-held tickers. Sort by score descending.

    All functions are pure. *)

(** Sector health rating used by the screener gate. *)
type sector_rating = Strong | Neutral | Weak [@@deriving show, eq]

type sector_context = {
  sector_name : string;
  rating : sector_rating;
  stage : Weinstein_types.stage;
}
(** Minimal sector context the screener needs per stock. *)

type scoring_weights = {
  w_stage2_breakout : int;
      (** Weight for a clean Stage2 transition from Stage1. Default: 30. *)
  w_strong_volume : int;
      (** Weight for Strong volume confirmation. Default: 20. *)
  w_adequate_volume : int;
      (** Weight for Adequate volume confirmation. Default: 10. *)
  w_positive_rs : int;
      (** Weight for positive RS trend (Positive_rising or Bullish_crossover).
          Default: 20. *)
  w_bullish_rs_crossover : int;
      (** Additional weight for RS crossing from negative to positive. Default:
          10. *)
  w_clean_resistance : int;
      (** Weight for Virgin_territory or Clean overhead. Default: 15. *)
  w_sector_strong : int;  (** Weight bonus for a Strong sector. Default: 10. *)
  w_late_stage2_penalty : int;
      (** Negative weight for late Stage2 flag. Default: -15. *)
}
(** Scoring weights for each positive signal. All are configurable. *)

val default_scoring_weights : scoring_weights
(** [default_scoring_weights] provides the reference weights. *)

type config = {
  weights : scoring_weights;
  min_grade : Weinstein_types.grade;
      (** Minimum grade to include in output. Default: C. *)
  max_buy_candidates : int;
      (** Maximum number of buy candidates returned. Default: 20. *)
  max_short_candidates : int;
      (** Maximum number of short candidates returned. Default: 10. *)
}
(** Main screener configuration. *)

val default_config : config
(** [default_config] returns recommended defaults. *)

type scored_candidate = {
  ticker : string;
  analysis : Stock_analysis.t;
  sector : sector_context;
  grade : Weinstein_types.grade;
  score : int;
  suggested_entry : float;
      (** Suggested buy-stop entry price (breakout_price + small buffer). *)
  suggested_stop : float;
      (** Suggested initial stop-loss (below prior base low). *)
  risk_pct : float;
      (** (suggested_entry - suggested_stop) / suggested_entry. *)
  swing_target : float option;
      (** Estimated swing target using Weinstein's swing rule, if computable. *)
  rationale : string list;
      (** Human-readable list of signals that contributed to this grade. *)
}
(** A scored and graded candidate ready for the weekly report. *)

type result = {
  buy_candidates : scored_candidate list;  (** Ranked by score descending. *)
  short_candidates : scored_candidate list;  (** Ranked by score descending. *)
  watchlist : (string * string) list;
      (** Tickers with grade C that passed the filter but missed top-N.
          [(ticker, reason)]. *)
  macro_trend : Weinstein_types.market_trend;
      (** The macro trend used by the cascade gate. *)
}
(** Screener output. *)

val screen :
  config:config ->
  macro_trend:Weinstein_types.market_trend ->
  sector_map:(string, sector_context) Core.Hashtbl.t ->
  stocks:Stock_analysis.t list ->
  held_tickers:string list ->
  result
(** [screen ~config ~macro_trend ~sector_map ~stocks ~held_tickers] runs the
    cascade filter and returns ranked candidates.

    @param config Screener parameters.
    @param macro_trend Overall market trend from Macro analyzer.
    @param sector_map Map from ticker to sector context.
    @param stocks Per-stock analysis results.
    @param held_tickers Tickers already in portfolio — excluded from output.

    Pure function. *)
