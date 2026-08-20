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

---

# RESULT — confirmed. Contention opens the channel; 0% → 13–36%.

Completed 09:09, three cells, ~3.5 min each.

## The measurement

Trade sets joined on `(symbol, entry_date)` against each arm's own salt-0 run:

| arm | `max_position_pct_long` | s0 vs s1 | s0 vs s2 | of N |
|---|---|---:|---:|---:|
| **control** (committed, not re-run) | 0.14 | **0 (0.0%)** | **0 (0.0%)** | 240 |
| **tightened** | **0.33** | **23 (13.1%)** | **63 (36.0%)** | 175 |

**Prediction (1) fires.** Divergence goes from *exactly zero* to 13–36% on a
one-knob change, with **period and universe held fixed**. That is the
confounding the 26y-vs-5y comparison could not escape, removed.

The magnitude lands in the same range as the 26y cell (40–62%), which is the
comparison the mechanism was proposed to explain.

## Prediction (2) did NOT fire, and that sharpens the mechanism

`force_liquidations_count` is **0 / 0 / 0** in all three tightened cells — same
as the control. It was pre-registered as the coarse signal whose absence would
not refute (1), and that is how it should be read; but the *reason* it stayed
at zero is informative.

At `max_position_pct_long = 0.33` against `max_long_exposure_pct = 0.70`, only
about **two positions fit at once**. So the constraint that binds here is a
**slot** constraint, not cash exhaustion. Forced liquidation is what happens
when cash runs out; **arrival-order slot competition is what happens when many
triggered tickets contend for few openings**, and it is the latter that opens
the discrete channel.

So the mechanism is more precisely stated than in #2436:

> **Any binding admission constraint** — cash *or* slots — makes ticket
> selection depend on arrival order, and arrival order is path-dependent.
> Force-liquidation count is a symptom of one particular constraint binding,
> not a proxy for contention in general.

## Cell metrics

| salt | return | trades | MaxDD | holds | win rate |
|---|---:|---:|---:|---:|---:|
| 0 | 35.17 | 175 | 19.35 | 62.5 | 36.57% |
| 1 | 34.42 | 172 | 18.37 | 64.1 | 38.37% |
| 2 | 45.18 | 172 | 17.79 | 58.3 | 36.05% |

Note the **trade counts themselves differ across salts** (175 / 172 / 172),
where the control was 240 / 240 / 240 — the seed now changes how many trades
happen, not merely which.

Return null is **10.76pp** on a mean of 38.3 (**28%** relative), against the
control's **0.99pp on 112.7 (0.9%)**. Tightening one knob moved relative return
noise **31×**, at fixed period and universe.

## What this establishes, and what it does not

**Does:** a binding admission constraint is **sufficient** to open the
discrete trade-set channel, at fixed period and universe. The #2436 account is
supported by an unconfounded test rather than by an n=2 story.

**Does not:** prove it is what opens the channel *at 26y*. That cell differs in
period, universe, breadth and constraint simultaneously. This shows the
mechanism works; it does not show it is the only one operating there. The
confirming direction remains a relaxed-26y run.

**Does not:** say anything about whether the tightened config is *good*. Return
falls 112.7 → 38.3. This is an instrument experiment, not a strategy one, and
the tightened arm is not a candidate.

⚠ **Three draws**, same downward-biased max−min caveat as #2436. The 0 → 13–36%
step is far too large for that to matter; the 10.76pp return null quoted above
is a soft number.

## Forward guidance

1. **A backtest's noise floor is a property of how binding its admission
   constraints are**, not of its length or its tail exposure. Two cells with the
   same universe and window can differ 31× in relative return noise.
2. **Report the constraint regime alongside any null.** A null measured at
   `max_position_pct_long = 0.14` does not transfer to a run at 0.33, let alone
   across universes.
3. **This is a testable prior for future A/B design**: if an experiment needs a
   tight null, run it where admission does not bind — and know that the answer
   it gives is then specific to that regime.
