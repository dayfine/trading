# Armed-StopLimit backtests were not reproducible — 2026-08-11

**Verdict: the P0 premise was wrong.** Task #17 asked which of five commits
changed armed-StopLimit behaviour between ladder-v3 and ladder-v4. The answer
is *none of them, as far as this evidence can tell* — because the comparison
itself was not reproducible. Two runs of one binary over one scenario and one
dataset returned different numbers.

Fix: PR `fix/deterministic-intraday-path`.

## What was measured

A short probe was built to bisect affordably: the ladder v2-core armed entry
stack on the 302-symbol `goldens-small` universe over six years — **~3.5 min a
run** against the 1h46m a 26y/top-3000 probe costs. Spec committed at
`trading/test_data/backtest_scenarios/experiments/armed-stoplimit-repro-2026-08-11/`.

The five commits, each probed once (cumulative, so each row's delta is that
commit's):

| commit | | total_return_pct | delta |
|---|---|---|---|
| `dd99a955d` | baseline (pre-F3) | 49.196080 | — |
| `7dbdf9646` | F3 stop_width_mode | 49.739915 | +0.544 |
| `2f6f07892` | F1 entry_freshness_basis | 48.617514 | −1.122 |
| `e3087812c` | F2 entry_order_ttl_weeks | 48.870941 | +0.253 |
| `f806fab14` | F5 volume_confirm_at_fill | 49.805953 | +0.935 |
| `a03f2a4e4` | PR-5 audit fields | 49.744711 | −0.061 |
| `7f8bb8df` | main | 49.284595 | −0.460 |

Every commit appeared to perturb the result. That is the shape of a null
result, not five regressions, and it prompted the control that should have run
first.

## The control

Same binary, same spec, same data, repeated:

- at `a03f2a4e4`: 49.744711 / 49.651156 / 49.638993
- at `main`: 49.284595 / 50.058893 / 49.344377 / 49.372289 — **spread 0.774pp**

The run-to-run spread is as large as every per-commit delta in the table. With
n=1 per commit against a null spread of 0.774pp, **no commit is distinguishable
from noise.** The bisect measured its own noise floor.

## Root cause

`Price_path.default_config` sets `seed = None`, and `seed = None` selects
`Random.State.make_self_init ()` for every generated path
(`price_path.ml:435`). Nothing in the backtest ever supplied a seed, so each
process drew fresh intraday paths.

Causally confirmed both directions: pinning `seed = Some 42` made two runs
bit-identical (49.4429893245481 twice); restoring `None` made them differ
again.

## Why every gate was blind

Market orders fill at the bar's open/close and never walk the intraday path.
Only **resting stop/limit orders** consult it — i.e. precisely the
armed-StopLimit entry family, which **no golden scenario arms**.

Verified, not assumed: the unarmed `six-year-2018-2023` golden returns
`100.63260509255689` on two consecutive runs, and the *same* value again after
the fix. Goldens are deterministic and immune; the armed regime was neither.

So the structural hole the 08-11 handoff identified — "zero of the 10 golden
specs arm that family" — is real, and this is the defect it was hiding. The
missing armed golden could not have been written before this fix: there was no
stable number to pin.

## Consequences for work in flight

- **The ladder-v3 → ladder-v4 cell-00 gap (317.80 → 343.90, 1143 → 1136
  trades, 36.49 → 44.28 DD) is not attributable to a code regression on this
  evidence.** It may be entirely noise, partly noise, or real; the runs that
  produced it are not reproducible, so the question cannot be answered by
  re-reading the diffs. Settle it by re-running both cells on the fixed build.
  Note the honest limit: the 6y/302 null (0.774pp on ~49.5%, 1.6% relative)
  does not by itself bound the 26y/top-3000 null (the v3/v4 gap is ~7.9%
  relative, with trade counts moving), so "it is all noise" is a hypothesis,
  not a finding.
- **Ladder-v4's Stage-A one-axis table is contaminated by an unmeasured noise
  term.** The large effects survive on magnitude alone — cell 09 nearfloor
  (670.0) and cell 10 volconf (−47.6) are nowhere near any plausible noise
  floor. The small ones do not: cells 01–05 sit within tens of percent of cell
  00 with no null to compare against. **Before any of those deltas is read as
  signal, the null must be measured at 26y/top-3000 scale** (repeat one cell
  k times on the pre-fix build), or the cells re-run on the fixed build.
- The running v4 sweep is on the pre-fix build at `4ecbe1154`. It was not
  disturbed. Its cell-to-cell deltas remain internally consistent in the weak
  sense that all cells share the defect — but they do not share a draw.

## What this does not explain

The 08-11 handoff's other observations stand on their own: F5's 3× candidate
explosion and −47.6% return, and the `stop_floor_kind` shift under `Nearest`,
are mechanism-scale effects with named mechanisms, orders of magnitude beyond
this noise term.

## Follow-ups

1. **Armed-StopLimit golden** (the durable close of the structural hole). Now
   possible, but its bands must be pinned from a **CI** measurement: local
   `data/` differs from CI's committed tree (the same golden reads 100.63
   locally against a pinned CI band of ~79.13), so bands measured on this host
   would be wrong. Land the scenario, read the first postsubmit run, re-pin.
2. **Measure the 26y null.** k repeats of one v4 cell on the pre-fix build
   gives the noise floor the Stage-A table needs to be read against.
3. **Re-run v3-w4 and v4-cell00 on the fixed build** to settle whether any gap
   survives.

## Method note

The failure mode here is the one `.claude/rules/mechanism-validation-rigor.md`
exists to prevent, in a new costume: five single-sample measurements were about
to be read as five effects, with a plausible mechanism story already drafted
for one of them (a float-boundary change in PR-5's volume refactor, `a >= k*b`
rewritten as `a/b >= k`). That story may even be true; it is unfalsifiable at
n=1. **Run the repeated-measurement control before the comparison, not after
the comparison surprises you.**
