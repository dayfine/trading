# Next-session priorities — 2026-06-03 (PM)

**Supersedes:** `next-session-priorities-2026-06-03.md`. That doc's **P0
(barbell-on-stocks blend)** is **DONE this session** and its **STALE-GOLDEN loose
end is FIXED**. This doc carries forward the remaining P1/P2/P3 and records the
new cross-regime confirmation.

## What shipped this session

### P0 · Barbell-on-stocks blend — DONE (PR #1435)
The headline open question is resolved. Both legs re-run fresh on deep
(2000-2026) and bull (2010-2026); post-hoc constant-weight NAV blend.

> **The floor+engine barbell strictly dominates BOTH standalone legs on
> risk-adjusted return (Calmar) in BOTH regimes.** Diversification pushes blended
> drawdown *below the floor leg itself*. 70/30 (floor/engine) is the
> regime-robust choice.

| | pure floor (SPY-timing) | **70/30** | pure engine (Cell E stocks) |
|---|---|---|---|
| deep 2000-26 | 387% / 18.8% / 0.32 | **534% / 17.8% / 0.39** | 918% / 37.3% / 0.24 |
| bull 2010-26 | 239% / 18.8% / 0.40 | **247% / 16.4% / 0.47** | 238% / 17.5% / 0.43 |

- Deep: return trades monotonically for drawdown; Calmar-max at defensive 80/20
  (0.414). Bull: legs have ~equal return so the blend is pure DD reduction —
  Calmar-max at balanced 50/50 (0.479). **70/30 beats both pure legs in each.**
- 70/30 ≈ raw BAH-SPY return at HALF the drawdown.
- Matches the ETF-lab barbell's 70/30 robust optimum (#1426) — same shape on
  stocks. Full writeup: `dev/notes/barbell-on-stocks-2026-06-02.md`.
- The deep engine reproduced the doc's 918%/37.3%/0.25 **exactly**; the bull
  engine reproduced **237.6%** exactly.

### Loose end · STALE GOLDEN — FIXED (PR #1434)
`goldens-sp500-historical/sp500-2010-2026.sexp` was pinned at 311.9% (bands
270-355) but ground-truth is **237.6%**. The 2026-05-30 #1383 re-baseline
measured 311.9% *before* the GSPC.INDX 2009-floor data fully propagated to the
run's index reader → macro gate still degenerate. With the index genuinely
covering 2009-2026 the gate is active full-window (blocks Stage-4 broad-tape
buys): fewer trades, lower return, much lower DD. Two independent measurements
(doc + this session's fresh run) agree on 237.6%. Re-pinned to ±12% bands.
**Lesson reinforced:** this golden is perf-tier 3-historical (not in PR CI), so
the stale pin never surfaced — local goldens drift silently. Consider a periodic
local re-pin sweep across the 3-historical goldens.

### Loose ends · housekeeping
- `stage_chart` tool confirmed landed on main (#1430).
- Scratch removed (/tmp svg/png, _pit_* dirs already gone).
- Reproduction scenarios committed under `dev/backtest/p0-barbell-*` (#1435);
  equity curves gitignored, reproducible via `scenario_runner --dir`.

## What's next (prioritized — unchanged framing, P0 now cleared)

### P0 (new) · Few-feature carrier comparison on stocks (was P1)
Does lighter machinery shift the return/DD tradeoff, or is the DD cost inherent
to stock selection? **Adapt `Sector_rotation_weinstein` to consume the scenario
universe** (it currently hardcodes the 11 SPDR ETFs — see
`trading/trading/weinstein/strategy/lib/sector_rotation_weinstein_strategy.mli`)
+ sweep **K much higher** (10/20/30 — 3-of-510 is reckless) + add a **sector
cap** (default-off per flag-discipline). Run on PIT S&P 500, compare to the Cell
E production engine. Most build-heavy item; dispatch to **feat-weinstein**.
Goal: find whether a simpler carrier reaches the production engine's return at
lower DD (a better barbell engine leg).

### P1 · Stage-classifier price-action-confirmation fix (was P2)
`stage_chart` (n=1, SPY 2005-10) showed the classifier flips **false Stage-3
mid-advance while price is still above a rising MA**. Principled fix =
**price-below-MA confirmation gate** for the Stage-2→3 transition (config dial,
default-off). Less-overfittable revival of the WF-CV-rejected exit-timing fix —
calibrate to the *chart*, not returns. First scan more symbols/eras with
`stage_chart` to confirm the pattern generalizes, then implement + test against
the per-symbol autopsy harness AND visually.

### P2 · Widen toward mid/small-cap (was P3, now unblocked by min_price #1428)
Once selection is characterized on clean S&P 500, widen to PIT top-1000/3000
**with the `min_price` floor (1/5/10) + an ADV floor** — the bankable
broad-universe test the top-3000 result (penny-stock-flattered) couldn't be.
Note from the barbell work: breadth is the lever (memory
`project_cell_e_2020_stall_regime`), so a broader engine leg may shift the
barbell frontier favourably.

## Data / tooling state (ready, unchanged)
- PIT S&P 500 universes: `universes/sp500-historical/sp500-{2000,2005,2010,2015,2020}-01-01.sexp`.
- `min_price` floor (#1428): merged, default-off, `((screening_config ((min_price 5.0))))`.
- `stage_chart`: `analysis/scripts/stage_chart/bin/stage_chart.exe <SYM> <START> <END> <DATA_DIR> <OUT.png>`.
- Blend tool: `/tmp/blendw.awk` (constant-weight daily-return NAV blend).
- RAM: container ~6GB; 510-sym deep run ~4.5GB → `--parallel 1`, purge
  `/tmp/panel_runner_csv_snapshot_*` between runs. Deep run wall ~30 min on a
  busy container (1845s this session, single-threaded).

## Ramp-up reminders
- Step 0: main CI green; newest priorities = this doc.
- **Print current wall-clock time on EVERY pause** (user feedback 2026-06-03).
- Code PRs: `gh pr merge --admin --squash`; confirm MERGED before deleting branch.
- Serialize backtests vs jj agents. Bounded poll loops only.
- Zero-code PRs (docs / data-golden re-pins / research fixtures) have no contract
  for QC to pin → admin-merge on CI green (this session's #1434/#1435).
- Locked objective: drawdown-defense / risk-adjusted — but "918% with 37% DD" is
  a legitimate higher-return mandate; the barbell (70/30) is how you reconcile.
