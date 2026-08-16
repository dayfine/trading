# Nearfloor confirmation grid — VERDICT: do not promote

`support_floor_anchor_scope = Nearest` (vs the default `Window_extreme`), run as
the `promotion-confirmation.md` grid on top of the ladder-v4 seeded ACCEPT.

**Verdict: NO PROMOTION.** The mechanism keeps its default-off axis status. On
return it is *unresolved-but-positive* in one cell, *inside the null* in the
second, and a **real loss** in the third — and both grid axes (period *and*
universe) flip it independently. It never once beats baseline in a way that
survives its own cell's null with n≥3.

## The grid

Three (universe × period) cells, each read against **its own** core-salt null —
cell A's 132.5pp yardstick does not carry, as cell B's 180.1pp spread shows.
Same pinned worktree (`60100bbf6`) and same binary as the seeded run, so cell A
is directly comparable. Arms are paired at the same `TRADING_PATH_SEED_SALT`.

| cell | universe | period | core salts | nearfloor |
|---|---|---|---|---|
| **A** | top-3000 | 2000-2026 | 3 | 1 (+2 mixes) |
| **B** | sp500 | 2000-2026 | 3 | 1 |
| **C** | top-3000 | 2010-2026 | 2 | 1 |

A is the macro-diverse cell (dot-com bust + GFC). B isolates **universe** at
fixed period. C isolates **period** at fixed universe. That is the minimum
viable grid the rule asks for.

## Results

### Cell A — top-3000 × 2000-2026 (the cell that produced the ACCEPT)

Both arms at 3 salts (`dev/experiments/nearfloor-26y-salts-2026-08-13/`):

| metric | core (n=3) | nearfloor (n=3) | separated? |
|---|---|---|---|
| return | 265.4 / 281.7 / 398.0 → **315.0** | 337.3 / 483.1 / 541.6 → **454.0** | **no** — ranges overlap 337-398; 8/9 pairwise, p≈0.10 one-sided |
| trades | 1135 / 1147 / 1172 | 970 / 973 / 985 | **yes**, zero overlap |
| maxDD | 36.25 / 39.03 / 41.01 → **38.8** | 27.77 / 29.45 / 29.86 → **29.0** | **yes**, zero overlap (−9.8pp) |

Core null **132.5pp**; nearfloor's own spread is **204.3pp** — *wider*, so the
mean gap of +139pp sits inside the dispersion of the arm claiming it.

**Read honestly, cell A is `return unresolved, risk clearly better`, not a win.**
The `483.10 / 508.12 / 568.10` figures that motivated the grid are three
*different mixes* at salt 0 (`09-nearfloor`, `15-rt-ttl4-nearfloor`,
`13-rt-nearfloor`), not three salts of one arm; nearfloor's own salt-0 draw is
483.10 and its salt-2 draw is 337.3, which is inside the core range. Cell A is
the strongest cell in the grid and it is already only suggestive.

### Cell B — sp500 × 2000-2026 (universe swap, same period)

| arm | salt | return | trades | maxDD |
|---|---|---|---|---|
| core | 0 | 591.38 | 1041 | 27.35 |
| core | 1 | 740.05 | 1066 | 29.66 |
| core | 2 | 771.47 | 1035 | 25.54 |
| **nearfloor** | 0 | **504.69** | 982 | 27.94 |

Null: **180.1pp** return (mean 700.97), **4.11pp** maxDD (mean 27.52).
Paired vs core s0: **−86.7pp return** (inside the 180pp null), **+0.6pp maxDD**
(inside the 4.11pp null). Trade count barely moves (−5.7%).
**No effect the data can resolve** — not a loss, but emphatically not the +201pp
of cell A.

### Cell C — top-3000 × 2010-2026 (period swap, same universe)

| arm | salt | return | trades | maxDD |
|---|---|---|---|---|
| core | 0 | 225.83 | 799 | 34.08 |
| core | 1 | 260.01 | 759 | 35.17 |
| **nearfloor** | 0 | **156.68** | 699 | **28.83** |

Null: **34.2pp** return (mean 242.92, n=2), **1.10pp** maxDD (mean 34.62, n=2).
Paired vs core s0: **−69.2pp return — 2.0× the null spread**, and **−5.2pp
maxDD — 4.8× the null spread**. A real return loss bought with a real DD
improvement.

⚠ A 2-salt spread understates the true spread; cell C's null is the weakest in
the grid. The return loss is 2× that weak null, not 2× a 3-salt one.

## The decision rule

`promotion-confirmation.md`: promote a value only if it beats baseline in a
**strong majority** of cells (all-but-one at n=3) **and is never badly dominated
in any**. Nearfloor beats baseline in **0 of 3 cells at the standard of "outside
its own cell's null"** — A is positive but unresolved at n=3, B is inside the
null, C is a loss at 2× the null. And it *is* dominated in C, on return and on
risk-adjusted return alike.

