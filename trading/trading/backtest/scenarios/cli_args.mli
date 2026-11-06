(** Command-line parsing for [scenario_runner]. *)

type checkpoint_flags = {
  every_n_fridays : int option;  (** [--checkpoint-every N]. *)
  resume : string option;
      (** [--resume <dir>]: continue the one scenario whose artefact directory
          (or its [checkpoint/] subdirectory) is [dir]. *)
  halt_after_checkpoints : int option;
      (** [--halt-after-checkpoint K], test-only: the worker exits
          {!Backtest.Backtest_checkpoint.halt_exit_code} (75) after K
          checkpoints. The parent reports that scenario as HALTED, not FAIL, and
          [scenario_runner] exits 75 when every non-passing scenario halted; a
          crash still exits 1. *)
}

type t = {
  dir : string;
  parallel : int;
  fixtures_root : string option;
  snapshot_dir : string option;
      (** Snapshot warehouse directory; [None] keeps CSV mode. *)
  progress_every : int;  (** Friday-cycle cadence for [progress.sexp]. *)
  emit_all_eligible : bool;  (** [false] under [--no-emit-all-eligible]. *)
  emit_candidates : bool;  (** [true] under [--emit-candidates]. *)
  checkpoint : checkpoint_flags;  (** Resumable-backtest flags (#3477). *)
}

val repo_root : unit -> string
(** Repository root (parent of the default data dir), with trailing slash. *)

val parse_args : unit -> t
(** Parse [Sys.argv]; prints usage and exits 1 on a bad flag. *)
