(** Entry-candidate assembly: the single seam where the per-candidate entry
    gates compose before the entry walk.

    Pipeline: {!Short_side_gate.combine} (short-side enable + short-min-price) →
    {!Declining_ma_gate.filter} (drop misclassified declining-MA longs,
    default-off) → {!Entry_liquidity_gate.apply} (dollar-ADV gate, default-off)
    → {!Short_borrow_gate.apply} (short-side borrow-availability ADV floor,
    margin M3a, default-off) → {!Entry_recency_gate.apply} (drop candidates
    whose latest daily bar is stale, issue #2672, default-off) →
    {!Delisted_entry_gate.apply} (drop candidates whose warehouse delisting
    marker has already passed, issue #2693, {b unconditional} — no config field,
    because the marker is data rather than a tuning choice; a no-op on any
    warehouse that carries no [active_through]). With every flagged gate at its
    no-op default and a marker-free warehouse, the result is the plain
    [buy_candidates @ short_candidates], bit-identical to prior behaviour. *)

val assemble :
  config:Weinstein_strategy_config.config ->
  bar_reader:Bar_reader.t ->
  current_date:Core.Date.t ->
  Screener.result ->
  Screener.scored_candidate list
(** [assemble ~config ~bar_reader ~current_date screen_result] runs the gate
    pipeline over [screen_result]'s buy + short candidates and returns the final
    ordered entry-candidate list. *)
