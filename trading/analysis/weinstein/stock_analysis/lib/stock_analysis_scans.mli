(** Split-aware prior-base window scans for {!Stock_analysis}.

    The long-side breakout price is the maximum high over the prior-base window;
    the short-side breakdown price is the minimum low over the same window. Both
    scans walk backwards from [base_end_offset] to [base_lookback - 1] over
    callback closures, stopping at the first missing bar or the first split
    boundary — bars on the far side of a split live in a different price space
    and must not leak into the scan.

    Extracted verbatim from {!Stock_analysis} to keep that coordinator within
    the declared-large file-length cap; behaviour is unchanged. Pure: depends
    only on the closures passed in.

    The scans read raw highs and lows. {!raw_close} puts a close on that same
    raw basis, so a close can be compared with a scanned level (#3659). *)

val scan_max_high :
  get_high:(week_offset:int -> float option) ->
  get_split_factor:(week_offset:int -> float option) ->
  base_end_offset:int ->
  base_lookback:int ->
  float option
(** Maximum defined high over
    [week_offset = base_end_offset .. base_lookback - 1]. Returns [None] when
    the range is empty ([base_end_offset >= base_lookback]) or no bar produced a
    defined high. The walk stops at the first [None] from [get_high] (no more
    bars) or at the first offset whose per-bar split factor jumps materially
    relative to its more-recent neighbour. A [get_split_factor] that always
    returns [None] makes truncation a no-op. *)

val scan_min_low :
  get_low:(bar_offset:int -> float option) ->
  get_split_factor:(week_offset:int -> float option) ->
  base_end_offset:int ->
  base_lookback:int ->
  float option
(** Mirror of {!scan_max_high}: the minimum defined low over the same window,
    with the same stop conditions. [get_low] is consumed via the Resistance
    callback bundle, which labels its index [~bar_offset]; both conventions mean
    "offset back from the newest bar". *)

val scan_recent_max_high :
  get_high:(week_offset:int -> float option) ->
  get_split_factor:(week_offset:int -> float option) ->
  weeks:int ->
  float option
(** {!scan_max_high} over the most recent [weeks] bars — offsets
    [0 .. weeks - 1], the current bar included: the "current trading range" the
    book anchors the buy-stop above (weinstein-book-reference.md §4.7). [None]
    when [weeks <= 0] (the knob that sets it is off) or no bar in the window has
    a defined high. Same split-boundary truncation as {!scan_max_high}, so a
    shorter window's result never exceeds a longer one's. Backs both the replace
    anchor ([entry_anchor_local_range_weeks]) and the stale-entry cap
    ([entry_cap_local_range_weeks], {!Stale_entry_cap}). *)

val raw_close :
  adjusted_close:float option -> split_factor:float option -> float option
(** The raw (as-traded) close of one bar, from its back-adjusted close and its
    own per-bar split factor [adjusted_close / close_price] (the
    {!Stock_analysis.callbacks} [get_split_factor] convention, read at the same
    offset): [adjusted_close /. split_factor]. This puts a close on the same
    basis as {!scan_max_high}'s raw highs. On history the adjusted close carries
    every split and dividend paid after the bar; the raw close carries none.

    [None] when either input is [None] or the factor is not positive (a bad bar
    — never divide by it). *)
