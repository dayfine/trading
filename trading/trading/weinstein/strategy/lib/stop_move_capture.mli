(** Observability for stop moves that no transition carries (issue #2974).

    {!Stops_runner.update} advances each held ticker's stop state machine and
    reports a moved stop as an [UpdateRiskParams] adjust — except for
    [Weinstein_stops.Entered_tightening], which installs the tightened level in
    [stop_states] (where the next bar's trigger check enforces it) without
    emitting any transition. The per-trade stop log only sees transitions, so
    those moves were invisible in [trades.csv]'s [n_stop_raises] / [max_stop].

    This module recovers them by diffing the stop levels [stop_states] held
    immediately before and after the stops runner, and handing every held
    position whose level moved {b without} an adjust (or exit) transition of its
    own to {!Audit_recorder.t.record_stop_move}.

    Pure observability: it reads the two maps and the runner's output, writes
    nothing the strategy reads, and changes no transition. *)

open Core
open Trading_strategy

val silent_moves :
  positions:Position.t Map.M(String).t ->
  before:Weinstein_stops.stop_state Map.M(String).t ->
  after:Weinstein_stops.stop_state Map.M(String).t ->
  reported:Position.transition list ->
  current_date:Date.t ->
  Audit_recorder.stop_move_event list
(** One event per [Holding] position in [positions] whose ticker's stop level in
    [after] differs from its level in [before], unless [reported] (the stops
    runner's exit and adjust transitions for this bar) already carries a
    transition for that position id. A ticker absent from either map yields no
    event. [stop_level] is the [after] level; [date] is [current_date].

    Positions not in [Holding] are skipped even when they share a moved ticker
    with a held sibling: the runner only advances the machine for held
    positions, so the move belongs to the holding.

    Output order follows [positions]' key order. *)

val emit :
  audit_recorder:Audit_recorder.t ->
  positions:Position.t Map.M(String).t ->
  before:Weinstein_stops.stop_state Map.M(String).t ->
  after:Weinstein_stops.stop_state Map.M(String).t ->
  reported:Position.transition list ->
  current_date:Date.t ->
  unit
(** [emit] is {!silent_moves} fed event-by-event to
    [audit_recorder.record_stop_move]. With {!Audit_recorder.noop} the events
    are computed and dropped. *)
