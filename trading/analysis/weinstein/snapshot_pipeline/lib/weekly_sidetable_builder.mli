(** Builds the sparse per-symbol weekly side-table (sketch v5, PR 1) from the
    {b same} weekly aggregation the resistance sketch consumes.

    The builder reuses {!Weekly_prefix} — the single-pass weekly aggregator that
    {!Resistance_sketch} runs over — rather than re-deriving weekly bars with
    different semantics. {!Weekly_prefix} is bit-identical to
    [Time_period.Conversion.daily_to_weekly ~include_partial_week:true], so the
    resulting {!Data_panel_snapshot.Weekly_sidetable.entry} list is exactly the
    weekly series the sketch buckets. This is what makes the point-in-time
    invariants hold {e by construction}:

    - {b split/dividend-adjusted basis} (#2133): the daily bars are rescaled
      onto the adjusted basis ({!Adjusted_basis.to_adjusted_basis}) before the
      weekly fold, so [high] / [mid] lie on the continuous [adjusted_close]
      scale and a split inside the lookback window no longer hides or fabricates
      supply. The warehouse stamps
      {!Data_panel_snapshot.Weekly_sidetable.format_hash} (the adjusted-basis
      hash) so the reader anchors these entries at [Adjusted_close];
    - {b partial current week}: the trailing entry is the current (possibly
      partial) week aggregated through the last daily bar, since
      {!Weekly_prefix} includes the partial week. *)

val of_bars :
  deep_bars:Types.Daily_price.t list ->
  bars:Types.Daily_price.t list ->
  Data_panel_snapshot.Weekly_sidetable.entry list
(** [of_bars ~deep_bars ~bars] is the weekly side-table over [deep_bars @ bars]
    (deep history first, then the window bars — the same concatenation
    {!Resistance_sketch.compute_windowed} uses to widen the weekly prefix). The
    result is the full weekly series oldest-first, one entry per weekly bar,
    with the trailing (possibly partial) current week as the last entry. Returns
    [[]] when both lists are empty.

    Both lists must be individually chronological and [bars] must follow
    [deep_bars]; out-of-order input raises [Invalid_argument] from
    {!Weekly_prefix.build} (the same contract the sketch has). *)
