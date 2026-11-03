(** Flat-directory sexp file I/O for {!Backtest_checkpoint}: one sexp per
    component file, with errors that name the file. Extracted from
    [backtest_checkpoint.ml] (#3477) to keep that module under the file-length
    limit. *)

open Core

val remove_dir : string -> unit
(** Remove a flat directory of files and the directory itself; an absent
    directory is fine. *)

val write_sexp : dir:string -> string -> Sexp.t -> unit
(** [write_sexp ~dir name sexp] writes [sexp] (human-readable, newline
    terminated) to [dir/name], replacing any existing file. *)

val read_as : dir:string -> string -> (Sexp.t -> 'a) -> 'a Status.status_or
(** [read_as ~dir name of_sexp] loads [dir/name] and converts it. A missing file
    is [NotFound]; a file that does not parse, or parses to the wrong shape, is
    [Invalid_argument]. Every error message names the file. *)
