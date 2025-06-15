type entry = { symbol : string; csv_path : Fpath.t } [@@deriving show, eq]
type t

val create : csv_dir:string -> t
(** Create a new registry from a directory of CSV files *)

val get : t -> symbol:string -> entry option
(** Get an entry by symbol *)

val list : t -> entry list
(** List all entries in the registry *)
