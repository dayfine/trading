(** Command-line parsing for [scenario_runner]. *)

type t = {
  dir : string;
  parallel : int;
  fixtures_root : string option;
  snapshot_dir : string option;
      (** Snapshot warehouse directory; [None] keeps CSV mode. *)
  progress_every : int;  (** Friday-cycle cadence for [progress.sexp]. *)
  emit_all_eligible : bool;  (** [false] under [--no-emit-all-eligible]. *)
  emit_candidates : bool;  (** [true] under [--emit-candidates]. *)
}

val repo_root : unit -> string
(** Repository root (parent of the default data dir), with trailing slash. *)

val parse_args : unit -> t
(** Parse [Sys.argv]; prints usage and exits 1 on a bad flag. *)
