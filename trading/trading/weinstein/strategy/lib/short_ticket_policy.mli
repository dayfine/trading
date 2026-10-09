(** Shorts Phase B v1 (#3218) — short-side-only resting-ticket policy.

    Two default-off levers over {!Entry_ticket_ttl}'s resting-ticket lifecycle,
    both {b short side only}:

    - [short_cancel_on_non_bearish]: when the weekly macro read is no longer
      Bearish, every resting short entry ticket is {b cancelled} (not suspended)
      with {!cancel_reason}. Mirrors the long-side [entry_ticket_macro_suspend]
      idea. Book authority: [docs/design/weinstein-book-reference.md] §6.1 item
      1 — a short needs a bearish market (DJI Stage 4, long-term indicators
      negative); a ticket resting through a Neutral/Bullish week has lost that
      premise.
    - [short_entry_order_max_rest_weeks]: a short-only override of
      [entry_order_max_rest_weeks]; [None] inherits the long value (no-op). §6.2
      notes shorts are entered on the breakdown and pullbacks are rarer, so a
      short setup goes stale faster than a long one. The number itself is a
      {b BOOK-NEUTRAL dial}.

    Covering open shorts on a Bullish read is {b NOT} proposed here — this
    module only touches unfilled tickets. Long tickets are never touched. *)

open Core
module Position = Trading_strategy.Position

val cancel_reason : string
(** ["entry_ticket_short_macro_not_bearish"] — the [CancelEntry] reason, a
    member of the trade audit's closed cancel-reason list. *)

val macro_cancellations :
  positions:Position.t String.Map.t ->
  current_date:Date.t ->
  Position.transition list
(** One [CancelEntry] ({!cancel_reason}) per resting short ticket: [Entering]
    with [filled_quantity = 0.0] and side [Short], in key order. Partially
    filled shorts, long tickets and non-[Entering] positions are skipped. The
    caller decides whether the macro read warrants calling this. *)

val partition_by_side :
  Position.t String.Map.t -> Position.t String.Map.t * Position.t String.Map.t
(** [(longs, shorts)] — splits a position map by side so each half can run
    {!Entry_ticket_ttl} with its own rest limit. *)

val armed : Weinstein_strategy_config.config -> bool
(** [true] when any resting-ticket cancel is armed: the re-screen, a positive
    long clock, or either #3218 short lever. [false] means {!run} is a no-op, so
    the caller skips building its [still_qualifies] predicate (R1). *)

val run :
  Weinstein_strategy_config.config ->
  macro_result:Macro.result ->
  pending_entry_e:Entry_freeze.t ->
  positions:Position.t String.Map.t ->
  still_qualifies:(symbol:string -> side:Position.position_side -> bool) ->
  current_date:Date.t ->
  Position.transition list
(** The F2 resting-ticket cancels with the #3218 short levers folded in: first
    {!macro_cancellations} when [short_cancel_on_non_bearish] is set and the
    macro trend is not Bearish (each cancelled symbol's frozen [E] is released),
    then {!Entry_ticket_ttl.run} over the remaining positions — one pass, or
    longs at [entry_order_max_rest_weeks] and shorts at
    [short_entry_order_max_rest_weeks] when that override is [Some]. With both
    levers at their defaults this is exactly [Entry_ticket_ttl.run]. *)
