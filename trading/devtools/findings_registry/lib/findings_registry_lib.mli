(** Findings registry: parse [dev/findings/registry.sexp] and verify that every
    row's guard still exists (issue #3001).

    A backtest surprise is a "finding". Each row records the guard that pins it
    (a unit test, a validator check, both, or none with a reason) so that a
    deleted or renamed guard fails CI instead of silently un-pinning the
    finding.

    {2 Row shape}

    {v
    ((issue 2982)
     (finding "stop raise mixes adjusted MA with raw bars")
     (guard ((unit ("<repo-relative test file>" "<test name>"))
             (validator V13)))
     (status fixed-behind-flag))
    v}

    - [issue]: integer, optional. A row must carry [issue] or [ref].
    - [ref]: string, optional (e.g. ["salt0-analysis section 3 #11"]).
    - [guard]: either the atom [none] (then [reason] is required), or a list of
      [(unit (FILE NAME))] / [(validator Vn)] entries; at least one, repeatable.
    - [reason]: string, optional (required for [none]).
    - [status]: one of {!statuses}. *)

type unit_guard = { file : string; test : string }

type guard =
  | No_guard
  | Guards of { units : unit_guard list; validators : string list }

type t = {
  issue : int option;
  ref_ : string option;
  finding : string;
  guard : guard;
  reason : string option;
  status : string;
}

val statuses : string list
(** Accepted [status] values: [open], [fixed], [fixed-behind-flag], [wontfix],
    [observation]. *)

val kind : t -> string
(** Guard kind for display: ["unit"], ["validator"], ["both"] or ["none"]. *)

val label : t -> string
(** Human label for error messages, e.g. ["#2982"] or the [ref] string. *)

val parse : Sexplib.Sexp.t list -> t list * string list
(** Parse top-level rows. Returns the rows that parsed plus one error message
    per malformed row (unknown key, missing field, bad guard shape, bad status,
    [none] without reason). *)

val registered_validators : string -> string list
(** [registered_validators source] returns the ids [V<n>] found as [("V<n>",]
    tuples in the text of [validator_checks.ml], in order. Reading the ids from
    that source keeps the check from carrying its own list. *)

val contains : haystack:string -> needle:string -> bool
(** Fixed-string substring test. *)

val check_rows :
  validators:string list ->
  read_file:(string -> string option) ->
  t list ->
  string list
(** Existence checks. Returns one message per violation: a [unit] guard whose
    file is missing (per [read_file], given the repo-relative path) or does not
    contain the test name, or a [validator] id not in [validators]. *)
