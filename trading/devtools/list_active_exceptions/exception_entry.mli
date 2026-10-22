(** Parsing and review-status helpers for active exception reporting. *)

type conf_entry = {
  linter : string;
  path_substr : string;
  reason : string;
  review_at : string option;
  status : string;
}
(** One parsed exception row, including its computed review status. *)

val contains_substring : string -> string -> bool
(** [contains_substring s sub] tests whether [sub] occurs in [s]. *)

val split_on_char_custom : char -> string -> string list
(** Split on the given character, retaining empty parts and their order. *)

val trim : string -> string
(** Strip leading and trailing spaces, tabs, newlines and carriage returns. *)

val compute_status : string option -> string
(** Return [no-review-at] for a missing/blank annotation, [expired] for a date
    strictly before the current UTC date, and [active] otherwise. *)

val extract_review_at : string -> string option
(** Return trimmed text after the first [review_at:] occurrence, if any. *)

val read_conf_entries : string -> conf_entry list
(** Read a config file in order, ignoring comments, blank and malformed lines.
    Raises [Sys_error] when the file cannot be opened. *)
