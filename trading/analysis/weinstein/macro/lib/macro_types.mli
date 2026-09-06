open Weinstein_types

(** Types and default config values for macro analysis.

    Separated from [Macro] to keep the implementation file under the 300-line
    limit. [Macro] re-exports all of these via [include Macro_types]. *)

type indicator_reading = {
  name : string;
  signal : [ `Bullish | `Bearish | `Neutral ];
  weight : float;
  detail : string;
}
[@@deriving sexp]

type indicator_weights = {
  w_index_stage : float;
  w_ad_line : float;
  w_momentum_index : float;
  w_nh_nl : float;
  w_global : float;
}
[@@deriving sexp]

type indicator_thresholds = {
  ad_line_lookback : int;
  momentum_period : int;
  nh_nl_lookback : int;
  nh_nl_up_threshold : float;
  nh_nl_down_threshold : float;
  ad_min_bars : int;
  nh_nl_min_bars : int;
  global_consensus_threshold : float;
}
[@@deriving sexp]

type config = {
  stage_config : Stage.config;
  bullish_threshold : float;
  bearish_threshold : float;
  indicator_weights : indicator_weights;
  indicator_thresholds : indicator_thresholds;
  breadth_direction : Breadth_direction.config;
      [@sexp.default Breadth_direction.default_config]
}
[@@deriving sexp]

type ad_bar = { date : Core.Date.t; advancing : int; declining : int }

type breadth_bar = {
  date : Core.Date.t;
  universe_count : int;
  above_ma_count : int;
  new_highs : int;
  new_lows : int;
}
(** One day's universe-participation breadth. Counts, not percentages — the
    percentages are derived in {!Breadth_series_cache} so the divisor is always
    the same day's [universe_count]. Loaded by {!Breadth_bars}; see its [.mli]
    for provenance and the holiday-row rule. *)

type result = {
  index_stage : Stage.result;
  indicators : indicator_reading list;
  trend : market_trend;
  breadth_state : breadth_state;
  confidence : float;
  regime_changed : bool;
  rationale : string list;
}

type callbacks = {
  index_stage : Stage.callbacks;
  get_index_close : week_offset:int -> float option;
  get_cumulative_ad : week_offset:int -> float option;
  get_ad_momentum_ma : week_offset:int -> float option;
  get_pct_above_ma : week_offset:int -> float option;
  get_new_lows_pct : week_offset:int -> float option;
  global_index_stages : (string * Stage.callbacks) list;
}
(** Bundle of indicator callbacks consumed by [Macro.analyze_with_callbacks].
    Exposed at the [Macro_types] level so that the per-indicator helpers
    (defined in [Macro_indicators]) and the bar-list wrapper (defined in
    [Macro]) can share the type without circular references. *)

val default_indicator_weights : indicator_weights
val default_indicator_thresholds : indicator_thresholds
val default_config : config
