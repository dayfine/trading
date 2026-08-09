(** Price-basis selection for the trade-audit report's on-demand bar reads.

    The snapshot daily view exposes two close columns for the same bars —
    [raw_closes] (the [Snapshot_schema.Close] cell) and [adjusted_closes] (the
    [Snapshot_schema.Adjusted_close] cell). Every report series that compares
    two prices {e across time} wants the adjusted column: a split inside the
    window puts a ~Nx discontinuity into the raw series that is an artefact of
    the corporate action, not a price move. That is the G14 pathology (see
    [dev/notes/g14-deep-dive-2026-05-01.md]) relocated to the reporting layer.

    The complication the two columns do not share is missingness. The daily view
    drops bars whose raw [Close] is NaN, so [raw_closes] is NaN-free by
    construction; [adjusted_closes] instead carries [Float.nan] wherever the
    snapshot has no adjusted-close cell for the date (and is NaN for the whole
    symbol on a schema predating the field). Swapping one column for the other
    naively would therefore introduce NaNs into consumers that have never had to
    handle them.

    {2 The policy: all-or-nothing per window, never mixed}

    Prefer [adjusted_closes] when {e every} cell in the window is finite; other-
    wise fall back to [raw_closes] {e wholesale}. A per-bar fallback is
    deliberately not offered: splicing a raw close into an otherwise-adjusted
    window reintroduces exactly the cross-split discontinuity this module exists
    to remove, so a partial gap must never yield a half-adjusted window.

    This mirrors the answer the stops layer already gave to the same question —
    a NaN adjusted cell makes the whole window un-rescalable and the scan falls
    back to the raw basis (see [Weinstein_stops.config.split_safe_floors] and
    {!Snapshot_runtime.Snapshot_bar_views.daily_view_for}).

    Because the fallback target is NaN-free, the policy can never introduce a
    NaN where the pre-existing raw-basis code had none. The fallback is silent
    to the rendered report, though; surfacing which basis a series was drawn on
    is a possible follow-up, not something this module does. *)

val window_closes : adjusted:float array -> raw:float array -> float array
(** [window_closes ~adjusted ~raw] returns [adjusted] when it is entirely
    finite, and [raw] otherwise. The two arrays are expected to index the same
    bars (the {!Snapshot_runtime.Snapshot_bar_views.daily_view} invariant), so
    the result is positionally interchangeable with either input and can be
    zipped against the view's [dates].

    An empty [adjusted] is vacuously finite, so empty in yields empty out.

    The returned array is one of the inputs, not a copy — callers must not
    mutate it. *)

val last_close : adjusted:float array -> raw:float array -> float option
(** [last_close ~adjusted ~raw] is the newest close of
    {!window_closes}[ ~adjusted ~raw], i.e. the last-known close on the
    preferred basis for the window.

    Returns [None] when the window is empty, and also when the selected close is
    non-finite — the latter cannot arise from a well-formed daily view (the raw
    fallback is NaN-free) but is guarded rather than propagated, so a
    [Some Float.nan] can never reach a benchmark or utilization mark and poison
    it silently. *)
