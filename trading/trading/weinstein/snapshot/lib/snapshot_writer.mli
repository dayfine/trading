(** Sexp serializer for {!Weekly_snapshot.t}.

    Produces a canonical, sortable on-disk representation. The output is plain
    sexp (no compression, no binary framing) — same shape used throughout the
    codebase — so existing sexp-aware tooling (jq-style readers, [sexp pretty])
    works without adaptation.

    {1 Output shape}

    See {!Weekly_snapshot} for the field-by-field schema.

    {1 File naming}

    The {!path_for} helper returns the canonical on-disk path for a snapshot.
    File names use the [YYYY-MM-DD.sexp] form so lexicographic listing equals
    chronological order.

    {1 Round-trip}

    [Snapshot_reader.parse (serialize t) = Ok t] for every well-formed [t]. The
    round-trip property is pinned by [test_round_trip.ml]. *)

open Core

val serialize : Weekly_snapshot.t -> string
(** [serialize t] returns the sexp form of [t] as a string, with a trailing
    newline. The output is canonical: deterministic field order, no comments. *)

val path_for : root:string -> system_version:string -> Date.t -> string
(** [path_for ~root ~system_version date] returns the canonical on-disk path for
    a snapshot of the given system version and date.

    Layout: [<root>/<system_version>/<YYYY-MM-DD>.sexp].

    Pure function — does not touch the filesystem. *)

val write_to_file :
  root:string ->
  system_version:string ->
  Weekly_snapshot.t ->
  string Status.status_or
(** [write_to_file ~root ~system_version t] serializes [t] and writes it to
    [path_for ~root ~system_version t.date], creating parent directories as
    needed. Returns the path written on success.

    Errors are reported as [Status.t]:

    - [Invalid_argument] if [t.system_version <> system_version] (guard against
      mis-routed writes).
    - [Internal] if filesystem I/O fails. *)
