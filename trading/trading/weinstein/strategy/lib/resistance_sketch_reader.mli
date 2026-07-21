(** Read a resistance-v2 sketch ({!Resistance_supply.sketch}) out of the
    warehouse for the [Stock_analysis] overhead-supply score.

    Extracted from {!Panel_callbacks} (keeps that coordinator under the
    file-length cap). Three warehouse generations feed the same
    {!Resistance_supply.sketch} record — {!read} dispatches between them; the
    per-generation leaves are {!read_sketch} (v4 / v3 dense columns) and
    {!Weekly_sidetable_reader.sketch_of_entries} (v5 side-table). *)

module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

val read :
  cb:Snapshot_callbacks.t ->
  symbol:string ->
  as_of:Core.Date.t ->
  ?weekly_sidetable:Weekly_sidetable.entry list ->
  unit ->
  Resistance_supply.sketch option
(** [read ~cb ~symbol ~as_of ?weekly_sidetable ()] is the three-generation
    sketch dispatch, in priority order:

    + {b v5 (side-table)} — when [weekly_sidetable] is [Some entries] the sketch
      is derived by {!Weekly_sidetable_reader.sketch_of_entries} at score time,
      anchored at the row's raw [Close] (read from [cb] — the histogram [Res_*]
      columns are retired under v5 but [Close] stays a dense column). A failed
      [Close] read collapses to [None], the same partial-read discipline as
      {!read_sketch}.
    + {b v4 (80 age-banded columns)} / {b v3 (20 age-blind columns)} — when
      [weekly_sidetable] is [None] the read falls through to {!read_sketch},
      which itself width-detects between a v4 and a v3 warehouse.

    {b Consistency guard.} A [Some] side-table takes precedence over the dense
    columns unconditionally; the caller ({!Weekly_sidetable_reader.load_gated})
    only produces [Some] when the manifest's side-table format hash matches, so
    a stale / mismatched side-table is rejected loudly at load time rather than
    silently preferred here. [as_of] must be a [week_end_date] present in the
    side-table for v5 to equal the v4 columns (see {!Weekly_sidetable_reader}) —
    the strategy scores only at week close, so it always is. *)

val read_sketch :
  cb:Snapshot_callbacks.t ->
  symbol:string ->
  as_of:Core.Date.t ->
  Resistance_supply.sketch option
(** [read_sketch ~cb ~symbol ~as_of] reads the sketch columns
    ([Res_max_high_130/260/520w], [Res_bars_seen], the [Res_hist] histogram, and
    [Close] as the histogram anchor) at [(symbol, as_of)]. Returns [None] if ANY
    required scalar cell read fails (missing row, a schema without the sketch
    columns, or a decode error) — a partial read never fabricates a sketch.

    {b Warehouse-width detection (v3 back-compat).} A v4 (age-banded) warehouse
    carries [Snapshot_schema.n_hist_cells] histogram columns; the reader reads
    all of them and reshapes into the {!Resistance_supply.sketch.hist_bands}
    age-band matrix. An older v3 warehouse carries only the [n_hist_buckets]
    age-blind columns (the trailing [Res_hist] cells are absent, so a probe read
    of the last v4 cell fails); the reader falls back to reading those
    [n_hist_buckets] cells and packs them into the youngest age band via
    {!Resistance_supply.hist_bands_of_legacy}, which under default band weights
    scores bit-identically to before lever f. Existing v3 warehouses therefore
    keep working with no rebuild. *)

val closure :
  ?snapshot_cb:Snapshot_callbacks.t ->
  ?stock_symbol:string ->
  ?weekly_sidetable:Weekly_sidetable.entry list ->
  stock:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  unit ->
  unit ->
  Resistance_supply.sketch option
(** [closure ?snapshot_cb ?stock_symbol ?weekly_sidetable ~stock ()] builds the
    [get_sketch] thunk for a {!Stock_analysis.callbacks} bundle. It reads at
    [as_of = stock]'s last bar date via {!read}, so passing [weekly_sidetable]
    activates the v5 side-table path and omitting it keeps the v4 / v3
    dense-column path (the production default until the v5 warehouse rebuild).
    Requires BOTH a snapshot shim and the stock symbol (and a non-empty [stock]
    view); missing either yields a [fun () -> None] thunk — the panel simply has
    no sketch to offer, so [Stock_analysis] leaves [supply = None]. *)
