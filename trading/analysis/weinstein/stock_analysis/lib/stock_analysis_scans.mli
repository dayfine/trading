(** Split-aware prior-base window scans for {!Stock_analysis}.

    The long-side breakout price is the maximum high over the prior-base window;
    the short-side breakdown price is the minimum low over the same window. Both
    scans walk backwards from [base_end_offset] to [base_lookback - 1] over
    callback closures, stopping at the first missing bar or the first split
    boundary — bars on the far side of a split live in a different price space
    and must not leak into the scan.

    Extracted verbatim from {!Stock_analysis} to keep that coordinator within
    the declared-large file-length cap; behaviour is unchanged. Pure: depends
    only on the closures passed in. *)

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
