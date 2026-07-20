(** Entry-candidate assembly: the single seam where the per-candidate entry
    gates compose before the entry walk.

    Pipeline: {!Short_side_gate.combine} (short-side enable + short-min-price) →
    {!Declining_ma_gate.filter} (drop misclassified declining-MA longs,
    default-off) → {!Entry_liquidity_gate.apply} (dollar-ADV gate, default-off)
    → {!Short_borrow_gate.apply} (short-side borrow-availability ADV floor,
    margin M3a, default-off). With every gate at its no-op default the result is
    the plain [buy_candidates @ short_candidates], bit-identical to prior
    behaviour. *)

val assemble :
  config:Weinstein_strategy_config.config ->
  bar_reader:Bar_reader.t ->
  current_date:Core.Date.t ->
  Screener.result ->
  Screener.scored_candidate list
(** [assemble ~config ~bar_reader ~current_date screen_result] runs the gate
    pipeline over [screen_result]'s buy + short candidates and returns the final
    ordered entry-candidate list. *)
