# Nearfloor at 26y × top-3000 — 3 path salts per arm

**What this settles.** `dev/notes/ladder-v4-read-2026-08-12.md` §2 could not rank
cell 09 (`support_floor_anchor_scope = Nearest`) against cell 00 because the 26y
ladder ran one draw per cell and the measured noise floor was 278pp. This runs
both arms three times under `TRADING_PATH_SEED_SALT`, so each arm is a small
distribution instead of a lottery ticket.

Same pinned worktree (`.claude/worktrees/v4-fixed`, post-#2279 seed fix), same
snapshot warehouse, `--parallel 1`. `run.sh` reproduces it; `results.txt` is the
raw per-run metric dump. Arms differ in exactly one knob.

## Results

| metric | core (cell 00) | nearfloor (cell 09) | overlap? |
|---|---|---|---|
| **return** | 265.4 / 281.7 / 398.0 → **315.0** | 337.3 / 483.1 / 541.6 → **454.0** | **YES** (337-398) |
| **trades** | 1135 / 1147 / 1172 → 1151 | 970 / 973 / 985 → 976 | none |
| **win rate** | 32.95 / 33.13 / 33.45 → 33.2 | 39.39 / 40.08 / 40.72 → 40.1 | none |
| **maxDD** | 36.25 / 39.03 / 41.01 → 38.8 | 27.77 / 29.45 / 29.86 → **29.0** | none |
| **holding days** | 46.3 / 47.1 / 48.2 → 47.2 | 72.6 / 74.3 / 74.7 → 73.9 | none |
| **Sharpe** | 0.420 / 0.432 / 0.500 → 0.451 | 0.448 / 0.527 / 0.542 → 0.506 | YES |

Return spread: core **132.5pp**, nearfloor **204.3pp**.

## 1. The risk signature is real — four metrics, zero overlap

Fewer trades, ~7pp higher win rate, **~10pp lower drawdown**, ~57% longer holds.
Every one separates completely across three draws per arm, and every one points
the same way as the 302/6y run
(`dev/experiments/nearfloor-302-6y-2026-08-13/`). A path-draw artifact does not
reproduce four-for-four across two universes and two window lengths.

The drawdown result is the strongest single number in the study: **38.8 → 29.0**,
no overlap.

## 2. The return direction is SCALE-DEPENDENT

| context | who wins on return | separation |
|---|---|---|
| 302 syms / 6y | **core**, 9/9 pairwise (6/6 draws, every pairing) | clean — min core 47.33 > max nearfloor 25.42 |
| 26y / top-3000 | **nearfloor**, 8/9 pairwise, +139pp on the mean | **none** — ranges overlap 337-398 |

8-of-9 pairwise at n=3 v 3 is p ≈ 0.10 by exact rank test: suggestive, not
established. But the *direction* reverses between scales, which means the
shorthand "nearfloor is a risk dial that costs return" is only true at 302/6y.
At 26y it costs nothing measurable and may add. Return / maxDD roughly doubles
(8.1 → 15.6).

## 3. RETRACTION — "nearfloor collapses path-variance" was 302/6y-specific

The 302/6y writeup observed nearfloor's return spread at **0.44pp** against
core's **18.58pp** (~42x tighter) and concluded the mechanism *collapses
path-variance*. **That does not hold here.** At 26y nearfloor's spread is
**204.3pp** against core's **132.5pp** — about 1.5x *wider*.

The claim was generalized from a single context the same night it was measured,
which is precisely the error `ladder-v4-read` §1b exists to warn about. It is
retracted outside 302/6y, in this file and in
`dev/agent-memory/project_nearfloor_is_risk_not_return.md`.

**Why the two scales differ, most plausibly:** at 302 symbols over 6 years the
opportunity set is thin, both arms trade nearly the same names, and the stop rule
dominates the outcome — so damping the stop damps the result. At 26y × top-3000
the monster lottery is live (~976-1151 trades, and §1b showed ~half the PnL in
five trades); *which* monsters get funded is a breadth-and-capital phenomenon,
and no stop rule damps that. Consistent with `project_edge_is_the_fat_tail`.

**That story makes a checkable prediction, and this run's own data confirms it.**
If the 302/6y variance-collapse came from both arms trading nearly the same
names, then *which names get traded* should barely move across draws there and
should move materially at 26y. It does: trade counts vary by **1** across the
302/6y draws (288/289/288) against **37 and 15** here (1135/1147/1172 and
970/973/985). The composition is genuinely churning at 26y and essentially
frozen at 302/6y — which is the mechanism, not a restatement of the outcome.

⚠ One caveat on the label. The two contexts differ in breadth, window length
*and* macro regime simultaneously, so "scale-specific" is shorthand for a
confound, and the explanation above leans specifically on **breadth**. A 3-salt
sp500/5y run (different breadth, same era) would separate breadth from window
length. Until then the retraction is stated in its conservative form — the claim
does not hold *outside* 302/6y — rather than asserting which axis causes it.

## Status: promotion CANDIDATE, not a promotion

Three path draws per arm is **not** walk-forward CV. Before any default flip,
`.claude/rules/promotion-confirmation.md` requires a ≥3-cell grid spanning period
*and* universe diversity with at least one genuinely different macro regime, plus
best-of-N correction (Deflated Sharpe). None of that has been done.

What this study does establish is that the mechanism is worth that spend: the
drawdown improvement is large, clean and reproduced at both scales, and the
return objection that previously blocked it is **not established at 26y** — the
arms overlap there rather than core winning. That is non-establishment, not
refutation: 8/9 pairwise is p≈0.10 one-sided, ≈0.20 two-sided, and the direction
was chosen after seeing the data, against a prior pointing the other way. The
objection stands undisturbed at 302/6y, where core wins **9/9 with complete
separation** — which is a stronger result than this 26y one, and should not be
flattened by quoting it as "6/6 draws" beside 26y's "8/9 pairwise" as though the
two were the same kind of count.

**Next step if pursued:** run it as a `Variant_matrix` axis under WF-CV rather
than more single-window salts — more draws of the same window cannot fix the
n=3-per-arm power problem, and the 26y window is one macro path however many
times it is re-drawn.
