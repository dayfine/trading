open Core

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
  stop_update_cadence : Stops_runner.stop_update_cadence;
      [@sexp.default Stops_runner.Daily]
      (** Cadence for trailing-stop trail advancement (G11). [Daily] (the
          default) preserves all existing baselines: the trail can tighten on
          every daily bar. [Weekly] only advances the state machine on Friday
          ticks, matching Weinstein Ch. 6 §Stop-Loss Rules ("trail moves only on
          weekly close"). Trigger logic stays continuous in both modes. *)
  stage3_force_exit_config : Stage3_force_exit.config;
      [@sexp.default Stage3_force_exit.default_config]
      (** Stage-3 force-exit detector parameters (issue #872). Default
          [{ hysteresis_weeks = 2 }] — fires on the second consecutive Friday
          Stage-3 classification of a held long position. *)
  enable_stage3_force_exit : bool; [@sexp.default false]
      (** Master switch for the Stage-3 force-exit runner. Default [false]
          preserves all existing baselines: the runner is a no-op and the
          strategy emits no [StrategySignal "stage3_force_exit"] transitions.
          Flipping to [true] activates {!Stage3_force_exit_runner.update} on
          every Friday tick. *)
  stage3_reentry_cooldown_weeks : int; [@sexp.default 0]
      (** Reserved for future tuning — currently unwired (default [0] = no
          cooldown applied). Once wired, would suppress cascade re-admission of
          a symbol force-exited under Stage 3 for [N] weeks beyond the existing
          stop-out cooldown surface (#718). [0] is the book-aligned default
          (§5.2 "STATE: EXITED — IF whipsaw … acceptable to re-buy"). The knob
          exists on [config] so future tuning can flip it via sexp override
          without a code change. *)
  laggard_rotation_config : Laggard_rotation.config;
      [@sexp.default Laggard_rotation.default_config]
      (** Laggard-rotation detector parameters (issue #887). Default
          [{ hysteresis_weeks = 4; rs_window_weeks = 13 }] — fires on the fourth
          consecutive Friday observation of negative
          relative-strength-vs-benchmark over a rolling 13-week window. *)
  enable_laggard_rotation : bool; [@sexp.default false]
      (** Master switch for the laggard-rotation runner (issue #887). Default
          [false] preserves all existing baselines: the runner is a no-op and
          the strategy emits no [StrategySignal "laggard_rotation"] transitions.
      *)
  laggard_reentry_cooldown_weeks : int; [@sexp.default 0]
      (** Reserved for future tuning — currently unwired (default [0] = no
          cooldown applied beyond the existing stop-out cooldown surface #718).
          The knob exists on [config] so future tuning can flip it via sexp
          override without a code change. *)
}
[@@deriving sexp]

let default_config ~universe ~index_symbol =
  {
    universe;
    indices = { primary = index_symbol; global = [] };
    sector_etfs = [];
    stage_config = Stage.default_config;
    macro_config = Macro.default_config;
    screening_config = Screener.default_config;
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
    stop_update_cadence = Stops_runner.Daily;
    stage3_force_exit_config = Stage3_force_exit.default_config;
    enable_stage3_force_exit = false;
    stage3_reentry_cooldown_weeks = 0;
    laggard_rotation_config = Laggard_rotation.default_config;
    enable_laggard_rotation = false;
    laggard_reentry_cooldown_weeks = 0;
  }

let name = "Weinstein"
