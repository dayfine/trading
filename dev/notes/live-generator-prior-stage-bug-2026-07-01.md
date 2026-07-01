# Live weekly-snapshot generator resets `weeks_advancing` — a stage-classification defect

**Severity:** high — it changes *which stocks* the live weekly screener picks, not
just their grade. **Scope:** live snapshot generator only; backtests are unaffected
(they already chain the stage classifier). Found 2026-07-01 while auditing why every
2026 weekly pick scores exactly 70.

## The defect

`Weekly_snapshot_generator._analyze_ticker` (`weekly_snapshot_generator.ml:63`)
analyses each ticker with a **single** `Stock_analysis.analyze` call passing
**`~prior_stage:None`**. The stage classifier uses `prior_stage` to *carry the
running count of how long a stock has been in its current stage*. With `None`, it
cannot know the history, so it **resets `weeks_advancing` to ~1 for every Stage-2
stock** — the generator believes every advancer just broke out this week.

### Evidence (2026-05-29 picks, proper chained vs the live single-call)

| stock | chained classification (= backtest) | live single-call `prior=None` |
|---|---|---|
| AIP  | Stage2 **w44** | Stage2 **w1** |
| ATRO | Stage2 **w45** | Stage2 **w1** |
| AAON | Stage2 **w5**  | (labelled Early Stage2) |

Under correct (prior-chained) classification the 20 picks of 2026-05-29 span
**w1 → w45**. The live generator labelled **all 20** "Early Stage2". Verified with a
`stage_dump` diagnostic that reuses `weinstein.stage`'s rolling classifier (the same
one the backtest drives via `weinstein_trading_state.prior_stages`).

## Why it matters — two consequences

**1. Grade collapse.** `Screener_scoring._stage_long_signal`:
`Stage2, weeks_advancing ≤ 4 → 15` ("Early Stage2"); `> 4 → 0`. With the reset,
every advancer gets 15 → and with the other maxed signals lands at exactly 70 =
grade A. Correctly classified, only genuinely-early names keep the 15; the ~13/20
extended names lose it (→ 55 = grade B). The flat "20× A/70" is an artifact.

**2. Admission pollution (the real problem).** The candidate gate itself,
`Stock_analysis._initial_breakout_arm`, is `Stage2 {weeks_advancing} →
weeks_advancing ≤ 4`. With the reset (all w1) **every** Stage-2 stock passes.
Correctly classified, the w5–w45 names **fail the gate** — they should never be
candidates. So the live weekly list is padded with **extended advancers** (AIP ~44
weeks, ATRO ~45 weeks into Stage 2 ≈ 11 months, arguably near Stage-3 topping risk)
that the strategy's *own rule* excludes. Of the 20 picks, ~13 shouldn't be there.

The live picks are therefore **not** "20 fresh breakouts that happen to tie" — they
are a few genuinely-early names buried in a pile of extended movers, all flattened
to look identical because `weeks_advancing` is stuck at 1.

## The fix

Chain the stage classification in the generator, exactly as the backtest does. The
generator already holds the full weekly bar history per ticker; it just needs to
roll `Stage.classify` over the prefix (threading `prior_stage`) and feed the correct
prior stage — with its accumulated count — into the `as_of` `analyze` call, instead
of `None`. `Stage.classify` is cheap, so the extra pass is cheap.

Properties:
- **Backtests unaffected** — they already chain via `trading_state`. This is purely
  a live-generator fidelity fix.
- **Independent** of the coarse-bucket / continuous-RS scoring discussion (that is
  about resolution *within* a legitimate tie; this is about the tie being fake).
- Highest-value of the live-picks threads (vs #1782 display order, vs continuous-RS
  scoring): it changes the *candidate set*, not just presentation.

## Verification — IMPLEMENTED + CONFIRMED (2026-07-01)

Fix implemented in `_analyze_ticker` (`_chained_prior_stage` rolls `Stage.classify`
over the weekly prefix and feeds the chained prior into `analyze`). Re-ran
`generate_weekly_snapshot` on the 50 pick symbols at `--as-of 2026-05-29`, before vs
after (reduced data — no index/sector bars, so scores are lower, but the
`weeks_advancing` / admission effect is exact):

| | BEFORE (prior=None) | AFTER (chained) |
|---|---|---|
| candidates admitted | **22** | **10** |
| labelling | all "Early Stage2" | genuinely-early only |

**15 names dropped** — all extended advancers the `≤4-week` gate should reject, with
their *true* (chained) `weeks_advancing` at 05-29:
`AIP w44, ATRO w45, AESI w18, AGYS w18, ATOM w14, BAND w12, AXTA w10, BLBD w9,
AOSL w7, AUDC w7` + the w5 edge cases `AAON ACMR ATKR BB BLDP`. Survivors were the
w≤4 breakouts (ADUR AEVA AGPU ALMU AMBA APPS BLZE BOOM CCSI CLFD). The corrected
`weeks_advancing` matches the `stage_dump` chained reference exactly — the fix is not
a blanket over-count, it's correct.

### Two follow-on findings the fix surfaces

1. **2 generator tests encoded the buggy behavior.**
   `test_weekly_snapshot_generator`'s "breakout AAPL is a long candidate" (+1 more)
   expect AAPL admitted, but their synthetic breakout sits **5–8 weeks** before
   `as_of` (inside the 8-week breakout-event window). Under `prior=None` that reset
   to w1 and passed; under correct chaining it's `weeks_advancing > 4` and the `≤4`
   gate rejects it. The tests must be updated — ideally by making the synthetic
   breakout genuinely recent (≤4 weeks pre-`as_of`) so they assert the *correct*
   fresh-breakout path.

2. **A real tuning tension: `≤4` early-gate vs the 8-week breakout-event window.**
   The breakout-event lookback is 8 weeks, but `_initial_breakout_arm` admits
   `weeks_advancing ≤ 4`. While the classifier was broken, this never mattered (all
   reset to w1). Now that it works, breakouts 5–8 weeks old are inside the event
   window but rejected by the early gate. Whether `≤4` is the right threshold — or
   should align with the 8-week window — is a **separate tuning decision** the fix
   exposes but does not resolve. The fix makes the *configured* gate actually bite;
   the *value* of the gate is now a live question.

## Status — FIXED + MERGED (#1818, main `4662e768b`)

Landed via option 1 (correctness fix). `_chained_prior_stage` in
`weekly_snapshot_generator.ml` supplies the chained prior the classifier already
expects. The 2 tests that encoded the buggy `prior=None` behavior were re-anchored
(`as_of` 2022-10-07 → 2022-09-16; a w6 stale breakout is now correctly rejected) and a
`test_stale_breakout_not_admitted` regression pins the corrected behavior.
qc-structural + qc-behavioral both APPROVED (5/5) — a **faithfulness improvement**, not
a spine change; **backtest parity confirmed** (the backtest chains via `trading_state`
and never calls this generator → no golden re-pin).

**OPEN follow-up (deferred, separate decision):** now that the `≤4`-week admission gate
actually bites, is `≤4` the right threshold vs the 8-week breakout-event window?
(Item 2 above.)

Diagnostic tool: `analysis/scripts/stage_dump/` (reuses `weinstein.stage` rolling
classification; the same one the backtest drives). Committed as a reusable
stage-timeline inspector.
