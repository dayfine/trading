---
name: project-nearfloor-is-risk-not-return
description: "Nearest-floor stop anchoring: the RISK signature (fewer trades, higher win rate, lower maxDD, longer holds) separates with ZERO overlap at BOTH 302/6y and 26y — magnitudes differ by scale (maxDD −3.97pp / holds +49% at 302/6y; −9.8pp / +57% at 26y). RETURN is scale-dependent and unresolved: core wins 9/9 at 302/6y, nearfloor leads +139pp (8/9, p≈0.10 one-sided) at 26y. Promotion candidate, not promoted; the variance-collapse claim was retracted as 302/6y-specific"
metadata: 
  node_type: memory
  type: project
  originSessionId: d7d8f2bb-6b58-4fde-8e01-c50e796e5faa
  modified: 2026-08-16T06:00:03.147Z
---

## ⛔ GRID VERDICT 2026-08-16 — NOT PROMOTED, and the knob is universe/regime conditional

The `promotion-confirmation.md` grid ran three cells and **kills the promotion**
(`dev/experiments/nearfloor-confirmation-grid-2026-08-16/results.md`). Paired at
the same path salt, against **each cell's own** core-salt null:

| cell | universe × period | core null | nearfloor vs core | maxDD | read |
|---|---|---|---|---|---|
| A | top-3000 × 2000-2026 | 132.5pp (n=3) | +139 mean, ranges OVERLAP | −9.8pp, zero overlap | return unresolved, risk better |
| B | sp500 × 2000-2026 | **180.1pp** (n=3) | −86.7pp — inside the null | +0.6pp — inside | **no effect** |
| C | top-3000 × 2010-2026 | 34.2pp (n=2) | **−69.2pp = 2.0× the null** | −5.2pp = 4.8× the null | **real return loss** |

**0 of 3 cells clear their own null on return**, and C dominates it on return and
Calmar both (Calmar at salt 0: A 16.18 vs 7.22; B 18.06 vs 21.62; C 5.43 vs 6.63).

**THE TRANSFERABLE WHY — it is a crash-depth dial, not a stop dial.** Both grid
axes flip it independently and in the same direction. Narrow the universe
(A→B) and the effect vanishes *and the trade count stops moving* (−5.7% vs
−15.4%): the two anchors only disagree when the window holds a deep prior low,
which is routine for a crash-scarred microcap and rare for an S&P name. Remove
the bear regimes (A→C) and the trade/DD effects survive but the return goes
negative: the tighter stop still fires more, and without crashes to be saved
from it fires on winners. `Window_extreme` anchors at the window's deepest low,
so the stop is loose and losers run; `Nearest` tightens it. **That tightening
pays only where deep prior lows are common AND crashes actually arrive.**
Everywhere else it is a plain fat-tail tax — the 12th confirmation of
[[project-edge-is-the-fat-tail]], same shape as
[[project-weekly-close-stop-lever]].

**Classification for `experiment-flag-discipline.md` Rule 4:
REJECT-as-default-but-legitimate-axis. NOT do-not-revive. Do not retire the
flag.** It is a breadth-conditional preset knob, the shape of
[[project-declining-ma-gate-breadth-preset]] (ARM-FOR-BROAD).

**Also corrected by the grid:** the "−10pp maxDD, zero overlap" risk signature
below is a **broad-universe** number, not a property of the mechanism — cell B
shows +0.6pp. And the `483 / 508 / 568` trio that motivated the grid is three
*different mixes* at salt 0, not three salts of one arm.

---

