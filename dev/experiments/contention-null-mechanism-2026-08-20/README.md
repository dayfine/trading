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

At 5y the trade SET is identical across path seeds — the same (symbol,
entry_date) pairs every time. ⚠ An earlier version said "bit-identical", which
is wrong and which this document elsewhere contradicts: **454 of 480 control
rows differ** between salts (`pnl_dollars` 94.6%, `entry_price` 74.2%,
`quantity` 65.0%). The seed moves fill prices *within* a fixed trade set, which
is exactly why the control still has a 0.99pp return null. At 26y the seed
re-rolls 40–62% of *which trades happen* — a different channel entirely.

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

# RESULT — one knob takes divergence from 0% to 13-36%

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

## Prediction (2) did NOT fire — and my reading of why was wrong

`force_liquidations_count` is **0 / 0 / 0** in all three tightened cells — same
as the control. It was pre-registered as the coarse signal whose absence would
not refute (1), and that is how it should be read; but the *reason* it stayed
at zero is informative.

⚠ **An earlier version of this section reclassified the constraint from cash to
"slots", reasoning that at `max_position_pct_long = 0.33` against
`max_long_exposure_pct = 0.70` "only about two positions fit at once". That
reasoning is wrong, and this PR's own trade data refutes it by 3–6×.** Position
size is a *cap*, not a target — sizing is driven by stop distance, so most
positions sit far below the cap and the cap arithmetic does not predict the
count. Measured from `results/`:

| | control (0.14) | tight (0.33) |
|---|---:|---:|
| mean concurrent positions | 5.96 | **5.99** |
| peak concurrent | 10 | **12** |

**Concurrency is flat.** There is no slot scarcity. Found by qc-behavioral.

### What the knob actually changed

| | control | tight |
|---|---:|---:|
| median position notional | $138,758 | **$87,224** |
| p90 | $226,998 | **$329,381** |
| max | $284,794 | **$421,067** |
| mean holding days | 45.4 | **62.5** |

Not "fewer, larger positions" — **wider size dispersion at flat concurrency**,
with longer holds. The median position got *smaller* while the tail got bigger.

### So what does bind?

`force_liquidations_count` is 0/0/0, so nothing is being force-sold; and slots
are plentiful. What remains is **admission funding**: per
`project_ticket_dies_on_cash_shortfall`, a triggered ticket that cannot be
funded at that moment is destroyed outright, and selection at trigger is
effectively arrival order. A fatter size tail consumes cash unevenly, so
*which* tickets are fundable at a given moment becomes path-dependent — without
any position ever being liquidated.

That is **#2436's original cash account, not a replacement for it** — refined
only in *when* it binds: at the moment a ticket needs funding, not at the moment
a position must be sold. The correction cuts back toward the reading this
section previously claimed to supersede.

> **A binding admission-funding constraint makes ticket selection depend on
> arrival order, and arrival order is path-dependent.** `force_liquidations_count`
> is a symptom of cash exhaustion *at the selling end* and is not a proxy for
> funding contention at the admission end — it stayed 0 throughout.

### The alternative this run does NOT rule out

Because what moved was size dispersion and holding time rather than admission
pressure per se, a competing explanation is live and untested: **concentration
alone makes each admission decision more consequential**, so a path difference
propagates further regardless of whether funding ever binds.

Both readings require *some* binding admission constraint, so the sufficiency
result below survives either way. But which one operates decides whether the
forward guidance generalises, and this run does not separate them. Separating
them needs a cell that raises admission pressure **without** changing size
dispersion — e.g. holding sizing fixed and cutting starting capital.

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

**Does:** **one config knob**, at fixed period and universe, takes cross-salt
trade-set divergence from exactly 0% to 13–36%. The 26y-vs-5y comparison could
not separate that from period and universe; this can, and does.

**Does not:** identify *which* consequence of that knob is responsible.
Admission-funding contention and concentration-raises-the-stakes are both live
(see above) and this run does not separate them. Both are forms of "a binding
admission constraint", so the sufficiency statement holds at that level of
abstraction and no lower.

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

1. **A backtest's noise floor depends on its portfolio-construction regime, not
   only on its length or breadth.** Two cells with the **same universe and
   window** differ **31×** in relative return noise on one knob.

   ⚠ An earlier version wrote this as "a property of how binding its admission
   constraints are, **not of its length or its tail exposure**" — an exclusivity
   claim, and one that contradicts this document's own hedge twelve lines above
   ("does not show it is the only one operating there"). Nothing here rules
   *out* length or tail exposure; it rules them *in*sufficient as the whole
   story. Fourth recurrence of that shape today, and this is the paragraph a
   future session copies forward, which is exactly why it matters.
2. **Report the constraint regime alongside any null.** A null measured at
   `max_position_pct_long = 0.14` does not transfer to a run at 0.33, let alone
   across universes.
3. **This is a testable prior for future A/B design**: if an experiment needs a
   tight null, run it where admission does not bind — and know that the answer
   it gives is then specific to that regime.
