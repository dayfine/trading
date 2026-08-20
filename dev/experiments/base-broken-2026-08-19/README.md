# E4 / #2407 — how much of the record's return comes from fills whose base no longer held

**Verdict: NO BUILD as specified. #2407's central claim — that a structural
test "should dominate both existing mechanisms" — is refuted on its own terms.
The population it would rescue from the clock is 10 fills worth +17,678, which
is 0.76% of the run's realized P&L.**

Not because the structural idea is wrong. There *is* a clean dose-response: the
deeper the breach, the worse the cohort. It is because **at this holding cadence,
"the base broke" and "the ticket rested a long time" are very nearly the same
population** — 79 of the 89 fills resting >26 weeks had already broken their
8-week base low. There is no meaningful long-but-pristine cohort to save.

Run: `ttl-retest-00-null` at pinned `59b26c3bf`, 26y × top-3000, wall 6877s.
**Tripwire passed exactly** — `total_return_pct 281.707836178685`, 1147 trades,
so these artifacts describe the record base. All 1,147 round trips joined, with
zero blank `position_id`s — over **1,146 unique ids**, because one id
(`FARM-wein-914`) carries two round trips. See the join note at the bottom: the
first version of this measurement keyed P&L by id with last-wins and so
overstated the total by 3,750.90.

## The question, stated as an estimand

For every ticket that **filled** on the 26-year record base, was the base that
defined its `E` still intact at fill time? Split realized P&L by that flag.

The output is an **attribution**, not a counterfactual. It says how much return
sits in the broken-base cohort; it does **not** say what the run would have
earned had those tickets been cancelled, because the capital they consumed
would have gone somewhere else (and ~25% of triggered tickets already die on a
cash shortfall — `project_ticket_dies_on_cash_shortfall`). Per
`.claude/rules/mechanism-validation-rigor.md` this is a screen that can decide
**prioritization**, not a mechanism REJECT. The real test is the default-off
flag + walk-forward surface #2407 proposes.

## Why age is not the discriminator

