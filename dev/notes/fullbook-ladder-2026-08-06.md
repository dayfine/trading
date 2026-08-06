# Ladder 3 — the full book ticket, and the inversion of the verdict (2026-08-06)

Final rung of the fill-model program (`sim-entry-fill-ladder-2026-08-05.md` →
`honest-ladder-2026-08-05.md` → `localtop-deepdive-2026-08-06.md`). Two arms
with the COMPLETE book ticket — E-anchored resting StopLimit, band 2pp, and
the #2219 stop re-anchored to the entry base — pinned @`b918e1d2`, same
split-safe basis. Clean runs (no ELI-class contamination hits).

## The complete eight-arm table (26y, top-3000, identical basis)

| Arm | Realized | Sharpe | MaxDD | Trades |
|---|---:|---:|---:|---:|
| control — market fill + deep structural floors (record rule) | **+8,367%** | **0.90** | 37.1% | 1,122 |
| estop2 — E-stop band2 × deep floor (mispaired; incl. fake ELI +$4.3M) | +965%* | 0.30 | 29.5% | 1,102 |
| localtop26 — 26w-E × deep floor (mispaired) | +474% | 0.57 | 39.3% | 1,122 |
| localtop52 — 52w-E × deep floor (mispaired) | +177% | 0.38 | 29.5% | 1,109 |
| estop15 — E-stop band15 × deep floor | +244% | 0.41 | 37.7% | 993 |
| **fullbook-graded — E-stop band2 + base-anchored stop** | **+287%** | 0.48 | **23.2%** | 1,161 |
| **fullbook-local26 — 26w-E stop band2 + base-anchored stop** | +268% | 0.44 | 40.8% | 1,187 |
| (SPY-TR same window ≈ +687%) | | | | |

*contaminated; corrected ≈ +400-500%.

## The decisive specimen, closed

The #2219 re-anchor DID unblock the AXTI class (ranked #1, previously
skipped 24× Stop_too_wide): fullbook-graded entered AXTI twice — and the
book's tight base stop exited both within a day (9.46→9.48 +0%;
4.13→4.00 −3%). The +5,196%/+$64.3M ride (76% of the record) is unreachable
under the book ticket from EITHER side: deep floor → risk gate rejects the
ticket; tight base stop → next-day noise stops it out.

## The inversion

The record is NOT a "fill-flattered artifact of the book rule." It is a
DIFFERENT, coherent, live-executable rule that empirically dominates the
book ticket ~30× on this window:

- **Record rule:** enter at market after the weekly Stage-2 close confirms;
  initial stop at the DEEP structural floor (survives base noise); ride with
  extension-stop insurance. Executable live with market/limit-at-open orders.
- **Book ticket:** resting buy-stop at the breakout level, tight band, stop
  under the base. Every variant measured lands at +180% to ~+500% honest
  (with the graded fullbook arm's 23.2% MaxDD the best risk profile of the
  program).

The wedge decomposes into three reinforcing channels, all fat-tail-loading:
(1) sub-E fills buy bases/pullbacks the resting stop never touches;
(2) deep floors hold through the noise that kills tight base stops (AXTI);
(3) both compound into monster rides (AXTI, BFX-2020, the 2009/2020 recovery
clusters — see the YoY map in the deepdive note).

## Decision framing (user)

The live/record consistency choice is now fully measured:
- **(A) Align live to the record rule** — weekly tickets become
  market/limit-at-open (cap optional) + the DEEP structural floor stops the
  sim already computes; live then honestly matches the +8,367% basis. Costs:
  worse DD than the book rule (37% vs 23%), extreme realized concentration
  (one trade = 76%), and abandoning the resting-stop discipline.
- **(B) Align live+record to the book ticket** — records re-base to the
  ~+280% / DD 23% profile (still index-beating on Sortino? — 0.69, below
  SPY-BAH-class; honestly weaker), keep the buy-stop workflow.
- Any promotion of the involved flags stays behind WF-CV + the
  confirmation grid regardless (single-window evidence throughout).

## Artifacts

`dev/experiments/stoplimit-entry-wfcv-2026-08-04/fullbook-ladder/`
(2× actual/trades/equity). Twins committed under `staging-record-convention/`
(fullbook-graded / fullbook-local26 + the localtop twins backfilled from the
run branch).
