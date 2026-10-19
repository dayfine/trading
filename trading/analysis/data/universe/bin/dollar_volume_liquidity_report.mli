(** Entry-liquidity gate-flip tables from the dollar-volume scan. *)

val render : Buffer.t -> floor:float -> Dollar_volume_scan.t list -> unit
(** [render buf ~floor scans] appends the Markdown table, aggregating by
    calendar year in ascending order, including per-symbol flip counts and
    passes that rest on one bar. [floor] labels the heading. *)

val csv : Dollar_volume_scan.t list -> string
(** [csv scans] emits the per-symbol rows in scan order, omitting rows with no
    flips or one-bar passes. The header is emitted even for empty input. *)
