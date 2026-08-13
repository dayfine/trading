(** File-discovery: which [lib/*.ml] files the magic-number linter scans, and
    which of those are excluded by [linter_exceptions.conf]. Extracted from
    {!Magic_numbers_linter_lib} purely to keep that file under the file-length
    linter's limit -- nothing here inspects file *content*, only paths. *)

val read_magic_number_exclusions : string -> string list
(** [read_magic_number_exclusions conf_path] reads
    [magic_numbers <path-substring> ...] rows from a
    [linter_exceptions.conf]-formatted file at [conf_path] and returns the path
    substrings. Returns [] if [conf_path] does not exist. *)

val is_excluded : string list -> string -> bool
(** [is_excluded excludes path] is [true] if [path] contains any of the
    [excludes] substrings. *)

val collect_lib_ml_files : string -> string list
(** [collect_lib_ml_files root] walks [root] and returns every path whose name
    ends in [.ml] (but not [.pp.ml]) and contains [/lib/] -- mirrors the shell
    [find] pruning [_build]/[.formatted] at any depth and selecting paths
    matching [*/lib/*.ml] but not [*.pp.ml]. Note this has no file-type filter:
    a matching DIRECTORY is both returned and still walked into (only
    [_build]/[.formatted] are pruned from descent). *)
