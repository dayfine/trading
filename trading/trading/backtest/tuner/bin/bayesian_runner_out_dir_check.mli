(** Belt-and-suspenders [--out-dir] guard for [bayesian_runner.exe].

    Sweep output must be written under [/tmp/sweeps/] so that snapshot churn
    inflates the bind-mounted host directory, not the container's writable layer
    (which is what caused the 2026-05-23..25 ~16h-of-wall-time Docker.raw
    runaway). [dev/scripts/launch_sweep.sh] enforces this at launch time; this
    module enforces it at the binary's own arg-parse time so a direct
    [dune exec ... bayesian_runner.exe --out-dir <bad>] also fails fast.

    Authority: [.claude/rules/sweep-hygiene.md] +
    [dev/plans/sweep-and-qc-architecture-2026-05-26.md]. *)

val validate :
  out_dir:string ->
  ?env_lookup:(string -> string option) ->
  unit ->
  unit Status.status_or
(** [validate ?env_lookup ~out_dir] returns [Ok ()] when [out_dir] starts with
    [/tmp/sweeps/], OR when [env_lookup] returns [Some "1"] for the documented
    override env var [BAYESIAN_RUNNER_ALLOW_NON_SWEEP_OUTPUT]. Returns [Error]
    (an [invalid_argument] [Status.t]) otherwise; the message names both the
    violated rule + the override.

    [env_lookup] defaults to [Sys.getenv]; injected for unit tests. *)

val validate_or_exit : out_dir:string -> unit
(** [validate_or_exit ~out_dir] runs [validate] with the live [Sys.getenv]. On
    [Ok ()] returns [unit]; on [Error] writes the message to stderr and calls
    [Stdlib.exit 2]. *)
