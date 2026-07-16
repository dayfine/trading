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
    depth (capped at 520) rather than fabricating history. The result is
    bit-equal to
    [Snapshot_pipeline.Resistance_sketch.compute_windowed ~deep_bars:[||]
     ~bars_arr] read at its last index, with the histogram anchor taken from the
    last bar's raw [close_price] (matching {!Resistance_sketch_reader}, which
    anchors on the snapshot [Close] column).

    Returns [None] when [daily_bars] is empty (no bar to anchor the sketch).
    Pure function. *)
