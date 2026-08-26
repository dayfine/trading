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
      (** Multiplier applied to the entry price to build the {b fallback} stop
          reference when the support scan finds no qualifying correction low:
          [entry *. initial_stop_buffer] for a long,
          [entry /. initial_stop_buffer] for a short
          ({!Weinstein_stops.compute_initial_stop_with_floor}). The reference is
          then inset by [min_correction_pct /. 2] to give the stop.

          {b Default [1.0] (since 2026-08-24, issue #2486 §2.1).} At [1.0] the
          reference is the entry price itself, so the fallback stop lands
          exactly [min_correction_pct /. 2] = 4% away — the floor of the book's
          §5.3 flat-stop band ("Use 4-6% initial stop if no nearby prior peak").
          Values [> 1.0] push the reference {i in the position's favour} before
          the inset, which {b narrows} the stop: the previous [1.02] default
          produced 2.08%, roughly half the band, on what
          [dev/agent-memory/project_fallback_stop_half_book_band.md] measures as
          the common path (88.7% of entries take the fallback). Width is pinned
          against the band by
          [trading/trading/weinstein/stops/test/test_fallback_stop_width.ml].

          The flip is a book-faithfulness correction, not a tuned value —
          user-directed, recorded in
          [dev/experiments/_ledger/2026-08-24-stops-basis-book-faithful.sexp].
          Structural (support-floor) stops are unaffected: this multiplier is
          read only on the fallback branch. *)
  lookback_bars : int;
      (** Depth, in weekly bars, of the standard per-symbol weekly view the
          screen reads ([Bar_reader.weekly_view_for ~n:lookback_bars]). Every
          weekly analysis — stage classification, RS, volume, breakout detection
          — sees exactly this many weeks, except resistance/support {i when}
          [resistance_lookback_bars] is armed. At that knob's [0] default the
          separate resistance view is [None] ([Weinstein_strategy_screening]),
          so breakout/resistance-zone detection reads this depth too.

          {b Default [56] (since 2026-08-25, issue #2380).} It was [52], which
          silently disabled {!Rs} trend classification entirely. Derivation of
          the [56] floor, from {!Rs.default_config} ([rs_ma_period = 52],
          [trend_lookback = 4]):

          - [Sma.calculate_sma] over [n] aligned weeks emits
            [n - rs_ma_period + 1] values, so {!Rs} builds an RS history of that
            length ([rs.ml] [_history_of_aligned]).
          - [Rs._classify_trend] compares the newest history entry against the
            one [trend_lookback] entries back, so it needs
            [trend_lookback + 1 = 5] history entries; below [2] it
            short-circuits to [Positive_flat] and between [2] and [4] the
            comparison is clamped to a shorter span than [trend_lookback].
          - Hence [n >= rs_ma_period - 1 + trend_lookback + 1 = 56].

          At [52] the history was exactly [1] entry long, so {b every} candidate
          in {b every} run classified [Positive_flat] — 4,231 tickets across
          three independently-run arms, zero non-flat.

          {b Scope of that claim:} it covers everything reading {i this} view.
          The [all_eligible] / [optimal] feature-capture path is {b not}
          affected — it builds its own per-Friday weekly slice at
          [bar_lookback_weeks = 90] and calls [Stock_analysis.analyze] directly,
          never reading this field, so [rs_trend] was live there throughout.

          {b Four} consumers of {!Rs.result.trend} were affected, three
          unreachable and one stuck:

          - the [Bullish_crossover] scoring bonus
            ({!Screener_scoring.w_bullish_rs_crossover}) — unreachable;
          - the §4.5 [rs_zero_cross] ticket tag — unreachable;
          - the [Rs]-trend term of the sector rating — unreachable;
          - {b {!Screener_admission.rs_blocks_short}} — {b stuck at [true]}.
            This one is not a scoring input but a {b hard admission gate}:
            [Screener]'s short branch is an unconditional [-> None] on it, and
            it returns [true] for
            [Positive_rising | Positive_flat | Bullish_crossover]. With the
            trend pinned at [Positive_flat], it rejected {b every} short
            candidate carrying an RS series, so the short side was structurally
            dead rather than merely conservative
            ([dev/notes/short-side-real-data-verification-2026-04-27.md]: 0
            shorts in 133 trades over 2019-2023, including zero in the 2022
            bear). At [56] the negative states become reachable and the gate
            starts discriminating — which is what Ch. 11's "never short a stock
            with strong relative strength" actually asks for; a gate that blocks
            {i all} shorts is not that rule. Pinned by
            [test_rs_blocks_short_flips_with_depth].

          The first three are why this is framed as a correctness fix rather
          than a performance lever. The fourth is {b not} return-neutral by
          construction — re-enabling the short side has a return impact, and the
          long-short goldens are expected to move. See issue #2380.

          {b Warmup interaction.} [Backtest.Runner._weekly_strategy_warmup_days]
          is [364] (~52 weeks), so at the very start of a measurement window
          only ~52 aligned weeks exist and the trend stays [Positive_flat] for
          the first few weeks regardless of this value; it becomes live once the
          window has advanced past 56 weekly bars. Raising the warmup to match
          is a separate basis change (it re-pins every golden) and is not done
          here. *)
  bar_history_max_lookback_days : int option;
  skip_ad_breadth : bool;
  skip_sector_etf_load : bool;
  universe_cap : int option;
  full_compute_tail_days : int option;
  enable_short_side : bool; [@sexp.default true]
  short_min_price : float; [@sexp.default 0.0]
      (** Minimum entry price for short candidates. Short candidates whose
          {!Screener.scored_candidate.suggested_entry} is strictly below this
          value are dropped before they join the entry candidate list.

          Default [0.0] = no gating: the gate short-circuits to the identity
          when [short_min_price <= 0.0], so every existing golden replays
          unchanged (R1). Encodes the sub-$17 economic-margin floor on shorts as
          a default-off, searchable [Variant_matrix] axis; not wired into any
          default config or preset. See
          [dev/notes/long-short-margin-mechanics-2026-06-12.md]. *)
  short_borrow_min_dollar_adv : float; [@sexp.default 0.0]
      (** Borrow-availability floor for short candidates (margin M3a): the
          minimum trailing dollar-ADV a name must trade for its shares to be
          considered locatable-to-borrow. Short candidates whose dollar-ADV
          (computed from bars available at the screen date, no lookahead, over
          {!liquidity_config}'s [adv_lookback_days]) is strictly below this
          value are dropped before the entry walk; long candidates are never
          affected (borrow is a short-only concern).

          Default [0.0] = no gating: {!Short_borrow_gate.filter} short-circuits
          to the identity, so every existing golden replays unchanged (R1).
          Dollar-ADV is the borrow-supply proxy (we have no locate feed); the
          bar-cadence caveat (intraweek borrow recall / gap squeeze invisible)
          is documented in {!Short_borrow_gate}. See
          [dev/notes/long-short-margin-mechanics-2026-06-12.md] §4 item 6. *)
  suppress_warmup_trading : bool; [@sexp.default true]
      (** When [true] (the default), the backtest runner suppresses all new
          position entries (long and short) before the measurement [start_date],
          so the warmup window builds indicators/data only and the measurement
          window opens with an all-cash portfolio. In live/forward mode it is a
          no-op (no entries are dated before "now").

          [false] = legacy "running start": the simulator runs from
          [start_date - warmup_days] and the strategy trades during warmup, so
          the backtest inherits a warmup-built portfolio at measurement start.
          Kept as an explicit escape hatch / searchable axis.

          Implemented runner-side by {!Backtest.Warmup_trade_gate}, which drops
          [CreateEntering] transitions dated before [start_date]; exits/stops/
          fills are never suppressed. Default [true] is a measurement-semantics
          correction (user directive 2026-06-13, "measured window = window
          only"), not an alpha mechanism, so the R1/R3 ledger gate does not
          apply. See [Backtest.Fold_health]. *)
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

          The runner suppresses the exit when
          [(ma_value -. close_price) /. ma_value < stage3_exit_margin_pct], so
          negative values (close above MA) are likewise suppressed when the
          threshold is positive. The hysteresis streak counter is unaffected —
          only the emission decision is gated by margin.

          Default [0.0] preserves prior behaviour: any close satisfies the
          inequality, so the runner emits whenever
          {!Stage3_force_exit.observe_position} returns [Force_exit].
          Recommended panel values: [0.02..0.05] paired with
          [hysteresis_weeks >= 2]. *)
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
          behaviour when the field is omitted from a scenario sexp. Exposed so
          parameter sweeps can tune [ma_slope_min], [pullback_band],
          [consolidation_weeks], and [consolidation_range_pct]. *)
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
          macro gate bit-equally (longs admitted under [Bullish] and [Neutral],
          blocked only under [Bearish]).

          This {e tightens} Weinstein's unconditional macro gate
          (weinstein-book-reference.md §Macro Analysis) — a faithful dial, not a
          spine change. The short-side gate is independent of this flag. Wired
          by threading into [screening_config.neutral_blocks_longs] at screen
          time, so it is a single-component [Variant_matrix] flag axis.
          Default-off until an experiment-ledger ACCEPT. *)
  neutral_blocks_shorts : bool; [@sexp.default true]
      (** Short-side mirror of {!neutral_blocks_longs}. When [true] (the
          default), a macro-[Neutral] tape blocks new short entries exactly as a
          [Bullish] tape does — only a [Bearish] tape admits shorts. Setting
          [false] restores the historical gate (shorts admitted under [Bearish]
          and [Neutral], blocked only under [Bullish]).

          This tightens the short side to the book's confirmed-bear rule
          (weinstein-book-reference.md §Short-Selling Rules) — a faithful dial,
          not a spine change. Default flipped [false] -> [true] on 2026-07-09
          (user mandate) as a {b faithfulness} flip, not an alpha claim; ledger
          ACCEPT [2026-06-22-neutral-blocks-shorts-wfcv]. Wired by threading
          into [screening_config.neutral_blocks_shorts] at screen time, so it is
          a single-component [Variant_matrix] flag axis. *)
  enable_slow_grind_short_gate : bool; [@sexp.default false]
      (** Faithful-short decline-character gate (default-off). When [true],
          shorts are admitted only when the current primary-index decline is a
          slow grind ([Decline_character.Slow_grind]) — fast-V crashes and
          non-declines are excluded. Default [false] is a no-op (bit-identical;
          the decline classification is not even consumed).

          Weinstein shorts a sustained distribution bear, not a fast V-crash
          that snaps back (weinstein-book-reference.md §Short-Selling Rules).
          The slow-grind bool is classified at screen time from the current
          macro result + index bars via [Decline_character_wiring] and threaded
          into [Screener.screen_with_cooldown ~decline_is_slow_grind]. The
          classification uses the {e current} cycle's macro + bars —
          lookahead-free for an entry gate. Single-component [Variant_matrix]
          flag axis; default-off until an experiment-ledger ACCEPT. *)
  fast_v_arm_on_rate_alone : bool; [@sexp.default false]
      (** Arming-speed dial for the fast-crash absolute stop
          ([stops_config.catastrophic_stop_pct]); default [false] is a no-op
          (the decline classifier behaves exactly as before). When [true], the
          primary-index [Decline_character.Fast_v] classification may arm on the
          {b rate of decline alone}, without waiting for the weekly MA to roll
          over and price to fall below it — in a fast V-crash the binding
          constraint is arming {b latency}, not stop width. The falling-MA
          precondition is dropped for the fast-V path only (slow-grind
          untouched); threaded into [Decline_character.fast_v_ignores_ma_filter]
          at both classify sites.

          {b Faithfulness}: changes no buy/sell rule — only {b when} the
          absolute tail-risk-insurance stop arms — so it is the sanctioned
          tail-insurance exception ([.claude/rules/weinstein-faithful-core.md]);
          the spine is intact. Single-component [Variant_matrix] flag axis;
          default-off until an experiment-ledger ACCEPT. *)
  fast_v_min_rate_pct : float; [@sexp.default 0.08]
      (** Fast-V arming rate threshold: the minimum trailing rate-of-decline
          drawdown (positive fraction over [rate_lookback_weeks]) at which the
          primary index is classified [Decline_character.Fast_v]. Threaded into
          [Decline_character.fast_v_min_rate_pct] at both classify sites via
          {!Decline_character_wiring.classifier_config}. Default [0.08] equals
          [Decline_character.default_config.fast_v_min_rate_pct], so it is a
          no-op (bit-identical classification).

          Whipsaw-suppression dial: raising the threshold requires a steeper
          drawdown before [Fast_v] is declared, at the cost of arming later in a
          genuine crash. A higher value never widens the [Fast_v] band, so the
          spine is untouched. Single-component [Variant_matrix] float axis;
          default no-op until a ledger ACCEPT. *)
  reject_declining_ma_long_entry : bool; [@sexp.default false]
      (** Long-entry faithfulness gate (default-off): when [true], drop any long
          candidate whose stage-classification MA direction is
          [Weinstein_types.Declining] at entry. Weinstein Stage 2 is defined as
          price above a {b rising} 30-week MA; the classifier nonetheless tags a
          minority of breakouts [Stage2] while the MA is still declining — these
          are counter-trend bounces in a Stage-4 downtrend. Default [false]
          preserves all baselines bit-for-bit. Shorts are unaffected — a
          declining MA is correct for a Stage-4 short.

          Spine intact: it {e tightens} the Stage-2-only buy rule toward the
          book's rising-MA definition. Single-component [Variant_matrix] flag
          axis; default-off until an experiment-ledger ACCEPT. *)
  enable_late_stage2_stop_tighten : bool; [@sexp.default false]
      (** Held-position risk dial (default-off): when [true], the
          {!Late_stage2_stop_runner} tightens the trailing stop of every held
          long whose current stage is [Stage2 { late = true }] (MA-slope
          deceleration — the earliest top-warning the classifier produces, today
          discarded for held positions). Default [false] preserves all existing
          baselines: the runner is never invoked, so behaviour is bit-identical
          regardless of [late_stage2_stop_buffer_pct].

          This is the {b exit-aggressiveness} dial (the trader preset), a
          faithful adaptation of [docs/design/weinstein-book-reference.md]
          §Stage 3 detail (Ch. 2). Spine untouched — only the trailing stop of
          an existing held position moves, and it is only ever raised.
          Single-component [Variant_matrix] flag axis; default-off until a
          confirmation-grid ACCEPT. *)
  late_stage2_stop_buffer_pct : float; [@sexp.default 0.0]
      (** Buffer (fraction) below the current close at which
          {!Late_stage2_stop_runner.update} raises the trailing stop on a held
          [Stage2 { late }] long: the tightened candidate is
          [close *. (1.0 -. late_stage2_stop_buffer_pct)]. Only consulted when
          [enable_late_stage2_stop_tighten = true]. Default [0.0] is the no-op
          buffer (and, because the runner is gated entirely by the flag, the
          disabled path is byte-identical to baseline regardless of this value).
          See {!Late_stage2_stop_runner}. *)
  enable_macro_bearish_exposure_trim : bool; [@sexp.default false]
      (** Master switch for the macro-bearish held-exposure trim runner
          ({!Macro_bearish_trim_runner}). When [true] and the macro tape is
          Bearish on a screening (Friday) day, held long exposure is capped (see
          [macro_bearish_max_long_exposure_pct]) and the excess is trimmed
          weakest-RS-first. Default [false] preserves all existing baselines —
          the trim pass short-circuits to [[]] before any work. Searchable as a
          [Variant_matrix] flag axis. Plan:
          [dev/plans/macro-bearish-exposure-trim-2026-06-06.md]. *)
  macro_bearish_max_long_exposure_pct : float; [@sexp.default 0.70]
      (** Fraction of portfolio value at which total held long exposure is
          capped when the macro-bearish trim fires; the excess is exited
          weakest-RS-first. [0.0] = full flat (all cash in a bear tape); [1.0]
          (or higher) = no-op. Only consulted when
          [enable_macro_bearish_exposure_trim = true]. Default [0.70] mirrors
          the normal long-exposure cap, so even with the flag flipped on the
          value defaults to a no-op cap — only a tighter value changes
          behaviour. See {!Macro_bearish_trim_runner}. *)
  stale_exit_after_days : int option;
      [@sexp.default Some default_stale_exit_days]
      (** When [Some n], a held position whose underlying symbol has stopped
          emitting bars for [n] calendar days is force-sold at its last
          available close as a realised trade (instead of being carried open at
          a stale mark indefinitely and counted in terminal NAV — issue #1484).
          The runner threads this into
          [Trading_simulation.Stale_hold.config.stale_exit_after_days].

          {b Default flipped [None] -> [Some 5] on 2026-07-10 (user mandate)} as
          a REALISM / faithfulness basis change, {b not} an alpha promotion: the
          simulator must not hold ghosts. Set [None] to restore the pre-flip
          no-op (detector still records stale holds; no force-exit), kept as a
          searchable [Variant_matrix] flag axis. Ledger:
          [2026-07-10-realism-defaults-flip]. *)
  short_sleeve_fraction : float; [@sexp.default 0.0]
      (** Fraction of portfolio value reserved as a dedicated short-only cash
          budget in the per-Friday entry walk
          ({!Weinstein_strategy.entries_from_candidates}). Addresses shorts
          being crowded out: the screener appends shorts after longs
          ([buy_candidates @ short_candidates]) against a single shared
          [remaining_cash] ref, so longs consume the budget first and the walk
          rarely reaches the shorts (memory [project_short_funnel_crowded_out]).

          {b Semantics.}
          - [<= 0.0] (default): {b bit-identical to baseline} — one combined
            entry walk against a single [remaining_cash] seeded at
            [portfolio.cash].
          - [> 0.0]: a short-only budget
            [short_sleeve_fraction *. portfolio_value] is reserved; long
            candidates walk against [max 0 (portfolio.cash -. short_budget)] and
            shorts against the reserved budget — two independent
            [remaining_cash] refs. The {!Portfolio_risk} short-notional cap and
            the shared per-sector accumulator still apply across both walks;
            kept transitions are re-emitted in the order the candidates
            {e entered} the walk, so audit ordering matches the single-walk
            path. That is screener order under the defaults, and post-demotion
            order once [stop_width_mode = Demote_over_max] has already permuted
            the list — the sleeve restores whichever order it was handed, it
            does not recover the screener's.

          {b Faithfulness} (W1/W2): a portfolio-allocation dial — Weinstein runs
          long and short simultaneously in bear markets. Spine untouched; only
          the {e capital available} to already-screened shorts changes.
          Searchable as a [Variant_matrix] axis; default-off until a ledger
          ACCEPT. *)
  extension_stop_config : Weinstein_stops.Extension_stop.config;
      [@sexp.default Weinstein_stops.Extension_stop.default_config]
      (** Extension-stop parameters — a wide tail-INSURANCE trail for a held
          long that has run far above its 30-week WMA (a blow-off / parabolic
          advance). Wired through {!Extension_stop_runner} as a special-exit
          channel that emits a [TriggerExit] once the weekly close reached
          [trigger_ratio ×] the WMA30 and has since fallen [trail_pct] below the
          post-trigger running peak weekly close (weekly-close semantics, L3).

          {b Tail-insurance, not an alpha axis} — same class as
          [stops_config.catastrophic_stop_pct]. Extension events are rare
          (~0.6-1% of episodes over a quarter-century), so a walk-forward CV on
          this axis is structurally powerless; its acceptance basis is the
          left-tail / event-level audit, {b never} fold Sharpe.

          {b Default-off.} Default
          {!Weinstein_stops.Extension_stop.default_config}
          ([trigger_ratio = 0.0], [trail_pct = 0.0]) DISABLES the mechanism:
          {!Extension_stop_runner.update} returns [[]], so every existing golden
          replays bit-identically (R1). Set e.g.
          [((trigger_ratio 2.0) (trail_pct 0.25))] to arm it.

          {b Tighten-only (L2).} The runner only ever ADDS an exit trigger and
          never lowers or replaces the structural trailing stop; a position
          already exiting this tick via another channel is skipped.

          {b Faithfulness (W2).} A faithful trader exit-aggressiveness dial
          ([docs/design/weinstein-book-reference.md] §5.3). Screen evidence pins
          the width — tight [0.10-0.20] trails are on-ramp killers
          ([dev/backtest/extension-screen-2026-07-11/FINDINGS.md]). Searchable
          as a nested [Variant_matrix] axis, e.g.
          [((key (extension_stop_config trigger_ratio)) (values (2.0 2.25)))];
          default-off until an experiment-ledger ACCEPT. *)
  liquidity_config : Liquidity_config.t;
      [@sexp.default Liquidity_config.default_config]
      (** Liquidity-realism overlay parameters — the held-position liquidity
          degradation exit ({!Liquidity_exit_runner}) and the entry liquidity
          gate ({!Liquidity_gate}). Detects a name whose dollar-ADV is
          collapsing, from data at decision time, and refuses / exits it before
          it becomes untradeable.

          {b Semantics.} Default [Liquidity_config.default_config]
          ([min_entry_dollar_adv = 1_000_000.0] since the 2026-07-10 realism
          flip, [min_hold_dollar_adv = 0.0]): the entry gate drops sub-$1M-ADV
          candidates so the simulator never fills entries reality could not
          fill; the held-position degradation exit still never fires. Set
          [min_entry_dollar_adv = 0.0] to restore the pre-flip no-op
          (bit-identical replay). See {!Liquidity_config} for the flip rationale
          + estimand caveat (ledger [2026-07-10-realism-defaults-flip]).

          {b Faithfulness} (W1/W2): a risk/realism dial; spine untouched, only
          tradeability-eligibility is narrowed. Each threshold is searchable as
          a [Variant_matrix] axis, e.g.
          [((key (liquidity_config min_hold_dollar_adv)) (values (0.0 1e6)))].
      *)
  max_long_exposure_pct_entry : float; [@sexp.default 0.0]
      (** Cap on aggregate NEW long-entry notional as a fraction of
          {e current portfolio value}, applied at the Friday entry walk
          ({!Weinstein_strategy.entries_from_candidates}).
          Entry-price-denominated committed-at-entry notional across held
          [Holding] longs plus the candidates funded this walk may not exceed
          [max_long_exposure_pct_entry * portfolio_value].

          {b ⚠ Use this, not [Portfolio_risk.max_long_exposure_pct]}, which has
          had no production consumer since [Portfolio_risk.check_limits] was
          deleted 2026-07-09 (memory [project_envelope_knobs_dead]) — a scenario
          override of that field does nothing. This one is consumed at the seam
          that actually gates entry funding, mirroring
          {!check_short_notional_cap}'s machinery.

          {b Basis — entry-price-denominated notional, NOT marked value.} The
          cap counts [shares * entry_price] committed at entry, matching the
          short cap. Marked exposure exceeding 100% of NAV purely from
          {e unrealized appreciation} of held winners is legitimate and must NOT
          trigger the cap. This is also THE margin convention for long-short
          runs: short proceeds credit cash (unchanged) and can fund longs, but
          only up to this cap.

          {b Scope — NEW entries only.} Exits, covers, stop orders and
          force-liquidations do not flow through the entry walk, so the cap can
          never block an exit (the #1553 lesson).

          {b Semantics.}
          - [<= 0.0] (default [0.0]): {b EXACT no-op} — the long-notional cap is
            [Float.infinity], so every existing long-only golden replays
            bit-identically (R1).
          - [> 0.0]: a long candidate whose entry notional would push the
            running long total past [pct * portfolio_value] is rejected as a
            [Long_exposure_cap] skip; short candidates are unaffected.

          {b Faithfulness} (W1/W2): a portfolio-risk dial that {e tightens}
          deployment without touching any spine item. Searchable as a
          single-component [Variant_matrix] axis; default-off until a ledger
          ACCEPT. *)
  initial_long_margin_req : float; [@sexp.default 1.0]
      (** Long-side initial-margin requirement — the leverage dial that
          generalizes {!max_long_exposure_pct_entry} into a buying-power model
          (levered long-short realism, M1a). [1.0] = cash account / Reg-T 100%
          requirement; [0.5] = Reg-T 2× buying power. The entry-walk long
          ceiling becomes [min exposure_term margin_term] via
          {!Long_buying_power.long_notional_ceiling}, where
          [margin_term = portfolio_value /. initial_long_margin_req] for a
          fractional requirement.

          {b Semantics.}
          - [>= 1.0] (default [1.0], cash account): {b EXACT no-op} — the
            buying-power term is [Float.infinity], so the combined ceiling is
            governed solely by {!max_long_exposure_pct_entry} (also disabled at
            its default) and every existing golden replays bit-identically (R1).
            Note this default imposes {e no} equity ceiling: the
            [portfolio_value] ceiling of a strict cash account is the explicit
            [max_long_exposure_pct_entry = 1.0] opt-in, deliberately, so the
            legitimate held-winner-appreciation and short-proceeds cases are not
            newly capped.
          - [0.0 < req < 1.0]: leverage opted in — the buying-power ceiling
            rises to [portfolio_value /. req].

          {b Scope (M1a).} This field sets the ceiling only. The entry-walk
          cash-gate relaxation that funds longs beyond available cash and the
          per-tick interest accrual are M1b; until then a fractional requirement
          is inert (the available-cash gate binds first). See
          {!Long_buying_power} and
          [dev/plans/levered-longshort-margin-realism-2026-07-14.md] §M1. R2:
          real config field; default-off until a ledger ACCEPT. *)
  long_margin_rate_annual_pct : float; [@sexp.default 0.0]
      (** Annualized interest rate charged on a long-margin debit balance
          (borrowed cash funding the long book beyond equity), the
          priced-leverage companion to
          [margin_config.short_borrow_fee_annual_pct] (M1a). Accrued per trading
          day as [debit_balance *. annual /. 252] via
          {!Long_buying_power.long_margin_interest_charge}, the same 252
          day-count the short borrow fee uses.

          [0.0] (default) = {b EXACT no-op}, no interest accrues on any balance
          (R1); [> 0.0] means a positive debit balance carries this financing
          cost.

          {b Scope (M1a).} This field defines the {e priced-debit convention};
          the per-tick accrual and the cash-gate relaxation that creates a
          nonzero debit balance are M1b, so until then the charge is always
          [0.0]. See {!Long_buying_power}. R2: real config field; default-off
          until a ledger ACCEPT. *)
  maintenance_long_pct : float; [@sexp.default 0.0]
      (** Long-side maintenance-margin requirement — the marked-basis loan-call
          threshold for a levered long book (M2). When
          [equity /. marked_long_exposure < maintenance_long_pct] on a weekly
          (Friday) close, {!Trading_simulation.Long_maintenance} force-reduces
          held longs — weakest first (ascending unrealized return since entry) —
          until the ratio is restored above
          [maintenance_long_pct *. (1 + buffer)], then stops. Here
          [equity = current_cash - long_margin_debit + marked_long_exposure] and
          [marked_long_exposure] sums [quantity *. close] over held longs priced
          today. Each forced sale's proceeds pay down [long_margin_debit] first.

          {b Semantics.}
          - [0.0] (default): {b EXACT no-op} — a cash account has no maintenance
            requirement, so the reduce never fires (R1). An unlevered book never
            fires even at a positive value, since
            [equity >= marked_long_exposure] keeps the ratio [>= 1.0].
          - [> 0.0] (e.g. [0.25]): a levered long book whose equity falls below
            [maintenance_long_pct] of its marked long exposure is deleveraged
            incrementally on the next weekly close.

          {b Scope — the long book.} The numerator is long-account equity; the
          short book's marked P&L is excluded (it has its own maintenance
          surface, [margin_config.maintenance_margin_pct]). The reduce closes
          whole weakest longs and is scoped to a forced sale — it can never
          block an exit (the #1553 lesson). {b Cadence caveat:} daily-close
          marks cannot see an intraweek gap-through-maintenance move; those
          paths are M3/M4, documented in {!Trading_simulation.Long_maintenance}.
          R2: real config field; default-off until a ledger ACCEPT plus the
          promotion-confirmation grid. *)
  resistance_min_history_bars : int; [@sexp.default 0]
      (** Overhead-resistance history floor threaded into
          [Stock_analysis.config.resistance.min_history_bars] (and, because
          [Stock_analysis] reuses the same [Resistance.config] record for the
          short-side support mirror, into the support side too). When a symbol
          has fewer than this many bars of history the resistance/support mapper
          classifies the breakout as [Weinstein_types.Insufficient_history]
          rather than risk a false [Virgin_territory] grade off a starved window
          (PR #1941).

          {b Semantics.}
          - [0] (default): {b bit-identical to baseline} — the check is disabled
            exactly as {!Resistance.default_config} leaves it, so the built
            [Stock_analysis.config] is byte-identical to
            {!Stock_analysis.default_config} (R1).
          - [> 0] (typically [520], the full virgin-lookback): a symbol with
            fewer bars produces the [Insufficient_history] grade at screen time.

          Threaded into the per-screen [Stock_analysis.config] by
          [_stock_analysis_config_for] (weinstein_strategy_screening.ml). A
          data-hygiene dial that {e tightens} the breakout-above-resistance
          criterion; spine untouched. R2: real config field, expressible as a
          [Variant_matrix] int axis and in scenario [config_overrides];
          default-off until an experiment-ledger ACCEPT. *)
  resistance_lookback_bars : int; [@sexp.default 0]
      (** Resistance-specific weekly-history depth: when [> 0], the Phase-2
          screen fetches a {e second, deeper} weekly view of this many bars for
          the resistance/support callbacks only — stage / RS / volume / breakout
          detection keep reading the standard [lookback_bars] view, so screening
          decisions other than the resistance grade are unaffected.

          {b Why.} Backtest panels carry only ~[lookback_bars] weekly bars, so
          the resistance mapper's 520-bar virgin lookback claims
          [Virgin_territory] off a starved window (the false-virgin defect,
          validator V7). {b Feeding real history is the fix}, not the
          [resistance_min_history_bars] label floor — arming that marks every
          name [Insufficient_history] and deletes the signal wholesale.

          {b Semantics.}
          - [0] (default): {b bit-identical to baseline} — resistance callbacks
            are built from the same weekly view as today (R1).
          - [> 0] (typically [520] = the virgin-lookback spec): resistance and
            support callbacks read a [resistance_lookback_bars]-deep weekly
            view. Values [<= lookback_bars] are harmless but pointless.

          Pure data-hygiene, no spine item touched. R2: real config field →
          [Variant_matrix] int axis and scenario [config_overrides]; default-off
          until a ledger ACCEPT. *)
  overhead_supply : Resistance_supply.config option; [@sexp.default None]
      (** Continuous overhead-supply score (resistance-v2 PR-D). When
          [Some cfg], the strategy copies [cfg] into the per-screen
          [Stock_analysis.config]; the snapshot-backed panel adapter reads the
          precomputed warehouse sketch columns and populates
          [Stock_analysis.t.supply], which the screener's [w_overhead_supply]
          scoring weight then consumes in place of the binary virgin/clean
          grade.

          {b Default flipped [None] -> [Some Resistance_supply.default_config]
             on 2026-07-23} by the BUNDLE promotion (user-approved, R3):
          [overhead_supply armed + w_overhead_supply=30 +
           virgin_crossing_readmission], with [Resistance_supply.default_config]
          floors also zeroed. Evidence and the full chain:
          [dev/notes/resistance-supply-promotion-memo-2026-07-19.md].

          {b Semantics.}
          - [Some cfg] (new default): the continuous score runs for survivors
            whose panel carries the sketch columns. The live CSV report path has
            no warehouse sketch, so [supply] is [None] there and the screener
            degrades gracefully to the bit-identical v1 binary grade (the live
            weekly-review generator computes a real sketch, so its displayed
            grade switches to the v2 score).
          - [None] (the deserialization fallback): {b bit-identical to baseline}
            — [supply] is always [None], no sketch reads occur. This is what a
            config sexp written {e before} the promotion parses to, and the
            explicit disarm escape hatch.

          {b Faithfulness} (W1/W2): ranking weight only, not an entry gate —
          spine untouched. R2: real config field → option axis over the
          [Resistance_supply.config] sub-fields. *)
  virgin_crossing_readmission : bool; [@sexp.default false]
      (** resistance-v2 lever (a): virgin-crossing re-admission. When [true],
          the strategy sets [Stock_analysis.config.virgin_crossing_readmission],
          so a Stage-2 survivor that has crossed into virgin territory (above
          its 520-week max high) on volume is re-admitted by
          [Stock_analysis.is_breakout_candidate] even when it is past the
          [early_stage2_max_weeks] window. This restores access to the
          crash-recovery cohort the [overhead_supply] penalty correctly demotes
          at their supplied breakout but which becomes genuinely virgin later.

          {b Default flipped [false] -> [true] on 2026-07-23} by the BUNDLE
          promotion (user-approved, R3) — see [overhead_supply] for the evidence
          chain.

          {b Semantics.}
          - [true] (new default): a stale Stage-2 survivor is re-admitted iff
            its warehouse sketch is present AND the breakout is into new high
            ground ([Resistance_supply.is_virgin] or [is_clear_of_supply]);
            sketch absent → no re-admission (no fabrication). Independent of
            [overhead_supply] — the virgin test needs only the sketch.
          - [false] (the deserialization fallback):
            {b bit-identical to baseline} —
            [Stock_analysis.t.virgin_readmission] is always [false] and the
            early-Stage-2 staleness rejection is unchanged; also the disarm
            escape hatch.

          {b Faithfulness} (W1/W2): the book's "new high ground" breakout — a
          fresh breakout into virgin territory with volume is a valid Stage-2
          entry regardless of how long ago the Stage-2 transition happened
          (weinstein-book-reference.md §Buy Criteria). Spine intact. R2: real
          top-level [bool] field → [Variant_matrix] flag axis. *)
  dawn_leverage_enabled : bool; [@sexp.default false]
      (** Master switch for the regime-conditional long-leverage "dawn"
          mechanism ({!Leverage_dawn}). When [true] AND the primary index is in
          a young post-bear "dawn" (its weekly MA is currently rising and the
          most recent negative->positive slope flip happened no more than
          [dawn_max_ma_flip_age_weeks] weeks ago), that Friday's entry walk
          sizes against the levered [dawn_initial_long_margin_req]; on a
          non-dawn week the entry walk is {b raised} to a cash account.

          {b ⚠ Permissive-funding / gated-sizing design.} The entry walk only
          {e sizes} the position; the {e funding} authority is the simulator,
          constructed once at the {e base} [initial_long_margin_req] and unable
          to track the per-Friday dawn value. So an armed cell MUST set the base
          [initial_long_margin_req] at least as permissive (numerically [<=]) as
          [dawn_initial_long_margin_req] — otherwise a levered dawn entry is
          floor-rejected rather than funded. {!Leverage_dawn.validate} enforces
          [base <= dawn]. See {!Leverage_dawn.dawn_effective_config}.

          {b ⚠ Margin-armed convention.} Dawn leverage runs margin-armed
          ([margin_config.enabled = true]) so borrowed dollars are priced and
          maintenance applies; {!Leverage_dawn.validate} (called at
          {!Weinstein_strategy.make}) raises when this flag is [true] with
          [margin_config] disarmed or [dawn_initial_long_margin_req] outside the
          interval [0.0 < req <= 1.0].

          {b Default [false] = EXACT no-op} (R1): the wiring short-circuits to
          the unchanged config before any bar fetch or signal computation, so a
          scenario is bit-identical with the field absent and with it explicitly
          [false].

          {b Faithfulness} (W1/W2): a {b deployment-intensity dial} conditioned
          on a {b trailing} (never forward-looking) regime label off the weekly
          MA. Spine untouched; not reversal timing — the MA-flip-age signal is
          lagging by construction. R2: real config field → [Variant_matrix] flag
          axis; default-off until a promotion-confirmation grid ACCEPT. *)
  dawn_initial_long_margin_req : float; [@sexp.default 1.0]
      (** The long-side initial-margin requirement the {b entry walk} sizes
          against during a "dawn" week when [dawn_leverage_enabled = true] — the
          leverage dial (see {!initial_long_margin_req} for the buying-power
          semantics). [1.0] = cash account (no leverage); [0.75] = Reg-T 1.33x;
          [0.5] = Reg-T 2x buying power.

          {b Default [1.0] = no-op}: even with [dawn_leverage_enabled = true],
          the dawn week sizes cash-account until a spec sets a fractional value.
          Only consulted on dawn weeks with the mechanism enabled; a non-dawn
          week raises the entry-walk requirement to a cash account.

          {b ⚠ Armed cells must set the base [initial_long_margin_req] to match
             (or be more permissive than) this value} — the simulator funds
          fills at the base requirement, so a base of [1.0] would floor-reject a
          levered [0.75] dawn entry. {!Leverage_dawn.validate} enforces
          [initial_long_margin_req <= dawn_initial_long_margin_req] (and 0.0 <
          req <= 1.0) when the mechanism is enabled.

          R2: real config field → single-component [Variant_matrix] float axis
          ([((dawn_initial_long_margin_req) (values (0.9 0.85 0.75)))]). *)
  dawn_max_ma_flip_age_weeks : int;
      [@sexp.default default_dawn_max_flip_age_weeks]
      (** Maximum age (in weeks) of the primary index's most recent
          negative->positive weekly-MA slope flip for the "dawn" label to be
          active. Default [78] (~1.5y) matches the P1b memo's lagging-label
          definition. Larger = a longer post-bear window counts as "dawn" (more
          levered weeks); [0] = only the exact flip week qualifies. Inert while
          [dawn_leverage_enabled = false]. R2: real config field →
          single-component [Variant_matrix] int axis. *)
  sparse_tail_min_bars : int; [@sexp.default 0]
      (** Sparse-tail eligibility gate (issue #2083 fix 1) — minimum number of
          daily bars a candidate ticker must have within the trailing
          [sparse_tail_window_trading_days] trading days ending at the
          screener's as-of date. Engineering data-hygiene gate, {b not} a
          Weinstein book rule: it closes a "zombie feed" hole where a
          delisted/renamed ticker's data source keeps serving occasional stale
          bars under the dead symbol, so the series reads current at the
          right-hand edge while the middle is almost empty.

          Default [0] = gate disabled (no-op, R1): every candidate is eligible
          regardless of tail density. Paired with
          [sparse_tail_window_trading_days]; both must be [> 0] to activate.
          Consumed only by [Weekly_snapshot_generator.generate] via
          [Sparse_tail_gate.check] — the backtest/live strategy path
          ([on_market_close]) never reads this field, so arming it cannot move a
          backtest number. R2: resolves through
          [Backtest.Overlay_validator.apply_overrides], armed today via
          [dev/weekly-picks/live-config-overrides.sexp]. *)
  sparse_tail_window_trading_days : int; [@sexp.default 0]
      (** Trailing window width, in trading days per the bar reader's own
          calendar (real holiday calendar in production; synthesized Mon-Fri
          weekdays for tests / in-memory readers — see
          [Bar_reader.of_snapshot_views]), that [sparse_tail_min_bars] is
          checked against. Default [0] = gate disabled (no-op, matches
          [sparse_tail_min_bars]'s default). See [sparse_tail_min_bars] for the
          full rationale. *)
  spike_bar_threshold_pct : float; [@sexp.default 0.0]
      (** Spike-bar "data-suspect" report-hygiene flag (issue #2083 fix 3) —
          minimum absolute single-bar move, in percentage points vs the prior
          bar's close, that marks a candidate's last bar as anomalous.
          Engineering data-hygiene flag, {b not} a Weinstein book rule: it
          neither admits nor rejects a candidate and moves no entry / stop /
          size. A flagged candidate STAYS in the ranked list with
          [Weekly_snapshot.candidate.data_suspect = true] plus a warning line.

          Default [0.0] = flag disabled (no-op, R1): every candidate carries
          [data_suspect = false] and no spike warning is emitted. Consumed only
          by [Weekly_snapshot_generator.generate] via [Spike_bar_gate.check] —
          the backtest/live strategy path never reads this field, so arming it
          cannot move a backtest number. R2: resolves through
          [Backtest.Overlay_validator.apply_overrides]. *)
  rename_detect_min_overlap_days : int; [@sexp.default 0]
      (** Live ticker-rename detection (issue #2083 fix 2) — minimum number of
          dates a stale ticker and a candidate successor must share before their
          daily returns are compared. Engineering data-hygiene mechanism,
          {b not} a Weinstein book rule: it neither admits nor rejects a
          candidate on any strategy criterion and moves no entry / stop / size.

          When armed, [Weekly_snapshot_generator.generate] looks for a
          {e succession} — a ticker that goes sparse at the right-hand edge
          while a younger ticker takes over with matching returns — drops the
          dead predecessor from candidate consideration and emits a warning
          naming the successor. See [Rename_detector] and
          [dev/plans/rename-tracking-live-2026-07-26.md].

          Default [0] = detection disabled (no-op, R1): the generator does not
          even load the series. Paired with [rename_detect_match_fraction]; both
          must be [> 0] to activate. Consumed only by
          [Weekly_snapshot_generator.generate] — the backtest/live strategy path
          never reads this field, so arming it cannot move a backtest number.
          R2: resolves through [Backtest.Overlay_validator.apply_overrides]. *)
  rename_detect_match_fraction : float; [@sexp.default 0.0]
      (** Fraction of the shared-date return pairs that must agree (within
          [Rename_detector.Config.default.ret_epsilon]) for a succession to be
          reported. [Twin_detector]'s top-3000 calibration puts real rename
          twins at 0.95-0.99 and different-company controls below 0.06, so
          [0.95] is the natural armed value. Default [0.0] = detection disabled
          (no-op, matches [rename_detect_min_overlap_days]'s default). See
          [rename_detect_min_overlap_days] for the full rationale. *)
  entry_through_band_pct : float; [@sexp.default 0.0]
      (** Entry reconciliation (issue #2103) — the de-minimis band, in
          percentage points of the entry level, within which a candidate whose
          close has edged past its breakout entry still gets today's resting
          stop ticket. A stop order resting a few cents under the market fills
          essentially at the stop, so re-anchoring inside the band buys nothing.
          Above it the ticket re-anchors to a market fill at the close and is
          {b re-sized on that fill}. See [Entry_reconciliation.classify].

          {b ⚠ Paired with [entry_extension_max_pct], which is the arming
             switch} — this field alone activates nothing. [1.0] (one percentage
          point) is the armed value. R2: resolves through
          [Backtest.Overlay_validator.apply_overrides], armed via
          [dev/weekly-picks/live-config-overrides.sexp]. *)
  entry_extension_max_pct : float;
      [@sexp.default default_entry_extension_max_pct]
      (** Entry reconciliation (issue #2103) — the do-not-chase cap: the
          furthest past the breakout entry, in percentage points of the entry
          level, that an entry order may fill. It is the limit leg of the
          [StopLimit (E, E * (1 +/- pct/100))] ticket, and nothing else.

          {b ⚠ It is no longer a suppression threshold} (issue #2404). The picks
          artifact used to drop the ticket of any candidate past this cap and
          move its row into a do-not-chase watch section. It now keeps the
          ticket and annotates it "will not fill at current price" — which is
          exactly what the order does: the limit sits below the market, so it
          rests unfilled and is re-evaluated next week, the same behaviour the
          simulator gives under [enable_sim_entry_stoplimit]. One rule, two
          views; there is no separate suppression dial to tune.

          Execution correctness, not a new strategy mechanic:
          [Weekly_snapshot.candidate.entry] is the breakout level from the
          {e transition} week and the <=4-week early-Stage-2 window admits a
          name for weeks afterwards, so a buy-stop printed far below the current
          price is an instantly-filling market order whose displayed risk
          understates the real risk. The cap follows
          [docs/design/weinstein-book-reference.md] §1 "Stage 2 detail (Ch. 2)",
          which locates the buy at the breakout or on "at least one pullback
          close to the breakout point". No admission rule changes and no
          pullback-timing mechanic is implied — see [Entry_reconciliation] for
          why the section's "Late Stage 2 warning" is deliberately NOT the
          citation.

          {b Default [2.0] = the live value}
          ({!default_entry_extension_max_pct};
          {b flipped from the [0.0] no-op on 2026-08-26} together with
          [enable_sim_entry_stoplimit] — user-directed fidelity decision
          recorded on issue #2405). [2.0] is the #2404-unified live value (user
          decision 2026-08-25: live's old [15.0] was a one-day eyeball
          calibration, and [2.0] is the corpus value the staged
          record-convention specs already used). The default and
          [dev/weekly-picks/live-config-overrides.sexp] now agree, so a backtest
          run from the default config prices its entry tickets the way the
          weekly picks do.

          {b The flip is a fidelity change, not a return claim.} The
          [2026-08-04] entry-ledger entry REJECTED this pair on returns; that
          surface compared sim-vs-sim, which is the wrong estimand for "does the
          simulator model the orders we actually place". See
          [enable_sim_entry_stoplimit] for the full R3 basis. No golden moves
          {i because} the numbers improved — they move because the basis
          changed.

          Setting [0.0] restores the pre-flip no-op: every candidate carries
          [Entry_reconciliation.Not_reconciled], sizing uses [entry] exactly as
          before, and (with the cap absent) the backtest runner falls back to
          Market entry fills. Consumed by [Weekly_snapshot_generator.generate]
          (report/live-ticket path), and — only when
          [enable_sim_entry_stoplimit] is also on — by the backtest runner as
          the simulator's entry-fill cap. R2: resolves through
          [Backtest.Overlay_validator.apply_overrides]. *)
  enable_sim_entry_stoplimit : bool; [@sexp.default true]
      (** Simulator entry fill model (#2158 Phase 2) — when [true] AND
          [entry_extension_max_pct > 0], the backtest runner threads the cap
          into the simulator so entries fill as
          [StopLimit (entry, entry * (1 +/- entry_extension_max_pct/100))]
          (long/short mirrored) instead of Market orders: the order triggers at
          the breakout entry and refuses fills beyond the do-not-chase cap, so a
          gap past the cap is a no-fill and the candidate is re-evaluated at the
          next strategy call. This aligns the simulator with the live
          [Weinstein_order_gen] StopLimit(E, cap) tickets and the report's
          [Entry_reconciliation] semantics.

          {b Default [true] since 2026-08-26} — flipped as a PAIR with
          [entry_extension_max_pct] ([0.0] -> [2.0]), because the runner arms
          the StopLimit path iff
          [enable_sim_entry_stoplimit && entry_extension_max_pct > 0.0]
          ([Backtest.Panel_runner] [_entry_cap_for_sim];
          [Backtest.Execution_faithfulness.entry_order_kind_of_config]), so a
          lone flag flip would be a half-mechanism that changes nothing. Before
          the flip the default was [false] (Market fills).

          {b R3 basis — a user-directed FIDELITY decision, NOT a return claim}
          (recorded on issue #2405, 2026-08-26; same class as the #2530
          stops-basis flip). The [2026-08-04] entry in
          [dev/experiments/_ledger/] REJECTED this flip {i on returns}, and that
          verdict is not disputed here: it is overridden, openly, because the
          surface that produced it compared {b sim-vs-sim} — the wrong estimand
          for the question actually being decided, which is whether the
          simulator models the orders live actually places. Live emits
          [Weinstein_order_gen] [StopLimit (E, cap)] tickets; before this flip
          the default backtest filled the same decisions as Market orders, so
          every default-config number described an execution model nobody runs.
          {b No return improvement is claimed anywhere} — goldens move because
          the basis moved.

          {b ⚠ This is a fill-model basis change}: every golden not already
          arming the pair is re-pinned by the flip. Weinstein authority: the
          book locates the buy at the breakout or a pullback close to it, so an
          unfilled order (missing > chasing) is the faithful failure mode. R2:
          still axis-expressible as
          [((flag enable_sim_entry_stoplimit) (values (true false)))]; setting
          [false] (or the cap to [0.0]) restores Market fills. *)
  sim_entry_trigger_at_suggested : bool; [@sexp.default false]
      (** Book-faithful E-anchored entry trigger. When [true] AND
          [enable_sim_entry_stoplimit] is on, the strategy's
          [CreateEntering.entry_price] is set to the candidate's
          [suggested_entry] (the graded breakout level [E]) instead of the most
          recent raw close (the G14 fix-B default). The emitted order is then a
          genuine [StopLimit (E, E * (1 +/- entry_extension_max_pct/100))]
          resting AT the breakout level — matching the book's ticket
          ([docs/design/weinstein-book-reference.md] §4.7) and the live report's
          tickets. Sizing follows automatically: [make_entry_transition] anchors
          [compute_position_size ~entry_price] at the same [effective_entry].

          {b Default [false] = current-close trigger, bit-identical to every
             existing baseline/golden} (R1).
          {b ⚠ Since the 2026-08-26 fill-model flip,
             [enable_sim_entry_stoplimit] is default-[true]}, so arming this
          field alone DOES move a backtest number — the previous "gated on a
          default-off flag, therefore inert" note no longer holds.
          {b ⚠ A fill-model basis change when armed} — its own WF-CV surface,
          never bundled. R2: axis-expressible as
          [((flag sim_entry_trigger_at_suggested) (values (true false)))].
          Decision record: [dev/plans/gtc-breakout-orders-2026-08-05.md] Step 0
          option (b).

          {b Split-safety} (why the G14 fix-B default exists): fix-B pinned the
          trigger to the current close because [suggested_entry] {i could} land
          in a different price space than the fill across a split boundary. That
          hazard is closed by G14 fix-A — the screener's high/low lookback is
          truncated at the most recent split ([Stock_analysis]
          [_no_split_between]), so [E] is computed in {i current} raw
          close-price space, and in-sim screener bars and fill bars share one
          source. (Deliberately no epsilon-disagreement fallback to close: [E]
          is by design {i above} the close for a long breakout, so such a guard
          would misfire on every normal breakout.) *)
  entry_anchor_local_range_weeks : int; [@sexp.default 0]
      (** Book-faithful local-range entry anchor. When [> 0], the screener
          anchors each candidate's [suggested_entry] at the top of the
          {i current} trading range — the split-safe maximum high over the most
          recent [entry_anchor_local_range_weeks] bars
          ([Stock_analysis.t.local_range_top]) — instead of the 520-week graded
          resistance top. This is the book's "write down the price it would need
          to break out" ticket ([docs/design/weinstein-book-reference.md] §4.1):
          a nearer, earlier-triggering buy-stop. Example value: [26].

          {b ⚠ Prerequisite for [entry_freshness_basis = Range_top_breakout].}
          That basis measures freshness against
          [Stock_analysis.t.local_range_top], which exists only when this field
          is [> 0]. Armed alone — basis set, anchor left at [0] — the basis
          admits {b nothing}. A backtest smoke test does not catch this (the
          trade count merely drops); see memory
          [project_rt_needs_its_anchor_knob]. Every cell arming the basis must
          also set this field.

          {b Strictly ticket-level.} Threaded verbatim into
          [Stock_analysis.config.entry_anchor_local_range_weeks] on both the
          simulator screening path ([_stock_analysis_config_for]) and the
          weekly-report path ([Weekly_snapshot_generator]). It moves only the
          entry ticket (and its derived stop / risk); admission,
          [resistance_quality] grading, the false-virgins protection
          ([[project_false_virgins_load_bearing]]), cascade scoring, and stage
          classification are all UNCHANGED.

          {b Composes with the E-anchored fill family.} The local top is
          typically {i below} the graded top, so an armed
          [sim_entry_trigger_at_suggested] + [enable_sim_entry_stoplimit] order
          rests / triggers earlier than with the graded E.

          {b Default [0] = off, bit-identical to every existing baseline/golden}
          (R1): [local_range_top = None] and the screener uses the graded
          breakout top exactly as before. R2: axis-expressible as
          [((flag entry_anchor_local_range_weeks) (values (13 26 52)))];
          default-off until a ledger ACCEPT. Note:
          [dev/notes/honest-ladder-2026-08-05.md]. *)
  entry_freshness_basis : Entry_freshness.basis;
      [@sexp.default Entry_freshness.Ma_cross]
      (** F1 — which event starts the Stage-2 admission clock.

          {b The mis-mapping it addresses.}
          [docs/design/weinstein-book-reference.md] §1 says Stage 2 {i begins}
          when the stock breaks out above the top of the resistance zone AND
          above the 30-week MA. Our stage classifier instead starts
          [weeks_advancing] at the {b MA cross}, so a name that crossed its MA
          ten weeks ago but is still coiled under its range top has aged out of
          the [early_stage2_max_weeks <= 4] window before the book's Stage-2
          week one has happened.

          {b [Ma_cross] (default, no-op).} Today's clock, verbatim. R1: every
          existing golden is bit-identical — [range_top_freshness] is [None] and
          [is_breakout_candidate] runs its pre-F1 arms unchanged.

          {b [Range_top_breakout] (armed).} Freshness is measured from the
          breakout above the ticket anchor ([entry_anchor_local_range_weeks] →
          [Stock_analysis.t.local_range_top] — deliberately the {i same} level
          the resting order uses, so the freshness test and the ticket cannot
          drift apart).
          {b ⚠ That anchor knob must be set too; at its default [0] this basis
             admits nothing.} A non-late Stage-2 candidate is admitted iff the
          close is at or within [Entry_freshness.proximity_pct] (5%) below the
          anchor {b and} the MA is not declining {b and} the anchor clears the
          MA — §4.1 requirements 1–3 kept explicit, because "a breakout below a
          declining MA is a trap, not a buy". The MA-cross age is not consulted:
          the basis {b replaces} that window rather than widening it, so this is
          not a stealth re-run of the rejected continuation (#1366) or
          early-admission axes — the [<= 4] value itself is untouched.

          {b Composes with [reject_declining_ma_long_entry] (#1775)} without
          conflict: F1 enforces the same §4.1 MA condition earlier and against
          the {i anchor}, so an armed basis never admits a candidate that gate
          would then reject.

          {b Faithfulness (W1/W2).} Spine intact — Stage-2-only, volume
          confirmation, and the macro/sector gates are untouched. R2:
          axis-expressible as
          [((flag entry_freshness_basis) (values (Ma_cross
           Range_top_breakout)))]. R3: stays [Ma_cross] until a ledger ACCEPT
          plus the promotion-confirmation grid. Plan:
          [dev/plans/entry-ticket-async-v2-2026-08-10.md] §3 F1. *)
  stop_anchor_at_entry_base : bool; [@sexp.default false]
      (** Book-faithful initial-stop re-anchoring for E-anchored entries — the
          faithfulness fix that PAIRS with the E-anchored entry family
          ([sim_entry_trigger_at_suggested] + [enable_sim_entry_stoplimit]).
          Those tickets rest the entry at the breakout level [E], but the
          initial stop still comes from the deep support-floor machinery
          anchored to crash lows; for a crash-recovery name that mismatched pair
          inflates risk% so the entry walk's 15% [max_stop_distance_pct] gate
          rejects the ticket as [Stop_too_wide]. That is unfaithful to
          [docs/design/weinstein-book-reference.md] §5.1, which places the
          breakout buy's initial stop just under the breakout base / below the
          MA, not under the entire multi-year crash floor.

          When [true] AND the entry is E-anchored (the effective
          [trigger_at_suggested] the strategy derives from
          [sim_entry_trigger_at_suggested && enable_sim_entry_stoplimit]), a
          support-floor-derived initial stop that sits farther from [E] than
          [stops_config.max_stop_distance_pct] is RE-ANCHORED to the
          buffer-below-breakout stop ([E *. initial_stop_buffer] then the
          standard round-nudged half-correction inset). A structural floor
          already within the 15% book limit is kept UNCHANGED, so normal-shape
          candidates are unaffected. The [Stop_too_wide] gate itself is NOT
          modified.

          {b Strictly the INITIAL stop, ticket-level.} Admission,
          [resistance_quality] grading, [breakout_price], cascade scoring, stage
          classification, and the false-virgins protection are all UNCHANGED.
          The trailing-stop machinery ([Weinstein_stops.update] / stop-recompute
          on held positions) is UNTOUCHED.

          {b Default [false] = off, bit-identical to every existing
             baseline/golden} (R1): the support-floor stop is installed
          verbatim. Because it additionally gates on the E-family being armed
          ([sim_entry_trigger_at_suggested] still defaults [false], even though
          [enable_sim_entry_stoplimit] is default-[true] since the 2026-08-26
          fill-model flip), arming this field alone cannot move a backtest
          number. R2: axis-expressible as
          [((flag stop_anchor_at_entry_base) (values (true false)))];
          default-off until a ledger ACCEPT. Note:
          [dev/notes/honest-ladder-2026-08-05.md]. *)
  sim_entry_fill_next_open : bool; [@sexp.default false]
      (** Next-bar-open fill realism for Market entries (Fix #1). Threaded from
          this config into the simulator dependencies by the backtest runner
          (same route as [entry_extension_max_pct]).

          {b The realism gap it closes.} Because the engine retains the last bar
          per symbol on non-trading (weekend/holiday) steps, a Market entry
          created from a Friday-close decision is filled on the following
          non-trading step against the {i stale} signal bar — i.e. at that same
          bar's open, a price observed {i before} the close the decision was
          made on. That is an optimistic, effectively look-back fill.

          When [true], a Market order that would route to an [Entering] position
          is NOT filled on a step where its symbol has no fresh bar; it stays
          pending until the next {i fresh} trading bar and fills at that bar's
          open. {b Scope: Market ENTRY orders only.} Exits, stops, [StopLimit]
          entries, and every other order path are untouched. The strategy's
          decision-time [CreateEntering.entry_price] (used for sizing and
          stop-distance math) is UNCHANGED — only the executed engine fill
          price/date move. The realized cost basis comes from the engine fill so
          it moves with the fill; [Position.entry_price] remains the decision
          close by construction.

          {b Default [false] = current stale-bar fill, bit-identical to every
             existing baseline/golden} (R1).
          {b ⚠ A fill-model basis change when armed} — its own WF-CV surface and
          deliberate golden re-pins before any default flip; NEVER bundled. R2:
          axis-expressible as
          [((flag sim_entry_fill_next_open) (values (true false)))].
          Weinstein-faithful: spine untouched, only the {i fill assumption}
          changes. Plan: [dev/plans/fill-model-faithfulness-2026-08-07.md]
          Workstream C. *)
  freeze_entry_at_first_breakout : bool; [@sexp.default false]
      (** No-chase entry-[E] freeze (Fix #2).

          {b The faithfulness gap it closes.} The screener recomputes each
          candidate's [suggested_entry] — [E] =
          [breakout_price *. (1 + entry_buffer_pct)] — every Friday from the
          current analysis. For a stock making new highs, [E] floats {i up} week
          over week, so the resting entry ticket ratchets upward with the trend:
          from the screener's view each Friday is a "fresh breakout," but from a
          Weinstein-purist view it is {b buying an extended stock}
          ([docs/design/weinstein-book-reference.md] §4.1, §3).

          {b Behaviour when [true].} The first Friday a symbol qualifies
          (appears as an actionable entry candidate with a suggested [E]), that
          [E] is {b pinned}. On subsequent Fridays the strategy reuses the
          pinned [E], overriding the freshly recomputed higher level, for as
          long as the setup stays live. The pin is {b released} when the symbol
          stops qualifying and is no longer held (candidate drops out / setup
          expires / the position round-trips to [Closed]), so a genuinely new
          base/breakout later earns a fresh [E]. A symbol resting an unfilled
          entry order stays held, so its pin persists (dormant) until the
          position closes.

          {b Strictly ticket-level and the entry [E] only.} Freezing overrides
          the candidate's [suggested_entry]; the installed initial stop is
          re-derived from the effective entry as before. The paired
          suggested-stop / [risk_pct] audit metadata reflect the current week's
          screener output.

          {b Faithfulness (W2): this INCREASES faithfulness.} It restores the
          book's "buy {i the} breakout, not every successive higher high" rule.
          Spine untouched — Stage-2 admission, volume confirmation, grading,
          stage classification, and the stop machinery are all UNCHANGED.

          {b Default [false] = off, bit-identical to every existing
             baseline/golden} (R1): {!Entry_freeze.apply} returns the candidate
          list untouched and never allocates a pin. R2: axis-expressible as
          [((flag freeze_entry_at_first_breakout) (values (true false)))];
          default-off until a ledger ACCEPT. Plan:
          [dev/plans/fill-model-faithfulness-2026-08-07.md] Workstream D. *)
  enable_entry_ticket_rescreen : bool; [@sexp.default false]
      (** F2 {b primary}, the book-supported half: re-validate every unfilled
          entry ticket on each weekly review, and cancel the ones whose setup no
          longer exists. Split out of the former [entry_order_ttl_weeks] on
          2026-08-16, which armed {b two} mechanisms at once — this re-screen
          and the arbitrary clock below — with no way to have the faithful half
          without the invented one.

          {b Behaviour when [true].} On each weekly review an unfilled
          [Entering] position is cancelled when its symbol no longer classifies
          into the stage its side requires (base broken down / MA rolled over),
          its sector rating flipped against it, or the macro gate flipped. The
          predicate reuses the cascade's own Phase-1 stage filter, sector
          pre-filter and {!Screener.longs_admitted_by_macro} /
          {!Screener.shorts_admitted_by_macro} gates, so re-screen and screen
          cannot drift.

          {b Faithfulness (W2): BOOK-SUPPORTED.} §4.7 has the order standing
          "until you either cancel the orders or they are actually executed",
          and §7's weekend homework is the loop at which that cancel decision is
          taken. Unlike the clock, this half carries no invented number. Spine
          untouched: it governs only the lifetime of an order that has not yet
          become a position.

          {b ⚠ REJECTED as a lever} on 2026-08-18
          ([dev/experiments/_ledger/2026-08-18-entry-ticket-rescreen.sexp]) —
          kept as an axis, not a recommendation.

          {b Default [false] = off} (R1), which with
          [entry_order_max_rest_weeks = 0] reproduces the old
          [entry_order_ttl_weeks = 0] exactly: no cancels, weekly re-issue and
          GTC-forever persistence as pinned by
          [trading/simulation/test/test_gtc_entry_persistence.ml]. R2:
          axis-expressible as
          [((flag enable_entry_ticket_rescreen) (values (true false)))]. *)
  entry_order_max_rest_weeks : int; [@sexp.default 0]
      (** F2 {b backstop}, the invented half: the clock. An unfilled ticket that
          has rested more than this many whole weeks is cancelled regardless of
          whether it still qualifies. [0] = {b unbounded} = the default. A
          ticket placed on review week 0 survives review week
          [entry_order_max_rest_weeks] and is cancelled at week
          [entry_order_max_rest_weeks + 1].

          {b Why it exists at all.} Unbounded is genuinely wrong at the extreme:
          a resting order has been observed surviving {b 21.7 years} before
          filling. The clock's job is removing that absurdity.

          {b ⚠ Promoted to 26 on 2026-08-18, REVERTED on 2026-08-19} — the
          reversal is the more useful fact. On the one golden that arms
          [enable_sim_entry_stoplimit] {i as of that date} (the only place a
          clock can bite, since Market entries fill immediately and never rest —
          {b since the 2026-08-26 fill-model flip made that flag default-[true],
             every default-config run rests tickets}, so the clock now bites
          everywhere; it stays at the unbounded [0] default), clock=26 measured
          {b −40.91pp} against clock=0 across three salts with
          {b complete separation}. The mechanism is a {b tail-touching lever}:
          the clock cuts the resting-ticket population blind, and that
          population is where the fat-tail winners live — the removed cohort's
          entire positive total was a single trade larger than the cohort's net.
          Nth confirmation of [project_edge_is_the_fat_tail].

          {b The calibration lesson.} The promotion rested on a 26-year base
          whose gap sat {i inside} that base's own seed spread, while the
          golden's base is ~33x quieter. {b Every base needs its own null};
          never import one base's noise floor to judge another's gap.

          {b If a bound is wanted}, the evidence points at {b 156 weeks} rather
          than 26 — but as a value to test first, not a measured winner: one of
          three bases inverts the ranking, and the supporting arithmetic is
          static bucket subtraction, which is not the counterfactual (cutting at
          26 removed 59 trades and {i added} 48). Any future promotion needs a
          ledger ACCEPT plus the [promotion-confirmation.md] grid, neither of
          which the 26 flip had.

          {b Faithfulness (W2): BOOK-NEUTRAL dial.} The book grants the cancel
          authority (§4.7 / §7) but names no number, so every value here is a
          free parameter — which is why it is the {i backstop}, not the primary
          rule. Do {i not} substitute the re-screen: the two rules select
          {b opposite} populations, and the re-screen was itself REJECTED.

          R2: axis-expressible as
          [((flag entry_order_max_rest_weeks) (values (0 13 26 52 156)))]. Full
          record: [dev/experiments/clock26-golden-ab-2026-08-19/]. *)
  reserve_cash_for_resting_tickets : bool; [@sexp.default false]
      (** G3 of [dev/plans/ticket-funding-2026-08-16.md]: subtract the cost the
          book has already committed to {b resting} entry tickets from the cash
          the entry walk is allowed to spend this tick.

          {b The leak it closes.} {!Entry_audit_capture.check_cash_and_deduct}
          already enforces cash discipline {i within} one tick, but its
          [remaining_cash] ref is re-seeded from [portfolio.cash] every tick,
          and a ticket placed in week [N] and still resting in week [N+1] has
          taken {b no} cash. So the next walk sees that money as available and
          commits it again; repeat weekly and the book carries more claims than
          cash. When several over-committed tickets then trigger in the same
          week, the first ones consume the balance and the rest are
          {b destroyed} — not retried, not resized
          ([[project-ticket-dies-on-cash-shortfall]]).

          {b Reserved amount} is the {b unfilled remainder},
          [(target_quantity - filled_quantity) * entry_price], summed over
          [Entering] {b long} positions. Partial fills already drew their own
          cash; an entering {i short} credits cash on fill, so reserving against
          it would shrink the budget for a claim that pays in.

          {b No double-count on the filling tick.}
          {!Trading_simulation.Simulator} applies fills in
          [_process_fills_and_cancels] {i before} [_call_strategy], so a ticket
          that fills this tick has already left [Entering] and its cash has
          already left [portfolio.cash] when [spendable] is computed.

          {b Not [cash_reserve_pct]} (retired in #2286): that was a blanket
          idle-cash floor. This reserve is earmarked against
          {b specific written claims} and released the moment a ticket fills or
          cancels; with no resting tickets it is exactly [0.0].

          {b The cost, stated up front.} Reserved cash is idle cash. Deployment
          already sits near the exposure cap, so this plausibly pushes
          utilisation {i below} it — report deployment alongside return.

          [false] (default) = [spendable] is [portfolio.cash], bit-identical to
          the prior behaviour (R1). R2: axis-expressible as
          [((flag reserve_cash_for_resting_tickets) (values (true false)))]. *)
  entry_fill_reject_retries : int; [@sexp.default 0]
      (** G2a of [dev/plans/ticket-funding-2026-08-16.md]: how many further
          attempts a triggered entry ticket gets after the portfolio refuses to
          fund its fill. [0] (default) is today's behaviour — one refusal
          destroys the ticket.

          {b The failure it addresses.} The engine marks a resting entry order
          [Filled] the moment the fill function returns a trade, {i before}
          {!Trading_portfolio.Portfolio.apply_single_trade} has agreed to book
          it. When the portfolio then refuses (insufficient cash),
          {!Trading_simulation.Cancel_handler.transitions_for_rejected_trades}
          emits a [CancelEntry] and the [Entering] position is deleted — so
          {b one cash-tight instant permanently destroys a ticket} that may have
          rested for months, and the margin of destruction can be arbitrarily
          small. Rate: {b ~25% of would-be entries}, stable across universes and
          periods.

          {b What [n > 0] does.} The ticket is put {b back} rather than
          destroyed: the [Entering] position is left alone (it never filled) and
          a fresh copy of the refused order is re-submitted to the order
          manager, so the engine re-offers it next tick against whatever cash
          the book has by then. After the [n]-th refusal the ticket dies exactly
          as today. This is the entry-side mirror of
          {!Trading_simulation.Cancel_handler.revert_rejected_exits}.

          {b Why it may fail, stated up front.} A retry changes {e when} we
          enter, and the price the retry gets is worse than the one the ticket
          triggered at — at which point the do-not-chase cap
          ({!entry_extension_max_pct}) starts refusing the retry itself
          ([[project-sim-entry-stoplimit-reject]]).

          {b ⚠ Alternatives, not complements.} G2a (retry), G2b
          ([entry_fill_size_to_available], resize) and G3
          ({!reserve_cash_for_resting_tickets}, prevent) are three policies for
          one failure. Arm one at a time. {b No ledger verdict exists} —
          default-off until one does (R3). R2: axis-expressible as
          [((flag entry_fill_reject_retries) (values (0 1 2)))]. *)
  entry_fill_size_to_available : bool; [@sexp.default false]
      (** G2b of [dev/plans/ticket-funding-2026-08-16.md]: when [true], an entry
          fill the portfolio refuses for want of cash is re-offered at the
          largest quantity the book {e can} fund, instead of the ticket being
          destroyed. [false] (default) is today's behaviour.

          {b The failure it addresses} is the same one G2a
          ({!entry_fill_reject_retries}) addresses — a refusal cancels a ticket
          that may have rested for months, at a rate of
          {b ~25% of would-be entries}.

          {b How it differs from G2a.} A resize enters
          {b now, at the price the ticket triggered at}, so it pays none of the
          timing tax that sinks the retry — the entry is simply smaller. That
          makes it the smallest possible change to the failure mode, and it
          turns the near-miss cohort into near-full fills.

          {b What it costs.} It silently breaks fixed-risk sizing: the position
          no longer carries {!Weinstein_portfolio_risk.risk_per_trade_pct} of
          the book, and a systematically undersized entry into the largest
          winners is its own tail tax ([project_edge_is_the_fat_tail]).
          {!entry_fill_min_size_fraction} is the guard on that.

          {b Precedence with G2a.} When both are armed the simulator offers the
          resize {e first} on each refusal; only a refusal the resize declines
          (below the minimum fraction) consumes retry budget.

          {b ⚠ Interacts with} {!stop_width_mode}'s [Size_down], which also
          decouples the filled size from the designed size — with both armed,
          two independent mechanisms shrink the same position and the resulting
          size attributes to neither. Not special-cased in code: a cell arming
          both must say why.

          {b ⚠ Alternatives, not complements} (see
          {!entry_fill_reject_retries}); arm one at a time.
          {b No ledger verdict exists} — default-off until one does (R3). R2:
          axis-expressible as
          [((flag entry_fill_size_to_available) (values (true false)))]. *)
  entry_fill_min_size_fraction : float; [@sexp.default 0.5]
      (** G2b's minimum viable size: the smallest fraction of a ticket's
          {e designed} quantity that a clamped fill may be. A clamp below it is
          refused and the ticket takes the unchanged destroy path, so the
          mechanism buys back the near-miss cohort without booking token
          positions that carry the trade's costs and none of its exposure.

          Read only when {!entry_fill_size_to_available} is [true]; inert
          otherwise, so the default [0.5] changes no behaviour on its own (R1).
          [0.0] accepts any positive clamp. {b ⚠ [1.0] is NOT a no-op}: the
          guard is a strict [<] against [fraction *. designed], so a clamp
          {e equal} to the designed quantity still books — reachable, because
          the rejection batch is folded in order and an accepted exit later in
          the same batch can raise cash back to the full designed cost. A grid's
          control cell is the [entry_fill_size_to_available = false] flag, never
          [1.0].

          The designed quantity is the [Entering] position's [target_quantity],
          i.e. [Weinstein_portfolio_risk.compute_position_size]'s output — so
          the fraction is measured against a number that already respects the
          risk-based, side-exposure, per-position and sizing-cash caps. R2:
          axis-expressible as
          [((flag entry_fill_min_size_fraction) (values (0.25 0.5 0.75)))]. *)
  stop_width_mode : Stop_width_mode.t;
      [@sexp.default Stop_width_mode.Drop_over_max]
      (** F3: what the entry walk does with a candidate whose structural initial
          stop sits further than [stops_config.max_stop_distance_pct] from
          entry. Three readings of one book sentence:

          - [Drop_over_max] (default) is today's G15 step-3 drop — the candidate
            is skipped with [Audit_recorder.Stop_too_wide]. §5.1 read as a ban.
          - [Size_down] admits it, up to {!stop_width_size_down_max_pct}, and
            {e tags} the entry
            [Entry_audit_capture.entry_meta.sized_down_wide_stop = true] (trace
            outcome [Sized_down_wide_stop]). Note that fixed-risk sizing already
            shrinks the share count ~[1 / stop_distance] under {b every} mode —
            sizing never reads the mode — so what [Size_down] adds over the
            default is the admission and the tag, not the shrink.
          - [Demote_over_max] admits the identical candidate at the identical
            size, but walks it {e after} every candidate whose stop is within
            the limit, so wide stops are funded only with what is left
            ({!Entry_stop_width_order}). The delta against [Size_down] is
            {b order only}, which means the two diverge exactly when capital
            binds.
            {b ⚠ Also bounded by {!stop_width_size_down_max_pct} — leaving that
               at [0.0] makes this mode a no-op}, so a spec must set the ceiling
            for it to bite.

          {b Honest citation.} §5.1 says "prefer other candidates", which is
          comparative rather than an absolute ban — and the book reserves ban
          vocabulary for the cases it means as bans (§4.4 on negative RS) while
          {e grading} the rest (§4.3 A+/A/B/C). Of the three, [Demote_over_max]
          is closest to §5.1's wording. [Size_down] is NOT a documented book
          mechanism: the book's remedies for a wide stop are (i) anchor at the
          nearest prior correction low
          ([stops_config.support_floor_anchor_scope = Nearest], the competing
          {e faithful} arm), (ii) the §5.3 trader preset's 4–6% stop, (iii) pass
          — never risk-parity size-down. It remains a tolerated-participation
          {e reading}, labelled as such; see {!Stop_width_mode}.

          {b Default [Drop_over_max] = bit-identical to every existing
             baseline/golden} (R1). R2: axis-expressible as
          [((flag stop_width_mode) (values (Drop_over_max Size_down
           Demote_over_max)))]; stays default-off until a ledger ACCEPT plus the
          promotion-confirmation grid (R3). Evidence that the width gate — not
          the entry anchor — excludes the crash-recovery cohort:
          [dev/notes/entry-anchor-defect-a-refuted-2026-08-16.md]. *)
  stop_width_size_down_max_pct : float; [@sexp.default 0.0]
      (** Sanity ceiling for {!stop_width_mode} — {b both} [Size_down] and
          [Demote_over_max]: stop distances above this fraction of entry are
          still dropped, so neither mechanism can admit unbounded structural
          risk. [0.0] (the default) falls back to
          [stops_config.max_stop_distance_pct], which makes an
          armed-but-unconfigured mode admit exactly the population
          [Drop_over_max] admits. The field name predates [Demote_over_max]; it
          was not renamed because 26 committed specs set it.

          It exists as its own knob rather than reusing [max_stop_distance_pct]
          so a sweep can widen the {e admission} boundary without also moving
          the §5.1 15% line that other mechanisms read (the
          [stop_anchor_at_entry_base] re-anchor threshold, and the
          [Sized_down_wide_stop] tag boundary itself) — so a wide-admission cell
          is not confounded with a re-anchor change. Unread under
          [Drop_over_max]. Default [0.0] is an exact no-op (R1);
          axis-expressible (R2). *)
  volume_confirm_at_fill : bool; [@sexp.default false]
      (** F5 — judge the breakout's volume {b at the fill}, not at placement
          ([docs/design/weinstein-book-reference.md] §4.2 + §4.7).

          {b The faithfulness gap it closes.} Book §4.7's GTC buy-stop is
          written {i before} the breakout, so breakout-week volume is unknowable
          at placement — yet today's cascade demands Strong/Adequate volume at
          the Friday screen. §1 further notes that base volume "dries up", so a
          screen-week volume requirement selects {i against} textbook bases.
          §4.2's confirmation is defined on the breakout week, which under a
          resting ticket is the {b fill} week.

          {b Armed behaviour} (two inseparable halves, both gated on
          {!volume_confirm_at_fill_armed} — this flag AND the StopLimit family
          [sim_entry_trigger_at_suggested] + [enable_sim_entry_stoplimit]):

          - {b Placement}: the screen-week volume signal is no longer required
            to place the ticket ([Stock_analysis.config.require_breakout_volume]
            goes [false]). Every other gate — stage, base, RS, resistance,
            macro, sector — still applies, so the placed-ticket population
            widens but stays bounded.
          - {b At fill}: {!Volume_eject_runner} confirms the fill week's volume
            against {b both} §4.2 branches ([Volume.confirms_breakout]) on the
            first screening tick at which that week is complete (no partial-week
            lookahead). Unconfirmed ⇒ the position is ejected, audit tag
            [Volume_eject]; confirmed ⇒ held.

          {b ⚠ The eject is INSEPARABLE from the flag.} There is deliberately no
          eject-off cell: holding a volume-unconfirmed breakout would be a W1
          spine item-3 violation, and §4.2's low-volume-breakout SELL rule is
          explicit that a buy-stop filled without volume confirmation is sold,
          not held. Arming the placement waiver alone is not expressible.

          {b Default [false] = today's screen-time volume requirement,
             bit-identical} (R1): [require_breakout_volume] stays [true] and the
          eject runner short-circuits to [[]], so no golden moves. R2:
          axis-expressible as
          [((flag volume_confirm_at_fill) (values (true false)))]. R3: no
          default flip without a ledger ACCEPT.

          {b Faithfulness: BOOK-SUPPORTED.} Spine item 3 is preserved and
          relocated to the correct event — the check is not weakened, it is
          moved from a week the book never evaluates to the week the book
          defines it on.

          {b Future work (NOT built)}: plan §3-F5 amendment (iv) notes a later
          trader/investor variant of the unconfirmed branch
          ([eject | hold_with_stop_at_breakout]); v4 implements the eject only.
          Plan: [dev/plans/entry-ticket-async-v2-2026-08-10.md] §3-F5. *)
}
[@@deriving sexp]
(** Complete Weinstein strategy configuration. All parameters configurable for
    backtesting. *)

val default_dawn_max_flip_age_weeks : int
(** Default value for {!config.dawn_max_ma_flip_age_weeks} (78 weeks ~= 1.5y),
    the P1b-memo lagging dawn-label window. Exposed as the named no-op so the
    sexp default and the {!config} literal share one source of truth. *)

val default_entry_extension_max_pct : float
(** Default value for {!config.entry_extension_max_pct} ([2.0] percentage
    points), the #2404-unified live do-not-chase cap. Exposed as the named
    default so the sexp default and the {!config} literal share one source of
    truth. *)

val default_config : universe:string list -> index_symbol:string -> config
(** Build a default config with Weinstein book values. *)

val volume_confirm_at_fill_armed : config -> bool
(** [volume_confirm_at_fill_armed c] is [true] iff F5 is active:
    [c.volume_confirm_at_fill] AND the StopLimit family
    ([c.sim_entry_trigger_at_suggested] && [c.enable_sim_entry_stoplimit]).

    F5 only makes sense for a resting E-anchored ticket — that is the entry
    model whose fill week {i is} the breakout week. Under the default
    close-triggered entry the fill week and the screen week coincide, so
    relocating the check would be a pure loss of information.

    Single source of truth for both halves of the mechanism: the screener's
    placement waiver ([Stock_analysis.config.require_breakout_volume]) and the
    {!Volume_eject_runner} at-fill confirmation read this same predicate, so a
    ticket can never be placed without volume {i and} then held without the
    at-fill check. *)

val name : string
(** Strategy name, always ["Weinstein"]. *)
