(** Pure serializer: {!Html_data.t} to a complete self-contained HTML document.

    Emits the run's data as a JS object literal ([const DATA={...}]) and
    substitutes it for the [/*DATA*/] placeholder in
    [{!Html_template.markup} ^ {!Html_script.script}]. Deterministic for a given
    input — no timestamps. Symbol and label strings are JS-escaped. *)

val render : Html_data.data -> string
(** Render the report to a complete self-contained HTML document. *)
