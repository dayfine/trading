(** Generic fork-based worker pool for CPU-bound, embarrassingly-parallel OCaml
    jobs.

    Motivation: backtest sweeps (walk-forward CV folds, Bayesian-opt evals,
    scenario_runner catalog runs) are pure of their inputs and share no state.
    Running them serially leaves cores idle and — more importantly once
    {!Backtest.Runner.run_backtest} is involved — accumulates per-call heap
    residue in a long-lived parent process (~25 MB per backtest as of
    2026-05-19, see
    {{:../../../dev/notes/bayesian-int-rounding-bug-2026-05-19.md}
     bayesian-int-rounding-bug-2026-05-19}). Fork-per-job sidesteps both: the OS
    schedules workers across cores and reclaims each child's heap on exit.

    Concurrency model: at any time at most [parallel] children are alive. Each
    child runs exactly one job, marshals its result onto a pipe to the parent,
    and exits. The parent reaps children and reassembles the result array in
    input-index order.

    Failure semantics: first-failure short-circuit. If any child raises or exits
    abnormally, the parent sends [SIGTERM] to all remaining children, waits for
    them to reap, and re-raises the failure wrapped with the failing job's
    index. This matches the pre-existing serial behaviour modulo timing — a
    serial sweep would also have stopped at the first failure.

    Determinism: each child runs an independent, side-effect-free job, so float
    ops and Hashtbl iteration order are deterministic within that child. The
    parent reassembles results in input-index order, which is independent of the
    (non-deterministic) child completion order. As long as the caller's
    [jobs.(i)] closures are themselves deterministic, the overall output array
    is deterministic too.

    The [parallel = 1] case takes a no-fork fast path (direct in-process
    iteration), which preserves the simple synchronous call-stack for tests +
    debuggers and avoids the marshal round-trip when there's no parallelism to
    gain. *)

val max_parallel : int
(** Hard upper bound on [parallel]. Enforced by {!run_parallel} — values above
    this are rejected with [Invalid_argument]. The cap is a sanity check against
    accidental fork-bombs (e.g. a user typing [--parallel 1000]); typical
    dev-container budgets are 4-8 anyway. *)

val run_parallel : parallel:int -> jobs:(unit -> 'a) array -> 'a array
(** [run_parallel ~parallel ~jobs] runs each [jobs.(i)] in a separate forked
    child process, with at most [parallel] children alive at any time, and
    returns the results in input order: result [i] is the value returned by
    [jobs.(i) ()].

    The [parallel = 1] case is special-cased to a direct in-process
    [Array.map (fun job -> job ()) jobs] — no fork, no marshalling. This
    preserves the synchronous call-stack so callers' debuggers + stack traces
    work normally when not actually parallelising.

    For [parallel > 1], each child marshals its result via the [Stdlib]
    [Marshal] module across an OS pipe. Therefore [jobs.(i) ()] results must be
    marshallable: closures, [Lazy.t], abstract objects, and a few other types
    are not. Plain records / variants / strings / ints / floats / lists / arrays
    / [Hashtbl.t]s of marshallable contents are all fine.

    @param parallel
      Maximum number of concurrent children. Must satisfy
      [1 <= parallel <= max_parallel]; otherwise [Invalid_argument] is raised
      before any fork happens.

    @param jobs
      Array of thunks to evaluate. Each thunk runs in its own child (except for
      the [parallel = 1] fast path). The order of the returned array matches
      [jobs]: returned [i] = [jobs.(i) ()].

    @raise Invalid_argument if [parallel < 1] or [parallel > max_parallel].

    @raise Failure
      if any job raises or its child exits abnormally. The exception message is
      wrapped with the failing job's index so the caller can correlate back to
      its work-item table. *)
