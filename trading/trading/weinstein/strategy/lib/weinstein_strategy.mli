(** Weinstein stage-analysis strategy.

    Implements Stan Weinstein's Stage 2 entry / Stage 3-4 exit methodology as a
    [STRATEGY] module that the existing simulator can run.

    {1 Cadence}

    This strategy runs on daily cadence. Pair it with
    [Simulator.create_deps ~strategy_cadence:Daily].

    Stop adjustments happen every day — trailing stops follow the MA, which
    moves daily. Macro analysis and screening for new entries happen only on
    Fridays (weekly review), detected from the date of the index bar.

    {1 State}

    The STRATEGY interface is stateless (positions are passed in every call).
    Weinstein-specific state (stop states, prior stage classifications, last
    macro result) lives in a closure created by [make]. In simulation the state
    evolves across daily calls. In live mode it should be saved/loaded via
    [Weinstein_trading_state].

    {1 on_market_close behaviour}

    On each daily call the strategy: 1. Updates trailing stops for all held
    positions; emits [UpdateRiskParams] for adjusted stops, [TriggerExit] for
    stops hit. 2. On Fridays only: runs macro analysis using the index bars
    provided via [get_price]; runs stock screener over all symbols; emits
    [CreateEntering] for top-ranked buy candidates that pass portfolio-risk
    limits (no new entries if macro is Bearish). *)

open Core

(** {1 Sub-modules} *)

module Ad_bars = Ad_bars
(** NYSE advance/decline breadth data loader. See {!Ad_bars}. *)

module Ad_series_cache = Ad_series_cache
(** Precomputed cumulative-A-D + momentum series for the per-tick macro path.
    See {!Ad_series_cache}. *)

module Bar_reader = Bar_reader
(** Panel-backed bar source. See {!Bar_reader}. *)

module Spy_only_weinstein_strategy = Spy_only_weinstein_strategy
(** Single-instrument long/flat Weinstein stage-timing reference strategy. See
    {!Spy_only_weinstein_strategy}. *)

module Sector_rotation_weinstein_strategy = Sector_rotation_weinstein_strategy
(** Multi-symbol long/flat Weinstein stage-timing reference strategy that holds
    the top-[k] strongest Stage-2 sector ETFs by RS vs SPY. See
    {!Sector_rotation_weinstein_strategy}. *)

module Breaker_spy_strategy = Breaker_spy_strategy
(** Long-only, default-in-market SPY floor sleeve that defers sell/re-buy to the
    pure {!Index_circuit_breaker} state machine (P1b floor-quality program). See
    {!Breaker_spy_strategy}. *)

module Stops_runner = Stops_runner
(** Trailing-stop state machine loop over held positions. See {!Stops_runner}.
*)

module Stops_split_runner = Stops_split_runner
(** Per-tick split-event detector and stop-state rescaler. Invoked at the top of
    [on_market_close] (before {!Stops_runner.update}) so absolute stop prices
    stay in lockstep with the broker-side share-count rescale on a
    corporate-action split. See {!Stops_split_runner}. *)

module Force_liquidation_runner = Force_liquidation_runner
(** Force-liquidation policy runner. Invoked at the bottom of [on_market_close]
    after {!Stops_runner.update} — defense in depth beyond stops. Closes G4 from
    [dev/notes/short-side-gaps-2026-04-29.md]. See {!Force_liquidation_runner}.
*)