`stops_config.support_floor_anchor_scope = Nearest` (F3, PR #2258) anchors the
initial stop on the nearest qualifying prior correction low instead of the
window extremum. Ladder-v4 cell 09 made it look like the best lever in the
program (669.98 vs cell 00's 343.90 at 26y/top-3000). **That return claim does
not hold up.**

**The mechanism is real and reproduces everywhere** — fewer trades, higher win
rate, lower drawdown, in every context tested:

| context | trades | win rate | maxDD | return |
|---|---|---|---|---|
| 26y / top-3000 — SINGLE DRAW, superseded ↓ | 967 < 1136 | 40.4 > 34.0 | 27.0 < 44.3 | **670 > 344** |
| 26y / top-3000 — **3 salts, sourced** | 976 < 1151 | **40.1 > 33.2** | **29.0 < 38.8** | 454.0 > 315.0 (overlapping) |
| sp500 / 5y | 207 < 240 | — | — | **38.6 < 112.3** |
| small-302 / 6y (3 salts) | 235 < 288 | 37.87 > 31.25 | 15.09 < 19.05 | **25.24 < 53.84** |

⚠ **The 26y single-draw row above is superseded** by the 3-salt row beneath it
(`dev/experiments/nearfloor-26y-salts-2026-08-13/results.txt`) and is kept only
so the older figures are recognisable when they turn up in prior writeups. Use
the sourced row.

That also **closes the win-rate gap**: the previously-unsourced `40.4 > 34.0`
now has a measured counterpart, **40.1 > 33.2** — close, but different in both
columns, which is exactly why it needed sourcing rather than trusting. Every
cell in the 3-salt row traces to `results.txt`.

**The return advantage was originally seen in exactly one context** — the 26y
*single draw*, the measurement most exposed to the monster lottery, whose noise
floor is ~278pp ([[project-ladder-v4-null-278pp]]). At 302/6y across three path
salts, core beats nearfloor on **every** draw (9/9 pairwise, complete
separation); nearfloor itself is strikingly stable (25.2 / 24.9 / 24.9).

⚠ **Superseded in part (2026-08-13).** The 26y arm has since been re-run with 3
salts and the advantage did **not** vanish: nearfloor leads by +139pp on the mean
and 8/9 pairwise. It is *not established* (ranges overlap 337–398; the 8/9 gives
p≈0.10 one-sided, ≈0.20 two-sided, and the direction was chosen after seeing the
data against a prior pointing the other way) — but "appears in exactly one
context, therefore an artifact" is no longer the right reading. The honest
statement is that **return is scale-dependent and unresolved at 26y**, while the
risk signature separates cleanly at both scales.

**Re-run + corrected 2026-08-13** (`dev/experiments/nearfloor-302-6y-2026-08-13/`,
committed after PR #2288's review found this cell had no artifact at all).
Nearfloor reproduces essentially exactly (24.98 / 25.42 / 25.32). The core arm's
"≤6.6pp draw-spread" does **not** — this run gave 65.91 / 47.33 / 48.27, spread
**18.58pp (~2.8x** the original figure). The separation still holds and is
stronger than claimed: worst core draw 47.33 > best nearfloor draw 25.42, by
21.9pp. Win rate also now sourced (37.87 vs 31.25–33.33) and holding period is
new: nearfloor holds **~62 days vs core's ~41**.

⚠ **Do NOT pool the two runs.** A draft of this correction quoted a pooled
six-draw 24.4pp — withdrawn. Both runs are salts 0/1/2 of one spec, so
post-#2279 they should be bit-identical and are not (old 47.3 aligns to new
**s1**; 48.1 ≠ 48.27). Different generative processes, and the pooled low
endpoint came from the run being retired as untraceable. That non-reproducibility
*even by salt* is the real argument for retiring the old numbers.

**The mechanism at 302/6y:** core's dispersion is structurally concentrated —
across its three draws the trade count moves by **one** (288/289/288) and maxDD
by **0.009pp**, while return moves 18.58pp. Nearly the whole draw-to-draw
difference sits in **a single trade's outcome** — §1b's "a cent re-runs the
lottery", seen directly. Nearfloor's trade count is exactly invariant
(235/235/235).

⚠ **RETRACTED 2026-08-13 (26y salts): "nearfloor collapses path-variance" is
SCALE-SPECIFIC, not a property of the mechanism.** I generalized it from the
302/6y context the same night I measured it — the exact error this whole writeup
warns about. At 26y/top-3000, 3 salts each:

| | core | nearfloor |
|---|---|---|
| return spread | **132.5** | **204.3** ← MORE dispersed, not less |

At 302/6y nearfloor was ~42x tighter; at 26y it is ~1.5x *wider*. Likely reason:
at 302/6y the opportunity set is thin, both arms trade nearly the same names, and
the stop dominates the outcome; at 26y/top-3000 the monster lottery is live and
*which* monsters get funded is a breadth-and-capital phenomenon a stop rule does
not damp ([[project_edge_is_the_fat_tail]]). Do not carry the variance-collapse
claim outside 302/6y.

**Method carry-forward:** never quote a range from n=3 as a noise floor. The
original error was measuring the *stable* arm's spread accurately and assuming it
characterised both arms; three draws of a fat-tailed quantity look tight by luck.
Prefer a duplicate-cell null ([[project-ladder-v4-null-278pp]]) over a small-n
range, and always report n.

## 26y × top-3000, 3 path salts each (2026-08-13) — the powered-ish read

| metric | core (n=3) | nearfloor (n=3) | separated? |
|---|---|---|---|
| return | 265.4 / 281.7 / 398.0 → **315.0** | 337.3 / 483.1 / 541.6 → **454.0** | **no** (overlap 337-398); 8/9 pairwise to nearfloor, p≈0.10 |
| trades | 1135 / 1147 / 1172 | 970 / 973 / 985 | **YES**, zero overlap |
| win rate | 32.95 / 33.13 / 33.45 | 39.39 / 40.08 / 40.72 | **YES**, zero overlap |
| maxDD | 36.25 / 39.03 / 41.01 → 38.8 | 27.77 / 29.45 / 29.86 → **29.0** | **YES**, zero overlap |
| holding days | 46.3 / 47.1 / 48.2 | 72.6 / 74.3 / 74.7 | **YES**, zero overlap |
| Sharpe | 0.420 / 0.432 / 0.500 → 0.451 | 0.448 / 0.527 / 0.542 → 0.506 | no |

**The mechanism signature reproduces at 26y with zero overlap on four metrics** —
fewer trades, higher win rate, ~10pp lower drawdown, ~57% longer holds. That is
not a lottery artifact.

**The return direction FLIPS between scales.** 302/6y: core beat nearfloor **9/9 pairwise** (6 draws, every pairing), cleanly separated — the stronger of the two results. 26y: nearfloor leads on mean by +139pp and wins 8/9 pairwise,
though ranges overlap. So "nearfloor costs return" is itself **scale-dependent** —
true at 302/6y, UNRESOLVED at 26y (overlapping ranges, not a refutation). Return/maxDD roughly doubles at 26y
(8.1 → 15.6).

**Status: a genuine promotion CANDIDATE, not a promotion.** Three path draws is
not walk-forward CV; `promotion-confirmation.md` requires the ≥3-cell grid with
macro-regime diversity, and the DSR/best-of-N correction has not been applied.
The drawdown result (38.8 → 29.0, zero overlap) is the strongest single number.

**How to apply:** do not carry "nearfloor = the result" forward. The right
question is not "does it make more money" but "is the risk reduction worth the
return it costs" — and note that at 26y the answer to the first question is no
longer clearly no (nearfloor leads +139pp there; it is 302/6y and 500/5y that
say core wins). That is a Calmar/Sharpe question, and the 3-salt distributions
above supersede the single-draw figures this paragraph used to quote
(Sharpe 0.582 vs 0.457, maxDD 27.0 vs 44.3): use **Sharpe 0.506 vs 0.451** and
**maxDD 29.0 vs 38.8**, which are means over three draws with the maxDD
separation clean and the Sharpe separation not. Also note
the mechanism verified in the audit: `stop_floor_kind` moves 867/558 →
108/1158 Buffer_fallback/Support_floor, i.e. `Window_extreme` was falling back
to an arbitrary buffer for most candidates.

Writeup: `dev/notes/ladder-v4-read-2026-08-12.md` §3c. Related:
[[project-edge-is-the-fat-tail]], [[project-backtest-nondeterminism-intraday-path]].

## ⚠ Amendment 2026-08-20 — the grid contains an sp500 cell

Under the new [[project-never-measure-on-sp500]] rule
(`.claude/rules/universe-discipline.md`, #2444), **cell B (sp500 × 2000-2026) is
not a valid measurement cell.** Quote the grid as **0 of 2 BROAD cells**, not
0 of 3.

The verdict is unchanged and if anything cleaner:

- **A** (top-3000 × 2000-2026) — return unresolved, risk better.
- **C** (top-3000 × 2010-2026) — **decisive**: −69.2pp = 2.0× the null on
  return, maxDD −5.2pp = 4.8× the null.
- ~~B (sp500)~~ — reported "no effect", i.e. it was the least informative cell
  anyway. Dropping it removes a null result, not a supporting one.

Also note **cell B had the largest core null of the three (180.1pp vs 132.5pp on
top-3000)** — an index universe was noisier here, not tighter, so it could not
have resolved the effect even on its own terms.

Anything citing "nearfloor failed 0-of-3" (including
[[project-rangetop-freshness-is-a-drawdown-lever]]) overstates the grid by one
cell and leans on a cell the rule disallows.

## ⚠ Amendment 2 (2026-08-20) — the grid has TWO structural defects, not one

Beyond cell B being sp500 (Amendment 1), the user surfaced a second problem:

- **C is NESTED inside A.** A = top-3000 × **2000-2026**; C = top-3000 ×
  **2010-2026**. `promotion-confirmation.md` states in its own words that
  *"Overlapping windows are NOT independent"* — so the grid's period-diversity
  axis is violated by the rule that defines it. C is a sub-window of A, not an
  independent context.
- **C's null is n=2.** 34.2pp from **two** salts. A 2-draw range is a weaker
  spread estimator than 3, and 3 is already downward-biased. The **decisive**
  cell therefore has the **thinnest and least reliable null** in the grid, and
  the headline "2.0× the null" rests on it.

**Net:** strip the disallowed cell (B, sp500) and the nested one (C) and the
grid reduces to **one clean cell (A)**, where return was *unresolved*.

The REJECT may still be correct — the mechanism story is coherent (remove bear
regimes and the tighter stop fires on winners instead of saving from crashes) —
but **"nearfloor failed its confirmation grid" is a much weaker prior than its
writeup implies.** Anything leaning on it as settled (notably
[[project-rangetop-freshness-is-a-drawdown-lever]]'s argument that the
selectivity signature is generic) inherits that weakness.

**Grid-construction lesson:** a confirmation grid needs *disjoint* windows and
*broad* universes, and each cell needs enough salts to have a real null. This
one had a nested window, an index universe, and an n=2 null — three of the
things the grid exists to prevent. Check the cells before citing the verdict.
