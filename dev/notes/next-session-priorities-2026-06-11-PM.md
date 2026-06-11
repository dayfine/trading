# Next-session priorities — 2026-06-11 (PM)

**Supersedes** `next-session-priorities-2026-06-11.md` (the harvest-rotate-DONE
doc). Check main CI green before dispatching.

## TL;DR — we've been judging the strategy on the wrong number; build the right evaluation

A start-date check (strategy vs BAH-SPY, **both from the same start through today**)
shows the **single-start headline numbers we'd been quoting are unreliable** — the
edge over SPY swings wildly with *when you started*. This is **not** a verdict that
the strategy is weak; it's that **we have not yet evaluated it properly.** Building
that proper evaluation (robust start dates, longer history, clean universe) is the
program — and those matrices double as the **substrate for feature work** (they show
*where* the gaps and edges are, which guides what to build next).

| Start | Strategy CAGR | SPY CAGR | Edge |
|---|---|---|---|
| 2011 | 15.3% | 14.0% | +1.3 |
| 2012 | 18.1% | 14.8% | +3.4 |
| **2014** | **7.1%** | 13.5% | **−6.3** |
| **2016** | **6.8%** | 15.0% | **−8.2** |
| 2018 | 17.2% | 17.1% | +0.2 |
| 2020 | 32.7% | 14.5% | +18.2 |
| 2022 | 35.9% | 21.8% | +14.1 |
| 2024 | 102.5% | 16.6% | +85.9 |

(Source: the coarse rolling-start run `rolling_t3k`, 8 starts at 730-day stride,
Cell-E top-3000 NAV/MTM, all → 2026-04-30. **Preliminary** — see why below.)

**Why this is preliminary, not a verdict** (the reasons to build the real eval, not
to draw conclusions from this table):

1. **2011-2026 is a near-continuous bull — the least favorable regime for a
   stage-timing strategy.** The strategy earns its keep by cutting losses in Stage 4
   and sidestepping bears; this window had no real bear, so its core design value is
   **untested, not disproven.** (Tell: it already shows *lower* MaxDD than SPY,
   27.9% vs 33.7% — downside protection visible even with little to protect against.
   A dot-com/GFC test is where that could actually pay.)
2. **This table is on the incomplete setup** — MTM (not capital-capped, so the AXTI
   mark inflates the recent-start wins), pre-composition universe, coarse 2-yr
   stride. Capital-capped + clean-universe + finer-stride could look materially
   different.
3. **These are measurement *and* improvement tools.** Each lens reveals gaps (e.g.
   *why* did 2014/2016 entries lag?) that point at the next feature to build.

So the takeaway is **methodological**: stop quoting single-start numbers; build the
robust evaluation (P0) on the clean universe (P1) over longer history (P2), then
honestly locate where the edge and the gaps are. The edge over SPY is an **open
question to be measured properly**, and an opportunity to improve — not a settled
result.

(Context, same caveats apply: realized — not MTM — return over 2011-2026 is **+158%**
vs BAH-SPY's +641%, with ~80% of NAV gain unrealized in one name; Sharpe 0.71 vs
SPY 0.85. These too are bull-only / MTM / single-universe reads pending the proper
evaluation.)

## P0 — Rolling-start robustness runner (the lens that makes every comparison honest)

