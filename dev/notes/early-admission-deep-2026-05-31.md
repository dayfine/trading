# Early-admission 27-year deep test — REVERSES the promotion recommendation

**Date:** 2026-05-31
**Verdict:** **Reject for promotion.** Mechanism stays default-off.
**Ledger:** `dev/experiments/_ledger/2026-05-31-early-admission-deep-27y.sexp`
**Supersedes the ma=13 promotion recommendation in** `early-admission-promotion-grid-2026-05-31.md`.

## The headline

Across all **post-2009** contexts (4-context grid #1384), `early_admission_ma_period`
beat baseline and **ma=13** was grid-robust. Extending the test to the **full
2000–2026 cycle including the dot-com bust and GFC** flips it: **baseline
dominates every early-admission variant and is the only Pareto-frontier cell.**

| 2000–2026 (51 folds) | Sharpe | Calmar | MaxDD% | Return% | Frontier | per-fold Sharpe wins |
|---|---:|---:|---:|---:|:--:|---:|
| **baseline** | **0.681** | 2.038 | 11.14 | **16.73** | **yes** | — |
| ma=7 | 0.557 | 1.461 | 13.43 | 12.02 | no | 23/51 |
| ma=10 | 0.609 | 1.874 | 12.97 | 14.96 | no | 24/51 |
| ma=13 | 0.654 | 1.914 | 11.27 | 15.75 | no | 26/51 |

ma=13's per-fold win rate collapses from ~60–77% (post-2009) to **26/51 ≈ a coin
flip**, and on aggregate it trails baseline on Sharpe AND return. The early folds
traded (fold-000 +80% riding the 2000 bubble), so this is a real result, not a
data gap.

## Why

Early admission buys earlier off bottoms on a fast MA. That paid in the
**bull-heavy 2009–2026 regime**, but in the **dot-com grind (2000–02) and the GFC**
it gets whipsawed — the slow 30-week MA's lateness is *protective* in prolonged
bear/choppy regimes (it keeps you out of false starts). The mechanism's edge was
a **post-2009 regime artifact.**

## The methodological point (this is the durable lesson)

Four independent post-2009 contexts + a Deflated-Sharpe of 1.0 said ACCEPT/promote
ma=13. The promotion-confirmation grid (`.claude/rules/promotion-confirmation.md`)
already caught the *single-window* overfit (ma=10). But all four grid contexts
shared one hidden commonality: **they all post-date 2009.** Adding a genuinely
different *macro regime* (2000–02, 2008) reversed the verdict. **A confirmation
grid is only as good as the regime diversity in its cells** — period+universe
diversity within one macro era is not enough. This is why the GSPC-floor fix and
the deep-history data build mattered: without 2000–2008, we'd have promoted a
mechanism that net-hurts over the full cycle.

→ **promotion-confirmation.md should require at least one pre-2009 (dot-com/GFC)
cell whenever the data permits.** (Follow-up: fold this into the rule.)

## Provenance

`{7,10,13}` surface, Rolling 2000-01-01→2026-04-30 test365/step182 (51 folds),
base `goldens-sp500-historical/sp500-2000-2026.sexp` (point-in-time 2000 SP500
universe, 515 names incl. delisted LEH/BS/YHOO; bars fetched 1999-2026 via the
`fetch-historical-data` skill; GSPC index extended to 1999). Ranked via
`rank_variants` (Pareto + Deflated Sharpe). The deep bars are an uncommitted
experiment input (rebuildable from the committed 2000 snapshot + the skill).