module Stage3_force_exit_runner = Stage3_force_exit_runner
(** Stage-3 force-exit runner — capital recycling on the long side (issue #872).
    Invoked AFTER {!Stops_runner.update} and BEFORE
    {!Force_liquidation_runner.update} on Friday ticks when
    [config.enable_stage3_force_exit = true]. See {!Stage3_force_exit_runner}.
*)

module Stage3_force_exit = Stage3_force_exit
(** Pure Stage-3 force-exit detector (issue #872). Re-exposed from
    [analysis/weinstein/stage3_force_exit] so callers building a
    {!Weinstein_strategy.config} can reference {!Stage3_force_exit.config} and
    {!Stage3_force_exit.default_config} without a separate library import. *)

module Late_stage2_stop_runner = Late_stage2_stop_runner
(** Late-Stage-2 trailing-stop tightening runner (P1 stage-accuracy dial).
    Invoked on Friday ticks when
    [config.enable_late_stage2_stop_tighten = true]: raises the trailing stop of
    every held [Stage2 { late = true }] long. Emits [UpdateRiskParams] adjust
    transitions (never exits). Default-off preserves all baselines. See
    {!Late_stage2_stop_runner}. *)

module Harvest_rotate_runner = Harvest_rotate_runner
(** Harvest-rotate dial (default-off). Invoked on Friday ticks when
    [config.enable_harvest_rotate = true]: trims [config.harvest_fraction] of
    every held [Stage2 { late = true }] long via a [TriggerPartialExit] (the
    book's "sell half as the Stage-3 top forms"), freeing capital to recycle
    through the existing entry pipeline into a fresh Stage-2 leader. Default-off
    preserves all baselines. See {!Harvest_rotate_runner}. *)

module Macro_bearish_trim_runner = Macro_bearish_trim_runner
(** Macro-bearish held-exposure trim runner (default-off). Invoked AFTER the
    special-exit passes on Friday ticks when
    [config.enable_macro_bearish_exposure_trim = true] AND the macro trend is
    Bearish: caps held long exposure at
    [config.macro_bearish_max_long_exposure_pct] of portfolio value, trimming
    the excess weakest-RS-first. Default-off preserves all baselines. See
    {!Macro_bearish_trim_runner}. *)

module Laggard_rotation_runner = Laggard_rotation_runner
(** Laggard-rotation runner — capital recycling on the long side (issue #887).
    Invoked AFTER {!Stops_runner.update}, {!Force_liquidation_runner.update} and
    {!Stage3_force_exit_runner.update} on Friday ticks when
    [config.enable_laggard_rotation = true]. See {!Laggard_rotation_runner}. *)

module Laggard_rotation = Laggard_rotation
(** Pure laggard-rotation detector (issue #887). Re-exposed from
    [analysis/weinstein/laggard_rotation] so callers building a
    {!Weinstein_strategy.config} can reference {!Laggard_rotation.config} and
    {!Laggard_rotation.default_config} without a separate library import. *)

module Special_exits = Special_exits
(** Post-stops special-exit channels (force-liquidation, Stage-3 force-exit,
    laggard-rotation, liquidity-degradation). Re-exposed so tests can drive the
    full {!Special_exits.run} pipeline directly. See {!Special_exits}. *)

module Liquidity_config = Liquidity_config
(** Liquidity-realism overlay config ({!Liquidity_config.t}). Re-exposed so
    callers building a {!Weinstein_strategy.config} can reference
    {!Liquidity_config.default_config} without a separate library import. *)

module Scale_in_detector = Scale_in_detector
(** Scale-in add-trigger detection + knobs ({!Scale_in_detector.config}).
    Re-exposed so callers building a {!Weinstein_strategy.config} can reference
    {!Scale_in_detector.default_config} and the [trigger] variants without a
    separate library import. *)

module Scale_in_runner = Scale_in_runner
(** Scale-in add runner (default-off). Runs on Friday ticks before the
    fresh-entry walk when [config.enable_scale_in = true]; emits sibling
    [CreateEntering] adds into revealed strength and reduces the entry walk's
    cash budget by their cost. See {!Scale_in_runner}. *)

module Liquidity_metric = Liquidity_metric
(** Pure trailing dollar-ADV metric. See {!Liquidity_metric}. *)

module Liquidity_exit_runner = Liquidity_exit_runner
(** Held-position liquidity-degradation exit runner. Invoked among the special
    exits (alongside {!Stage3_force_exit_runner} / {!Laggard_rotation_runner})
    on Friday ticks when [config.liquidity_config.min_hold_dollar_adv > 0.0].
    See {!Liquidity_exit_runner}. *)

module Extension_stop_runner = Extension_stop_runner
(** Extension-stop exit runner — the strategy-side arm of the extension
    tail-insurance stop. Invoked among the special exits on Friday ticks when
    [config.extension_stop_config] is enabled; LONG-only, weekly-close,
    tighten-only. See {!Extension_stop_runner}. *)

module Macro_inputs = Macro_inputs
(** Sector map + global index assembly from accumulated bar history. Exposes the
    canonical {!Macro_inputs.spdr_sector_etfs} and
    {!Macro_inputs.default_global_indices} constants for use in {!config}. *)

module Panel_callbacks = Panel_callbacks
(** Panel-shaped callback bundle constructors for the strategy's callees. See
    {!Panel_callbacks}. *)

module Resistance_sketch_reader = Resistance_sketch_reader
(** Reads a resistance-v2 {!Resistance_supply.sketch} out of the warehouse
    snapshot columns for the overhead-supply score. See
    {!Resistance_sketch_reader}. *)

module Weekly_sidetable_reader = Weekly_sidetable_reader
(** Sketch-v5 read path: derive the resistance sketch from the per-symbol weekly
    side-table by score-time bucketing (+ the manifest-gated loader). See
    {!Weekly_sidetable_reader}. *)

module Weekly_ma_cache = Weekly_ma_cache
(** Per-symbol weekly MA cache (Stage 4 PR-D). Memoises Stage / Macro / Sector /
    Stops MA reads keyed by [(symbol, ma_type, period)]. *)

module Audit_recorder = Audit_recorder
(** Decision-trail recorder bundle invoked at entry / exit decision sites. The
    strategy emits raw events; backtest layers wrap a {!Backtest.Trade_audit.t}
    collector. See {!Audit_recorder}. *)

module Entry_audit_capture = Entry_audit_capture
(** Per-candidate entry construction + audit emission. Factored out of the main
    strategy file to keep it under the file-length cap. See
    {!Entry_audit_capture}. *)

module Screening_notional = Screening_notional
(** Per-Friday entry-walk notional / sector-exposure accumulator seeds. Exposed
    so tests can pin the accumulator-seeding primitives
    ([initial_short_notional] / [initial_long_notional]) directly. See
    {!Screening_notional}. *)

module Long_buying_power = Long_buying_power
(** Long-side buying-power model (M1a): the buying-power ceiling that
    generalizes [max_long_exposure_pct_entry] and the priced margin-interest
    primitives. Exposed so tests can pin the pure ceiling / interest math
    directly. See {!Long_buying_power}. *)

module Short_borrow_gate = Short_borrow_gate
(** Short-side borrow-availability entry gate (margin M3a): drops short
    candidates whose trailing dollar-ADV is below the borrow-supply floor.
    Exposed so tests can pin the pure {!Short_borrow_gate.filter} directly. *)

module Exit_audit_capture = Exit_audit_capture
(** Exit-side trade-audit capture. Bridges [TriggerExit] transitions to
    {!Audit_recorder.exit_event}. See {!Exit_audit_capture}. *)

module Weinstein_strategy_macro = Weinstein_strategy_macro
(** Macro computation and screen-dispatch helpers. Re-exposed for tests that
    drive {!Weinstein_strategy_macro.Internal_for_test} (the PI membership
    predicate and the flag-driven callback factory consumed by
    {!Screener.screen_with_cooldown}'s [?membership_at] argument). *)

module Weinstein_strategy_config = Weinstein_strategy_config
(** Strategy configuration record + {!Weinstein_strategy_config.default_config}
    factory. Re-exposed so tests can construct configs without depending on the
    included-into-this-module re-export below (which is read-only at the type
    level). *)

(** {1 Configuration} *)

type index_config = {
  primary : string;
      (** The US benchmark symbol (e.g. ["GSPCX"]). Dual-use: passed to
          {!Macro.analyze} as [~index_bars], and used by
          {!Stock_analysis.analyze} as [~benchmark_bars] when computing relative
          strength. *)
  global : (string * string) list;
      (** [(symbol, label)] pairs for non-US indices used by the macro
          global-consensus indicator. Default: empty. Use
          {!Macro_inputs.default_global_indices} for the canonical (GDAXI, N225,
          ISF.LSE) triple. [primary] is intentionally excluded from this list —
          it is already passed via [~index_bars]. *)
}
[@@deriving sexp]
(** Indices consumed by the macro analyser. The primary index is the US
    benchmark; globals are additional markets used only for the global consensus
    indicator. *)

type config = {
  universe : string list;  (** All ticker symbols to consider for screening. *)
  indices : index_config;
      (** Market indices consumed by the macro analyser. See {!index_config}. *)
  sector_etfs : (string * string) list;
      (** [(etf_symbol, sector_name)] pairs — one per sector tracked by the
          screener. When non-empty, the strategy accumulates bars for each ETF
          via [get_price] and builds a sector context map on screening days.
          Default: empty (sector gate degrades to Neutral). Use
          {!Macro_inputs.spdr_sector_etfs} for the canonical 11-sector list. *)
  stage_config : Stage.config;  (** Stage classifier parameters. *)
  macro_config : Macro.config;  (** Macro analyser parameters. *)
  screening_config : Screener.config;  (** Screener cascade parameters. *)
  portfolio_config : Portfolio_risk.config;
      (** Position sizing and risk limits. *)
  stops_config : Weinstein_stops.config;
      (** Trailing stop state machine parameters. *)
  initial_stop_buffer : float;
      (** Multiplier applied to [suggested_stop] when computing the initial stop
          level for a new entry. Default: 1.02 (2% buffer above the screener
          stop). *)
  lookback_bars : int;
      (** Number of weekly bars to pass to stage/macro analysers (default: 52).
          Must be >= 30 (one MA period). *)
  bar_history_max_lookback_days : int option;
      (** Hypothesis-testing field (perf workstream C1). Vestigial after the
          Stage 3 PR 3.2 deletion of [Bar_history] — the parallel cache no
          longer exists, so trimming has no behavioural effect. The field is
          kept on [config] so existing override sexps and CLI flags continue to
          parse; setting it is a no-op. Will be removed once backtest_runner CLI
          surface drops the corresponding flag. *)
  skip_ad_breadth : bool;
      (** Hypothesis-testing field (perf workstream C1). When [true], the runner
          does NOT call [Weinstein_strategy.Ad_bars.load]; macro indicators that
          depend on AD-breadth fall through to a degraded mode (treat AD-breadth
          as constant). Default [false] — current behaviour. Used for hypothesis
          tests like H3 (does AD-breadth load dominate RSS at 10K-symbol
          scale?). NOT safe to flip on in production. *)
  skip_sector_etf_load : bool;
      (** Hypothesis-testing field (perf workstream C1). When [true], the runner
          clears [sector_etfs] before strategy construction so sector-ETF bars
          are not loaded. Sector classification falls back to whatever
          [Sector_map] alone provides. Default [false] — current behaviour. Used
          for hypothesis tests like H4 (are sector ETF + index loads bounded?).
          NOT safe to flip on in production. *)
  universe_cap : int option;
      (** Hypothesis-testing field (perf workstream C1). When [Some n], the
          runner truncates the loaded universe to the first [n] symbols (after
          the existing [String.compare] sort) before strategy construction.
          [None] (default) uses the full universe. Used for hypothesis tests
          like H5 (how does RSS scale with universe size?). NOT safe to flip on
          in production. *)
  full_compute_tail_days : int option;
      (** Hypothesis-testing field (perf workstream H2). Vestigial after Stage 3
          PR 3.3 deleted the Tiered runner + [Bar_loader] subsystem; the
          original target ([Bar_loader.Full_compute.tail_days]) no longer
          exists, so setting this is a no-op. The field is kept on [config] so
          existing override sexps and CLI flags continue to parse. Will be
          removed in a follow-up cleanup. *)
  enable_short_side : bool; [@sexp.default true]
      (** When [false], the strategy drops [Screener.short_candidates] before
          generating entry transitions — only long-side breakouts are
          considered. Default [true] (preserves prior behaviour). Turning this
          off is a temporary mitigation while the short-side gaps documented in
          [dev/notes/short-side-gaps-2026-04-29.md] are open: stops on shorts do
          not fire correctly, [Metrics.extract_round_trips] does not pair
          Sell→Buy round-trips so shorts are invisible in [trades.csv], and the
          cash floor only triggers on Buy so unbounded short losses cannot
          force-liquidate. *)
  short_min_price : float; [@sexp.default 0.0]
      (** Minimum entry price for short candidates. Short candidates whose
          {!Screener.scored_candidate.suggested_entry} is strictly below this
          value are dropped before they join the entry candidate list. Default
          [0.0] = no gating (no-op, preserves prior behaviour). Encodes the
          researched sub-$17 economic-margin floor on shorts
          ([dev/notes/long-short-margin-mechanics-2026-06-12.md]) as a
          default-off, searchable {!Walk_forward.Variant_matrix} axis. Not wired
          into any default config or preset. *)
  short_borrow_min_dollar_adv : float; [@sexp.default 0.0]
      (** Borrow-availability floor for short candidates (margin M3a): shorts
          whose trailing dollar-ADV (no-lookahead, over {!liquidity_config}'s
          lookback) is below this value are dropped as "no borrow available"
          before the entry walk; longs are never affected. Default [0.0] = no-op
          (bit-identical). A default-off, searchable
          {!Walk_forward.Variant_matrix} axis; see
          {!Weinstein_strategy_config.short_borrow_min_dollar_adv} and
          {!Short_borrow_gate}. *)
  suppress_warmup_trading : bool; [@sexp.default true]
      (** When [true] (the default), the backtest runner suppresses all new
          position entries (long and short) before the measurement [start_date],
          so the warmup window builds indicators/data only and the measurement
          window opens with an all-cash portfolio. Default [true] =
          measurement-correctness invariant (user directive 2026-06-13:
          "measured window = window only"); warmup forms indicators only.
          [false] = legacy "running start" (the strategy trades during warmup),
          kept as an escape hatch / searchable axis. No-op in live/forward mode.
          Motivated by PR #1549's A2 warmup-leak root cause; implemented
          runner-side by {!Backtest.Warmup_trade_gate}. Remains a searchable
          {!Walk_forward.Variant_matrix} axis. *)
  stop_update_cadence : Stops_runner.stop_update_cadence;
      [@sexp.default Stops_runner.Daily]
      (** Cadence at which the trailing-stop state machine advances (G11).

          - [Daily] (default) — preserves all existing baselines: the trail can
            tighten on every daily bar.
          - [Weekly] — only advances the state machine on Friday ticks. Mirrors
            Weinstein Ch. 6 §Stop-Loss Rules: "the trail moves only when a
            weekly bar confirms a new pivot above the prior pivot." Trigger
            logic stays continuous — a stop can still fire on any daily bar.

          Lever introduced to test whether the daily-cadence default explains
          the very-short-hold cluster observed in
          [dev/notes/sp500-trade-quality-findings-2026-04-30.md] §G11. The
          comparison run is a follow-up; this field exists so the experiment
          becomes a config flip rather than a code change. *)
  stage3_force_exit_config : Stage3_force_exit.config;
      [@sexp.default Stage3_force_exit.default_config]
      (** Stage-3 force-exit detector parameters (issue #872). Default
          [{ hysteresis_weeks = 2 }] — fires on the second consecutive Friday
          Stage-3 classification of a held long position. *)
  enable_stage3_force_exit : bool; [@sexp.default false]
      (** Master switch for the Stage-3 force-exit runner (issue #872). Default
          [false] preserves all existing baselines: the runner is a no-op and
          the strategy emits no [StrategySignal "stage3_force_exit"]
          transitions. Flipping to [true] activates
          {!Stage3_force_exit_runner.update} on every Friday tick.

          The opt-in default is intentional: enabling the mechanism produces new
          exits and shifts every existing fixture's pinned numbers (trade count,
          return, MaxDD). Re-pinning every goldens-sp500-historical scenario is
          a separate post-merge step per the framing note's "Recommended
          sequencing" (§3) in
          [dev/notes/capital-recycling-framing-2026-05-06.md]. *)
  stage3_reentry_cooldown_weeks : int; [@sexp.default 0]
      (** Suppresses cascade re-admission of a symbol force-exited under Stage 3
          for [N] weeks beyond the existing stop-out cooldown surface (#718).
          Default [0] = no cooldown applied (preserves baselines). The strategy
          records Stage-3 force-exit events into [last_stop_out_dates] when this
          knob is [> 0], so the existing cascade gate applies regardless of
          which exit path fired. *)
  stage3_exit_margin_pct : float; [@sexp.default 0.0]
      (** Minimum margin (fraction) by which the current bar's close must sit
          below the 30-week MA before {!Stage3_force_exit_runner.update} emits a
          force-exit transition. Layered on top of
          {!Stage3_force_exit.config.hysteresis_weeks}: both conditions must be
          satisfied for an exit to fire.

          Default [0.0] preserves prior behaviour. Recommended panel values per
          [dev/notes/next-session-priorities-2026-05-29-PM.md] §P0:
          [stage3_exit_margin_pct] in [0.02..0.05] paired with
          [stage3_force_exit_config.hysteresis_weeks >= 2]. See
          {!Weinstein_strategy_config} for full semantics. *)
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
          Flipping to [true] activates {!Laggard_rotation_runner.update} on
          every Friday tick.

          The opt-in default is intentional: enabling the mechanism produces new
          exits and shifts every existing fixture's pinned numbers (trade count,
          return, MaxDD). Re-pinning every goldens-sp500-historical scenario is
          a separate post-merge step per the framing note's "Recommended
          sequencing" in [dev/notes/capital-recycling-framing-2026-05-06.md]. *)
  laggard_reentry_cooldown_weeks : int; [@sexp.default 0]
      (** Suppresses cascade re-admission of a symbol exited by the laggard-
          rotation runner for [N] weeks beyond the existing stop-out cooldown
          surface (#718). Default [0] = no cooldown applied (preserves
          baselines). The strategy records laggard-rotation exits into
          [last_stop_out_dates] when this knob is [> 0], so the existing cascade
          gate applies regardless of which exit path fired. *)
  enable_continuation_buys : bool; [@sexp.default false]
      (** Master switch for Weinstein Ch. 3 continuation-buy detection
          (Interpretation B of issue #889). Default [false] preserves all
          existing baselines: the {!Continuation} detector does not run and
          {!Stock_analysis.is_breakout_candidate} retains its
          initial-breakout-only behaviour. Flipping to [true] populates
          [Stock_analysis.continuation] via the detector and admits continuation
          candidates through the OR-arm of the cascade.

          Interpretation A (pyramid adds to existing holdings) is deferred
          behind a core-module decision and is NOT enabled by this flag. *)
  continuation_config : Continuation.config;
      [@sexp.default Continuation.default_config]
      (** Detector parameters for continuation-buy detection. Only consulted
          when [enable_continuation_buys = true]. Defaults to
          [Continuation.default_config], preserving bit-equality with prior
          behaviour when omitted from a scenario sexp. Exposed so parameter
          sweeps can tune [ma_slope_min], [pullback_band],
          [consolidation_weeks], and [consolidation_range_pct] via the standard
          config-override mechanism (issue #889 follow-up). *)
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
      (** Phase-2 margin-accounting parameters (issue #859 / Phase 2). When
          [enabled = true], the runner threads the value into the simulator's
          per-tick margin mechanics. Default
          {!Trading_portfolio.Margin_config.default_config} (disabled) preserves
          bit-equality with prior baselines. See [Weinstein_strategy_config] for
          full semantics. *)
  neutral_blocks_longs : bool; [@sexp.default false]
      (** Entry-gate axis (default-off): when [true], a macro-[Neutral] tape
          blocks new long entries (only [Bullish] admits longs). Default [false]
          preserves the historical macro gate where both [Bullish] and [Neutral]
          admit longs. Tightens the macro gate only; the Stage-2-only entry,
          stops, and short-side gate are unaffected. Threaded into
          [screening_config.neutral_blocks_longs] at screen time so it is a
          [Variant_matrix] flag axis. See [Weinstein_strategy_config] for full
          semantics. *)
  neutral_blocks_shorts : bool; [@sexp.default true]
      (** Short-side mirror of {!neutral_blocks_longs}: when [true] (the
          default), a macro-[Neutral] tape blocks new short entries (only
          [Bearish] admits shorts). Setting [false] restores the historical gate
          where both [Bearish] and [Neutral] admit shorts. Tightens the short
          side to Weinstein's confirmed-bear rule; the Stage-4 breakdown
          criteria and the macro gate are unaffected. Default flipped [false] ->
          [true] on 2026-07-09 (user mandate) as a faithfulness flip; ledger
          ACCEPT [2026-06-22-neutral-blocks-shorts-wfcv]. Threaded into
          [screening_config.neutral_blocks_shorts] at screen time so it is a
          [Variant_matrix] flag axis. See [Weinstein_strategy_config] for full
          semantics. *)
  enable_slow_grind_short_gate : bool; [@sexp.default false]
      (** Faithful-short decline-character gate (default-off): when [true],
          shorts are admitted only when the current primary-index decline is a
          [Decline_character.Slow_grind] (fast-V crashes and non-declines are
          excluded). Default [false] is a no-op. The slow-grind bool is
          classified at screen time from the current macro result + index bars
          and threaded into
          [Screener.screen_with_cooldown ~decline_is_slow_grind] (the screener
          lib stays macro-agnostic). [Variant_matrix] flag axis. See
          [Weinstein_strategy_config] for full semantics. *)
  fast_v_arm_on_rate_alone : bool; [@sexp.default false]
      (** Arming-speed dial for the fast-crash absolute stop (default-off): when
          [true], the primary-index [Decline_character.Fast_v] classification
          may arm on the rate of decline alone, without waiting for the weekly
          MA to roll over (the 2020 arming-latency fix — the binding constraint
          is when the stop arms, not its width). Default [false] is a no-op
          (bit-identical; the classifier is unchanged). Threaded into
          [Decline_character.fast_v_ignores_ma_filter] at both classify sites.
          The {b spine} is untouched — it changes no buy/sell rule, only when
          the tail-RISK-insurance absolute stop arms. [Variant_matrix] flag
          axis. See [Weinstein_strategy_config] for full semantics. *)
  fast_v_min_rate_pct : float; [@sexp.default 0.08]
      (** Fast-V arming rate threshold (whipsaw-suppression dial): the minimum
          trailing rate-of-decline drawdown at which the primary index is
          classified [Decline_character.Fast_v]. Default [0.08] equals
          [Decline_character.default_config.fast_v_min_rate_pct] — a no-op
          (bit-identical classification). Raising it (e.g. to 0.16) requires a
          steeper drawdown before [Fast_v] arms, suppressing the rate-alone
          re-arm whipsaw in choppy corrections. Threaded into
          [Decline_character.fast_v_min_rate_pct] at both classify sites. The
          {b spine} is untouched — it changes only when the tail-RISK-insurance
          absolute stop arms. [Variant_matrix] float axis. See
          [Weinstein_strategy_config] for full semantics. *)
  reject_declining_ma_long_entry : bool; [@sexp.default false]
      (** Long-entry faithfulness gate (default-off): drop long candidates whose
          stage-classification MA direction is [Declining] at entry (a
          misclassified Stage-2 / counter-trend bounce). [Variant_matrix] flag
          axis. See [Weinstein_strategy_config] for full semantics. *)
  enable_late_stage2_stop_tighten : bool; [@sexp.default false]
      (** Held-position risk dial (default-off): when [true], the
          {!Late_stage2_stop_runner} tightens the trailing stop of every held
          long whose current stage is [Stage2 { late = true }] on Friday ticks.
          Default [false] preserves all baselines (the runner is never invoked).
          The {b spine} is untouched — only an existing held long's trailing
          stop moves, and only ever upward. [Variant_matrix] flag axis. See
          [Weinstein_strategy_config] / {!Late_stage2_stop_runner} for full
          semantics. *)
  late_stage2_stop_buffer_pct : float; [@sexp.default 0.0]
      (** Buffer (fraction) below the current close at which the late-Stage-2
          tighten runner raises the trailing stop; the candidate stop is
          [close *. (1.0 -. late_stage2_stop_buffer_pct)]. Only consulted when
          [enable_late_stage2_stop_tighten = true]; default [0.0] is the no-op
          buffer. See [Weinstein_strategy_config]. *)
  enable_macro_bearish_exposure_trim : bool; [@sexp.default false]
      (** Held-exposure risk dial (default-off): when [true] and the macro tape
          is Bearish on a Friday tick, the {!Macro_bearish_trim_runner} caps
          total held long exposure (see [macro_bearish_max_long_exposure_pct])
          and trims the excess weakest-RS-first. Default [false] preserves all
          baselines (the runner is never invoked). The {b spine} is untouched —
          this is the macro gate (spine item #6) extended from "block buys" to
          "raise cash on a bear tape", a faithful exit-aggressiveness dial; it
          never force-buys. [Variant_matrix] flag axis. See
          [Weinstein_strategy_config] / {!Macro_bearish_trim_runner} for full
          semantics. *)
  macro_bearish_max_long_exposure_pct : float; [@sexp.default 0.70]
      (** Fraction of portfolio value at which held long exposure is capped when
          the macro-bearish trim fires. [0.0] = full flat; [1.0] (or higher) =
          no-op. Only consulted when
          [enable_macro_bearish_exposure_trim = true]; default [0.70] mirrors
          the normal long-exposure cap (a no-op cap). See
          [Weinstein_strategy_config]. *)
  stale_exit_after_days : int option; [@sexp.default None]
      (** [Some n] force-sells a stale/delisted held position at its last close
          after an [n]-day bar gap, as a realised trade — instead of carrying it
          open at a stale mark indefinitely (issue #1484). [None] (default) is a
          no-op (detector-only, byte-identical to pre-#1484). Threaded into the
          simulator's [Trading_simulation.Stale_hold.config]. Searchable as a
          [Variant_matrix] flag axis. See [Weinstein_strategy_config]. *)
  enable_harvest_rotate : bool; [@sexp.default false]
      (** Master switch for the harvest-rotate dial: trim [harvest_fraction] of
          every held [Stage2 { late = true }] long via a [TriggerPartialExit] on
          Friday ticks, recycling the freed capital through the existing entry
          pipeline. Default [false] is a no-op (byte-identical to baseline).
          Searchable as a [Variant_matrix] flag axis. See
          [Weinstein_strategy_config] / {!Harvest_rotate_runner}. *)
  harvest_fraction : float; [@sexp.default 0.5]
      (** Fraction of a held [Stage2 { late }] long trimmed by the
          harvest-rotate runner; [0.5] = sell half. Only consulted when
          [enable_harvest_rotate = true]. See [Weinstein_strategy_config]. *)
  short_sleeve_fraction : float; [@sexp.default 0.0]
      (** Fraction of portfolio value reserved as a dedicated short-only cash
          budget in the per-Friday entry walk; default [0.0] is a no-op
          (bit-identical single combined walk). Reserves capital for shorts so
          they are not crowded out by longs at the entry walk. See
          [Weinstein_strategy_config]. *)
  extension_stop_config : Weinstein_stops.Extension_stop.config;
      [@sexp.default Weinstein_stops.Extension_stop.default_config]
      (** Extension-stop tail-INSURANCE trail for a held long far above its
          WMA30; default {!Weinstein_stops.Extension_stop.default_config}
          ([trigger_ratio = 0.0] / [trail_pct = 0.0]) DISABLES it (bit-identical
          to baseline). Wired via [Extension_stop_runner] as a special-exit
          channel (weekly-close, tighten-only). See [Weinstein_strategy_config].
      *)
  liquidity_config : Liquidity_config.t;
      [@sexp.default Liquidity_config.default_config]
      (** Liquidity-realism overlay parameters (held-position degradation exit +
          entry liquidity gate). Default [Liquidity_config.default_config] is a
          no-op (both thresholds [0.0]) — bit-identical to baseline. See
          [Weinstein_strategy_config]. *)
  enable_scale_in : bool; [@sexp.default false]
      (** Master switch for the explore/exploit scale-in mechanism (½-unit
          initial entries + one pullback add into revealed strength). Default
          [false] is a no-op — bit-identical to baseline. See
          [Weinstein_strategy_config]. *)
  scale_in_config : Scale_in_detector.config;
      [@sexp.default Scale_in_detector.default_config]
      (** Scale-in knobs; only consulted when [enable_scale_in = true]. See
          [Weinstein_strategy_config] and {!Scale_in_detector}. *)
  cash_reserve_pct : float; [@sexp.default 0.0]
      (** Fraction of current portfolio value held back from NEW entry funding
          each Friday; default [0.0] is a no-op (bit-identical to baseline). The
          working replacement for the dead [Portfolio_risk.min_cash_pct]. Scoped
          to entries only — exits are never blocked. See
          [Weinstein_strategy_config]. *)
  max_long_exposure_pct_entry : float; [@sexp.default 0.0]
      (** Cap on aggregate NEW long-entry (entry-price-denominated) notional as
          a fraction of current portfolio value, applied at the Friday entry
          walk; default [0.0] => [Float.infinity] cap => exact no-op. The
          working replacement for the dead
          [Portfolio_risk.max_long_exposure_pct] — it bounds how far the long
          book may lever on short proceeds at entry time. Scoped to NEW long
          entries only — exits/covers/stops are never blocked. See
          [Weinstein_strategy_config.max_long_exposure_pct_entry]. *)
  initial_long_margin_req : float; [@sexp.default 1.0]
      (** Long-side initial-margin requirement — the leverage dial that
          generalizes [max_long_exposure_pct_entry] into a buying-power ceiling
          ([min exposure_term (equity / req)], via
          [Long_buying_power.long_notional_ceiling]). [1.0] (default) = cash
          account = no explicit equity ceiling => exact no-op (R1); [0.5] =
          Reg-T 2x buying power. See
          [Weinstein_strategy_config.initial_long_margin_req]. *)
  long_margin_rate_annual_pct : float; [@sexp.default 0.0]
      (** Annualized interest on a long-margin debit balance, priced per trading
          day as [debit * annual / 252]. Default [0.0] => no charge => exact
          no-op (R1). See
          [Weinstein_strategy_config.long_margin_rate_annual_pct]. *)
  maintenance_long_pct : float; [@sexp.default 0.0]
      (** Long-side maintenance-margin requirement (margin M2). When
          [equity /. marked_long_exposure < maintenance_long_pct] on a weekly
          (Friday) close, {!Trading_simulation.Long_maintenance} force-reduces
          held longs weakest-first until the ratio is restored. Default [0.0]
          (cash account, no requirement) => exact no-op (R1); an unlevered book
          never fires. See [Weinstein_strategy_config.maintenance_long_pct]. *)
  resistance_min_history_bars : int; [@sexp.default 0]
      (** Overhead-resistance history floor threaded into the per-screen
          [Stock_analysis.config.resistance.min_history_bars] (and, via the
          shared [Resistance.config] record, the short-side support mirror).
          Default [0] disables the check (bit-identical to baseline); [> 0]
          (typically [520]) grades starved windows as [Insufficient_history]
          instead of a false resistance label (PR #1941). R2-searchable int
          axis. See [Weinstein_strategy_config] and
          {!stock_analysis_config_for}. *)
  resistance_lookback_bars : int; [@sexp.default 0]
      (** Resistance-history feed: when [> 0] (typically [520]), the Phase-2
          screen fetches a second, deeper weekly view of this many bars for the
          resistance/support callbacks only — the real fix for the false-virgin
          defect (feeding history rather than suppressing output via the
          [resistance_min_history_bars] label floor, which Run C showed deletes
          the signal wholesale). Default [0] = resistance reads the standard
          [lookback_bars] view, bit-identical to baseline. R2-searchable int
          axis. See [Weinstein_strategy_config.resistance_lookback_bars]. *)
  overhead_supply : Resistance_supply.config option; [@sexp.default None]
      (** Continuous overhead-supply score (resistance-v2). When [Some cfg], the
          strategy copies [cfg] into the per-screen [Stock_analysis.config] and
          the panel adapter reads the warehouse sketch columns, populating
          [Stock_analysis.t.supply] for the screener's [w_overhead_supply]
          scoring weight. Default [None] = [supply] always [None], binary grade
          fallback, no sketch reads (bit-identical to baseline). Pairs with the
          screener weight; live CSV path stays v1. See
          [Weinstein_strategy_config.overhead_supply]. *)
  virgin_crossing_readmission : bool; [@sexp.default false]
      (** resistance-v2 lever (a): virgin-crossing re-admission. When [true], a
          stale Stage-2 survivor that has crossed into virgin territory (above
          its 520-week max high) on volume is re-admitted by
          [Stock_analysis.is_breakout_candidate] despite being past the
          [early_stage2_max_weeks] early-Stage-2 window (the book's "new high
          ground" breakout). Default [false] = bit-identical to baseline; needs
          a warehouse sketch (absent → no re-admission). Independent of
          [overhead_supply]. See
          [Weinstein_strategy_config.virgin_crossing_readmission]. *)
}
[@@deriving sexp]
(** Complete Weinstein strategy configuration. All parameters configurable for
    backtesting.

    The five hypothesis-testing fields ([bar_history_max_lookback_days],
    [skip_ad_breadth], [skip_sector_etf_load], [universe_cap],
    [full_compute_tail_days]) all default to behaviour-preserving values.
    Setting any of them changes runner / strategy behaviour and is intended for
    perf measurement A/Bs only — see the H-series in
    [dev/plans/backtest-perf-2026-04-24.md]. *)

val default_config : universe:string list -> index_symbol:string -> config
(** Build a default config with Weinstein book values. The resulting config has
    [indices.primary = index_symbol] and [indices.global = []]; callers can set
    [indices.global] and [sector_etfs] via record update to opt into the full
    macro pipeline.

    @param universe Ticker symbols to screen.
    @param index_symbol US benchmark index (becomes [indices.primary]). *)

(** {1 Factory} *)

val name : string
(** Strategy name, always ["Weinstein"]. *)

val held_symbols : Trading_strategy.Portfolio_view.t -> string list
(** Ticker symbols of positions the strategy is still holding (or still trying
    to enter/exit). Closed positions are excluded — the strategy has no stake in
    them and must be free to re-enter the symbol.

    Used internally to (a) filter screener candidates and (b) populate
    [held_tickers] passed to [Screener.screen]. Public because the result is a
    natural query on strategy state and the behaviour (exclude [Closed]) is
    worth pinning by direct unit test. *)

val prune_universe_by_active_through :
  universe:string list ->
  active_through_for:(string -> Date.t option) ->
  fold_start_date:Date.t ->
  string list
(** Win #4 pure helper: drop symbols from [universe] whose [active_through_for]
    returns [Some d] with [Core.Date.(d < fold_start_date)]. [None] symbols (no
    delisting marker — still trading or unknown) pass through unchanged.

    Point-in-time framing: filters on the fold's START date (a date in the past
    relative to the present), so symbols delisted later during the fold are
    KEPT. This is NOT survivor bias — filtering on the current date would be,
    but that cut is not performed here. Authority:
    [dev/plans/v7-sweep-speedup-2026-05-26.md] §Win #4. *)

val survivors_for_screening :
  ?active_through_for:(string -> Date.t option) ->
  ?fold_start_date:Date.t ->
  ?sector_map:(string, Screener.sector_context) Core.Hashtbl.t ->
  config:config ->
  bar_reader:Bar_reader.t ->
  prior_stages:Weinstein_types.stage Core.Hashtbl.M(String).t ->
  current_date:Date.t ->
  unit ->
  (string * Snapshot_runtime.Snapshot_bar_views.weekly_view * Stage.result) list
(** Stage 4-5 PR-A / PR-B: cheap-cascade survivors of the lazy screener. For
    every ticker in [config.universe], reads a panel weekly view and classifies
    the current stage via the cheap stage-only callback bundle (cache-aware via
    PR-D {!Weekly_ma_cache}). Returns survivors — symbols whose stage could in
    principle yield a screener candidate ([Stage2 _] for longs; [Stage4 _] for
    shorts) — paired with their weekly view (reused by Phase 2) and
    {!Stage.result}.

    When [?sector_map] is supplied, also applies the sector pre-filter (PR-B): a
    Stage 2 candidate in a [Weak]-rated sector and a Stage 4 candidate in a
    [Strong]-rated sector are dropped, mirroring {!Screener._long_candidate} /
    {!Screener._short_candidate}'s downstream rejection rules. Tickers not
    present in [sector_map] default to PASS (matches
    {!Screener._resolve_sector}'s [Neutral] fallback for unknown tickers). When
    [?sector_map] is omitted, returns stage-only survivors — the PR-A behaviour,
    retained for tests that exercise the stage filter in isolation.

    [prior_stages] is updated for every classified symbol, including
    non-survivors, so the next Friday's classification has accurate prior-stage
    context.

    Public for testability — lets unit tests assert that the universe filter
    correctly drops Stage1 / Stage3 symbols (PR-A) and weak-/strong-sector
    symbols (PR-B) without instrumenting the screener loop. The filter
    predicates are intentionally narrow (stage-only and sector-only); the
    screener's full eligibility rules (volume / RS / prior_stage / quality)
    still run inside Phase 2's [Stock_analysis] for the surviving symbols.

    @param active_through_for
      Win #4: optional per-symbol [active_through] lookup. When both this and
      [?fold_start_date] are [Some _], [config.universe] is pre-pruned before
      Phase 1: symbols whose [active_through_for s = Some d] with
      [Date.(d < fold_start_date)] are dropped. Symbols with
      [active_through_for s = None] (no delisting marker — still trading or
      unknown) pass through. Default [None] preserves baselines (no
      pre-pruning). Point-in-time, NOT survivor bias: the filter uses the fold's
      start date, a past date relative to the present, so symbols delisted later
      during the fold are kept and participate normally.
    @param fold_start_date
      Win #4: companion to [?active_through_for]. The fold's first day. When
      omitted, no pre-pruning happens (matches default behaviour). *)

val stock_analysis_config_for : config:config -> Stock_analysis.config
(** Build the per-screen-pass [Stock_analysis.config] the screener consumes for
    the given strategy [config]. Applies two strategy-config-driven overrides on
    top of {!Stock_analysis.default_config}:

    - [enable_continuation_buys] toggles the continuation detector (threading
      [continuation_config]);
    - [resistance_min_history_bars], when non-zero, sets
      [resistance.min_history_bars] — and because [Stock_analysis] reuses the
      same [Resistance.config] record for the short-side support mirror, the
      floor applies to both the resistance and support cascades automatically.

    When both overrides are at their no-op defaults
    ([enable_continuation_buys = false] and [resistance_min_history_bars = 0])
    the result is byte-identical to {!Stock_analysis.default_config}
    (experiment-flag-discipline R1).

    Public for testability — lets unit tests pin the R2-searchability threading
    (default-off bit-identity + the [520] override landing on
    [resistance.min_history_bars]) without instrumenting the screener loop. *)

val entries_from_candidates :
  ?sector_lookup:(string -> string option) ->
  config:config ->
  candidates:Screener.scored_candidate list ->
  stop_states:Weinstein_stops.stop_state String.Map.t ref ->
  bar_reader:Bar_reader.t ->
  portfolio:Trading_strategy.Portfolio_view.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  current_date:Date.t ->
  ?audit_recorder:Audit_recorder.t ->
  ?macro:Macro.result ->
  unit ->
  Trading_strategy.Position.transition list
(** Generate [CreateEntering] transitions for a list of screener candidates.

    For each candidate:
    - Applies the Weinstein position sizer
      ({!Weinstein.Portfolio_risk.compute_position_size}). Candidates whose
      per-trade risk rounds to zero shares are dropped.
    - Computes the initial stop via
      {!Weinstein_stops.compute_initial_stop_with_floor}, threading [cand.side]:
      longs get a stop below the prior correction low; shorts get a stop above
      the prior rally high. Falls back to [config.initial_stop_buffer] when no
      qualifying counter-move is in the lookback window.
    - Emits a [CreateEntering] with [side = cand.side].

    Side effect: seeds [stop_states] with the computed initial stop for each new
    entry.

    Cash tracking: each entry's [target_quantity * entry_price] is deducted from
    [portfolio.cash]; candidates whose cost exceeds the remaining cash are
    skipped. For short candidates this is conservative (shorts generate proceeds
    rather than consume cash) but safe.

    Public because it's a useful primitive for callers that want to run
    screening out-of-band (e.g. custom universe loops) and feed candidates into
    the strategy's entry pipeline.

    @param audit_recorder
      Optional decision-trail recorder. When passed, every entered candidate
      yields a {!Audit_recorder.entry_event} populated with the chosen
      candidate, the macro snapshot ([macro]), the alternatives considered, and
      the audit-relevant intermediates ([installed_stop], [stop_floor_kind],
      sizing). Defaults to {!Audit_recorder.noop}.
    @param macro
      Macro snapshot consumed by [audit_recorder]'s entry event. Required only
      when [audit_recorder] is passed; ignored otherwise. Tests that don't
      record audit events can omit it.
    @param sector_lookup
      P1 2026-05-15. Resolves a held symbol to its sector name; used to seed the
      per-sector exposure accumulator that drives
      [Portfolio_risk.config.max_sector_exposure_pct]. When omitted, the
      accumulator is empty — held positions don't contribute to any sector
      bucket. Default-off path
      ([config.portfolio_config.max_sector_exposure_pct = None]) is bit-equal to
      pre-P1 behaviour regardless of whether [sector_lookup] is passed. *)

val make :
  ?initial_stop_states:Weinstein_stops.stop_state String.Map.t ->
  ?ad_bars:Macro.ad_bar list ->
  ?ticker_sectors:(string, string) Hashtbl.t ->
  ?bar_reader:Bar_reader.t ->
  ?audit_recorder:Audit_recorder.t ->
  ?fold_start_date:Date.t ->
  config ->
  (module Trading_strategy.Strategy_interface.STRATEGY)
(** Create a Weinstein strategy module with fresh internal state.

    Calling [make] twice creates two independent instances with their own stop
    states. Re-use the same instance across weekly calls to accumulate stop
    history.

    @param initial_stop_states
      Seed the stop state map — useful for tests and for restoring live state
      from persistence. Default: empty map.
    @param ad_bars
      NYSE advance/decline daily bars, passed through to {!Macro.analyze} on
      every screening day. Load once via {!Ad_bars.load} before calling [make] —
      the list lives in the closure for the lifetime of the strategy instance.
      Default: empty list (macro breadth indicators degrade to zero weight).
    @param ticker_sectors
      Stock ticker → GICS sector name hashtable, typically loaded via
      {!Sector_map.load}. Used to expand the ETF-level sector analysis to
      individual stock tickers in the screener. Default: empty table (sector
      gate degrades to Neutral for all tickers).
    @param bar_reader
      Optional pre-built {!Bar_reader.t}. When omitted defaults to
      {!Bar_reader.empty} — every read returns the empty list, sufficient for
      tests that exercise control paths where no bar is ever consumed (empty
      universe, no held positions, etc.). Production callers always supply one —
      built via {!Bar_reader.of_snapshot_views} for snapshot-mode runs or
      {!Bar_reader.of_in_memory_bars} for tests with in-memory fixtures.

    Phase F.3.a-4 (2026-05-04) retired the legacy [?bar_panels] parameter + its
    underlying [Bar_reader.of_panels] constructor; all bar reads now route
    through the snapshot path.
    @param audit_recorder
      Optional callback bundle invoked at entry / exit decision sites
      ({!Audit_recorder.entry_event} / [exit_event]). When omitted defaults to
      {!Audit_recorder.noop} — no observation is emitted and the strategy runs
      unchanged. Backtest callers wire a recorder backed by a
      [Backtest.Trade_audit.t] collector.
    @param fold_start_date
      Win #4: the fold's first day. When [Some d] together with [bar_reader]
      exposing a snapshot-backed [active_through_for], the screener pre-prunes
      [config.universe] before Phase 1 (stage classification), dropping symbols
      whose last active day is strictly before [d]. Default [None] preserves
      baselines — no pre-pruning. Point-in-time, NOT survivor bias: see
      {!survivors_for_screening}'s [?active_through_for] / [?fold_start_date]
      doc and the Win #4 spec in [dev/plans/v7-sweep-speedup-2026-05-26.md]. *)

(** {1 Internal — testing only}

    Direct seams into the strategy's [_on_market_close] used by behavioural
    regression tests. These bypass {!make}'s closure so a test can drive a
    [Peak_tracker] in a known [Halted] state and assert that the next Friday
    tick resets the halt to [Active] when macro flips off Bearish (PR #695,
    review item B1). Not for production use. *)
module Internal_for_test : sig
  val on_market_close :
    fold_start_date:Date.t option ->
    config:config ->
    ad_bars:Macro.ad_bar list ->
    stop_states:Weinstein_stops.stop_state String.Map.t ref ->
    last_stop_out_dates:Date.t Hashtbl.M(String).t ->
    prior_macro:Weinstein_types.market_trend ref ->
    prior_macro_result:Macro.result option ref ->
    prior_decline_character:Decline_character.t ref ->
    peak_tracker:Portfolio_risk.Force_liquidation.Peak_tracker.t ->
    bar_reader:Bar_reader.t ->
    prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
    prior_stage_ma_values:float Hashtbl.M(String).t ->
    sector_prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
    ticker_sectors:(string, string) Hashtbl.t ->
    stage3_streaks:int Hashtbl.M(String).t ->
    laggard_streaks:int Hashtbl.M(String).t ->
    audit_recorder:Audit_recorder.t ->
    get_price:Trading_strategy.Strategy_interface.get_price_fn ->
    get_indicator:Trading_strategy.Strategy_interface.get_indicator_fn ->
    portfolio:Trading_strategy.Portfolio_view.t ->
    Trading_strategy.Strategy_interface.output Status.status_or
  (** Drives [_on_market_close] with all closure-scoped state passed in
      explicitly. Mutates [stop_states] / [last_stop_out_dates] / [prior_macro]
      / [prior_macro_result] / [peak_tracker] / [prior_stages] /
      [prior_stage_ma_values] / [sector_prior_stages] / [stage3_streaks] /
      [laggard_streaks] in place, mirroring the closure semantics in {!make}.

      [~fold_start_date] is a required parameter here (not optional) — pass
      [None] to preserve baselines; pass [Some d] to enable Win #4 universe
      pre-pruning at the per-Friday screener. The [make] entry point hides this
      behind [?fold_start_date] (default [None]); the internal hook surfaces it
      explicitly so tests pin the semantics directly. *)

  val record_force_exit :
    last_stop_out_dates:Date.t Hashtbl.M(String).t ->
    positions:Trading_strategy.Position.t Map.M(String).t ->
    current_date:Date.t ->
    cooldown_weeks:int ->
    label:string ->
    Trading_strategy.Position.transition ->
    unit
  (** Records a strategy-signal exit into [last_stop_out_dates] when
      [cooldown_weeks > 0] AND the transition is a [TriggerExit] whose
      [StrategySignal.label] equals [label]. Otherwise a no-op.

      Used to plumb stage-3 force-exit and laggard-rotation exits through the
      existing screener cooldown gate (issue #889 §F1). Exposed for tests; not
      part of the public strategy API. *)

  val maybe_reset_halt :
    peak_tracker:Portfolio_risk.Force_liquidation.Peak_tracker.t ->
    prior_macro:Weinstein_types.market_trend ->
    current_macro:Weinstein_types.market_trend ->
    unit
  (** Resets [peak_tracker]'s halt state to [Active] only on the TRANSITION from
      [Bearish] to [Bullish]/[Neutral] (i.e. [prior_macro = Bearish] and
      [current_macro <> Bearish]). All other [(prior, current)] pairs are no-ops
      — in particular [(Bullish, Bullish)] does NOT reset, which breaks the
      Portfolio_floor death loop in the 2026-05-12 long-short 16y backtest. The
      strategy invokes this on every Friday after refreshing macro. *)

  val positions_minus_exited :
    positions:Trading_strategy.Position.t String.Map.t ->
    stop_exit_transitions:Trading_strategy.Position.transition list ->
    Trading_strategy.Position.t String.Map.t
  (** Filters [positions] down to those whose [position_id] is NOT among the
      [TriggerExit] transitions in [stop_exit_transitions]. Used to ensure
      force-liquidation does not double-exit a position [Stops_runner] already
      closed on this tick. *)
end
