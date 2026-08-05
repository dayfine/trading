# BKE order diagnosis — the sim entry trigger is the current close, not E (2026-08-05)

Root-cause investigation for the fill-model ladder's central specimen
(`dev/notes/sim-entry-fill-ladder-2026-08-05.md`). Instrumented replay of BKE
through the real snapshot-mode path (windowed cap15 scenario, warehouse
`/tmp/snap_top3000_dedup_v5thin_adj`).

## Verdict: the premise was false — there was never an order resting at E=28.66

Instrumented trace (2020-08-28 signal):

```
effective_entry as_of=2020-08-28 suggested_entry=28.66 result=18.98
order-gen id=2020-08-28-000 StopLimit(18.98, 21.83)
fill-route 2020-08-29 Buy 5347 @ 19.45 -> BKE-wein-1109
fill-route 2021-05-29 Sell @ 43.00
```

**Mechanism** (`trading/trading/weinstein/strategy/lib/entry_audit_helpers.ml`
`effective_entry_price`, the deliberate G14 fix B): the strategy's
`CreateEntering.entry_price` is pinned to the **most recent raw close**
(18.98), falling back to `suggested_entry` only when no bars exist. The #2202
StopLimit therefore triggers at the current price and **fills the next bar** —
in isolation, the cap15 arm produces the exact same BKE trade as the
market-fill control (+138%).

## Why BKE was absent from the deep-pair stop arms

Not order expiry: 26 years of tiny per-fill differences compound into
different cash/position states; by 2020-08-28 the stop arms' portfolios did
not fund BKE at the entry walk (`Skipped` — no CreateEntering, no order, no
warn). Path divergence in candidate funding. All five expiry/cancel/routing
hypotheses rejected by code trace: nothing removes an `Entering` position
except `Cancel_handler` on a portfolio-rejected fill (always warns; none for
BKE); stale-exit and laggard rotation are Holding-only; the order manager
never expires by TIF; the engine fills a resting order on the first later
cross (PR #2207's pin tests — kept, they document real engine behavior).

## What this invalidates (corrections applied in place)

1. The ladder's E-based trade classification ("base-buys below E", "299
   expired orders", "3 refused monsters") — mis-specified; the stop arm's
   trigger was never E. The static facts about fills vs the AUDIT's
   `suggested_entry` remain true as *report-vs-fill distance* measurements,
   but they do not describe the built mechanism.
2. The GTC plan's motivation (BKE = expiry miss) — void. GTC persistence
   changes nothing while triggers sit at the current close.
3. The deep-pair 2× gap's attribution — real measurement, but dominated by
   path divergence + close-trigger-vs-open-fill mechanics, not do-not-chase
   economics. The fold-validated sp500 REJECT (#2205) is unaffected (it
   measured the mechanism as built).

## The real three-layer divergence (sharper than #2158 documented)

| Layer | Entry anchored at |
|---|---|
| Weekly report ticket (what the user places) | **E** — graded breakout level |
| Sim, ALL arms incl. #2202 StopLimit | **current close** (G14) |
| Book (Ch.3 p.67-68) | **E**, GTC, tight band |

No sim arm models what live tickets actually do. The prerequisite for any
faithful fill-model work: a default-off flag making the sim entry trigger
`suggested_entry` (E) — only then do orders genuinely rest, and only then are
GTC / band / do-not-chase mechanics measurable. Reframed plan:
`dev/plans/gtc-breakout-orders-2026-08-05.md` (rewritten).

## Open user decision (supersedes the earlier "record convention" framing)

Should the sim (and therefore the record) model entries as resting stops at
report-E? Options: (a) keep current-close entries as the design (then the
REPORT should print close-anchored tickets for consistency), (b) move the sim
to E-triggered resting stops (then re-derive the ladder honestly), (c) dual
convention with documented divergence. Everything else hangs off this.
