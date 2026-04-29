(** Apply a stock-split factor to a {!Stop_types.stop_state}.

    The Weinstein stop state machine carries every reference price as an
    {b absolute} dollar amount: [stop_level], [reference_level],
    [last_correction_extreme], [last_trend_extreme], and [ma_at_last_adjustment]
    are all economic prices that must rescale in lockstep with the broker-side
    share count when the issuer splits.

    Without this adjustment a 4:1 forward split on a position with a pre-split
    [stop_level] of $440 would leave the stop at $440 even though the post-split
    bar's [low_price] is around $110, causing {!Weinstein_stops.check_stop_hit}
    to fire spuriously on the first post-split bar — an exit on a phantom drop
    that has zero economic meaning.

    Direction. [factor] is the split's [new_shares /. old_shares] ratio,
    matching {!Trading_portfolio.Split_event.t.factor}: [4.0] for a 4:1 forward
    split, [0.2] for a 1:5 reverse split. Every absolute price in the state is
    divided by [factor] (equivalently, multiplied by the inverse): a 4:1 split
    shrinks $440 to $110; a 1:5 reverse split grows $20 to $100. The non-price
    fields ([correction_count], [reason]) pass through unchanged.

    Long vs. Short. The stop_state carries the same field shape for both sides —
    only the {e interpretation} differs ([reference_level] is a support floor
    for longs, a resistance ceiling for shorts; the trailing extremes flip too).
    On a split every absolute price scales the same way regardless of side:
    [factor > 0] is enforced by the issuer, and the side-specific semantics are
    preserved post-scale. The function is therefore side-agnostic.

    Pure: returns a new state. The caller (typically the strategy) is
    responsible for swapping the new state into [stop_states]. *)

val scale : factor:float -> Stop_types.stop_state -> Stop_types.stop_state
(** [scale ~factor state] returns a new {!Stop_types.stop_state} with every
    absolute price field divided by [factor]. See the module-level docs for the
    contract.

    @raise Invalid_argument
      if [factor <= 0.0] — splits multiply share counts by a positive ratio, so
      a non-positive factor cannot represent a real corporate action. *)
