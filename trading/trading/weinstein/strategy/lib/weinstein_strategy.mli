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

module Bar_reader = Bar_reader
(** Panel-backed bar source. See {!Bar_reader}. *)

module Spy_only_weinstein_strategy = Spy_only_weinstein_strategy
(** Single-instrument long/flat Weinstein stage-timing reference strategy. See
    {!Spy_only_weinstein_strategy}. *)

module Sector_rotation_weinstein_strategy = Sector_rotation_weinstein_strategy
(** Multi-symbol long/flat Weinstein stage-timing reference strategy that holds
    the top-[k] strongest Stage-2 sector ETFs by RS vs SPY. See
    {!Sector_rotation_weinstein_strategy}. *)

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

module Macro_inputs = Macro_inputs
(** Sector map + global index assembly from accumulated bar history. Exposes the
    canonical {!Macro_inputs.spdr_sector_etfs} and
    {!Macro_inputs.default_global_indices} constants for use in {!config}. *)

module Panel_callbacks = Panel_callbacks
(** Panel-shaped callback bundle constructors for the strategy's callees. See
    {!Panel_callbacks}. *)

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
