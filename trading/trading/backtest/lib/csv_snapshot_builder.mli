(** Build an in-process snapshot directory from per-symbol CSVs.

    F.3.a-3 collapsed the legacy CSV path's [Ohlcv_panels] / [Bar_panels] /
    [Indicator_panels] build into an in-process snapshot directory. The CSV
    runner mode reads each universe symbol's CSV via [Csv_storage.get], filters
    to the simulator's active window, feeds the bars to the same
    {!Snapshot_pipeline.Pipeline.build_for_symbol} the offline writer uses, and
    serialises them to per-symbol [.snap] files under a tmp directory. The
    downstream setup is then identical to a pre-built snapshot mode run.

    {2 Cleanup of [/tmp/panel_runner_csv_snapshot_*] dirs}

    Each call to {!build} creates a fresh tmp directory under
    [Filename.temp_dir_name] (typically
    [/tmp/panel_runner_csv_snapshot_<hash>/], ~26-30 MB at 530 symbols). The
    {b normal} success path of long-running walk-forward rigs cleans these
    per-fold via {!cleanup} (caller invokes it after the fold completes).

    The {b abnormal} exit path (uncaught exception, [Stdlib.exit], graceful
    signal kill) is handled by this module itself:

    - Every dir returned by {!build} is registered in a process-wide cleanup
      ledger and scheduled for [Stdlib.at_exit] removal.
    - The first call to {!build} also installs handlers for [SIGTERM], [SIGINT],
      and [SIGHUP] that re-raise as [Stdlib.exit 130], so the at_exit chain runs
      on a graceful kill.
    - {!cleanup} removes a dir explicitly {b and} unregisters it from the
      ledger, so the at_exit handler does not double-rm.
    - [SIGKILL] is uncoverable — the kernel destroys the process before any
      handler runs. {!startup_orphan_sweep} provides a belt-and-suspenders sweep
      that removes orphans older than a threshold on startup.

    See {{!issue_1393} issue #1393} for the failure mode this guards: a killed
    or crashed walk-forward run accumulated ~53 GB of orphans over many days,
    eventually exhausting [/tmp] and ENOSPC-killing a fresh deep run. *)

open Core

val build :
  data_dir:Fpath.t ->
  universe:string list ->
  start_date:Date.t ->
  end_date:Date.t ->
  string * Snapshot_pipeline.Snapshot_manifest.t
(** [build ~data_dir ~universe ~start_date ~end_date] reads CSVs for every
    symbol in [universe] from [data_dir] (using the standard
    [Csv_storage.symbol_data_dir] layout), filters bars to
    [start_date..end_date] inclusive, runs each symbol's bars through
    {!Snapshot_pipeline.Pipeline.build_for_symbol}, and writes the resulting
    rows to per-symbol [.snap] files under a fresh tmp directory.

    Returns [(snapshot_dir, manifest)]: the path to the tmp directory and the
    in-memory directory manifest (also serialised to [<dir>/manifest.sexp]).

    The returned [snapshot_dir] is registered for cleanup on abnormal exit — see
    the module docstring. Callers should still call {!cleanup} explicitly on the
    success path; the at_exit hook then becomes a no-op for that dir.

    Missing-CSV / [NotFound] errors are tolerated: the symbol contributes an
    empty bar list, mirroring the legacy CSV loader's "row stays NaN" semantics.
    Any other [Csv_storage] / pipeline / serialisation error fails via
    [failwith] with a descriptive message — these all indicate programming or
    environment errors that the runner cannot recover from. *)

val cleanup : string -> unit
(** [cleanup dir] removes [dir] recursively if it exists and unregisters it from
    the at_exit cleanup ledger. Idempotent: calling it twice (or on a dir that
    does not exist) is a no-op.

    Use this on the success path immediately after the consumer is done with the
    snapshot directory. The at_exit hook will then skip this dir on process
    exit. *)

val register_for_cleanup : string -> unit
(** [register_for_cleanup dir] adds [dir] to the at_exit cleanup ledger and
    installs the SIGTERM / SIGINT / SIGHUP handlers (idempotent across calls).
    {!build} calls this internally on every dir it creates; tests and callers
    that allocate snapshot dirs through some other path can call it directly. *)

val registered_dirs : unit -> string list
(** [registered_dirs ()] returns the dirs currently in the cleanup ledger (i.e.
    created via {!build} and not yet {!cleanup}-ed). Intended for tests and
    diagnostics. *)

val startup_orphan_sweep : ?max_age_hours:float -> unit -> int
(** [startup_orphan_sweep ?max_age_hours ()] sweeps [Filename.temp_dir_name] for
    [panel_runner_csv_snapshot_*] directories whose mtime is older than
    [max_age_hours] (default 24) and removes them. Returns the count removed.

    This is a belt-and-suspenders defense against the SIGKILL / power-loss case
    the at_exit hook cannot cover. The per-call at_exit registration is the
    load-bearing fix; this sweep handles the residual long-tail.

    Safe to call multiple times. Errors removing individual dirs (e.g.
    permission, EBUSY) are swallowed; the sweep continues. *)
