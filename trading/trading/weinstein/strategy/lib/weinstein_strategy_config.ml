open Core

(* Named defaults: see [weinstein_strategy_config_defaults.mli]. *)
include Weinstein_strategy_config_defaults

type index_config = { primary : string; global : (string * string) list }
[@@deriving sexp]

type config = {
  universe : string list;
  indices : index_config;
  sector_etfs : (string * string) list;
  stage_config : Stage.config;
  macro_config : Macro.config;
  screening_config : Screener.config;
  portfolio_config : Portfolio_risk.config;
  stops_config : Weinstein_stops.config;
  initial_stop_buffer : float;
  initial_stop_buffer_by_macro_state : Stop_buffer_by_state.t;
      [@sexp.default Stop_buffer_by_state.default]
      (** See [.mli]. *)
  lookback_bars : int;
  bar_history_max_lookback_days : int option;
  skip_ad_breadth : bool;
  skip_sector_etf_load : bool;
  universe_cap : int option;
  full_compute_tail_days : int option;
  enable_short_side : bool; [@sexp.default true]
  short_min_price : float; [@sexp.default 0.0]  (** See [.mli]. *)
  short_min_price_on_order_price : bool; [@sexp.default false]
      (** See [.mli]. *)
  short_borrow_min_dollar_adv : float; [@sexp.default 0.0]  (** See [.mli]. *)
  suppress_warmup_trading : bool; [@sexp.default true]  (** See [.mli]. *)
  stop_update_cadence : Stops_runner.stop_update_cadence;
      [@sexp.default Stops_runner.Daily]
      (** See [.mli]. *)
  stage3_force_exit_config : Stage3_force_exit.config;
      [@sexp.default Stage3_force_exit.default_config]
      (** See [.mli]. *)
  enable_stage3_force_exit : bool; [@sexp.default false]  (** See [.mli]. *)
  stage3_reentry_cooldown_weeks : int; [@sexp.default 0]  (** See [.mli]. *)
  stage3_exit_margin_pct : float; [@sexp.default 0.0]  (** See [.mli]. *)
  laggard_rotation_config : Laggard_rotation.config;
      [@sexp.default Laggard_rotation.default_config]
      (** See [.mli]. *)
  enable_laggard_rotation : bool; [@sexp.default false]  (** See [.mli]. *)
  laggard_reentry_cooldown_weeks : int; [@sexp.default 0]  (** See [.mli]. *)
  enable_continuation_buys : bool; [@sexp.default false]  (** See [.mli]. *)
  continuation_config : Continuation.config;
      [@sexp.default Continuation.default_config]
      (** See [.mli]. *)
  enable_pi_filter : bool; [@sexp.default false]  (** See [.mli]. *)
  margin_config : Trading_portfolio.Margin_config.t;
      [@sexp.default Trading_portfolio.Margin_config.default_config]
      (** See [.mli]. *)
  neutral_blocks_longs : bool; [@sexp.default false]  (** See [.mli]. *)
  deteriorating_blocks_longs : bool; [@sexp.default false]  (** See [.mli]. *)
  index_stage_veto_blocks_longs : bool; [@sexp.default false]
      (** See [.mli]. *)
  neutral_blocks_shorts : bool; [@sexp.default true]  (** See [.mli]. *)
  enable_slow_grind_short_gate : bool; [@sexp.default false]  (** See [.mli]. *)
  fast_v_arm_on_rate_alone : bool; [@sexp.default false]  (** See [.mli]. *)
  fast_v_min_rate_pct : float; [@sexp.default fast_v_min_rate_no_op]
      (** See [.mli]. *)
  reject_declining_ma_long_entry : bool; [@sexp.default false]
      (** See [.mli]. *)
  enable_late_stage2_stop_tighten : bool; [@sexp.default false]
      (** See [.mli]. *)
  late_stage2_stop_buffer_pct : float; [@sexp.default 0.0]  (** See [.mli]. *)
  enable_macro_bearish_exposure_trim : bool; [@sexp.default false]
      (** See [.mli]. *)
  macro_bearish_max_long_exposure_pct : float;
      [@sexp.default macro_bearish_no_op_cap]
      (** See [.mli]. *)
  stale_exit_after_days : int option;
      [@sexp.default Some default_stale_exit_days]
      (** See [.mli]. *)
  short_sleeve_fraction : float; [@sexp.default 0.0]  (** See [.mli]. *)
  extension_stop_config : Weinstein_stops.Extension_stop.config;
      [@sexp.default Weinstein_stops.Extension_stop.default_config]
      (** See [.mli]. *)
  liquidity_config : Liquidity_config.t;
      [@sexp.default Liquidity_config.default_config]
      (** See [.mli]. *)
  max_long_exposure_pct_entry : float; [@sexp.default 0.0]  (** See [.mli]. *)
  initial_long_margin_req : float; [@sexp.default 1.0]  (** See [.mli]. *)
  long_margin_rate_annual_pct : float; [@sexp.default 0.0]  (** See [.mli]. *)
  maintenance_long_pct : float; [@sexp.default 0.0]  (** See [.mli]. *)
  cash_yield : Trading_simulation_cash_yield.Cash_yield.source;
      [@sexp.default Trading_simulation_cash_yield.Cash_yield.default_source]
      (** See [.mli]. *)
  cash_yield_fee_bp : float;
      [@sexp.default Trading_simulation_cash_yield.Cash_yield.default_fee_bp]
      (** See [.mli]. *)
  dividend_crediting : bool; [@sexp.default false]  (** See [.mli]. *)
  split_dividend_guard : bool; [@sexp.default false]  (** See [.mli]. *)
  ex_dividend_stop_adjust : bool; [@sexp.default false]  (** See [.mli]. *)
  resistance_min_history_bars : int; [@sexp.default 0]  (** See [.mli]. *)
  resistance_lookback_bars : int; [@sexp.default 0]  (** See [.mli]. *)
  overhead_supply : Resistance_supply.config option; [@sexp.default None]
      (** See [.mli]. *)
  virgin_crossing_readmission : bool; [@sexp.default false]  (** See [.mli]. *)
  dawn_leverage_enabled : bool; [@sexp.default false]  (** See [.mli]. *)
  dawn_initial_long_margin_req : float; [@sexp.default 1.0]  (** See [.mli]. *)
  dawn_max_ma_flip_age_weeks : int;
      [@sexp.default default_dawn_max_flip_age_weeks]
      (** See [.mli]. *)
  sparse_tail_min_bars : int; [@sexp.default 0]  (** See [.mli]. *)
  sparse_tail_window_trading_days : int; [@sexp.default 0]  (** See [.mli]. *)
  spike_bar_threshold_pct : float; [@sexp.default 0.0]  (** See [.mli]. *)
  rename_detect_min_overlap_days : int; [@sexp.default 0]  (** See [.mli]. *)
  rename_detect_match_fraction : float; [@sexp.default 0.0]  (** See [.mli]. *)
  entry_through_band_pct : float; [@sexp.default 0.0]  (** See [.mli]. *)
  entry_extension_max_pct : float;
      [@sexp.default default_entry_extension_max_pct]
      (** See [.mli]. *)
  enable_sim_entry_stoplimit : bool; [@sexp.default true]  (** See [.mli]. *)
  sim_entry_trigger_at_suggested : bool; [@sexp.default false]
      (** See [.mli]. *)
  entry_anchor_local_range_weeks : int; [@sexp.default 0]  (** See [.mli]. *)
  entry_freshness_basis : Entry_freshness.basis;
      [@sexp.default Entry_freshness.Ma_cross]
      (** See [.mli]. *)
  stop_anchor_at_entry_base : bool; [@sexp.default false]  (** See [.mli]. *)
  continuation_stop_at_pullback_low : bool; [@sexp.default false]
      (** See [.mli]. *)
  require_structural_stop : bool; [@sexp.default false]  (** See [.mli]. *)
  sim_entry_fill_next_open : bool; [@sexp.default false]  (** See [.mli]. *)
  sim_exit_fill_next_open : bool; [@sexp.default true]  (** See [.mli]. *)
  sim_entry_stoplimit_fresh_bar_only : bool; [@sexp.default false]  (** .mli *)
  sim_stop_exit_fill_on_trigger_bar : bool; [@sexp.default false]  (** .mli *)
  freeze_entry_at_first_breakout : bool; [@sexp.default false]
      (** See [.mli]. *)
  enable_entry_ticket_rescreen : bool; [@sexp.default false]  (** See [.mli]. *)
  entry_order_max_rest_weeks : int; [@sexp.default 52]  (** See [.mli]. *)
  short_cancel_on_non_bearish : bool; [@sexp.default false]  (** .mli *)
  short_entry_order_max_rest_weeks : int option; [@sexp.default None]
      (** See [.mli]. *)
  cancel_resting_entry_on_split : bool; [@sexp.default false]
      (** See [.mli]. *)
  reserve_cash_for_resting_tickets : bool; [@sexp.default false]
      (** See [.mli]. *)
  entry_fill_reject_retries : int; [@sexp.default 0]  (** See [.mli]. *)
  entry_fill_size_to_available : bool; [@sexp.default false]  (** See [.mli]. *)
  entry_fill_min_size_fraction : float; [@sexp.default 0.5]  (** See [.mli]. *)
  stop_width_mode : Stop_width_mode.t;
      [@sexp.default Stop_width_mode.Drop_over_max]
      (** See [.mli]. *)
  stop_width_size_down_max_pct : float; [@sexp.default 0.0]  (** See [.mli]. *)
  volume_confirm_at_fill : bool; [@sexp.default false]  (** See [.mli]. *)
  enable_rs_positive_declining : bool; [@sexp.default false]  (** See [.mli]. *)
  entry_max_bar_age_days : int; [@sexp.default 0]  (** See [.mli]. *)
  stale_exit_without_prior_bar : bool; [@sexp.default false]  (** See [.mli]. *)
  entry_ticket_macro_suspend : Entry_ticket_suspend_mode.t;
      [@sexp.default Entry_ticket_suspend_mode.Off]
      (** See [.mli]. *)
  max_one_share_class_per_issuer : bool; [@sexp.default false]
      (** See [.mli]. *)
  share_class_gate_covers_shorts : bool; [@sexp.default false]
      (** See [.mli]. *)
  share_class_groups : Share_class_map.t; [@sexp.default Share_class_map.empty]
      (** See [.mli]. *)
  trailing_stop_ma_period : int option; [@sexp.default None]  (** See [.mli]. *)
}
[@@deriving sexp]

