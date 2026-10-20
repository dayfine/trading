(** Splice-pass wiring for {!Build_scenario_snapshots}: loads each symbol's
    windowed bars, runs {!Splice_detector} + {!Snapshot_pipeline.Series_splice},
    writes the [splices.csv] / [splice_actions.csv] sidecars, and returns the
    surviving symbols plus the cuts the builder must apply. *)

open Core

val load_windowed_bars :
  data_dir:Fpath.t ->
  warmup_start:Date.t ->
  end_date:Date.t ->
  string ->
  Types.Daily_price.t array option
(** [load_windowed_bars ~data_dir ~warmup_start ~end_date symbol] is the
    symbol's daily bars with [warmup_start <= date <= end_date] (both bounds
    inclusive), ascending by date. [None] when the CSV is missing, unreadable,
    or has no bar in the window. *)

val plan_splices :
  config:Splice_detector.Config.t ->
  splice_config:Snapshot_pipeline.Series_splice.Config.t ->
  exceptions:Snapshot_pipeline.Series_splice.Exceptions.t ->
  data_dir:Fpath.t ->
  warmup_start:Date.t ->
  end_date:Date.t ->
  output_dir:string ->
  string list ->
  string list * Date.t Map.M(String).t
(** [plan_splices ~config ~splice_config ~exceptions ~data_dir ~warmup_start
     ~end_date ~output_dir symbols] returns [(survivors, cuts)]. With
    [config.enabled = false] it does no I/O: every symbol survives, no cuts, no
    file written. Armed, it scans the windowed series, writes [splices.csv] and
    [splice_actions.csv] under [output_dir] (creating it if absent), drops
    symbols the rule or an exception drops (order of [symbols] preserved), and
    maps each cut symbol to the date it keeps from. *)
