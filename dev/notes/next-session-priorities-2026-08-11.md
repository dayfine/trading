# Next-session priorities — 2026-08-11

**Supersedes** `next-session-priorities-2026-08-09.md` (its P0 — execute the
entry-ticket-async-v2 plan — completed this session: all four mechanisms,
audit fields, and the 24-cell ladder-v4 spec set are merged).

## State at handoff

**Ladder v4 is RUNNING** and must not be disturbed. Pinned worktree
`.claude/worktrees/sweep-ladder-v4` at HEAD `4ecbe1154`, 24 cells, parallel=1
(forced — the worker peaks 7.28GB in a 7.94GB container). ~1h45m/cell,
~43h total, finishing ~midday 2026-08-12.

**HOW TO PICK IT UP NEXT SESSION** (the hourly monitor is session-scoped and
dies with the session; the run itself does not):

```sh
# is it still going?
docker exec trading-1-dev ps -eo etime,cmd | grep '[s]cenario_runner.exe --dir /tmp/sweeps/ladder-v4'
# finished? (exit sentinel)
docker exec trading-1-dev grep '^exit=' /tmp/sweeps/ladder-v4.log
# how many cells are done?
find .claude/worktrees/sweep-ladder-v4/trading/dev/backtest/scenarios-2026-08-11-052209 \
  -maxdepth 2 -name actual.sexp | wc -l      # want 24
```
Re-arm an hourly monitor if you want one. The host disk watchdog is also
session-launched — re-arm it too, or just check `df -h /` occasionally (disk
recovered to 58G+, so this is low risk now).

- Log: `docker exec trading-1-dev tail -f /tmp/sweeps/ladder-v4.log`
- Output: `<worktree>/trading/dev/backtest/scenarios-2026-08-11-052209/`
  **COPY OUT BEFORE REMOVING THE WORKTREE.**
- A host watchdog SIGTERMs the runner below 20G disk. Disk recovered to 58G+
  mid-run, so this is no longer a live risk.
