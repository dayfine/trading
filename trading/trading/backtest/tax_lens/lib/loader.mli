(** Load a scenario output directory into [Tax_types.run_data].

    Reads [trades.csv] (closed round-trips) and [equity_curve.csv] (daily
    pre-tax portfolio value). No other file is consulted; open positions are
    deliberately ignored under the realization basis. *)

val load_exn : string -> Tax_types.run_data
(** [load_exn dir] parses [dir/trades.csv] and [dir/equity_curve.csv]. Raises if
    either file is missing or malformed. *)
