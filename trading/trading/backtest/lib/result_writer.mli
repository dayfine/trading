(** Serializes a [Runner.result] to an output directory. Intentionally separate
    from [Runner] so callers can run a backtest without writing anything, or
    customize what gets written. *)

val write : output_dir:string -> Runner.result -> unit
(** Write [params.sexp], [summary.sexp], [trades.csv], [equity_curve.csv],
    [open_positions.csv], [final_prices.csv], [splits.csv], [universe.txt], and
    [macro_trend.sexp] into [output_dir]. Also writes [stale_holds.sexp] iff
    [result.stale_holds] is non-empty. The directory must already exist.

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

val with_trades_stream :
  output_dir:string ->
  every_n_fridays:int ->
  start_date:Core.Date.t ->
  f:(on_step_setup:Panel_runner.step_hook_setup -> 'a) ->
  'a
(** [with_trades_stream ~output_dir ~every_n_fridays ~start_date ~f] runs [f]
    with a {!Panel_runner.step_hook_setup} that streams closed round-trips into
    [output_dir/trades.csv] as the run proceeds (issue #2502), and closes the
    stream when [f] returns or raises. Pass the hook to {!Runner.run_backtest}'s
    [?on_step_setup].

    Why this lives here rather than in {!Runner}: the batch a streamed row needs
    is exactly what {!write} writes at the end, extracted with {!Runner}'s own
    in-window filters — so the mid-run and end-of-run definitions of a
    [trades.csv] row cannot drift apart.

    [every_n_fridays] is the flush cadence; passing the run's [progress.sexp]
    cadence makes both artefacts advance together.
    {!Trades_stream.default_every_n_fridays} is the sensible default.

    {b The completed-run contract is unchanged.} {!write} re-creates
    [trades.csv] from scratch afterwards, truncating whatever the stream left,
    so a run that finishes produces exactly the bytes it did before streaming
    existed. The value is the run that {e doesn't} finish: a crash or OOM now
    leaves every round-trip closed before the kill on disk instead of nothing.

    Two consequences worth knowing. [trades.csv]'s presence no longer implies
    the run completed — the completion sentinel is unchanged ([actual.sexp]
    under the scenario runner, [summary.sexp] under [backtest_runner.exe]). And
    streamed rows carry no [position_id]; see {!Trades_stream} for why. *)
