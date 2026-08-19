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
  short_min_price : float; [@sexp.default 0.0]
      (** Minimum entry price for short candidates. Short candidates whose
          {!Screener.scored_candidate.suggested_entry} is strictly below this
          value are dropped before they join the entry candidate list.

          Default [0.0] = no gating: the gate short-circuits to the identity
          when [short_min_price <= 0.0], so the candidate list is bit-identical
          to the prior behaviour and every existing golden/baseline decodes and
          replays unchanged.

          Encodes the researched sub-$17 economic-margin floor on shorts
          ([dev/notes/long-short-margin-mechanics-2026-06-12.md]: sub-$17 shorts
          carry 83–362% maintenance margin) as a default-off, searchable
          {!Walk_forward.Variant_matrix} axis. Not wired into any default config
          or preset. *)
  short_borrow_min_dollar_adv : float; [@sexp.default 0.0]
      (** Borrow-availability floor for short candidates (margin M3a): the
          minimum trailing dollar-ADV a name must trade for its shares to be
          considered locatable-to-borrow. Short candidates whose dollar-ADV
          (computed from bars available at the screen date, no lookahead, over
          {!liquidity_config}'s [adv_lookback_days]) is strictly below this
          value are dropped as "no borrow available" before the entry walk; long
          candidates are never affected (borrow is a short-only concern).

          Default [0.0] = no gating: {!Short_borrow_gate.filter} short-circuits
          to the identity when [short_borrow_min_dollar_adv <= 0.0], so the
          candidate list is bit-identical to prior behaviour and every existing
          golden/baseline replays unchanged.

          We have no locate feed; dollar-ADV is the practical borrow-supply
          proxy per [dev/notes/long-short-margin-mechanics-2026-06-12.md] §4
          item 6 (a thinly-traded name is the canonical hard-to-borrow case). A
          default-off, searchable {!Walk_forward.Variant_matrix} axis; not wired
          into any default config or preset. Bar-cadence caveat (intraweek
          borrow recall / gap squeeze invisible; stress paths are M3b/M4) is
          documented in {!Short_borrow_gate}. *)
  suppress_warmup_trading : bool; [@sexp.default true]
      (** When [true] (the default), the backtest runner suppresses all new
          position entries (long and short) before the measurement [start_date],
          so the warmup window builds indicators/data only and the measurement
          window opens with an all-cash portfolio.

          Default [true] = measurement-correctness invariant (user directive
          2026-06-13: "measured window = window only"). A backtest's measured
          window must contain only that window's activity — a 210-day backtest
          has trades for 210 days, not 420. Warmup exists solely to form
          indicators; trading during it contaminates the measured return with
          pre-window activity and inherited positions. This is the canonical
          backtest semantics; in live/forward mode it is a no-op (there are no
          entries dated before "now", so the gate never fires).

          [false] = legacy "running start": the simulator runs from
          [start_date - warmup_days] and the strategy trades during the warmup
          window, so the backtest inherits a warmup-built portfolio at
          measurement start. Kept as an explicit escape hatch / searchable axis
          for measurement experiments and for reproducing pre-flip baselines.

          Motivated by PR #1549's A2 root-cause: warmup-window trading over the
          GFC bottom depleted a fold's portfolio to ~35% before its measurement
          window opened (see [Backtest.Fold_health]). Implemented runner-side by
          {!Backtest.Warmup_trade_gate}, which drops [CreateEntering]
          transitions dated before [start_date]; exits/stops/fills are never
          suppressed. Remains a searchable {!Walk_forward.Variant_matrix} axis.

          This is a measurement-semantics correction, not an alpha mechanism, so
          {!experiment-flag-discipline} R1/R3 (the ledger-ACCEPT gate for
          promoting alpha-mechanism defaults) do not apply. *)
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
  neutral_blocks_shorts : bool; [@sexp.default true]
      (** Short-side mirror of {!neutral_blocks_longs}. When [true] (the
          default), a macro-[Neutral] tape blocks new short entries exactly as a
          [Bullish] tape does — only a [Bearish] tape admits shorts. Setting
          [false] restores the historical macro gate (shorts admitted under both
          [Bearish] and [Neutral], blocked only under [Bullish]).

          This *tightens* the short side to Weinstein's confirmed-bear rule
          (weinstein-book-reference.md §Short-Selling Rules — short only in a
          confirmed bear market) — a faithful exit/entry-aggressiveness dial,
          not a spine change: the Stage-4-breakdown + negative-RS + weak-sector
          \+ volume short criteria and the macro gate itself are unaffected. It
          removes the [Neutral] chop tape (the 2020 V) where shorts are most
          likely squeezed.

          Default flipped [false] -> [true] on 2026-07-09 (user mandate) as a
          {b faithfulness} flip, not an alpha claim: shorting only a confirmed
          [Bearish] tape is strictly more Weinstein-faithful than also shorting
          a [Neutral] tape. Ledger ACCEPT:
          [2026-06-22-neutral-blocks-shorts-wfcv] (helpful-or-inert on the WF-CV
          cell; the companion grid [2026-06-22-neutral-blocks-shorts-grid]
          showed no edge flip). The deep-cell re-attribution (2026-07-09,
          [dev/notes/p1a-deep-short-screens-364-2026-07-09.md]) found the gate
          blocked exactly one [Neutral]-tape short in 11 deep years (a loser) so
          the true edge cost is ~0; blocked [Neutral]-tape shorts are the
          squeeze-trap class.

          Wired by threading into [screening_config.neutral_blocks_shorts] at
          screen time, so the flag is a single-component [Variant_matrix] flag
          axis ([((flag neutral_blocks_shorts) (values (true false)))]). *)
  enable_slow_grind_short_gate : bool; [@sexp.default false]
      (** Faithful-short decline-character gate (default-off). When [true],
          shorts are admitted only when the current primary-index decline is a
          slow grind ([Decline_character.Slow_grind]) — fast-V crashes and
          non-declines are excluded. Default [false] is a no-op (bit-identical
          to baseline; the decline classification is not even consumed).

          Weinstein shorts a sustained distribution bear, not a fast V-crash
          that snaps back (weinstein-book-reference.md §Short-Selling Rules).
          The slow-grind bool is classified at screen time from the current
          macro result + index bars via [Decline_character] /
          [Decline_character_wiring] (which live in this lib, so
          [weinstein.screener] stays macro-agnostic) and threaded into
          [Screener.screen_with_cooldown ~decline_is_slow_grind] alongside
          [screening_config.enable_slow_grind_short_gate]. The classification
          uses the *current* cycle's macro + bars — lookahead-free for an entry
          gate, since entries already gate on the current [macro_trend] (the
          prior-cycle decline-character ref is for the stop, not entries).

          Single-component [Variant_matrix] flag axis
          ([((flag enable_slow_grind_short_gate) (values (true false)))]).
          Default-off until an experiment-ledger ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md]). *)
  fast_v_arm_on_rate_alone : bool; [@sexp.default false]
      (** Arming-speed dial for the fast-crash absolute stop
          ([stops_config.catastrophic_stop_pct]); default [false] is a no-op
          (bit-identical to baseline — the decline classifier behaves exactly as
          before). When [true], the primary-index [Decline_character.Fast_v]
          classification may arm on the {b rate of decline alone}, without
          waiting for the weekly MA to roll over and price to fall below it.

          Motivation: in a fast V-crash (2020), the structural gap-down stop has
          already exited every long before the weekly MA rolls over, so the
          [Fast_v]-gated [catastrophic_stop_pct] absolute stop never fires — the
          binding constraint is arming {b latency}, not stop width. This flag
          drops the falling-MA precondition for the fast-V path only (the
          slow-grind path is untouched, since it presupposes a decline already
          in progress). It is threaded into
          [Decline_character.fast_v_ignores_ma_filter] at the two classify sites
          ([Decline_character_wiring.update_ref], the load-bearing stop-arming
          seam, and the [enable_slow_grind_short_gate] screen-time classify,
          inert here since it maps [Fast_v] -> not-slow-grind) so one config
          builds the classifier config.

          {b Faithfulness}: a fast crash gives no Advance-Decline breadth lead
          and falls before the weekly MA can confirm
          (weinstein-book-reference.md §Macro / Ch. 8 distribution-lead
          doctrine). This changes no buy/sell rule — only {b when} the absolute
          tail-RISK-insurance stop arms — so it is the sanctioned
          tail-RISK-insurance exception
          ([.claude/rules/weinstein-faithful-core.md]); the spine is intact.

          Single-component [Variant_matrix] flag axis
          ([((flag fast_v_arm_on_rate_alone) (values (true false)))]).
          Default-off until an experiment-ledger ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md]). *)
  fast_v_min_rate_pct : float; [@sexp.default 0.08]
      (** Fast-V arming rate threshold: the minimum trailing rate-of-decline
          drawdown (positive fraction over [rate_lookback_weeks]) at which the
          primary index is classified [Decline_character.Fast_v]. Threaded into
          [Decline_character.fast_v_min_rate_pct] at the two classify sites via
          {!Decline_character_wiring.classifier_config}. Default [0.08] equals
          [Decline_character.default_config.fast_v_min_rate_pct], so it is a
          no-op (bit-identical classification to the pre-flag behaviour).

          Whipsaw-suppression dial: in choppy corrections (e.g. 2010/2011) the
          [fast_v_arm_on_rate_alone] path arms the fast-crash absolute stop on
          rate alone, and a low rate threshold lets shallow rallies-into-decline
          re-arm/dis-arm repeatedly. Raising the threshold (e.g. to 0.16)
          requires a steeper drawdown before [Fast_v] is declared, suppressing
          that whipsaw — at the cost of arming later in a genuine crash. A
          higher value never widens the [Fast_v] band, so the spine is untouched
          (it changes only when the tail-RISK-insurance stop arms, never a
          buy/sell rule — see [.claude/rules/weinstein-faithful-core.md]).

          Single-component [Variant_matrix] float axis (e.g.
          [((flag fast_v_min_rate_pct) (values (0.08 0.12 0.16)))]). Default
          no-op until an experiment-ledger ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md]). *)
  reject_declining_ma_long_entry : bool; [@sexp.default false]
      (** Long-entry faithfulness gate (default-off): when [true], drop any long
          candidate whose stage-classification MA direction is
          [Weinstein_types.Declining] at entry. Weinstein Stage 2 is defined as
          price above a {b rising} 30-week MA; the classifier nonetheless tags a
          minority of breakouts [Stage2] while the MA is still declining — these
          are counter-trend bounces in a Stage-4 downtrend (e.g. dead-cat
          bounces under a prior top), which the broad top-3000 audit shows win
          only ~13% vs ~34% for rising-MA entries (n=30, avg P&L −0.1% vs
          +2.6%). Default [false] preserves all baselines bit-for-bit (no
          candidate is dropped). Shorts are unaffected — a declining MA is
          correct for a Stage-4 short.

          This keeps the strategy {b spine} intact (it {e tightens} the
          Stage-2-only buy rule toward the book's rising-MA definition, removing
          misclassified entries rather than adding any new mechanism). Wired as
          a real config field, so it is a single-component [Variant_matrix] flag
          axis
          ([((flag reject_declining_ma_long_entry) (values (true false)))]).
          Evidence: the 2026-06-27 drawdown-driver chart review + entry-quality
          quantification (dev/charts/, the declining-MA bucket). Default-off
          until an experiment-ledger ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md]). *)
  enable_late_stage2_stop_tighten : bool; [@sexp.default false]
      (** Held-position risk dial (default-off): when [true], the
          {!Late_stage2_stop_runner} tightens the trailing stop of every held
          long whose current stage is [Stage2 { late = true }] (MA-slope
          deceleration — the earliest top-warning the classifier produces, today
          discarded for held positions). Default [false] preserves all existing
          baselines: the runner is never invoked, so behaviour is bit-identical
          to today regardless of [late_stage2_stop_buffer_pct].

          This is the {b exit-aggressiveness} dial (the trader preset — "get out
          as the Stage-3 top starts forming"), a faithful adaptation of
          [docs/design/weinstein-book-reference.md] §Stage 3 detail (Ch. 2):
          "Traders: exit with profits. Investors: sell half, protect remaining
          half with tight sell-stop below support." The strategy {b spine} is
          untouched — stage classification, the Stage-2-only buy rule,
          breakout+volume entry, the macro/sector gate, and relative strength
          are all unaffected; only the trailing stop of an existing held
          position moves, and it is only ever raised (never lowered).

          Wired as a real config field, so the flag is a single-component
          [Variant_matrix] flag axis
          ([((flag enable_late_stage2_stop_tighten) (values (true false)))]).

          Motivation + cross-regime lead-time evidence:
          [dev/notes/stage-lifecycle-pivot-diagnosis-2026-06-03.md] (the [late]
          flag fired weeks-to-months before 6 of 7 major tops, while the Stage-4
          exit lagged each top by 5-29 weeks). Default-off until a
          confirmation-grid ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md] +
          [.claude/rules/promotion-confirmation.md]). *)
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
          ({!Macro_bearish_trim_runner}, plan
          [dev/plans/macro-bearish-exposure-trim-2026-06-06.md]). When [true]
          and the macro tape is Bearish on a screening (Friday) day, held long
          exposure is capped (see [macro_bearish_max_long_exposure_pct]) and the
          excess is trimmed weakest-RS-first. Default [false] preserves all
          existing baselines — the trim pass short-circuits to [[]] before any
          work, so the disabled path is byte-identical to the pre-feature
          strategy. Searchable as a [Variant_matrix] flag axis
          ([((flag enable_macro_bearish_exposure_trim) (values (true false)))]).
      *)
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
          The runner threads this into the simulator's
          [Trading_simulation.Stale_hold.config.stale_exit_after_days].

          {b Default flipped [None] -> [Some 5] on 2026-07-10 (user mandate)} as
          a REALISM / faithfulness basis change, {b not} an alpha promotion —
          same class as the warmup 210->364 re-pin
          ([dev/notes/warmup-364-repin-2026-07-08.md]) and the total-return
          comparator rule. The simulator must not hold ghosts: without the
          force-exit a delisted name is carried open at its last close forever
          (IN1 marked at its 2005 close for 20 years inside NAV; 5 zombie
          positions in the deep top-3000 2000-2026 run — issue #1484 / flag
          #1487). Set [None] to restore the pre-flip no-op (detector still
          records stale holds; no force-exit) — the pre-flip behaviour, kept as
          a searchable [Variant_matrix] flag axis
          ([((flag stale_exit_after_days) (values (() (5))))]). Ledger:
          [2026-07-10-realism-defaults-flip]. *)
  short_sleeve_fraction : float; [@sexp.default 0.0]
      (** Fraction of portfolio value reserved as a dedicated short-only cash
          budget in the per-Friday entry walk
          ({!Weinstein_strategy.entries_from_candidates}).

          {b Motivation} (memory [project_short_funnel_crowded_out],
          2026-06-19). Over a 28y long-short backtest the short cascade
          {e offers} 1,662 candidate-slots but only 37 {e enter} (2%), with zero
          short fills rejected. Shorts are not rare or bad — they are
          {b crowded out at the entry walk}: the screener appends shorts after
          longs ([buy_candidates @ short_candidates]) and a single shared
          [remaining_cash] ref is consumed by the longs first, so the walk
          rarely reaches the appended shorts. This reserves a separate cash
          budget for shorts, walked independently of the long book, so shorts
          get capital regardless of long demand.

          {b Semantics.}
          - [<= 0.0] (default): {b bit-identical to baseline} — one combined
            entry walk over [buy_candidates @ short_candidates] against a single
            [remaining_cash] seeded at [portfolio.cash]. Every existing
            golden/baseline replays unchanged (experiment-flag-discipline R1).
          - [> 0.0]: the per-Friday cash budget is partitioned. A short-only
            budget [short_sleeve_fraction *. portfolio_value] is reserved; long
            candidates walk against [max 0 (portfolio.cash -. short_budget)] and
            short candidates walk against the reserved short budget — two
            independent [remaining_cash] refs, so longs can no longer starve
            shorts. The {!Portfolio_risk} short-notional cap
            ([max_short_notional_fraction]) and the shared per-sector exposure
            accumulator still apply across both walks; the kept transitions are
            re-emitted in the order the candidates {e entered} the walk, so
            audit ordering matches the single-walk path. That is screener order
            (score-desc) under the defaults, and post-demotion order once
            [stop_width_mode = Demote_over_max] has already permuted the list —
            the sleeve restores whichever order it was handed, it does not
            recover the screener's.

          {b Faithfulness} (W1/W2, [.claude/rules/weinstein-faithful-core.md]).
          This is a {b portfolio-allocation / structural-diversification} dial —
          Weinstein runs long and short simultaneously in bear markets
          ([docs/design/weinstein-book-reference.md] §Short Selling). The spine
          is untouched: Stage-4-only short entry, the relative-strength hard
          gate, and the Ch.11 short cascade are all unaffected; only the
          {e capital available} to the already-screened short candidates
          changes. Searchable as a [Variant_matrix] axis
          ([((flag short_sleeve_fraction) (values (0.0 0.1 0.2 0.3)))]).
          Default-off until an experiment-ledger ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md] +
          [.claude/rules/promotion-confirmation.md]). *)
  extension_stop_config : Weinstein_stops.Extension_stop.config;
      [@sexp.default Weinstein_stops.Extension_stop.default_config]
      (** Extension-stop parameters — a wide tail-INSURANCE trail for a held
          long that has run far above its 30-week WMA (a blow-off / parabolic
          advance). Wired through {!Extension_stop_runner} as a special-exit
          channel that emits a [TriggerExit] once the weekly close reached
          [trigger_ratio ×] the WMA30 and has since fallen [trail_pct] below the
          post-trigger running peak weekly close (weekly-close semantics, L3).

          {b Tail-insurance, not an alpha axis.} A catastrophic-stop-class dial
          (same class as [stops_config.catastrophic_stop_pct], #1695), NOT a
          performance knob. Extension events are rare (~0.6-1% of episodes reach
          [2.0×] WMA30 over a quarter-century), so a walk-forward CV on this
          axis is structurally powerless; its acceptance basis is the left-tail
          / dispersion / event-level audit (armed-vs-off record runs + the
          [analysis/scripts/extension_screen] counterfactual), {b never} fold
          Sharpe. User-directed insurance build (2026-07-11): "no way we
          actually sit through 140→70, even if that would take a manual
          intervention" — an encoded, tested rule beats an untested panic exit
          ([dev/backtest/extension-screen-2026-07-11/FINDINGS.md] §"What
          survives").

          {b Default-off.} Default
          {!Weinstein_stops.Extension_stop.default_config}
          ([trigger_ratio = 0.0], [trail_pct = 0.0]) DISABLES the mechanism:
          {!Extension_stop_runner.update} returns [[]], so every existing
          golden/baseline replays bit-identically
          ([.claude/rules/experiment-flag-discipline.md] R1). Set e.g.
          [((trigger_ratio 2.0) (trail_pct 0.25))] to arm it.

          {b Tighten-only (L2).} The runner only ever ADDS an exit trigger and
          never lowers or replaces the structural trailing stop; a position
          already exiting this tick via any other channel is skipped, so an
          earlier structural exit always wins.

          {b Faithfulness (W2).} A faithful {b trader exit-aggressiveness} dial
          — on a parabolic advance far above the MA a trader takes profits /
          swing-sells rather than waiting for the MA violation
          ([docs/design/weinstein-book-reference.md] §5.3 "Trailing Stop —
          Trader Method"; §Stage 3 detail Ch. 2 "Traders: exit with profits").
          The spine is untouched. Screen evidence pins the width:
          [trail_pct 0.25] survives the on-ramp shakeouts (the AXTI April 2025
          dip, the January chop) and still banks the collapse; tighter
          [0.10-0.20] trails are on-ramp killers.

          Searchable as a nested {!Walk_forward.Variant_matrix} axis, e.g.
          [((key (extension_stop_config trigger_ratio)) (values (2.0 2.25)))].
          Default-off until an experiment-ledger ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md]). *)
  liquidity_config : Liquidity_config.t;
      [@sexp.default Liquidity_config.default_config]
      (** Liquidity-realism overlay parameters — the held-position liquidity
          degradation exit ({!Liquidity_exit_runner}) and the entry liquidity
          gate ({!Liquidity_gate}).

          {b Motivation.} A deep broad-universe long-short backtest produced a
          −48% single-day NAV crash traced to ONE short: a delisted micro-cap
          (ELCO) trading ~2 shares/day whose stale ~$38 high-tick tripped the
          short stop's worst-case cover fill. Root cause = trading an
          illiquid/degraded name, detectable in real time from its collapsing
          dollar-ADV. The realistic case is a name we {e held} whose liquidity
          degraded over time (large-cap → thinly-traded micro-cap / delisting);
          the overlay detects that from data at decision time and exits before
          the name becomes untradeable.

          {b Semantics.} Default [Liquidity_config.default_config]
          ([min_entry_dollar_adv = 1_000_000.0] since the 2026-07-10 realism
          flip, [min_hold_dollar_adv = 0.0]): the entry gate drops sub-$1M-ADV
          candidates so the simulator never fills entries reality could not
          fill; the held-position degradation exit still never fires. Set
          [min_entry_dollar_adv = 0.0] to restore the pre-flip no-op (bit-
          identical replay). See {!Liquidity_config} for the full flip rationale
          + estimand caveat (ledger [2026-07-10-realism-defaults-flip]).

          {b Faithfulness} (W1/W2, [.claude/rules/weinstein-faithful-core.md]).
          A risk/realism dial — Weinstein would never hold a name he could not
          trade out of. The spine is untouched (stage framework, Stage-2 entry,
          volume-confirmed breakout all unchanged); only
          tradeability-eligibility is narrowed. Each threshold is searchable as
          a [Variant_matrix] axis, e.g.
          [((key (liquidity_config min_hold_dollar_adv)) (values (0.0 1e6)))].
          Default-off until an experiment-ledger ACCEPT. *)
  max_long_exposure_pct_entry : float; [@sexp.default 0.0]
      (** Cap on aggregate NEW long-entry notional as a fraction of
          {e current portfolio value}, applied at the Friday entry walk
          ({!Weinstein_strategy.entries_from_candidates}).
          Entry-price-denominated committed-at-entry notional across held
          [Holding] longs plus the candidates funded this walk may not exceed
          [max_long_exposure_pct_entry * portfolio_value].

          {b The working replacement for the dead
             [Portfolio_risk.max_long_exposure_pct].} Per
          [memory/project_envelope_knobs_dead] (the envelope knobs were unwired
          when [Portfolio_risk.check_limits] was deleted 2026-07-09),
          [Portfolio_risk.max_long_exposure_pct] has no production consumer — a
          scenario override of it does nothing. The 2026-07-13 Run-E long-short
          matrix showed the long book {e levering on short proceeds} (marked
          long exposure > NAV in 269 sampled weeks, peak 158%) with that dead
          knob set to 0.70 and ignored. This field is the honest, live-path cap:
          it is consumed at the one seam that actually gates entry funding (the
          entry-walk long-notional accumulator), mirroring
          {!check_short_notional_cap}'s machinery exactly.

          {b Basis — entry-price-denominated notional, NOT marked value.} The
          cap counts [shares * entry_price] committed at entry, matching the
          short cap ([max_short_notional_fraction]). Marked exposure exceeding
          100% of NAV purely from {e unrealized appreciation} of held winners is
          legitimate (it is not leverage) and must NOT trigger the cap; only
          entries funded beyond the cap {e at entry time} are the Run-E artifact
          this gate targets. Entry-denominated also keeps the long and short
          caps symmetric and avoids threading a [get_price] mark into the walk.

          {b Margin convention for long-short runs.} Short proceeds credit cash
          (existing behaviour, unchanged); NEW long entries are then capped at
          [max_long_exposure_pct_entry * portfolio_value] of committed-at-entry
          notional — i.e. shorts can fund longs, but only up to this cap. This
          is THE margin convention for long-short backtests: it bounds how far
          the long book may lever on short proceeds.

          {b Scope — NEW entries only.} The cap narrows only new long entry
          funding. Exits, covers, stop orders, and force-liquidations do not
          flow through the entry walk and are structurally unaffected, so the
          cap can never block an exit (the #1553 exit-fill-reject lesson).

          {b Semantics.}
          - [<= 0.0] (default [0.0]): {b EXACT no-op} — the long-notional cap is
            [Float.infinity], so every long candidate passes the gate and every
            existing long-only golden/baseline replays bit-identically
            (experiment-flag-discipline R1).
          - [> 0.0]: a long candidate whose entry notional would push the
            running long total past [pct * portfolio_value] is rejected as a
            [Long_exposure_cap] skip; short candidates are unaffected.

          {b Faithfulness} (W1/W2, [.claude/rules/weinstein-faithful-core.md]).
          A portfolio-risk / exposure dial that {e tightens} deployment without
          touching any spine item (stage classification, Stage-2-only buys,
          breakout+volume entry, stops, macro/sector gate all unchanged).
          Searchable as a single-component [Variant_matrix] axis
          ([((max_long_exposure_pct_entry) (values (0.0 0.7 1.0)))]).
          Default-off until an experiment-ledger ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md] +
          [.claude/rules/promotion-confirmation.md]). *)
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
            buying-power term is [Float.infinity], so it imposes no explicit
            equity ceiling and the combined ceiling is governed solely by
            {!max_long_exposure_pct_entry} (also disabled at its default). Every
            existing golden/baseline replays bit-identically
            (experiment-flag-discipline R1). The reachable [portfolio_value]
            ceiling of a strict cash account is the explicit
            [max_long_exposure_pct_entry = 1.0] opt-in, NOT this default: the
            pre-M1 default had no explicit long ceiling (new long funding was
            bounded only by the implicit available-cash gate), and imposing an
            [equity] ceiling by default would newly cap the legitimate
            held-winner-appreciation-above-NAV and short-proceeds cases #1965
            deliberately leaves to that opt-in.
          - [0.0 < req < 1.0]: leverage opted in — the buying-power ceiling
            rises to [portfolio_value /. req] (e.g. [0.5] →
            [2.0 *. portfolio_value]).

          {b Scope (M1a).} This field sets the ceiling only. The entry-walk
          cash-gate relaxation that actually funds longs beyond available cash
          (creating a debit balance) and the per-tick interest accrual are M1b;
          until then a fractional requirement is inert (the available-cash gate
          binds first). See {!Long_buying_power} and
          [dev/plans/levered-longshort-margin-realism-2026-07-14.md] §M1.

          {b R2 searchability.} A real config field resolved by
          [Overlay_validator.apply_overrides]; expressible as a single-component
          [Variant_matrix] float axis
          ([((initial_long_margin_req) (values (1.0 0.75 0.5)))]). Default-off
          until an experiment-ledger ACCEPT. *)
  long_margin_rate_annual_pct : float; [@sexp.default 0.0]
      (** Annualized interest rate charged on a long-margin debit balance
          (borrowed cash funding the long book beyond equity), the
          priced-leverage companion to
          [margin_config.short_borrow_fee_annual_pct] (levered long-short
          realism, M1a). Accrued per trading day as
          [debit_balance *. annual /. 252] via
          {!Long_buying_power.long_margin_interest_charge}, the same 252
          day-count the short borrow fee uses.

          {b Semantics.}
          - [0.0] (default): {b EXACT no-op} — no interest accrues on any
            balance (experiment-flag-discipline R1). Prices old-Run-E "free
            leverage" as free, exactly as pre-M1.
          - [> 0.0]: a positive debit balance carries this financing cost, so a
            levered long book pays for the leverage.

          {b Scope (M1a).} This field defines the {e priced-debit convention};
          the per-tick simulator accrual and the cash-gate relaxation that
          creates a nonzero debit balance are M1b. Until then the charge is
          always [0.0] (no debit is ever created). See {!Long_buying_power}.

          {b R2 searchability.} A real config field; expressible as a
          single-component [Variant_matrix] float axis
          ([((long_margin_rate_annual_pct) (values (0.0 0.08 0.10)))]).
          Default-off until an experiment-ledger ACCEPT. *)
  maintenance_long_pct : float; [@sexp.default 0.0]
      (** Long-side maintenance-margin requirement — the marked-basis loan-call
          threshold for a levered long book (levered long-short realism, M2).
          When the book's equity erodes so that
          [equity /. marked_long_exposure < maintenance_long_pct] on a weekly
          (Friday) close, {!Trading_simulation.Long_maintenance} force-reduces
          held longs — weakest first (ascending unrealized return since entry) —
          until the ratio is restored above
          [maintenance_long_pct *. (1 + buffer)], then stops. Here
          [equity = current_cash - long_margin_debit + marked_long_exposure] and
          [marked_long_exposure] sums [quantity *. close] over held longs priced
          today (margin M1b-2 [equity_cash]). Each forced sale's proceeds pay
          down [long_margin_debit] first, which is what lifts the ratio.

          {b Semantics.}
          - [0.0] (default): {b EXACT no-op} — a cash account has no maintenance
            requirement, so the reduce never fires and every existing
            golden/baseline replays bit-identically (experiment-flag-discipline
            R1). An unlevered book (no debit) never fires even at a positive
            value, since [equity >= marked_long_exposure] keeps the ratio
            [>= 1.0].
          - [> 0.0] (e.g. [0.25]): a levered long book whose equity falls below
            [maintenance_long_pct] of its marked long exposure is deleveraged
            incrementally on the next weekly close. Only leverage
            ([long_margin_debit > 0]) can breach the ratio.

          {b Scope — the long book.} The numerator is the long-account equity
          (cash net of the long debit plus long market value); the short book's
          marked P&L is excluded — it has its own maintenance surface
          ([margin_config.maintenance_margin_pct] via
          {!Trading_portfolio.Portfolio_margin.check_maintenance_margin}). The
          reduce closes whole weakest longs (never the whole book unless equity
          is fully wiped) and is scoped to a forced sale — it can never block an
          exit (the #1553 lesson). {b Cadence caveat:} daily-close marks cannot
          see an intraweek gap-through-maintenance move; those gap paths are
          M3/M4 stress-path territory, documented in
          {!Trading_simulation.Long_maintenance}.

          {b R2 searchability.} A real config field resolved by
          [Overlay_validator.apply_overrides]; expressible as a single-component
          [Variant_matrix] float axis
          ([((maintenance_long_pct) (values (0.0 0.25 0.35)))]). Default-off
          until an experiment-ledger ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md] +
          [.claude/rules/promotion-confirmation.md]). *)
  resistance_min_history_bars : int; [@sexp.default 0]
      (** Overhead-resistance history floor threaded into
          [Stock_analysis.config.resistance.min_history_bars] (and, because
          [Stock_analysis] reuses the same [Resistance.config] record for the
          short-side support mirror, into the support side too — see
          {!Stock_analysis} [_support_result]). When a symbol has fewer than
          this many bars of history the resistance/support mapper classifies the
          breakout as [Weinstein_types.Insufficient_history] rather than risk a
          false [Virgin_territory] (or any other) grade off a starved window (PR
          #1941).

          {b Semantics.}
          - [0] (default): {b bit-identical to baseline} — the
            [min_history_bars] check is disabled exactly as
            {!Resistance.default_config} leaves it, so the built
            [Stock_analysis.config] is byte-identical to
            {!Stock_analysis.default_config} and every existing golden/baseline
            replays unchanged (experiment-flag-discipline R1).
          - [> 0] (typically [520], the resistance spec's full virgin-lookback):
            a symbol with fewer than this many bars produces the
            [Insufficient_history] grade at screen time instead of a
            resistance/support label off too little data.

          {b R2 searchability.} Wired as a real config field so it resolves
          through [Overlay_validator.apply_overrides] and is expressible as a
          single-component [Variant_matrix] int axis
          ([((resistance_min_history_bars) (values (0 520)))]) and in scenario
          [config_overrides] ([((resistance_min_history_bars 520))]). Threaded
          into the per-screen [Stock_analysis.config] by
          [_stock_analysis_config_for] (weinstein_strategy_screening.ml).

          {b Faithfulness} (W1/W2, [.claude/rules/weinstein-faithful-core.md]).
          A data-hygiene / realism dial — it prevents a false
          overhead-resistance read off a starved window, {e tightening} the
          breakout-above-resistance entry criterion toward the book's
          chart-reading intent rather than adding any new mechanism. The spine
          is untouched (stage framework, the Stage-2-only buy rule,
          breakout+volume entry, the macro/sector gate, stops are all
          unchanged). Default-off until an experiment-ledger ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md]). *)
  resistance_lookback_bars : int; [@sexp.default 0]
      (** Resistance-specific weekly-history depth: when [> 0], the Phase-2
          screen fetches a {e second, deeper} weekly view of this many bars for
          the resistance/support callbacks only — stage / RS / volume / breakout
          detection keep reading the standard [lookback_bars] view, so screening
          decisions other than the resistance grade are unaffected.

          {b Why} (armed-run matrix 2026-07-13, Run C): backtest panels carry
          only ~[lookback_bars] weekly bars, so the resistance mapper's 520-bar
          virgin lookback claims [Virgin_territory] off a starved window (the
          CWST-class false-virgin defect, validator V7). The
          [resistance_min_history_bars] label floor is NOT the fix — arming it
          marks every name [Insufficient_history] and deletes the signal
          wholesale (Run C halved the return).
          {b Feeding real history is the fix}: this field widens the data the
          mapper sees instead of suppressing its output.

          {b Semantics.}
          - [0] (default): {b bit-identical to baseline} — resistance callbacks
            are built from the same weekly view as today
            (experiment-flag-discipline R1); every existing golden/baseline
            replays unchanged.
          - [> 0] (typically [520] = the virgin-lookback spec): resistance and
            support callbacks read a [resistance_lookback_bars]-deep weekly
            view. Values [<= lookback_bars] are harmless but pointless (the
            standard view already covers them).

          {b R2 searchability.} Real config field → resolves through
          [Overlay_validator.apply_overrides]; expressible as a [Variant_matrix]
          int axis ([((resistance_lookback_bars) (values (0 520)))]) and in
          scenario [config_overrides] ([((resistance_lookback_bars 520))]).

          {b Faithfulness} (W1/W2). Pure data-hygiene: gives the book's
          chart-reading its intended ~10-year window instead of a truncated one.
          No spine item is touched. Default-off until an experiment-ledger
          ACCEPT. *)
  overhead_supply : Resistance_supply.config option; [@sexp.default None]
      (** Continuous overhead-supply score (resistance-v2 PR-D). When
          [Some cfg], the strategy copies [cfg] into the per-screen
          [Stock_analysis.config] ([overhead_supply]); the snapshot-backed panel
          adapter reads the precomputed warehouse sketch columns and populates
          [Stock_analysis.t.supply], which the screener's [w_overhead_supply]
          scoring weight then consumes in place of the binary virgin/clean
          grade.

          {b Default flipped [None] -> [Some Resistance_supply.default_config]
             on 2026-07-23} by the BUNDLE promotion (user-approved, R3): part of
          the three-default bundle
          [overhead_supply armed + w_overhead_supply=30 +
           virgin_crossing_readmission], with [Resistance_supply.default_config]
          floors also zeroed. Evidence: mechanism ACCEPT (ledger
          [2026-07-17-resistance-supply-confirmation-grid], 3/3) + bundle
          studies (ledger [2026-07-20-bundle-promotion-studies]: sp500 CONFIRM,
          rolling-start REPAIRS the recovery-window tail) + lever-f REJECT
          (ledger [2026-07-22-leverf-age-band-surface], age axis closed). See
          [dev/notes/resistance-supply-promotion-memo-2026-07-19.md].

          {b Semantics.}
          - [Some cfg] (new default): the continuous score runs for survivors
            whose panel carries the sketch columns; it pairs with the armed
            screener weight [Screener.scoring_weights.w_overhead_supply]. The
            live CSV report path has no warehouse sketch
            ([Stock_analysis.callbacks_from_bars] sets
            [get_sketch = fun () -> None]), so [Stock_analysis.t.supply] is
            [None] there and the screener degrades gracefully to the
            bit-identical v1 binary grade (the live weekly-review generator
            computes a real sketch from the bar history, so its displayed grade
            switches to the v2 score — the score/display split, PR-live-path
            #1989).
          - [None] (the [[@sexp.default None]] deserialization fallback):
            {b bit-identical to baseline} — [Stock_analysis.t.supply] is always
            [None], the screener falls back to the binary grade, no sketch reads
            occur. This is the value a config sexp written {e before} the
            promotion (omitting the field) parses to, so an old saved config
            stays disarmed; it is also the explicit disarm escape hatch.

          {b R2 searchability.} Real config field → resolves through
          [Overlay_validator.apply_overrides]; expressible as an option axis
          over the [Resistance_supply.config] sub-fields.

          {b Faithfulness} (W1/W2). Ranking weight only, not an entry gate — the
          Stage-2-only buy rule, breakout+volume entry, macro/sector gate and
          stops are untouched. *)
  virgin_crossing_readmission : bool; [@sexp.default false]
      (** resistance-v2 lever (a): virgin-crossing re-admission. When [true],
          the strategy sets [Stock_analysis.config.virgin_crossing_readmission],
          so a Stage-2 survivor that has crossed into virgin territory (above
          its 520-week max high) on volume is re-admitted by
          [Stock_analysis.is_breakout_candidate] even when it is past the
          [early_stage2_max_weeks] early-Stage-2 window. This restores access to
          the crash-recovery "redeemed monster" cohort the [overhead_supply]
          penalty correctly demotes at their supplied breakout but which becomes
          genuinely virgin later (the AXTI post-mortem,
          [dev/notes/resistance-supply-divergence-forensic-2026-07-17.md]).

          {b Default flipped [false] -> [true] on 2026-07-23} by the BUNDLE
          promotion (user-approved, R3) — see [overhead_supply] for the full
          evidence chain. This is the lever that repairs bare-w30's
          recovery-window left tail (the 2000/2008/2010 rolling starts) in the
          bundle studies.

          {b Semantics.}
          - [true] (new default): a stale Stage-2 survivor is re-admitted iff
            its warehouse sketch is present AND the breakout is into new high
            ground ([Resistance_supply.is_virgin] or [is_clear_of_supply]);
            sketch absent → no re-admission (no fabrication). Independent of
            [overhead_supply] — the virgin test needs only the sketch, not the
            scoring config.
          - [false] (the [[@sexp.default false]] deserialization fallback):
            {b bit-identical to baseline} —
            [Stock_analysis.t.virgin_readmission] is always [false] and the
            early-Stage-2 staleness rejection is unchanged. A config sexp
            written {e before} the lever (omitting the field) parses to [false]
            so an old saved config keeps the staleness cut; also the disarm
            escape hatch.

          {b R2 searchability.} Real top-level [bool] field → resolves through
          [Overlay_validator.apply_overrides]; expressible as a [Variant_matrix]
          [((flag virgin_crossing_readmission) (values (true false)))] axis.

          {b Faithfulness} (W1/W2). This is the book's "new high ground"
          breakout — a fresh breakout into virgin territory with volume is a
          valid Stage-2 entry regardless of how long ago the Stage-2 transition
          happened (weinstein-book-reference.md §Buy Criteria). Spine intact:
          still Stage-2-only, still breakout + volume + RS gates, macro/sector
          gates and stops untouched — it only widens which Stage-2 names clear
          the early-window staleness cut. *)
  dawn_leverage_enabled : bool; [@sexp.default false]
      (** Master switch for the regime-conditional long-leverage "dawn"
          mechanism ({!Leverage_dawn}, P1b memo
          [dev/notes/regime-dependency-evaluation-2026-07-24.md] §1/§3 +
          [dev/notes/margin-m4-validation-2026-07-23.md] §Addendum, user
          green-lit 2026-07-24). When [true] AND the primary index is in a young
          post-bear "dawn" (its weekly MA is currently rising and the most
          recent negative->positive slope flip happened no more than
          [dawn_max_ma_flip_age_weeks] weeks ago), that Friday's entry walk
          sizes against the levered [dawn_initial_long_margin_req]; on a
          non-dawn week the entry walk is {b raised} to a cash account — i.e.
          the long book runs levered only in label-visible young uptrends,
          cash-account otherwise.

          {b Permissive-funding / gated-sizing design (B1 fix, 2026-07-24).} The
          entry walk only {e sizes} the position; the {e funding} authority is
          the simulator, which is constructed once at the {e base}
          [initial_long_margin_req] ([Backtest.Panel_runner] ->
          [Simulator.create_deps]) and cannot track the per-Friday dawn value.
          So an armed cell must set the base [initial_long_margin_req] to a
          value at least as permissive (numerically [<=]) as
          [dawn_initial_long_margin_req] — the simulator then funds any levered
          fill into [long_margin_debit] (priced by [long_margin_rate_annual_pct]
          \+ [maintenance_long_pct]), while the entry-walk requirement decides
          {e when} to request leverage. {!Leverage_dawn.validate} enforces the
          [base <= dawn] constraint. See {!Leverage_dawn.dawn_effective_config}.

          {b Default [false] = EXACT no-op} (experiment-flag-discipline R1). The
          wiring ({!Leverage_dawn.dawn_effective_config}) short-circuits to the
          unchanged config before any bar fetch or signal computation when this
          flag is [false], so merging the mechanism changes no backtest result
          and every existing golden/baseline replays bit-identically (a scenario
          is bit-identical with the field absent and with it explicitly
          [false]).

          {b Faithfulness} (W1/W2, [.claude/rules/weinstein-faithful-core.md]).
          A {b deployment-intensity dial} — how much buying power the long
          engine deploys, conditioned on a {b trailing} (never forward-looking)
          regime label off the weekly MA (the book's central instrument). The
          spine is untouched: stage classification, the Stage-2-only buy rule,
          breakout+volume entry, stops, and the macro/sector gate are all
          unchanged. Not reversal timing — the MA-flip-age signal is lagging by
          construction (it errs late, never early). Weinstein deploys
          aggressively in confirmed young uptrends and defensively otherwise.

          {b Margin-armed convention.} Dawn leverage runs margin-armed
          ([margin_config.enabled = true]) so borrowed dollars are priced and
          maintenance applies; {!Leverage_dawn.validate} (called at
          {!Weinstein_strategy.make}) raises when [dawn_leverage_enabled = true]
          with [margin_config] disarmed or [dawn_initial_long_margin_req]
          outside the interval 0.0 < req <= 1.0.

          {b R2 searchability.} A real config field resolved by
          [Overlay_validator.apply_overrides]; expressible as a single-component
          [Variant_matrix] flag axis
          ([((flag dawn_leverage_enabled) (values (true false)))]). Default-off
          until a promotion-confirmation grid ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md] +
          [.claude/rules/promotion-confirmation.md]). *)
  dawn_initial_long_margin_req : float; [@sexp.default 1.0]
      (** The long-side initial-margin requirement the {b entry walk} sizes
          against during a "dawn" week when [dawn_leverage_enabled = true] — the
          leverage dial (see {!initial_long_margin_req} for the buying-power
          semantics). [1.0] = cash account (no leverage); [0.75] = Reg-T 1.33x;
          [0.5] = Reg-T 2x buying power.

          {b Default [1.0] = no-op}: even with [dawn_leverage_enabled = true],
          the dawn week sizes cash-account (bit-identical to the base
          [initial_long_margin_req = 1.0] default) until a spec sets a
          fractional value. Only consulted on dawn weeks with the mechanism
          enabled; a non-dawn week raises the entry-walk requirement to a cash
          account (see {!dawn_leverage_enabled}).

          {b Armed cells must set the base [initial_long_margin_req] to match (or
          be more permissive than) this value} — the simulator funds fills at the
          base requirement, so a base of [1.0] (cash account) would floor-reject
          a levered [0.75] dawn entry rather than fund it. {!Leverage_dawn.validate}
          enforces [initial_long_margin_req <= dawn_initial_long_margin_req] (and
          the interval 0.0 < req <= 1.0) when the mechanism is enabled. In the
          shipped surface spec the base is fixed at the most-permissive rung
          swept ([0.75]) while this dawn axis sweeps
          {[[0.90; 0.85; 0.75]]} — the base [0.75] funds any of them.

          R2: real config field → single-component [Variant_matrix] float axis
          ([((dawn_initial_long_margin_req) (values (0.9 0.85 0.75)))]). *)
  dawn_max_ma_flip_age_weeks : int;
      [@sexp.default default_dawn_max_flip_age_weeks]
      (** Maximum age (in weeks) of the primary index's most recent
          negative->positive weekly-MA slope flip for the "dawn" label to be
          active. Default [78] (~1.5y) matches the P1b memo's lagging-label
          definition (catches 2002-03 back-half, 2010/2012/2016/2020 post-bear
          dawns — and, by construction of a lagging label, also the 2024
          melt-up-lag false positive, the named WF-CV falsifier).

          Larger = a longer post-bear window counts as "dawn" (more levered
          weeks); [0] = only the exact flip week qualifies. Inert while
          [dawn_leverage_enabled = false]. R2: real config field →
          single-component [Variant_matrix] int axis
          ([((dawn_max_ma_flip_age_weeks) (values (52 78)))]). *)
  sparse_tail_min_bars : int; [@sexp.default 0]
      (** Sparse-tail eligibility gate (issue #2083 fix 1) — minimum number of
          daily bars a candidate ticker must have within the trailing
          [sparse_tail_window_trading_days] trading days ending at the
          screener's as-of date. Engineering data-hygiene gate, {b not} a
          Weinstein book rule: it closes a "zombie feed" hole where a
          delisted/renamed ticker's data source keeps serving occasional stale
          bars under the dead symbol, so the series reads current at the
          right-hand edge (data_end = as_of) while the middle is almost empty —
          the 2026-07-17 SNSE/FTH incident, where 6 bars over ~15 trading days
          included one anomalous spike the screener picked up as a breakout.
          Default [0] = gate disabled (no-op, R1): every candidate is eligible
          regardless of tail density, bit-identical to pre-#2083-fix1 behaviour.
          Consumed only by [Weekly_snapshot_generator.generate] via
          [Sparse_tail_gate.check] — the backtest/live strategy path
          ([on_market_close]) never reads this field, so arming it cannot move a
          backtest number. Paired with [sparse_tail_window_trading_days]; both
          must be [> 0] to activate. R2: real config field → resolves through
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
          Engineering data-hygiene flag, {b not} a Weinstein book rule (no book
          section is cited): it neither admits nor rejects a candidate and moves
          no entry / stop / size. A flagged candidate STAYS in the ranked list
          with [Weekly_snapshot.candidate.data_suspect = true] plus a warning
          line, so the weekly report can mark the row — the 2026-07-17 SNSE/FTH
          incident, whose rank-1 pick's breakout was a single [+58%] zombie-feed
          print. Default [0.0] = flag disabled (no-op, R1): every candidate
          carries [data_suspect = false] and no spike warning is emitted,
          bit-identical to pre-#2083-fix3 behaviour. Consumed only by
          [Weekly_snapshot_generator.generate] via [Spike_bar_gate.check] — the
          backtest/live strategy path ([on_market_close]) never reads this
          field, so arming it cannot move a backtest number. R2: real config
          field → resolves through [Backtest.Overlay_validator.apply_overrides],
          armable via [dev/weekly-picks/live-config-overrides.sexp]. *)
  rename_detect_min_overlap_days : int; [@sexp.default 0]
      (** Live ticker-rename detection (issue #2083 fix 2) — minimum number of
          dates a stale ticker and a candidate successor must share before their
          daily returns are compared. Engineering data-hygiene mechanism,
          {b not} a Weinstein book rule (no book section is cited; none supports
          it): it neither admits nor rejects a candidate on any strategy
          criterion and moves no entry / stop / size.

          Closes the root cause of the 2026-07-17 incident, where the report's
          rank-1 pick "SNSE" did not exist at the broker — Sensei
          Biotherapeutics had renamed to Faeth Therapeutics (SNSE -> FTH) on
          2026-06-16 and nothing in the pipeline knew. When armed,
          [Weekly_snapshot_generator.generate] looks for a {e succession} — a
          ticker that goes sparse at the right-hand edge while a younger ticker
          takes over with matching returns — drops the dead predecessor from
          candidate consideration and emits a warning naming the successor. See
          [Rename_detector].

          Default [0] = detection disabled (no-op, R1): the generator does not
          even load the series, so an unarmed run is bit-identical to
          pre-#2083-fix2 behaviour. Paired with [rename_detect_match_fraction];
          both must be [> 0] to activate. Consumed only by
          [Weekly_snapshot_generator.generate] — the backtest/live strategy path
          ([on_market_close]) never reads this field, so arming it cannot move a
          backtest number. R2: real config field → resolves through
          [Backtest.Overlay_validator.apply_overrides], armable via
          [dev/weekly-picks/live-config-overrides.sexp]. *)
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

          Paired with [entry_extension_max_pct], which is the arming switch —
          this field alone activates nothing. [1.0] (one percentage point) is
          the armed value, from the issue's own bucketing of the 2026-07-24
          list. R2: real config field → resolves through
          [Backtest.Overlay_validator.apply_overrides], armed via
          [dev/weekly-picks/live-config-overrides.sexp]. *)
  entry_extension_max_pct : float; [@sexp.default 0.0]
      (** Entry reconciliation (issue #2103) — the maximum overshoot past the
          breakout entry, in percentage points of the entry level, at which the
          system will still issue an order. Beyond it the ticket is
          {b suppressed} with a do-not-chase reason and the row is kept for
          watch purposes.

          Execution correctness, not a new strategy mechanic:
          [Weekly_snapshot.candidate.entry] is the breakout level from the
          {e transition} week, and the <=4-week early-Stage-2 window admits a
          name for weeks afterwards, so a printed "BUY STOP @ $46.08" on a stock
          trading $62 is an instantly-filling market order whose displayed risk
          understated the real risk 14x (the 2026-07-24 MBX specimen). The
          suppression above the cap follows
          [docs/design/weinstein-book-reference.md] §1 "Stage 2 detail (Ch. 2)",
          which locates the buy at the breakout or on "at least one pullback
          close to the breakout point — this is a second chance to buy": a name
          trading far above its breakout is at neither, so there is no Weinstein
          buy point to write a ticket against. No admission rule changes, and no
          pullback-timing mechanic is implied — see [Entry_reconciliation] for
          why the section's "Late Stage 2 warning" is deliberately NOT the
          citation here.

          {b Default [0.0] = reconciliation disabled} (no-op, R1): every
          candidate carries [Entry_reconciliation.Not_reconciled], sizing uses
          [entry] exactly as before, and the reports render unchanged. [15.0]
          (fifteen percentage points) is the armed value from the issue.
          Consumed by [Weekly_snapshot_generator.generate] (report/live-ticket
          path), and — only when [enable_sim_entry_stoplimit] is also on — by
          the backtest runner as the simulator's entry-fill cap; with that flag
          at its default [false], arming this field alone cannot move a
          backtest number. R2: real config field → resolves through
          [Backtest.Overlay_validator.apply_overrides], armed via
          [dev/weekly-picks/live-config-overrides.sexp]. *)
  enable_sim_entry_stoplimit : bool; [@sexp.default false]
      (** Simulator entry fill model (#2158 Phase 2) — when [true] AND
          [entry_extension_max_pct > 0], the backtest runner threads the cap
          into the simulator so entries fill as
          [StopLimit (entry, entry * (1 +/- entry_extension_max_pct/100))]
          (long/short mirrored) instead of Market orders: the order triggers at
          the breakout entry and refuses fills beyond the do-not-chase cap, so a
          gap past the cap is a no-fill and the candidate is re-evaluated at the
          next strategy call. This aligns the simulator with the live
          [Weinstein_order_gen] StopLimit(E, cap) tickets and the report's
          [Entry_reconciliation] semantics (#2158's "one cap, three layers";
          Phase 1 = #2171 covered live + report).

          {b Default [false] = Market fills, bit-identical to every existing
             baseline/golden} (R1). This is a fill-model basis change when
          armed: route it through its own WF-CV surface and deliberate golden
          re-pins before any default flip — NEVER bundle it with another
          mechanism (user directive 2026-08-04, issue #2158). R2: real config
          field → axis-expressible as
          [((flag enable_sim_entry_stoplimit) (values (true false)))] via
          [Variant_matrix] / [Backtest.Overlay_validator.apply_overrides].
          Weinstein authority: the book locates the buy at the breakout or a
          pullback close to it — far above the breakout there is no buy point,
          so an unfilled order (missing > chasing) is the faithful failure mode.
      *)
  sim_entry_trigger_at_suggested : bool; [@sexp.default false]
      (** Book-faithful E-anchored entry trigger (user decision 2026-08-05, plan
          [dev/plans/gtc-breakout-orders-2026-08-05.md] Step 0 option (b)). When
          [true] AND [enable_sim_entry_stoplimit] is on, the strategy's
          [CreateEntering.entry_price] is set to the candidate's
          [suggested_entry] (the graded breakout level [E]) instead of the most
          recent raw close (the G14 fix-B default). The emitted order is then a
          genuine [StopLimit (E, E * (1 +/- entry_extension_max_pct/100))]
          resting AT the breakout level — matching the book's "Buy ... at [E]
          stop -- [E * band] limit" ticket (Ch.3 p.67-68,
          [docs/design/weinstein-book-reference.md] §4.7) and the live report's
          tickets, which size and trigger at [E]. Sizing follows automatically:
          [make_entry_transition] anchors [compute_position_size ~entry_price]
          at the same [effective_entry], so an armed backtest sizes at [E].

          {b Default [false] = current-close trigger, bit-identical to every
             existing baseline/golden} (R1). Because it gates on
          [enable_sim_entry_stoplimit] as well, arming this field alone (with
          the StopLimit flag at its default [false]) cannot move a backtest
          number. This is a fill-model basis change when armed — its own WF-CV
          surface, never bundled (same discipline as
          [enable_sim_entry_stoplimit]). R2: real config field, axis-expressible
          as [((flag sim_entry_trigger_at_suggested) (values (true false)))].

          {b Split-safety} (why the G14 fix-B default exists): G14 fix-B pinned
          the trigger to the current close because [suggested_entry] {i could}
          land in a different price space than the fill on a symbol whose
          screener lookback spanned a split boundary. That hazard is closed by
          G14 fix-A: the screener's high/low lookback is truncated at the most
          recent split ([Stock_analysis] [_no_split_between]), so the breakout
          level -- and therefore [suggested_entry] -- is computed in {i current}
          raw close-price space. In-sim the screener bars and the fill bars come
          from the same snapshot/CSV source, so [E] and the close share one
          price basis by construction; no per-symbol split guard is added.
          (Deliberately no epsilon-disagreement fallback to close: [E] is by
          design {i above} the close for a long breakout -- that is the whole
          point of a resting stop -- so such a guard would misfire on every
          normal breakout.) *)
  entry_anchor_local_range_weeks : int; [@sexp.default 0]
      (** Book-faithful local-range entry anchor (2026-08-05 user decision,
          option (b); note [dev/notes/honest-ladder-2026-08-05.md], PR #2216).
          When [> 0], the screener anchors each candidate's [suggested_entry] at
          the top of the {i current} trading range — the split-safe maximum high
          over the most recent [entry_anchor_local_range_weeks] bars
          ([Stock_analysis.t.local_range_top]) — instead of the 520-week graded
          resistance top. This is the book's "write down the price it would need
          to break out" ticket (Ch. 3; [docs/design/weinstein-book-reference.md]
          §4.1): a nearer, earlier-triggering buy-stop. Example candidate value:
          [26] (a half-year range).

          {b Strictly ticket-level.} Threaded verbatim into
          [Stock_analysis.config.entry_anchor_local_range_weeks] on both the
          simulator screening path ([_stock_analysis_config_for]) and the
          weekly-report path ([Weekly_snapshot_generator]). It moves only the
          entry ticket (and its derived stop / risk); it does NOT shorten the
          resistance-grading lookback, so admission, [resistance_quality]
          grading, the false-virgins protection
          ([[project_false_virgins_load_bearing]]), cascade scoring, and stage
          classification are all UNCHANGED.

          {b Composes with the E-anchored fill family.} The local top is
          typically {i below} the graded top, so an armed
          [sim_entry_trigger_at_suggested] + [enable_sim_entry_stoplimit] order
          rests / triggers earlier (nearer the breakout) than with the graded E.

          {b Default [0] = off, bit-identical to every existing baseline/golden}
          (R1): [Stock_analysis.t.local_range_top = None] and the screener uses
          the graded breakout top exactly as before. R2: real config field,
          axis-expressible as
          [((flag entry_anchor_local_range_weeks) (values (13 26 52)))] via
          [Variant_matrix] / [Backtest.Overlay_validator.apply_overrides]. Per
          the experiment discipline it stays default-off until a ledger ACCEPT
          (WF-CV per the honest-ladder plan). *)
  entry_freshness_basis : Entry_freshness.basis;
      [@sexp.default Entry_freshness.Ma_cross]
      (** F1 — which event starts the Stage-2 admission clock (plan
          [dev/plans/entry-ticket-async-v2-2026-08-10.md] §2 M1 / §3 F1).

          {b The mis-mapping.} [docs/design/weinstein-book-reference.md] §1 says
          Stage 2 {i begins} when the stock breaks out above the top of the
          resistance zone AND above the 30-week MA; Stage 1 explicitly has price
          tossed above and below the MA for months while it bases. Our stage
          classifier starts [weeks_advancing] at the {b MA cross}, so a name
          that crossed its MA ten weeks ago but is still coiled under its range
          top has aged out of the [early_stage2_max_weeks <= 4] admission window
          before the book's Stage-2 week one has happened. Ladder v3
          ([dev/notes/ladder-v3-faithful-stoplimit-2026-08-09.md]) traced the
          structural exclusion of the crash-recovery cohort to exactly this.

          {b [Ma_cross] (default, no-op).} Today's clock, verbatim. R1: every
          existing baseline / golden is bit-identical —
          [Stock_analysis.t .range_top_freshness] is [None] and
          [is_breakout_candidate] runs its pre-F1 arms unchanged.

          {b [Range_top_breakout] (armed).} Freshness is measured from the
          breakout above the ticket anchor ([entry_anchor_local_range_weeks] →
          [Stock_analysis.t.local_range_top] — deliberately the {i same} level
          the resting order uses, so the freshness test and the ticket cannot
          drift apart). A non-late Stage-2 candidate is admitted iff the close
          is at or within [Entry_freshness.proximity_pct] (5%) below that anchor
          {b and} the MA is not declining {b and} the anchor clears the MA —
          §4.1 requirements 1–3 kept explicit, because "a breakout below a
          declining MA is a trap, not a buy" (Ch. 3, Western Union). The
          MA-cross age is not consulted: the basis {b replaces} that window
          rather than widening it, so this is not a stealth re-run of the
          rejected continuation (#1366) or early-admission axes — the [<= 4]
          value itself is untouched.

          {b Interaction with [reject_declining_ma_long_entry] (#1775).} That
          flag is a later strategy-level veto on long entries taken while the MA
          declines. F1 enforces the same §4.1 condition earlier and against the
          {i anchor} (the level a resting ticket actually fills at), so the two
          compose without conflict: an armed basis never admits a candidate the
          #1775 gate would then have to reject on MA direction, and leaving
          #1775 off does not weaken F1's own check.

          {b Faithfulness (W1/W2).} Spine intact — Stage-2-only, volume
          confirmation, and the macro/sector gates are untouched; this moves the
          admission clock onto the book's own Stage-2 start event, and the
          crossing requirement is enforced {i better} because the ticket cannot
          fill without the cross.

          R2: real config field, axis-expressible as
          [((flag entry_freshness_basis) (values (Ma_cross
           Range_top_breakout)))] via [Variant_matrix] /
          [Backtest.Overlay_validator.apply_overrides]. R3: no default is
          flipped by this PR — it stays [Ma_cross] until a ledger ACCEPT plus
          the promotion-confirmation grid. *)
  stop_anchor_at_entry_base : bool; [@sexp.default false]
      (** Book-faithful initial-stop re-anchoring for E-anchored entries (user
          go 2026-08-06; note [dev/notes/honest-ladder-2026-08-05.md]). The
          faithfulness fix that PAIRS with the E-anchored entry family
          ([sim_entry_trigger_at_suggested] + [enable_sim_entry_stoplimit],
          #2209): those tickets rest the entry at the breakout level [E], but
          the initial stop still comes from the deep support-floor machinery
          anchored to crash lows. For a crash-recovery name the mismatched pair
          (E-entry × crash-floor-stop) inflates risk% so the entry walk's 15%
          [max_stop_distance_pct] gate ([G15] step 3) rejects the ticket as
          [Stop_too_wide] — AXTI, ranked #1, was skipped 24x this way and never
          entered (honest-ladder note). This is unfaithful to the book, which
          places the breakout buy's initial stop just under the breakout base /
          below the MA, NOT under the entire multi-year crash floor
          ([docs/design/weinstein-book-reference.md] §5.1).

          When [true] AND the entry is E-anchored (i.e. the effective
          [trigger_at_suggested] the strategy derives from
          [sim_entry_trigger_at_suggested && enable_sim_entry_stoplimit] is on),
          a support-floor-derived initial stop that sits farther from [E] than
          [stops_config.max_stop_distance_pct] is RE-ANCHORED to the
          buffer-below-breakout stop (the [initial_stop_buffer] fallback the
          stops layer already computes — [E *. initial_stop_buffer] then the
          standard round-nudged half-correction inset). A structural floor that
          is already within the 15% book limit is kept UNCHANGED, so
          normal-shape candidates are unaffected. The [Stop_too_wide] gate
          itself is NOT modified — it simply sees honestly-paired risk.

          {b Strictly the INITIAL stop, ticket-level.} It moves only the
          installed initial stop and its derived risk / sizing for the entry
          ticket. Admission, [resistance_quality] grading, [breakout_price],
          cascade scoring, stage classification, and the false-virgins
          protection ([[project_false_virgins_load_bearing]]) are all UNCHANGED.
          The trailing-stop machinery ([Weinstein_stops.update] / stop-recompute
          on held positions) is UNTOUCHED — this is the entry-time stop only.

          {b Composes with the E-anchored fill family} as the intended armed set
          with [sim_entry_trigger_at_suggested] + [enable_sim_entry_stoplimit]
          (and typically [entry_anchor_local_range_weeks] for the nearer local
          top): entry rests at [E], stop sits just under the breakout base, risk
          is book-faithful.

          {b Default [false] = off, bit-identical to every existing
             baseline/golden} (R1): the support-floor stop is installed
          verbatim, exactly as before. Because it additionally gates on the
          E-family being armed (both StopLimit flags default [false]), arming
          this field alone cannot move a backtest number. R2: real config field,
          axis-expressible as
          [((flag stop_anchor_at_entry_base) (values (true false)))] via
          [Variant_matrix] / [Backtest.Overlay_validator.apply_overrides]. Per
          the experiment discipline it stays default-off until a ledger ACCEPT
          (WF-CV per the honest-ladder plan). *)
  sim_entry_fill_next_open : bool; [@sexp.default false]
      (** Next-bar-open fill realism for Market entries (Fix #1, plan
          [dev/plans/fill-model-faithfulness-2026-08-07.md] Workstream C;
          findings [dev/notes/fill-model-fix-findings-2026-08-07.md] §5).
          Threaded from this config into the simulator dependencies by the
          backtest runner (same route as [entry_extension_max_pct]).

          {b The realism gap it closes.} The record entry is a Market order (the
          default fill model, [enable_sim_entry_stoplimit = false]). The
          strategy decides on a weekly signal bar's close and the order rests in
          the manager until the engine matches it against a bar. Because the
          engine retains the last bar per symbol on non-trading
          (weekend/holiday) steps, a Market entry created from a Friday-close
          decision is filled on the following non-trading step against the
          {i stale} signal bar — i.e. at that same bar's open, a price observed
          {i before} the close the decision was made on. That is an optimistic,
          effectively look-back fill ("you cannot buy the close you just
          observed" — nor the open from earlier that day).

          When [true], a Market order that would route to an [Entering] position
          is NOT filled on a step where its symbol has no fresh bar; it stays
          pending until the next {i fresh} trading bar and fills at that bar's
          open — the earliest genuinely tradeable price after the decision.
          {b Scope: Market ENTRY orders only.} Exits, stops, [StopLimit] entries
          (the [enable_sim_entry_stoplimit] family), and every other order path
          are untouched. The strategy's decision-time
          [CreateEntering.entry_price] (used for position sizing and
          stop-distance math at the signal close) is UNCHANGED — only the
          executed engine fill price/date move to the next open. The position's
          realized cost basis (portfolio cash + round-trip pairing) already
          comes from the engine fill, so it moves with the fill; the
          [Position.entry_price] the state machine carries remains the decision
          close by construction (the engine fill price has always been discarded
          there).

          {b Default [false] = current stale-bar fill, bit-identical to every
             existing baseline/golden} (R1): no [Entering]-fill is ever
          deferred, so the engine processes orders exactly as before. This is a
          fill-model basis change when armed — route it through its own WF-CV
          surface and deliberate golden re-pins before any default flip; NEVER
          bundle it with another mechanism (same discipline as
          [enable_sim_entry_stoplimit]). R2: real config field, axis-expressible
          as [((flag sim_entry_fill_next_open) (values (true false)))] via
          [Variant_matrix] / [Backtest.Overlay_validator.apply_overrides].
          Weinstein-faithful (spine untouched: the Stage-2 breakout entry
          decision is identical; only the {i fill assumption} — a realism dial —
          changes). *)
  freeze_entry_at_first_breakout : bool; [@sexp.default false]
      (** No-chase entry-[E] freeze (Fix #2, plan
          [dev/plans/fill-model-faithfulness-2026-08-07.md] Workstream D;
          findings [dev/notes/fill-model-fix-findings-2026-08-07.md] §4 Q3).

          {b The faithfulness gap it closes.} The screener recomputes each
          candidate's [suggested_entry] — the breakout level [E] =
          [breakout_price *. (1 + entry_buffer_pct)] — every Friday from the
          current analysis ([Screener.screen]). For a stock making new highs,
          [E] floats {i up} week over week, so the strategy's resting entry
          ticket ratchets upward with the trend: from the screener's view each
          Friday is a "fresh breakout," but from a Weinstein-purist view it is
          {b buying an extended stock} — the exact thing the book warns against
          ([docs/design/weinstein-book-reference.md] §4.1 "write down the price
          it would need to break out and buy {i that} breakout"; §3 do not chase
          a stock that has already run). Observed: BDLN 2000 chased from [E] =
          50 in January to a March fill at 79.81 (~60% higher, straight into a
          whipsaw); the record vs book fill-basis gap is dragged up by this
          E-chase (findings §4 "Reframe of the reframe").

          {b Behaviour when [true].} The first Friday a symbol qualifies
          (appears as an actionable entry candidate with a suggested [E]), that
          [E] is {b pinned}. On subsequent Fridays the strategy reuses the
          pinned [E] — overriding the freshly recomputed higher level — for as
          long as the setup stays live. The pin is {b released} when the symbol
          stops qualifying and is no longer held (candidate drops out / setup
          expires / the position round-trips to [Closed]), so a genuinely new
          base/breakout later earns a fresh [E]. A symbol resting an unfilled
          entry order stays held, so its pin persists (dormant — held symbols
          are excluded from the candidate walk) until the position closes.

          {b Faithfulness (W2): this INCREASES faithfulness.} It restores the
          book's "buy {i the} breakout, not every successive higher high" rule.
          The spine is untouched — Stage-2 admission, volume confirmation,
          grading, stage classification, and the stop machinery are all
          UNCHANGED; only the entry ticket's price level is frozen (a faithful
          adaptation of the entry-mode dial per
          [.claude/rules/weinstein-faithful-core.md]).

          {b Strictly ticket-level and the entry [E] only.} Freezing overrides
          the candidate's [suggested_entry]; the installed initial stop is
          re-derived from the effective entry as before. The paired
          suggested-stop / [risk_pct] audit metadata carried into the entry
          event reflect the current week's screener output.

          {b Default [false] = off, bit-identical to every existing
             baseline/golden} (R1): {!Entry_freeze.apply} returns the candidate
          list untouched and never allocates a pin. R2: real config field,
          axis-expressible as
          [((flag freeze_entry_at_first_breakout) (values (true false)))] via
          [Variant_matrix] / [Backtest.Overlay_validator.apply_overrides]. Per
          the experiment discipline it stays default-off until a ledger ACCEPT
          (WF-CV per the fill-model plan). *)
  enable_entry_ticket_rescreen : bool; [@sexp.default false]
      (** F2 {b primary}, the book-supported half: re-validate every unfilled
          entry ticket on each weekly review, and cancel the ones whose setup no
          longer exists.

          Split out of the former [entry_order_ttl_weeks] on 2026-08-16 (defect
          C of [dev/plans/entry-anchor-and-ttl-2026-08-15.md]). That single
          field armed {b two} mechanisms at once — this re-screen and the
          arbitrary clock below — with no way to have the faithful half without
          the invented one; the old code did not even consult the re-screen
          predicate at [0]. The ladder-v4 seeded run then found ttl4 and ttl8
          indistinguishable (+0.5pp and −34.5pp against a 132.5pp null), i.e.
          {b the re-screen was doing the work and the number was free} — which
          is only sayable now that the two can be set independently.

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
          and §7's weekend homework is precisely the loop at which that cancel
          decision is taken. Unlike the clock, this half carries no invented
          number. The spine is untouched: it governs only the lifetime of an
          order that has not yet become a position.

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
          whether it still qualifies. [0] = {b unbounded} = the default.

          A ticket placed on review week 0 survives review week
          [entry_order_max_rest_weeks] and is cancelled at week
          [entry_order_max_rest_weeks + 1].

          {b ⚠ Promoted to 26 on 2026-08-18, REVERTED on 2026-08-19.} The
          promotion was user-directed on a single cell and is recorded here
          because the reversal is the more useful fact.

          {b Why it exists at all.} Unbounded is genuinely wrong at the extreme
          (defect E): [FUL-wein-64] was decided 2000-02-04 and filled 2021-11-01
          — a resting order that survived {b 21.7 years}. (The {b 865-week} max
          fill age on the 26-year null is a different run's longest rester,
          ~16.6 years; the two are not in conflict — they are two measurements
          of the same pathology.) The clock's job is removing that absurdity.

          {b What the promotion rested on.} Three salts of a clock-only arm on
          top3000 × 2000-2026 returned 513.42 / 434.06 / 377.73 against the
          null's 265.44 / 281.71 / 397.95 — mean gap {b +126.7pp}. But that
          base's own seed spread is {b 132.5pp}
          ([dev/experiments/ladder-v4-seeded-2026-08-14/results.md]), so the gap
          sits {i inside} its own noise floor; the distributions touch and the
          exact rank test gives p = 0.100.

          {b What reversed it.} The one golden that arms
          [enable_sim_entry_stoplimit] — and therefore the only one where a
          clock can bite, since Market entries fill immediately and never rest —
          measured at three salts per arm:

          {v
          salt   clock=0            clock=26         delta
          0      108.23% (238 tr)   69.81% (227)     -38.42pp
          1      111.40% (240)      69.09% (227)     -42.31pp
          2      112.30% (240)      70.29% (227)     -42.01pp
          mean   110.64%            69.73%           -40.91pp
          spread   4.07pp            1.20pp
          v}

          {b Complete separation} — the armed arm's best draw sits 37.94pp below
          the control's worst, giving the 3-vs-3 exact rank test its floor (p =
          0.05), and the effect is ~10x the larger arm's spread. The armed arm
          returns 227 trades in all three draws while the control varies
          238-240, so the clock removes a {i stable} cohort rather than winning
          or losing on path luck.

          {b CI reproduces the salt-0 pair independently, to the cent.} Reading
          the scenario [summary.sexp] from the two postsubmit runs' artefacts:

          {v
                             parent (clock=0)   merge commit (clock=26)
          totalreturnpct     108.23             69.81
          numtrades          238                227
          totalpnl           751,808.07         424,936.24
          largestwindollar   258,902.38         170,802.85
          v}

          The control's [largestwindollar] is SMCI to the cent, and it is absent
          from the armed arm — the decomposition below, confirmed in a different
          environment on different hardware.

          ⚠ An earlier version of this docstring claimed the golden "passed on
          the commit before the promotion and FAILED on the merge commit". That
          is {b false} and is withdrawn: the scenario has failed on {i every}
          run back to [e00bb5a90] (2026-08-18), a full day before the promotion
          merged — it is a standing pre-existing red against a 110.78 floor, and
          the claim compared a {i job} conclusion against a {i step} result. The
          artefact comparison above is the honest form, and is stronger: a
          status flip proves nothing, whereas two reproduced metric sets do.

          {b The mechanism — a tail-touching lever.} Dissecting the two arms'
          trades (joined on [symbol|entry_date]; [position_id] does {i not} join
          across arms, only 99 of 238 overlap once the ticket counter shifts):
          59 trades removed worth {b +248,545}, 48 substituted worth
          {b -84,172}, 179 shared and unchanged. The removed cohort is mostly
          junk — median {b -2,840}, 40 losers to 19 winners — and its entire
          positive total is one trade: {b SMCI +258,902 (+240.0%, 292 days)},
          larger than the cohort's net. The clock cuts the resting-ticket
          population blind, and that population is where the fat-tail winners
          live. 12th+ confirmation of [project_edge_is_the_fat_tail]; it joins
          harvest-rotate, trim, re-time and cap.

          {b The calibration lesson.} 132.5pp is a property of {i that} base,
          not a universal floor — this base measures {b 4.07pp}, ~33x quieter
          (132.5 / 4.07 = 32.6). A longer, broader run is not automatically the
          more reliable one: more symbols and more decision points give path
          realisation more places to change which tickets get funded.
          {b Every base needs its own null}; never import one base's floor to
          judge another's gap.

          {b If a bound is wanted}, the evidence points at {b 156 weeks}, and
          the working belongs here rather than the bare number. On cell 13's
          rest-time buckets a 26-week bound cuts {b 87 trades worth +215,806},
          including the best per-trade bucket (1-3yr at +10,857/trade); a
          156-week bound cuts only the >3yr population, {b −154,006} and
          upside-free. [project_ttl_is_a_tail_lever] reaches the same place
          independently. {b 26 cuts where the monsters are.}

          ⚠ {b One base disagrees}, and it is the one this flip was promoted on:
          the ledger's four-bound table for the 26-year null {i inverts} the
          ranking, with the 26-week bound removing the largest net-losing cohort
          there (89 fills, −349,132). So two of three bases say 26 cuts profit
          and 156 is never contradicted — but
          {b 156 is a reasoned candidate, not a measured winner}. No surface has
          been run on it. Treat it as the value to test first, not as a result.

          ⚠ {b And all of that is static bucket subtraction}, which is not the
          counterfactual. It assumes the trades a bound removes simply vanish;
          they do not — the cash they would have consumed funds different later
          tickets. This PR's own decomposition is the proof: cutting at 26 weeks
          removed 59 trades but {i added} 48 others, a near-total reshuffle that
          no bucket arithmetic predicts. So the 87-trades/+215,806 figure bounds
          what is cut, not what is lost. Another reason 156 is a value to test
          rather than a value to adopt.

          Any future promotion needs a ledger ACCEPT plus the
          [promotion-confirmation.md] grid, neither of which the 26 flip had.

          {b Faithfulness (W2): BOOK-NEUTRAL dial.} The book grants the cancel
          authority (§4.7 / §7) but names no number, so every value here is a
          free parameter — which is why it is the {i backstop} and not the
          primary rule.

          {b Do {i not} prefer the re-screen instead.} It was {b REJECTED} on
          2026-08-18
          ([dev/experiments/_ledger/2026-08-18-entry-ticket-rescreen.sexp]),
          draws 176.36 / 174.83 / 182.28 with its best sitting 83pp below the
          null's worst. The two rules select {b opposite} populations: a clock
          cuts tickets that rested long {i without} their setup changing, while
          the re-screen cuts tickets whose stage/sector/macro wobbled — which is
          the base-building pullback-then-resume pattern.

          R2: axis-expressible as
          [((flag entry_order_max_rest_weeks) (values (0 13 26 52 156)))].

          Full record: [dev/experiments/clock26-golden-ab-2026-08-19/]. *)
  reserve_cash_for_resting_tickets : bool; [@sexp.default false]
      (** G3 of [dev/plans/ticket-funding-2026-08-16.md]: subtract the cost the
          book has already committed to {b resting} entry tickets from the cash
          the entry walk is allowed to spend this tick.

          {b The leak it closes.} {!Entry_audit_capture.check_cash_and_deduct}
          already enforces cash discipline {i within} one tick — the walk
          threads a [remaining_cash] ref and each admitted [CreateEntering]
          deducts its designed cost, so one Friday's tickets cannot collectively
          exceed that Friday's cash. But the ref is re-seeded from
          [portfolio.cash] every tick, and a ticket placed in week [N] and still
          resting in week [N+1] has taken {b no} cash — it is a resting order,
          not a position. So the next walk sees that money as available and
          commits it again. Repeat weekly and the book carries more claims than
          cash.

          {b What that costs today.} When several over-committed tickets trigger
          in the same week, the first ones consume the balance and the rest are
          {b destroyed} — not retried, not resized
          ([[project-ticket-dies-on-cash-shortfall]]). Measured over 3,530
          rejections: median shortfall is {b 52%} of the ticket's cost, only
          5.1% are within 5% of fundable, and {b 63%} arrive in bursts against a
          single cash balance. That burst structure is the signature of
          aggregate over-commitment rather than per-ticket bad luck, and it is
          why this axis is the one that removes the failure instead of
          arbitrating it (G2a retry and G2b size-to-available both arbitrate).

          {b Reserved amount} is the {b unfilled remainder},
          [(target_quantity - filled_quantity) * entry_price], summed over
          [Entering] {b long} positions. Partial fills already drew their own
          cash, so reserving the full [target_quantity] would double-count them;
          an entering {i short} credits cash on fill, so reserving against it
          would shrink the budget for a claim that pays in.

          {b No double-count on the filling tick.}
          {!Trading_simulation.Simulator} applies fills in
          [_process_fills_and_cancels] {i before} [_call_strategy], so a ticket
          that fills this tick has already left [Entering] and its cash has
          already left [portfolio.cash] by the time [spendable] is computed.

          {b Not [cash_reserve_pct]} (retired in #2286,
          [[project-cash-reserve-rejected]]). That was a blanket idle-cash floor
          — a protection lever, which the barbell dominates. This reserve is
          earmarked against {b specific written claims} and is released the
          moment a ticket fills or cancels; with no resting tickets it is
          exactly [0.0].

          {b The cost, stated up front.} Reserved cash is idle cash. Deployment
          already sits near the exposure cap, so this plausibly pushes
          utilisation {i below} it — fewer claims, each funded. Report
          deployment alongside return, not after it.

          [false] (default) = [spendable] is [portfolio.cash], bit-identical to
          the prior behaviour (R1).

          R2: axis-expressible as
          [((flag reserve_cash_for_resting_tickets) (values (true false)))]. *)
  stop_width_mode : Stop_width_mode.t;
      [@sexp.default Stop_width_mode.Drop_over_max]
      (** F3 ([dev/plans/entry-ticket-async-v2-2026-08-10.md] §3-F3): what the
          entry walk does with a candidate whose structural initial stop sits
          further than [stops_config.max_stop_distance_pct] from entry.

          Three readings of one book sentence:

          - [Drop_over_max] (default) is today's G15 step-3 drop — the candidate
            is skipped with [Audit_recorder.Stop_too_wide]. §5.1 read as a ban.
          - [Size_down] admits it, up to {!stop_width_size_down_max_pct}, and
            {e tags} the entry
            [Entry_audit_capture.entry_meta.sized_down_wide_stop = true] (trace
            outcome [Sized_down_wide_stop]). Note that fixed-risk sizing already
            shrinks the share count ~[1 / stop_distance] under {b every} mode —
            sizing never reads the mode — so what [Size_down] adds over the
            default is the admission and the tag, not the shrink.
          - [Demote_over_max] (added 2026-08-16, defect B) admits the identical
            candidate at the identical size, but walks it {e after} every
            candidate whose stop is within the limit, so wide stops are funded
            only with what is left ({!Entry_stop_width_order}). The delta
            against [Size_down] is {b order only}, which means the two diverge
            exactly when capital binds. Also bounded by
            {!stop_width_size_down_max_pct} — leaving that at [0.0] makes this
            mode a no-op, so a spec must set the ceiling for it to bite.

          {b Honest citation.} §5.1 says "prefer other candidates", which is
          comparative rather than an absolute ban — and the book reserves ban
          vocabulary for the cases it means as bans ("NEVER buy, no matter how
          good other factors", §4.4 on negative RS) while {e grading} the rest
          (§4.3 A+/A/B/C on overhead resistance). Of the three,
          [Demote_over_max] is the closest to §5.1's wording. It is {b not},
          contrary to an earlier draft of this docstring, the shape the codebase
          already uses for [overhead_supply]: the supply score is a term of
          [Screener.score_long], so a heavy-supply candidate can fall under
          [passes_score_floor] and be excluded outright. That precedent claim is
          withdrawn; the argument rests on the book. [Size_down] is NOT a
          documented book mechanism: the book's remedies for a wide stop are (i)
          anchor at the nearest prior correction low
          ([stops_config.support_floor_anchor_scope = Nearest], the competing
          {e faithful} arm), (ii) the §5.3 trader preset's 4–6% stop, (iii) pass
          — never risk-parity size-down. It remains a tolerated-participation
          {e reading}, labelled as such; see {!Stop_width_mode} for the full
          framing and the ladder-v3 evidence.

          {b What [Demote_over_max] is responding to.} On the 26-year top-3000
          core arm AXTI was rejected {b 21 times} with [Stop_too_wide] at a
          correct, fresh entry anchor — and became the single largest winner in
          the record run. The width gate, not the entry anchor, is what excludes
          that cohort ([dev/notes/entry-anchor-defect-a-refuted-2026-08-16.md]).

          {b Default [Drop_over_max] = bit-identical to every existing
             baseline/golden} (R1). R2: real config field, axis-expressible as
          [((flag stop_width_mode) (values (Drop_over_max Size_down
           Demote_over_max)))] via [Variant_matrix] /
          [Backtest.Overlay_validator.apply_overrides]. Stays default-off until
          a ledger ACCEPT plus the promotion-confirmation grid (R3). *)
  stop_width_size_down_max_pct : float; [@sexp.default 0.0]
      (** Sanity ceiling for {!stop_width_mode} — {b both} [Size_down] and
          [Demote_over_max]: stop distances above this fraction of entry are
          still dropped, so neither mechanism can admit unbounded structural
          risk. [0.0] (the default) falls back to
          [stops_config.max_stop_distance_pct], which makes an
          armed-but-unconfigured mode admit exactly the population
          [Drop_over_max] admits. The field name predates [Demote_over_max]
          (2026-08-16); it was not renamed because 26 committed specs set it.

          It exists as its own knob rather than reusing [max_stop_distance_pct]
          so the ladder-v4 sweep can widen the {e admission} boundary without
          also moving the §5.1 15% line that other mechanisms read (the
          [stop_anchor_at_entry_base] re-anchor threshold, and the
          [Sized_down_wide_stop] tag boundary itself) — the two roles are
          separated so a wide-admission cell is not confounded with a re-anchor
          change. Unread under [Drop_over_max]. Default [0.0] is an exact no-op
          (R1); axis-expressible (R2). *)
  volume_confirm_at_fill : bool; [@sexp.default false]
      (** F5 — judge the breakout's volume {b at the fill}, not at placement
          (plan [dev/plans/entry-ticket-async-v2-2026-08-10.md] §3-F5;
          [docs/design/weinstein-book-reference.md] §4.2 + §4.7).

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

          {b The eject is INSEPARABLE from the flag.} There is deliberately no
          eject-off cell: holding a volume-unconfirmed breakout would be a W1
          spine item-3 violation ("entry on a breakout above resistance WITH
          volume confirmation"), and §4.2's low-volume-breakout SELL rule is
          explicit that a buy-stop filled without volume confirmation is sold,
          not held. Arming the placement waiver alone is not expressible.

          {b Default [false] = today's screen-time volume requirement,
             bit-identical} (R1): [require_breakout_volume] stays [true] and the
          eject runner short-circuits to [[]], so no golden moves. R2: real
          config field, axis-expressible as
          [((flag volume_confirm_at_fill) (values (true false)))] via
          [Variant_matrix] / [Backtest.Overlay_validator.apply_overrides]. R3:
          no default flip without a ledger ACCEPT.

          {b Faithfulness: BOOK-SUPPORTED.} Spine item 3 is preserved and
          relocated to the correct event — the check is not weakened, it is
          moved from a week the book never evaluates to the week the book
          defines it on.

          {b Future work (NOT built)}: plan §3-F5 amendment (iv) notes a later
          trader/investor variant of the unconfirmed branch
          ([eject | hold_with_stop_at_breakout]); v4 implements the eject only.
      *)
}
[@@deriving sexp]
(** Complete Weinstein strategy configuration. All parameters configurable for
    backtesting. *)

val default_dawn_max_flip_age_weeks : int
(** Default value for {!config.dawn_max_ma_flip_age_weeks} (78 weeks ~= 1.5y),
    the P1b-memo lagging dawn-label window. Exposed as the named no-op so the
    sexp default and the {!config} literal share one source of truth. *)

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
