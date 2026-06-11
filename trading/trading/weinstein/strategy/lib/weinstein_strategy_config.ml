open Core

(* No-op default for [macro_bearish_max_long_exposure_pct]: equals the normal
   long-exposure cap, so the trim never bites until a spec sets a tighter value. *)
let macro_bearish_no_op_cap = 0.70

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
  stage3_exit_margin_pct : float; [@sexp.default 0.0]
      (** Minimum margin (fraction) by which the current bar's close must sit
          below the 30-week MA before the Stage-3 force-exit runner emits.
          Default [0.0] preserves the prior detector behaviour. See [.mli]. *)
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
  margin_config : Trading_portfolio.Margin_config.t;
      [@sexp.default Trading_portfolio.Margin_config.default_config]
      (** Phase-2 margin-accounting parameters (issue #859,
          [dev/plans/short-side-margin-2026-05-13.md] §2). See [.mli]. *)
  neutral_blocks_longs : bool; [@sexp.default false]
      (** When [true], a macro-[Neutral] tape blocks new long entries (only
          [Bullish] admits longs); default [false] preserves the historical gate
          where both [Bullish] and [Neutral] admit longs. Threaded into
          [screening_config.neutral_blocks_longs] at screen time. See [.mli]. *)
  enable_late_stage2_stop_tighten : bool; [@sexp.default false]
      (** Master switch for the late-Stage-2 stop-tighten runner; see [.mli]. *)
  late_stage2_stop_buffer_pct : float; [@sexp.default 0.0]
      (** Buffer below close where the runner raises the stop; see [.mli]. *)
  enable_macro_bearish_exposure_trim : bool; [@sexp.default false]
      (** Master switch for the macro-bearish held-exposure trim runner; default
          [false] is a no-op (bit-identical to baseline). See [.mli]. *)
  macro_bearish_max_long_exposure_pct : float;
      [@sexp.default macro_bearish_no_op_cap]
      (** Fraction of portfolio value the trim caps held long exposure at on a
          Bearish tape; default [0.70] is a no-op cap. See [.mli]. *)
  stale_exit_after_days : int option; [@sexp.default None]
      (** [Some n] force-sells a stale/delisted held position at its last close
          after an [n]-day bar gap; default [None] is a no-op (#1484). Threaded
          into the simulator's [Stale_hold.config]. See [.mli]. *)
  enable_harvest_rotate : bool; [@sexp.default false]
      (** Master switch for the harvest-rotate dial; default [false] is a no-op
          (bit-identical to baseline). See [.mli]. *)
  harvest_fraction : float; [@sexp.default 0.5]
      (** Fraction of a held [Stage2 { late }] long trimmed by the
          harvest-rotate runner; [0.5] = sell half. Only consulted when
          [enable_harvest_rotate = true]. See [.mli]. *)
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
    stage3_exit_margin_pct = 0.0;
    laggard_rotation_config = Laggard_rotation.default_config;
    enable_laggard_rotation = false;
    laggard_reentry_cooldown_weeks = 0;
    enable_continuation_buys = false;
    continuation_config = Continuation.default_config;
    enable_pi_filter = false;
    margin_config = Trading_portfolio.Margin_config.default_config;
    neutral_blocks_longs = false;
    enable_late_stage2_stop_tighten = false;
    late_stage2_stop_buffer_pct = 0.0;
    enable_macro_bearish_exposure_trim = false;
    macro_bearish_max_long_exposure_pct = macro_bearish_no_op_cap;
    stale_exit_after_days = None;
    enable_harvest_rotate = false;
    harvest_fraction = 0.5;
  }

let name = "Weinstein"