Crude Calmar (return ÷ maxDD), paired at salt 0:

| cell | core | nearfloor | |
|---|---|---|---|
| A | 7.22 | **16.18** | better (but n=1 pairing of an unresolved arm) |
| B | 21.62 | 18.06 | worse |
| C | 6.63 | 5.43 | worse |

The DD improvement does not buy back the return loss anywhere except cell A.
**No promotion. Keep default-off as an axis.**

## The transferable why — nearfloor is a *crash-depth* dial, not a stop dial

Both grid axes flip the result independently, and they flip it in the same
direction, which pins the mechanism:

- **A → B (period fixed, universe narrowed):** effect collapses to nothing, and
  the trade count barely moves (−5.7% vs −15.4%). If the two anchors rarely
  *disagree* on large caps, the knob is a no-op there. `Nearest` and
  `Window_extreme` coincide whenever the lookback window holds no deep prior
  low — which is the normal case for an S&P name and the exceptional case for a
  microcap that has already been cut in half once. Cell A's audit corroborates
  the same thing from the other side: arming `Nearest` moves `stop_floor_kind`
  from 867/558 to 108/1158 `Buffer_fallback`/`Support_floor`, i.e. under
  `Window_extreme` most candidates had **no usable floor at all** and fell back
  to an arbitrary buffer.
- **A → C (universe fixed, bear regimes removed):** the trade-count and DD
  effects survive (−12.5% trades, −5.2pp maxDD) but the return goes **negative**.
  The tighter stop still fires more often; without crashes to be saved from, the
  extra firing lands on winners.

So the mechanism is: `Window_extreme` anchors the support floor at the deepest
low in the window, which on a crash-scarred broad universe is *far* below price,
so the installed stop is loose and losers run. `Nearest` anchors at the closest
support, tightening the stop. **That tightening pays only where deep prior lows
are common (broad universe) and crashes actually arrive (a bear-containing
window). Everywhere else it is a plain fat-tail tax** — the twelfth confirmation
of `project_edge_is_the_fat_tail`, and consistent with every previous
stop-tightening rejection (`project_weekly_close_stop_lever`,
`project_extension_stop_screen_no_build`).

The risk signature that `project_nearfloor_is_risk_not_return` recorded (fewer
trades, lower maxDD) **partly reproduces**: fewer trades in all three cells
(−15.4% / −5.7% / −12.5%), but the maxDD win appears only in A (−9.8pp, zero
overlap at n=3) and C (−5.2pp, 4.8× its null) and is **absent in B** (+0.6pp,
inside the null). So the memory's "−10pp maxDD, zero overlap" is a
**broad-universe** number, not a property of the mechanism — the same
over-generalisation that file already had to retract once for the
variance-collapse claim, now caught by the grid instead of by a later re-run.

## What this rules out, and what it opens

**Rules out:** flipping `support_floor_anchor_scope` to `Nearest` by default, and
— by the same mechanism — any *global* stop-tightening lever. The grid says the
knob's sign is set by regime and universe breadth, so a single global value
cannot be right.

**Opens:** `Nearest` is a legitimate **breadth-conditional preset knob**, the same
shape as `project_declining_ma_gate_breadth_preset` (ARM-FOR-BROAD). Cell A is
the case where it is worth +201pp and −9pp DD. If a breadth preset is ever
built, this belongs in it. Recording that classification now matters: per
`experiment-flag-discipline.md` Rule 4 this is a
**REJECT-as-default-but-legitimate-axis**, explicitly **not** do-not-revive, so
it must **not** be retired.

## Method notes

- Every cell was read against its own core salts. Cell B's null (180.1pp) is
  **36% wider** than cell A's (132.5pp) on the same period — carrying A's
  yardstick across would have scored B's −86.7pp as a loss when it is inside the
  noise. `feedback_run_the_null_control_first`, applied per cell.
- Single nearfloor salt in B and C. The cell-B "no effect" reading is
  underpowered; a second salt there would be the cheapest next datum if anyone
  wants to revisit. It would not change the verdict, which is driven by C's loss
  and by the 1-of-3 count.
- The grid was narrowed from 11 runs to 7 mid-flight: the `ttl4` and `both` arms
  were dropped once ttl4 was known mis-specified (defect D — its 28-day clock
  cuts the lower edge of the most profitable rest-time band). Those arms answered
  a question that no longer stands; TTL gets its own re-test at {13, 26, 52}
  weeks after the knob is split.

## Artifacts

- Chain: `/tmp/v4grid-run.sh`, log `/tmp/v4grid-chain.log`, specs
  `/tmp/v4grid-specs/`, outputs `/tmp/v4grid/`.
- Pinned worktree `.claude/worktrees/sweep-v4-seeded` @ `60100bbf6` (same binary
  as the seeded run — cell A is comparable, not merely similar).
- Cell A source: `dev/experiments/ladder-v4-seeded-2026-08-14/results.md`.
