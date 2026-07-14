(** JS behaviour + closing tags half of the interactive report page.

    Generic client-side JS (plus the closing [</script></body></html>]) that
    reads every value from the [DATA] object literal injected into
    {!Html_template.markup}. It hides the benchmark line, the utilization chart,
    the open-positions table, and the conformance / behavioural panels when the
    corresponding [DATA] fields are absent/empty. *)

val script : string
(** The report's JS, beginning with a leading newline so it appends directly
    after {!Html_template.markup}'s [const DATA=...;] line. *)
