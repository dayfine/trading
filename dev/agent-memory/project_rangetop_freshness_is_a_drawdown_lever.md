---
name: project-rangetop-freshness-is-a-drawdown-lever
description: "entry_freshness_basis=Range_top_breakout improves ulcer/win-rate/MaxDD past their nulls on the 26y top-3000 base — but REVERSES on every metric at 5y (13-73x that cell's 0.36pp null), and the same 'selectivity signature' is produced more strongly by nearfloor, which failed confirmation 0-of-3. NOT promotable. The durable finding is that a noise floor is a function of tail exposure: 42% relative return noise at 26y vs 0.9% at 5y."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7959dddf-3101-4cab-8f02-c90b77a7d8fd
  modified: 2026-08-20T15:30:00.000Z
---

**A 26y-only signature that failed its first independent cell.** Six-cell paired
seeded run, 26y top-3000, 2026-08-20
(`dev/experiments/rt-freshness-seeded-2026-08-20/`, PR #2433), plus the 5y
counter-cell (`dev/experiments/rt-freshness-5y-null-2026-08-20/`, PR #2436).

`entry_freshness_basis = Range_top_breakout` is the book's §4.7 order mechanics:
screen while still **under** the range top and rest a GTC buy-stop at the anchor,
instead of admitting only after the MA cross. Single-flag delta.

## 26y: three metrics move (Rule 4 = beats own null, all 3 salts, same sign)

| metric | core → rt | weakest leg |
|---|---|---|
| ulcer index | 14.98 → **11.02** (−26.5%) | **1.43×** null (1.851) |
| win rate | 33.18% → **34.91%** | **1.96×** null (0.496pp) |
| MaxDD | 38.76 → **30.81** (−21%) | **1.02×** null (4.76pp) |
| return / Sharpe | sign flips | **not moved** (nulls 132.51pp / 0.0797) |

**trades and holding days FAIL Rule 4** (s1 legs 0.16× and 0.80×) — they were
asserted as "trades fewer, holds longer" from a difference of means before
qc-behavioral caught it. Concurrency does not fall but does not rise either
(gaps in-null at 0.187), so it is not an exposure artifact — and not "more
exposed" either.

## 5y REVERSES it — every metric, 13–73× that cell's null

5y sp500 (187 traded), 2019-2023, same six-cell design. **5y MaxDD null =
0.3616pp**, so the contradiction (+4.60pp) is **12.7× its own null** — real, not
noise. rt loses on all five: return −67.2pp (68×), Sharpe −0.503 (73×), ulcer
+3.59 (35×), win rate −9.50pp (23×), MaxDD +4.60 (13×).

**Ulcer flips hardest**: rt's *strongest* 26y leg (−26.5%) is +51.8% *worse* at
5y. The earlier "5 years of 187 names cannot resolve a ~3pp effect" dismissal is
refuted by measurement — that cell resolves 0.36pp.

Cells differ in **period AND universe**, so the reversal is unattributed.

## The signature is generic — `nearfloor` prior

`dev/experiments/nearfloor-26y-salts-2026-08-13/results.txt`, same base, same
salts: `09-nearfloor` produces the **identical** signature (fewer trades, much
longer holds, higher win rate, lower MaxDD, return unmoved) at **4–15× headroom**
on every leg vs rt's 1.0–2.0×. And nearfloor **failed its confirmation grid
0-of-3** ([[project-nearfloor-is-risk-not-return]]).

⇒ **"fewer / longer / higher-win / lower-drawdown / return-unmoved" is what
reduced turnover looks like on the 26y top-3000 base, not a mechanism-specific
virtue.** Treat any future mechanism producing it as unproven until a second cell
agrees. This is the transferable finding.

## A noise floor is a function of tail exposure

Relative return noise: **42%** at 26y (132.51/315.0) vs **0.9%** at 5y
(0.99/112.7) — 48×, on ~5× the trades. Not sample size: the fat tail
([[project-edge-is-the-fat-tail]]). At 26y a few monsters dominate and their
fills are path-dependent, so the seed re-rolls the answer; at 5y on 500
bull-market names there are none to win or lose.

1. **Never import a null across scales** — 13–134× apart by metric.
2. **A tight null is not a better instrument** — it means low tail exposure,
   which is what makes that cell's answer regime-specific.

## Status

**NOT promotable**, and not merely "needs a grid" — it is at 1 of 2 cells with
the second reversing everything. Do not quote the +115.7pp 26y mean return gain
(in-null) or "drawdown lever" unqualified.

Instrument validation: six metrics × three salts reproduce digit-for-digit
against the independent 2026-08-13 salts file.

Related: [[project-entry-cap-horizon-reversal]], [[project-promotion-confirmation-grid]],
[[feedback-run-the-null-control-first]], [[project-record-gap-is-concentration]].
