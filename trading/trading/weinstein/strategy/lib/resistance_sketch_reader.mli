(** Read a resistance-v2 sketch ({!Resistance_supply.sketch}) out of the
    warehouse snapshot columns for the [Stock_analysis] overhead-supply score.

    Extracted from {!Panel_callbacks} (keeps that coordinator under the
    file-length cap). The sketch cells live as precomputed scalar columns in the
    snapshot schema; this module bridges {!Snapshot_runtime.Snapshot_callbacks}
    field reads to the pure {!Resistance_supply.sketch} record. *)

module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks

val read_sketch :
  cb:Snapshot_callbacks.t ->
  symbol:string ->
  as_of:Core.Date.t ->
  Resistance_supply.sketch option
(** [read_sketch ~cb ~symbol ~as_of] reads the sketch columns
    ([Res_max_high_130/260/520w], [Res_bars_seen], [Res_hist k] for
    [k = 0 .. n_hist_buckets - 1], and [Close] as the histogram anchor) at
    [(symbol, as_of)]. Returns [None] if ANY required cell read fails (missing
    row, a schema without the sketch columns, or a decode error) — a partial
    read never fabricates a sketch. *)

val closure :
  ?snapshot_cb:Snapshot_callbacks.t ->
  ?stock_symbol:string ->
  stock:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  unit ->
  unit ->
  Resistance_supply.sketch option
(** [closure ?snapshot_cb ?stock_symbol ~stock ()] builds the [get_sketch] thunk
    for a {!Stock_analysis.callbacks} bundle. It reads at [as_of = stock]'s last
    bar date. Requires BOTH a snapshot shim and the stock symbol (and a
    non-empty [stock] view); missing either yields a [fun () -> None] thunk —
    the panel simply has no sketch to offer, so [Stock_analysis] leaves
    [supply = None]. *)
