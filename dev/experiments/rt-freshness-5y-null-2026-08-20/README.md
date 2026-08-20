# Does the 5-year testbed have a drawdown null? — 2 arms × 3 salts

**Status at commit time: NOT YET RUN.** Everything below is pre-registered.
Results and the verdict land in a later commit, so the decision rule provably
predates the numbers.

> **[added in commit 2]** The run is complete — see **RESULT** at the bottom.
> The text above is unchanged from commit 1; the PR's two-commit history is the
> proof that the decision rule was fixed before any number existed. **Branch 3b
> fired**, i.e. the outcome that undercuts the 26y finding.

## The question

The 26y seeded A/B (`../rt-freshness-seeded-2026-08-20/`) found
`entry_freshness_basis = Range_top_breakout` improving MaxDD **38.76 → 30.81**,
clearing a *measured* 4.76pp null at all three salts. The 5-year sp500 testbed
(`../ladder-v4-small-deterministic-2026-08-12/`) says the opposite:
**16.98 → 21.43**, i.e. **+4.45pp the wrong way**.

The 26y writeup first dismissed the 5y result with *"5 years of 187 names cannot
resolve a ~3pp drawdown effect."* **That threshold was asserted, never
measured** — qc-behavioral F4 on #2433. Dismissing the 5y number requires its
drawdown null to sit above ~4.5pp, and **no run in this repo establishes any 5y
null at all.**

Every prior 5y cell was a *single realization*. Re-running one reproduces
digit-for-digit (verified 2026-08-20) — which proves the binary is
deterministic, and says nothing whatsoever about spread **across** salts. That
spread is what a null is, and it is what has never been looked at.

## Design

Two arms × salts {0,1,2} = 6 cells, ~4 min each against committed
`trading/test_data` ⇒ ~25 min total. Arms are paired within a salt so both see
the same intraday path realization; compare within-salt, never mean-to-mean.

- `specs/sm-v4-00-core-w4.sexp` (`Ma_cross`) — copied verbatim from
  `../ladder-v4-small-deterministic-2026-08-12/specs/`
- `specs/sm-v4-02-fresh-rangetop.sexp` (`Range_top_breakout`) — same source

Verified single-flag delta: the two differ only in `entry_freshness_basis`
plus `name`/`description`.

This is deliberately the **same six-cell shape as the 26y run**, so the two
nulls are directly comparable rather than two differently-shaped estimates.

## Decision rule, pre-registered

1. **Tripwire.** core at salt 0 must reproduce `total_return_pct` ≈ **112.28**
   and `max_drawdown_pct` ≈ **16.98**. A miss means the binary or the data
   moved and nothing else is interpretable.
2. **Null per metric** = max − min across core's three salts.
3. **Read the answer off the null, not the point estimate:**
   - 5y MaxDD null **> 4.45pp** ⇒ the 5y contradiction is inside its own noise.
     It never was evidence against the 26y result, and the dismissal in the 26y
     writeup becomes correct *for the first time* — measured, not asserted.
   - 5y MaxDD null **< 4.45pp** ⇒ the contradiction is **real**, and the 26y
     drawdown finding is regime- or universe-conditional rather than general.
     This blocks a confirmation grid framed on 26y alone, and **must be
     reported as loudly as the favourable outcome.**
   - null within ~1pp of 4.45 ⇒ underpowered at 3 salts. Say so and extend to
     5 salts rather than picking a side.
4. Report the rt-vs-core gap per salt against that null under the same
   all-three-salts rule the 26y run used. Sign flips ⇒ not moved.

Both outcomes are written down before the run, and one of them undercuts a
finding this session already published. That is the point of writing them first.

## Why this is worth the 25 minutes

It is the cheapest open measurement in the program relative to what it settles.
Either it retires a standing contradiction between two horizons, or it caps how
far the 26y result can be carried. `run.sh` carries the same reasoning inline.

---

# RESULT — the 5y contradiction is REAL, and it is not close

Completed 08:13, six cells, ~4 min each. **Tripwire passed:** `00-core-w4-s0`
reads `total_return_pct 112.28323995525771`, `max_drawdown_pct
16.984669525908746`, Sharpe `1.1045580768778107`, holds `45.3625` — the recorded
2026-08-12 figures, digit-for-digit. The binary and the data are unmoved.

## The 5-year nulls

Null = max − min across core's three salts, exactly as pre-registered.

