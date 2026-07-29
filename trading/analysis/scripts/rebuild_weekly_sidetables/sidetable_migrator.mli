(** Rebuild a snapshot warehouse's sketch-v5 [SYMBOL.weekly] side-tables on the
    split/dividend-adjusted basis (#2133), into a clone directory — never
    mutating the certified source warehouse.

    Pre-#2133 warehouses carry side-tables built from RAW weekly high/mid
    (manifest hash
    {!Data_panel_snapshot.Weekly_sidetable.format_hash_raw_basis}). This
    migrator derives adjusted-basis replacements and stamps the clone's manifest
    with {!Data_panel_snapshot.Weekly_sidetable.format_hash}, so the reader
    ({!Weekly_sidetable_reader.load_gated}) anchors them at [Adjusted_close].

    {2 Where the bars come from}

    A symbol's [.snap] file holds only the {e window} bars ([start .. end]); the
    original build additionally fed [sketch_deep_days] (default 3650) calendar
    days of {e deep} CSV history before the window start into the weekly series
    (the sketch's 520-week prefix — see [Build_runner._deep_bars]). The deep
    bars are NOT recoverable from the warehouse, so the migrator re-reads them
    from the CSV store:

    - {b window bars}: reconstituted verbatim from the symbol's [.snap] daily
      columns (raw O/H/L/C + [Adjusted_close] + volume) — the warehouse's own
      basis, immune to CSV refetches since the build;
    - {b deep bars}: the CSV store's bars in
      [[first_snap_date - sketch_deep_days, first_snap_date - 1]], re-pinned to
      the {e warehouse's} adjusted basis (below).

    {2 Basis pinning (the [basis_factor])}

    EODHD rebases [adjusted_close] over the whole history whenever a new
    dividend/split lands, so a CSV refetched after the warehouse was built can
    sit on a {e different} adjusted basis than the warehouse's [Adjusted_close]
    column — and side-table entries are compared against that column at read
    time. The migrator therefore samples snap-vs-CSV [adjusted_close] ratios on
    overlap dates: the ratios must agree up to the feed's 4-decimal rounding
    noise (a global rebase — their median is [c]); deep bars are then re-pinned
    by scaling their [adjusted_close] by [c] before the weekly fold. An unstable
    ratio (a genuine historical data revision, percents not basis-points of
    disagreement) or a missing CSV falls back to a snap-only rebuild (no deep
    prefix), flagged loudly in the outcome.

    {2 Validation artifact}

    For every symbol the migrator compares the rebuilt entry [week_end_date]s
    against the source side-table's — a basis migration must move only
    [mid]/[high] values, never the weekly-bar skeleton. Parity failures are
    flagged per symbol, and the whole run's outcomes are written to
    [<output-dir>/migration_report.sexp]. *)

(** How a symbol's rebuild went. [Rebuilt] is the healthy path; the two
    fallbacks rebuilt from snap-only bars (shallow weekly prefix — the symbol's
    early-window sketches see fewer weeks than the source build did). *)
type outcome =
  | Rebuilt of {
      deep_bars_used : int;  (** CSV deep bars fed into the weekly fold. *)
      basis_factor : float;
          (** The snap/CSV adjusted-basis ratio [c] applied to deep bars ([1.0]
              = CSV basis unchanged since the warehouse build). *)
    }
  | Fallback_no_csv  (** CSV store has no data for the symbol. *)
  | Fallback_unstable_basis
      (** Snap-vs-CSV adjusted ratios disagree across overlap samples — a
          historical data revision, not a global rebase; no honest re-pin
          exists. *)
[@@deriving sexp, equal]

type symbol_report = {
  symbol : string;
  outcome : outcome;
  date_parity : bool;
      (** [true] iff the rebuilt entries' [week_end_date]s equal the source
          side-table's 1:1 (the expected shape for a pure basis change). Always
          worth eyeballing when [false] — [Fallback_*] symbols lose their deep
          prefix, so parity failure is expected there. *)
}
[@@deriving sexp, equal]

type summary = {
  total : int;
  rebuilt : int;
  fallback_no_csv : int;
  fallback_unstable_basis : int;
  date_parity_failures : int;
  reports : symbol_report list;  (** One per manifest entry, manifest order. *)
}
[@@deriving sexp, equal]

val default_sketch_deep_days : int
(** Calendar-day deep-history span fed to the weekly prefix, matching
    [Build_runner.default_sketch_deep_days] (3650 ~ 520 trading weeks). *)

val migrate :
  warehouse_dir:string ->
  csv_data_dir:string ->
  output_dir:string ->
  ?sketch_deep_days:int ->
  unit ->
  summary Status.status_or
(** [migrate ~warehouse_dir ~csv_data_dir ~output_dir ?sketch_deep_days ()]
    clones the warehouse at [warehouse_dir] into [output_dir] with
    adjusted-basis side-tables:

    - each [SYMBOL.snap] is hard-linked (copied on link failure) into
      [output_dir] unchanged;
    - each [SYMBOL.weekly] is rebuilt adjusted-basis as described above;
    - the manifest is cloned with entry paths rewritten to bare filenames
      (relative to the clone — {!Snapshot_runtime.Daily_panels} resolves them
      against its [snapshot_dir]) and
      [weekly_sidetable_format_hash = Weekly_sidetable.format_hash];
    - the per-symbol outcomes land in [<output-dir>/migration_report.sexp] (the
      returned {!summary}, serialized).

    [output_dir] is created if absent. Returns [Error] when the source manifest
    can't be read or [output_dir] can't be created; per-symbol failures
    (unreadable [.snap], write errors) abort with [Error] rather than skipping
    silently — a partial clone must not masquerade as a full one. *)
