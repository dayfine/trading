open Core

(* No-op default for [macro_bearish_max_long_exposure_pct]: equals the normal
   long-exposure cap, so the trim never bites until a spec sets a tighter value. *)
let macro_bearish_no_op_cap = 0.70

(* No-op default for [fast_v_min_rate_pct]: equals [Decline_character]'s own
   [default_config.fast_v_min_rate_pct], so threading this value into the
   classifier config reproduces [default_config] exactly (bit-identical
   classification) until a spec sets a different fast-V arming rate threshold. *)
let fast_v_min_rate_no_op = 0.08

(* Default bar-gap (calendar days) after which [stale_exit_after_days] force-
   sells a stale/delisted held position at its last close. Flipped None ->
   Some 5 on 2026-07-10 (user mandate) as a REALISM/faithfulness basis change:
   the simulator must not hold ghosts (IN1 marked at its 2005 close for 20 years
   inside NAV; 5 zombie positions in the deep run — issue #1484 / flag #1487). *)
let default_stale_exit_days = 5

(* Grid-robust continuous overhead-supply ranking weight, armed into the default
   screening weights by the 2026-07-23 bundle promotion (user-approved, R3).
   w=30 was robust across the 3-cell confirmation grid (ledger
   [2026-07-17-resistance-supply-confirmation-grid]) and the bundle studies
   (ledger [2026-07-20-bundle-promotion-studies]); it replaces the binary
   virgin/clean grade points when the continuous supply score is present. *)
let bundle_w_overhead_supply = 30

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
  lookback_bars : int;
  bar_history_max_lookback_days : int option;
  skip_ad_breadth : bool;
  skip_sector_etf_load : bool;
  universe_cap : int option;
  full_compute_tail_days : int option;
  enable_short_side : bool; [@sexp.default true]
  short_min_price : float; [@sexp.default 0.0]  (** See [.mli]. *)
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
  enable_harvest_rotate : bool; [@sexp.default false]  (** See [.mli]. *)
  harvest_fraction : float; [@sexp.default 0.5]  (** See [.mli]. *)
  short_sleeve_fraction : float; [@sexp.default 0.0]  (** See [.mli]. *)
  extension_stop_config : Weinstein_stops.Extension_stop.config;
      [@sexp.default Weinstein_stops.Extension_stop.default_config]
      (** See [.mli]. *)
  liquidity_config : Liquidity_config.t;
      [@sexp.default Liquidity_config.default_config]
      (** See [.mli]. *)
  enable_scale_in : bool; [@sexp.default false]  (** See [.mli]. *)
  scale_in_config : Scale_in_detector.config;
      [@sexp.default Scale_in_detector.default_config]
      (** See [.mli]. *)
  cash_reserve_pct : float; [@sexp.default 0.0]  (** See [.mli]. *)
  max_long_exposure_pct_entry : float; [@sexp.default 0.0]  (** See [.mli]. *)
  initial_long_margin_req : float; [@sexp.default 1.0]  (** See [.mli]. *)
  long_margin_rate_annual_pct : float; [@sexp.default 0.0]  (** See [.mli]. *)
  maintenance_long_pct : float; [@sexp.default 0.0]  (** See [.mli]. *)
  resistance_min_history_bars : int; [@sexp.default 0]  (** See [.mli]. *)
  resistance_lookback_bars : int; [@sexp.default 0]  (** See [.mli]. *)
  overhead_supply : Resistance_supply.config option; [@sexp.default None]
      (** See [.mli]. *)
  virgin_crossing_readmission : bool; [@sexp.default false]  (** See [.mli]. *)
}
[@@deriving sexp]

(* Kept top-level so [default_config] stays a flat record literal (the
   nesting linter caps the file average). *)
let _default_indices index_symbol = { primary = index_symbol; global = [] }

(* Screening config for the promoted bundle (2026-07-23): the standard screener
   defaults with the continuous overhead-supply ranking weight armed. Pairs with
   [overhead_supply = Some Resistance_supply.default_config] in [default_config]
   — both must be armed for the continuous score to replace the binary grade
   points (either absent falls back to the bit-identical binary path). Kept
   top-level so [default_config] stays a flat one-line-per-field literal. *)
let _default_screening_config =
  {
    Screener.default_config with
    weights =
      {
        Screener.default_config.weights with
        w_overhead_supply = Some bundle_w_overhead_supply;
      };
  }

(* Flat record literal over every config field — exactly one line per field
   by construction (no logic), growing one line per new default-off
   experiment knob. OCaml has no partial record literals, so splitting is
   impossible and extracting field groups would only add indirection.
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
    initial_stop_buffer = 1.02;
    lookback_bars = 52;
    bar_history_max_lookback_days = None;
    skip_ad_breadth = false;
    skip_sector_etf_load = false;
    universe_cap = None;
    full_compute_tail_days = None;
    enable_short_side = true;
    short_min_price = 0.0;
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
    enable_harvest_rotate = false;
    harvest_fraction = 0.5;
    short_sleeve_fraction = 0.0;
    extension_stop_config = Weinstein_stops.Extension_stop.default_config;
    liquidity_config = Liquidity_config.default_config;
    enable_scale_in = false;
    scale_in_config = Scale_in_detector.default_config;
    cash_reserve_pct = 0.0;
    max_long_exposure_pct_entry = 0.0;
    initial_long_margin_req = 1.0;
    long_margin_rate_annual_pct = 0.0;
    maintenance_long_pct = 0.0;
    resistance_min_history_bars = 0;
    resistance_lookback_bars = 0;
    overhead_supply = Some Resistance_supply.default_config;
    virgin_crossing_readmission = true;
  }

let name = "Weinstein"
