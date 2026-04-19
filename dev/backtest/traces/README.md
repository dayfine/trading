# Backtest phase traces

Per-run phase-tracing sexp output lives here. One file per backtest run:
`<run-id>.sexp`, written via `Backtest.Trace.write` when
`Runner.run_backtest` is called with `?trace:(Some ...)`.

Raw traces are run artifacts. The committed directory exists only so
`Out_channel.with_file` doesn't fault on a fresh checkout.

## Retention policy

Ad-hoc — see `dev/plans/backtest-scale-optimization-2026-04-17.md`
§Decisions #3. No automatic cleanup; prune manually when noise
accumulates.
