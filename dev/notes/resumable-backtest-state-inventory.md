# Resumable backtests: state inventory (#3477 PR 1)

Read against `origin/main` @ `7615dde7d` (2026-10-29), host-only (grep for `ref` / `mutable` / `Hashtbl` / `Queue`, then the call paths). It is the checklist for PRs 3-6: every item marked **S** must be captured and restored, every **R** rebuilt on resume. The byte-identity acceptance test (PR 7) is the backstop for anything this scan missed.

Decision 2026-10-29: the order manager's hash-order dependence is removed first (PR 0, fill in insertion order), so the checkpoint never has to reproduce a Stdlib hash-table bucket layout.

**There is no RNG state to save.** The #3425 seeded tiebreak is a stateless FNV-1a hash of `seed|date|ticker` (`screener_ranking.ml:126-159`). The intraday-path RNG is seeded per bar (`market_state.ml:82-90`). The real hazards are below.

**Top hazards**
1. **`Trading_orders.Manager`** (`orders/lib/manager.ml:20`) uses two *Stdlib* Hashtbls. `list_orders ~filter:ActiveOnly` returns them in `Hashtbl.fold` order, unsorted, and `Engine.process_orders` fills in that order while checking cash one order at a time. So bucket order changes results. **Resolved by PR 0:** the manager stamps an insertion sequence and `list_orders` sorts by it; the checkpoint saves the sequence counter and each order's sequence number.
2. **`Entry_audit_capture._position_counter`** (`entry_audit_capture.ml:53-57`) is a process-global ref that mints `SYM-wein-N` position ids. These key trades, the trade audit and the stop log.
3. **Dividend-crediting cache**: save its key set too. A rebuild would count `DividendMissingFileCount` misses twice.
4. **Engine `market_state.bars`**: the last bar ever seen per symbol. Orders on symbols with no bar that day fill against it.
5. **`Hashtbl.keys` of `stashed`** goes into `held_tickers` unsorted (`entry_ticket_suspend.ml:221`). Low risk.

**State inventory** (S = save, R = rebuild on resume)
- **Simulator** (`simulator.ml:112-129`):
  - S: date, portfolio, positions (no sexp yet), step_history (no sexp yet; its `Order.t` carries wall-clock times), last_known_prices, valuation_failure_count, Fill_router order_links.
- **Deps:**
  - S: Manager, engine bars and the stop-limit count, `Entry_fill_retry.used`, cash-yield total, dividend crediting, the stale-hold log.
  - R: the panel LRU and other read-through caches.
- **Strategy closures** (`weinstein_strategy.ml:403-452`):
  - S: the state tuple in `weinstein_strategy_state.ml:3-53` (stops, stop-outs, prior macro/stages/MA, peak tracker, streaks), `pending_entry_e`, freeze pins, suspend stash/origins.
  - R: A-D and breadth series, the weekly MA cache, the sidetable memo.
  - v1 supports the Weinstein strategy only; it refuses other `strategy_choice` values.
- **Recorders:**
  - S: Stop_log, Trade_audit with its cascade_summaries queue, FL log, Candidate_log.
  - R: Trades_stream and progress, both from step_history.

**Metrics:** `_build_run_result` batch-computes every metric over the full step history. Keep that rather than move to streaming. Store steps as an append-only journal (`steps.sexpl`); the checkpoint records `n_steps`. Out of the byte-identity check: `wall_seconds.txt`, `progress.sexp`, the gc trace.

**Design**
- **Format:** a `<scenario_dir>/checkpoint/` dir with `header.sexp` plus one sexp per component, written atomically (tmp dir, then rename). Sexp, not Marshal.
- **Hook:** `?on_friday` in `Panel_step_loop.run_simulator_with_gc_trace` (`panel_step_loop.ml:71-83`); `Panel_runner.run` builds the closure.
- **CLI:** `--checkpoint-every N` (Fridays); `--resume <scenario_dir>` (one scenario only); `--halt-after-checkpoint K`, test-only, exits 75.
- **Refuse on mismatch:** config digest, build SHA (compiled-in), snapshot manifest digest, `TRADING_PATH_SEED_SALT`, checkpoint version.

**PR breakdown** (each under ~500 lines)
1. State-inventory note, plus a test that a Manager round-trip keeps the same `list_orders` order.
2. Sexp derivers for Position, Order types, step_result, price_bar, Split_event, with round-trip tests.
3. `Simulator.Checkpoint` and capture/restore for the deps. Test: run a fixture to D, capture, restore into a fresh sim, run both to the end, and require an equal `run_result`. The fixture needs resting stops and dividends.
4. Strategy state record, `make_with_state`, the position counter, freeze and suspend. Test: snapshot/restore mid-run, with freeze and suspend armed. This is the hardest PR.
5. Recorder capture/restore and the step journal.
6. `Backtest_checkpoint` (header, validation, atomic dir) and the hook.
7. CLI flags and the acceptance test: an armed small golden, run uninterrupted vs paused at D and resumed, must byte-diff clean. It must arm StopLimit, suspend and dividends; unarmed goldens never walk the intraday path.
8. After merge: one goldens-broad cell byte-identical, with D placed mid-crash.

**Size:** about 2.5–3.5k lines over 7 PRs, roughly 1.5–2 weeks of agent time.

**Risks:**
- state the grep scan missed, such as closures in sub-libraries. The armed byte-diff test is the backstop.
- checkpoint size: tens of MB. Keep the cadence at 26 Fridays or more.
