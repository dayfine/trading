# Next-session priorities — 2026-07-09

**Supersedes** `next-session-priorities-2026-07-08-PM.md`. Both of its P1a/P1
run-items are DONE (overnight autonomous session 07-08→09); P1b design is
drafted. Main was green at rampup (postsubmits from #1893 in flight).

## What the overnight session shipped

1. **Deep top-3000 re-measure on the 364 basis** (the user-directed overnight
   run — it had NOT been launched at the prior handoff; launched + completed
   this session, 73 min). `dev/notes/deep-remeasure-364-2026-07-09.md` +
   DEEP_RESULTS.md §364-basis:
   - MTM **+2062.6%** (12.4%/yr) but $15.3M of $21.6M end equity = ONE open
     AXTI position; **realized-basis ≈ +475% (6.9%/yr) < SPY TOTAL-RETURN
     +686.6% (8.15%/yr)** same window. Honest structural picture unchanged.
   - **Raw MaxDD 59.4% is FAKE** — MSZ (delisted micro-cap) has recurring
     corrupt 13× one-day spike-revert bars (raw EODHD, in the warehouse).
     Despiked MaxDD **50.3%** = real 2021-02→2025-05 underwater. MSZ =
     liquidity-overlay validation case #2 (ELCO was #1).
   - 0 portfolio-floor liqs at 0.14 conc; 5 zombie stale holds (#1487 off).
2. **P1a deep re-screens** (2000-2010, sp500-2000 PIT, real mechanisms, 364
   basis) — `dev/notes/p1a-deep-short-screens-364-2026-07-09.md`:
   - **Faithful-short gates: no window where they add edge.** Short leg IS
     deep-additive (ungated 296%/DD30.7 vs long-only 251%/40.6) but UNGATED
     dominates both gates. WHY: deep short value is **hedge-shaped** (early-
     bear NAV smoothing), and the gates block exactly those hedges (grind's
     8-week confirm too slow). Gates stay default-off axes.
   - **Arming speed (#1708): deep verdict CORRECTED after decomposition** —
     armon is inert 2000-2009 incl. 2008 (year-end equity identical,
     confirming the 06-22 fold story); its whole +16.5pp = ONE 2010
     divergence whose sign flips vs the 06-22 WF-CV 2010 fold → noise.
     **catstop 0.10 is the real deep value and it's distributed** (2001-02
     +5.9%, 2008 +3.1% incremental) → see P1-next.
3. **P1b design doc**: `dev/plans/fast-circuit-breaker-spy-sleeve-2026-07-08.md`
   — breaker state machine, index-referenced windowed peak (squeeze-immune, the
   GME lesson), asymmetric fast/slow re-entry, eval plan vs TR-SPY.
4. **Carried breadth fix**: re-fetched unicorn NYSE advn/decln (13,873 rows,
   1965→2020-02 upstream end) into `data/breadth/` — the 2 local-only
   `ad_bars` test failures now pass.
5. New fixtures: `experiments/build2-arming-speed-deep-screen-2026-07-08/`
   (4 arms, committed with this PR).

## P1 — next (priority order)

1. ~~catstop deep WF-CV~~ **DONE same session — Reject(promotion)**
   (`_ledger/2026-07-09-catstop-deep-wfcv`,
   `dev/backtest/catstop-deep-wfcv-2026-07-09/FINDINGS.md`): fold-honest,
   catstop 0.10 is a WASH (−0.12pp/yr for −0.20pp mean DD; fires 7/26 folds;
   worst folds untouched). PAYS in declines that keep going (2002 +3.15pp,
   2008 +2.11pp), COSTS in V-recoveries (2020 −5.24pp, 2003 −2.44pp) — the
   continue-vs-recover discrimination gap again. The P1a screen's +15.2pp was
   PATH-COMPOUNDING (methodology lesson: compounded-path screens flatter
   crash-exit mechanisms; decompose per-fold before believing them). Stays
   default-off. Parity bonus: first nested `stops_config.*` key-path axis
   validated (0.10 cell ≡ baseline bit-identical, 26/26).
   **→ P1b is now unambiguously the next lever**: the breaker design's whole
   job is the continue-vs-recover discriminator (asymmetric re-entry targets
   the 2020-shaped cost; slow-grind exit the 2002/2008-shaped pay).
2. **P1b build mandate (user):** the circuit-breaker sleeve design is drafted;
   build is default-off + behavior-relevant → wants an explicit go. The
   faithful-short screen's forward guidance STRENGTHENS the case (hedge-shaped
   crash protection is the working lever class; per-trade gates are not).
3. **P1c blending stays PARKED** until P1b produces a floor worth blending.

## Decision items (human)

1. `check_limits` wire-or-delete (carried; DELETE now natural).
2. `Portfolio_floor` monotonic-peak semantics (carried; the P1b design shows
   the squeeze-robust alternative — index-referenced windowed peak).
3. `neutral_blocks_shorts` faithfulness flip: deep cost now quantified
   (−8.6pp return, +7.8pp MaxDD on 2000-2010). Mandate call.

## Bugs / small follow-ups found this session

- **Short leaked past `enable_short_side=false`**: LH 2001-06-13→16, SHORT,
  laggard_rotation exit, in the faithful-short 00 long-only reference run.
  The laggard-rotation path appears to bypass the short flag. Small but a
  correctness bug — worth a feat-agent one-shot with a pinning test.
- **MSZ-class corrupt bars**: mechanical warehouse audit idea — flag ≥5×
  one-day spike-revert bars in sub-$5 names before the next deep re-baseline.
- `write_ledger_entry.exe` doesn't regen `index.sexp` (carried).
- `feature_screen` constant-feature failwith nit (carried).
- goldens-small still at 0.14 concentration override (carried, intentional).

## Standing constraints (unchanged)

Entry-selection CLOSED (powered null); scale-in / reallocation / envelope /
stop-tuning closed. Weinstein spine fixed. Open frontier: **floor quality
(fast circuit breaker + hedge-shaped shorts) → then blending; capacity/breadth
economics.** Comparators TOTAL-RETURN always. All pre-2026-07-08 absolute
numbers are 210-basis — re-measure before citing.
