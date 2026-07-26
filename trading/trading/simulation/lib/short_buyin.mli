(** Deterministic short-side buy-in stress-path mode (levered long-short margin
    realism, M3b).

    Models the worst-case squeeze cost for a levered long-short config: when a
    short is hard-to-borrow (HTB), the lender can recall the borrowed shares at
    any time, forcing the trader to buy the position back ("buy-in") at whatever
    price the market is offering. This module force-covers {b every} held short
    that is HTB at its current mark on the next weekly close — the deterministic
    {b upper bound} on buy-in cost, for the M4 promotion-grid stress cells.

    {1 Deterministic, not probabilistic}

    There is no seeded RNG and no sampled cover: the promotion grid wants the
    single worst-case path (every HTB borrow recalled), not a distribution over
    sampled paths, and every analysis function must be pure / reproducible. Same
    portfolio + same config → same covers, always. This is the {e stress-path}
    branch chosen over a probabilistic forced-cover.

    {1 HTB definition}

    A short is HTB when its mark is strictly below the configured
    {!Trading_portfolio.Margin_config.short_buyin_htb_price_below} and the mode
    {!Trading_portfolio.Margin_config.short_buyin_stress_mode} is armed; see
    {!Trading_portfolio.Margin_config.is_buyin_htb}. A default / disarmed config
    marks nothing HTB, so the mechanism is a bit-equal no-op (R1). The threshold
    is deliberately decoupled from the M3a maintenance / borrow tier tables: a
    share recall can hit a name comfortably above its maintenance requirement,
    so the stress cell varies "which shorts get bought in" orthogonally to the
    leverage / maintenance dials.

    {1 Cadence + bar-cadence caveat}

    Weekly-close (Friday) only, matching the strategy spine and the short-side
    maintenance force-cover / M2 long-reduce cadence.
    {b Bar-cadence limitation:} marks are daily closes, so this cannot observe
    an intraweek gap-through-recall — a Monday-to-Thursday squeeze is only
    covered at Friday's close. Modelling those gap paths is M4 stress-path
    territory, not this runner.

    {1 Exit tag}

    Every forced cover carries
    [exit_reason = StrategySignal { label = "buyin_stress"; detail = Some
     "<key=value>" }] so forensics / trades.csv separate buy-ins from strategy
    exits, short-maintenance force-covers ([margin_call]) and long-maintenance
    reduces ([maintenance_reduce]). [exit_price] is the symbol's mark.

    Authority: [dev/plans/levered-longshort-margin-realism-2026-07-14.md] §M3
    (buy-in risk). *)

open Core
module Margin_config = Trading_portfolio.Margin_config
module Position = Trading_strategy.Position

type short_holding = {
  position_id : string;
  symbol : string;
  mark : float;  (** Today's close for the symbol. *)
}
(** A held short marked at today's close — the unit force-covered on a buy-in.
    Exposed so the HTB selection can be pinned directly with plain data. *)

val select_buyins :
  margin_config:Margin_config.t ->
  holdings:short_holding list ->
  short_holding list
(** The sublist of [holdings] that are hard-to-borrow at their mark
    ({!Trading_portfolio.Margin_config.is_buyin_htb}) and therefore
    force-covered. Returns [[]] when the mode is disarmed or the HTB threshold
    is [0.0] (R1). Preserves the input order (the caller orders positions
    deterministically). Pure. *)

val buyin_stress_transitions :
  margin_config:Margin_config.t ->
  positions:Position.t String.Map.t ->
  prices:(string * float) list ->
  date:Date.t ->
  Position.transition list
(** Build [TriggerExit] transitions tagged [buyin_stress] for every held short
    that {!select_buyins} flags on a weekly (Friday) close. Returns [[]] when
    [date] is not a Friday, when
    {!Trading_portfolio.Margin_config.short_buyin_stress_mode} is [false] (R1),
    when there are no priced held shorts, or when none are HTB. [exit_price]
    equals the symbol's mark. *)
