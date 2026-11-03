(** The git commit the binary was built from, compiled in by a dune rule. *)

val git_sha : string
(** Full commit hash of the build tree, or ["unknown"] when git is unavailable.
    A checkpoint records it and refuses to resume under a different value, so
    state written by one build is never fed to code that may interpret it
    differently. *)
