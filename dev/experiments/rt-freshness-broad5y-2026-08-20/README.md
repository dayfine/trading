# rt-freshness at 5 years on the BROAD universe — period isolated

**Status at commit time: NOT YET RUN.** Pre-registered; results land in a later
commit.

## Why this run exists

The 5y cell that produced the reversal (`../rt-freshness-5y-null-2026-08-20/`,
PR #2436) ran on **`universes/sp500.sexp`, 500 names**. The 26y cell (PR #2433)
ran on **top-3000**. So the comparison that concluded *"`Range_top_breakout`
fails its first independent cell"* changed **period AND universe at once**.

#2436 hedged that ("this run does not attribute the reversal"), but the hedge is
not the fix. **The fix is to not use sp500 at all** — per the user's standing
instruction (2026-08-20): *"we do NOT care about running on S&P500 universe;
even 5y should run on broad."* This is also what
`project_cell_e_2020_stall_regime` already says — **broad universe is THE
lever** — so an sp500 cell was never the right control.

## Design — one axis vs the 26y run

Both specs are the **26y specs verbatim**, with exactly two coupled edits:

| | 26y run (#2433) | this run |
|---|---|---|
| period | 2000-01-01 → 2026-06-26 | **2019-01-02 → 2023-12-29** |
| universe | top-3000, PIT **2000** | top-3000, PIT **2019** |
| breadth | 3000 | 3000 |
| every other knob | — | verbatim |

The PIT year moves with the window because a 2000-vintage composition applied to
a 2019 window is a different defect, not a control. Breadth is held at 3000,
which is the axis that was wrong before.

Arms differ **only** in `entry_freshness_basis` (`Ma_cross` vs
`Range_top_breakout`) — verified by diff.

6 cells: 2 arms × salts {0,1,2}, so the run yields the broad-5y **null** as well
as the treatment effect, same as both prior runs.

## What this can and cannot settle

**Can:** whether rt's reversal at 5y survives when the universe is held at
top-3000. That isolates **period** as the only moving axis against #2433.

**Cannot:** anything about macro-regime diversity. 2019-2023 is still one
post-2009 bull-dominated window, so per `promotion-confirmation.md` this is a
second cell, not a grid. A pre-2009 deep cell is still required before any
promotion talk.

## Decision rule, pre-registered

1. **Null first.** Compute the broad-5y null per metric from core's three salts.
   Nothing below that spread is interpretable, however suggestive.
2. **Score rt vs core under Rule 4** — the paired gap must beat that metric's own
   null, in the same direction, at **all three salts**. Report every metric,
   including the ones that fail (the 26y record's repeated defect was scoring
   only the metrics that passed).
3. **Read the outcome against #2436's sp500 result:**
   - **rt still reverses on broad-5y** ⇒ the reversal is a *period* effect and
     #2436's conclusion survives its universe error. `Range_top_breakout` stays
     not-promotable.
   - **rt does NOT reverse on broad-5y** ⇒ #2436's reversal was driven by the
     **universe**, not the period. Its headline claim is then wrong as stated,
     and the merged record plus its agent-memory note must be corrected. #2433's
     26y result would stand un-contradicted at 1-of-1 cells.
   - **mixed / in-null** ⇒ the broad-5y cell cannot resolve it; say so and do not
     pick a side.
4. Report the **broad-5y null vs the sp500-5y null** (0.9862 / 0.3616 / 0.0069 /
   0.1029 / 0.4167 for return / MaxDD / Sharpe / ulcer / win-rate). If the broad
   null is much larger, that alone explains why an sp500 cell looked decisive —
   and it would be a second, independent confirmation of the
   noise-floor-tracks-portfolio-regime finding from #2438.

Both outcomes are written down before the run, and one of them retracts a
merged conclusion.
