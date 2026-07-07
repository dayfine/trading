(** Markdown renderer for a {!Feature_screen.t} result.

    Emits: sample sizes, per-feature None coverage, the full-sample OLS table
    (coef / HC1-SE / t), the logistic table (coef / z, plus AUC), an era-split
    coefficient-sign-stability table, and a fixed screen-rigor caveats footer.
    All numbers are IN-SAMPLE; the footer states the epistemic limits. *)

val render : Feature_screen.t -> title:string -> string
(** [render t ~title] produces the full markdown report as a single string. *)
