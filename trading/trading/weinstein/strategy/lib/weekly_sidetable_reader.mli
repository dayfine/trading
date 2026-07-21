(** Sketch-v5 (PR 2 of 4): derive a {!Resistance_supply.sketch} from the sparse
    per-symbol weekly side-table ({!Data_panel_snapshot.Weekly_sidetable}) by
    bucketing AT SCORE TIME against the row's raw close, plus the manifest-gated
    loader for the [SYMBOL.weekly] side-file.

    The v4 warehouse materialized, for every trading day, an 80-cell age-banded
    histogram re-anchored to that day's close
    ({!Snapshot_pipeline.Resistance_sketch}). That is ~350x redundant with the
    per-symbol weekly series it is derived from, so a top-3000 warehouse did not
    fit the Docker VM. The v5 storage (PR 1) keeps only the weekly series in a
    [SYMBOL.weekly] side-file; this module is the read path that reconstructs
    the identical sketch on demand.

    {2 The v5-equals-v4 contract}

    {!sketch_of_entries} reproduces the v4 dense-column sketch {b bit-for-bit}
    at any [as_of] equal to a side-table entry's [week_end_date] — the anchor is
    the greatest [week_end_date <= as_of] (the current, age-0 week), the
    finalized weeks are the entries before it, and the horizons / age bands /
    log buckets are computed with constants and float arithmetic copied verbatim
    from {!Snapshot_pipeline.Resistance_sketch}. Because the strategy scores
    overhead supply only at week-close (the weekly-view's last-bar date is a
    [week_end_date]), that is exactly the set of dates it is ever queried at in
    production. The bit-exact equality across a synthetic pipeline is pinned by
    [test_weekly_sidetable_reader.ml] (the intended guard against constant drift
    from the duplicated pipeline logic).

    For a mid-week [as_of] (not a [week_end_date]) the sketch anchors at the
    greatest earlier [week_end_date], so it lags v4's intra-week partial week by
    one bar — a difference that never arises in production. *)

module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

val sketch_of_entries :
  entries:Weekly_sidetable.entry list ->
  as_of:Core.Date.t ->
  close:float ->
  Resistance_supply.sketch
(** [sketch_of_entries ~entries ~as_of ~close] derives the sketch a breakout
    scored on [as_of] at raw close [close] would face, from the weekly side-table
    [entries] (oldest-first, one per weekly bar — the {!Weekly_sidetable_builder}
    order; the binary-search windowing requires ascending [week_end_date]).

    The window is the trailing at-most-520 entries whose [week_end_date <= as_of]
    (the current/age-0 week last). Then, mirroring
    {!Snapshot_pipeline.Resistance_sketch}:
    - [max_high_130w/260w/520w]: max raw [high] over the trailing 130/260/520
      window entries (age-0 week included);
    - [bars_seen]: count of entries at/before [as_of], capped at 520;
    - [hist_bands.(b).(k)]: count of window entries of age band [b]
      ([0-26w / 26-78w / 78-130w / 130-520w], age = distance in weekly bars from
      the age-0 week) whose raw [high > close] and whose [mid] lands in the log
      bucket [k] of [[close * 2^(k/20), close * 2^((k+1)/20))]; mids at or beyond
      [2 * close] are dropped;
    - [anchor_close]: [close].

    Corrupt anchor: when [close] is non-positive or non-finite every derived cell
    is [Float.nan] (mirroring the v4 corrupt-bar row), with [anchor_close = close]
    verbatim. Pure function. *)

val load_gated :
  snapshot_dir:string ->
  symbol:string ->
  manifest_format_hash:string option ->
  Weekly_sidetable.entry list option Status.status_or
(** [load_gated ~snapshot_dir ~symbol ~manifest_format_hash] loads the
    [<snapshot_dir>/<symbol>.weekly] side-file, gating on the warehouse
    manifest's recorded side-table format hash
    ({!Snapshot_pipeline.Snapshot_manifest.weekly_sidetable_format_hash}):

    - [manifest_format_hash = None] (no side-table warehouse) -> [Ok None];
    - [Some h] with [h <> Weekly_sidetable.format_hash] -> [Error Internal] — a
      loud refusal to read a side-table produced under a different format, the
      same discipline the runtime applies to a snapshot schema-hash skew;
    - [Some h] matching, file absent -> [Ok None] (this symbol has no side-file;
      the caller falls back to the dense columns);
    - [Some h] matching, file present -> [Ok (Some entries)] via
      {!Weekly_sidetable.read_file} (any decode failure surfaces as its
      [Error Internal]). *)

val loader_for :
  snapshot_dir:string ->
  manifest_format_hash:string option ->
  symbol:string ->
  Weekly_sidetable.entry list option
(** [loader_for ~snapshot_dir ~manifest_format_hash] is the partially-applied,
    raising form of {!load_gated} used to build the [weekly_sidetable_loader]
    threaded into {!Bar_reader.of_snapshot_views}: it fixes the warehouse dir +
    manifest format hash and returns a per-[symbol] loader. On the [load_gated]
    [Ok] path it returns the option verbatim ([None] = no side-table for this
    symbol / no side-table warehouse -> the dense read path); on the [Error]
    path (a present-but-mismatched manifest format hash) it {b raises}
    [Failure] — the loud staleness refusal, so a warehouse whose side-tables
    were produced under a different format is never silently read. *)
