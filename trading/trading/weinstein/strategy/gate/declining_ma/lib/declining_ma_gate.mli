(** Long-entry faithfulness gate: drop long candidates whose 30-week MA is still
    {b declining} at entry.

    Weinstein Stage 2 is defined as price above a {e rising} 30-week MA. The
    stage classifier nonetheless tags a minority of breakouts [Stage2] while the
    MA is still declining — these are counter-trend bounces inside a Stage-4
    downtrend (e.g. dead-cat bounces under a prior top). A broad top-3000 audit
    (2026-06-27) found such entries win only ~13% (avg P&L −0.1%) vs ~34%
    (+2.6%) for rising-MA entries.

    The gate {e tightens} the existing Stage-2-only buy rule toward the book's
    rising-MA definition — it removes misclassified entries, it does not add a
    new mechanism. Shorts are never touched (a declining MA is correct for a
    Stage-4 short). Default-off at the call site
    ([Weinstein_strategy_config.reject_declining_ma_long_entry]); with
    [reject = false] this is the identity, so the entry candidate list is
    bit-identical to prior behaviour. *)

val filter :
  reject:bool ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** [filter ~reject candidates] returns [candidates] unchanged when
    [reject = false]. When [reject = true], drops every [Long] candidate whose
    [analysis.stage.ma_direction] is [Weinstein_types.Declining]; [Rising] /
    [Flat] longs and all [Short] candidates are retained, in order. *)
