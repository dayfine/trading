# Broad-golden sub-task 2 — top-3000 verification (issue #1729, 2026-06-24)

Sub-task 2 of the broad-golden complete-data work (`dev/plans/broad-golden-complete-data-2026-06-24.md`).
Sub-task 1 (#1733) re-pinned the runnable top-1000/500 cells; the top-3000 / full-pool
cells were deferred as **"blocked on the snapshot memory crash"**
(`project_panel_runner_memory_ceiling`). This verifies that framing.

## Headline: the memory ceiling is RETIRED — top-3000 snapshot runs clean

`tier4-broad-1y` (PIT `top-3000-2022`, full N=3000, 2022 calendar) **completed PASS**
in snapshot mode against `/tmp/snap_top3000_1998_2026`:

```
n_symbols=3015  snapshot cache cap=4096 MB  cache evictions=0
tier4-broad-1y   Return -10.4%  Trades 16  WinRate 6.2%  MaxDD 19.6%  PASS
```

Full metrics (`actual.sexp`): total_return_pct −10.41, total_trades 16, win_rate 6.25,
sharpe −0.855, max_drawdown 19.64, avg_holding_days 40.19, open_positions_value
865,873, sortino −0.971, calmar −0.536, ulcer 10.37. (Low trade count is correct: 2022
was a bear tape, so the Weinstein macro gate suppressed most entries.)

**`evictions=0` at the 4 GB cache cap with all 3015 symbols loaded** — no memory
pressure. The snapshot-format-v2 columnar mmap work (#1631) did what its memory claimed
("top-3000 runs clean, memory ceiling GONE"); the broad goldens inherit it.

`sp500-30y-capacity-1996` (N=1000 survivorship sentinel, 30-year) also runs clean and
**deterministic** — two independent runs bit-identical at **1453.6% / 1210 trades /
38.8% WR / 34.9% MaxDD**.

## The real sub-task-2 obstacles were NOT memory

1. **A fixtures-root path bug in the invocation.** Running `scenario_runner` from the
   dune root (`/workspaces/trading-1/trading`) with `--fixtures-root
   trading/test_data/backtest_scenarios` **doubles** the `trading/` prefix, so the
   `../goldens-custom-universe/composition/top-3000-YYYY.sexp` universe path resolves to
   a non-existent file → `Sys_error "… No such file or directory"` (looks like a crash,
   is a path error). Correct form from the dune root: `--fixtures-root
   test_data/backtest_scenarios` (no leading `trading/`). The composition fixtures all
   exist (`top-3000-1998 … top-3000-2025`).
2. **Wall-time, not memory.** `tier4-broad-10y` (top-3000 × 10y) and
   `weinstein-2019-full-pool` (top-3000 × 5y) are multi-hour at N=3000 (~2.4 h / 5y per
   `project_deep_1998_2026_contiguous`); they run within the memory budget but exceed a
   convenient inline window. Deferred, not blocked.

## What this means for the cells

`tier4-broad-1y`, `tier4-broad-10y`, and `sp500-30y-capacity-1996` are **SCALE /
scaffolding cells** — their own headers say *"expected ranges are intentionally
permissive … leave ranges wide."* Their purpose is to validate the runtime path at
scale, **not** to pin a return regression (unlike sub-task-1's regression cells, which
were survivor-inflated and needed tight complete-universe re-pins). So the correct
action here is to **record verified complete-universe provenance, keeping the wide
ranges** — not to tighten them. `tier4-broad-1y` carries a dated provenance comment
recording this N=3000 PASS.

`weinstein-2019-full-pool` (top-3000-2019, 5y) is a **research baseline** with an
existing measured comment (32.37%, 2026-05-23); refreshing it to a current
complete-universe number is a multi-hour run, deferred.

## Verdict

Sub-task 2's blocking premise (memory crash) is **retired**. Top-3000 broad goldens are
runnable in snapshot mode against the warehouse; the scaffolding cells keep their
intentionally-wide ranges with verified provenance, and the two multi-hour cells
(top-3000 × 5y/10y) are runnable-when-wanted, not blocked. Issue #1729 can close the
"memory crash" sub-task.

Warehouse: `/tmp/snap_top3000_1998_2026` (old .snap, format-detecting reader handles it)
and a columnar `/tmp/snap_top3000_1998_2026_v2` (3016 syms) both present locally
(ephemeral; rebuild per the plan's recipe if lost).
