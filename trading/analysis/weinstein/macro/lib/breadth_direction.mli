(** Refine the three-state macro trend with the DIRECTION of universe breadth.

    Weinstein reads the advance/decline line and the new-highs-minus-new-lows
    series as leading indicators of the tape (Ch. 8; see
    [docs/design/weinstein-book-reference.md] §Macro Analysis). The existing
    macro gate already weights both as {b level} signals inside its confidence
    score. This module adds the reading he actually describes for those series —
    whether participation is deteriorating or repairing — and exposes it as a
    separate five-state label rather than folding it into the score.

    It is a state {i label}, not a gate: {!classify} never blocks a side, and
    [Macro.result.trend] is untouched. Consumers that want the refinement read
    [Macro.result.breadth_state]; everything else keeps reading [trend].

    {1 Why direction, not level}

    A level threshold ("participation below 45%") fires on the way down and on
    the way back up, which is exactly where the outcomes diverge. Over
    2000-2026, entries taken while participation was below 45% {b and falling}
    lost money in both books measured, while entries taken while it was below
    45% {b and rising} were the best cohort in the run — same level, opposite
    result. The evidence is
    [dev/experiments/stop-width-cadence-surface-2026-09-05/README.md] §"Breadth
    state across 27 years".

    {1 Default-off}

    [config.enabled = false] is the default and makes {!classify} the identity
    projection of the macro trend
    ([Weinstein_types.breadth_state_of_market_trend]), so every existing
    baseline and golden is bit-identical. *)

open Weinstein_types

type config = {
  enabled : bool;
      (** Master switch. [false] (default): {!classify} returns
          [breadth_state_of_market_trend trend] and reads no breadth input at
          all. *)
  weak_pct_above : float;
      (** Participation below this percent counts as weak. Default 45.0. Both
          the Deteriorating and the Recovering rules are gated on it — the
          direction reading is only interesting from a weak base. *)
  falling_points : float;
      (** Percentage POINTS of decline over {!lookback_weeks} that make a weak
          tape Deteriorating. Default 5.0. *)
  rising_points : float;
      (** Percentage POINTS of gain over {!lookback_weeks} that make a weak tape
          Recovering. Default 5.0. *)
  new_lows_pct : float;
      (** New 52-week lows above this percent of the universe, {i and} rising
          over the lookback, make the tape Deteriorating regardless of the
          participation rule. Default 8.0. *)
  lookback_weeks : int;
      (** How far back the prior sample is taken, in weeks. Default 4 — with
          {!Breadth_series_cache}'s 5-rows-per-week step that is the ~20
          trading-day window the 27-year study used. *)
}
[@@deriving sexp]

val default_config : config
(** [enabled = false]; thresholds as documented per field. The disabled default
    is the pre-feature behaviour exactly. *)

val classify :
  config:config ->
  trend:market_trend ->
  pct_above:float option ->
  pct_above_prior:float option ->
  nl_pct:float option ->
  nl_pct_prior:float option ->
  breadth_state
(** [classify ~config ~trend ~pct_above ~pct_above_prior ~nl_pct ~nl_pct_prior]
    is the five-state read.

    Falls back to [breadth_state_of_market_trend trend] when
    [config.enabled = false] or when {b any} of the four breadth samples is
    [None] — a partial reading is not a reading, and the missing-data case must
    be the pre-feature behaviour, not a third policy.

    Otherwise, in this order (the order is part of the contract):

    + [trend = Bearish] → [Bearish_breadth]. An outright bearish tape is already
      the strongest statement the macro gate makes; refining it would only
      weaken it.
    + [pct_above < weak_pct_above] and it fell by at least [falling_points] over
      the lookback → [Deteriorating].
    + [nl_pct > new_lows_pct] and [nl_pct > nl_pct_prior] → [Deteriorating].
      Expanding new lows is a deterioration signal in its own right, independent
      of where participation sits.
    + [pct_above < weak_pct_above] and it rose by at least [rising_points] over
      the lookback → [Recovering].
    + otherwise → [breadth_state_of_market_trend trend].

    {b Deteriorating is checked before Recovering} and therefore wins when both
    could fire — the new-lows rule and the participation-rising rule can be true
    on the same day at a turn (lows made early in the window, participation
    already climbing). Resolving that tie toward Deteriorating is the
    conservative choice: the cost of labelling a turn late is a missed
    Recovering week, and the cost of labelling it early is entering into the
    cohort that lost money in both books.

    Pure function. All arguments in percent (0-100), matching
    {!Breadth_series_cache}'s output. *)
