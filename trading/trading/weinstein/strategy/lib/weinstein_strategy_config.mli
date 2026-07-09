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
  stale_exit_after_days : int option; [@sexp.default None]
      (** When [Some n], a held position whose underlying symbol has stopped
          emitting bars for [n] calendar days is force-sold at its last
          available close as a realised trade (instead of being carried open at
          a stale mark indefinitely and counted in terminal NAV — issue #1484).
          The runner threads this into the simulator's
          [Trading_simulation.Stale_hold.config.stale_exit_after_days]. Default
          [None] keeps every existing backtest byte-identical (detector still
          records stale holds; no force-exit). Searchable as a [Variant_matrix]
          flag axis ([((flag stale_exit_after_days) (values (() (5))))]). *)
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
          ([min_entry_dollar_adv = 0.0], [min_hold_dollar_adv = 0.0]) is a no-op
          — the gate drops nothing and the exit never fires, so every existing
          golden/baseline replays {b bit-identically}
          (experiment-flag-discipline R1).

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
}
[@@deriving sexp]
(** Complete Weinstein strategy configuration. All parameters configurable for
    backtesting. *)

val default_config : universe:string list -> index_symbol:string -> config
(** Build a default config with Weinstein book values. *)

val name : string
(** Strategy name, always ["Weinstein"]. *)
