(** See [entry_ticket_suspend_mode.mli]. *)

type t = Off | On_bearish_macro | On_index_stage4 [@@deriving show, eq, sexp]
