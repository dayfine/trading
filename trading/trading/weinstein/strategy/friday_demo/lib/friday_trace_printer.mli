(** Plain-text rendering of one Friday's pipeline, stage by stage.

    Each of the nine stages prints a banner, one line on what it does, what it
    takes in and what it puts out, then a table of its result. The text depends
    only on the {!Friday_trace.t} it is given, so the same printer serves the
    synthetic demo and any later caller that builds a {!Friday_trace.t} from
    real bars. *)

val render : Friday_trace.t -> string
(** [render t] is the full trace, newline-terminated. Deterministic: no clock,
    no environment, collections in the order [t] holds them. *)
