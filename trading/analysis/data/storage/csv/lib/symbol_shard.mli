(** Shard directory letters for a symbol's on-disk bar store.

    Bars live at [<data_dir>/<L1>/<L2>/<SYMBOL>/], where [L1] and [L2] are the
    UPPERCASED first and last characters of the symbol. Uppercasing matters for
    renamed symbols with a lowercase suffix: [COMP_old] is stored under
    [C/D/COMP_old], not [C/d/COMP_old]. A case-insensitive filesystem (macOS)
    hides the difference; a case-sensitive one (Linux) silently drops the symbol
    (issue #3506). Every path builder must go through this module. *)

val letters : string -> string * string
(** [letters symbol] is [(L1, L2)]. A one-character symbol yields the same
    letter twice. Raises on the empty symbol. *)

val dir : string -> string
(** [dir symbol] is ["L1/L2"], e.g. [dir "AAPL" = "A/L"]. *)
