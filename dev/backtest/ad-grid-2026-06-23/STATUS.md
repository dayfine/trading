# A-D-default confirmation grid — 2026-06-23 (in progress)

## Why this exists
The A-D-default flip (make A-D-live the default basis) was confirmed by the user
on the strength of ONE scenario (27y longshort, sp500-2000 PIT —
`dev/backtest/ad-default-fullwindow-2026-06-22/FINDINGS.md`). A spot-check this
session (`goldens-sp500/sp500-2019-2023`, default config) **contradicted** it:
A-D-live there is risk-WORSE (MaxDD 21.6%→31.3%, Calmar 0.46→0.26, Ulcer→12.48).
That fails the repo's confirmation-grid bar for a default flip
(`.claude/rules/promotion-confirmation.md`). User decision: **grid first, then
decide** (do NOT mass re-pin goldens / flip the default yet).

## Status of the broader effort
- **P0a (A-D macro O(n²) perf fix) — DONE.** Merged to main as #1722 (commit
  b2f5a03), CI green. A-D-live macro path now O(log n)/tick (prefix-sum cache).
- **P0b (the flip + golden re-pin) — DEFERRED pending this grid.** Mechanism
  corrected: `skip_ad_breadth` already defaults to false; CI reads
  `TRADING_DATA_DIR=trading/test_data` (Unicorn breadth 1965–2020-02 present);
  the flip = commit the synthetic post-2020 tail into test_data/breadth + re-pin
  ~22 post-2020 goldens. **Non-blocking** for merge: all 4 `perf-tier:1`
  (required `perf-tier1-smoke`) scenarios end ≤2020-01-03, inside Unicorn
  coverage, so they don't shift. The re-pin is soak-honesty, not a merge gate.

## The grid (promotion-confirmation.md: A-D-live vs inert, longshort config)
| cell | universe (PIT) | window | regime | verdict |
|---|---|---|---|---|
| 1 | sp500-2000 | 1999–2026 | deep: dot-com+GFC+COVID | **live BETTER** (Sharpe 0.933 vs 0.884, Sortino 1.583 vs 1.481, Calmar 0.528 vs 0.509, MaxDD 25.6 vs 27.3, Ulcer 8.80 vs 9.71; return 3077% vs 3408% = ~10% cost). From FINDINGS. |
| 2 | sp500-2010 | 2010–2026 | post-GFC bull + COVID | **live BETTER** (Sharpe .594 vs .573, Sortino .919 vs .879, Calmar .233 vs .218, MaxDD 29.3 vs 33.3, Ulcer 11.30 vs 12.98; return 194% vs 213% = ~9% cost). |
| 3 | sp500-2015 | 2015–2026 | recent, diff universe | **live BETTER** (return 66% vs 26%, Sharpe .461 vs .231 (2×), Sortino .664 vs .275, Calmar .169 vs .082; MaxDD 27.2 vs 25.6 = +1.6pp, Ulcer ~tie). |

## VERDICT: PROMOTE (3/3 cells live-better, none badly dominated)
The flip generalizes across deep/post-GFC/recent regimes + two universes. Passes
promotion-confirmation.md (≥2/3, never badly dominated). The 5y long-only
default-config spot-check that looked worse is a different config family (A-D
breadth's edge is short-timing, which long-only can't use) — not a grid cell.
**Execute P0b: commit synthetic breadth into test_data/breadth + re-pin ~22
post-2020 goldens to the A-D-live basis. Record ACCEPT in the ledger.**

## P0b execution — IN FLIGHT (2026-06-23)
- **Ledger ACCEPT recorded:** `dev/experiments/_ledger/2026-06-23-ad-default-flip-confirmation-grid.sexp` + index.
- **Breadth committed-pending:** `data/breadth/synthetic_{advn,decln}.csv` copied into
  `trading/test_data/breadth/` (working copy; not yet committed). This is THE flip.
