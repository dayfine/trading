(** [scenario_runner]'s checkpoint and resume flags (#3477 PR 7). *)

val request :
  scenario_dir:string ->
  Cli_args.checkpoint_flags ->
  Backtest.Backtest_checkpoint.request option
(** The request one scenario's run takes. [None] unless checkpointing or
    resuming was asked for, so the default run is untouched. A resume that does
    not also checkpoint never writes one. *)

val plan :
  resume:string option ->
  (string * Scenario.t) list ->
  (string * Scenario.t) list * string
(** [plan ~resume scenarios] is the scenarios to run and the output root their
    artefacts go under. Without [resume], all of them under a fresh timestamped
    root. With [resume], the one scenario whose artefact directory (or its
    [checkpoint/] subdirectory) was named, in the root that directory sits in.
    Exits 1 when no single scenario matches. *)

val print_halted_row :
  output_root:string -> checkpoints:int option -> Scenario.t -> unit
(** Print the results-table row for a scenario whose worker exited
    {!Backtest.Backtest_checkpoint.halt_exit_code}:
    [HALTED at checkpoint <n> (<date>)], with [n] from [checkpoints] (the
    [--halt-after-checkpoint] value) and the date read from the checkpoint
    header; ["?"] for whichever is unavailable. Not a failure row. *)

val exit_code : pass_flags:bool list -> halted_flags:bool list -> int
(** The runner's process exit code from per-scenario [pass_flags] and
    [halted_flags] (same length, same order): 0 when every scenario passed;
    {!Backtest.Backtest_checkpoint.halt_exit_code} when every non-passing
    scenario halted at a checkpoint (a wrapper may resume); 1 when any scenario
    failed or crashed. *)
