type index_config = {
  primary : string;  (** The US benchmark symbol (e.g. ["GSPCX"]). *)
  global : (string * string) list;
      (** [(symbol, label)] pairs for non-US indices used by the macro
          global-consensus indicator. Default: empty. *)
}
[@@deriving sexp]
(** Indices consumed by the macro analyser. *)

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
  stage3_force_exit_config : Stage3_force_exit.config;
      [@sexp.default Stage3_force_exit.default_config]
  enable_stage3_force_exit : bool; [@sexp.default false]
  stage3_reentry_cooldown_weeks : int; [@sexp.default 0]
  stage3_exit_margin_pct : float; [@sexp.default 0.0]
      (** Minimum margin (fraction) by which the current bar's close must sit
          below the 30-week MA before {!Stage3_force_exit_runner.update} emits a
          force-exit transition. Layered on top of
          {!Stage3_force_exit.config.hysteresis_weeks} (the consecutive-Stage-3
          count): both must be satisfied for an exit to fire.

          Concretely the runner suppresses the exit when
          [(ma_value -. close_price) /. ma_value < stage3_exit_margin_pct], i.e.
          the close is not far enough below the MA. Negative values (close above
          MA) are likewise suppressed when the threshold is positive. The
          hysteresis streak counter is unaffected — the detector still observes
          the Stage 3 read and advances its consecutive count; only the emission
          decision is gated by margin.

          Default [0.0] preserves prior behaviour: any close (above or below the
          MA) satisfies the inequality, so the runner emits whenever
          {!Stage3_force_exit.observe_position} returns [Force_exit].

          Recommended panel values per
          [dev/notes/next-session-priorities-2026-05-29-PM.md] §P0:
          [stage3_exit_margin_pct] in [0.02..0.05] paired with
          [stage3_force_exit_config.hysteresis_weeks >= 2]. The two knobs
          together filter the false Stage 2 -> 3 transitions identified by the
          trade-autopsy tool (PR #1360) as the dominant capital-recycling
          failure mode. *)
  laggard_rotation_config : Laggard_rotation.config;
      [@sexp.default Laggard_rotation.default_config]
  enable_laggard_rotation : bool; [@sexp.default false]
  laggard_reentry_cooldown_weeks : int; [@sexp.default 0]
  enable_continuation_buys : bool; [@sexp.default false]
      (** Master switch for Weinstein Ch. 3 continuation-buy detection
          (Interpretation B of issue #889). Default [false] preserves existing
          baselines. See [.ml] for full semantics. *)
  continuation_config : Continuation.config;
      [@sexp.default Continuation.default_config]
      (** Detector parameters for continuation-buy detection. Only consulted
          when [enable_continuation_buys = true]. Defaults to
          [Continuation.default_config], preserving bit-equality with prior
          behaviour when the sweep field is omitted from a scenario sexp.
          Exposed so parameter sweeps (issue #889 follow-up, see
          [dev/notes/next-session-priorities-2026-05-14.md] §P3) can tune
          [ma_slope_min], [pullback_band], [consolidation_weeks], and
          [consolidation_range_pct] via the standard config-override mechanism.
      *)
  enable_pi_filter : bool; [@sexp.default false]
      (** Master switch for the screener point-in-time universe-membership
          filter (universe plan phase P5). Default [false] preserves existing
          baselines. See [.ml] for full semantics. *)
  margin_config : Trading_portfolio.Margin_config.t;
      [@sexp.default Trading_portfolio.Margin_config.default_config]
      (** Phase-2 margin-accounting parameters (issue #859 / Phase 2). Opting in
          via [margin_config.enabled = true] threads the value through the
          backtest runner into the simulator's per-tick margin mechanics (daily
          borrow fee + maintenance-margin force-cover). Default
          {!Trading_portfolio.Margin_config.default_config} (disabled) preserves
          bit-equality with prior baselines. See [.ml] for full semantics. *)
  neutral_blocks_longs : bool; [@sexp.default false]
      (** Entry-gate axis (default-off): when [true], a macro-[Neutral] tape
          blocks new long entries exactly as a [Bearish] tape does — only a
          [Bullish] tape admits longs. Default [false] preserves the historical
          macro gate bit-equally (longs admitted under both [Bullish] and
          [Neutral], blocked only under [Bearish]).

          This *tightens* Weinstein's unconditional macro gate
          (weinstein-book-reference.md §Macro Analysis: do not buy in a
          non-confirmed tape) — it is a faithful dial, not a spine change: the
          Stage-2-only / breakout+volume entry criteria, the stops, and the
          short-side gate are all unaffected. The short-side gate ([Bullish]
          blocks; [Bearish]/[Neutral] admit) is independent of this flag.

          Wired by threading into [screening_config.neutral_blocks_longs] at
          screen time, so the flag is a single-component [Variant_matrix] flag
          axis ([((flag neutral_blocks_longs) (values (true false)))]).

          Motivation: lever #2 of the Cell E 2020-2026 stall diagnosis — in 2022
          the macro gate was [Bearish] ~51% of the year but longs still entered
          through the [Neutral]/[Bullish] bear-rally blips, contributing to the
          false-breakout stop-out churn. Default-off until an experiment-ledger
          ACCEPT (per [.claude/rules/experiment-flag-discipline.md]). *)
}
[@@deriving sexp]
(** Complete Weinstein strategy configuration. All parameters configurable for
    backtesting. *)

val default_config : universe:string list -> index_symbol:string -> config
(** Build a default config with Weinstein book values. *)

val name : string
(** Strategy name, always ["Weinstein"]. *)