- **Re-pin batch RUNNING:** 22 post-2020 asserted goldens staged at
  `dev/backtest/ad-repin-2026-06-23/scenarios/`, running via scenario_runner
  `--parallel 4` against `TRADING_DATA_DIR=test_data` (breadth present). Log:
  `dev/backtest/ad-repin-2026-06-23/run.log`. Output root: latest
  `dev/backtest/scenarios-*/<name>/actual.sexp`. Slow (top-1000 universes + 30y);
  ETA ~2-3h.
- **Resume after batch:** for each scenario whose runner row is `FAIL (...)`, read
  its `actual.sexp` and rewrite the original golden's `(expected ...)` bands to the
  new central values ±~15% (mirror existing per-metric tolerance). Scenarios that
  `PASS` (bands absorbed the shift) need no edit. Then: commit (breadth CSVs +
  re-pinned goldens + ledger + this dir's docs) on bookmark `feat/ad-default-flip`,
  PR with the grid evidence, full CI + QC (behavior-change PR).
- **NOT merge-blocking:** required `perf-tier1-smoke` scenarios all end <=2020-01-03
  (inside Unicorn coverage) so they don't shift; the re-pin is soak-honesty.

### Re-pin progress (2026-06-23/24)
Ran the **feasible** tier (sp500-510 / small / single-symbol universes) in CSV
mode — the top-1000/3000 broad+custom-universe scenarios OOM/crawl in CSV mode
and are DEFERRED (need snapshot-mode re-pin; mostly perf-tier:4 local-release-gate).
Actuals: `trading/dev/backtest/scenarios-2026-06-24-000012/`.

- **Re-pinned (shifted out of band):**
  - `goldens-small/six-year-2018-2023` — A-D-live BETTER (ret 56→78, Sharpe→0.71, MaxDD 26→19).
  - `goldens-small/bull-crash-2015-2020` — A-D-live WORSE (ret 110→59, Sharpe 0.93→0.64): conservative gate, long-only can't use the short-timing edge.
  - `goldens-sp500-historical/sp500-2010-2026` (long-only) — ret 237→346, MaxDD→22.4 (consistent w/ its longshort twin 358).
- **PASS, no re-pin (bands absorbed):** `sp500-2010-2026-longshort` (longshort, in band), `covid-recovery-2020-2024` (small), `sp500-default-hybrid` (wide bands).
- **Unchanged (breadth-independent):** `*-bah-brk-b`/`*-bah-spy` (buy-and-hold), `sp500-no-candidates` (zero by design).
- **Pending feasible (4):** `sp500-2019-2023` (+ `-long-only`, `-bah-spy`), `smoke/recovery-2023`.
- **DEFERRED (top-1000/3000, snapshot-mode):** `goldens-broad/*` (6), `goldens-custom-universe-scenarios/*` (2), `perf-sweep/bull-3y`, `goldens-broad/sp500-30y-capacity-1996`. Follow-up.

Pattern confirmed: A-D-live helps the longshort/short-timing strategy, costs
return in long-only bull/recovery windows — exactly the grid's read. Re-pins
record this honestly.

Scenarios: `dev/backtest/ad-grid-2026-06-23/scenarios/cell{2,3}-*-ad{live,inert}.sexp`.
Run against `data/` (validated synthetic breadth 1998–2026, 0.92–0.93 corr vs
NYSE + 731-name bars). Output root `dev/backtest/scenarios-2026-06-23-224643/`.

## Decision rule (promotion-confirmation.md)
PROMOTE A-D-live default only if live beats inert (risk-adjusted; frontier or
positive) in a **strong majority** of cells (≥2 of 3) AND never badly dominated.
- 3/3 live-better → promote (execute P0b re-pin).
- 2/3 → promotable with regime caveat.
- ≤1/3 → DO NOT flip; keep A-D-live as deep-longshort basis only; P0a stays.

Auxiliary signal: the 5y default-config spot-check (live worse) is a yellow flag
but is NOT a longshort grid cell.
