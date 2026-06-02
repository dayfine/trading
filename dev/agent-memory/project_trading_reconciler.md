---
name: trading-reconciler external repo + design docs
description: External P&L reconciliation tool for trading-1 backtest runs. Independent codebase to catch accounting bugs internal QC misses.
type: project
originSessionId: 3d750cdc-15d7-4d5a-992a-73af38ed62e9
---
External P&L reconciliation tool. Lives in a separate repo
(`dayfine/trading-reconciler`, currently bootstrapped with design doc only)
to break the "internal QC validates against the same code that produced
the data" failure mode that shipped the AAPL split-day cliff bug to main
on 2026-04-29.

**Why:** `trading-1`'s audit harness, optimal-strategy counterfactual,
metrics pins, etc. all run inside the same OCaml codebase that generated
the trades. A bug in the simulator's accounting can pass every internal
test because both test and production share the broken implementation.
Demonstrated by the cliff-drop bug that drove sp500-2019-2023 to negative
cash on 2020-08-31 — internal QC was clean. An external arithmetic-only
reconciler would have caught it.

**Where:**

- **GH repo**: `dayfine/trading-reconciler` (created 2026-04-29; design
  doc only).
- **Local staging**: `~/Projects/trading-reconciler/` with three docs
  (consolidated to one canonical PHASE_1_SPEC.md by user):
  - `README.md` — design / why / phases / language recommendation (Python).
  - `PHASE_1_SPEC.md` — consolidated accounting + I/O contract spec.
    Authoritative for Phase 1 implementation. Folds in the event-walk
    correction (was originally split into PHASE_1_SPEC + RESOLUTIONS).

**Key spec decisions** (in case future-me needs the load-bearing bits
without rereading the doc):

- **Event-walk, not row-walk**. Each trades.csv row → 2 events (Entry +
  Exit); sort by `(date, csv_row_order)`; walk + cash-floor check at
  every event. Row-walk misses the AAPL bug because it only applies the
  net round-trip at exit_date.
- **Strict realized-cash floor** in Phase 1 (`cash >= -epsilon_absolute`
  at every event). No soft-floor with unrealized accumulator — that
  needs `--daily-prices` (Phase 2).
- **Mirror `trading-1` G3 (PR #694)** for cash-impact formulas: LONG
  entry debits cash; SHORT entry credits cash (proceeds); etc.
- **Splits** require `--splits` CSV input. Without it, reconciler
  refuses to verify any trade whose `[entry_date, exit_date]` window
  intersects a known split (exit code 2). Silent wrong-reconciliation
  defeats the whole purpose.
- **Open positions**: separate `--open-positions` input file (NOT
  encoded in trades.csv). Entry events injected into the walk;
  unrealized P&L computed from `--open-positions × --final-prices`
  combination at end-of-run.
- **Exit codes**: 0 (clean) / 1 (usage) / 2 (parse) / 3 (P&L diverge)
  / 4 (cash floor violated — the load-bearing AAPL-class catcher) /
  5 (open-position price missing). Walk-to-completion; gather all
  divergences; exit with max severity (4 > 3 > 5 > 0).
- **Python recommended** for bootstrap (Backtrader / pandas already
  model FIFO accounting; .claude/rules/no-python.md applies to
  trading-1 only, not external repos).

**Status**: implementation deferred to user's separate bootstrap
session. The two repos communicate via the CLI contract defined in
PHASE_1_SPEC.md — both can iterate independently as long as that schema
stays stable.

**Trigger to revisit**: when an accounting bug is suspected in
trading-1 and internal QC says clean.
