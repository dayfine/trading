# Session-end follow-ups (2026-04-28)

Three outstanding items from the 2026-04-28 autonomous trade-audit
session. All require next-session work.

## 1. Split-day OHLC inconsistency — needs broker-model design

**Symptom**: AAPL 2020-08-31 4:1 split caused 75% phantom drop in
sp500-2019-2023 portfolio MtM (equity briefly $25K from $520K).

**Root**: `Daily_price.t` carries both `close_price` (raw) AND
`adjusted_close` (back-rolled). Each layer uses a different one:

| Layer | OHLC source |
|---|---|
| Simulator MtM | raw `close_price` |
| Panel `weekly_view.closes` | adjusted (smooth across splits) |
| Panel `weekly_view.highs` / `lows` | raw |

So the screener sees raw $211 highs vs adjusted $124 closes for AAPL
pre-split — internally inconsistent.

**Failed band-aid**: PR #641 added `_split_adjust_bar` to the simulator's
MtM path. Over-broad — rescales every bar where `adjusted_close ≠
close_price` (every pre-corporate-action bar in EODHD's back-rolled
data), not just split days. Causes 1-3 round-trip drift on small
goldens (panel-golden-2019-full 7→6, tiered-loader-parity HD→JPM,
6-year 45/42/39→41/37/34, portfolio-positive 6/6/6→5/4/4) and a
30-trade outcome on sp500 — no longer comparable to the 478-trade
baseline. **PR #641 held indefinitely**.

