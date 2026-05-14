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
      (** Cadence for trailing-stop trail advancement (G11). [Daily] preserves
          baselines; [Weekly] gates trail advancement to Friday ticks. *)
  stage3_force_exit_config : Stage3_force_exit.config;
      [@sexp.default Stage3_force_exit.default_config]
      (** Stage-3 force-exit detector parameters (issue #872). *)
  enable_stage3_force_exit : bool; [@sexp.default false]
      (** Master switch for the Stage-3 force-exit runner. Default [false]
          preserves all existing baselines. *)
  stage3_reentry_cooldown_weeks : int; [@sexp.default 0]
      (** Cascade re-admission cooldown (#718) for Stage-3 force-exited symbols.
          Default [0] = no extra cooldown. *)
  laggard_rotation_config : Laggard_rotation.config;
      [@sexp.default Laggard_rotation.default_config]
      (** Laggard-rotation detector parameters (issue #887). *)
  enable_laggard_rotation : bool; [@sexp.default false]
      (** Master switch for the laggard-rotation runner (issue #887). *)
  laggard_reentry_cooldown_weeks : int; [@sexp.default 0]
      (** Cascade re-admission cooldown (#718) for laggard-rotation exited
          symbols. Default [0] = no extra cooldown. *)
  enable_continuation_buys : bool; [@sexp.default false]
      (** Master switch for Weinstein Ch. 3 continuation-buy detection
          (Interpretation B of issue #889). Default [false] preserves baselines.
      *)
  continuation_config : Continuation.config;
      [@sexp.default Continuation.default_config]
      (** Detector parameters; only consulted when
          [enable_continuation_buys = true]. See [.mli] for tuning context. *)
  enable_pi_filter : bool; [@sexp.default false]
      (** Master switch for the screener point-in-time (PI) universe-membership
          filter. Default [false] preserves all existing baselines: the
          [Screener.screen_with_cooldown] [?membership_at] callback is left
          unsupplied and every loaded symbol participates in the cascade.

          When [true], the strategy builds a callback from per-symbol bar reads
          — a symbol is treated as a member on [as_of] iff its most recent
          observed bar's [Daily_price.active_through] is either [None] (still
          trading / unknown delisting status) or [Some d] with [as_of <= d].
          Symbols delisted before [as_of] are excluded from stage
          classification, sector resolution, and scoring before the cascade's
          downstream phases run.

          Authority: [dev/notes/historical-universe-membership-2026-04-30.md]
          §P5; [dev/notes/historical-universe-status-2026-05-13.md] §1 phase 3
          action item #2.

          The opt-in default is intentional: enabling the filter changes which
          symbols the cascade considers and shifts every existing fixture's
          pinned numbers as the underlying [active_through] column propagates
          through the snapshot pipeline. Re-pinning goldens is a separate
          post-merge step. *)
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
    enable_continuation_buys = false;
    continuation_config = Continuation.default_config;
    enable_pi_filter = false;
  }

let name = "Weinstein"
