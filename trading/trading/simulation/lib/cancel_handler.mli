(** Cancel-entry transition builder + applier — extracted from the simulator so
    the file stays under its declared-large size limit.

    When a fill is rejected by [Portfolio.apply_single_trade] (typically on
    insufficient cash from a next-day-open gap-up that exceeds the strategy's
    sizing headroom), the corresponding [Entering] position stays stuck with 0
    fills. Strategies whose entry-idempotency check excludes only [Closed] (e.g.
    BAH's [_has_position_for_symbol]) then never retry. The simulator works
    around that by emitting a [CancelEntry] transition for each rejected trade
    so the position transitions to [Closed] and the strategy can retry from a
    clean slate on the next market close.

    See PR #1172 follow-up §"Option B" for the failure mode this handler
    surfaces and the BAH gap-buffer fix (#1172) for the related sizing-side
    workaround that closes the common (small-gap) case. *)

open Core
module Position = Trading_strategy.Position

val transitions_for_rejected_trades :
  date:Date.t ->
  positions:Position.t String.Map.t ->
  rejected_trades:Trading_base.Types.trade list ->
  Position.transition list
(** [transitions_for_rejected_trades ~date ~positions ~rejected_trades] emits
    one [CancelEntry] transition per rejected trade, matched by symbol against
    the [Entering] positions in [positions]. Rejected trades whose symbol has no
    [Entering] match are silently skipped (defensive — should not happen given
    the strategy invariant). *)

val apply_to_positions :
  Position.t String.Map.t ->
  Position.transition ->
  Position.t String.Map.t Status.status_or
(** [apply_to_positions positions trans] applies a [CancelEntry] transition to
    [positions] via [Position.apply_transition]. Drops the position from the map
    when it reaches the terminal [Closed] state — same convention used by the
    simulator for [TriggerExit] under [_set_or_drop_if_closed].

    Returns the original map unchanged when the transition's position_id has no
    entry in [positions] (defensive — same shape as the simulator's
    [_apply_trigger_exit]). *)
