(** Append-only journal of simulator steps, one sexp per line.

    A resumable backtest keeps its [step_result]s outside the checkpoint, so a
    checkpoint stays small. The contract: {b append the steps before writing
    the checkpoint that counts them}. A crash between the two leaves extra
    lines past the checkpoint's step count, which {!read} ignores and
    {!truncate} drops. (#3477 PR 5.) *)

type step_result = Trading_simulation_types.Simulator_types.step_result

val file_name : string
(** ["steps.sexpl"], the journal's name inside a checkpoint directory. *)

val append : path:string -> step_result list -> unit
(** Append one line per step, creating the file if needed. *)

val read : path:string -> n_steps:int -> step_result list Status.status_or
(** The first [n_steps] steps. Later lines (a torn tail) are not parsed. [Error]
    when the file is missing, has fewer than [n_steps] lines, or one of the
    first [n_steps] lines does not parse; the message names the line. *)

val truncate : path:string -> n_steps:int -> unit Status.status_or
(** Keep only the first [n_steps] lines, via a temporary file and a rename.
    [Error] when the file is missing or has fewer than [n_steps] lines. *)
