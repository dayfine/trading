(** Serializes a [Runner.result] to an output directory. Intentionally separate
    from [Runner] so callers can run a backtest without writing anything, or
    customize what gets written. *)

val write : output_dir:string -> Runner.result -> unit
(** Write [params.sexp], [summary.sexp], [trades.csv], [equity_curve.csv],
    [open_positions.csv], [final_prices.csv], [splits.csv], [universe.txt], and
    [macro_trend.sexp] into [output_dir]. The directory must already exist.

    Additionally writes [trade_audit.sexp] iff [result.audit] is non-empty.
    Empty audit lists (the pre-PR-2 default, capture sites not yet wired)
    produce no file rather than a sexp containing [()] — consumers must tolerate
    the file's absence.

    [macro_trend.sexp] is always written (one entry per Friday the screener
    fired, possibly empty list) — counterfactual tooling consumes it to replay
    per-Friday macro state. See {!Macro_trend_writer}.

    [universe.txt] is always written — one symbol per line, no header, captured
    from [result.universe]. Downstream counterfactual tooling
    ([optimal_strategy]) loads this file to scope its analysis to the actual
    run's universe; an empty [universe] yields an empty file.

    The reconciler-producer artefacts ([open_positions.csv], [splits.csv],
    [final_prices.csv]) are always written, header-only when there is nothing to
    record. Consumed by the external [trading-reconciler] tool to verify
    cash-floor / held-through-split / unrealized-P&L accounting — see
    [~/Projects/trading-reconciler/PHASE_1_SPEC.md] §3 + §4 + §3.3. *)
