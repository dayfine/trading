# F1 freshness axis, seeded — `Range_top_breakout` vs `Ma_cross` on the 26y base

**RESULT: `Range_top_breakout` moves DRAWDOWN and nothing else — and it is not
an exposure artifact.** Mean MaxDD **38.76 → 30.81** (−7.95pp, −21% relative),
better at all three salts by more than drawdown's own null. Return and Sharpe
flip sign between salts and stay inside their nulls. Completed 05:39.

All three tripwires reproduced the recorded null draws digit-for-digit
(281.707836178685 / 397.94778549196963 / 265.44150500657236), and the measured
null spread reproduces the historical one exactly — **132.51pp** on return
(recorded 132.5) and **37** on trades (recorded 37). The instrument is validated.

## Results

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

## It is NOT the position-count artifact

`project_entry_cap_horizon_reversal` warns that a risk-metric-led win is an
exposure signal until proven otherwise. Tested directly, from `trades.csv`
(time-weighted, entry-price basis over the 9,671-day span):

| salt | avg concurrent positions | avg deployed capital |
|---|---|---|
| 0 | 5.71 → **5.77** | $1.23M → **$1.53M** |
| 1 | 5.53 → **5.67** | $1.29M → **$1.36M** |
| 2 | 5.61 → **5.62** | $1.16M → **$1.68M** |

**rt holds more concurrent positions and deploys more capital at every salt,
while taking less drawdown at every salt.** The improvement cannot be "it holds
less" — it is the reverse. rt also turns over less (1105 vs 1151 trades at
higher concurrency ⇒ ~6% longer holds).

Note this inverts the 5-year testbed, where rt held *shorter* (45.4 → 34.4 days)
and drawdown got *worse* — a second concrete 5y-vs-26y divergence on this axis.

## What this does and does not license

**Does:** `Range_top_breakout` is a drawdown lever on the 26-year top-3000 base,
not a return lever, and not an exposure trick. That reconciles the horizon
contradiction: the unseeded 26y hinted exactly this (44.28 → 32.51) and the 5y
testbed could not resolve a ~3pp drawdown effect on 187 names.

**Does not:** promotion. One universe, one window. Per
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
on 5y (16.98 → 21.43) and much *better* on the unseeded 26y (44.28 → 32.51),
with returns unmeasurable on 26y and clearly worse on 5y.

## Why six cells and not two

The 2026-08-14 seeded run recorded **return and trades per salt and nothing
else**, and its artifacts are gone. So there is **no null spread for MaxDD or
Sharpe** — and drawdown is precisely the disputed metric.

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
confirmation grid **0 of 3** (`project_nearfloor_is_risk_not_return`).

**Path-dependence caveat (raised by the user, 2026-08-19).** A confirmation grid
is evaluated against *a baseline*, so `nearfloor`'s REJECT is conditional on the
current default. If `rt` were ever promoted, the baseline moves and nearfloor's
0-of-3 could legitimately come back different. Grid verdicts are not absolute —
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