(* Top-level so [default_config] stays a flat literal (nesting linter). *)
let _default_indices index_symbol = { primary = index_symbol; global = [] }

(* Promoted-bundle screening config (2026-07-23): standard defaults with the
   continuous overhead-supply weight armed. Pairs with [overhead_supply = Some
   Resistance_supply.default_config] in [default_config]; both must be armed. *)
let _default_screening_config =
  {
    Screener.default_config with
    weights =
      {
        Screener.default_config.weights with
        w_overhead_supply = Some bundle_w_overhead_supply;
      };
  }

(* Flat record literal, one line per field (no logic); OCaml has no partial
   record literals, so splitting would only add indirection.
   @large-function: flat default-config record literal, one line per field *)
let default_config ~universe ~index_symbol =
  {
    universe;
    indices = _default_indices index_symbol;
    sector_etfs = [];
    stage_config = Stage.default_config;
    macro_config = Macro.default_config;
    screening_config = _default_screening_config;
    portfolio_config = Portfolio_risk.default_config;
    stops_config = Weinstein_stops.default_config;
    initial_stop_buffer = 1.0;
    initial_stop_buffer_by_macro_state = Stop_buffer_by_state.default;
    (* 56 = Rs.rs_ma_period - 1 + Rs.trend_lookback + 1. See the [.mli]. *)
    lookback_bars = 56;
    bar_history_max_lookback_days = None;
    skip_ad_breadth = false;
    skip_sector_etf_load = false;
    universe_cap = None;
    full_compute_tail_days = None;
    enable_short_side = true;
    short_min_price = 0.0;
    short_min_price_on_order_price = false;
    short_borrow_min_dollar_adv = 0.0;
    suppress_warmup_trading = true;
    stop_update_cadence = Stops_runner.Daily;
    stage3_force_exit_config = Stage3_force_exit.default_config;
    enable_stage3_force_exit = false;
    stage3_reentry_cooldown_weeks = 0;
    stage3_exit_margin_pct = 0.0;
    laggard_rotation_config = Laggard_rotation.default_config;
    enable_laggard_rotation = false;
    laggard_reentry_cooldown_weeks = 0;
    enable_continuation_buys = false;
    continuation_config = Continuation.default_config;
    enable_pi_filter = false;
    margin_config = Trading_portfolio.Margin_config.default_config;
    neutral_blocks_longs = false;
    deteriorating_blocks_longs = false;
    index_stage_veto_blocks_longs = false;
    neutral_blocks_shorts = true;
    enable_slow_grind_short_gate = false;
    fast_v_arm_on_rate_alone = false;
    fast_v_min_rate_pct = fast_v_min_rate_no_op;
    reject_declining_ma_long_entry = false;
    enable_late_stage2_stop_tighten = false;
    late_stage2_stop_buffer_pct = 0.0;
    enable_macro_bearish_exposure_trim = false;
    macro_bearish_max_long_exposure_pct = macro_bearish_no_op_cap;
    stale_exit_after_days = Some default_stale_exit_days;
    short_sleeve_fraction = 0.0;
    extension_stop_config = Weinstein_stops.Extension_stop.default_config;
    liquidity_config = Liquidity_config.default_config;
    max_long_exposure_pct_entry = 0.0;
    initial_long_margin_req = 1.0;
    long_margin_rate_annual_pct = 0.0;
    maintenance_long_pct = 0.0;
    cash_yield = Trading_simulation_cash_yield.Cash_yield.default_source;
    cash_yield_fee_bp = Trading_simulation_cash_yield.Cash_yield.default_fee_bp;
    dividend_crediting = false;
    split_dividend_guard = false;
    ex_dividend_stop_adjust = false;
    resistance_min_history_bars = 0;
    resistance_lookback_bars = 0;
    overhead_supply = Some Resistance_supply.default_config;
    virgin_crossing_readmission = true;
    dawn_leverage_enabled = false;
    dawn_initial_long_margin_req = 1.0;
    dawn_max_ma_flip_age_weeks = default_dawn_max_flip_age_weeks;
    sparse_tail_min_bars = 0;
    sparse_tail_window_trading_days = 0;
    spike_bar_threshold_pct = 0.0;
    rename_detect_min_overlap_days = 0;
    rename_detect_match_fraction = 0.0;
    entry_through_band_pct = 0.0;
    entry_extension_max_pct = default_entry_extension_max_pct;
    enable_sim_entry_stoplimit = true;
    sim_entry_trigger_at_suggested = false;
    entry_anchor_local_range_weeks = 0;
    entry_freshness_basis = Entry_freshness.Ma_cross;
    stop_anchor_at_entry_base = false;
    continuation_stop_at_pullback_low = false;
    require_structural_stop = false;
    sim_entry_fill_next_open = false;
    sim_exit_fill_next_open = true;
    sim_entry_stoplimit_fresh_bar_only = false;
    sim_stop_exit_fill_on_trigger_bar = false;
    freeze_entry_at_first_breakout = false;
    enable_entry_ticket_rescreen = false;
    entry_order_max_rest_weeks = 52;
    short_cancel_on_non_bearish = false;
    short_entry_order_max_rest_weeks = None;
    cancel_resting_entry_on_split = false;
    reserve_cash_for_resting_tickets = false;
    entry_fill_reject_retries = 0;
    entry_fill_size_to_available = false;
    entry_fill_min_size_fraction = 0.5;
    stop_width_mode = Stop_width_mode.Drop_over_max;
    stop_width_size_down_max_pct = 0.0;
    volume_confirm_at_fill = false;
    enable_rs_positive_declining = false;
    entry_max_bar_age_days = 0;
    stale_exit_without_prior_bar = false;
    entry_ticket_macro_suspend = Entry_ticket_suspend_mode.Off;
    max_one_share_class_per_issuer = false;
    share_class_gate_covers_shorts = false;
    share_class_groups = Share_class_map.empty;
    trailing_stop_ma_period = None;
  }

(* F5 arming predicate, the one source for both halves (placement waiver +
   at-fill eject), so they cannot drift apart. See [.mli]. *)
let volume_confirm_at_fill_armed (c : config) : bool =
  c.volume_confirm_at_fill && c.sim_entry_trigger_at_suggested
  && c.enable_sim_entry_stoplimit

let name = "Weinstein"
