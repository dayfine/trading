open Core
open Weinstein_types

type indicator_reading = {
  name : string;
  signal : [ `Bullish | `Bearish | `Neutral ];
  weight : float;
  detail : string;
}

type indicator_weights = {
  w_index_stage : float;
  w_ad_line : float;
  w_momentum_index : float;
  w_nh_nl : float;
  w_global : float;
}

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

type config = {
  stage_config : Stage.config;
  bullish_threshold : float;
  bearish_threshold : float;
  indicator_weights : indicator_weights;
  indicator_thresholds : indicator_thresholds;
}

type ad_bar = { date : Date.t; advancing : int; declining : int }

type result = {
  index_stage : Stage.result;
  indicators : indicator_reading list;
  trend : market_trend;
  confidence : float;
  regime_changed : bool;
  rationale : string list;
}

let default_indicator_weights =
  {
    w_index_stage = 3.0;
    w_ad_line = 2.0;
    w_momentum_index = 2.0;
    w_nh_nl = 1.5;
    w_global = 1.5;
  }

let default_indicator_thresholds =
  {
    ad_line_lookback = 26;
    momentum_period = 200;
    nh_nl_lookback = 13;
    nh_nl_up_threshold = 1.02;
    nh_nl_down_threshold = 0.98;
    ad_min_bars = 4;
    nh_nl_min_bars = 10;
    global_consensus_threshold = 0.6;
  }

let default_config =
  {
    stage_config = Stage.default_config;
    bullish_threshold = 0.65;
    bearish_threshold = 0.35;
    indicator_weights = default_indicator_weights;
    indicator_thresholds = default_indicator_thresholds;
  }
