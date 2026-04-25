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
      older regime.

    Implementation note: this is a thin wrapper over
    {!find_recent_level_with_callbacks}. It builds a {!callbacks} record via
    {!callbacks_from_bars} (which applies the [as_of] filter and [lookback_bars]
    truncation up-front) and threads it through. Behaviour is bit-identical to
    the callback API for the same underlying bar inputs. *)

(** {1 Callback API} *)

type callbacks = {
  get_high : day_offset:int -> float option;
      (** Daily [high_price] at [day_offset] days back. [day_offset:0] is the
          newest bar in the eligible window (the bar dated on or just before
          [as_of]); [day_offset:n_days-1] is the oldest. [None] = no bar at that
          offset (out of range). *)
  get_low : day_offset:int -> float option;
      (** Daily [low_price] at [day_offset] days back. Same offset convention as
          [get_high]. *)
  get_close : day_offset:int -> float option;
      (** Daily [close_price] at [day_offset] days back. Currently unused by
          {!find_recent_level_with_callbacks} but kept in the bundle so panel-
          backed callers can reuse the same callback shape across primitives
          that may consume close. *)
  get_date : day_offset:int -> Core.Date.t option;
      (** Calendar date of the bar at [day_offset] days back. Useful for
          telemetry / debugging; not consumed by the algorithm itself (the
          windowing and tie-break are by offset, not by date). *)
  n_days : int;
      (** Total number of eligible days exposed by the callbacks. The window has
          already been filtered by [as_of] and truncated to [lookback_bars] at
          construction time, so consumers can scan [0..n_days-1] without further
          bounds checks. *)
}
(** Bundle of bar-field callbacks consumed by
    {!find_recent_level_with_callbacks}.

    The bundle exposes a {b pre-windowed} view: [as_of] filtering and
    [lookback_bars] truncation are applied once at construction time, leaving a
    contiguous, cap-trimmed window that callers can scan by offset alone. Day
    offset [0] is the most recent bar; [n_days - 1] is the oldest. *)

val callbacks_from_bars :
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  lookback_bars:int ->
  callbacks
(** [callbacks_from_bars ~bars ~as_of ~lookback_bars] constructs a callback
    bundle by applying the same windowing the bar-list path used inline: drop
    bars dated strictly after [as_of], then keep only the trailing
    [lookback_bars] of the remainder. Day offset [0] is the newest bar in the
    resulting window.

    When [lookback_bars <= 0], the resulting bundle has [n_days = 0] and every
    accessor returns [None]. *)

val find_recent_level_with_callbacks :
  callbacks:callbacks ->
  side:Trading_base.Types.position_side ->
  min_pullback_pct:float ->
  float option
(** [find_recent_level_with_callbacks ~callbacks ~side ~min_pullback_pct] is the
    indicator-callback shape of {!find_recent_level}. [as_of] and
    [lookback_bars] are baked into the [callbacks] bundle and no longer
    parameters here.

    The algorithm scans [0..n_days-1] to identify the anchor (highest high for
    [Long], lowest low for [Short]; tie-break: latest date wins, i.e. the
    smallest day offset), then scans the post-anchor offsets
    [0..anchor_offset-1] for the counter-move extreme. Returns [Some level] when
    the counter-move depth meets [min_pullback_pct], else [None]. *)
