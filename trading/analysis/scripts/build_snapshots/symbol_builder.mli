(** Per-symbol stage of the snapshot build, extracted from {!Build_runner}: load
    a symbol's CSV bars, apply series hygiene (splice cut, tail rule,
    store-level classify), run the snapshot pipeline, and write the [.snap] and
    [.weekly] files. *)

type built = {
  entry : Snapshot_pipeline.Snapshot_manifest.file_metadata;
  last_bar : Core.Date.t option;
      (** Date of the last stored bar; [None] when the entry was reused from a
          previous incremental run (no bars read). *)
  findings : Snapshot_pipeline.Series_tail.finding list;
  level : Snapshot_pipeline.Series_level.finding option;
      (** Store-level review row, when the level pass is armed and this symbol's
          stored series failed its rule. *)
}
(** One built symbol. *)

type hygiene
(** Series-hygiene knobs (tail config + exceptions, level config, splice cuts)
    bundled so the per-symbol call chain threads one parameter. *)

val make_hygiene :
  tail_config:Snapshot_pipeline.Series_tail.Config.t ->
  tail_exceptions:Snapshot_pipeline.Series_tail.Exceptions.t ->
  level_config:Snapshot_pipeline.Series_level.Config.t ->
  splice_cuts:Core.Date.t Core.Map.M(Core.String).t ->
  hygiene
(** Bundle the hygiene knobs. [splice_cuts] maps symbols to the date to keep
    bars from (#2672 class ii). *)

val benchmark_bars_opt :
  data_dir:Fpath.t ->
  start_date:Core.Date.t option ->
  end_date:Core.Date.t option ->
  benchmark_symbol:string option ->
  Types.Daily_price.t list option
(** Windowed bars of the benchmark symbol; [None] when no benchmark is requested
    or its load fails (a warning is printed). *)

val process_symbol :
  data_dir:Fpath.t ->
  start_date:Core.Date.t option ->
  end_date:Core.Date.t option ->
  sketch_deep_days:int ->
  schema:Data_panel_snapshot.Snapshot_schema.t ->
  benchmark_bars:Types.Daily_price.t list option ->
  output_dir:string ->
  existing:Snapshot_pipeline.Snapshot_manifest.t option ->
  manifest_path:string ->
  checkpoint:bool ->
  hygiene:hygiene ->
  string ->
  built option
(** Build (or, when the existing manifest entry is current, reuse) one symbol.
    [None] when the symbol is skipped (no CSV, load or build failure; reason on
    stderr). *)
