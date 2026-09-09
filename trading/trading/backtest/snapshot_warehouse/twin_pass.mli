(** The builder-side {b rename-twin} pass: load each symbol's windowed
    adjusted-close series, run {!Twin_detector} over the set, drop the losing
    legs, and write the sidecar report.

    {!Twin_detector} is a pure function of a config plus a list of
    already-loaded series. This module is the thin I/O shell around it — bar
    loading, the windowing, the sidecar write, and the shared CLI flag block —
    factored out so {e both} warehouse builders run the identical pass rather
    than one of them carrying a private copy.

    That asymmetry is the defect this module closes (#2730): the pass was wired
    only into [build_scenario_snapshots.exe], while the vintage rebuilds
    ([dev/experiments/warehouse-rebuild-2026-09-06/rebuild2.sh]) go through
    [build_snapshots.exe] via {!Build_runner}. The resulting [_v7mark]
    warehouses still carry twin pairs (NLS/BFX, BB/BBRY, AABA/YHOO, DOC/HCP_old,
    …), so a backtest holding both legs double-counts one position — measured at
    ~$764k of duplicated P&L on one arm, and the effect grows with any
    stop-width lever that keeps the second leg alive longer. Same shape as the
    splice-flag gap in #2711.

    {b Default-off.} With {!Twin_detector.Config.default} (which is
    [enabled = false]) {!run} reads no bar, writes no file, and returns its
    input symbol list unchanged — so every existing build stays byte-identical
    until a caller explicitly arms the pass. *)

open Core

val report_name : string
(** Filename of the sidecar written into the build's output directory:
    [rename_twin_report.txt]. It holds {!Twin_detector.render}'s rendering of
    the config plus every detected group, and is also echoed to stderr. *)

val params : Twin_detector.Config.t Command.Param.t
(** Shared CLI flag block, so both builders expose one surface and one set of
    defaults: [-dedupe-rename-twins] (the master switch, default off),
    [-twin-basis levels|returns], [-twin-min-overlap-days],
    [-twin-match-fraction], [-twin-close-epsilon], [-twin-ret-epsilon].

    Every numeric default comes from {!Twin_detector.Config.default}. An
    unrecognised [-twin-basis] value fails the command with the accepted
    spellings rather than silently falling back to [Levels]. *)

val run :
  Twin_detector.Config.t ->
  data_dir:Fpath.t ->
  start_date:Date.t option ->
  end_date:Date.t option ->
  output_dir:string ->
  string list ->
  string list * string list
(** [run config ~data_dir ~start_date ~end_date ~output_dir symbols] returns
    [(survivors, dropped)], where [survivors] is [symbols] with every dropped
    twin leg removed (input order preserved) and [dropped] is the sorted set
    that was removed.

    - [config] disabled (the default) → [(symbols, [])] with no bar read and no
      file written. This is the bit-identical passthrough.
    - [config] enabled → each symbol's CSV history under [data_dir] is loaded
      and windowed to the inclusive [start_date] / [end_date] bounds (either
      [None] means unbounded on that side — the same contract as
      {!Bar_window.filter}), projected to its [(date, adjusted_close)] series,
      and handed to {!Twin_detector.detect}. The report is written to
      [output_dir/]{!report_name} and echoed to stderr.

    A symbol whose CSV is missing, unreadable, or empty in-window contributes no
    series and therefore can never be matched or dropped — it simply survives.

    The window matters: two legs are compared only over the bars the build
    itself will store, so a pass run over a warmup-windowed build sees the same
    overlap the warehouse will. *)
