(** Markdown rendering of an after-tax lens run.

    Produces (1) a pre-tax vs after-tax summary, (2) a per-year table including
    the carryforward trajectory, and (3) the top-winners days-to-LT diagnostic.
*)

val render : Tax_model.result -> Diagnostics.winner_row list -> string
(** [render result winners] returns the full markdown report. *)
