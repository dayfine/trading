(** Snapshot-warehouse reader for the rolling-start screener-based factors.

    The I/O layer between the snapshot warehouse
    ({!Snapshot_runtime.Daily_panels}) and the pure {!Rolling_start_factors}
    projections. {!Rolling_start_runner} calls {!factors_as_of} once per start
    (over a single shared panels handle) to fill each row's
    {!Rolling_start_types.per_start.factors} — the factor-decomposition lens
    stage 5b.

    Kept separate from the runner so the runner stays a thin orchestrator and
    the "read the precomputed cells as-of a date" logic is independently
    readable. It is impure (reads panels) — unlike {!Rolling_start_factors},
    which is the pure arithmetic the reader feeds. *)

open Core

val factors_as_of :
  panels:Snapshot_runtime.Daily_panels.t ->
  benchmark_symbol:string option ->
  universe:(string * string) list ->
  date:Date.t ->
  Rolling_start_factors.factors
(** [factors_as_of ~panels ~benchmark_symbol ~universe ~date] builds the four
    screener-based factor columns as-of [date], all from the {b precomputed}
    snapshot-warehouse fields (cheap point reads — no classifier re-run):

    - {b SPY/macro stage} + {b macro composite}: the benchmark index's [Stage]
      cell (decoded via {!Rolling_start_factors.macro_stage_of_value}) and
      [Macro_composite] cell as-of [date]. Both unavailable ([None] / [nan])
      when [benchmark_symbol] is [None] or it has no row on/before [date].
    - {b Stage-2 candidate count}: the number of [universe] symbols whose
      [Stage] cell decodes to Stage 2 as-of [date]
      ({!Rolling_start_factors.stage2_candidate_count}). [None] for an empty
      [universe] (could not scan); [Some 0] is a real "no setups" reading.
    - {b sector-RS dispersion}: the IQR of per-sector mean [RS_line] across
      [universe] as-of [date] ({!Rolling_start_factors.sector_rs_dispersion}).

    Each as-of read takes the latest row on/before [date] within a short
    lookback window (snapshot rows exist on trading days only, so [date] may be
    a weekend / holiday with no exact row). A missing row or absent field reads
    as unavailable ([nan] for the universe scan so {!Rolling_start_factors}
    skips it, [None] for the benchmark stage). [universe] is the
    [(symbol, sector)] list; an empty list leaves the two universe-scan factors
    unavailable. *)

val resolve_per_start :
  bar_data_source:Backtest.Bar_data_source.t option ->
  benchmark_symbol:string option ->
  universe:(string * string) list ->
  starts:Date.t list ->
  (Date.t, Rolling_start_factors.factors, Date.comparator_witness) Map.t
(** [resolve_per_start ~bar_data_source ~benchmark_symbol ~universe ~starts]
    computes every start's {!factors_as_of} once, reusing a {b single} shared
    {!Snapshot_runtime.Daily_panels} handle (built from [bar_data_source])
    across all starts — each symbol file decodes once and stays LRU-cached, so
    the whole sweep's factor reads are cheap. Returns a [start_date -> factors]
    map for {!Rolling_start_runner.run} to join onto its forked per-start jobs.

    Returns the {b empty} map (every start falls back to
    {!Rolling_start_factors.empty}) when [bar_data_source] is [None] (CSV mode —
    no shared-panels handle), or when
    {!Backtest.Bar_data_source.build_shared_panels} yields no panels / errors.
    The panels handle is opened and closed within this call; the parent owns the
    lifecycle. *)
