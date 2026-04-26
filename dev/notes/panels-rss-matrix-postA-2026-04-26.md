# Post-Stage-4.5-PR-A RSS matrix — null result on `bull-crash-292x6y` (2026-04-26)

Companion to `dev/notes/panels-rss-matrix-2026-04-26.md`. Re-run on
the same `bull-crash-292x6y` cell at four N × T points after Stage 4.5
PR-A (`feat/panels-stage045-pr-a-lazy-stage-filter`, PR #599) introduced
the two-phase lazy cascade in `_screen_universe`.

## Setup

Identical to the prior matrix. Container `trading-1-dev`, opam env,
panel build on PR-A merge tip (`684a4292`, post-#599).

```bash
TRADING_DATA_DIR=/tmp/data-small-302 \
  /usr/bin/time -v _build/default/trading/backtest/bin/backtest_runner.exe \
    <START> <END> --override "((universe_cap (<N>)))"
```

Four cells: {50, 292} × {1y (2019), 6y (2015–2020)}.

## Result

| N | T | Pre-PR-A RSS | Post-PR-A RSS | Δ RSS | Pre-PR-A Wall | Post-PR-A Wall |
|---:|---:|---:|---:|---:|---:|---:|
| 50 | 1y | 342 MB | 342 MB | 0 | 0:15 | 0:13 |
| 50 | 6y | 408 MB | 407 MB | −1 | 1:08 | 1:01 |
| 292 | 1y | 1,581 MB | 1,581 MB | 0 | 1:08 | 1:01 |
| 292 | 6y | 1,861 MB | 1,866 MB | +5 | 4:39 | 4:05 |

`Maximum resident set size` from `/usr/bin/time -v`. Wall = `Elapsed`.

## Fit

`RSS ≈ 86 + 5.12·N + 0.22·N·(T − 1)` MB — **unchanged from pre-PR-A**.

| Component | Pre-PR-A | Post-PR-A |
|---|---:|---:|
| Fixed (α) | ~86 MB | ~86 MB |
| Per-symbol (β) | ~5.12 MB | ~5.12 MB |
| Per-symbol-per-year (γ) | ~0.22 MB | ~0.22 MB |

Wall slightly faster across cells (~10–15% on each), suggesting PR-A
cuts CPU work but not memory residency. Plausible: less work but the
short-lived allocations were already GC'd and not contributing to peak
RSS.

## Verdict: **β did not drop**

The hypothesis going in was that `Stock_analysis.analyze_with_callbacks`
+ Volume + Resistance bundles dominated per-symbol residency. PR-A
filtered Stage 1 / Stage 3 symbols out of Phase 2; on `small-302` over
2015–2020 most symbols are Stage 2 (long-running advance) or Stage 4
(crash phase) — both pass PR-A's filter. The cascade saw little change
in the survivor set on this universe + period.

This is consistent with autopilot rule **β ≥ 4.5 → wedge is elsewhere**.

## Why the per-symbol cost is still 5 MB on small-302

Hypotheses still open:

1. **`Stops_runner.update`** — daily allocations on held positions.
   Daily, not weekly; if held-position count grows over 6y, this
   compounds. Independent of `_screen_universe` filter.
2. **Macro AD-bar list + Stage1 fallback retention** — Macro callbacks
   re-bind each symbol; closure environments retain refs to the global
   AD-bar list. Sized per-symbol via the bind multiplier, not directly
   per-loaded-symbol.
3. **`Trace` event ring** — retained for the whole run. Per-tick
   events for daily ticks × 1715 days × something-per-symbol.
4. **OCaml heap fragmentation** across 6y compounds majorly. The minor
   heap is fine but major-heap survivors don't compact between Friday
   ticks.
5. **`Bar_panels.weekly_view_for` allocations in Phase 1** — PR-A's
   pragmatic deviation kept `weekly_view_for` calls in Phase 1; ~2 KB
   per symbol per Friday × 313 Fridays × 292 symbols = ~180 MB churn
   per run. Allocated and GC'd, but with promotion latency contributes
   to peak.

## Recommendation

**Memtrace before any more architectural PRs.** The post-D spike note's
"`> 1 GB: stop, memtrace, and revisit`" branch was already triggered;
PR-A was the one architecturally clear lever before resorting to
memtrace. With it ruled out as the dominant wedge, the remaining
candidates can't be distinguished by code reading alone.

```bash
TRADING_DATA_DIR=/tmp/data-small-302 \
  MEMTRACE=/tmp/panel-292x6y.ctf \
  /usr/bin/time -v _build/default/trading/backtest/bin/backtest_runner.exe \
    2015-01-02 2020-12-31 --override "((universe_cap (292)))"

memtrace_viewer /tmp/panel-292x6y.ctf
```

Top-N callsites in the `memtrace_viewer` retention view will identify
which of the 5 hypotheses dominates. Without that data, further PRs
are guesses.

## What this means for Stage 4.5

PR-A is **still worth keeping merged** as a code-quality cleanup:
- Slightly faster wall (~10–15%).
- Cleaner separation of stage classification from full per-symbol
  analysis (architecturally lazy).
- The filter may be more impactful at scale (N=5,000 release-gate),
  where stage distribution is broader and Stage 1 / Stage 3 symbols
  are more numerous. The small-302 universe is mostly blue-chip
  long-runners; not representative of the release-gate workload.

PR-B (sector pre-filter) remains in the plan but is **not dispatched
yet**. Same reasoning: the wedge is elsewhere; PR-B would compound
on PR-A's modest impact.

PR-C (config thresholds) is fine to skip until the wedge is identified.

## References

- Pre-PR-A matrix: `dev/notes/panels-rss-matrix-2026-04-26.md`
- Spike progression: `dev/notes/panels-rss-spike-{,postB,postC,postD}-*.md`
- Post-D recommendation (memtrace): `dev/notes/panels-rss-spike-postD-2026-04-26.md` §Recommendation
- Plan: `dev/plans/panels-stage045-lazy-tier-cascade-2026-04-26.md`
- Master plan: `dev/plans/columnar-data-shape-2026-04-25.md` §"Stage 4.5"
