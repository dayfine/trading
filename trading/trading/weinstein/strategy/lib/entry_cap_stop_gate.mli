(** Stop gate on the uncapped trigger
    ([Weinstein_strategy_config.entry_cap_stop_gate_on_uncapped], which carries
    the full contract): an attribution control for the stale-entry cap
    ({!Stale_entry_cap}). The cap lowers a long's trigger [E] to [E′], and a
    support floor more than 15 % below [E] can sit within 15 % of [E′], so the
    capped arm places names the record skips at the stop gate. With the flag,
    the stop-width decisions (the §5.1 re-anchor test,
    [require_structural_stop], the [max_stop_distance_pct] gate, the
    [Demote_over_max] ordering) are computed on the stop the ticket would
    install at [E], so they match the cap-off arm's. The trigger, the installed
    stop and the size follow [E′]. Run:
    [dev/experiments/stale-e-cap-k5-2026-11-14/README.md] (PR #3608), channel 5.

    {b Faithfulness (W1/W2).} [docs/design/weinstein-book-reference.md] §4.7
    (the buy-stop at the top of the current range: the cap) and §5.1 "Initial
    Stop Placement" (pass on a name whose stop needs more than 15 % risk). The
    flag changes only which [E] that test reads, a dial; no spine item moves.
    §5.1 measures from the purchase price, [E′] under the cap, so this is a
    control, not a more faithful gate. *)

val gate_entry :
  config:Weinstein_strategy_config.config ->
  Screener.scored_candidate ->
  float option
(** [gate_entry ~config cand] is [Some e] when the flag applies to [cand], and
    [e] is the trigger [cand] would have with the cap off. It is [None] in every
    other case, and the stop-width decisions then read the ticket's own entry
    exactly as before. The flag applies when all of these hold:
    - [config.entry_cap_stop_gate_on_uncapped] and
      [config.entry_cap_local_range_weeks > 0];
    - the entry is the trigger: [sim_entry_trigger_at_suggested] and
      [enable_sim_entry_stoplimit] (otherwise the entry is the decision close in
      both arms, and the cap never reaches it);
    - [cand] is a long whose ticket the cap lowered: its arm is
      [Local_range_top] and it has a [breakout_price]. With the replace anchor
      off, that arm fires only when the cap bound.

    [e] is [Screener.suggested_entry] of [breakout_price] with
    [screening_config.candidate_params.entry_buffer_pct]: the screener's own
    rounding and buffer on the anchor it uses with the cap off. Pure. *)

val validate : Weinstein_strategy_config.config -> unit
(** Fail when the flag and the cap are armed together with a ticket transform
    whose cap-off trigger the candidate does not carry:
    - the replace anchor ([entry_anchor_local_range_weeks > 0]): the capped
      ticket is [min] of the replace anchor and the cap's top, and the uncapped
      replace anchor is not kept;
    - the entry freeze ([freeze_entry_at_first_breakout]): the pinned [E] is the
      first week's, and its cap-off value is not kept.

    A no-op for a default config, and whenever the flag or the cap is off. *)
