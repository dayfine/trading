---
name: project_broad_universe_790_mtm_inflated
description: The +790.5% honest top-3000 15y baseline is MTM-inflated by ONE open position (AXTI); robust breadth signal is realized +199% vs +68% + MaxDD halved
metadata: 
  node_type: memory
  type: project
  originSessionId: 927fd47a-427f-4acc-bd93-388f8cd6b2a9
---

P0 verify 2026-06-08 (#1485, note `p0-verify-broad-universe-790-2026-06-08.md`):
the headline **+790.5% top-3000 PIT 15y Cell-E** ([[project_n3000_covid_oom]])
**reproduces bit-identical** on main (post-#1481) and is **NOT a
universe-construction artifact** (top-1000 980 syms ⊆ top-3000 2962, zero
divergence) — BUT it is **misleading**:

- **~75% of it is terminal unrealized mark-to-market**, ~entirely ONE open
  position: **AXTI** entry $2.19 × 88,347 sh → mark $79.22 (~36×, +$6.8M
  unrealized ≈ the whole $6.146M unrealized total). AXTI's price is **real &
  verified** (no split, close==adj, vol 12M) — *real ≠ robust*. AXTI is in
  **top-3000 only, not top-1000** → "breadth = one extra shot at a tail winner,"
  but the winner is unrealized + single-name (skew 5.72 / kurt 142).
- **Strip AXTI: +790% → +199% realized.** The robust breadth signal is
  **realized +199% (top-3000) vs +68% (top-1000) = 3×**, plus **MaxDD halved
  58.3%→29.2%**, Calmar 5×, force-liqs 18→2. Breadth lever holds on
  realized/risk metrics; the +790.5% headline should be **retired**.

**Apples-to-apples top-1000 (my identical-config run) = 142.9%, NOT the 29.6%**
cited in the trim-grid doc / priorities doc → data-vintage/config drift (snapshot
now extends to 2026-05-01). So the "790 vs 29.6 = 27× breadth" framing is
inflated; honest is 790 vs 143 (5.5× MTM) or 199 vs 68 (3× realized). The
29.6 top-1000 baseline ([[project_pit_survivorship_inflation]]) needs re-pinning.

**Harness gap → #1484, FIXED #1487 (default-off):** `simulation/lib/stale_hold.ml`
was a DETECTOR only — delisted/stale positions never exited, carried at last close
forever (CPKI zombie since 2011). Inflated terminal NAV of every broad-PIT run
(secondary to AXTI for top-3000: 8 zombies ≈ $1.5M of $8.5M open). **#1487 shipped
a default-off `stale_exit_after_days : int option` (on `Stale_hold.config` +
`Weinstein_strategy.config`, axis-able): `Some n` force-sells a stale position at
last close as a realized trade + frees cash; `None` = byte-identical to before.**
Default still carries zombies until promoted — broad-PIT re-baselines should set
`stale_exit_after_days = 5`. Pin comparisons on a metric a single open position
can't hijack (realized, or capital-relative-DD #1471).

**Honest re-baseline (stale_exit=5) DEGRADES this window:** 450.9% / Sharpe 0.585 /
MaxDD 38.5% / Calmar 0.31 / 878 trades / only 3 live opens (8 zombies force-exited)
— **worse on EVERY metric** than the zombie-carrying 790.5% / 0.71 / 29.2%. Cause:
forcing zombies out at last close and redeploying the cash went into worse positions
and *raised* MaxDD (carrying a delisted name flat adds no volatility; redeploying
into a live one does). **AXTI still dominates the unrealized ($4.02M) regardless** —
the single-name MTM problem is independent of the zombie fix. Lesson: stale-exit is
a *correctness* mechanism but NOT free; default-off is vindicated; promotion to
default-on needs a confirmation grid (`.claude/rules/promotion-confirmation.md`).

**P1 dispersion (#1486):** breadth caps the DD tail — top-3000 bounds peak-MaxDD
24-33% on every start vs top-1000 blowing to 58-61%; beats CAGR 8/8 matched
starts; but top-1000 median CAGR only ~5.6% (start-date sensitivity dominates).
Ledger verdicts are survivorship-robust (same-universe baseline-vs-variant) — no
flips needed. Notes: p0-verify-broad-universe-790 + p1-rolling-start-dispersion-pit.
