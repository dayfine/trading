# Next-session priorities — 2026-07-10

**Supersedes** `next-session-priorities-2026-07-09.md`. Everything it queued is
DONE. Main green; origin has exactly one branch (main); 0 open PRs; open
issues triaged 2026-07-10.

## What the 07-09→10 sessions shipped (day 2 of the arc, ~20 PRs total)

1. **Both user-mandated default flips merged**: `neutral_blocks_shorts` → true
   (#1909; bit-inert 2010-2026, one blocked HD Q4-2018 loser in the six-year
   window — test now pins the default) and **portfolio-floor trigger → off**
   (#1910; ablation-backed, mechanism retained behind explicit config,
   silent-revert pin test; GME golden re-pinned floor-off 2223.3%).
2. **P1b steps 1+2 merged**: `Index_circuit_breaker` pure lib (#1904) +
   `Breaker_spy_strategy` sleeve consumer (#1913; default-off variant,
   stay-out safety property pinned, no-reversal-timing framing in the .mli).
   **NEXT = step 3: lens screen vs TR-SPY** (per-episode table
   2000-02/2008/2011/2015-16/2018Q4/2020/2022, interventions count, whipsaw
   distribution; the sleeve runs via `Strategy_choice.Breaker_spy_sleeve`).
3. **Honest-tradeable record run** (#1912, DEEP_RESULTS ⭐): realized ≈+1600%
   (~11.4%/yr) vs TR-SPY 8.15%/yr — first realized-beats-index deep path.
   **Fold-proof (#1919) inverted the bundle story**: hold-degradation exit
   ALONE dominates baseline (Sharpe .654→.753, Calmar .917→1.131, DD −5.6pp,
   DSR .9999, 8/13 — strongest fold candidate the program has produced);
   entry gate alone costs Sharpe/Calmar (estimand caveat: simulator credits
   fake profit); bundle < hold-only; gate FAIL on the strict worst-fold rule
   (fold-008 2016-18 low-ADV monster). ⭐ row = realism measurement
   convention, not an alpha claim.
4. **Standing methodology LAW (3 confirmations: armon, catstop, overlay):
   single compounded paths flatter exit/overlay mechanisms — only fold
   distributions decide.** Decompose per-year/per-fold before any verdict.
5. **corrupt-bar tooling + LH mislabel fix + check_limits deletion + flaky
   orphan-sweep fix (#1900/#1906/#1902/#1921, issue #1884 closed)**; branch
   cleanup (78 remote branches removed; 5 orphaned budget records batch-landed
   #1917); stale ci-red watchdog #1896 closed.

## Scoped queue for upcoming sessions (user-agreed 2026-07-10 PM, priority order)

**In flight, must land first:**
- **4y-fold sensitivity** of the overlay decomposition (running; answers the
  fold-horizon-bias question — does hold-exit's 8/13 dominance shrink at 4y?).
  On landing: amend ledger `2026-07-10-liquidity-overlay-wfcv` with the read.
- **Realism-defaults flip PR** (`feat/realism-defaults-flip`, agent holding):
  entry-gate 1e6 + stale-exit 5d default-on, golden re-pins, ledger basis
  entry. Gates + merge. min_hold stays default-off.

**S1 — AXTI exit verification (extended window).** Rebuild the deep warehouse
to 2026-06-26 (bars already in `data/`; ~31 min — ONLY after the flip agent is
done with the current warehouse), re-run the honest-tradeable scenario with
`end_date 2026-06-26`, and observe the actual exit: trailing stop (~$90-100 if
the stop advanced past the mid-May pullback) vs still-holding at $70. Also
refresh the SPY-TR comparator to the same end. Context: AXTI peaked $140.83
(May 22 weekly close, 3.45× the 30w MA), fell to $70.15 by Jun 26 with the 30w
MA still RISING (+3.7%/wk) — the whole collapse is inside Stage 2, so only the
stop can exit; stage channels are structurally silent
(`scratchpad/axti_stage.png` rendered; close/MA table in session log).

**S2 — extension-episode event-level screen (read-only, rigor-calibrated).**
Enumerate every held-position episode across the deep runs where weekly
close/30wMA ≥ ~2.5-3× (GME, DDD/BFX 2020-21 cohort, AXTI, …). Per event,
simulate simple high-trail exits (10/15/20/25%) vs the actual hold — PAIRED,
distributions not means, per `mechanism-validation-rigor`. Key trap already
identified on AXTI: a 15% trail exits the April-28 shakeout at ~$70 (missing
96→141); 20% survives April by 2.7pts — shakeouts and the top are the same
depth, so single-specimen thresholds are hindsight. The screen decides whether
an `extension_stop` axis (close/MA-triggered high-trail; W2 authority =
Weinstein's overextension warning, a trader dial) is worth building
default-off + WF-CV. Feeds S3.

**S3 — trader-preset BUNDLE test** (per `weinstein-faithful-core` W3: presets
as wholes, never dial-grafts): audit the preset table
(`dev/plans/weinstein-trader-investor-presets-2026-05-31.md`) for which dials
are config today vs need default-off exposure (10-week MA, full-size entries,
exit-as-Stage-3-forms / extension-sensitive exits); build the missing dials;
deep WF-CV of the trader bundle vs investor baseline; AXTI as the qualitative
specimen (does the trader preset exit $110-125?).

**S4 — hold-exit promotion pipeline** (strongest fold candidate, #1919):
fold-008 realizability autopsy (re-run the 2016-17 baseline window with trade
output; was the low-ADV monster's +69.7% tradeable at size?) → neighbor
surface `min_hold_dollar_adv {2.5e5, 5e5, 1e6}` → rolling-start matrix as the
tail-honest arbiter (folds truncate the tail; paths flatter it — the matrix
keeps full horizon with start dispersion).

**S5 — P1b step 3: sleeve lens screen vs TR-SPY** (sleeve merged #1913): full
window + per-crash-episode table (2000-02/2008/2011/2015-16/2018Q4/2020/2022),
interventions count, whipsaw distribution. Bar: match TR-SPY, cut left tail;
if it loses honestly, the answer is hold-through (no reversal timing).

**S6 (carried) — grind-weeks exposure PR**: `weeks_below_ma_slow_grind` as
strategy config (default 8 = no-op), deep surface {2,4,6,8}.

Container discipline for all of the above: long runs get a SOLO container;
one builder agent at a time; every dispatch requires WIP-push within 30 min.

## Open issues (triaged 2026-07-10)

- #1782 screener ranking (build default-off ranked mode + WF-CV; framed).
- #1729 survivor-subset goldens — pins now warehouse-measured (364 re-pin);
  provisioning half open (commented).
- #1672 window migration 2000→1998 (carried).
- #1572 orchestrator orphans budget records — backlog cleaned via #1917
  (commented); root fix = bundle budget into the daily PR (harness-maintainer).
- #1563 short-proceeds collateral (enhancement, carried).
- #1557 zombie-fix follow-ups: 1 agent-ready (fold_health wiring) + 2 human
  decision items (CancelExit core transition; cash-floor exemption for
  closing trades).

## Ops lessons this run (recorded in memory)

- cleanup-merged reaper wipes agent worktrees with no origin branch after 1h
  → every dispatch brief now requires WIP push within 30 min (hit 4 agents).
- Long WF runs get a SOLO container (v1 of the overlay WF-CV died
  artifact-less to concurrent agent builds; runner writes only at end).
- A stale watcher whose command line matches your pgrep will shadow "is it
  still running" checks — match on the exe path, not the name.

## Standing constraints (unchanged)

Entry-selection CLOSED; scale-in / reallocation / envelope / stop-tuning
closed; NO reversal timing (user 07-09); Weinstein spine fixed. Open
frontier: floor quality (sleeve lens screen) + hold-exit promotion +
capacity/breadth economics. Comparators TOTAL-RETURN always; pre-07-08
absolute numbers are 210-basis.
