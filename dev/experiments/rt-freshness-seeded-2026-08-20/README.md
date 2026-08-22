# F1 freshness axis, seeded — `Range_top_breakout` vs `Ma_cross` on the 26y base

**RESULT: on the 26-year base, `Range_top_breakout` improves ulcer index, win
rate and max drawdown past their own nulls at all three salts, and moves return
and Sharpe not at all. The MaxDD improvement also holds on the broad-5y cell
(#2448) — the earlier "fails its first independent cell" reading rested on an
sp500 cell (#2436) that was RETRACTED as a universe artifact. Still NOT
promotable: both 5y windows nest inside the 26y window, so no valid
independent grid cell exists yet, and the same signature is produced more
strongly by `nearfloor`, which failed confirmation on every broad cell
tested.** Completed 05:39; headline corrected in the 2026-08-22 reframe.

⚠ **Read "The 5y 'reversal' was retracted — it was the universe, not the
horizon" and "`nearfloor` produces this same signature, and it failed 0-of-2
broad cells" before quoting anything below.** They are what the record is
actually for. The 26y measurement is sound and reproduces; what it licenses is
narrower than the first two versions of this file claimed, but wider than the
retracted third version implied.

Three metrics clear their own null at all three salts (Rule 4):

| metric | core → rt (mean) | weakest leg |
|---|---|---|
| **ulcer index** | 14.98 → **11.02** (−26.5%) | **1.43×** null |
| **win rate** | 33.18% → **34.91%** | **1.96×** null |
| **max drawdown** | 38.76 → **30.81** (−21%) | 1.02× null |

Trade count and holding time are reported **descriptively, with no verdict** —
they are not performance metrics and Rule 4 does not apply to them. See
"Turnover and holding time, reported without a verdict" below.

### Correction history, kept rather than edited away

- **v1** said *"moves drawdown and nothing else."* False: ulcer index and win
  rate move by the same Rule-4 test. **Ulcer repairs MaxDD's fragile s1 leg**
  (1.02× → 1.43×), a path-integrated measure being less noisy than a single
  extremum.
- **v2** (this file's previous headline) said *"trades FEWER, HOLDS LONGER, WINS
  MORE OFTEN and draws down LESS."* **Two of those four verbs — "trades FEWER, holds
  LONGER" — were asserted from a difference of means, which Rule 3 forbids, and
  describe quantities that have no better/worse direction to score.** They are
  now reported plainly with no verdict. Corrected below.
- **v2** also claimed the finding *"reconciles the horizon contradiction."* It
  does not — measured since, and it is the reverse.
- **v3** (the previous rework) said `nearfloor` beat rt *"on every leg"* and that
  the signature is *"a generic consequence of reduced turnover."* **Wrong on
  MaxDD (1.2×, not 4–15×)** — and the table three lines below it said so, so the
  file contradicted itself while the memory carried the wrong version forward.
  Scoped in "Drawdown is the exception" below.

All four corrections came from qc-behavioral. The pattern is worth naming
because it has now recurred **four** times, including inside the rework that
named it: **each pass fixes the instances found and not the rule that generated
them.** The rule, stated plainly: *when a claim quantifies several legs, score
every leg before choosing the summary adjective* — v1 skipped the metrics that
moved, v2 skipped the ones that failed Rule 4, v3 skipped the one leg that did
not fit "every".

## Instrument validation — stronger than first claimed

This file originally claimed only the three *return* draws reproduced. In fact
**six metrics × three salts** reproduce digit-for-digit against an independent
committed artefact, `dev/experiments/nearfloor-26y-salts-2026-08-13/results.txt`:

```
08-13 file:  00-core-w4 s1 => return 397.94778549196963 | trades 1135
             | win_rate 32.951541850220259 | maxDD 36.249041280521169
             | sharpe 0.49983223694668849 | holding_days 47.098678414096916
this run:    identical, all six, all three salts
```

That is a far better determinism tripwire than "the return draws matched", and
it was available for free — the understatement cost the record its strongest
evidence.

## Results

⚠ **Units are NOT uniform across these metrics, and the table never said so.**
`total_return_pct` is `(final − initial)/initial × 100` — a **total over the
whole 26.48-year window**, not annualized. `sharpe_ratio` **is** annualized
(`metric_computers.mli`: *"Annualized Sharpe ratio"*). Each Rule-4 ratio below is
internally valid (gap and null share the metric's own units), but **cross-metric
and cross-horizon comparisons are not** — return's null is a 26-year compounded
quantity. This is why the horizon-free framing elsewhere is the **Sharpe** ratio,
not return. Raised by the user 2026-08-20.

| salt | core return | rt return | core DD | rt DD | core trades | rt trades |
|---|---:|---:|---:|---:|---:|---:|
| 0 | 281.71 | 355.11 | 39.03 | **27.68** | 1147 | 1094 |
| 1 | 397.95 | 388.82 | 36.25 | **31.42** | 1135 | 1129 |
| 2 | 265.44 | 548.23 | 41.01 | **33.34** | 1172 | 1092 |
| **mean** | **315.0** | **430.7** | **38.76** | **30.81** | 1151 | 1105 |

Null spreads from core's own three salts: return **132.51pp**, MaxDD **4.76pp**,
Sharpe **0.0797**, trades **37**.

| metric | s0 | s1 | s2 | verdict |
|---|---|---|---|---|
| return | +73.4 in-null | −9.1 in-null | +282.8 BEAT | **not moved** — sign flips |
| Sharpe | +0.068 in-null | −0.003 in-null | +0.171 BEAT | **not moved** — sign flips |
| **MaxDD** | **+11.35 BEAT** | **+4.83 BEAT** | **+7.67 BEAT** | **MOVED** |

⚠ **Salt 1 clears by 0.07pp** (4.83 vs a 4.76 null). The all-three-salts rule
passes, but that leg is inside any reasonable measurement wobble. The finding
rests on s0 and s2 being comfortable and s1 not contradicting.

## The other two moved metrics

| metric | null | s0 | s1 | s2 |
|---|---:|---|---|---|
| ulcer index (lower better) | 1.851 | +4.12 (2.23×) | +2.65 (**1.43×**) | +5.12 (2.76×) |
| win rate (higher better) | 0.496pp | +2.52 (5.08×) | +0.97 (1.96×) | +1.72 (3.47×) |

Both clear at all three salts in the same direction, same Rule-4 test as MaxDD.
Ulcer is the more informative drawdown statistic here: it integrates depth over
time rather than taking one extremum, which is why its weakest leg is
comfortable where MaxDD's is marginal.

## Is drawdown's null really 4.76pp? — the 7.8pp objection

`dev/notes/ladder-v4-read-2026-08-12.md` §"Sharpe and drawdown are contaminated
in the same proportion" records a **behaviourally identical** config pair on
this same base differing by **0.222 Sharpe and 7.8pp of drawdown**. That 7.8pp
exceeds two of our three gaps (4.83, 7.67), so it has to be addressed rather
than left out — omitting it would favour our own conclusion.

**It is the nondeterministic binary's contamination, not this one's.** The same
document puts that chain's *return* floor at **278pp**; measured on the seeded
binary here, return's null is **132.51pp** — 2.1× tighter. Drawdown moves the
same way, 7.8pp → 4.76pp (1.6×). The path-seed fix (#2279) is exactly what
removed that excess, and our null is measured on the fixed binary, from the same
three salts the comparison is paired against.

Anyone re-reading this should still treat MaxDD's s1 leg (1.02×) as the weak
point, and prefer the ulcer-index legs, which carry more headroom against
their own null (1.43x vs 1.02x) and so survive a moderately wider one.

⚠ This sentence previously claimed the ulcer legs "do not depend on which null
you accept." False — they are ratios against ulcer's own 3-draw range (1.851)
exactly as MaxDD's are against 4.76. Headroom is not independence, and the
overclaim sat in the very section written to concede a null objection.

## It is NOT the position-count artifact

`project_entry_cap_horizon_reversal` warns that a risk-metric-led win is an
exposure signal until proven otherwise. Tested directly, from `trades.csv`
(time-weighted, entry-price basis over the 9,671-day span):

| salt | avg concurrent positions | avg deployed capital |
|---|---|---|
| 0 | 5.71 → **5.77** | $1.23M → **$1.53M** |
| 1 | 5.53 → **5.67** | $1.29M → **$1.36M** |
| 2 | 5.61 → **5.62** | $1.16M → **$1.68M** |

**Exposure does not fall. The artifact explanation is refuted — but it is NOT
reversed, and an earlier version of this file wrongly said it was.**

⚠ **Correction.** This section previously read *"rt holds more concurrent
positions and deploys more capital … the improvement cannot be 'it holds less'
— it is the reverse."* The second half overclaims, in two ways qc-behavioral
caught:

- **Concurrency gaps are inside concurrency's own null.** +0.059 / +0.146 /
  +0.007 against a null of **0.187**. Concurrency does not move; it merely fails
  to fall.
- **Raw dollar deployment rises largely because equity rises.** rt earned more,
  so it had more to deploy — the dollar gaps track the equity gaps almost
  exactly (×1.248 vs ×1.231, ×1.053 vs ×1.056, ×1.452 vs ×1.393). Normalised by
  each arm's own equity, the fractional gaps **flip sign** across salts and are
  mostly in-null.

What survives, and it is the half the conclusion needs: **rt is not less
exposed**, so the drawdown/ulcer improvement cannot be explained by holding
less. What does not survive is the stronger "more exposed" reading.

## Turnover and holding time, reported without a verdict

⚠ **Correction.** This section previously read *"rt does turn over less: 1105 vs
1151 trades at equal-or-higher concurrency ⇒ ~5.5% longer holds (47.2 → 49.8
days)"* — a **difference of means**, which pre-registered Rule 3 forbids.

**Reported descriptively, with no verdict** (see the note below on why):

| metric | core (s0/s1/s2) | rt (s0/s1/s2) | per-salt difference | core spread across salts |
|---|---|---|---|---:|
| total trades | 1147 / 1135 / 1172 | 1094 / 1129 / 1092 | −53 / −6 / −80 | 37 |
| avg holding days | 48.18 / 47.10 / 46.31 | 51.04 / 48.60 / 49.76 | +2.85 / +1.50 / +3.46 | 1.877 |

rt trades less and holds longer in all three salts, but at s1 the differences
(−6 trades, +1.50 d) are **smaller than core's own salt-to-salt spread** (37
trades, 1.877 d), so the size of the effect is not resolved by three salts. The
direction is consistent; the magnitude is not established.

⚠ **No pass/fail is asserted on these two, deliberately** (user, 2026-08-20).
Trade count and holding time are **descriptive, not performance metrics** —
neither "fewer" nor "longer" is a priori better, so there is no direction to
score against and Rule 4 does not apply. An earlier version ran them through
Rule 4 anyway and stamped both **FAILS**, using the direction this document had
itself asserted. That was a category error: it manufactured a verdict for a
quantity nobody had defined a goal for.

The spreads themselves are unremarkable in relative terms: holding days 1.877 d
on a mean of 47.2 = **4.0%**, trades 37 on 1151 = **3.2%** — consistent with
each other, not anomalous.

What the original defect actually was: the "selectivity" framing leaned on these
two quantities while every metric that *did* have a scored ratio was tabulated
with one. Reporting them plainly, without a verdict, is the fix.

### Rule 5, which this document never evaluated

Pre-registered Rule 5: *trade count is a **control, not an outcome**; if 26y
shows a large count change, the mechanism differs between horizons and the
comparison needs re-framing **before any verdict**.*

Evaluated now: the count change is **ambiguous** — 2 of 3 salts outside the
null, 1 inside. That is neither "no change" nor a clean "large change", so
Rule 5's trigger is not cleanly met; but it is close enough that the honest
reading is *the trigger cannot be ruled out*, which is itself a reason the 26y
verdict should not have been stated as broadly as it was. The re-framing Rule 5
demands is supplied by the two sections that follow, from a different direction
than anticipated.

Note the sp500 5-year testbed inverted the holding-time direction outright
(rt held *shorter* there, 45.4 → 34.4 days) — but that cell's universe makes
it a non-measurement per `universe-discipline.md` (see the retraction section
below), so the inversion is an sp500 observation, not a horizon claim.

## What the 26y cell establishes on its own

**`Range_top_breakout` improves ulcer, win rate and MaxDD on the 26-year
top-3000 base past their own nulls, moves return and Sharpe not at all, and is
not an exposure artifact.** That is the whole of it. ⚠ A previous version called
this "a drawdown lever", unqualified — the two sections that follow are why that
phrasing does not survive.

## The 5y "reversal" was retracted — it was the universe, not the horizon

*(This section previously read "It reverses at 5 years — measured, not
assumed" and presented the table below as an independent-cell failure. The
retraction is kept in the file's correction-history style.)*

The same-morning 5y run (`../rt-freshness-5y-null-2026-08-20/`, PR #2436) did
show rt losing on every metric at 13–73× that cell's null. **But that cell ran
on sp500-500 (187 traded names)** — and moving period AND universe at once
means it never isolated the horizon. Re-running the **same 5y period on
top-3000** (`../rt-freshness-broad5y-2026-08-20/`, PR #2448, merged) shows
**no reversal**: MaxDD improves past its own null there too, so **MaxDD passes
Rule 4 at both 26y and broad-5y**. `.claude/rules/universe-discipline.md`
(#2444, user rule 2026-08-20) now bans sp500 as a measurement surface
outright; the #2436 table survives only as the episode that motivated the
rule.

The retraction produced a durable law of its own (recorded in
`project_rangetop_freshness_is_a_drawdown_lever`): **breadth moves noise
floors in opposite directions** — same period, universe only: return's floor
14.9× noisier on broad, Sharpe 25.2×, but **MaxDD 0.44× (2.3× more stable)**.
Drawdown's SNR *improves* with breadth, which is why the MaxDD finding
survives both cells while nothing else does.

**Why this still does not promote rt:** both 5y windows are **nested** inside
the 26y window. Period-diverse means disjoint (`promotion-confirmation.md`);
there is no valid independent grid cell yet, and building one (a pre-2009
disjoint broad window) is the only path to a promotion case.

## `nearfloor` produces this same signature, and it failed 0-of-2 broad cells

The strongest objection to this record is not about its arithmetic. From the
committed `dev/experiments/nearfloor-26y-salts-2026-08-13/results.txt`, on this
same base and these same three salts, scored by this document's own Rule 4:

| metric (26y) | rt (this PR) | `09-nearfloor` |
|---|---|---|
| trades | **fails** s1 (0.16×) | −177/−162/−187 → **4.4–5.1×** ✓ |
| holding days | **fails** s1 (0.80×) | +26.5/+27.2/+26.3 → **14×** ✓ |
| win rate | +0.97 → 1.96× ✓ | +7.6/+7.1/+5.9 → **11.9–15.3×** ✓ |
| MaxDD | +4.83 → 1.02× ✓ | +9.2/+8.5/+11.6 → **1.8–2.4×** ✓ |
| return | in-null, sign flips | in-null at s2 → **not moved** |

**`nearfloor` produces the identical "selectivity" signature — fewer trades,
much longer holds, higher win rate, lower drawdown, return unmoved — with an
order of magnitude more headroom on three of four legs — but NOT on drawdown.**
And `nearfloor` **failed its
confirmation grid **0 of 2 BROAD cells** (`project_nearfloor_is_risk_not_return`).

⚠ **The original said "0 of 3". That counted an sp500 cell** (B: sp500 ×
2000-2026), which `.claude/rules/universe-discipline.md` (#2444) disallows as a
measurement cell. The honest count is **0 of 2 broad cells**, and the rejection
is unweakened: B reported *no effect* either way, so dropping it removes a null
result rather than a supporting one, and the decisive cell C (top-3000 ×
2010-2026, −69.2pp = 2.0× its null on return) is broad. Note also that B had the
**largest** core null of the three (180.1pp vs 132.5pp on top-3000) — the index
universe was noisier, not tighter, so it could never have resolved the effect.
Raised by the user 2026-08-20.

This record cited that rejection only under "Not bundled", as a reason to keep
the axes separate. It is much more than that: it is a **prior on the signature
itself.** The pattern this file calls a finding is one a rejected mechanism
produces more strongly, which means the signature is weak evidence for a
mechanism being good — plausibly just what trading less looks like on this base.

### ⚠ Drawdown is the exception, and it breaks the "generic" framing

An earlier version of this section said the headroom advantage held **"on every
leg"**, and concluded flatly that the signature is *"a generic consequence of
reduced turnover"*. The table three lines above **prints 1.8–2.4× for MaxDD** —
the file contradicted itself on the page, and the memory file carried the wrong
version forward, which is what future sessions actually read. Found by
qc-behavioral; this is the **third** recurrence of the pattern this document
already names, which is why it is stated here rather than quietly patched.

Per-leg, `nearfloor`'s advantage over rt:

| nf ÷ rt | trades | holds | win rate | **MaxDD** |
|---|---:|---:|---:|---:|
| | 3.8× | 10.2× | 4.0× | **1.2×** |

Drawdown does **not** scale with turnover reduction the way the other legs do.
Concretely: **rt buys 81.6% of nearfloor's drawdown improvement (7.95pp of
9.74pp) for 26.4% of its turnover cut (46 trades of 175).** Drawdown improvement
is strongly *sublinear* in turnover reduction.

**So the scoped claim, and it is weaker than the one it replaces:** on the 26y
top-3000 base, **trade count, holding time and win rate** move together with
turnover and are therefore near-worthless as evidence for a mechanism — a
rejected mechanism produces them 4–10× more strongly. **Drawdown is not in that
package**, so a drawdown improvement is not explained away by "it traded less",
and rt's is unusually efficient per unit of turnover forgone.

That makes the 26y drawdown result *more* interesting than the generic framing
allowed — and it changes nothing about the verdict, because the **5y cell
reverses drawdown too**. The mechanism fails on independent evidence, not on
this argument. Any future mechanism showing the fewer/longer/higher-win package
should still be treated as unproven until a second cell agrees; a drawdown move
deserves its own look.

## What this does and does not license

**Does not — (a) reconcile the horizons.** ⚠ Twice superseded; retained for
the audit trail. The apparent horizon disagreement below was resolved by the
broad-5y re-run (#2448): the sp500 5y testbed's contradiction was a
**universe** artifact, and on top-3000 the drawdown improvement holds at both
horizons (see the retraction section above). Original text: the 5y testbed
moved drawdown **+4.45pp the other way** (16.98 → 21.43). ⚠ An earlier version claimed reconciliation, on the
grounds that "5 years of 187 names cannot resolve a ~3pp drawdown effect."
**That threshold was asserted, never derived** — the 5y testbed is
single-realization deterministic, so *its* drawdown null has never been
measured, and dismissing its result requires a 5y null above ~4.5pp that no run
in this repo establishes. The two horizons still disagree, and the cheapest way
to settle it is to salt the 5y testbed three ways (minutes of compute) and
measure that floor directly. Until then, treat the 26y result as scoped to 26y.

The one piece of independent 26y support is directional only: the unseeded
ladder-v4 chain put core-w4 at **44.2845** and `02-fresh-rangetop` at
**32.5078** MaxDD. Those live in the **untracked**
`.sweep-output/ladder-v4-artifacts-2026-08-12/*/actual.sexp`, not in the repo,
and they come from the **nondeterministic** binary whose drawdown contamination
that same chain measures at 7.8pp — so an 11.78pp gap is barely above its own
noise. It agrees in sign with this run; it is not evidence on its own.

**Does not — (b) license promotion.** One universe, one window. Per
`promotion-confirmation.md` this earns a confirmation grid — ≥3 cells across
period × universe, including a macro-diverse one — not a default flip. The mean
return gain (+115.7pp) is inside the null and must not be quoted as a return
result.

**Caveat on the exposure proxy:** deployed capital is entry-price × quantity ×
days-held, i.e. cost basis, not mark-to-market. It answers "was rt less
invested" (no) but is not a precise utilisation series.

### Reproducing the exposure check

The counter-check is what upgrades this from suspected-artifact to finding, so
it must be recomputable rather than taken from the table above. `results/`
carries each cell's `trades.csv` for exactly that reason:

```sh
for f in results/s*-trades.csv; do
  printf '%-24s ' "$(basename "$f" -trades.csv)"
  awk -F, 'NR>1 {n++; dh=$5+0; dd+=dh; cap+=($6+0)*($8+0)*dh}
    END {span=9671; printf "trades=%-5d avg_concurrent=%-6.2f avg_deployed=$%.0f\n", n, dd/span, cap/span}' "$f"
done
```

`span=9671` is the calendar length of 2000-01-03 → 2026-06-26. Both metrics are
time-weighted, so a cell that holds fewer names for longer is not scored as less
exposed.

---

Method and the decision rule below were written **before** the numbers existed.

## The question

`entry_freshness_basis = Range_top_breakout` is the book's §4.7 order mechanics:
screen the setup while it is still **under** the range top and rest a GTC
buy-stop at the anchor, instead of admitting only after the MA cross. The
`.mli` states the mis-mapping it fixes — a name that crossed its MA ten weeks
ago but is still coiled under its range top has aged out of
`early_stage2_max_weeks <= 4` *before the book's Stage-2 week one has happened*.

**Its isolated effect has never been measured on a trustworthy binary.**

## Why the existing evidence does not settle it

| source | universe / span | result | why it does not decide |
|---|---|---|---|
| ladder-v4 cell-02, 2026-08-11 chain | top-3000, 2000-2026 | 302.68 vs core 343.90 | **Nondeterministic binary.** Its own duplicate cell put the floor at ~278pp and its results file discredits the whole ranking — `maxstop50`'s 726.2 came back at 363.86 when re-run seeded. A −41pp gap is noise. |
| ladder-v4 seeded, 2026-08-14 | top-3000, 2000-2026 | — | **Cell-02 was never re-run.** Only `rt` *combined with* nearfloor (13-rt-nearfloor 568.10, 15-rt-ttl4-nearfloor 508.12), and nearfloor alone already clears (483.10). rt's marginal contribution is +85pp — inside the 132.5pp null. |
| small-deterministic, 2026-08-12 | sp500 500 (**187 traded**), 2019-2023 | 112.28 → **45.33**, Sharpe 1.105 → 0.603, MaxDD 16.98 → **21.43** | Zero noise floor (reproduced digit-for-digit on 2026-08-20), but **one 5-year bull-heavy window, 187 names**. Its own README warns that `nearfloor` and `anchor-w8` *reverse sign* between this testbed and 26y. |

**The two horizons disagree on the metric that matters.** Drawdown gets *worse*
on 5y (16.98 → 21.43) and much *better* on the unseeded 26y (44.2845 → 32.5078,
`.sweep-output/ladder-v4-artifacts-2026-08-12/top3000-2000-2026-v4-{00-core-w4,02-fresh-rangetop}/actual.sexp`
— **untracked**, and from the nondeterministic binary), with returns
unmeasurable on 26y and clearly worse on 5y.

## Why six cells and not two

⚠ **Corrected premise.** This section previously said the 2026-08-14 seeded run
recorded "return and trades per salt and nothing else" so there was "no null
spread for MaxDD or Sharpe". **That is wrong, and a committed artefact in this
repo refutes it:** `dev/experiments/nearfloor-26y-salts-2026-08-13/results.txt`
already carries `00-core-w4` at all three salts with `win_rate`, `maxDD`,
`sharpe` and `holding_days`. The MaxDD null (4.7596), the Sharpe null, the
win-rate null (0.4956) and the holding-days null (1.8768) were all derivable
before this run.

**Only ulcer index was genuinely unrecorded** — and the rt arm had never been run
seeded at all. The six-cell design remains justified on those two grounds; the
reason originally given for it was not one.

Running **both arms at the same three salts** yields the null spread *and* the
treatment effect for every metric, in one self-contained design that depends on
nothing unrecoverable. Arms are paired within a salt, so both see the same
intraday path realization; compare within-salt, never mean-to-mean.

- `00-core` (`Ma_cross`) × salts 0, 1, 2
- `02-rangetop` (`Range_top_breakout`) × salts 0, 1, 2

Single-flag delta: the two specs differ only in `entry_freshness_basis` (plus
name/description). Everything else is verbatim from `ttl-retest-00-null`, which
arms `enable_sim_entry_stoplimit` + `sim_entry_trigger_at_suggested`, anchor 4,
cap 2.0 — all of which `Range_top_breakout` needs, since its contract is written
around a *resting ticket at the anchor*.

**Tripwire:** `00-core-s0` must read `total_return_pct 281.707836178685`. A miss
means the binary moved and nothing else in the table is interpretable.

Known null on return, from core's own three salts: **265.44 / 281.71 / 397.95**,
spread **132.5pp** on a mean of 315.0 — ±21% from the seed alone.

## Decision rule, pre-registered

1. **Tripwire first.** If salt 0 core ≠ 281.707836178685, stop; nothing is read.
2. **Compute the null per metric** from core's three salts — return, Sharpe,
   MaxDD. That spread is the yardstick for that metric and nothing below it is
   interpretable, however suggestive.
3. **Paired within salt.** Report rt−core at each salt for each metric, not a
   difference of means.
4. **A metric counts as moved only if the paired gap exceeds that metric's own
   null spread in the same direction at all three salts.** Two of three is not
   a result, it is a coin.
5. **Trade count is a control, not an outcome.** On 5y the counts were nearly
   identical (240 vs 233) — so if 26y shows a large count change, the mechanism
   differs between horizons and the comparison needs re-framing before any
   verdict.
6. **No promotion either way.** This is one universe and one window. Even a
   clean win only earns a confirmation grid (`promotion-confirmation.md`), which
   needs ≥3 cells including a macro-diverse one.

## Not bundled, deliberately

One axis. The best seeded cell of the whole ladder was `13-rt-nearfloor` (568.10)
and it contains `rt` — but bundling would make the result unattributable, which
is the pre-#2349 composite-knob failure. `nearfloor` also already failed its own
confirmation grid **0 of 2 BROAD cells** (`project_nearfloor_is_risk_not_return`).

**Path-dependence caveat (raised by the user, 2026-08-19).** A confirmation grid
is evaluated against *a baseline*, so `nearfloor`'s REJECT is conditional on the
current default. If `rt` were ever promoted, the baseline moves and nearfloor's
0-of-2 could legitimately come back different. Grid verdicts are not absolute —
worth carrying into `promotion-confirmation.md` rather than leaving in a log.

## What this run cannot answer

- **The cap's refusal cost.** `Engine.stop_limit_blocked_count` (#2423) exists
  and is tested, but nothing prints it yet — the wiring needs a `get_deps`
  accessor and `simulator.ml` is at its 500-line hard cap. So refused fills stay
  invisible in this run.
- **Whether the 5y verdict or the 26y verdict generalises.** Two windows, and
  the small-deterministic README already documents sign reversals between them.

## Provenance

Pinned worktree at **main@74aefdeb0**, warehouse
`/tmp/snap_top3000_dedup_v5thin_adj`, top-3000 PIT-2000, 2000-01-01 →
2026-06-26, `--parallel 1` per cell with two cells concurrent per salt.

The tally in #2423 is bit-identical (`112.28323995525771` / 240 trades before
and after) and unreported, so pinning to main rather than the PR branch costs
nothing and gives merged-commit provenance.
