open Types

(** Index circuit-breaker — a pure, lookahead-free two-state machine that
    decides when a long-only index (SPY) floor sleeve should sell to cash and
    when it should re-enter.

    Design authority: [dev/plans/fast-circuit-breaker-spy-sleeve-2026-07-08.md]
    (P1b of the floor-quality program), user mandate 2026-07-09. This module is
    {b step 1} of that plan: the pure lib only. The thin sleeve strategy that
    consumes it (buy-and-hold SPY + breaker) is a separate follow-up and is NOT
    built here — this module changes no behaviour anywhere on its own.

    {b Why this exists}: full Weinstein stage-timing on SPY
    ([Spy_only_weinstein_strategy]) times {e everything}, so every false stage
    exit is an upside tax on the one instrument whose long-run drift is the
    whole return (the index sleeve's "winner" IS the buy-and-hold position — per
    [project_edge_is_the_fat_tail], touching it needs the tail-RISK-insurance
    exception, i.e. rare, crash-gated interventions only). The breaker is
    instead {b default-in-market}: a rare intervention, asymmetric by decline
    character, with fast re-entry.

    {b Faithfulness / spine}: this does not change any Weinstein spine rule
    ([weinstein-faithful-core.md]). For a single-instrument index sleeve the
    macro gate collapses to the instrument itself; the breaker is a
    tail-RISK-insurance exit/re-entry overlay, not a new buy rule. Every
    threshold is a config field (no hardcoded magic numbers) so it is an
    experiment axis on day one ([experiment-flag-discipline.md] R2).

    {b Lookahead-free}: every decision reads only the current and earlier index
    bars plus the current-week macro read. No future bar is ever consulted. All
    functions are pure: same inputs always produce the same output.

    {b The two load-bearing semantics (from the design doc §"Semantics
       requirements — the GME lesson", non-negotiable, see
       [dev/notes/warmup-364-repin-2026-07-08.md] §Findings)}:

    - {b The T3 floor peak is a TRAILING-WINDOW high of INDEX PRICE, never a
         monotonic high-water mark.} The engine's
      [Force_liquidation.Peak_tracker] is monotonic over NAV; GME's Jan-2021
      parabolic MTM spike ($28.9M) set a floor the run could never re-clear,
      sterilizing the strategy for 5 years (32 repeat liquidations). A
      trailing-window high of index price {b decays by construction} once the
      spike scrolls out of the window, so it cannot be poisoned by a single
      position's unrealized mark. See {!config.floor_peak_lookback_bars}.
    - {b Re-entry is self-contained in the state machine — there is no
         halt-until-external-reset.} The engine [Portfolio_floor]'s
      Bearish→non-Bearish reset was the second half of the GME sterilization
      (the reset fired while NAV was still under the un-decayed floor, so it
      refired). Here, an {!Out_of_market} state re-enters purely from subsequent
      index behaviour (recovery off the post-exit low, or price above a turning
      MA) — it never waits on an external macro flip. *)

type exit_reason =
  | Fast_crash
      (** T1: a steep short-window index drawdown with fast-V character (no
          Advance-Decline breadth lead). Arms {b fast} re-entry. *)
  | Slow_grind
      (** T2: a sustained breadth-led distribution decline (A-D line leading the
          index down), confirmed over several weeks. Arms {b slow},
          Weinstein-style re-entry (grind bottoms are slow; confirmation is
          cheap there). *)
  | Absolute_floor
      (** T3: the catastrophic backstop — the index closed below a fraction of
          its {b trailing-window} high (a decaying reference, never a monotonic
          high-water mark). Arms {b fast} re-entry. *)
[@@deriving show, eq, sexp]

type state =
  | In_market of { grind_streak : int }
      (** Holding the index. [grind_streak] is the number of consecutive steps
          most recently classified [Slow_grind] (0 when the last step was not a
          grind); the T2 exit fires when it reaches
          {!config.grind_confirm_weeks}. A fresh sleeve starts at {!in_market}
          ([grind_streak = 0]). *)
  | Out_of_market of {
      exited_on : exit_reason;
          (** Which trigger caused the exit — selects the re-entry rule
              (asymmetric re-entry). *)
      exit_date : Core.Date.t;  (** Date of the bar on which the exit fired. *)
      post_exit_low : float;
          (** Lowest index close observed from the exit bar through the current
              bar (inclusive). Monotonically non-increasing while out of market;
              the fast re-entry threshold is measured as a recovery
              {b off this low}, so a deeper crash lowers the bar the index must
              clear to re-enter. *)
    }
[@@deriving show, eq, sexp]

type action =
  | Hold  (** No transition this step (stay in the current state). *)
  | Exit of exit_reason  (** Sell the index to cash this step. *)
  | Re_enter  (** Buy the index back this step. *)
[@@deriving show, eq, sexp]

