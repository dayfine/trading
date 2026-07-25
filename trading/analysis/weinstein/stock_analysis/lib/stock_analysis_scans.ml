(** Split-aware prior-base window scans for {!Stock_analysis}.

    The breakout price is the maximum high over the prior-base window; the
    breakdown price is the minimum low over the same window. Both walk backwards
    from [base_end_offset] to [base_lookback - 1] over callback closures and
    stop at the first missing bar or the first split boundary.

    Extracted from {!Stock_analysis} to keep that coordinator within the
    declared-large file-length cap. Pure: depends only on the closures passed
    in. *)

open Core

(** Combine a running maximum with a fresh sample. *)
let _max_opt (best : float option) (h : float) : float option =
  match best with None -> Some h | Some b -> Some (Float.max b h)

(** Combine a running minimum with a fresh sample. Mirror of [_max_opt]. *)
let _min_opt (best : float option) (l : float) : float option =
  match best with None -> Some l | Some b -> Some (Float.min b l)

(** Per-bar split-jump threshold: the smallest [factor_at_off / factor_at_off-1]
    ratio (in either direction) that we treat as a split rather than a dividend
    / continuous-adjustment drift. A split causes a discrete multiplicative jump
    in [adjusted_close / close_price] between consecutive bars (e.g., a forward
    four-for-one split creates a 4x jump; a five-for- four reverse split creates
    a 1.25x jump); dividends create only gradual drift. The smallest real-world
    split is around 5:4 (a one-quarter jump); the largest dividend drift over a
    couple of weeks is well under one- twentieth. The threshold below sits
    safely between the two. *)
let _split_jump_threshold = 0.20

(** [true] when bars at [off] and [off-1] sit in the same price space — i.e.,
    the per-bar split factor didn't jump by more than [_split_jump_threshold].
    Used to truncate the breakout / breakdown scans at the most recent split
    boundary: a [false] here means a split occurred between [off] (older) and
    [off-1] (newer), so any further-back bars belong to the pre-split price
    space and would leak into the scan. When either factor is unavailable the
    comparison is a no-op (returns [true] — keep walking) so that fixtures
    without raw / adjusted-close metadata behave as before. *)
let _no_split_between ~get_split_factor ~off : bool =
  if off <= 0 then true
  else
    match
      ( get_split_factor ~week_offset:off,
        get_split_factor ~week_offset:(off - 1) )
    with
    | None, _ | _, None -> true
    | Some f_old, Some f_new
      when Float.( <= ) f_old 0.0 || Float.( <= ) f_new 0.0 ->
        true
    | Some f_old, Some f_new ->
        Float.( < ) (Float.abs ((f_old /. f_new) -. 1.0)) _split_jump_threshold

(** Walk back from [week_offset = base_end_offset .. base_lookback - 1] reading
    [get_high] at each offset. Returns the maximum defined high. Stops the walk
    at the first [None] (treated as "no more bars") OR at the first offset whose
    per-bar split factor jumps materially relative to its more-recent neighbour
    (a split occurred between [off] and [off-1]; everything older belongs to the
    pre-split price space). Returns [None] when the range is empty or no bar
    produced a defined high. *)
let scan_max_high ~get_high ~get_split_factor ~base_end_offset ~base_lookback :
    float option =
  if base_end_offset >= base_lookback then None
  else
    let rec loop off best =
      if off >= base_lookback then best
      else if not (_no_split_between ~get_split_factor ~off) then best
      else
        match get_high ~week_offset:off with
        | None -> best
        | Some h -> loop (off + 1) (_max_opt best h)
    in
    loop base_end_offset None

(** Mirror of {!scan_max_high} for the short-side cascade: walks
    [bar_offset = base_end_offset .. base_lookback - 1] reading [get_low] at
    each offset and returns the {b minimum} defined low. The base low is the
    short-side analogue of the breakout price.

    Note: [get_low] is consumed via the Resistance callback bundle, which uses
    [~bar_offset] rather than [~week_offset]. Both indexing conventions mean
    "offset from the newest bar"; only the labelled-arg name differs.

    Same split-boundary truncation as the max-high scan: stops at the first
    offset whose [get_split_factor] jumps relative to its more-recent neighbour.
*)
let scan_min_low ~get_low ~get_split_factor ~base_end_offset ~base_lookback :
    float option =
  if base_end_offset >= base_lookback then None
  else
    let rec loop off best =
      if off >= base_lookback then best
      else if not (_no_split_between ~get_split_factor ~off) then best
      else
        match get_low ~bar_offset:off with
        | None -> best
        | Some l -> loop (off + 1) (_min_opt best l)
    in
    loop base_end_offset None
