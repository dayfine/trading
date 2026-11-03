(** Resumable-backtest checkpoint directory (#3477 PR 6).

    A checkpoint is the directory [<scenario_dir>/checkpoint/]:
    - [header.sexp]: {!header}, the version, the position in the run and the
      {!identity} of the run that wrote it;
    - [simulator.sexp] (simulator and dependency state), [strategy.sexp],
      [stop_log.sexp], [trade_audit.sexp], [force_liquidation_log.sexp] and
      [candidates.sexp] (present only when candidate capture is on): one sexp
      per component, each a [capture] of PRs 3-5;
    - [steps.sexpl]: the step journal ({!Step_journal}), holding the first
      [header.n_steps] steps. The simulator snapshot is stored without its
      steps.

    {!write} builds the directory under a temporary name and renames it into
    place, so [checkpoint/] is always either absent or complete. {!load}
    validates the header against the resuming run and refuses on any mismatch.
*)

open Core

val version : int
(** Checkpoint format version. Bump it when any component's sexp changes. *)

val dir_name : string
(** ["checkpoint"]. *)

type identity = {
  config_digest : string;
      (** Digest of the run's strategy config, dates, cash and strategy. *)
  build_sha : string;  (** {!Build_info.git_sha}. *)
  manifest_digest : string;  (** Digest of the snapshot manifest. *)
  seed_salt : string option;  (** [TRADING_PATH_SEED_SALT], if set. *)
}
[@@deriving sexp]
(** What must be identical between the run that wrote a checkpoint and the run
    that resumes it. *)

type header = {
  version : int;
  date : Date.t;
  n_steps : int;
  identity : identity;
}
[@@deriving sexp]
(** [date] is the simulator's next date to step; [n_steps] the steps completed.
*)

type state = {
  simulator : Trading_simulation.Simulator.Checkpoint.snapshot;
  strategy : Weinstein_strategy.Weinstein_strategy_state.snapshot;
  stop_log : Stop_log.snapshot;
  trade_audit : Trade_audit.snapshot;
  force_liquidation_log : Force_liquidation_log.snapshot;
  candidate_log : Candidate_log.snapshot option;
}
(** Everything a resumed run restores. [simulator.steps] is the full history. *)

val identity_of :
  run_key:Sexp.t -> manifest:Sexp.t -> seed_salt:string option -> identity
(** [identity_of ~run_key ~manifest ~seed_salt] digests the two sexps and adds
    the compiled-in {!Build_info.git_sha}. *)

val write :
  ?before_commit:(unit -> unit) ->
  scenario_dir:string ->
  identity:identity ->
  state ->
  unit Status.status_or
(** Write [state] as the scenario's checkpoint, replacing any earlier one.
    [before_commit], a testing seam, runs after every file is written and before
    the rename; an exception from it leaves the previous checkpoint (or none) in
    place. [Error] on an I/O failure; the previous checkpoint is untouched. *)

val load :
  scenario_dir:string -> expect:identity -> (header * state) Status.status_or
(** Read the checkpoint, after checking its version and each {!identity} field
    against [expect]. The [Error] names the first field that differs, with both
    values. Also [Error] when the directory or a component is missing or does
    not parse. *)

(** {1 Friday hook} *)

type request = {
  scenario_dir : string;
  every_n_fridays : int;
      (** Checkpoint on every N-th Friday, counted from the start of this run (a
          resumed run counts from its resume point); [Int.max_value] never
          writes (a resume-only run). *)
  resume : bool;
      (** Continue from the checkpoint already in [scenario_dir] instead of
          starting from the window's first day (#3477 PR 7). *)
  halt_after_checkpoints : int option;
      (** Test-only: [Stdlib.exit 75] once this many checkpoints have been
          written, simulating a killed run. [None] in production. *)
}
(** Ask a run to checkpoint into [scenario_dir] on every [every_n_fridays]-th
    Friday, and optionally to resume from the checkpoint found there. *)

val load_for_resume :
  request:request ->
  run_key:Sexp.t ->
  manifest:Sexp.t ->
  (header * state) Status.status_or
(** {!load} the checkpoint in [request.scenario_dir], validated against the
    identity {!setup} would write for this [run_key] and [manifest]. *)

val friday_hook :
  request:request ->
  identity:identity ->
  strategy_state:Weinstein_strategy.Weinstein_strategy_state.t ->
  stop_log:Stop_log.t ->
  trade_audit:Trade_audit.t ->
  force_liquidation_log:Force_liquidation_log.t ->
  candidate_log:Candidate_log.collector option ->
  date:Date.t ->
  Trading_simulation.Simulator.t ->
  unit
(** The [?on_friday] closure for {!Panel_step_loop.run_simulator_with_gc_trace}
    once applied up to [~candidate_log]: counts the Fridays it is called on and
    {!write}s on every [every_n_fridays]-th. A failed write is reported on
    stderr and the run continues. Raises [Failure] when
    [request.every_n_fridays] is not positive. *)

val setup :
  resumed:state option ->
  request:request option ->
  weinstein:bool ->
  run_key:Sexp.t ->
  manifest:Sexp.t ->
  stop_log:Stop_log.t ->
  trade_audit:Trade_audit.t ->
  force_liquidation_log:Force_liquidation_log.t ->
  candidate_log:Candidate_log.collector option ->
  Weinstein_strategy.Weinstein_strategy_state.t option
  * (date:Date.t -> Trading_simulation.Simulator.t -> unit) option
(** What a run needs to checkpoint: the strategy state (fresh, or restored from
    [Some] [resumed], the state {!load_for_resume} returned) it must build its
    strategy over (via {!Weinstein_strategy.make_with_state}) and the
    {!friday_hook} sharing it, with an identity digested from [run_key],
    [manifest] and the build. [(None, None)] without a [request], which is the
    unchanged default. Raises [Failure] when [weinstein] is false (v1 supports
    the Weinstein strategy only) or [request.every_n_fridays] is not positive.
*)