Established this session and recorded in
`project_stale_order_fills_are_not_an_edge`: fills from tickets resting >26
weeks are 7.8% of fills and **−15.1% of total P&L** (−3,923/trade vs +2,518 —
those are per *trade* over 1,147 round trips, from the prior session; the tables
below are per *position id* over 1,146, which puts the same figure at +2,520).
Net-losing — but tail-heavy, which is why a single 5-year cell showed −40.91pp
for cutting them (the removed cohort held SMCI +240%, alone exceeding the
cohort's net).

A base can legitimately take months. The clock cuts held-base and broken-base
alike; the re-screen cuts on stage flicker and was REJECTED at −137pp because a
pullback that resumes **is** base-building. Neither tests the structure.

## The discriminator, three ways

All three are computed and reported together
(`feedback_perturb_before_believing_a_cohort_split` — a split believed off one
cutoff is how the last two wrong findings happened):

| flag | broken when, between placement and fill, a close fell below … |
|---|---|
| `broken_stop` | the ticket's own `suggested_stop` — the level the strategy itself would have exited at |
| `broken_4w` | the base low = min low over the 4 weeks ending at placement (the window that defined `local_range_top`) |
| `broken_8w` | the 8-week base low (width perturbation) |

## Method

1. **Phase 1 (`run.sh`)** — re-run `ttl-retest-00-null` at the pinned commit
   `59b26c3bf`, same warehouse, `TRADING_PATH_SEED_SALT=0`. Tripwire: the top
   line must read `total_return_pct 281.707836178685`, or the binary moved and
   the artifacts do not describe this base. A re-run is required because every
   `trade_audit.sexp` still on disk predates #2317 and its fill ages cap at
   0/1wk (`project_prefix_artifacts_cannot_measure_rest`).
2. **Phase 2 (`measure.sh`)** — extract one row per entry decision
   (`extract_tickets.sh`), reduce warehouse bars per ticket over
   `[placement, fill]`, join to `trades.csv` **on `position_id`** — the only
   valid join key, since symbols repeat across tickets
   (`feedback_position_id_is_the_only_join_key`) — and tabulate.

## What the writeup must contain before it is a result, not a draft

- The **distribution**, not the means: n, per-trade, max and min per cohort.
- The **cross-tab against rest time**. If broken-base is diagonal with age, the
  mechanism is the clock wearing a new name and #2407's premise fails.
- The **top-10 trades by |P&L| with their cohort flags**. 85% of this
  strategy's return is ~10 trades; a cohort verdict that flips when one trade
  moves is not a verdict, and cohorts under ~230 trades are unmeasurable at
  this dispersion.
- The **why**, not just the split — which failure mode the broken-base cohort
  represents, and what it rules in or out for the next lever.

## Pre-registered decision rule (written before the numbers exist)

Let `S` = the broken-base cohort's realized P&L, `T` = the run's total realized
P&L, `n` = the cohort's size.

| finding | verdict |
|---|---|
| `\|S\| < 5% of \|T\|` | **No build.** Principled or not, the mechanism cannot move the record enough to justify the flag, the axis, and the grid. |
| `S` large and **negative** | **Build as a default-off axis** (#2407). Also: the record baseline is overstated by roughly `S`, which matters beyond this issue. |
| `S` large and **positive** | **The premise is wrong.** Broken-base fills would be where part of the tail lives, and "cancel on a broken base" would be another tail-taxing lever — the class `project_edge_is_the_fat_tail` keeps rejecting. Record that and stop. |
| the three flags disagree on sign | **Unmeasurable at this n.** Report the disagreement, do not pick the flavour that agrees with the premise. |
| removing the single largest trade flips the cohort's sign | **Unmeasurable.** Report as a tail lottery, exactly as the −40.91pp clock cell turned out to be. |
| cross-tab is diagonal (broken ≈ rest > 26wk) | **The mechanism is the clock renamed.** #2407's premise — that these are different variables — fails, and the honest move is to test the clock properly rather than dress it up. |

`n < 230` is the threshold below which this strategy's cohort figures have
historically not been measurable
(`feedback_perturb_before_believing_a_cohort_split`); a cohort under it gets a
distribution and an explicit "underpowered", never a per-trade mean quoted as
a finding.

## Results

Total realized P&L on the base: **2,314,952** over 1,146 position ids.

### The three flags disagree on sign — and the disagreement is structured

| flag | breach depth | n | cohort P&L | per trade | % of total |
|---|---|---:|---:|---:|---:|
| `broken_stop` | below the ticket's own stop (shallowest) | 339 | **+1,048,334** | +3,092 | +45.3% |
| `broken_4w` | below the 4-week base low | 195 | +320,073 | +1,641 | +13.8% |
| `broken_8w` | below the 8-week base low (deepest) | 131 | **−222,667** | −1,700 | −9.6% |

Monotone in breach depth: **+3,092 → +1,641 → −1,700 per trade.** A shallow dip
below the resting ticket's own stop is not a broken base — those fills *beat*
the average (held: +1,570/trade). That is the same lesson the re-screen REJECT
taught at −137pp: a pullback that resumes **is** the base-building pattern.
A break below the 8-week low is a different animal.

⚠ **The per-trade means in that table are underpowered** at n=195 and n=131,
below the ~230 this strategy's dispersion needs
(`feedback_perturb_before_believing_a_cohort_split`). They are reported because
the *ordering* is what the dose-response claim rests on, and because the verdict
below rests on counts and totals (89, 79, 10, 52) rather than on any mean.

### Only the deepest flag is robust to the tail

| flag | total | minus top-1 | minus top-2 | minus top-3 |
|---|---:|---:|---:|---:|
| `broken_stop` | +1,048,334 | +387,087 | +138,264 | **−65,575** |
| `broken_4w` | +320,073 | +116,235 | **−32,415** | **−160,671** |
| `broken_8w` | −222,667 | **−371,317** | **−499,573** | **−587,105** |

Both shallow flags survive losing their single best trade, then flip —
`broken_4w` at **two**, `broken_stop` at **three**. So their positive sign rests
on a handful of trades, and on fewer for the shallower cut.

Two prior versions of this paragraph were wrong in opposite directions and both
are recorded rather than overwritten: the first said the sign was "one trade"
(understating robustness — MSTR's +661,246 is 63% of `broken_stop`'s total but
not the whole of its sign); the correction then said both flip "at three",
which *overstated* `broken_4w`'s robustness. The minus-top-2 column is added so
the claim is readable off the table instead of resting on prose.

`broken_8w` gets *more* negative at every step, so its negative sign is the one
result here that a tail argument cannot touch.

### But it is age wearing a structural mask

| rest | base | n | P&L | per trade |
|---|---|---:|---:|---:|
| 0-1wk | held | 607 | +1,720,333 | +2,834 |
| 1-5wk | held | 269 | −186,567 | −694 |
| 1-5wk | BROKEN | 3 | −22,107 | −7,369 |
| 5-13wk | held | 97 | +946,522 | +9,758 |
| 5-13wk | BROKEN | 23 | +117,729 | +5,119 |
| 13-26wk | held | 32 | +39,654 | +1,239 |
| 13-26wk | BROKEN | 26 | +48,521 | +1,866 |
| >26wk | held | **10** | **+17,678** | +1,768 |
| >26wk | BROKEN | 79 | **−366,810** | −4,643 |

(`broken_8w`. The >26wk row totals 89 fills / −349,132, **independently
reproducing** the committed 2026-08-16 figure on a fresh run.)

**79 of the 89 long-rest fills are structurally broken.** Within the >26wk band
the flag does separate (+1,768 vs −4,643 per trade) — but the held side is
**n=10**, far below the ~230 this strategy's dispersion needs, and worth +17,678
in total.

### Head-to-head against the incumbent clock

| rule | cuts | cohort P&L |
|---|---:|---:|
| clock (rest > 26wk) | 89 fills | **−349,132** |
| `broken_8w` | 131 fills | −222,667 |
| ...of which also >26wk | 79 fills | −366,810 |
| ...**outside** >26wk | 52 fills | **+144,142** |

The structural rule cuts **52 profitable short-rest fills** to catch 79 of the
clock's 89. It is strictly worse as a cut rule, and the thing it was supposed to
save — the long-but-valid base — is 10 fills at 0.76% of P&L.

## Verdict against the pre-registered rule, including where the rule fell short

By the letter of the pre-registration, `broken_8w` at −9.6% of total P&L is
"large and negative ⇒ build as a default-off axis". **That reading is wrong, and
the pre-registration is what was wrong:** it compared the cohort against *zero*
rather than against the incumbent. #2407's claim was never "broken-base fills
lose money" — it was "this dominates both existing mechanisms". Against the
clock it is dominated, and the comparison that settles it is the rescue
population, which the pre-registration did not name.

Recording that rather than quietly switching thresholds: the pre-registered
criterion was under-specified, the fix is to pre-register **against the
incumbent**, and the verdict below does not depend on the repair.

- **NO BUILD** for #2407 as specified (a replacement for the clock).
- The **clock is not a crude proxy** for structure — at this cadence the two are
  nearly the same variable, so "age is the wrong discriminator" is closed.
- The dose-response is worth keeping: shallow breach ≈ healthy pullback, deep
  breach ≈ real failure. Any future entry-quality work should use the 8-week
  base low, not the ticket's own stop, as its structural test.

## ⚠ The flags are computed on a RAW (unadjusted) price basis

`dump_snap` emits unadjusted OHLC, and `measure.sh` compares raw rest-window
closes against raw pre-placement lows. Across a multi-year rest window that is
**not like-for-like**: a split in between moves the two ends of the comparison
differently, so a ticket can read BROKEN purely because the price series
re-based. This is `project_split_safe_resistance_basis`'s hazard showing up in
an analysis script rather than in the strategy.

Measured rather than assumed. qc-behavioral on #2417 re-ran the classification
for the whole 89-fill >26wk band on adjusted prices:

- **87 of 89 identical**;
- **2 flip BROKEN → held** (`ARE-wein-2493`, `ARLP-wein-1800`, both losers);
- **0 flip the other way**.

So the rescue cohort — the population #2407 exists to save — becomes **12 fills
at −922** rather than 10 at +17,678. **The verdict is unchanged and slightly
stronger**: it goes from negligible-and-positive to negligible-and-negative.

The tables above are left on the raw basis, matching the committed `joined.tsv`,
so the artifact and the writeup agree. Any *future* use of this pipeline should
adjust first — that is the fix, not a re-statement of these numbers.

## What this does not test

- The **second** criterion in #2407 — that the resistance `E` was derived from
  has been superseded by a newer range top — is untested. This measures the
  support side only.
- "Base broken" here is a **proxy**: a daily close below an N-week low, not the
  strategy's own re-derivation of the base. A close-based proxy cannot see an
  intraweek break that recovered.
- One base, one config, one universe. The cohort figures are attribution, not a
  counterfactual: the capital those fills consumed would have gone elsewhere,
  and ~25% of triggered tickets already die on a cash shortfall.

## Extraction gotcha, recorded because it silently produced zeros

`[@sexp.option]` fields (`local_range_top`, `ticket_age_weeks_at_fill`) render
as `(field v)` and vanish entirely when `None`. A plain `t option` (e.g.
`rs_value`) renders as `(field (v))`. Reading the first with the second's
pattern returns `-` for every row and looks like "the knob was off".

## The bigger trap: `trade_audit`'s `entry_date` is the PLACEMENT date

`Trade_audit.entry_decision.entry_date` equals
`ticket_lifecycle.placement_date` on **all 1,466** entry decisions of this run —
while the same records carry `ticket_age_weeks_at_fill` up to 865. The actual
fill date is `trades.csv`'s `entry_date`.

Verified: `YUM-wein-2785`, audit date 2009-11-27, `ticket_age_weeks_at_fill` 14,
`trades.csv` entry 2010-03-09 — 14 weeks later to within a bar.

The first version of this measurement used the audit's `entry_date` for both
ends of the rest window. The window was empty by construction, so **every ticket
reported base-HELD and all three flags were identically zero** — a clean,
plausible, entirely false null. What caught it was not the tables (which looked
fine) but the contradiction between `placement == entry` on every row and a
non-zero age column two fields away.

## And the join trap underneath it: `position_id` is not UNIQUE

`trades.csv` has 1,147 rows over **1,146** distinct `position_id`s —
`FARM-wein-914` carries two round trips (−1,586.38 and +2,164.52, same fill
date). The first version keyed P&L into an array by id, so the second row
overwrote the first: one P&L double-counted, one dropped, total overstated by
**+3,750.90**.

`position_id` is still the right join key — symbols repeat far more
(`feedback_position_id_is_the_only_join_key`) — but "the only valid key" does
not mean "a unique key", and an assignment-style join silently loses rows.
`measure.sh` now **sums** P&L per id and prints a warning naming any id with
more than one round trip.

The tell was there and I explained it away: two totals computed from the same
file differed by 3,751, and I recorded that as my own arithmetic slip rather
than chasing it. It was this. Found by qc-behavioral on #2417, not by me.
