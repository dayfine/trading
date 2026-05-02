(** Convert dotted [key.path=value] strings into the partial-config sexp
    overlays consumed by [Backtest.Runner._apply_overrides].

    The runner already ingests partial-config sexps — see
    [Runner.run_backtest]'s [overrides] argument. The pre-existing [--override]
    CLI flag accepted only full sexp blobs (e.g.
    [--override '((stops_config ((initial_stop_buffer 1.05))))']), which is
    precise but verbose for one-off experiments.

    This module adds an ergonomic key-path syntax that compiles down to the same
    sexp overlay. Callers can mix the two forms freely — the runner sees only
    [Sexp.t list]:

    - [stops_config.initial_stop_buffer=1.05] →
      [((stops_config ((initial_stop_buffer 1.05))))]
    - [initial_stop_buffer=1.08] → [((initial_stop_buffer 1.08))]
    - [stage_config.ma_period=40] → [((stage_config ((ma_period 40))))]

    The value half is parsed as a sexp atom (numbers, booleans, atoms — and full
    sexp blobs in parentheses for richer right-hand sides). Keys may contain
    dots to nest into sub-records but no special syntax for lists or variants —
    those should be expressed as full sexp overrides. *)

open Core

type t = {
  key_path : string list;
      (** Components of the dotted key, e.g.
          ["stops_config"; "initial_stop_buffer"]. *)
  value : Sexp.t;
      (** Parsed right-hand side. Atoms ([1.05], [true], [Daily]) parse as
          [Sexp.Atom]; parenthesised values parse as [Sexp.List]. *)
}
(** A single parsed key-path override. *)

val parse : string -> t Status.status_or
(** [parse "key.path=value"] returns the parsed override or
    [Error Invalid_argument] for malformed input. Errors:
    - empty key or value
    - missing [=] separator
    - key path with empty components (e.g. [stops_config..buffer=1.0], [.foo=1],
      [foo.=1])
    - value half is not a parseable sexp *)

val to_sexp : t -> Sexp.t
(** Render [t] as a partial-config sexp ready for deep-merge into the default
    config. Always returns a record-shape sexp ([List [List [Atom k; v]]]) so
    the runner's deep-merge primitives accept it.

    Examples:
    - [{key_path=["initial_stop_buffer"]; value=Atom "1.05"}] →
      [((initial_stop_buffer 1.05))]
    - [{key_path=["stops_config"; "initial_stop_buffer"]; value=Atom "1.05"}] →
      [((stops_config ((initial_stop_buffer 1.05))))] *)

val parse_to_sexp : string -> Sexp.t Status.status_or
(** [parse_to_sexp s = Result.map (parse s) ~f:to_sexp] — convenience for
    callers that don't need the intermediate [t]. *)

val is_key_path_form : string -> bool
(** Returns [true] iff [s] looks like a [key.path=value] override (alphanumeric
    + underscore + dot prefix followed by [=]). Used by argument parsers to
      decide whether to dispatch to [parse] or to fall back to raw sexp parsing
      for backward compatibility. *)
