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
salts: `09-nearfloor` produces the same signature (fewer trades, much longer
holds, higher win rate, lower MaxDD, return unmoved) and it **failed its
confirmation grid 0-of-3** ([[project-nearfloor-is-risk-not-return]]).

**But the advantage is NOT uniform, and the exception is the whole point.**
`nearfloor ÷ rt` per leg: trades **3.8×**, holds **10.2×**, win rate **4.0×**,
**MaxDD only 1.2×**. rt buys **81.6%** of nearfloor's drawdown improvement
(7.95pp of 9.74pp) for **26.4%** of its turnover cut (46 trades of 175) —
drawdown improvement is strongly **sublinear** in turnover reduction.

⇒ **Trade count, holding time and win rate travel with turnover** and are
near-worthless as evidence for a mechanism on this base — a rejected mechanism
produces them 4–10× more strongly. **Drawdown does not travel with turnover**,
so a drawdown move is NOT explained away by "it traded less". This is the
transferable finding.

⚠ An earlier version of this memory claimed "4–15× headroom **on every leg**"
and concluded the whole signature was "a generic consequence of reduced
turnover". Both were wrong on the MaxDD leg, and the experiment README's own
table said so — the memory carried the wrong version forward. Third recurrence
of the fix-the-instance-not-the-rule pattern; caught by qc-behavioral.

## Nulls are NOT comparable across scales — and the pattern is structured

26y null ÷ 5y null, by metric: win rate **1.2×**, Sharpe **11.6×**, MaxDD
**13.2×**, ulcer **18.0×**, return **134.4×**.

⚠ An earlier version said "13–134× apart by metric" — wrong at the bottom end;
win rate is **1.19×**, i.e. essentially scale-invariant, and that is the most
informative cell in the table.

**Sample size is refuted with the right sign.** 1151 trades (26y) vs 240 (5y)
⇒ naive 1/√n predicts the 26y null should be **0.46×** the 5y one, i.e.
*quieter*. Every metric is noisier; return by 292× the prediction.

**Structure:** the seed barely changes *what fraction* of trades win (win rate
flat); it changes *what they are worth*, and 26 years of multiplicative
compounding makes that the dominant term. Consistent with
[[project-edge-is-the-fat-tail]], but **two scales cannot separate "heavy tail"
from "long compounding horizon"** — the long window has both. Open question, not
a law. Falsifiable cheaply: a mean-type, non-compounded statistic (median trade
P&L, mean holding days) should stay scale-invariant like win rate.

1. **Never import a null across scales** — 1.2× to 134× apart depending on the
   metric, and the ordering is not guessable in advance.
2. **A tight null is not a better instrument** — the 5y cell measures precisely,
   and what it measures precisely is one bull market.
3. **⭐ Return is a near-useless A/B metric on the 26y base** — ~10× worse SNR
   than any risk metric. So the program's recurring "**X is a risk lever, not a
   return lever**" conclusion is partly an instrument artefact: "return did not
   move" is what a low-powered test looks like. Honest phrasing is "risk moved;
   return is not measurable here at this effect size." Worth auditing ledger
   entries that turn on a return-in-null reading.

## Status

**NOT promotable**, and not merely "needs a grid" — it is at 1 of 2 cells with
the second reversing everything. Do not quote the +115.7pp 26y mean return gain
(in-null) or "drawdown lever" unqualified.

Instrument validation: six metrics × three salts reproduce digit-for-digit
against the independent 2026-08-13 salts file.

Related: [[project-entry-cap-horizon-reversal]], [[project-promotion-confirmation-grid]],
[[feedback-run-the-null-control-first]], [[project-record-gap-is-concentration]].
