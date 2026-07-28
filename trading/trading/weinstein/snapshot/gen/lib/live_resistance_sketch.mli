(** Live bar-list resistance-v2 sketch bridge (resistance-v2 live-path,
    [dev/plans/resistance-v2-supply-sketches-2026-07-15.md] §D4-D6).

    The snapshot / backtest path reads precomputed {!Resistance_supply.sketch}
    cells out of warehouse columns ({!Resistance_sketch_reader}). The live
    weekly-review generator has no warehouse — it holds each survivor's full
    daily history in memory. This module bridges that history to the same
    {!Resistance_supply.sketch} record by computing the per-day sketch columns
    ({!Snapshot_pipeline.Resistance_sketch.compute_windowed}) and extracting the
    most-recent day (the analysis Friday). *)

val of_daily_bars : Types.Daily_price.t list -> Resistance_supply.sketch option
(** [of_daily_bars daily_bars] computes the resistance-v2 sketch at the most
    recent bar of [daily_bars] (chronological, oldest first — the last element
    is the analysis Friday).

    The full [daily_bars] history feeds the weekly prefix (rolling max-high
    family, trailing histogram, bars-seen), so the result is point-in-time and
    only as deep as the fetched history. When that history is shorter than 520
    weeks the sketch is honestly shallow — [bars_seen] reflects the true weekly
    depth (capped at 520) rather than fabricating history.

    {b Basis (#2133).} The bars are rescaled onto the split/dividend-adjusted
    basis ({!Snapshot_pipeline.Adjusted_basis.to_adjusted_basis}) before the
    sketch is computed, so a split inside the fetched history no longer hides or
    fabricates supply. The histogram anchor is therefore the last bar's
    {e adjusted} close — matching an adjusted-basis warehouse's [Adjusted_close]
    column, which the side-table reader anchors on. For split-free history this
    is a no-op (factor 1.0), so the result stays bit-equal to
    [Snapshot_pipeline.Resistance_sketch.compute_windowed ~deep_bars:[||]
     ~bars_arr] read at its last index.

    Returns [None] when [daily_bars] is empty (no bar to anchor the sketch).
    Pure function. *)
