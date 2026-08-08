# Fill-model ladder v2 — the honest A/B (2026-08-08)

Overnight run answering the record-vs-book A/B on **honest fill terms**, using
the two fill-model fixes shipped this session (both default-off):

- **Fix #1** `sim_entry_fill_next_open` (#2238) — Market entries fill at the
  next *fresh* bar's open, not the stale signal-bar open they decided on.
- **Fix #2** `freeze_entry_at_first_breakout` (#2241) — the resting entry E is
  pinned to the first-qualifying breakout, not chased weekly upward.

Companion to `fill-model-fix-findings-2026-08-07.md` (confound resolution) and
`project_fill_model_inversion` (⭐). Run: pinned worktree `d22bd1364`,
v5thin_adj warehouse, `--parallel 1`, ~9h. Artifacts:
`.sweep-output/ladder-v2-artifacts/`, `faith-*.md`, `ladder-v2-v12-*`.

## The four arms (26y, top-3000 PIT-2000, +$1M start)

| Arm | Fill model | Return | CAGR | MaxDD | Sharpe | Trades | Win% |
|---|---|---:|---:|---:|---:|---:|---:|
| record (baseline) | market @ **stale** signal-bar open + deep floor | +8,367% | ~18% | 37.1% | 0.90 | 1122 | — |
| **record-nextopen** | market @ **next fresh** open + deep floor | **+7,321%** | ~17% | 39.1% | — | 1121 | 34.6% |
| book-honest (fullbook + both fixes) | resting @ **frozen** E + next-open, tight stop | +310% | 5.5% | 28.2% | 0.49 | 1152 | 33.2% |
| book-nochase (fullbook + Fix #2 only) | resting @ frozen E, tight stop | +171% | 3.8% | 30.9% | 0.37 | 1194 | 32.6% |

## Headline — the record's edge is NOT the stale-open fill

Making the record fill honestly (next fresh open, no lookahead) costs
**~1,046pp of ~8,367 — about 12.5%.** record-nextopen still returns **+7,321%**
and beats the honest book ticket (+310%) by **~24×**. The +8,367-vs-+287
inversion documented all program is **not** an artifact of the optimistic
stale-Friday-bar-open fill. It survives.

This closes the last open worry from the 2026-08-07 confound resolution: we had
shown the "94% deep stops" were an E-basis metric artifact (not a real gate
breach) and that the edge relocates to the **fill basis** — cheap market entry
far below the chased E. Arm record-nextopen now confirms the edge is robust to
the *one* genuine realism gap in that fill (buying a price that predated the
decision): honest fill keeps ~7/8 of the record.

## Where the honest fill costs, and where it helps (record-stale → nextopen)

Year-level Δpnl (harness `faith-record-vs-nextopen.md`):

- **2020 COVID V-recovery: +8.88M → +5.37M** (−3.5M, the biggest hit). Next-open
  misses part of the gap-up cheap fills on the March-bottom snapback — exactly
  the mechanism the deep-dive predicted.
- **2025: +64.96M → +57.08M** (−7.9M) — dominated by AXTI (see below).
- **2022 bear: −3.40M → +0.32M** (+3.7M, honest fill *helps*). The stale-open was
  buying into a falling tape at optimistically low prints, then stopping out;
  the next-open fill is more honest and sidesteps some of that.
- Net: honest fill shaves the fat right-tail years (2020/2025) and *improves*
  the bear year — a more defensible, less lottery-flattered curve. MaxDD rises
  37.1 → 39.1 (slightly worse; the trimmed 2020 upside no longer cushions).

**AXTI (the monster, ~76% of the record):** +64.10M (stale) → +56.16M
(nextopen). It survives almost intact — enters a bit higher at the next open →
marginally fewer shares → still a colossal, edge-defining winner. The fat tail
is not a stale-fill mirage.

## Book side — Fix #2 (no-chase) helps, both fixes compound

book-honest (+310%) > book-nochase (+171%): on the resting-order book ticket,
adding next-open Market fills (for the non-resting legs) on top of the frozen E
nearly doubles the return and lowers MaxDD (28.2 vs 30.9). So the two fixes are
mutually reinforcing on the book side — but the book ticket remains ~24× below
the record. The book arm's stops are tight (0% > 15%, mean 5.6% — capped by
`stop_anchor_at_entry_base`), and its whipsaw is high (31–56%/yr ≤3-day
stopouts) — the shakeout tax that is the book's structural cost.

## Validation (V12) + a data caveat

V12 (installed stop ≤ gate, vs fill) on each arm:
- record-nextopen: **32/1121 (2.9%)** violations, all the modest 15–20%
  decision→fill drift band — same profile as the confound regen (29/1122). Full
  audit join (1121/1121).
- book arms: 3–8 violations but **audit join only ~19%** (216/1152, 231/1194) —
  the E-anchored resting orders fill on a *later* date than the decision, so the
  `(symbol, entry_date)` join misses most rows. V12 evaluates only the matched
  subset there. **Caveat:** the book-arm V12 is under-powered; the join needs a
  position_id-based path for resting-order arms (follow-up).

The stop-width "62% > 15%" still shows in the harness for record arms — that is
the **E-basis metric artifact** (col-16 `stop_initial_distance_pct` measured vs
suggested E), unchanged here because PR #2242 (fill-basis column) is not yet in
these runs. Not a real gate breach; see confound resolution §4 RESOLVED.

## The A/B decision (for the user)

The choice is unchanged in shape but now on honest terms:

- **(A) Record rule, honest fill — record-nextopen: +7,321%, CAGR ~17%, MaxDD
  39.1%, extreme concentration (AXTI ~76%).** Live-executable: buy the Stage-2
  signal at the next open with a deep structural floor stop. The edge is the
  cheap fill basis + uncapped fat tail, and it survives honest fill. Cost: one
  name is most of the P&L; drawdown is deep; the curve leans on 2020/2025.
- **(B) Book ticket, honest — book-honest: +310%, CAGR 5.5%, MaxDD 28.2%.** Rest
  at the frozen breakout E, tight base-anchored stop. Far lower return, far
  smoother, no single-name dependence. Roughly SPY-TR-like (~+687% same window)
  or below.

Neither flag is promoted; all four remain default-off axes
(experiment-flag-discipline). Promotion of any would still require WF-CV + the
confirmation grid (promotion-confirmation). This run is a **full-history
single-surface** result — decision input, not a promotion verdict.

## Follow-ups

1. **position_id join in V12** for resting-order arms (book V12 under-powered).
2. **PR #2242** (fill-basis stop_fill_distance_pct column) — merge, then the
   harness stop-width lens reads gate-basis, not E-basis.
3. If the user picks (A): the record-nextopen basis becomes the honest
   record-of-record; re-pin under WF-CV.
