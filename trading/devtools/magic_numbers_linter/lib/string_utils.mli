(** Small, generic char-level string utilities shared by
    {!Magic_numbers_linter_lib}. No external string/regex library (mirrors
    [devtools/list_active_exceptions.ml]'s style) -- plain char-level scanning
    only. Extracted from the main module purely to keep that file under the
    file-length linter's limit; nothing here is magic-number-linter specific. *)

val contains_substring : string -> string -> bool
(** [contains_substring s sub] is [true] if [sub] occurs anywhere in [s]. *)

val count_occurrences : string -> string -> int
(** [count_occurrences s sub] counts non-overlapping, left-to-right occurrences
    of [sub] in [s]. *)

val ends_with : string -> string -> bool
(** [ends_with s suffix] is [true] if [s] ends with [suffix]. *)

val split_fields : string -> string list
(** [split_fields s] splits [s] on runs of spaces/tabs, like awk's default field
    splitting: leading/trailing whitespace ignored, empty fields collapsed. *)

val find_substring : string -> string -> from:int -> int option
(** [find_substring s sub ~from] returns the index of the first occurrence of
    [sub] in [s] at or after [from], or [None] if not found. *)

val is_digit : char -> bool
(** [is_digit c] is [true] for ['0'..'9']. *)

val is_word_or_dot : char -> bool
(** [is_word_or_dot c] is [true] for letters, digits, underscore, or a literal
    dot. Used as the "glued to an identifier" lookaround guard in numeric-token
    extraction: a dot counts as a word character here so that dotted tokens like
    [v1.2.3] are correctly rejected as non-candidates. *)

val digit_run_end : string -> int -> int
(** [digit_run_end s start] returns the index just past the maximal run of digit
    characters in [s] beginning at [start] (or [start] itself if [s.[start]] is
    not a digit). *)

val lookahead_ok : string -> int -> bool
(** [lookahead_ok s pos] is [true] if [pos] is at or past the end of [s], or
    [s.[pos]] is not {!is_word_or_dot} -- i.e. a numeric token ending at [pos]
    is not glued to a following identifier/digit/dot. *)
