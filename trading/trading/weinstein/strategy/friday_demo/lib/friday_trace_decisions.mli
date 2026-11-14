(** Stages 6 to 9 of the Friday trace: scoring, ranking, the entry walk and the
    orders. Split from {!Friday_trace_printer}, which calls it, to keep each
    file short. *)

val render : Buffer.t -> Friday_trace.t -> unit
(** [render buf t] appends stages 6 to 9 of [t] to [buf]. *)
