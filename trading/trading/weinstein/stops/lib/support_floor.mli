(** Support/resistance primitive: derives the prior correction extreme from a
    daily bar history.

    Weinstein, Ch. 6 §5.1 ("Initial Stop Placement") for the long rule, and Ch.
    7 §6.3 ("Short Stop (Buy-Stop) Rules") for the short rule:

    {v
      Long:  Place BELOW the significant support floor (prior correction low)
             BEFORE the breakout. (§5.1)
      Short: Place ABOVE the significant resistance ceiling (prior
             counter-rally high) BEFORE the breakdown. (§6.3)
    v}

    Callers pipe the output into {!Weinstein_stops.compute_initial_stop}'s
    [reference_level] argument. When no qualifying move exists in the lookback
    window, the function returns [None] and the caller falls back to the
    fixed-buffer proxy.

    All computation is pure — same input gives the same output. *)

(** Which price field the correction-low / rally-high (and the anchoring peak /
    trough) are read from.

    Weinstein (§Stop-Loss Rules) says place the stop below "the significant
    support floor (prior correction low)" but does not mandate the {e intraday}
    extreme; whether the "correction low" is measured on closes or on intraday
    lows is a numeric-threshold-class dial per
    [.claude/rules/weinstein-faithful-core.md] (spine item 5 — "stop below the
    base" — holds under either reading). [Close] avoids a lone intraday wick
    anchoring the floor far below the surrounding trading range (e.g. CLMB's
    2026-04-30 wick $14.64, ~4% below its neighbouring closes, which forced a
    42.5% stop distance and a tiny position). *)
type anchor_mode =
  | Wick
      (** Anchor and correction extreme are measured on the {b intraday}
          [high_price] / [low_price] — a shakeout wick counts. This is the
          historical behaviour. *)
  | Close
      (** Anchor and correction extreme are measured on the bar [close_price]
          instead of the intraday high/low. A single-bar capitulation wick that
          undercuts (long) or overshoots (short) every surrounding close does
          {b not} pull the floor to the wick extreme. *)
[@@deriving show, eq, sexp]

(** WHICH prior counter-move the scan anchors on, orthogonal to {!anchor_mode}
    (which decides which price {e field} both the anchor and the counter-move
    are read from).

    Weinstein §5.1 says place the initial stop below "the significant support
    floor (prior correction low) BEFORE the breakout" — singular and {b recent},
    not "the deepest low anywhere in the lookback". For a normally-shaped base
    the two readings coincide (the window extremum {e is} the recent base). They
    diverge for a crash-recovery name, where the window extremum is a pre-crash
    peak and its counter-move is the crash floor tens of percent below the entry
    — a structurally wide stop that the entry gate then drops
    ([Audit_recorder.Stop_too_wide]).

    {!Nearest} is the book's own remedy for that width: shrink the stop
    {e distance} by anchoring on the nearest qualifying correction, rather than
    shrinking the {e share count} (which the book never prescribes — see
    [Weinstein_strategy_config.stop_width_mode] for the contrasting
    tolerated-participation reading). *)
type anchor_scope =
  | Window_extreme
      (** Anchor on the window extremum (highest high for a long, lowest low for
          a short), then take the counter-move extreme newer than it. The
          historical behaviour and the default. *)
  | Nearest
      (** Anchor on the {b nearest} bar (walking back from [as_of]) whose
          subsequent counter-move already meets [min_pullback_pct], and return
          that counter-move's extreme. Yields the most recent qualifying
          correction low (long) / counter-rally high (short), which is at or
          nearer to current price than the {!Window_extreme} answer. *)
[@@deriving show, eq, sexp]

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

    Bar-list convenience wrapper — always [Wick] mode. The [anchor_mode] dial is
    exposed only on {!find_recent_level_with_callbacks} (the path the production
    stop {!Weinstein_stops.compute_initial_stop_with_floor} and panel-backed
    callers use); this wrapper keeps its all-labelled signature unchanged.

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
      Weinstein's book default is [0.08] (8%): §5.2's STATE: INITIAL block pairs
      "stop = below prior correction low" (the §5.1 rule this function
      implements) with the qualifying depth "WAIT for first substantial
      correction (8-10%+)" — [0.08] is the lower bound of that range.
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
      (** Raw (un-adjusted) daily [close_price] at [day_offset] days back — the
          same price basis as [get_high] / [get_low]. Read by
          {!find_recent_level_with_callbacks} under [Close] anchor mode. *)
  get_adjusted_close : day_offset:int -> float option;
      (** Split- and dividend-adjusted daily close at [day_offset] days back.
          Never read by {!find_recent_level_with_callbacks} — the primitive
          stays a pure single-basis price consumer. It is carried in the bundle
          so the stops layer can derive the per-bar split-adjustment factor
          ([get_adjusted_close /. get_close]) and rescale a whole bundle onto
          the adjusted basis before scanning, which is what
          [Weinstein_stops.config.split_safe_floors] does. Returns [None]
          exactly where [get_close] does (same window); the value may be
          [Float.nan] when the backing source has no adjusted-close cell, in
          which case that bar admits no factor and the stops layer scans the raw
          basis for the whole window rather than rescaling part of it. *)
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
    resulting window. [get_close] reads [Daily_price.close_price] (raw) and
    [get_adjusted_close] reads [Daily_price.adjusted_close].

    When [lookback_bars <= 0], the resulting bundle has [n_days = 0] and every
    accessor returns [None]. *)

val find_recent_level_with_callbacks :
  ?anchor_mode:anchor_mode ->
  ?anchor_scope:anchor_scope ->
  callbacks:callbacks ->
  side:Trading_base.Types.position_side ->
  min_pullback_pct:float ->
  unit ->
  float option
(** [find_recent_level_with_callbacks ?anchor_mode ?anchor_scope ~callbacks
     ~side ~min_pullback_pct ()] is the indicator-callback shape of
    {!find_recent_level}. The trailing [unit] makes the optionals erasable (all
    other arguments are labelled). [as_of] and [lookback_bars] are baked into
    the [callbacks] bundle and no longer parameters here.

    Under the default [anchor_scope = Window_extreme] the algorithm scans
    [0..n_days-1] to identify the anchor (highest high for [Long], lowest low
    for [Short] under the default [Wick] mode — the [get_high] / [get_low]
    callbacks; the [get_close] callback under [Close]; tie-break: latest date
    wins, i.e. the smallest day offset), then scans the post-anchor offsets
    [0..anchor_offset-1] for the counter-move extreme (read from the same
    field). Returns [Some level] when the counter-move depth meets
    [min_pullback_pct], else [None].

    Under [anchor_scope = Nearest] the scan instead walks candidate anchors
    outward from day offset [0] and returns the counter-move extreme of the
    {b first} offset whose counter-move over [0..offset-1] already meets
    [min_pullback_pct] — the nearest qualifying correction rather than the
    deepest one. Offset [0] can never qualify (its post-anchor range is empty).
    Both scopes use the same depth formula and the same [anchor_mode] price
    field, so they agree whenever the window extremum {e is} the nearest
    qualifying anchor.

    [anchor_mode] defaults to [Wick]; [anchor_scope] defaults to
    [Window_extreme]. Both defaults reproduce the pre-flag behaviour exactly. *)
