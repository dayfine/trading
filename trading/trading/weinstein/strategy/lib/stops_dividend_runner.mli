(** Per-tick ex-dividend reduction of held longs' stop levels (issue #3174).

    The Weinstein stop state is the strategy's model of a resting protective
    order, kept as an absolute raw-price level. On a cash dividend's ex-date
    the raw price opens lower by the dividend, so a stop left where it was can
    trigger on a drop the holder was paid for (AD 2025-08-20, $23.00 special:
    stop 67.46, open 51.26). A broker reduces a resting sell-stop by the
    dividend on the ex-date (FINRA Rule 5330); this module does the same to the
    strategy's stop state, through the reader's {!Bar_reader.ex_dividend_stops}
    ({!Ex_dividend_stop} holds the rule and the vendor dividends).

    {b Scope.} Long positions in [Holding] only. A short's protective stop is a
    buy stop, which FINRA 5330 does not adjust: the ex-date drop moves the
    price away from it. Only [stop_level] moves; the trail's reference prices
    (extremes, MA) are left as they are, as a broker adjusts the order, not
    the holder's notes. This lowers a stop, which the trail itself never does
    (L2); it is an order adjustment by the broker, not a strategy decision.

    {b Window.} For [as_of]'s tick, the ex-dates in [(prev, as_of_bar]], where
    [as_of_bar] is the symbol's latest bar on or before [as_of] and [prev] the
    later of the bar before it and the position's [entry_date] (a stop placed
    after an ex-date open already sits on ex-dividend prices). The strategy
    runs once per trading day, so each ex-date falls in exactly one tick's
    window.

    The strategy invokes {!adjust} after {!Stops_split_runner.adjust} and
    before [Stops_runner.update] reads [stop_states]. With no reducer on the
    reader (the default) it does nothing. *)

open Core
open Trading_strategy

val with_stop_level :
  Weinstein_stops.stop_state -> float -> Weinstein_stops.stop_state
(** [with_stop_level state level] is [state] with its [stop_level] replaced by
    [level]; every other field is unchanged. *)

val adjust :
  positions:Position.t Map.M(String).t ->
  stop_states:Weinstein_stops.stop_state Map.M(String).t ref ->
  bar_reader:Bar_reader.t ->
  as_of:Date.t ->
  unit
(** [adjust ~positions ~stop_states ~bar_reader ~as_of] reduces, in place, the
    [stop_states] entry of every held long whose symbol went ex-dividend in this
    tick's window (see the module doc). No-op when the reader carries no
    {!Bar_reader.ex_dividend_stops}, for shorts, for positions not [Holding],
    for symbols with no stop entry or fewer than two bars, and when no ex-date
    falls in the window. Never emits transitions. *)