- 16 PRs merged this session (#2257-#2275, excluding others' #2259/#2268).

## The results so far are more interesting than the plan expected

Stage A (one-axis deltas off cell 00) — cell-to-cell valid, but **NOT
comparable to v3's +318%** (see P0 below):

| cell | ret | trades | sharpe | maxDD | note |
|---|---|---|---|---|---|
| 00 core-w4 | 343.9 | 1136 | 0.457 | 44.3 | reference |
| 01 anchor-w8 | 456.6 | 1105 | 0.512 | 31.6 | |
| 02 fresh-rangetop (F1) | 302.7 | 1134 | 0.460 | 32.5 | |
| 03 ttl4 (F2) | 278.2 | 1093 | 0.441 | 42.9 | |
| 04 ttl8 (F2) | 207.3 | 1112 | 0.386 | 43.9 | |
| 05 maxstop25 | 402.3 | 1291 | 0.506 | 30.6 | |
| 06 maxstop35 | 399.0 | 1381 | 0.495 | 27.9 | DIAGNOSTIC |
| 07 maxstop50 | 726.2 | 1442 | 0.612 | 34.7 | DIAGNOSTIC — not promotable |
| 08 sizedown50 | 448.1 | 1463 | 0.390 | 42.5 | DIAGNOSTIC |
| **09 nearfloor** | **670.0** | **967** | **0.582** | **27.0** | **FAITHFUL, best risk** |
| 10 volconf (F5) | **-47.6** | 3145 | **-0.196** | 68.5 | catastrophic |

### Four findings that should shape the next session

1. **CELL 09 (nearest-floor) IS THE RESULT.** 92% of the unfaithful 50%-gate's
   return, the best drawdown in the run (27.0), 475 FEWER trades, and it stays
   inside the book's 15% gate. Mechanism verified: `stop_floor_kind` flips from
   867 Buffer_fallback / 558 Support_floor (baseline) to 108 / 1158 — i.e. with
   `Window_extreme` most candidates couldn't find a qualifying floor and fell
   back to an arbitrary buffer; `Nearest` finds a real structural low. Mean stop
   distance ROSE (0.052 -> 0.120), still under 15%. **This is the first lever in
   the whole program that improves results without widening admission** — it is
   stop-PLACEMENT quality, not breadth. Prime promotion candidate; run it
   through `experiment-gap-closing` -> WF-CV -> the confirmation grid.

2. **CAPITAL, NOT ADMISSION, IS THE BINDING CONSTRAINT.** F1 armed pushes
   +1,181 more candidates into the entry walk (skip reasons: Insufficient_cash
   11,633 -> 13,852; Stop_too_wide 8,854 -> 7,811) yet final trades move by 2.
   The surplus is absorbed by cash. This reframes prediction 3's failure: F1
   changed admissions a lot and fills not at all. It also predicts Stage B's
   twelve `rt-` cells will show little, since they all arm F1.

3. **F5 IS A REJECT, but narrower than it looks.** Armed volconf: 3145 trades
   (3x baseline), 2011/2239 fills Unconfirmed, 1784 ejected, avg holding
   47.8d -> 8.4d, return -47.6%, Sharpe -0.196. The mechanism is FAITHFULLY
   IMPLEMENTED (both §4.2 branches computed per fill; the #2270 verdict/outcome
   split shows 2011 Unconfirmed != 1784 Ejected). The defect is the PLACEMENT
   WAIVER: the book says volume is judged AT the breakout, not that you stop
   screening volume. Dropping the screen-time gate with no substitute admits
   junk. **A variant keeping the screen-time gate AND adding fill confirmation
   was never tested and is the only part worth reviving.**

4. **THE MONSTERS ARE REACHABLE ONLY UNFAITHFULLY.** At the 50% gate SKYW
   2023-03-31 is captured (+240%, $628k). At 25% SKYW is DISPLACED OUT. AXTI at
   25% was admitted and LOST (-15% in 3 days — a 2020 entry, NOT the record's
   2025 crash-recovery monster). Capture requires a 50% structural stop, which
   §5.1 (>15% -> prefer other candidates) and §5.3 (trader 4-6%) both reject.
   **The gate costs you the monsters and no book-faithful width recovers them.**
   This sharpens plan §1's "elephant" rather than refuting it. Caveat: the 50%
   cell is fragile — top 5 trades = 43.4% of PnL, and two of the five biggest
   winners are NARROW-stop trades, i.e. not mechanism-driven.

Two of four pre-registered predictions are falsified (3: freshness > TTL — it is
backwards ~20x; 4: volconf costs little — it costs -391pp).

## P0 — the armed-baseline regression (task #17)

**Ladder-v4 cell 00 does not reproduce ladder-v3 faithful-w4**, though the spec
is semantically identical (all 7 added overrides equal declared defaults;
`max_stop_distance_pct = 0.15` verified at `stop_types.ml:67`) and the warehouse
is byte-identical (`schema_hash 060588c0224b7d7e73f367fbd1801084` in both logs).

| | v3 w4 (a19938a8b) | v4 cell 00 (4ecbe1154) |
|---|---|---|
| return | 317.80 | 343.90 |
| trades | 1143 | 1136 |
| maxDD | 36.49 | 44.28 |
| force_liquidations | 1 | 4 |

So one of five behaviour-touching PRs changed armed-StopLimit behaviour:
#2258 (7dbdf9646), #2261 (2f6f07892), #2263 (e3087812c), #2267 (f806fab14),
#2270 (a03f2a4e4).

**Why nothing caught it:** R1 bit-identity was verified by unit tests plus
default-config goldens, but plan §3 scopes F2/F3/F5/F6 to activate ONLY when the
StopLimit family is armed — and **zero of the 10 golden specs arm that family**.
The guarantee was only ever tested where these mechanisms are inert by
construction. Structural hole, not a slip.

**Do NOT bisect on the 26y top-3000 config** (1h46m/probe). Build a SHORT
armed-StopLimit repro (5y, small universe) that reproduces the delta in minutes,
then bisect. Then add a StopLimit-ARMED golden — that is the durable fix.

Consequence for v4: internal cell-to-cell deltas remain valid (one HEAD, one
warehouse). The "+318% faithful w4" comparator printed in every v4 spec header
is NOT comparable and the writeup must say so.

## P1 — the capital-constraint / scoring question (user, 2026-08-11)

User's proposal: raise the screening score threshold and improve scoring using
resistance / prior tops.

**Careful — most of this is already closed:** `project_entry_selection_closed_powered`
(162k tickets, return R2=0.0034, a POWERED null), `project_cascade_selection_inversion`
(cascade score is anti-predictive), `project_accuracy_is_unreachable_diversify_instead`.
Resistance is already in the cascade (resistance-v2 promoted default-on, #2047).
Do not re-run "better ranking" as if it were open.

**What IS live, and is new from tonight:** those nulls concern picking better
winners among admitted candidates. Tonight shows the funded set is decided at a
CASH BOUNDARY with 13,852 rejections, and the tiebreak there is alphabetical
(`project_screener_alphabetical_tiebreak`: "bites at cash boundary; ranked mode
default-off"). So the open question is **not** "can we score better" but "is the
funded set arbitrary among equals at the cash boundary, and does de-arbitrarying
it help?" That is a capacity/ordering question and it dodges the selection null.

The threshold half fits the same frame: raising it changes HOW MANY compete for
scarce capital, which is a concentration knob — the surface
`project_capacity_concentration_surface` left open with no promotable value.

Frame any experiment here as ordering/capacity, not selection accuracy.

### The concrete experiment (task #20) — and why the null does not cover it

Checked the provenance of R2=0.0034: it was computed on a **counterfactual
ticket study**, not on any backtest's realized trades. 884,083 raw Stage1->2
firings -> 162,632 deduped grade-F tickets, 26y x top-3000, **each ridden
through counterfactual exits at a fixed $10k**. Equal size for every eligible
ticket means the design contained NO capital constraint, NO sizing and NO
crowding-out — so it could not have measured funding order. It answered
"do features predict magnitude among all eligible tickets?" (no, with power).
It did not answer "when capital is scarce, does ORDER matter?"

The audit already records both populations per cell: funded trades AND the
13,852 `reason_skipped Insufficient_cash` candidates. So:

> Ride the cash-rejected candidates counterfactually (tooling exists:
> all-eligible feature capture #1878 + `feature_screen` exe #1880) and compare
> against what was actually funded.

- rejected >= funded  => the alphabetical tiebreak is leaving money on the
  table; ordering is a real lever, and it dodges the selection null entirely
  because it is not about ranking SKILL, it is about not choosing ARBITRARILY.
- rejected == funded  => the boundary is genuinely arbitrary; only the
  concentration knob remains (`project_capacity_concentration_surface`).

Rigor caveat: rejected candidates have no realized outcome, so this inherits
the 07-08 study's estimand gap (counterfactual rides != realized P&L under
stops and real sizing). It is a SCREEN — calibrate the verdict as one, report
distributions not point estimates, and note the selection bias (the rejected
set is conditioned on arriving when cash was already committed, which
correlates with regime).

## Task list carried forward (18 open)

Highest value first:

- **#17 P0** armed-baseline regression + missing StopLimit-armed golden (above).
- **#19** No integration coverage: every mechanism goes unit-test -> 43h ladder.
  F5 is the proof — its unit tests were correct and comprehensive, and could not
  catch a 3x candidate explosion. Proposed: per-mechanism smoke scenarios (tiny
  synthetic universe, seconds to run) asserting trade-level outcomes AND sanity
  bounds (armed trade count within ~2x baseline; holding period not collapsing;
  return not sign-flipping). Any of those trips instantly on F5.
- **#4** Join audit to trades by position_id — fill-side ticket age is capped at
  ~1 week (`_audit_lookup_window_days = 7`), so "how long did tickets rest" is
  unmeasurable. Do NOT just widen the window: F2's cancel+re-place means one
  symbol has several placements, and a wide date window would silently attribute
  a fill to the wrong one. The key exists (`position_id`) and the file already
  joins stop info by it.
- **#18** `stop_initial_distance_pct` empty on ~56% of trades.csv rows including
  stop_loss exits. Data IS recoverable from `trade_audit.sexp`. Until fixed,
  exclude empties explicitly — do not let awk coerce "" -> 0.
- **#12** Ladder-v4 uses N=24 (all composed cells pre-registered), so the
  Deflated-Sharpe best-of-N correction must use 24, not 13.
- **#13** docker-exec dune wedge -> wrapper script. Recurred 3x in one session,
  including by me in the v4 launch script AFTER updating the memory about it.
  Prose does not prevent it; a `dev/scripts/docker_dune.sh` that always runs
  detached with a sentinel does.
- **#14** base-extent anchor: build for v5 or amend the plan. Cell 01 (anchor-w8
  beating w4 on every axis) is evidence FOR building it. Cheaper first step: the
  blind-judge harness emits `trigger_level`, so comparing judge placements
  against our 4w/8w anchors measures whether short windows approximate the
  book's "top of the CURRENT trading range".
- **#8** Blind-judge first run — harness merged (#2269), skill available,
  unblocked. Cohort: AXTI/SKYW/BPT + mandatory controls, shuffled. I must not be
  the judge (contaminated). Measure judge-vs-judge self-consistency BEFORE any
  code-vs-judge number.
- **#9** P1 trim PRs: 18 flags with terminal ledger REJECTs, worklist in
  `dev/notes/mechanism-flag-inventory-2026-08-09.md`. This is what shrinks
  `weinstein_strategy_config.mli` from ~1,450 lines.
- **#15** Nothing checks the orchestrator's agents opened their PRs (a GHA
  cleanup agent's work sat orphaned 9h on 08-10; recovered as #2273).
- **#16** Agents end turns waiting on monitors instead of finishing (~5x).
- **#10** Adjusted-basis: understated harm (phantom supply, not just dropped
  supply), third unpinned formula copy at `floor_stop.ml:94`, and B2's
  whole-window fallback option never evaluated.
- **#11** magic-numbers linter: conf entry overstates itself by one clause
  (`file_discovery.ml` file-avg 2.87 > 2.5 IS newly silenced); `File_discovery`
  unpinned.
- **#6** Docker recompact — no longer urgent, disk recovered to 58G.

## When v4 finishes

1. Copy artifacts out of the pinned worktree BEFORE removing it.
2. Read plan §5's four predictions before looking at returns. Two are already
   falsified; check 1 (fills drop, composition shifts) and 2 (conditional tail
   participation) properly.
3. Honour the stop rule: if fills don't drop or composition doesn't shift, the
   mis-mapping model is wrong — stop and re-dissect, do NOT knob-search.
4. **Dissect trades before reporting anything** — see
   `feedback_always_dissect_before_reporting`. Top-line deltas mislead: I
   reported "the gate exclusion was costly" from `actual.sexp` and dissection
   showed AXTI admitted-and-lost, SKYW/BPT displaced, gains from unrelated
   names, and a cohort column empty on 56% of rows.
5. Expect cell 16 (the "fully faithful" flagship) to fail — it contains volconf,
   which alone is -47.6%. Cell 15 (`rt-ttl4-nearfloor`) is the informative
   volconf-free faithful arm.
6. Scale economically before calling anything good: even the best cell is
   ~8.3%/yr over 26.5y, roughly SPY-like, and 43% of its PnL is 5 trades.
