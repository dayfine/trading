# Does the 5-year testbed have a drawdown null? — 2 arms × 3 salts

> # ⚠ RETRACTED 2026-08-20 — this cell's headline is wrong
>
> **What was claimed:** that `Range_top_breakout` "fails its first independent
> cell", because a 5-year window reversed all five metrics against the 26-year
> result.
>
> **Why it is wrong:** the comparison moved **period AND universe at once** —
> this cell ran on **sp500-500 (187 traded names)** while the 26y cell ran on
> top-3000. The record hedged this ("does not attribute the reversal") and
> shipped anyway. Hedging is not fixing.
>
> **What settled it:** `../rt-freshness-broad5y-2026-08-20/` re-ran the same
> six-cell design at the **same period** on **top-3000 PIT-2019**, isolating the
> universe axis. `Range_top_breakout` does **not** reverse there — MaxDD passes
> Rule 4 at all three salts (14.9× / 1.4× / 19.3× its null) and ulcer holds its
> direction 3-of-3. **The reversal was a universe effect, not a period effect.**
>
> **The measured cause.** The nulls do not transfer between universes, and they
> do not even move in the same *direction* per metric:
>
> | metric | this cell (sp500-5y) | broad-5y | ratio |
> |---|---:|---:|---:|
> | return pp | 0.9862 | **14.650** | 14.9× |
> | Sharpe | 0.0069 | 0.1738 | 25.2× |
> | ulcer | 0.1029 | 1.1186 | 10.9× |
> | win rate pp | 0.4167 | 1.3706 | 3.3× |
> | MaxDD pp | 0.3616 | **0.1581** | **0.44×** |
>
> Breadth makes return noisier and drawdown *more stable*. Against this cell's
> 0.99pp return null a −6pp gap reads as decisive; against the true broad null
> of 14.65pp the same gap is invisible.
>
> **What still stands.** The null-measurement *method* is sound and the numbers
> in this file are correct as measurements of the sp500-500 testbed. What does
> not stand is any inference from them about `Range_top_breakout`, or about the
> 26y result. #2433's 26y finding is **not** contradicted; it now has a second
> cell agreeing with it on MaxDD.
>
> **Rule that came out of it:** `.claude/rules/universe-discipline.md` (#2444) —
> sp500 is a sanity-check / rule-validation fixture, never a measurement
> surface. Per user instruction 2026-08-20: *"we do NOT care about running on
> S&P500 universe. even 5y should run on broad."* That instruction was in fact
> first given **2026-07-04** and had lapsed; see `#2445`.

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

⚠ **Three draws.** max−min over three samples is a **downward-biased** estimator
of spread, so every null below is more likely too small than too large, and the
×null ratios that follow are correspondingly optimistic. The verdict tolerates
this — the verdict rests on a 12.31× margin (4.45 ÷ 0.3616) and survives a
several-fold wider null — but do
not read the 4-significant-figure nulls as precise quantities.

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

## Why the nulls differ by scale — measured, not a story

⚠ **An earlier version of this section asserted the gap "is not a sample-size
effect; it is the fat tail", and explained it as monster fills re-rolling. The
first clause is right and now demonstrated. The second was a causal story fitted
to two data points — and it understates the real mechanism by an order of
magnitude.** Replaced below with what the committed `trades.csv` files actually
show. Found by qc-behavioral; the superseded text is retained above in git
history rather than being the version anyone reads.

### At 26y the seed re-rolls which trades happen; at 5y it does not

⚠ **Definition, because an earlier version of this table had none and its prose
over-read it by ~2×.** Each arm's `trades.csv` is keyed on `(symbol,
entry_date)` and compared against its own salt-0 run. The column below is
**trades present in s0 and absent from the other salt, as a fraction of s0** —
the honest "how much of this run didn't happen in that one" figure.

The earlier version reported the **symmetric difference** over |s0|, which
counts a substituted trade **twice** in the numerator and once in the
denominator, and then described it as "40–62% of trades are different trades".
No convention yields that. Corrected, with all three conventions shown so the
reader can check:

| scale / arm | absent-from-other, s0 vs s1 | s0 vs s2 | of N | (symmetric diff ÷ s0, as previously reported) |
|---|---:|---:|---:|---:|
| **5y core** | **0 (0.0%)** | **0 (0.0%)** | 240 | 0.0% / 0.0% |
| 5y rangetop | 2 (0.9%) | 3 (1.3%) | 233 | 1.3% / 2.1% |
| **26y core** | **361 (31.5%)** | **217 (18.9%)** | 1147 | 61.9% / 40.0% |
| 26y rangetop | 327 (29.9%) | 278 (25.4%) | 1094 | 63.0% / 50.6% |

Union-basis (symmetric difference ÷ |s0 ∪ sx|) for 26y core: 47.5% / 33.1%.

**At 5y the core trade SET is identical across all three salts** — 0 under
every convention. Every metric difference there comes from fill *prices* moving
within a fixed set of trades, which is why the 5y nulls are tiny and why win
rate moves by exactly one trade (37.9167 / 37.9167 / 38.3333).

The *rows* are not identical. Every figure below is joined on `(symbol,
entry_date)`, n=240 per pair, and **names its pair explicitly** — the defect
corrected here was an unnamed scope, so leaving a new figure unnamed would
repeat it:

| comparison | differ in ≥1 of pnl/entry/qty | `pnl_dollars` | `entry_price` | `quantity` |
|---|---:|---:|---:|---:|
| **s0 vs s1** | **227 of 240 (94.6%)** | 94.6% | 74.2% | 65.0% |
| **s0 vs s2** | **228 of 240 (95.0%)** | 95.0% | 75.8% | 72.9% |
| **pooled (both pairs)** | **455 of 480 (94.8%)** | 94.8% | 75.0% | 69.0% |

It is the key set that is fixed, not the values.

⚠ **Correction history for this parenthetical, which needed three passes.**
v1 said "**454 of 480**" with no pair named. v2 replaced it with "227 of the 240
rows", called the old figure "227 doubled", and said of a reviewer's proposed
455 that "neither is right".

Two things wrong with v2, both found by qc-behavioral:

- **455 IS right** — it is exactly the pooled count under the 480 denominator
  v1 itself used. Dismissing a correct figure as wrong, inside a note about
  wrong figures, is the error this note exists to record.
- **"227 doubled" is arithmetically exact (227×2 = 454) but evidentially
  unsupported.** This section compares each salt against s0 in *two* columns, so
  `480 = 2 pairs × 240` is the natural reading of v1's own denominator — under
  which 454 is simply one short of the true 455 (s2 differs on 228, not 227).
  Both stories fit; v2 asserted one in the indicative.
- And v2 **did not fix the defect it named**: "227 of the 240 rows" sits under a
  two-column table and names no pair either.

The table above is the actual fix: every scope labelled, so no reading is left
to inference.

**At 26y, 19–32% of each run's trades do not occur in the other salt.** Smaller
than the retracted figure, and still a discrete channel rather than a
perturbation — which is what the argument needs. The section heading previously
said "re-rolls half the trade set"; ~a quarter is the right order.

⚠ Each 26y `trades.csv` contains **one** duplicate `(symbol, entry_date)` key,
so the join collapses one row per file. Immaterial at these magnitudes, but
noted per `feedback_position_id_is_the_only_join_key`. `position_id` is *not*
usable as the key here: it carries a run-relative counter that shifts for every
downstream trade once the set churns, which would report ~72% for a set that is
~30% different.

### Why the channel opens at 26y and not 5y

`force_liquidations_count`, same runs: **26y = 4 / 3 / 4; 5y = 0 / 0 / 0.**

⚠ **This section listed that count under "directly measured, not inferred", and
then inferred from it that the 26y cell "runs a binding capital constraint".
The inference has since been falsified — by a deliberate test, PR #2438.** That
run took the *same 5y cell*, changed `max_position_pct_long` 0.14 → 0.33, and
opened the channel (0% → 7.4%/18.9% absent-from-other) **with
`force_liquidations_count` still 0/0/0**. So the count is a symptom of cash
exhaustion *at the selling end* and **is not a proxy for admission contention**;
its 4/3/4-vs-0/0/0 split cannot carry the attribution this section rested on it.

What survives, stated as the hypothesis it is rather than in the indicative:
per `project_ticket_dies_on_cash_shortfall`, an unfundable triggered ticket is
destroyed outright and selection at trigger is effectively arrival order, so a
tiny path-induced P&L difference can change which tickets fund and cascade. That
remains the leading candidate — and #2438 shows *some* binding admission
constraint is sufficient to open the channel — but #2438 also leaves a second
candidate live (concentration raising the stakes of each admission), and neither
run separates them. Read #2438's result section before quoting a mechanism from
here.

This also explains the one metric that stays flat: **win rate is
scale-invariant (1.2×) even though ~a quarter of the 26y trade set churns**,
because a
re-rolled set is drawn from the same population with the same base rate. The
seed changes *which* names are held, not *what fraction* of them work.

⚠ **Attribution hedge, stated with the same force as the primary one.** These
two cells differ in period **and** universe, so this account is a mechanism
*consistent with* the data, not an isolated cause. What is directly measured and
not inferred: the trade-set divergence percentages, and the force-liquidation
counts.

### The 48× headline is the most extreme framing available

Relative return noise is 42% at 26y (132.51/315.0) vs 0.9% at 5y (0.99/112.7).
That 48× is real but horizon-inflated. Two less-inflated framings, **with the
arithmetic spelled out** — an earlier version quoted "≈33×" with no formula and
a reviewer could not reproduce it:

- **Annualised: 33.8×.** Convert each salt's total return to CAGR over its own
  span (26.48y / 4.99y), take max−min, express as a fraction of the mean CAGR.
  26y: 5.016–6.250%, mean 5.521 ⇒ null 1.234pp = **22.35%**. 5y: 16.282–16.391%,
  mean 16.326 ⇒ null 0.108pp = **0.66%**. Ratio **33.8×**. (On *absolute* CAGR
  points it is only **11.4×** — 1.234 vs 0.108.)
- **Horizon-free: 12×** on the Sharpe null (0.0797 vs 0.0069), which needs no
  annualisation convention at all.

**Quote 12× if you want the conservative, convention-free number.** The three
figures differ by a factor of four purely in how the horizon is handled, which
is itself the point: none of them is "the" answer.

⚠ **The nulls are 3-draw ranges.** A max−min over three samples is a
*downward-biased* estimator of spread, so every null here is more likely too
small than too large, and the ×null ratios are correspondingly optimistic. This
does not threaten the verdict — the margin is 12.31× and would survive a
several-fold wider null — but the 4-significant-figure nulls should not be read
as precise quantities.

### What survives regardless of mechanism

1. **Never import a null across scales.** 1.2× (win rate) to 134× (return) apart
   *by metric*, and the ordering is not guessable in advance. A 5y-sized floor at
   26y certifies noise; a 26y-sized floor at 5y buries real effects — which is
   exactly the error the 26y writeup made assuming 5y "cannot resolve ~3pp".
2. **A tight null is not a better instrument.** The 5y cell measures precisely,
   and what it measures precisely is one bull market with a non-binding capital
   constraint.
3. **⭐ Return is a near-useless A/B metric on the 26y base** — ~10× worse SNR
   than any risk metric. So the program's recurring "**X is a risk lever, not a
   return lever**" conclusion is partly an instrument artefact: "return did not
   move" is what a low-powered test looks like. Honest phrasing is "risk moved;
   return is not measurable here at this effect size." Worth auditing ledger
   entries that turn on a return-in-null reading. Recorded, not acted on here.

### Falsifiable, and cheap

If the capital-contention account is right, a 26y run with the constraint
relaxed (larger starting capital, or a higher `max_long_exposure_pct`) should
show a **much smaller** trade-set divergence across salts. One pair of runs
tests it.


## Artefacts

`results/s{0,1,2}-{core,rangetop}-actual.sexp` and the matching `trades.csv`;
raw chain lines in `results.txt`. Note the chain wrote both arms of a salt into
one timestamped output root, so the `RESULT` lines in `results.txt` concatenate
two arms' metrics — read the per-arm `actual.sexp` files, which are separate and
authoritative.
