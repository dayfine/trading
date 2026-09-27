(** Emit one {!Weinstein_stops.Stop_decision.t} per held position from the
    per-ticker advance steps {!Stops_runner.update} memoised on this tick
    (issue #2977).

    Observability only: reads the memo and the positions, calls the sink, and
    returns nothing — no stop state, transition or position is touched. Split
    out of {!Stops_runner} so the runner stays a stop-decision loop and the
    sampling rule lives in one place. *)

open Core
open Trading_strategy

val emit :
  on_stop_decision:(Weinstein_stops.Stop_decision.t -> unit) ->
  stops_config:Weinstein_stops.config ->
  is_week_close:bool ->
  positions:Position.t Map.M(String).t ->
  advanced:(string, Weinstein_stops.Stop_decision.step) Hashtbl.t ->
  unit
(** For every [Holding] position (in [positions] key order) whose ticker has an
    entry in [advanced] — i.e. whose state machine advanced on this tick —
    build its record with {!Weinstein_stops.Stop_decision.make} (the
    position's own [id] and [side]) and pass it to [on_stop_decision], subject
    to one sampling rule: a hold ({!Weinstein_stops.Stop_decision.is_hold}) is
    emitted only when [is_week_close]; every other decision is always emitted.
    Positions not [Holding], or with no advance on this tick, emit nothing. *)
