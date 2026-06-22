(** Fast-crash absolute stop (Build 2,
    dev/notes/decline-character-exploration-2026-06-21-PM.md).

    An {b absolute} drop from the position's trailing high that fires faster
    than the structural MA/correction-low trailing stop in a fast crash. It is
    explicit tail-RISK insurance, dormant ([~armed = false]) in normal times, so
    it does not tax the let-winners-run fat tail
    ([.claude/rules/weinstein-faithful-core.md]). Gated on the
    [Stop_types.config.catastrophic_stop_pct] knob; default [0.0] is an exact
    no-op.

    This lib stays macro-AGNOSTIC: the [Slow_grind | Fast_v] decision is made
    one level up in the strategy lib and passed in as a plain [~armed:bool]. *)

open Trading_base.Types

val trailing_high_of_state : Stop_types.stop_state -> float option
(** [Some] the stop state's trailing high — the rally peak for a long, the
    decline trough for a short ([last_trend_extreme]). Only
    {!Stop_types.Trailing} carries one; {!Stop_types.Initial} and
    {!Stop_types.Tightened} return [None] (no trend leg has been tracked yet).
    This is the [trailing_high] input to {!check_hit}: when it is [None] the
    fast-crash absolute stop is dormant for that position. *)

val check_hit :
  armed:bool ->
  pct:float ->
  trailing_high:float ->
  bar:Types.Daily_price.t ->
  side:position_side ->
  bool
(** [true] when the fast-crash absolute stop fires for this bar.

    Returns [false] (no-op) unless {b both}:
    - [armed] is [true] — the position's market is in a fast-V decline. The
      arming decision is made in the strategy lib (from
      {!Decline_character.Fast_v}) so this lib stays macro-agnostic. [armed]
      defaults to [false] at every existing call site, so the mechanism is
      dormant by default.
    - [pct > 0.0] — the [Stop_types.config.catastrophic_stop_pct] knob is
      enabled. At the default [0.0] the stop never fires.

    When both hold, fires when a long's [bar.low ≤ trailing_high *. (1. -. pct)]
    or a short's [bar.high ≥ trailing_high *. (1. +. pct)] — the intra-bar
    extreme in the against-position direction, mirroring the GTC structural
    stop's intra-bar trigger. Pure: same inputs always produce the same result.
*)
