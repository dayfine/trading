(** Pure fill decisions for one order against one bar's intraday path.

    Extracted from {!Engine} so that
    {i whether and at what price an order fills} is separable from the engine's
    order-processing orchestration. Every function here is pure: same path in,
    same answer out, no engine state.

    Natural slippage is modelled by path granularity (~390 points/day) rather
    than a spread model: a triggered stop fills at the {i observed} point price,
    not at the trigger price. *)

open Types

val would_fill_market : intraday_path -> fill_result option
(** Market orders fill at the first point on the path (the open). [None] only
    for an empty path. *)

val would_fill_limit :
  path:intraday_path ->
  side:Trading_base.Types.side ->
  limit_price:float ->
  fill_result option
(** Fills at the limit price when the path crosses it — conservative, so the
    modelled price is never better than the limit. *)

val would_fill_stop :
  path:intraday_path ->
  side:Trading_base.Types.side ->
  stop_price:float ->
  fill_result option
(** Fills at the observed point price once the stop triggers (natural slippage),
    not at [stop_price]. *)

(** Outcome of evaluating a StopLimit against one bar's path.

    The two non-fill cases are deliberately {b not} interchangeable:
    [Stop_not_triggered] means the market never reached the trigger, whereas
    [Limit_blocked] means it {i did} trade through the trigger and then ran past
    the limit. For an entry ticket carrying [entry_extension_max_pct], the limit
    {i is} the do-not-chase cap, so only [Limit_blocked] is a cost of that cap.
    They are separated at the one point that can tell the difference rather than
    re-derived by callers. *)
type stop_limit_outcome =
  | Fills of fill_result
  | Stop_not_triggered
  | Limit_blocked

val classify_stop_limit :
  path:intraday_path ->
  side:Trading_base.Types.side ->
  stop_price:float ->
  limit_price:float ->
  stop_limit_outcome
(** Two-stage: the stop must trigger, then the limit must be reachable. When the
    trigger price itself meets the limit the fill is at the trigger price;
    otherwise the remainder of the path is searched for the limit.

    This is the only StopLimit predicate exported: a caller that wants a plain
    [fill_result option] collapses [Fills] itself, keeping the {i reason} for a
    non-fill available at the one place that can still tell the difference. *)
