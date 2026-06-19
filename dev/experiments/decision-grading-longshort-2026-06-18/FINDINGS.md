# (c) Long-short screen — does the Stage-4 short leg diversify? (2026-06-18/19)

Initiative-B read-only screen (NOT the human-gated Phase-5 promotion): run the
deep 1998-2026 Cell-E with `enable_short_side=true` + `margin_config.enabled=true`
(the merged margin-phase3 long-short config) + `short_min_price=17`, and compare
to the long-only deep baseline. No goldens re-pinned; no default changed.

## Top-level: short leg cuts drawdown but also cuts return

| | return | trades | MaxDD | return/MaxDD |
|---|---|---|---|---|
| long-only deep | +1934.5% | 1061 | 48.7% | ~39.7 |
| long-short deep | +1662.9% | 1164 | 36.9% | ~45.1 |

Adding shorts cut MaxDD ~12pp (48.7 → 36.9%) at the cost of ~270pp return — a
better return/MaxDD ratio, the classic diversifier signature.

## But the short leg is anemic — the DD cut is mostly reduced long deployment

Per-side P&L (28y):

| side | n | win% | total P&L | avg/trade |
|---|---|---|---|---|
| LONG | 1127 | 33% | +$18,251,237 | +$16,195 |
| SHORT | 37 | 24% | **+$38,275** | +$1,034 |

- **Only 37 short trades in 28 years** across 3000 names — all exit via
  `stop_loss`, 24% win, **lifetime P&L +$38k (~0.2% of the long book)**.
- A near-breakeven 37-trade overlay cannot itself move MaxDD 12pp. The DD
  reduction is therefore mostly **reduced long deployment** (short collateral
  locks capital that would otherwise be long) plus a handful of crash-timed
  shorts cushioning the GFC/dot-com troughs — **not a profitable short hedge**.
- Reconciles with margin Phase-3 (`dev/notes/margin-phase3-bear-windows-2026-05-23.md`):
  shorts only show positive edge in the GFC window; flat-to-losing elsewhere. The
  Ch.11 short cascade (Stage-4 + negative RS + bearish macro) is so restrictive
  that only 37 names qualify in 28 years.

## Verdict — NO-BUILD (for now); barbell remains the DD lever

A read-only screen rejects *prioritization*, not the mechanism (`mechanism-validation-rigor`).
On this evidence:
- **Do not pursue the human-gated long-short Phase-5 promotion.** The short leg as
  built adds no meaningful return and is a weak DD-reducer largely explained by
  capital displacement, not edge. The risk-adjusted gain is real but small and
  confounded.
- **If short-side is to matter, the lever is loosening short admission** (more
  than 37 shorts/28y) — but the per-trade edge is weak (24% win, all stopped), so
  expanding the cascade risks adding losers. That is a separate, lower-priority
  exploration, not this screen's recommendation.
- **The better-validated DD diversifier is the barbell** (SPY-timing floor +
  Cell-E engine, `project_barbell_on_stocks`: pushes blended DD below the floor,
  regime-robust) — prefer it over the short leg for drawdown control.

## a→b→c synthesis (all three decision-level reads)
- **(a) stops** — whipsaw-dominated: forgo more upside (+30-33%) than disaster
  dodged (−19%); net per-decision negative even through dot-com+GFC. Improvement
  room → the **weekly-close stop lever** (`dev/plans/weekly-close-stop-2026-06-19.md`).
- **(b) laggard rotation** — the swap is a coin flip (~50%, ≈+1%); value is
  capital-recycling/freshness, not selection. Keep on, don't tune selection.
- **(c) long-short** — short leg anemic; weak/confounded DD diversifier; no-build.
  Barbell is the DD lever.

The transferable thread (tightens `project_edge_is_the_fat_tail`): selection
levers (entry, swap, short-pick) are coin flips; the live levers are
**holding-discipline** (the weekly-close stop) and **structural diversification**
(barbell), not picking better names.
