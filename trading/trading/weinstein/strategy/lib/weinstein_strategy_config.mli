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
  enable_harvest_rotate : bool; [@sexp.default false]
      (** Master switch for the harvest-rotate dial ({!Harvest_rotate_runner},
          plan [dev/plans/harvest-rotate-rigorous-test-2026-06-10.md]). When
          [true], on a screening (Friday) day the runner trims a fraction
          [harvest_fraction] of every held long whose current stage is
          [Stage2 { late = true }] (the earliest Stage-3 topping precursor),
          emitting a [TriggerPartialExit]; the freed capital recycles through
          the existing entry pipeline into a fresh Stage-2 leader. Default
          [false] preserves all existing baselines — the runner short-circuits
          to [[]] before any work, so the disabled path is byte-identical to the
          pre-feature strategy.

          This is the {b exit-aggressiveness} dial ("sell half as the Stage-3
          top forms") combined with {b rotate-into-leadership}, both Weinstein's
          "The Trader's Way" — a faithful adaptation of
          [docs/design/weinstein-book-reference.md] §Stage 3 detail (Ch. 2):
          "Investors: sell half, protect remaining half." The strategy {b spine}
          is untouched — stage classification, the Stage-2-only buy rule,
          breakout+volume entry, the macro/sector gate, and relative strength
          are all unaffected; only the size of an existing held long is reduced
          when it begins to top. Searchable as a [Variant_matrix] flag axis
          ([((flag enable_harvest_rotate) (values (true false)))]). Default-off
          until an experiment-ledger ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md] +
          [.claude/rules/promotion-confirmation.md]). See
          {!Harvest_rotate_runner}. *)
  harvest_fraction : float; [@sexp.default 0.5]
      (** Fraction of a held long position trimmed by {!Harvest_rotate_runner}
          when it enters [Stage2 { late = true }]: the trimmed quantity is
          [held_quantity *. Float.min 1.0 harvest_fraction]. [0.5] = sell half
          (the book's "sell half as the Stage-3 top forms"); [1.0] = full rotate
          out of the topping name. Only consulted when
          [enable_harvest_rotate = true]; because the runner is gated entirely
          by the flag, the disabled path is byte-identical to baseline
          regardless of this value. A value [<= 0.0] is itself a no-op (nothing
          to trim). Searchable as a [Variant_matrix] axis. See
          {!Harvest_rotate_runner}. *)
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
            re-emitted in original screener order so audit ordering is
            preserved.

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
  enable_scale_in : bool; [@sexp.default false]
      (** Master switch for the explore/exploit scale-in mechanism
          ([dev/plans/capital-management-scale-in-2026-07-02.md]): initial
          entries at [scale_in_config.initial_entry_fraction] of the full risk
          unit (broader survey of fresh Stage-2 breakouts) plus at most
          [scale_in_config.max_adds] follow-up adds into {e revealed} strength
          (the first pullback that holds the breakout — Weinstein's ½ + ½, "The
          Trader's Way"). A
          {b reallocation inside the existing exposure envelope}: per-symbol
          notional stays capped at [portfolio_config.max_position_pct_long] and
          no gross-exposure knob changes.

          Default [false] is a {b no-op} — the entry walk, sizing, and
          transitions are bit-identical to baseline (experiment-flag-discipline
          R1); the mechanism is searchable as a flag axis the day it lands (R2).
      *)
  scale_in_config : Scale_in_detector.config;
      [@sexp.default Scale_in_detector.default_config]
      (** Scale-in knobs — initial-entry fraction, add trigger ([Pullback] v1
          default / [Early_new_high] / [Either]), pullback proximity, the
          extension gate (max distance above the 30-week MA), and the not-late
          gate. Only consulted when [enable_scale_in = true]; each field is
          addressable as a [Variant_matrix] dot-path axis, e.g.
          [((key (scale_in_config add_trigger)) (values (Pullback Either)))].
          See {!Scale_in_detector}. *)
  cash_reserve_pct : float; [@sexp.default 0.0]
      (** Fraction of {e current portfolio value} held back from NEW entry
          funding on each Friday entry walk
          ({!Weinstein_strategy.entries_from_candidates}). The per-Friday
          spendable cash is
          [max 0 (portfolio.cash - cash_reserve_pct * portfolio_value)]; the
          reserve is taken off the top-level entry budget exactly once (in the
          reserved-short-sleeve path the same reduced budget is split between
          the long and short walks, so it is never charged twice).

          {b The working replacement for the dead
             [Portfolio_risk.min_cash_pct].} Per
          [dev/notes/envelope-knobs-dead-2026-07-05.md] (merged #1861),
          [Portfolio_risk.min_cash_pct] is unwired — it has no production
          consumer (its only reader, the dead [Portfolio_risk.check_limits], was
          deleted 2026-07-09), so backtests run at ~89-99% deployment with no
          cash-reserve mechanism at all. This field is the honest, live-path
          reserve: it is consumed at the one seam that actually gates entry
          funding (the entry-walk [remaining_cash]).

          {b Scope — entries only.} The reserve narrows only NEW entry funding.
          Exits, covers, stop orders, and force-liquidations do not flow through
          the entry walk and are structurally unaffected, so a reserve can never
          block an exit (the #1553 exit-fill-reject lesson). A held position
          always exits on its stop/stage/liquidity signal regardless of the
          reserve.

          {b Semantics.}
          - [0.0] (default): {b bit-identical to baseline} —
            [spendable = portfolio.cash], so every existing golden/baseline
            replays unchanged (experiment-flag-discipline R1).
          - [> 0.0]: a candidate whose cost fits within [portfolio.cash] but not
            within the reduced [spendable] budget is rejected exactly as an
            [Insufficient_cash] skip; candidates that fit within [spendable] are
            admitted normally.

          {b Faithfulness} (W1/W2, [.claude/rules/weinstein-faithful-core.md]).
          A portfolio-risk / capital-preservation dial that {e tightens}
          deployment — it holds cash back in exactly the spirit of the book's
          "when in doubt, stay out" caution, without touching any spine item
          (stage classification, the Stage-2-only buy rule, breakout+volume
          entry, stops, the macro/sector gate are all unchanged). Searchable as
          a single-component [Variant_matrix] axis
          ([((cash_reserve_pct) (values (0.0 0.1 0.2 0.3)))]). Default-off until
          an experiment-ledger ACCEPT (per
          [.claude/rules/experiment-flag-discipline.md] +
          [.claude/rules/promotion-confirmation.md]). *)
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

          {b Semantics.}
          - [None] (default): {b bit-identical to baseline} —
            [Stock_analysis.t.supply] is always [None], the screener falls back
            to the binary grade, no sketch reads occur
            (experiment-flag-discipline R1).
          - [Some cfg]: the continuous score runs for survivors whose panel
            carries the sketch columns. Pairs with the screener weight
            [Screener.scoring_weights.w_overhead_supply] (both must be armed for
            the mechanism to change any score); the live CSV report path has no
            warehouse sketch and stays on the v1 binary grade until a follow-up.

          {b R2 searchability.} Real config field → resolves through
          [Overlay_validator.apply_overrides]; expressible as an option axis
          over the [Resistance_supply.config] sub-fields.

          {b Faithfulness} (W1/W2). Ranking weight only, not an entry gate — the
          Stage-2-only buy rule, breakout+volume entry, macro/sector gate and
          stops are untouched. Default-off until an experiment-ledger ACCEPT. *)
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

          {b Semantics.}
          - [false] (default): {b bit-identical to baseline} —
            [Stock_analysis.t.virgin_readmission] is always [false] and the
            early-Stage-2 staleness rejection is unchanged
            (experiment-flag-discipline R1).
          - [true]: a stale Stage-2 survivor is re-admitted iff its warehouse
            sketch is present AND the breakout is virgin
            ([Resistance_supply.is_virgin]); sketch absent → no re-admission (no
            fabrication). Independent of [overhead_supply] — the virgin test
            needs only the sketch, not the scoring config.

          {b R2 searchability.} Real top-level [bool] field → resolves through
          [Overlay_validator.apply_overrides]; expressible as a [Variant_matrix]
          [((flag virgin_crossing_readmission) (values (true false)))] axis.

          {b Faithfulness} (W1/W2). This is the book's "new high ground"
          breakout — a fresh breakout into virgin territory with volume is a
          valid Stage-2 entry regardless of how long ago the Stage-2 transition
          happened (weinstein-book-reference.md §Buy Criteria). Spine intact:
          still Stage-2-only, still breakout + volume + RS gates, macro/sector
          gates and stops untouched — it only widens which Stage-2 names clear
          the early-window staleness cut. Default-off until an experiment-ledger
          ACCEPT. *)
}
[@@deriving sexp]
(** Complete Weinstein strategy configuration. All parameters configurable for
    backtesting. *)

val default_config : universe:string list -> index_symbol:string -> config
(** Build a default config with Weinstein book values. *)

val name : string
(** Strategy name, always ["Weinstein"]. *)
