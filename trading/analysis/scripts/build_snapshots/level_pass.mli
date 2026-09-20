(** The build-time store-level sanity pass: the CLI surface and the review
    sidecar for {!Snapshot_pipeline.Series_level}, which until now was written,
    tested and called by nothing.

    {!Snapshot_pipeline.Series_level} is pure by construction — no I/O, no clock
    — so the two impure halves of arming it (a [Core.Command] flag block and a
    file write) live here rather than in that module or in the already-large
    [build_runner.ml]. The shape is {!Twin_pass}'s: an in-build pass whose own
    module owns its report name, its sidecar write and its shared [params], so
    both builders ([build_snapshots.exe] and [build_scenario_snapshots.exe])
    expose one identical flag surface instead of two drifting copies. The
    {e contract} — default-off, report-only, a CSV sidecar beside the warehouse
    — is [-detect-splices]' (#2649), of which this is the third sibling after
    [splices.csv] and [terminal_runs.csv].

    {b Report-only, and unarmed by default.} {!params} defaults
    {!Snapshot_pipeline.Series_level.Config.enabled} to [false], under which
    {!Snapshot_pipeline.Series_level.classify} reads no bar and returns [None]
    for every symbol, and {!write_report} writes no file at all. An un-armed
    build is therefore bit-identical to its pre-wiring behaviour, byte for byte
    in every [.snap] and in the manifest. Armed, it is {e still} bit-identical:
    the pass classifies the series the builder already decided to store and has
    no action type, so nothing is dropped, cut or truncated whatever it finds.
    Acting on a finding is a separate, later decision (see the module's own
    header and [dev/status/post-run-validation.md] §Follow-ups). *)

val report_name : string
(** Filename of the review sidecar written into the output directory:
    [series_level.csv]. Named after the pass, like [terminal_runs.csv] and
    [splices.csv] beside it. *)

val write_report :
  Snapshot_pipeline.Series_level.Config.t ->
  output_dir:string ->
  Snapshot_pipeline.Series_level.finding list ->
  unit
(** [write_report config ~output_dir findings] writes {!report_name} under
    [output_dir] and logs {!Snapshot_pipeline.Series_level.summary} to stdout.

    {b Gated on [config.enabled], not on [findings] being empty}, and the
    distinction is the whole point: an armed pass that found nothing writes the
    header alone, which is the positive evidence that the scan ran — the same
    convention [terminal_runs.csv] and [splices.csv] follow. An {e empty} report
    is an expected outcome here rather than a symptom of dead wiring: the
    sub-class the {!Snapshot_pipeline.Series_level.Class.Whole_window} rows
    would come from (a mis-scale seam falling outside the build window) has no
    instance in any committed 2026-ending vintage.

    A disabled pass writes nothing, so an un-armed build leaves no trace in its
    output directory.

    A write failure is logged, never fatal: the warehouse is the build's product
    and this file is its audit trail, so a read-only output directory must not
    fail a build that otherwise succeeded. Same call it is modelled on
    ([Build_runner]'s tail report). *)

val params : Snapshot_pipeline.Series_level.Config.t Core.Command.Param.t
(** Shared CLI flags, so both builders expose the same surface and the same
    defaults: [-detect-series-level] (the master switch, {b off} by default),
    [-series-level-median-max R] and [-series-level-min-bars N].

    The two tuning knobs mirror [-splice-min-ratio] / [-splice-max-ratio]: every
    field of {!Snapshot_pipeline.Series_level.Config.t} is reachable from the
    command line, so a reviewer recalibrating the ceiling against a real
    warehouse never has to edit and rebuild. Their defaults are the config's
    own. *)
