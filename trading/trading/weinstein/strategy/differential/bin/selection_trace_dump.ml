(** Print the deterministic selection trace to stdout.

    The differential instrument for issue #2503: build this at two commits and
    [cmp] the two outputs. Byte-identical output means the two builds agree on
    every selection decision the trace covers. *)

let () = print_string (Selection_trace.render ())
