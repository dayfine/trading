(** Serializes a [Runner.result] to an output directory. Intentionally separate
    from [Runner] so callers can run a backtest without writing anything, or
    customize what gets written. *)

val write : output_dir:string -> Runner.result -> unit
(** Write [params.sexp], [summary.sexp], [trades.csv], and [equity_curve.csv]
    into [output_dir]. The directory must already exist. *)
