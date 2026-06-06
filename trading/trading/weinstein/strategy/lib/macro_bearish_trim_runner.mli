(** Macro-bearish held-exposure trim — caps total held {e long} exposure when
    the macro tape is confirmed Bearish, trimming the excess weakest-RS-first.

    {1 Motivation}

    Weinstein's macro gate (spine item #6) is normally an {e entry} filter: a
    Bearish tape blocks new long entries. Held longs, however, only exit via
    their own stops / Stage-3 / drawdown force-liquidation — so on a slow
    distribution top (2000, 2008) the gate turns Bearish months before the
    waterfall while existing longs ride all the way down to their individual
    stops. That lag is the bulk of the deep-window drawdown.

    This runner closes that gap. It extends the macro gate from "block buys" to
    "also raise cash": on a Bearish tape it caps total held long exposure at a
    (tighter) fraction of portfolio value and exits the excess. It is a faithful
    {e exit-aggressiveness} dial — Weinstein explicitly says to raise cash / get
    defensive when the major trend turns down
    ([docs/design/weinstein-book-reference.md] §Macro Analysis, §Stage 4). Plan:
    [dev/plans/macro-bearish-exposure-trim-2026-06-06.md].

    {1 Side & ordering}

    Long positions only. Shorts are never trimmed — a bearish tape is their
    natural environment, and capping {e long} exposure says nothing about the
    short book. Among the held longs, the weakest-RS positions are exited first
    (the trim keeps the relative-strength leaders, per Weinstein's RS-selection
    principle), until held long exposure is at or below the cap.

    {1 Re-entry is naturally damped (anti-whipsaw)}

    The runner only {e trims}; it never force-buys. Coming back requires the
    normal Stage-2 breakout + volume screen, so a Bearish→Bullish whipsaw does
    not auto-rebuy — re-entry is gated by the ordinary entry criteria.

    {1 Cadence & gating}

    The {e caller} is responsible for gating: this runner is invoked only when
    [config.enable_macro_bearish_exposure_trim = true], the macro trend is
    [Bearish], and it is a screening (Friday) day. The runner itself is a pure
    function of its inputs — it does not re-check the macro trend or the
    calendar. Modelled on {!Force_liquidation_runner} (portfolio-wide,
    threshold-triggered, emits [TriggerExit]s, integrates with the single-exit
    collision rules) but driven by the {e predictive} macro gate rather than the
    {e reactive} drawdown floor. *)

open Core
open Trading_strategy

val update :
  max_long_exposure_pct:float ->
  portfolio_value:float ->
  positions:Position.t Map.M(String).t ->
  get_price:Strategy_interface.get_price_fn ->
  rs_ranking:(Position.t -> float option) ->
  skip_position_ids:String.Set.t ->
  current_date:Core.Date.t ->
  Position.transition list
(** [update] caps total held long exposure at
    [max_long_exposure_pct * portfolio_value] and returns [TriggerExit]
    transitions trimming the excess, weakest-RS-first.

    {2 Behaviour}

    - Returns [[]] when [portfolio_value <= 0.0] (degenerate snapshot — no
      meaningful cap can be derived).
    - Computes [held] = the signed long market value of every held long
      [Holding] position that has a price this tick. Shorts, non-Holding states,
      and symbols without a price are excluded from [held] and never trimmed.
    - Returns [[]] when [held <= max_long_exposure_pct * portfolio_value] —
      already at or under the cap, nothing to do. [max_long_exposure_pct = 1.0]
      (or higher) is therefore a no-op; [0.0] flattens the entire long book.
    - Otherwise orders the trimmable longs by [rs_ranking] ascending (lowest =
      weakest, exited first) and emits a full-position [TriggerExit] for each in
      turn, subtracting its market value from the running held total, until the
      remaining held long exposure is at or below the cap.

    {2 Collision with earlier exits}

    A position whose [position_id] is in [skip_position_ids] — already exiting
    this tick via a stop / Stage-3 / laggard / force-liquidation channel — is
    excluded from the candidate set and never double-exited. The caller passes
    the union of all earlier-channel exit ids. Its market value is also excluded
    from [held] (an already-exiting long is no longer held exposure to cap).

    {2 RS ranking}

    [rs_ranking pos] returns the position's relative-strength score (lower =
    weaker). A position for which [rs_ranking] returns [None] (insufficient bar
    history to rank) is {e excluded} from trimming — it cannot be ordered
    against the others, so the runner leaves it held rather than exiting it
    arbitrarily. Its market value is likewise excluded from [held].

    {2 Exit semantics}

    Each emitted [TriggerExit] closes the {e entire} position at the current
    bar's close ([exit_price = bar.close_price]), with
    [exit_reason = StrategySignal { label = "macro_bearish_trim"; detail = None
     }]. Never emits a buy / entry transition. Empty list when no trim is needed
    — the common case (most days are not Bearish). *)
