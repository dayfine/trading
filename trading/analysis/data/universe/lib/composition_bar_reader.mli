(** Minimal CSV bar reader used by {!Build_from_individuals}.

    Reads [data/<L1>/<L2>/<symbol>/data.csv] (the EODHD-shaped header is
    [date,open,high,low,close,adjusted_close,volume]) into a stripped record
    carrying just the fields the composition ranker needs: [date], [close],
    [adjusted_close], [volume]. OHL fields are dropped to keep memory low across
    ~14k symbols / 29 reconstitution years.

    A missing file or any malformed body returns [None] — composition treats
    this as "no bars on disk, skip the symbol", consistent with the inventory
    occasionally lagging the on-disk cache. *)

open Core

type bar = {
  date : Date.t;
  close : float;
  adjusted_close : float;
  volume : float;
}

val bars_path : bars_root:string -> string -> string
(** [bars_path ~bars_root symbol] returns
    [{bars_root}/<L1>/<L2>/{symbol}/data.csv] where [L1] is the first letter and
    [L2] is the last letter of [symbol] (or [L1] for single-character symbols).
    Matches {!Csv_storage.symbol_data_dir}'s sharding rule. *)

val read_bars : bars_root:string -> string -> bar list option
(** [read_bars ~bars_root symbol] returns [Some bars] if the symbol's CSV file
    is present and parseable, [None] otherwise. Malformed rows are silently
    dropped from the list. *)
