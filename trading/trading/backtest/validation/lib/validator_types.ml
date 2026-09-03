open Core

let _default_overhead_pct = 0.25
let _default_overhead_lookback_bars = 260
let _default_spike_pct = 0.60
let _default_spike_lookback_weeks = 4
let _default_virgin_lookback_bars = 520
let _default_adv_lookback_bars = 20
let _default_stop_distance_min_pct = 0.0
let _default_stop_distance_max_pct = 0.30
let _default_gate_max_stop_distance_pct = 0.15
let _default_fill_price_epsilon_pct = 1e-6
let _default_entry_bar_stopout_max_bars = 1
let _default_splice_pnl_pct_threshold = 100.0
let _default_splice_max_days_held = 5
let _default_splice_adj_ratio_min = 0.4
let _default_splice_adj_ratio_max = 2.5
let far_future = Date.of_string "2100-01-01"

type severity = Invariant | Expectation [@@deriving sexp, equal]

type trade_row = {
  symbol : string;
  side : string;
  entry_date : Date.t;
  exit_date : Date.t;
  entry_price : float;
  exit_price : float;
  quantity : float;
  exit_trigger : string;
  stop_trigger_kind : string;
  stop_initial_distance_pct : float option;
  position_id : string option;
  stop_fill_distance_pct : float option;
}

type open_row = {
  symbol : string;
  side : string;
  entry_date : Date.t;
  entry_price : float;
  quantity : float;
}

type entry_context = {
  stage : Weinstein_types.stage;
  macro_trend : Weinstein_types.market_trend;
  ma_direction : Weinstein_types.ma_direction;
  resistance_quality : Weinstein_types.overhead_quality option;
  installed_stop : float; [@sexp.default 0.0]
  suggested_entry : float; [@sexp.default 0.0]
}
[@@deriving sexp]

type daily_bar = {
  date : Date.t;
  open_price : float;
  high : float;
  low : float;
  close : float;
  adjusted_close : float;
  volume : int;
}

type bars = {
  weekly_dates : Date.t array;
  weekly_closes : float array;
  daily : daily_bar array;
}

type check_config = {
  overhead_pct : float; [@sexp.default _default_overhead_pct]
  overhead_lookback_bars : int; [@sexp.default _default_overhead_lookback_bars]
  spike_pct : float; [@sexp.default _default_spike_pct]
  spike_lookback_weeks : int; [@sexp.default _default_spike_lookback_weeks]
  virgin_lookback_bars : int; [@sexp.default _default_virgin_lookback_bars]
  min_entry_dollar_adv : float option; [@sexp.default None]
  adv_lookback_bars : int; [@sexp.default _default_adv_lookback_bars]
  stale_exit_after_days : int option; [@sexp.default None]
  stop_distance_min_pct : float; [@sexp.default _default_stop_distance_min_pct]
  stop_distance_max_pct : float; [@sexp.default _default_stop_distance_max_pct]
  gate_max_stop_distance_pct : float;
      [@sexp.default _default_gate_max_stop_distance_pct]
  fill_price_epsilon_pct : float;
      [@sexp.default _default_fill_price_epsilon_pct]
  entry_bar_stopout_max_bars : int;
      [@sexp.default _default_entry_bar_stopout_max_bars]
  splice_pnl_pct_threshold : float;
      [@sexp.default _default_splice_pnl_pct_threshold]
  splice_max_days_held : int; [@sexp.default _default_splice_max_days_held]
  splice_adj_ratio_min : float; [@sexp.default _default_splice_adj_ratio_min]
  splice_adj_ratio_max : float; [@sexp.default _default_splice_adj_ratio_max]
  disabled_checks : string list; [@sexp.default []]
  severity_overrides : (string * string) list; [@sexp.default []]
}
[@@deriving sexp]

type specimen = { symbol : string; entry_date : string; detail : string }
[@@deriving sexp]

type check_result = {
  id : string;
  severity : severity;
  passed : bool;
  n_violations : int;
  n_skipped : int;
  specimens : specimen list;
}
[@@deriving sexp]

type audit_join = { matched : int; total : int } [@@deriving sexp]

type report = { checks : check_result list; audit_join : audit_join }
[@@deriving sexp]

type inputs = {
  trades : trade_row list;
  open_positions : open_row list;
  audit : trade_row -> entry_context option;
  bars : string -> bars option;
  run_end : Date.t;
  config : check_config;
}

let default_config =
  {
    overhead_pct = _default_overhead_pct;
    overhead_lookback_bars = _default_overhead_lookback_bars;
    spike_pct = _default_spike_pct;
    spike_lookback_weeks = _default_spike_lookback_weeks;
    virgin_lookback_bars = _default_virgin_lookback_bars;
    min_entry_dollar_adv = None;
    adv_lookback_bars = _default_adv_lookback_bars;
    stale_exit_after_days = None;
    stop_distance_min_pct = _default_stop_distance_min_pct;
    stop_distance_max_pct = _default_stop_distance_max_pct;
    gate_max_stop_distance_pct = _default_gate_max_stop_distance_pct;
    fill_price_epsilon_pct = _default_fill_price_epsilon_pct;
    entry_bar_stopout_max_bars = _default_entry_bar_stopout_max_bars;
    splice_pnl_pct_threshold = _default_splice_pnl_pct_threshold;
    splice_max_days_held = _default_splice_max_days_held;
    splice_adj_ratio_min = _default_splice_adj_ratio_min;
    splice_adj_ratio_max = _default_splice_adj_ratio_max;
    disabled_checks = [];
    severity_overrides = [];
  }

let load_config = function
  | None -> default_config
  | Some path -> check_config_of_sexp (Sexp.load_sexp path)

let empty_inputs ?(config = default_config) () =
  {
    trades = [];
    open_positions = [];
    audit = (fun _ -> None);
    bars = (fun _ -> None);
    run_end = far_future;
    config;
  }
