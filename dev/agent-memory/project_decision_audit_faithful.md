---
name: project_decision_audit_faithful
description: "decision_audit tool (#1799) + first real run verdict — selection is FAITHFUL, entry-selection lever confirmed dead on real data; only lever left = explicit capacity"
metadata: 
  node_type: memory
  type: project
  originSessionId: b69b7ea0-879e-4b35-a918-38f2e67d75e2
---

The **`decision_audit`** report (`trading/trading/backtest/decision_audit/`,
lib+bin, PR #1799, 2026-07-01) renders a per-screen **faithfulness** audit:
funded entries vs cash-rejected near-misses on *captured* features (score,
rs_value, volume_ratio, weeks_advancing, stage, sector). NOT an outcome grader.
Phase-0 (#1799) enriched `Trade_audit.alternative_candidate` with those features
(required fields, no `[@sexp.default]` → pre-2026-07-01 `trade_audit.sexp` files
won't parse; a fresh run is mandatory).

**First real run verdict (2026-07-01, #1803, writeup
`dev/notes/decision-audit-first-real-run-2026-07-01.md`):** run on 3 sp500 smoke
windows (bull/crash/recovery, default config). **Selection is FAITHFUL** — no
captured feature separates funded from near-miss in an exploitable direction:
score/volume separate in the funded-favoured direction (we already fund on both);
weeks_advancing separates (funded fresher) but earliness was already WF-CV-rejected
(#1793); rs_value underpowered (~77% `None`). Confirms the 2026-06-30 noise-floor
grid → the only remaining entry-side lever is **explicit capacity/diversification**
(`[[project_capacity_concentration_surface]]`), NOT a better sort. Re-derives
`[[project_edge_is_the_fat_tail]]` / `[[project_accuracy_is_unreachable_diversify_instead]]`
from a per-screen angle. Calibrated as a proxy screen, not a rejection
(`[[project_mechanism_validation_rigor]]`): short windows, point-estimate means.

**Invocation (reruns):** build `backtest_runner.exe` + `decision_audit_bin.exe`,
then `docker exec -d -e TRADING_DATA_DIR=/workspaces/trading-1/trading/test_data
trading-1-dev … backtest_runner.exe --smoke --csv-mode --experiment-name <n>`
(smoke = 3 sp500 ~500-sym windows, container-fit, each emits `trade_audit.sexp`;
default runner is snapshot-mode which emits NO audit → `--csv-mode` required). ⚠
`TRADING_DATA_DIR` MUST be passed via `-e`/inline `env` — `dune exec` and
`nohup … &` both DROP it (silently resolves to `/workspaces/trading-1/data`, the
full 10.5k universe that OOMs). Then `decision_audit_bin --audit <win>/trade_audit.sexp
--out r.md`.

**Phase-2 counterfactual — BUILT + RUN (#1806/#1807, 2026-07-01).** Forward-return
counterfactual (`decision_audit --snapshot-dir <warehouse> --horizon-weeks 12`):
12w forward return from screen date, funded vs cash-rejected near-miss, bars from a
snapshot warehouse. Result (3 sp500 windows, wfcv-top500-1998): **outcome CONFIRMS
faithful selection** — crash funded −2% vs near-miss −12% (protective!), bull flat,
recovery near-miss +3pp but driven by `Insufficient_cash` = the cash line = explicit
capacity lever NOT a sort gap. No window shows funded under-returning in a way a
better SORT fixes. Entry-selection is now dead-confirmed on outcomes too; only lever
= explicit capacity (`[[project_capacity_concentration_surface]]`). Caveat: proxy,
~half warehouse coverage (top-500-PIT ≠ sp500-smoke universe drops ~50% of symbols).
Writeup: `dev/notes/decision-audit-first-real-run-2026-07-01.md` §Phase-2.

**Open follow-ups:** (1) RS-coverage harness gap: ~77% of sp500 candidates carry
`rs_value=None`; investigate before trusting RS-based faithfulness reads. (2) Cleaner
counterfactual rerun with a warehouse whose membership matches the audit universe (or
add CSV-bar support to the counterfactual) to lift the ~50% coverage.
