# Does capital contention create the noise floor? — 3 cells

**Status at commit time: NOT YET RUN.** Everything below is pre-registered.
Results land in a later commit, so the prediction provably predates the numbers.

## The claim being tested

PR #2436 found that the 26y and 5y testbeds have wildly different noise floors,
and — after a qc-behavioral finding — attributed it to a **discrete channel**
rather than to fill-price perturbation:

| scale / arm | s0 vs s1 | s0 vs s2 | of N |
|---|---:|---:|---:|
| **5y core** | **0 (0.0%)** | **0 (0.0%)** | 240 |
| 26y core | 710 (61.9%) | 459 (40.0%) | 1147 |

At 5y the trade set is **bit-identical** across path seeds. At 26y the seed
re-rolls 40–62% of *which trades happen*.

The proposed mechanism: **a binding capital constraint.** Per
`project_ticket_dies_on_cash_shortfall`, an unfundable triggered ticket is
destroyed outright and selection at trigger is effectively arrival order — so a
tiny path-induced P&L difference changes what is affordable, which changes which
tickets fund, which cascades. Supporting evidence:
`force_liquidations_count` = 4/3/4 at 26y and **0/0/0** at 5y.

**That is a mechanism consistent with two observations, which is exactly the
kind of story this program keeps getting burned by.** The two cells also differ
in period and universe, so the account is confounded as it stands.

## The test, and why this direction

Rather than relax the 26y constraint (a ~2h run, and "less churn" is a weak
signal against a noisy baseline), **tighten the 5y one** — where the measured
churn is *exactly zero*. A zero-to-nonzero result is unambiguous in a way a
reduction never is, and it costs ~12 minutes.

`specs/contention-tight.sexp` is the committed 5y core spec with **one knob
changed**: `max_position_pct_long` **0.14 → 0.33**. Verified single-knob delta
(plus name/description). Larger positions ⇒ fewer fit ⇒ triggered tickets
contend for cash. Nothing about the strategy's entry or exit logic moves.

Run at salts {0,1,2}. The control is already committed and needs no re-run:
`rt-freshness-5y-null-2026-08-20/results/s{0,1,2}-core-trades.csv`, which is the
same spec at `max_position_pct_long = 0.14` and shows **0 differing rows**.

## Prediction, registered before the run

If capital contention is the mechanism:

1. **Trade-set divergence goes from 0 to clearly nonzero** — s0-vs-s1 and
   s0-vs-s2 joined on `(symbol, entry_date)`. Any value above ~2% (the 5y
   rangetop arm's incidental level) counts as appearing; I expect double digits
   if the effect is what drives the 26y numbers.
2. **`force_liquidations_count` may go above 0**, though it is a coarser signal
   and 0 would not by itself refute (1).

If the mechanism is wrong — if the churn is really about tail exposure or window
length, as the *first* version of #2436 claimed — then **tightening position
size changes the trade set deterministically but leaves cross-salt divergence at
or near zero**, because the seed still has no discrete decision to flip.

**Falsification is the useful outcome here.** The mechanism story is currently
in a merged-pending record and in agent memory; if this run leaves divergence at
zero, that account is wrong and both must be corrected. Recording that
obligation now, before seeing the number.

## What this cannot show

- It cannot attribute the **26y-vs-5y** difference specifically, since those
  cells differ in period and universe too. It tests whether contention is
  *sufficient* to open the channel, not whether it is what opened it at 26y.
- Raising position size is not identical to "more candidates than cash" — it
  reaches the same binding constraint by a different route. A relaxed-26y run
  remains the confirming direction if this one comes back positive.
- Three salts; the same downward-biased 3-draw caveat as #2436 applies to any
  spread quoted from it.
