(** Trailing dollar-ADV (Average Dollar Volume) — the liquidity metric backing
    the liquidity-realism overlay.

    Dollar-ADV is the mean of [close_price *. volume] over the most recent
    [lookback_days] daily bars available at the decision date — a real-time,
    lookahead-free measure of how much capital trades in a name per day. It is
    the signal both the held-position degradation exit
    ({!Liquidity_exit_runner}) and the entry liquidity gate ({!Liquidity_gate})
    consult.

    A legit large-cap that degrades over time into a thinly-traded micro-cap
    (delisting / exchange move) has a collapsing dollar-ADV; detecting that drop
    from data available at [as_of] lets the strategy exit BEFORE the name
    becomes untradeable, rather than cleaning the data after the fact. *)

val dollar_adv : lookback_days:int -> Types.Daily_price.t list -> float option
(** [dollar_adv ~lookback_days bars] = the mean of [close *. volume] over the
    most recent [lookback_days] bars in [bars].

    [bars] are daily bars in chronological order (oldest first) as returned by
    {!Bar_reader.daily_bars_for} — i.e. only bars up to and including the
    decision date, so the result carries no lookahead. The function takes the
    final [lookback_days] elements (or all of them when fewer are available).

    Returns [None] when [bars] is empty or [lookback_days <= 0] — the caller
    treats this "no liquidity reading" the same as "passes" (a missing reading
    must never force a spurious exit / drop). Each bar's dollar volume is
    [close_price *. Float.of_int volume]; the mean is over the number of bars
    actually present in the window (never divides by a padded count). *)
