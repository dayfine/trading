# Paired golden runs for the clock-52 flip (#2405 / PR #2587)

QC rework iteration 1 evidence (B1/B2/G2 of the qc-behavioral review at
`5044eb5f1`). All arms run in the pinned worktree `.claude/worktrees/
sweep-clock52` at `5dc61da07` (= the flip commit on top of merged #2583), so
both arms of every pair share one build; only `entry_order_max_rest_weeks`
differs. Per-cell raw artifacts (`*-actual.sexp`, `*-trades.csv`) are in
`.sweep-output/clock52g/` on the run host and committed under `results/`
(feedback_commit_raw_per_arm_artifacts). Old-arm (w0) specs =
the golden spec + `((entry_order_max_rest_weeks 0))` prepended to
`config_overrides`; committed under `specs/goldens-paired/`.

## Count correction (review item)

The blast radius is **12 strategy cells, not 13** as the run script's header
previously said: 15 goldens inherit the default; 3 carry `Bah_benchmark`
(no strategy config). Header fixed in this commit.

Additionally: `dev/weekly-picks/live-config-overrides.sexp` does **not** pin
this knob (grep = 0), so the **live weekly-picks pipeline inherits 52** on
merge. Assessment: no material effect — live tickets are re-issued weekly
from the report and lapse between reports (weinstein-book-reference.md §4.7,
"GTC-persistence semantics only become meaningful for a live weekly-re-issued
ticket (which DOES lapse between reports)"); a 52-week backstop on a ticket
that lives ≤1 week is dead code in the live path.

## Old-arm provenance — two golden classes

- **6 tight-pinned cells** (`±15%-around-actuals` pin convention, re-pinned
  2026-08-24 at the post-#2569/post-#2530 basis): the pin midpoint IS the
  old-arm point. One run per cell at the flipped default + compare-to-pin =
  the pair.
- **5 wide-band cells** (sentinel smoke bounds, no old-arm point on record):
  both arms run by hand — w52 and w0 (`-w0` specs above).
- `weinstein-2019-full-pool` is wide-band but its w0 control ran as
  `fp0-oldarm` — digit-for-digit identical to the w52 run (see table), so it
  is complete without a further old-arm run.

## Paired table — tight-pinned cells (pin = old arm)

| golden | metric | w0 (pin) | w52 (run) | Δ |
|---|---|---:|---:|---:|
| sp500-2019-2023-armed-stoplimit | return % | 42.7399 | 38.8009 | **−3.94pp** |
| | trades | 192 | 187 | −5 |
| | sharpe | 0.5552 | 0.5177 | −0.037 |
| | maxDD % | 21.4596 | 21.4596 | 0 (identical) |

The armed-stoplimit w0 row is not inferred from the pin: its old arm was
**re-run directly** (`sp500-2019-2023-armed-stoplimit-w0`, 2026-08-30) and
came out 42.7399 / 192 / 0.5552 / 21.4596 — digit-for-digit the pin
midpoint, which simultaneously validates the pin-midpoint-as-old-arm
methodology used for the other five tight cells.

**Trade-level dissection of the −3.94pp** (join key `symbol|entry_date`
across arms; per feedback_dissect_before_proposing_a_mechanism): 171 of
~190 entries shared; 21 entries unique to w0 (net **−$26.6k**), 16 unique
to w52 (net **−$80.8k**), shared-entry PnL drifts −$6.9k on exit paths.
First divergent entry 2021-03 — 2y3m into the window, where 52-week-aged
tickets first free slots/cash and the top-N admission reshuffles. Both
unique cohorts are net losers; the delta is *which* losers got admitted —
the same path-dominated reshuffle the ledger dissection describes at 26y,
and within this golden's ±15% band. No mechanism-tax claim attaches
(#2380 convention: tail-path reshuffling on a pin is not evidence).
| sp500-2019-2023 | return % | 76.8044 | 76.8044 | 0 (identical) |
| sp500-2019-2023-long-only | return % | 76.0665 | 76.0665 | 0 (identical) |
| weinstein-2019-top-500 | return % | 475.4773 | 475.4773 | 0 (identical) |
| sp500-2010-2026 | return % | 541.8425 | 541.8425 | 0 (identical) |
| sp500-2010-2026-longshort | return % | 737.3590 | 737.3590 | 0 (identical) |

For the five identical cells, trades / sharpe / maxDD also equal the pin
midpoints to the pins' recorded precision (4 dp) — the clock never fired.
`enable_sim_entry_stoplimit` defaults **true** since #2569, so tickets rest
in every cell; identity means no ticket in these books ever rested a full 52
weeks unfilled. The armed-stoplimit cell is the entry-path-heaviest golden
(its docstring's words) and the one cell where resting tickets aged past the
clock. Its w0 arm re-run (below) supplies the old-arm trades.csv for the
trade-level dissection.

All six cells are **inside their pinned bands at w52** — no golden fails at
the flipped default; no re-pin is forced by this flip.

| golden | in-band at w52? |
|---|---|
| sp500-2019-2023-armed-stoplimit | YES (return 38.80 in [36.33, 49.15]; all metrics in-band) |
| other five tight cells | YES (bit-identical to pin) |

## Paired table — wide-band cells (both arms run)

Prediction on record BEFORE the w0 runs (2026-08-30): all five pairs come
out at or near identity, matching the tight-cell pattern — the knob binds
only where a ticket rests ≥52 whole weeks.

| golden | metric | w0 | w52 | Δ |
|---|---|---:|---:|---:|
| weinstein-2019-full-pool (control `fp0-oldarm`) | return % | 51.1619 | 51.1619 | 0 (identical) |
| | trades | 193 | 193 | 0 |
| sp500-2000-2026-catstop | return % / trades | 108.3497 / 609 | 108.3497 / 609 | 0 (identical) |
| sp500-2000-2026-catstop-armon | return % / trades | 107.6377 / 612 | 107.6377 / 612 | 0 (identical) |
| sp500-2000-2026-longshort | return % / trades | 155.5248 / 685 | 155.5248 / 685 | 0 (identical) |
| sp500-1998-2026 | return % / trades | 66.3610 / 479 | 66.3610 / 479 | 0 (identical) |
| top3000-2000-2026-catstop | return % / trades | 1600.1775 / 571 | 1600.1775 / 571 | 0 (identical) |

(top3000 both arms also identical on sharpe 0.3258 / maxDD 30.73 / win_rate
35.03 — full actual.sexp files byte-comparable in `results/`.)

## Why 11 no-ops here but a 183pp surface effect in the ledger — the knob's
## real arming condition

`sim_entry_trigger_at_suggested` defaults **false** (config .ml line 136)
and is armed in exactly ONE golden — `sp500-2019-2023-armed-stoplimit` —
and in every cell of the #2405 surface (record-convention lineage). With it
false, a ticket triggers at the current close and fills within ~a bar, so
nothing ever rests 52 weeks and the clock is dead code: that is the 11
bit-identical cells, mechanically. With it true, tickets rest at the
suggested breakout `E` and can rest indefinitely: that is where the clock
binds — the one moved golden, and the entire ledger ACCEPT effect
(cell A 496.20 vs null 312.74). **The flip's blast radius on default-path
configs is empty by construction; its effect lives entirely behind the
trigger-at-E arming.** (Live overrides arm neither resting-trigger knob —
comment-only mention at live-config-overrides.sexp:69 — and live tickets
lapse weekly regardless, §4.7.)

## Bottom line (all 12 cells measured, 2026-08-30)

**11 of 12 paired cells are bit-identical under the flip** — the prediction
recorded above before the w0 runs held 5/5 on the wide-band cells. The one
moved cell, `sp500-2019-2023-armed-stoplimit`, shifts −3.94pp return with
maxDD unchanged, stays inside its ±15% pinned band on every metric, and
dissects to an entry-admission reshuffle (both divergent cohorts net
losers), not a mechanism tax. **No golden fails at the flipped default and
no re-pin is required.**

## G2 rework — cell D (composition-independent) + cell-B null

### Cell D — top-1000 PIT-2000, 2000→2026, breadth as the ONLY moved axis

clockA config, same window, same PIT vintage year, breadth swapped
top-3000 → top-1000 (`goldens-custom-universe/composition/top-1000-2000.sexp`).
This is the composition-independent cell the ledger deferred to this PR,
free of the A/B period confound the review named. Run 2026-08-30, build
`5dc61da07`, salt 0 (`run-d.sh`; artifacts `results/goldens/clockD-*`).

| arm | return % | trades | win % | sharpe | maxDD % |
|---|---:|---:|---:|---:|---:|
| clockD-0 (null) | 410.60 | 801 | 34.46 | 0.4759 | 30.13 |
| clockD-52 | 371.50 | 741 | 35.49 | **0.4958** | **23.29** |

**Mixed cell — reported plainly.** 52 loses raw return (−39.1pp on a 26y
book) but wins sharpe (+0.020) and wins maxDD by −6.84pp; trades −60 with
win-rate up, the same shape as cell A. So the grid's return sweep breaks at
D (3/4 cells), while the **risk-adjusted improvement (sharpe + maxDD) is
now 4/4 across compositions** — the maxDD win repeats in every cell (A
38.78→25.65, B 34.12→27.00, C 27.10→25.65, D 30.13→23.29). Caveat held
open: no D-cell null spread was run, so whether −39.1pp exceeds top-1000
26y path noise is unmeasured (at top-3000/26y, >50% of the book diverges
between arms per the ledger dissection; the honest read is "return effect
composition-dependent, risk effect composition-robust"). Under the
promotion decision rule 52 is not dominated at D (2 of 3 headline metrics).

### Cell B's own null — paired arms at salts {0,1,2}, one build

`run-b-null.sh`, this build (the original B ran at `90dfd6e97`, worktree
since removed, so salt 0 was re-run here; it reproduces the ledger's B
numbers digit-for-digit — a free determinism/build-lineage cross-check).

| salt | w0 ret % | w52 ret % | Δ ret | w0/w52 sharpe | w0/w52 maxDD |
|---|---:|---:|---:|---|---|
| 0 | 18.02 | 25.31 | **+7.29** | 0.271 / 0.345 | 34.12 / 27.00 |
| 1 | 17.30 | 23.84 | **+6.54** | 0.264 / 0.333 | 34.47 / 29.30 |
| 2 | 3.11 | 12.70 | **+9.59** | 0.122 / 0.221 | 40.31 / 33.90 |

Answer to the review's observation 2: **cell B's margin survives its own
null.** Arm LEVELS swing ~15pp salt-to-salt (s2 is a bad draw for both
arms), but the PAIRED delta is +6.5/+7.3/+9.6pp — positive on every salt
with a 3.05pp spread, i.e. the pairing controls the path noise and the
B-cell effect is not a salt-0 artifact. Sharpe and maxDD improve on all
three salts as well.

## BOOK-CHECK resolution (review item)

Resolved in this commit — see the write-back in
`docs/design/weinstein-book-reference.md` §4.7 ("Resolved 2026-08-30"):
the book's only GTC-cancel criterion is *pattern change + discretion* (Ch. 3
quiz answer 5), never elapsed time, and there is no weekly-lapse protocol.
A time-based cancel is therefore an *adaptation*, defensible only at an
outer-bound horizon (52w ≈ 17× the book's stated multi-week rest); the
condition-based reading was already measured and REJECTED at −137pp
(ledger `2026-08-18-entry-ticket-rescreen`).