**Recommended design** (per the rebase agent on PR #641): broker
model. Track positions in split-adjusted shares; quantity multiplies
on the actual split day (400 × 4:1 → 1600 shares, cash basis
preserved). Use raw OHLC everywhere for execution; use adjusted
only for relative comparisons (RS line, MA, breakout detection).

**Action**: open `dev/plans/split-day-ohlc-redesign-<date>.md` next
session with broker-model as the primary approach.

## 2. Tier-4 release-gate workflow broken on GHA — local-only

**Symptom**: `.github/workflows/perf-release-gate.yml` exits 0-1s
per cell, 4/4 instant-FAIL. Run [25034915781].

**Root**: workflow sets `TRADING_DATA_DIR=$WS/trading/test_data` (the
in-repo 7-symbol CI fixture). Tier-4 scenarios use the
`Full_sector_map` sentinel = "load all symbols from sectors.csv".
Universe load fails — 7 symbols can't satisfy 1000-symbol scenarios.

**Decision**: scope tier-4 OUT of GHA. The runner size itself is
fine (8 GB at N=1000 fits per
`dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`). It's
purely the data plumbing.

**Action — release-gate checklist** (to live in the
backtest-perf-catalog plan or this note):

1. **Pre-flight**: ensure `data/` is fresh (run `ops-data` agent or
   manually pull EODHD bars + universe CSV).
2. **Local invocation**:
   ```sh
   docker exec -it trading-1-dev bash -c \
     'cd /workspaces/trading-1/trading && eval $(opam env) && \
      dune build trading/backtest/scenarios/scenario_runner.exe && \
      cd .. && dev/scripts/perf_tier4_release_gate.sh'
   ```
3. Capture metrics from `dev/perf/tier4-release-gate-<ts>/summary.txt`.
4. Run `release_perf_report` against current vs prior release
   output dirs.
5. Decide go / no-go; optionally tighten `expected` ranges in
   `goldens-broad/*.sexp`.

GHA workflow stays in the repo as the smoke-tested invocation
shape, but its `workflow_dispatch` runs are no-ops on the in-repo
fixture. Don't scheduled-cron it.

## 3. sp500-2019-2023 baseline numbers conflict — re-establish

**Symptom**: across the 2026-04-28 session, sp500-2019-2023 trade
counts were measured as:

| Source | Trades | Return | MaxDD |
|---|---:|---:|---:|
| `dev/notes/sp500-golden-baseline-2026-04-26.md` (Apr 26) | 133 | +18.5 % | 47.6 % |
| `dev/notes/goldens-performance-baselines-2026-04-28.md` | 478 | +70.8 % | 97.7 %† |
| Mid-session verify run | 298 | +45.8 % | 22.5 % |
| Investigation bisect (PR #647) — 4 SHAs | 30 | +4.2 % | 5.05 % |
| Rebase agent run with #641 applied | 30 | +9.3 % | 4.3 % |

† 97.7 % was the split-day MtM bug.

Determinism test (#648) confirmed: same commit + same scenario →
bit-identical 5×. So conflict is NOT run-to-run noise.

**Root**: PR #647's investigation bisected across 4 SHAs (including
the SHA the goldens-baselines was authored against) and got 30 trades
each time. So the 478 number is **unreproducible**. Either the
agent's measurement was on a different scenario file, different
fixture, or different env path.

**Action**: next session, pick a clean main SHA (post-#651), run
sp500-2019-2023 once via:

```sh
docker exec -it trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   _build/default/trading/backtest/scenarios/scenario_runner.exe \
   --dir /workspaces/trading-1/trading/test_data/backtest_scenarios/goldens-sp500 \
   --fixtures-root /workspaces/trading-1/trading/test_data/backtest_scenarios'
```

(Note: `--fixtures-root` flag added in #634; required when running
outside the perf scripts.)

Pin the result as the canonical baseline. Use the trade-audit
chain (PR-1..PR-5 merged this session) to understand WHY the
strategy underperforms B&H on the canonical baseline.

The strategy underperforming B&H on 4/4 windows
(`dev/notes/goldens-performance-baselines-2026-04-28.md`) is a fact
regardless of the headline trade count. The trade-audit + the
optimal-strategy counterfactual (plan in PR #650) are the next-step
analysis tools.

## What landed this session (for context)

| PR | Title |
|---:|---|
| #612 | docs(notes): short-side bear-window real-data verification |
| #615 | fix(orchestrator): pass DATE as env to python3 (+ jq Dockerfile) |
| #616 | ci(perf-tier1): add tier-1 perf smoke workflow |
| #617 | test(weinstein): short-side bear-window regression — pins macro=Bearish |
| #618 | feat(backtest-perf): engine-layer Gc.stat instrumentation (PR-1) |
| #621 | docs(status): hygiene — short-side IN_PROGRESS, perf reflect #616/#618 |
| #622 | feat(backtest-perf): tier-2 nightly perf workflow |
| #623 | fix(weinstein): plumb Macro callbacks correctly in live cascade |
| #624 | fix(orchestrator): poll mergeable before auto-merge |
| #625 | feat(backtest-perf): tier-3 weekly perf workflow |
| #626 | feat(backtest-perf): per-symbol scratch buffer for Price_path (PR-2) |
| #627 | docs(status): track tier-1 smoke universe_path bug |
| #628 | feat(backtest-perf): thread Price_path.Scratch through per-tick loop (PR-3) |
| #629 | feat(backtest-perf): release_perf_report OCaml exe |
| #630 | feat(weinstein): full short-side screener cascade |
| #631 | feat(weinstein): short-side Ch.11 spot-check |
| #632 | feat(backtest-perf): buffer pool for transient workspaces (PR-4) |
| #633 | docs(backtest-perf): engine-pool matrix re-run — PR-5 |
| #634 | fix(backtest-perf): tier-1 smoke universe_path resolution + flip continue-on-error |
| #635 | feat(backtest-perf): tier-4 release-gate workflow at N=1000 |
| #636 | docs(status): hygiene — short-side MERGED, scale MERGED, hybrid-tier PARTIAL_DONE |
| #637 | docs(plans): trade-audit plan |
| #638 | feat(backtest-perf): trade-audit collector + types (PR-1) |
| #639 | docs(notes): goldens performance baselines |
| #640 | fix(backtest-perf): tier-4 release-gate — pass --fixtures-root |
| #642 | feat(backtest-perf): trade-audit capture sites in strategy + runner (PR-2) |
| #643 | feat(backtest-perf): trade-audit markdown renderer (PR-3) |
| #644 | docs(notes): sp500-shortside-refresh |
| #645 | refactor(backtest-perf): remove Panel_strategy_wrapper feedback into panel |
| #646 | feat(backtest-perf): trade-audit cascade-rejection counts |
| #647 | docs(notes): pr-642 regression investigation — no regression found |
| #648 | test(backtest): determinism + start-date-shift regression tests |
| #649 | feat(backtest-perf): trade-audit ratings + Weinstein conformance + 4 behavioral metrics (PR-4) |
| #650 | docs(plans): optimal-strategy counterfactual plan |
| #651 | feat(backtest-perf): integrate trade-audit ratings into release_perf_report (PR-5) |

**Held**: #641 (split-day MtM band-aid; needs broker-model
redesign per item 1).
