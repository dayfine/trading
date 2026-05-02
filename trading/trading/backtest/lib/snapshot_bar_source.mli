(** Snapshot-backed bar source for the simulator.

    Phase D of the daily-snapshot streaming pipeline (see
    [dev/plans/snapshot-engine-phase-d-2026-05-02.md]). Bridges
    [Snapshot_runtime.Daily_panels.t] (the per-symbol snapshot cache) into the
    [Trading_simulation_data.Market_data_adapter] callback contract used by the
    simulator's per-tick price reads.

    Field mapping (Phase A.1 schema): [open_price] ← [Snapshot_schema.Open],
    [high_price] ← [High], [low_price] ← [Low], [close_price] ← [Close],
    [volume] ← [Volume] (cast [Float.to_int] — exact for any realistic equity
    volume; counts up to ~2^53 round-trip exactly), [adjusted_close] ←
    [Adjusted_close], [date] ← [Snapshot.t.date]. A row with any OHLCV field set
    to [Float.nan] is treated as "no bar this day" — the closure returns [None],
    matching the CSV path's "missing CSV row" semantics.

    [get_previous_bar] needs the most recent bar with date strictly less than
    the requested date. Snapshots are addressed by exact date, so we read a
    bounded lookback window (60 calendar days — covers any realistic US holiday
    cluster) via [Daily_panels.read_history] and take the last entry. Symbols
    whose last bar is older than 60 days surface [None]; that matches the CSV
    path's behaviour for delisted / suspended symbols. *)

val make_callbacks :
  panels:Snapshot_runtime.Daily_panels.t ->
  callbacks:Snapshot_runtime.Snapshot_callbacks.t ->
  (symbol:string -> date:Core.Date.t -> Types.Daily_price.t option)
  * (symbol:string -> date:Core.Date.t -> Types.Daily_price.t option)
(** [make_callbacks ~panels ~callbacks] returns [(get_price, get_previous_bar)]
    — the closure pair the
    {!Trading_simulation_data.Market_data_adapter.create_with_callbacks}
    constructor accepts.

    [panels] is the snapshot cache providing [read_today] / [read_history];
    [callbacks] is the field-accessor shim built via
    {!Snapshot_runtime.Snapshot_callbacks.of_daily_panels} over the same
    [panels]. Both are passed in (rather than building [callbacks] inline) so
    callers that already hold a [Snapshot_callbacks.t] for other purposes can
    share it. *)
