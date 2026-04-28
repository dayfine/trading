(** Aggregator computing {!Optimal_types.optimal_summary} metrics over a list of
    {!Optimal_types.optimal_round_trip}.

    Pure function. Inputs:
    - The list of closed round-trips produced by
      {!Optimal_portfolio_filler.fill}.
    - The [starting_cash] used for the fill — needed to express
      [total_return_pct] as a fraction of starting capital and to compute the
      equity-curve drawdown.
    - The {!Optimal_types.variant_label} the round-trips were filled under;
      stamped onto the output summary.

    Metric definitions match the {!Optimal_types.optimal_summary} doc comments
    verbatim — see those for the per-metric formulas.

    See [dev/plans/optimal-strategy-counterfactual-2026-04-28.md] §Phase C +
    §Phase D headline comparison table. *)

val summarize :
  starting_cash:float ->
  variant:Optimal_types.variant_label ->
  Optimal_types.optimal_round_trip list ->
  Optimal_types.optimal_summary
(** [summarize ~starting_cash ~variant round_trips] aggregates the round-trips
    into an {!Optimal_types.optimal_summary}.

    Empty [round_trips] returns a zero summary — every metric is [0.0] or [0]
    except [profit_factor] which is [Float.infinity] (no losers, no winners
    either; consistent with the "infinite when no losers" rule).

    {b Drawdown computation.} The equity curve advances on a per-round-trip
    basis: [equity_after(i) = starting_cash + sum_{j<=i} pnl_dollars(j)] over
    round-trips ordered by [exit_week]. The drawdown is the peak-to-trough
    fraction of peak equity. Round-trips with the same [exit_week] are batched
    and applied together — the order of P&L application within a Friday does not
    change the equity curve's peak / trough.

    Pure function. *)
