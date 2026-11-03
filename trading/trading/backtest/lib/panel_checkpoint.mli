(** Checkpoint and resume wiring for {!Panel_runner} (#3477 PR 7): what the run
    asks of {!Backtest_checkpoint} and how a loaded checkpoint is put back. *)

open Core

type window = Date.t * Date.t * int * float
(** [(start_date, end_date, warmup_days, initial_cash)]: with the strategy
    config, what identifies a run. *)

type resumed = Backtest_checkpoint.header * Backtest_checkpoint.state
(** A loaded, validated checkpoint. *)

val manifest_sexp : Snapshot_pipeline.Snapshot_manifest.t -> Sexp.t
(** The content identity of a snapshot manifest, for the [~manifest] of
    {!Backtest_checkpoint.setup} and {!Backtest_checkpoint.load_for_resume}:
    schema hash, side-table hash and, per symbol, the byte size, payload md5 and
    delisting marker. File paths and source-CSV mtimes are left out: a CSV-mode
    run builds its snapshot in a fresh temporary directory every time, and the
    same bars must resume the same run. *)

val load_resume :
  checkpoint:Backtest_checkpoint.request option ->
  config:Weinstein_strategy.config ->
  window:window ->
  manifest:Snapshot_pipeline.Snapshot_manifest.t ->
  candidate_log:Candidate_log.collector option ->
  resumed option
(** The checkpoint to continue from, when [checkpoint] asks to resume; [None]
    otherwise. Raises [Failure] when the checkpoint is missing, unreadable or
    from a run with a different identity, and when [candidate_log] is given (a
    restore would replace the caller's collector). *)

val restore_sim :
  Trading_simulation.Simulator.t ->
  resumed option ->
  Trading_simulation.Simulator.t
(** The freshly built simulator positioned where the checkpoint was taken;
    unchanged for [None]. Raises [Failure] when the restore is refused. *)

val resume_date : resumed option -> Date.t option
(** The first date a resumed run steps. *)

val hooks :
  resumed:Backtest_checkpoint.state option ->
  checkpoint:Backtest_checkpoint.request option ->
  strategy_choice:Strategy_choice.t ->
  config:Weinstein_strategy.config ->
  window:window ->
  manifest:Snapshot_pipeline.Snapshot_manifest.t ->
  stop_log:Stop_log.t ->
  trade_audit:Trade_audit.t ->
  force_liquidation_log:Force_liquidation_log.t ->
  candidate_log:Candidate_log.collector option ->
  Weinstein_strategy.Weinstein_strategy_state.t option
  * (date:Date.t -> Trading_simulation.Simulator.t -> unit) option
(** {!Backtest_checkpoint.setup} for a run: the strategy state to build the
    strategy over and the Friday hook; both [None] without a request. *)
