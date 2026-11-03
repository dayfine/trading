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
