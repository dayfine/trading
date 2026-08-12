# Ladder v3 — faithful-StopLimit arms: results + dissection (2026-08-09)

Executes step 4 of `dev/plans/entry-ticket-right-basis-2026-08-08.md`. Three
arms composing ONLY existing default-off flags (no new mechanism code):
`enable_sim_entry_stoplimit` + `sim_entry_trigger_at_suggested` +
`entry_anchor_local_range_weeks {4,8,13}` + `freeze_entry_at_first_breakout`
(#2241) + `sim_entry_fill_next_open` (#2238), stop = support floor
(`stop_anchor_at_entry_base` OFF → the 15% `max_stop_distance_pct` gate acts
as the book §5.1 "prefer other candidates" candidate FILTER). Run: pinned
worktree `a19938a8b` (post-#2254, so `trade_audit.sexp` carries the new
E-provenance fields), v5thin_adj warehouse, top-3000 PIT-2000, 2000-01-01 →
2026-06-26. w8 arm killed mid-run by user decision (no marginal information —
w4/w13 bracket it). Artifacts: `.sweep-output/ladder-v3-artifacts/`
(trades.csv + trade_audit.sexp + equity per arm, + `faith-nextopen-vs-w13.md`);
scenario sexps to be committed with ladder v4 (PR-6 of the async-v2 plan).

## Results

| Arm | Return | Sharpe | MaxDD | Trades | Win% |
|---|---:|---:|---:|---:|---:|
| record-nextopen (v2 comparator) | +7,321% | — | 39.1% | 1,121 | 34.6% |
| book-honest (v2 comparator) | +310% | 0.49 | 28.2% | 1,152 | 33.2% |
| **faithful-w4** | **+318%** | 0.46 | 36.5% | 1,143 | 33.7% |
| **faithful-w13** | **+262%** | 0.42 | 31.6% | 1,139 | 33.4% |
| localtop26, no fixes (08-06 ladder) | +474% | 0.57 | 39.3% | — | — |

The faithful family lands in the same few-hundred-% band regardless of anchor
window — ~23× below the record. Window length is NOT the binding constraint.

## The mechanism (trade-dissection, verified at trade level)

**The gap is structural exclusion of crash-recovery monsters, not per-trade
slippage.** Top divergent symbols are ≈ $0 in the faithful arms:

- **AXTI** (+$56.2M in record = 76% of it): screened 36× in w13, skipped every
  time — 28× `Stop_too_wide`, 8× `Insufficient_cash` — including
  **2025-06-27, the exact Friday the record entered**. Geometry that day:
  close 2.03, 30-wk MA ≈ 1.80, 13-wk local top 2.70 → ticket trigger 2.71
  (limit 2.77), support floor 1.728 (June pullback low 1.81 × 0.95 buffer).
  Record measures the 15% gate off the close: (2.03−1.728)/2.03 = **14.9%,
  passes by 0.1pp**, fills next open 2.05, rides 334 days to 115.45. Faithful
  ticket measures off the trigger: (2.71−1.728)/2.71 = **36.2% → dropped**.
  w4 identical (22× Stop_too_wide) — the 4-wk and 13-wk tops coincide at 2.70.
- **SKYW 2023-03-17** (+$3.22M record: 17.88 → 73.76, 502d) — `Stop_too_wide`
  in w13 on that exact Friday. Only w13 SKYW trade ever: a calm 2013 base
  (top≈close, floor 13.4% → passes). Calm bases admit; recovery bases don't.
- **BPT 2022-01-21** (+$1.90M record) — `Stop_too_wide` that exact Friday and
  again 2022-02-11.

**Why the crossing week didn't save AXTI:** by the actual 2.71 cross (week of
2025-08-26) AXTI was ~10 weeks past its MA cross → `early_stage2_max_weeks ≤ 4`
had already aged it out of admission — **no candidate, no ticket, nothing to
fill**. Book semantics: Stage 2 *begins at the breakout above the range top*;
our classifier starts the clock at the MA cross, so a stock basing below its
range top ages out before its book-Stage-2 week one. (It reappears Oct-Nov via
virgin re-admission at 6–11 → skipped again: cash / 55%+ floor distance.)

**Adverse selection, not selectivity:** trade counts are nearly identical
(1,139 vs 1,121) — the entry walk *backfills* dropped wide-range names with
calm-base names from the ranked list. The filter changes composition, not
count, and range width correlates with explosiveness → it anti-selects the
fat tail. 9,520 `Stop_too_wide` skips run-wide (a first-order admission gate
under E-anchoring; marginal under close-basis entry).

**YoY shape:** record's fat years collapse (2020 +5.37M→+0.79M, 2023
+3.44M→+0.10M, 2025 +57.1M→+0.07M); faithful wins only where record loses
(2015/2018/2024/2026). Whipsaw 53–55% in shock years (2000, 2020): resting
tickets fill on spikes into tight stops (63% of stops are `Buffer_fallback`,
mean fill-basis distance 8.6%).

## Code sanity (the #2254 E-provenance fields, first real use)

- E = `local_range_top` × 1.005 in 94% of 1,444 w13 entries (rest = frozen-E,
  Fix #2 working); E > close in 97% — designed geometry holds.
- Execution faithfulness: 518/524 `faithful=true`, all fills within band.
- Caveats found: `ma_value` is adjusted-basis vs raw close/E (pre-existing
  basis mismatch, now visible — do not compute close-vs-MA naively); FARM
  2004 duplicate rows with an 879% `stop_fill_distance_pct` outlier
  (split/corrupt-bar class, 4–5 rows); the fill-basis column populates only
  for matched round-trips (525/1,139).

**Verdict: results are real; the code does exactly what was designed. The
underperformance is structural.**

## The why, and where it leads

11th re-derivation of `project_edge_is_the_fat_tail`, new angle: **Weinstein's
own 15% risk rule, applied honestly to a breakout-anchored ticket, excludes
crash-recovery monsters** — their defining features (wide current range +
structural floor at the crash low) sum to >15% for exactly the explosive
names. The record buys them only by measuring the same rule off the in-range
close (a non-book entry).

The 2026-08-10 introspection (user + assistant) identified three timing
mis-mappings in this arm family (synchronous Friday screen vs the book's
asynchronous GTC place-then-wait; stage clock from MA cross vs from breakout;
gate semantics that don't transfer across entry models) → design + book review
in **`dev/plans/entry-ticket-async-v2-2026-08-10.md`** (the successor plan).
Key reframe from the book review: §4.3 overhead grading + reward/risk say the
book itself would likely PASS on AXTI at 2.71 — a faithful process may
legitimately exclude the monsters; AXTI-capture is not the success criterion.