type config = {
  decline_config : Decline_character.config;
      (** Threaded into {!Decline_character.classify} to read the fast-V /
          slow-grind {b character} of the index each step. The breaker's default
          sets [fast_v_ignores_ma_filter = true] so the fast-V path arms on rate
          alone (the 2020 fix: a V-crash falls before the weekly MA rolls over).
          Exposed so its own thresholds are tunable as axes too. *)
  fast_exit_rate_pct : float;
      (** T1 threshold: the trailing index drawdown over
          {!fast_exit_lookback_bars} must be at least this positive fraction
          (e.g. 0.08 = 8%) for a fast-crash exit, {b in addition to} the step
          being classified [Fast_v]. Default: 0.08. *)
  fast_exit_lookback_bars : int;
      (** T1 window (bars) over which the fast-exit drawdown is measured.
          Default: 4. *)
  grind_confirm_weeks : int;
      (** T2 confirmation: the step must be classified [Slow_grind] this many
          consecutive times before the slow-grind exit fires. A slow bear is
          where early exit pays and confirmation is cheap (the decline is slow).
          Default: 3. *)
  floor_drop_pct : float;
      (** T3 threshold: an exit fires when the current index close is below
          [(1 -. floor_drop_pct)] times the {b trailing-window} high. Default:
          0.20. *)
  floor_peak_lookback_bars : int;
      (** T3 window (bars) over which the trailing high is taken. This is what
          makes the floor {b decay} — the reference high is the max close over
          only the last [floor_peak_lookback_bars] bars, never an all-time
          high-water mark, so a parabolic spike cannot poison it once it scrolls
          out of the window (the GME lesson). Default: 52. *)
  fast_reentry_recover_pct : float;
      (** Fast re-entry threshold (after a [Fast_crash] or [Absolute_floor]
          exit): re-enter when the current close has recovered at least this
          fraction {b off the post-exit low} (e.g. 0.05 = 5% above the low). A
          missed V-bounce is the floor's biggest historical tax, so this is
          deliberately quick. Default: 0.05. *)
  slow_reentry_ma_weeks : int;
      (** Slow re-entry (after a [Slow_grind] exit): the period of the simple MA
          of index close the price must be above. Weinstein-style re-entry above
          a turning weekly MA. Default: 30. *)
  slow_reentry_ma_rising_lookback : int;
      (** Slow re-entry: the MA must be {b turning up} — its value now must
          exceed its value this many bars earlier — before re-entry fires.
          Default: 4. *)
}
[@@deriving show, eq, sexp]
(** Every trigger threshold, all config fields (no hardcoded constants) so the
    breaker is expressible as a [Variant_matrix] axis the day a consumer wires
    it. Derives [sexp] for round-trip; a full record is expected on parse (the
    reference values live in {!default_config}), consistent with
    {!Decline_character.config}. *)

val default_config : config
(** [default_config] returns the design-doc reference priors (see the field
    docs). These are {b priors to search}, not a validated configuration: the
    plan calls for a WF-CV surface + a deep bear-regime promotion grid before
    any of these values is trusted as a default. *)

val in_market : state
(** [in_market] is the fresh sleeve state: [In_market { grind_streak = 0 }]. *)

val step :
  config:config ->
  state:state ->
  index_bars:Daily_price.t list ->
  ad_macro:Macro.result ->
  state * action
(** [step ~config ~state ~index_bars ~ad_macro] advances the breaker one bar and
    returns the next state paired with the action to take {b this} bar.

    @param index_bars
      Trailing index bars up to and including the current bar, chronological
      oldest-first. Closes are read as [close_price] (matching
      {!Decline_character}); a caller wanting a dividend-adjusted read supplies
      an adjusted series. Read at the current bar and earlier offsets only —
      never the future.
    @param ad_macro
      The already-computed macro result for the current week, threaded into
      {!Decline_character.classify} for the fast-V / slow-grind character read.
      Only consulted while {!In_market} (re-entry is decided from index bars
      alone).

    Transition rules (thresholds from [config]):

    {ul
     {- {b In_market} — exits are checked in precedence order:
        + {b T1 fast-crash} ([Fast_crash]): the step classifies [Fast_v] AND the
          trailing drawdown over [fast_exit_lookback_bars] ≥
          [fast_exit_rate_pct].
        + {b T3 absolute floor} ([Absolute_floor]): the current close is below
          [(1 -. floor_drop_pct)] × the trailing-window high over
          [floor_peak_lookback_bars].
        + {b T2 slow-grind} ([Slow_grind]): the step classifies [Slow_grind] and
          has done so for [grind_confirm_weeks] consecutive steps.

        Otherwise [Hold], carrying the updated [grind_streak].
     }
    }

    {ul
     {- {b Out_of_market} — [post_exit_low] is first lowered to include the
        current close, then re-entry is checked by the exit reason (asymmetric
        re-entry):
        - After [Fast_crash] / [Absolute_floor]: [Re_enter] when the current
          close ≥ [post_exit_low] × [(1 +. fast_reentry_recover_pct)].
        - After [Slow_grind]: [Re_enter] when the current close is above the
          [slow_reentry_ma_weeks] MA {b and} that MA is rising (its value now
          exceeds its value [slow_reentry_ma_rising_lookback] bars earlier).

        Otherwise [Hold], carrying the lowered [post_exit_low]. Re-entry is
        fully self-contained: it never waits on an external macro flip (the GME
        [Portfolio_floor] anti-pattern this design deliberately avoids).
     }
    }

    Empty [index_bars] (no current bar) is a safe no-op: the state is returned
    unchanged with [Hold]. Pure and lookahead-free. *)
