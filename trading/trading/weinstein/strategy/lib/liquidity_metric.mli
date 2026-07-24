(** Trailing dollar-ADV (Average Dollar Volume) — the liquidity metric backing
    the liquidity-realism overlay.

    Dollar-ADV aggregates [close_price *. volume] over the most recent
    [lookback_days] daily bars available at the decision date — a real-time,
    lookahead-free measure of how much capital trades in a name per day. It is
    the signal the held-position degradation exit ({!Liquidity_exit_runner}),
    the entry liquidity gate ({!Liquidity_gate}) and the short-borrow gate
    ({!Short_borrow_gate}) consult.

    A legit large-cap that degrades over time into a thinly-traded micro-cap
    (delisting / exchange move) has a collapsing dollar-ADV; detecting that drop
    from data available at [as_of] lets the strategy exit BEFORE the name
    becomes untradeable, rather than cleaning the data after the fact.

    {b Aggregation is configurable ({!aggregation}) because the arithmetic mean
       is spoofable} — see issue #2060. A single block-cross or bad print
    inflates the trailing mean past an entry floor a name never honestly clears:
    LINK on 2026-05-11 printed 4,608,300 shares ($15.4M) with zero price impact
    against a ~$250k/day honest baseline, which lifted its 20-day mean
    dollar-ADV to ~$1.0M and cleared the armed $1M entry gate. The resulting
    $8.9M position stopped out five days later at −17.7%. {!Median} and
    {!Trimmed_mean} are robust to that single spike; {!Mean} (the default) is
    not. *)

type aggregation =
  | Mean
      (** Arithmetic mean of the window's daily dollar volumes. The default — it
          reproduces the pre-#2060 behaviour bit-for-bit. Spoofable: one block
          print in the window moves the reading by [spike / n]. *)
  | Median
      (** Median of the window's daily dollar volumes: the middle observation
          for an odd-length window, the mean of the two central observations for
          an even-length one. Unaffected by any single spike, and the honest
          reading for a name whose volume distribution is right-skewed (which
          most thin names' are). *)
  | Trimmed_mean
      (** Symmetric trimmed mean: drop the [trim_pct] fraction of observations
          from {i each} tail of the sorted window, then take the mean of what
          remains. Between {!Mean} and {!Median} in robustness — it discards the
          extremes but still averages the body. The trim fraction is the
          [trim_pct] argument of {!dollar_adv} (default {!default_trim_pct}). *)
[@@deriving sexp, equal, compare]

val default_trim_pct : float
(** [0.1] — the default fraction trimmed from each tail by {!Trimmed_mean}. Over
    the default 20-bar window that drops the 2 largest and 2 smallest days. Only
    consulted when the aggregation is {!Trimmed_mean}. *)

val dollar_adv :
  ?aggregation:aggregation ->
  ?trim_pct:float ->
  lookback_days:int ->
  Types.Daily_price.t list ->
  float option
(** [dollar_adv ?aggregation ?trim_pct ~lookback_days bars] aggregates
    [close *. volume] over the most recent [lookback_days] bars in [bars].

    [bars] are daily bars in chronological order (oldest first) as returned by
    {!Bar_reader.daily_bars_for} — i.e. only bars up to and including the
    decision date, so the result carries no lookahead. The function takes the
    final [lookback_days] elements (or all of them when fewer are available).

    [aggregation] defaults to {!Mean}, which is the pre-#2060 behaviour: the
    arithmetic mean of the window, computed by the same left-fold sum in the
    same order, so every existing call site is bit-identical.

    [trim_pct] defaults to {!default_trim_pct} and is {b ignored} unless
    [aggregation = Trimmed_mean]. The number of observations dropped from each
    tail is [floor (window_length *. trim_pct)], clamped to
    [[0, (window_length - 1) / 2]] so at least one observation always survives;
    a non-finite or non-positive [trim_pct] trims nothing (degenerating to
    {!Mean}), and a [trim_pct] at or above [0.5] trims maximally (degenerating
    to {!Median} on an odd-length window).

    Returns [None] when [bars] is empty or [lookback_days <= 0] — the caller
    treats this "no liquidity reading" the same as "passes" (a missing reading
    must never force a spurious exit / drop). Each bar's dollar volume is
    [close_price *. Float.of_int volume]; every aggregation is over the number
    of bars actually present in the window (never a padded count). Pure: same
    input, same output. *)
