(** Stage-3 force-exit runner — wires {!Stage3_force_exit} into the Weinstein
    strategy.

    Capital-recycling exit per Weinstein Ch. 6 §5.2 (STAGE3_TIGHTENING) extended
    to a full exit. Issue #872, framing note
    [dev/notes/capital-recycling-framing-2026-05-06.md].

    {1 Cadence}

    Fires only on Friday (weekly cadence). The detector reads per-position stage
    classifications written into [prior_stages] by {!Stops_runner.update} on the
    same tick. On non-Friday calls the runner is a no-op — avoids intra-week
    noise from daily-cadence classifications.

    {1 Side & ordering}

    Long positions only. Short positions never trigger this exit; their stage
    semantics for "topping" differ (see book §6.3) and short-side capital
    recycling has separate gaps.

    Invoked AFTER {!Stops_runner.update} (so stop-outs have priority — a
    position already exiting via a stop hit is not re-exited under Stage 3) and
    BEFORE the entry walk + {!Force_liquidation_runner.update} on the same tick
    (so freed cash is visible to the entry walk). *)

open Core
open Trading_strategy

val update :
  config:Stage3_force_exit.config ->
  is_screening_day:bool ->
  positions:Position.t Map.M(String).t ->
  get_price:Strategy_interface.get_price_fn ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  stage3_streaks:int Hashtbl.M(String).t ->
  stop_exit_position_ids:String.Set.t ->
  current_date:Core.Date.t ->
  Position.transition list
(** [update] iterates over every held long {!Position.t} and runs the Stage-3
    force-exit detector, returning a list of [TriggerExit] transitions for
    positions whose detector decision is [Force_exit].

    {2 Behaviour}

    - Returns [[]] when [is_screening_day = false]. The detector runs at weekly
      cadence only.
    - Returns [[]] when [positions] is empty.
    - For each held long position with a {!Position.Holding} state: 1. Reads the
      current stage from [prior_stages]; falls back to no-op when the symbol is
      missing (typical on a position's first tick or when MA warmup hasn't
      completed). 2. Calls {!Stage3_force_exit.observe_position} — the detector
      mutates [stage3_streaks] in place to maintain the consecutive-Stage-3
      count. 3. On [Force_exit { weeks_in_stage3 }]:
    - Skips the position if its [position_id] is in [stop_exit_position_ids] —
      the stops runner already exited it this tick.
    - Otherwise emits a [TriggerExit] transition with
      [exit_reason = Stage3ForceExit { weeks_in_stage3 }] and
      [exit_price = bar.close_price] from [get_price]. When [get_price] returns
      [None] the position is silently skipped.
    - Short positions and non-Holding states are skipped without emitting, and
      their entry in [stage3_streaks] is left untouched. This keeps the streak
      counter accurate if the position later transitions back into Holding.

    {2 Mutates}

    - [stage3_streaks] — the per-symbol consecutive-Stage-3 count is updated in
      place via {!Stage3_force_exit.observe_position}. Each call advances the
      count by one on a Stage-3 read or resets it to zero on any non-Stage-3
      read. *)