| metric | **5y null** | 26y null (for scale) | ratio |
|---|---:|---:|---:|
| return | **0.9862pp** | 132.51pp | 134× |
| MaxDD | **0.3616pp** | 4.76pp | 13× |
| Sharpe | **0.0069** | 0.0797 | 12× |
| ulcer | **0.1029** | 1.851 | 18× |
| win rate | **0.4167pp** | 0.496pp | 1.2× |

## Applying the pre-registered rule

Rule 3 asked whether the 5y MaxDD null exceeds the 4.45pp contradiction.
**It is 0.3616pp — 12.3× too small.** So branch 3b fires:

> *5y MaxDD null < 4.45pp ⇒ the contradiction is **real**, and the 26y drawdown
> finding is regime- or universe-conditional rather than general. This blocks a
> confirmation grid framed on 26y alone, and must be reported as loudly as the
> favourable outcome.*

Reported accordingly. **The dismissal in the 26y writeup is refuted by
measurement**: the 5y testbed does not merely resolve a ~3pp drawdown effect, it
resolves a **0.36pp** one.

## rt loses on every metric at 5y, by 13–73× the null

| metric | core (mean) | rt (mean) | gap | gap ÷ 5y null | direction |
|---|---:|---:|---:|---:|---|
| return | 112.68 | **45.49** | −67.20pp | **68×** | worse |
| Sharpe | 1.1075 | **0.6044** | −0.5031 | **73×** | worse |
| ulcer | 6.937 | **10.531** | +3.594 | **35×** | worse |
| win rate | 38.06% | **28.55%** | −9.50pp | **23×** | worse |
| MaxDD | 16.758 | **21.360** | +4.601 | **13×** | worse |

Not one metric is inside the null, and not one favours rt. All three salts agree
in sign on all five metrics.

**Ulcer index flips hardest.** On 26y it was the *strongest* leg for rt
(−26.5%, weakest leg 1.43× null). Here it is +51.8% **worse** at 35× null. A
metric cannot be a mechanism's signature in one cell and its opposite in
another; what it can be is regime-conditional, which is what this says.

## What this does and does not establish

**Does:** the 26y result does not generalise to its first independent cell. Per
`.claude/rules/promotion-confirmation.md` this is a confirmation grid at **1 of
2**, with the second cell reversing every metric — the early-admission shape
(four post-2009 cells agreeing, a 27y cell reversing), and the reason the grid
rule exists. `Range_top_breakout` is **not promotable** and its 26y numbers must
be quoted as 26y-scoped, never as a property of the mechanism.

**Does not:** invalidate the 26y measurement. That was correctly measured
against its own null and it reproduces. Both are real; they disagree, and the
disagreement is now measured rather than assumed away.

**Does not:** attribute the reversal. The two cells differ in **period AND
universe** (2000-2026 top-3000 vs 2019-2023 sp500-500, 187 traded). Nothing here
says which axis carries it. A third cell varying one axis at a time is what
would.

## The transferable finding: a noise floor is a function of tail exposure

The nulls themselves are the more durable result. Relative noise on return is
**132.51 / 315.0 ≈ 42%** at 26y and **0.99 / 112.7 ≈ 0.9%** at 5y — a **48×**
difference in relative terms, on only ~5× the trades.

That is not a sample-size effect; it is the fat tail
(`project_edge_is_the_fat_tail`). At 26y on 3000 names a handful of monster
trades dominate the return, and whether each one fills is path-dependent — so
the seed re-rolls the outcome. At 5y on 500 bull-market names there are no
monsters to win or lose, so every salt lands in the same place.

Two consequences worth carrying:

1. **Never import a null across scales.** The 26y floor is 13–134× the 5y floor
   depending on metric. A 5y-sized floor applied at 26y would certify noise; a
   26y-sized floor applied at 5y buries real effects — which is precisely the
   error the 26y writeup made when it assumed 5y "cannot resolve ~3pp".
2. **A tight null is not a better instrument.** It means the cell has little
   tail exposure, which is exactly what makes its answer regime-specific. The 5y
   testbed measures precisely, and what it measures precisely is one bull market.

## Artefacts

`results/s{0,1,2}-{core,rangetop}-actual.sexp` and the matching `trades.csv`;
raw chain lines in `results.txt`. Note the chain wrote both arms of a salt into
one timestamped output root, so the `RESULT` lines in `results.txt` concatenate
two arms' metrics — read the per-arm `actual.sexp` files, which are separate and
authoritative.
