(** The strategy's whole long-entry macro gate, in one place.

    Two consumers must ask the identical question of the identical tape: the
    cascade (which reads the gate through the flags
    {!Weinstein_strategy_screening} projects onto [Screener.config]) and the F2
    resting-ticket re-screen (which re-asks it directly, because a symbol
    resting an unfilled ticket is held and so never appears in the cascade's
    candidate list). Whenever the two drift, a resting ticket quietly survives a
    tape that rejects every fresh candidate.

    This module is that single question, expressed once against a
    {!Weinstein_strategy_config.config} and a {!Macro.result}. It owns no
    semantics of its own — every conjunct lives in {!Screener_macro_gate}, and
    all of them are default-off, so at [default_config] this is exactly
    [Screener.longs_admitted_by_macro ~neutral_blocks_longs:false macro.trend].

    Sibling of {!Decline_character_wiring}, which plays the same thin-adapter
    role for the short side's slow-grind gate. *)

val admits :
  config:Weinstein_strategy_config.config -> macro_result:Macro.result -> bool
(** Whether the macro tape admits a new {b long} entry this week.

    Three conjuncts, all pure:
    - the three-state gate on [macro_result.trend]
      ([config.neutral_blocks_longs]),
    - the [Deteriorating] breadth conjunct on [macro_result.breadth_state]
      ([config.deteriorating_blocks_longs], issue #2755),
    - the Stage-4 index veto on [macro_result.index_stage.stage]
      ([config.index_stage_veto_blocks_longs], book §2.1 "Resolved 2026-09-16").

    The short side is untouched — {!Screener.shorts_admitted_by_macro} answers
    that question separately. *)
