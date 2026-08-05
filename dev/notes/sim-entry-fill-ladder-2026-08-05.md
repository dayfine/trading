# Entry fill-model ladder — market vs stop vs stop-limit (2026-08-04/05)

> **CORRECTION 2026-08-05 — read `dev/notes/bke-order-diagnosis-2026-08-05.md`
> first.** Instrumented replay showed the stop arms' trigger is the CURRENT
> CLOSE (G14 `effective_entry_price`), never the audit's `suggested_entry` E.
> Consequently: the E-based trade classification below (classes 1/3/4, the
> "base-buys below E" and "expired orders" stories, and the BKE specimen's
> attribution) is MIS-SPECIFIED — those buckets measure report-vs-fill
> distance, not the built mechanism; the deep-pair 2× gap is real but
> dominated by 26y path divergence + close-trigger-vs-open-fill mechanics.
> The ladder terminal numbers stand as measurements of the arms AS BUILT;
> the attribution narrative does not. The fold-validated sp500 REJECT
> (#2205) is unaffected. The GTC plan was rewritten around the true
> prerequisite (entry trigger semantics).

Follow-on to the 31-fold sp500 REJECT
(`dev/notes/sim-entry-stoplimit-surface-2026-08-04.md`, ledger
`2026-08-04-sim-entry-stoplimit-surface`). User asked for (1) broad universe,
(2) full-window runs, (3) trade-level fill diffs. Three 26y contiguous runs on
the record basis answered all three and **re-attributed the divergence**.

## Setup

Record-convention scenario (`staging-record-convention/`), top-3000 PIT-2000,
2000-01-01→2026-06-26, split-safe warehouse `/tmp/snap_top3000_dedup_v5thin_adj`,
cache 1024, pinned worktree @`97242cdf`, sequential runs. Control reproduces the
verified 07-28 split-safe number **exactly** (+8,366.76%) — pair basis clean.
Single-window runs (1,100+ trades each), NOT fold-validated — decomposition
evidence, not a WF verdict.

## The ladder

| Fill model | Terminal | Sharpe | MaxDD | Win% | Trades |
|---|---:|---:|---:|---:|---:|
| Market at open (record basis) | **+8,367%** (84.7×) | 0.90 | 37.1% | 37.7% | 1,122 |
| Stop uncapped (trigger @ E, fill any gap) | +2,852% (29.5×) | 0.71 | 40.7% | 30.5% | 1,108 |
| StopLimit E×1.15 (live ticket) | +4,108% (42.1×) | 0.77 | 40.9% | 31.7% | 1,092 |

Decomposition (multiplicative): **market / cap15 = 2.0×** (market / uncapped
stop = 2.9×) = the trigger wedge; **cap15 / uncapped-stop = 1.42×** = the
do-not-chase cap's PROTECTIVE
value within the stop family (refusing >15% gap-throughs is worth +42%
terminal — broad small-caps gap hugely; sp500 didn't show this because large
caps rarely gap >15%).

## Trade-level attribution (control arm, all 1,122 trades, E joined from trade_audit)

| Class | n | win% | mean pct | realized |
|---|---:|---:|---:|---:|
| 1 premium: control filled BELOW E; stop arm filled same day ≥E | 720 | 40% | +10.6% | $69.7M |
| 2 same fill (open ≥ E) | 71 | 37% | +3.2% | $1.9M |
| 4 stop never triggered (sub-E open, Day order expired unfilled) | 299 | 34% | +1.6% | +$2.1M |
| 3 cap refused (>15% gap) | 3 | 33% | −3.6% | −$0.1M |
| 5 path divergence (cash-blocked) | 29 | 28% | +2.2% | $1.2M |

- Class 1 = **64% of all record trades fill below the ticket's stated entry**
  (mean 0.98pp cheaper basis; paired per-trade advantage vs the stop arm sums
  to +704pp). Small edge × ~27 trades/yr × 26y compounding ≈ the whole 2×
  (2.7pp/yr CAGR gap).
- Class 4 = the user's "stop skips bad trades" hypothesis, quantified: 66% of
  skipped entries were losers — but the skipped tail (BKE +138%/$1.4M,
  LOGI +82%, FDX +59%/$1.2M, IONS, GWW, WLY) outweighs them.

## The BKE specimen (chart: claude.ai/code/artifact/6a4df760-801e-4f57-b0b2-d462ddec1765)

Prior top Nov-2019 $28.43 → graded E $28.66. COVID crash to ~$10, Aug-2020
Stage-2 signal at ~$18 — price had NEVER closed above E. Record buys $18.06
(pre-breakout BASE buy, not a pullback — harvests the $18→$28.66 stretch the
designed ticket refuses) → +138%. Stop arm: Day order at 28.66 expires; name
ages out of the ≤4-week early-Stage-2 window; breakout finally comes 2020-11-10
with nothing armed; the arm's only entry is 15 months later at $46.89 → −13%.
A PERSISTENT order at 28.66 fills the Nov breakout → +50% — the designed trade.

## Book verification (Secrets…, full text in user Downloads; p.67-68 + Ch.4 checklist)

Weinstein's exact ticket: **"Buy 1,000 XYZ at 12⅛ stop – 12⅜ limit – GTC"** —
(a) **GTC**, resting for weeks ("surprised two or three weeks later…");
(b) **tight limit band ≈ +2%**, not +15% — but GTC means a refused gap fills
later on a pullback into the band. Ch.4: at-range names → "write down the
price it would need to break out"; "discard those that have overhead
resistance NEARBY" (BKE's top was far, not nearby → watchlist + armed order,
not discard, and NOT a buy at 18). Both sim (Market fill, Day expiry) and the
in-repo book reference (no order-mechanics section) missed this.

## Conclusions (superseded 2026-08-05 — kept for the record; see the header)

> The four conclusions below were written before the diagnosis and are
> retracted or reframed as follows: (1) the "family" comparison stands only
> as an as-built measurement — all arms trigger at the current close, so
> "StopLimit E" was a mislabel; (2) the record's fill is close-anchored BY
> DESIGN (G14), and whether that is unfaithful is exactly the open Step-0
> decision, not a settled verdict; (3) GTC persistence is NOT the lever —
> engine orders already persist; the prerequisite is the entry-trigger
> semantics decision (rewritten plan); (4) stands.

1. ~~Live ticket shape is the best variant of its family~~ — as-built
   measurement only; no arm triggers at E.
2. ~~The record's Market-at-open fill is unfaithful~~ — reframed: the sim
   anchors entries at the close by design while the report prints E; the
   three-layer reconciliation is the open user decision.
3. ~~The one untested faithful lever: GTC persistence~~ — void; see
   `dev/notes/bke-order-diagnosis-2026-08-05.md` and the rewritten plan
   (`dev/plans/gtc-breakout-orders-2026-08-05.md` Step 0/1).
4. Open resistance-basis question (resistance-v2): local range top (~20.5)
   vs graded 520w top (28.66) as the resting level — false-virgins
   protection vs earlier entries; BKE is the costing specimen. (Stands.)

Follow-up not yet done: split class 4 into pre-breakout-base vs true
post-breakout-pullback (needs per-symbol bar history vs E before signal).

Artifacts: `dev/experiments/stoplimit-entry-wfcv-2026-08-04/deep-pair/`
(3× actual.sexp + 3× trades.csv). Scenarios committed under
`staging-record-convention/` (cap15 + trigonly twins).
