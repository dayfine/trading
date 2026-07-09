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
2. ~~P1b build mandate~~ **GRANTED (user, 2026-07-09) — step 1 MERGED
   (#1904)**: `Index_circuit_breaker` pure lib in analysis/weinstein/macro —
   two-state machine, T1 fast-crash / T3 trailing-WINDOW floor / T2
   slow-grind exits, asymmetric self-contained re-entry, both GME
   anti-sterilization semantics test-pinned, zero consumers. Track:
   `dev/status/floor-quality.md`. **NEXT = step 2**: thin SPY sleeve
   consumer (alongside Spy_only_weinstein, adjusted-close bars) → step 3
   lens screen vs TR-SPY (per-episode table incl. 2000-02/2008/2020/2022,
   interventions count, whipsaw dist) → step 4 WF-CV surface + promotion
   grid. The catstop WF-CV quantified exactly what the breaker must beat:
   discriminate continue (2002/2008) from recover (2003/2020).
3. **P1c blending stays PARKED** until P1b produces a floor worth blending.
4. **Grind-confirm tunability** (user question 2026-07-09): the classifier's
   `weeks_below_ma_slow_grind` (default 8) is a `Decline_character.config`
   field but NOT yet exposed as a strategy-config knob (the gate's classify
   site locks it to default). Queued: small default-off exposure PR (R2),
   then deep surface `{2,4,6,8}` — hypothesis: 2-4wk confirm catches the
   JNS-style Feb-2001 hedges the 8wk version misses.
5. **audit_bars remediation** (new decision input): first warehouse scan =
   3,797 spike-revert hits / 81 symbols. Choose: clean at warehouse build vs
   arm liquidity overlay for honest runs vs both. Cheap first step: eyeball
   the 81-symbol list for concentration in delisted sub-$5 names.

## Decision items (human)

1. ~~check_limits~~ DONE — deleted (#1902, user mandate 2026-07-09).
2. `Portfolio_floor` monotonic-peak semantics — **ablation run 2026-07-09**
   (`dev/backtest/floor-off-exp-2026-07-09/FINDINGS.md`): on the GME window,
   floor-OFF dominates every risk-adjusted metric (return 1013.8→2223.3%,
   Sharpe .538→.610, Ulcer 33.9→23.6; only raw MaxDD "wins" for the floor and
   that win is hollow — the floor's own bottom-tick liquidation is most of
   its measured DD). No tested config shows a beneficial portfolio-floor
   fire. Options in the FINDINGS: (1) port P1b windowed-peak semantics to the
   engine floor (recommended), (2) default the trigger off (wants more than
   one window per R3), (3) status quo. User call.
3. `neutral_blocks_shorts` faithfulness flip: deep cost RE-ATTRIBUTED
   (2026-07-09 event-level decomposition) — the gate blocked exactly ONE
   Neutral-tape short in 11 deep years (CF 2006, a loser; blocking helped);
   the −8.6pp arm delta is post-divergence path noise, true edge cost ≈ 0.
   Flip is cheap on faithfulness + squeeze-asymmetry grounds; realized
   benefit also tiny. Mandate call, analysis complete both ways.

## Bugs / small follow-ups — status after the 2026-07-09 day session

- ~~Short leak~~ **FIXED + merged (#1906).** Root cause was a round-trip
  pairing MISLABEL, not a flag bypass: `_filter_steps` truncated warmup steps
  before `Metrics.extract_round_trips`, so a warmup-opened long's orphaned
  in-window Sell read as a short-open (inverted P&L, pairing offset cascades
  for that symbol). Fix: `Runner.round_trips_in_window` (warmup-inclusive
  extraction, entry-date filter), pinned synthetically. **Consequence for
  analysis:** all PRE-#1906 trades.csv outputs contain spurious SHORT rows
  for warmup-straddling symbols (the faithful-short screen's per-arm short
  tallies included ~1 such artifact each — LH; portfolio-path conclusions
  unaffected, equity curves don't depend on labels). Re-runs shift
  total_trades/win_rate slightly — watch the tight-golden postsubmits; if
  they trip, re-pin is mechanical and expected.
- ~~MSZ-class corrupt bars~~ **audit tool BUILT + merged (#1900)**:
  `audit_bars.exe <warehouse-dir>` — first scan of the deep warehouse found
  **3,797 spike-revert hits across 81 symbols** (of 2,999). NEXT: decide
  remediation (drop/patch flagged bars at warehouse build vs arm the
  liquidity overlay for honest runs) — the hit list is bigger than MSZ.
- ~~check_limits~~ **DELETED + merged (#1902)** (user mandate; zero callers
  re-verified; config fields preserved for scenario compat).
- `write_ledger_entry.exe` doesn't regen `index.sexp` (carried).
- `feature_screen` constant-feature failwith nit (carried).
- goldens-small still at 0.14 concentration override (carried, intentional).
- **Harness:** periodic `cleanup-merged` job reaps agent worktrees whose
  branch isn't on origin after 1h — wiped two working agents this session.
  Standing dispatch rule added (WIP push within 30 min); structural fix =
  make the job honor `git worktree lock` (candidate harness-maintainer item).

## Standing constraints (unchanged)

Entry-selection CLOSED (powered null); scale-in / reallocation / envelope /
stop-tuning closed. Weinstein spine fixed. Open frontier: **floor quality
(fast circuit breaker + hedge-shaped shorts) → then blending; capacity/breadth
economics.** Comparators TOTAL-RETURN always. All pre-2026-07-08 absolute
numbers are 210-basis — re-measure before citing.
