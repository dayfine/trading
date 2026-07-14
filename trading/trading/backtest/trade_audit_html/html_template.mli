(** Markup + CSS half of the interactive trade-audit report page.

    A complete HTML document head, inline stylesheet, and body skeleton, ending
    with the opening [<script>] tag and [const DATA=/*DATA*/;]. {!Html_render}
    concatenates it with {!Html_script.script} and substitutes the run's JS
    object literal for the single [/*DATA*/] placeholder. No run figures live
    here — every value is injected via [DATA]. *)

val markup : string
(** The document head/CSS/body through [const DATA=/*DATA*/;], with exactly one
    [/*DATA*/] placeholder. *)
