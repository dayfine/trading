open Types

(** Underneath-support mapping for Weinstein breakdown grading (short side).

    Mirror of {!Resistance} for the short-side cascade: where {!Resistance}
    measures trapped buyers {b above} a long-side breakout price, {!Support}
    measures trapped longs {b below} a short-side breakdown price — i.e. where
    prior buyers sit waiting for a bounce.

    Per Weinstein's Short Entry Checklist: a strong short setup has minimal
    nearby support below the breakdown point — a steep prior advance with small
    congestion is ideal. Heavy support below a breakdown means the decline will
    struggle through prior congestion zones (each acting as a temporary floor);
    minimal / virgin support below means the stock can fall freely.

    The grading reuses [overhead_quality] with a side-flipped semantic:
    - [Virgin_territory]: no prior trading {b below} this price. The stock has
      never traded down to this level (or hasn't in the virgin window). Most
      explosive downside potential.
    - [Clean]: no significant support on the chart. Minor old prior trading
      only.
    - [Moderate_resistance]: some prior trading below but not dense. The decline
      can punch through.
    - [Heavy_resistance]: dense prior trading zone just below the breakdown. The
      stock will use up selling pressure working through this zone.

    The shared variant name (overhead_quality) is intentional: the same four
    grades describe both directions, the only difference is whether the trapped
    traders are above (long) or below (short) the level. The screener attaches
    the side via context.

    All functions are pure. *)

type config = Resistance.config
(** Reuses {!Resistance.config} byte-for-byte. *)

val default_config : config
(** Same defaults as {!Resistance.default_config}. *)

type result = {
  quality : Weinstein_types.overhead_quality;
      (** Graded quality of below-breakdown support — see module-level doc. *)
  breakdown_price : float;  (** The price level being analysed. *)
}
(** Result of below-breakdown support analysis at a given breakdown price.

    Lighter than {!Resistance.result}: the screener only consumes [quality]
    today, so [zones] / [nearest_zone] are intentionally omitted to keep the
    surface area small. They can be added in a later PR if a future analysis
    needs the full zone list. *)

val analyze :
  config:config ->
  bars:Daily_price.t list ->
  breakdown_price:float ->
  as_of_date:Core.Date.t ->
  result
(** [analyze ~config ~bars ~breakdown_price ~as_of_date] grades support
    {b below} [breakdown_price].

    @param bars
      Price bars in chronological order (oldest first). Same window semantics as
      {!Resistance.analyze}: the last [virgin_lookback_bars] tail is used for
      the virgin check, the last [chart_lookback_bars] for zone density.
    @param breakdown_price The price level to grade support below.
    @param as_of_date Reference date used for zone-age computation.

    Pure function: same inputs always produce the same output.

    Implementation note: this is a thin wrapper over {!analyze_with_callbacks}.
    It builds a {!Resistance.callbacks} record via
    {!Resistance.callbacks_from_bars} and delegates. Behaviour is bit-identical
    to the callback API for the same underlying [bars]. *)

val analyze_with_callbacks :
  config:config ->
  callbacks:Resistance.callbacks ->
  breakdown_price:float ->
  as_of_date:Core.Date.t ->
  result
(** [analyze_with_callbacks ~config ~callbacks ~breakdown_price ~as_of_date] is
    the indicator-callback shape of {!analyze}. Reuses {!Resistance.callbacks}
    since both directions need the same per-bar fields (high, low, date) — only
    the comparison flips. Used by panel-backed callers that read bar fields via
    per-cell closures rather than walking a {!Daily_price.t list}.

    Walks two bar windows back from the newest bar (offset 0):
    - the [config.virgin_lookback_bars] tail for the virgin-territory check
      below [breakdown_price],
    - the [config.chart_lookback_bars] tail for zone density analysis below
      [breakdown_price].

    Pure function: same callback outputs always produce the same result. *)