Was flagged as the **primary objective** on 2026-06-07
(`project_evaluation_methodology_reframe`: start-date robustness > MaxDD); the
metrics shipped (#1471 capital-relative DD, #1472 dispersion-stats core) but the
**runner itself was deferred** — so we kept quoting single-start numbers. Build it.

**Spec:**
- **Many start dates, each held to today** (NOT the WF-CV's 1-year non-overlapping
  folds — those answer "how did 2017 go," a different question).
- **Finer, irregular stride:** ~**3/6/9-month** spacing, and **a randomized/jittered
  offset** (not even calendar boundaries like 1/1 — avoid calendar-boundary
  artifacts; e.g. each start = base + uniform jitter within the stride). Deterministic
  seed for reproducibility. ≈ 20-40 starts over 2011-2026.
- **Benchmark overlay:** BAH-SPY (and BAH-BRK) CAGR from the **same start** per row,
  so the output is a head-to-head *edge* matrix, not a bare strategy number.
- **Capital-capped / realized basis:** run with a single-name NAV cap (or report
  realized P&L) so an AXTI-style unrealized mark can't flatter the recent-start
  windows. The MTM version overstates the recent edge.
- **Output = a matrix** (start_date × {strategy CAGR, SPY CAGR, edge, Sharpe,
  capital-DD, time-underwater}) + summary distribution (median edge, % of starts
  beating SPY, worst start). A heatmap (start × horizon) is a nice-to-have; start→today
  is the primary "real decision" framing.
- **Path-dependent / non-cacheable** (each start is an independent full backtest —
  can't reuse fold computations) but **trivially parallelizable** (fork per start).
- There is an existing coarse rolling runner (produced `rolling_t3k`); extend/replace
  it rather than starting fresh. Find it via the `rolling_t3k.sexp` producer.

**Deliverable:** the start-date edge-vs-SPY matrix as the new headline evaluation —
an honest read of *where* the edge shows up and *which* start regimes the gaps
cluster in (those gap regimes are direct feature targets). Not a pass/fail gate on
the strategy; a measurement + improvement lens.

## P1 — Universe-composition policy + weekly liquidity test (defines what everything reruns on)

The "live universe is 5000-8000" framing dissolved: per Ritter/CRSP the real US
**operating-company** universe is **~3,650**; the gap up to ~5,600 tickers (and the
looser 8,000) is **dual-class duplicates + ADRs + REITs + SPACs/warrants/units/
preferreds/CEFs** — mostly NOT stage-tradeable. Our current top-3000 already
includes REITs (SPG/O/PLD/AMT) + ADRs (TSM/ASML) + **un-deduped dual-class**
(GOOG+GOOGL, BRK-A+BRK-B both held); ETFs are correctly excluded.

So the real tradeable universe is **~3,500-4,500 (operating companies + large liquid
ADRs, REIT-policy TBD, dual-class deduped)** — barely above top-3000. Make the policy
**explicit**:
- **Dedup dual-class** — pick one class per economic entity. (Latent bug today: the
  screener can hold both GOOG and GOOGL as two positions.)
- **Explicit REIT in/out** — currently in; make it a stated, ideally backtestable flag.
- **ADR policy** — keep large/liquid (TSM, ASML) via a size/liquidity floor; drop the
  small/illiquid tail.
- **Confirm the junk is excluded** — verify SPAC/warrant/unit/preferred/CEF aren't
  leaking in (ETFs already out).
- **Weekly liquidity test** (user-requested guardrail): on each weekly screen, gate
  any candidate/position where our intended **stake > ~1% of ADV** (float/$-volume) —
  a tradeability sanity check that flags names we can't actually fill at size.

**Compute note:** at N≈4,000 the memory wall is a non-issue (close to top-3000); the
N=8000×26y concern evaporates because the real universe isn't 8000.

## P2 — Broad back to 2000 (fetch now; run after composition)

Tests whether any edge survives the **dot-com bust + GFC** — the macro-regime
diversity the 2011-2026 window lacks and that `promotion-confirmation.md` demands.

- **Data largely exists already:** a real, survivorship-clean `top-3000-2000` PIT
  composition exists (`Composition_from_individuals`, 3000 real names incl. delisted
  Q-tickers, **100% bar coverage** on the sample checked); bars for major names go
  back to 1962. The work is **build the `snap_top3000_2000` warehouse** (~1hr, like
  `snap_top3000_2011`) + run. Fetch any incremental gaps for the composition-policy
  universe regardless (cheap, independent — do it anytime).
- **Sequencing:** top-3000-2000 is **apples-to-apple** to run *now* for a fast
  dot-com+GFC regime read. But the *definitive* run should be on the **composition-
  policy universe (P1)** at ~top-4000. Don't over-invest in top-3000 runs that P1
  will obsolete.
- **Pre-2000 broad is a hard wall:** everything we have pre-2000 broad is **synthetic**
  (Shiller×French `SYNTH_*` skeletons — for regime synthesis, not name-level
  backtests). Real broad PIT membership + delisted bars pre-2000 needs **CRSP**
  (institutional purchase + integration). Out of scope unless we buy data.

## ⚠ Cross-cutting: the rerun dependency

P1 (universe composition) **changes the candidate pool → changes every backtest
result.** So:
- Any number produced *before* P1 lands (incl. the start-date matrix, the 2000 run)
  is on the *old* universe and **must be re-run after P1.**
- Keep an explicit "computed-on-universe-vX" tag on saved results so nothing goes
  stale silently. When P1 lands, re-run P0 (start-date matrix) + P2 (2000) on the
  new universe before drawing conclusions.
- Order if serial: **P1 → P0 → P2.** But P0's *runner* can be built in parallel with
  P1 (it's infrastructure); only the final headline matrix must wait for P1.

## Demoted / carried (low value)

- **"Re-weight the top-3000=artifact priors" (was P0, docs reconcile)** — DEMOTE.
  Partly overtaken by the liquidity/realized findings; prose cleanup, low value.
- **Trade-forensics tooling** (PR-3 post-exit capture ratio, PR-4 auto-`stage_chart`)
  — self-tagged LOW urgency.
- **MFE/MAE harness gap** (`max_favorable/adverse_excursion_pct` always 0) — small,
  well-scoped; only if audit-based give-back analysis is wanted.
- In-flight tracks are steady-state / data-gated (see `dev/status/_index.md`):
  spy-only long-short verification (human session), tuning M2 qNEHVI (awaiting a
  maintainer enable-commit #1327), data-foundations bars-retention.

## Done this session (2026-06-11)

- **Harvest-rotate rigorous test — COMPLETE → WF-CV REJECT** (steps 1-5; PRs #1525
  core partial-exit, #1528 mechanism, #1530 WF-CV spec, #1532 ledger+writeup). All
  `harvest_fraction` fail the gate; decomposed why = dispersion-amplifying noise, not
  Sharpe edge; structural tax in trend folds. Quantified instance of
  `project_edge_is_the_fat_tail`.
- **Methodology, now structural:** `.claude/rules/mechanism-validation-rigor.md`
  (auto-loaded; the 7 checks + "deliverable is the WHY" + verdict calibration),
  `screen-rigor` skill, `project_edge_is_the_fat_tail` meta-memory,
  `feedback_qc_stale_commit_false_positive`. Corrected the earlier screen overclaim.

## Key references

- Start-date matrix source: `rolling_t3k` (coarse, in-container); strategy-vs-SPY
  computed this session.
- `project_evaluation_methodology_reframe` (start-date robustness = primary objective,
  #1471/#1472 shipped, runner deferred), `project_broad_universe_790_mtm_inflated`
  (the AXTI MTM concern), `project_edge_is_the_fat_tail`,
  `reference_deep_history_data_sources` (CRSP wall), `.claude/rules/promotion-confirmation.md`
  (macro-regime diversity).
