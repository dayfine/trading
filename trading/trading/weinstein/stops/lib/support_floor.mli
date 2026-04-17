(** Support/resistance primitive: derives the prior correction extreme from a
    daily bar history.

    Weinstein, Ch. 6 §5.1 ("Initial Stop Placement"):

    {v
      Long:  Place BELOW the significant support floor (prior correction low)
             BEFORE the breakout.
      Short: Place ABOVE the significant resistance ceiling (prior
             counter-rally high) BEFORE the breakdown.
    v}

    Callers pipe the output into {!Weinstein_stops.compute_initial_stop}'s
    [reference_level] argument. When no qualifying move exists in the lookback
    window, the function returns [None] and the caller falls back to the
    fixed-buffer proxy.

    All computation is pure — same input gives the same output. *)

val find_recent_level :
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  side:Trading_base.Types.position_side ->
  min_pullback_pct:float ->
  lookback_bars:int ->
  float option
(** [find_recent_level ~bars ~as_of ~side ~min_pullback_pct ~lookback_bars]
    returns the reference level of the most recent qualifying counter-trend move
    ending at or before [as_of].

    Long side:
    - Identify the {b peak}: the bar in the window with the highest
      [high_price]. Ties are broken by taking the latest date.
    - Identify the {b correction low}: the minimum [low_price] across bars
      strictly after the peak date, through [as_of].
    - Qualify when
      [(peak_high -. correction_low) /. peak_high >= min_pullback_pct].

    Short side (mirror):
    - Identify the {b trough}: the bar in the window with the lowest
      [low_price]. Ties are broken by taking the latest date.
    - Identify the {b rally high}: the maximum [high_price] across bars strictly
      after the trough date, through [as_of].
    - Qualify when
      [(rally_high -. trough_low) /. trough_low >= min_pullback_pct].

    [min_pullback_pct] is symmetric — it is the depth threshold on either side.
    Long scales drawdown by the peak high; short scales the counter-rally by the
    trough low.

    Returns [None] when:
    - [bars] is empty, or no bars are dated at or on [as_of];
    - the anchor (peak for long, trough for short) falls on the last bar of the
      window — no counter-move observed;
    - the counter-move depth is below [min_pullback_pct];
    - [lookback_bars <= 0].

    Parameters:
    - [bars] — daily price bars in chronological order (oldest first), matching
      the layout produced by {!Bar_history}. Bars outside the [as_of] window are
      ignored.
    - [as_of] — the date at which the caller is computing a stop (usually the
      entry date). Bars strictly after this date are excluded.
    - [side] — [Long] returns a support floor (correction low); [Short] returns
      a resistance ceiling (rally high).
    - [min_pullback_pct] — minimum counter-move depth required to qualify.
      Weinstein's book default is [0.08] (8%).
    - [lookback_bars] — maximum window size (in bars, not calendar days). Chosen
      to capture the most recent counter-move without reaching back into an
      older regime. *)
