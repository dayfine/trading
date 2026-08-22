---
name: project-rangetop-freshness-is-a-drawdown-lever
description: "entry_freshness_basis=Range_top_breakout improves MaxDD past its null on BOTH the 26y top-3000 base and a broad-5y cell. The '5y reverses everything' result (#2436) was RETRACTED 08-20: it ran on sp500-500, and re-running the same period on top-3000 shows no reversal — it was a UNIVERSE artifact. Still NOT promotable (both cells are nested windows, not a grid). Durable law: breadth raises the return noise floor ~15x while LOWERING the drawdown noise floor ~2.3x."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7959dddf-3101-4cab-8f02-c90b77a7d8fd
  modified: 2026-08-20T20:48:18.797Z
---

`entry_freshness_basis = Range_top_breakout` is the book's §4.7 order mechanics:
screen while still **under** the range top and rest a GTC buy-stop at the anchor,
instead of admitting only after the MA cross. Single-flag delta.

Three six-cell paired seeded runs (2 arms × 3 path-seed salts), 2026-08-20:
26y top-3000 (`rt-freshness-seeded-`, PR #2433), 5y sp500
(`rt-freshness-5y-null-`, #2436), 5y top-3000 (`rt-freshness-broad5y-`, #2448).

## 26y top-3000 — three metrics move (Rule 4: beats own null, all 3 salts, same sign)

| metric | core → rt | weakest leg |
|---|---|---|
| ulcer index | 14.98 → **11.02** (−26.5%) | **1.43×** null (1.851) |
| win rate | 33.18% → **34.91%** | **1.96×** null (0.496pp) |
| MaxDD | 38.76 → **30.81** (−21%) | **1.02×** null (4.76pp) |
| return / Sharpe | sign flips | **not moved** (nulls 132.51pp / 0.0797) |

**trades and holding days FAIL Rule 4** (s1 legs 0.16× and 0.80×) — asserted as
"trades fewer, holds longer" from a difference of means before qc-behavioral
caught it. Concurrency neither falls nor rises (gaps in-null at 0.187).

## ⚠ RETRACTED — "5y reverses everything" was a UNIVERSE artifact

#2436 measured a 5y cell reversing all five metrics at 13–73× that cell's null
and concluded rt "fails its first independent cell." **That cell ran on
sp500-500 (187 traded names) against a 26y cell on top-3000 — it moved period
AND universe at once.** The record hedged and shipped anyway.

**#2448 re-ran the same period (2019-2023) on top-3000 PIT-2019**, moving only
the universe. **rt does not reverse there:**

| metric | s0 | s1 | s2 | vs broad-5y null |
|---|---:|---:|---:|---|
| **MaxDD** | −2.351 | −0.219 | −3.049 | 14.9× / 1.4× / 19.3× — **PASSES Rule 4** |
| ulcer | −0.985 | −1.381 | −2.265 | direction 3/3; s0 inside null (0.88×) |
| **win rate** | +3.318 | **−3.068** | +2.196 | **sign flips, s1 at 2.24× null — CONTRADICTED** |
| return / Sharpe / sortino / calmar / trades | — | — | — | sign flips |

⚠ **The broad cell SPLITS the 26y result — it does not confirm it.** THREE
metrics cleared Rule 4 at 26y (ulcer 1.43×, win rate 1.96×, MaxDD 1.02×), not
two. Of those three: MaxDD **holds**, ulcer **holds direction**, **win rate is
contradicted**. Do not quote #2433's win-rate leg as a Rule-4 survivor without
this counter-evidence.

#2436's null *measurements* remain correct for the sp500 testbed — **0.9862pp
was the right null for sp500-500.** The error was never the null; it was the
surface. Every inference drawn from those numbers about rt is void.

*(I wrote "the two that survived at 26y" in the first version of #2448 — the
5th recurrence of [[feedback-pin-every-element-of-a-category]], in a document
family whose own README carries a correction log of the previous four. Caught by
qc-behavioral, not by me.)*

## ⭐ The durable law: breadth moves noise floors in OPPOSITE directions per metric

Same period, same dials, same salts — only the universe differs:

| metric | sp500-5y null | broad-5y null | ratio |
|---|---:|---:|---:|
| return pp | 0.9862 | **14.650** | **14.9×** |
| Sharpe | 0.0069 | 0.1738 | **25.2×** |
| ulcer | 0.1029 | 1.1186 | 10.9× |
| win rate pp | 0.4167 | 1.3706 | 3.3× |
| MaxDD pp | 0.3616 | **0.1581** | **0.44×** |

**Breadth makes return/Sharpe 15–25× noisier and drawdown 2.3× MORE stable.**
More names ⇒ more tail lottery in the terminal figure, but a more diversified
drawdown path.

This **sharpens** the 26y "return has ~10× worse SNR than any risk metric"
finding, which was recorded with the caveat that "risk lever, not return lever"
might be a low-power artefact of the long horizon. **It is not a horizon
artefact — it is a property of breadth**, and it runs in opposite directions for
the two metric families. MaxDD survives precisely because it is the metric whose
SNR *improves* with breadth.

Concrete cost of the universe error: against sp500-5y's 0.99pp return null a
−6pp gap reads as decisive; against the true broad null of 14.65pp it is
invisible. See [[project-never-measure-on-sp500]].

## Nulls are NOT comparable across scales either

26y ÷ 5y(sp500), by metric: win rate **1.2×**, Sharpe **11.6×**, MaxDD
**13.2×**, ulcer **18.0×**, return **134.4×**.

**Sample size is refuted with the right sign.** 1151 trades (26y) vs 240 (5y) ⇒
naive 1/√n predicts the 26y null should be **0.46×** the 5y one, i.e. *quieter*.
Every metric is noisier; return by 292× the prediction.

⇒ **Never import a null across scales OR across universes.** Measure it in the
cell you are using. A tight null is not a better instrument — the sp500-5y cell
measures precisely, and what it measures precisely is one bull market on 187
large caps.

## The signature is generic — the `nearfloor` prior (weaker than it looks)

`nearfloor-26y-salts-2026-08-13`, same base and salts: `09-nearfloor` produces
the same signature (fewer trades, longer holds, higher win rate, lower MaxDD,
return unmoved) and failed its confirmation grid **0 of 2 BROAD cells**
([[project-nearfloor-is-risk-not-return]] — the original "0 of 3" counted an
sp500 cell; of the two remaining, **C is NESTED inside A** and has an **n=2
null**, so this prior is much weaker than its writeup implies).

`nearfloor ÷ rt` per leg: trades **3.8×**, holds **10.2×**, win rate **4.0×**,
**MaxDD only 1.2×**. rt buys **81.6%** of nearfloor's drawdown improvement for
**26.4%** of its turnover cut — drawdown improvement is strongly **sublinear**
in turnover reduction.

⇒ **Trade count, holding time and win rate travel with turnover** and are
near-worthless as mechanism evidence — a rejected mechanism produces them 4–10×
more strongly. **Drawdown does not travel with turnover.**

## Status — NOT promotable, but for a different reason than before

Not "it failed a cell." **It has no valid grid cell at all**: both 5y windows
are **nested inside** the 26y window, and `promotion-confirmation.md` says
overlapping windows are not independent. The broad-5y cell answers *"period or
universe?"*, never *"does rt generalise?"*

Promotion needs a genuinely independent cell — ideally pre-2009, macro-diverse.
Do not quote the +115.7pp 26y mean return gain (in-null) or "drawdown lever"
unqualified.

Instrument validation: six metrics × three salts reproduce digit-for-digit
against the independent 2026-08-13 salts file. All #2448 figures read from
per-arm `actual.sexp`, never the chain log
([[feedback-commit-raw-per-arm-artifacts]]).

Related: [[project-never-measure-on-sp500]], [[project-entry-cap-horizon-reversal]],
[[project-promotion-confirmation-grid]], [[feedback-run-the-null-control-first]],
[[project-record-gap-is-concentration]].
