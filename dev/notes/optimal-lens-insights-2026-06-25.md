# Optimal-strategy lens — "the better trades we're not making" (2026-06-25)

Driven by the user's ask: *run the optimal strategy and see what better trades we're
not making.* Uses the in-repo `optimal_strategy` counterfactual + `all_eligible`
forward-scoring tooling (which already existed — `Backtest_optimal.Outcome_scorer`,
`trade_audit_ratings`, `trade_autopsy/missed_gain`). This note synthesizes the runs.

## Method (and its honest limit)

`optimal_strategy --output-dir <run>` replays the actual run's Friday calendar, scores
**every** Stage-1→2 breakout by **forward-walking** the panel (look-ahead), then greedily
packs the ranking under the *same* live sizing envelope (the "Constrained" variant). It
emits a headline gap decomposition + a "Trades the actual missed" table with each missed
symbol's realized R-multiple and **cascade-rejection reason**.

**Limit (load-bearing):** the counterfactual uses look-ahead — it is an **upper bound**,
not a realizable strategy. A "missed" trade was *takeable under the envelope* but the
actual run didn't take it; whether it's *closeable in real time* is a separate question
(you can't know ex-ante which breakout becomes the +23R monster). So the lens answers
"where does the envelope/ranking leak return" — not "here's free money."

Tooling note: these runs are enabled at broad scale by **PR #1743** (`--snapshot-dir` on
the optimal + all-eligible runners → read a pre-built top-3000 warehouse instead of CSV
`data/`; no 3000-name fetch needed).

---

## Report #1 — recent: sp500 2019-2023, long-only Cell-E, A-D-live

Actual: **+23.48% / 280 trades / 33.6% win / −23.4% MaxDD / Sharpe 0.36**.

| Metric | Actual | Optimal (constrained, upper bound) |
|---|---:|---:|
| Total return | +23.48% | **+24.58%** (+1.1pp) |
| Win rate | 33.6% | **83.0%** |
| MaxDD | −23.4% | **−0.2%** |
| Round-trips | 280 | **47** |
| Avg R-multiple | 0.00 | **5.30** |

**Finding 1 — selection is NOT the gap.** Actual +23.5% vs the look-ahead upper bound
+24.6% = only **+1.1pp** of pickable return. The cascade ranks near-optimally under the
current envelope; "pick better entries" has ~no headroom here. (Re-confirms
`project_accuracy_is_unreachable_diversify_instead`.)

**Finding 2 — the misses are CAPACITY (`Insufficient_cash`), not picks.** The top missed
winners are dominated by one rejection reason:

| Symbol | R | P&L | reason |
|---|---:|---:|---|
| JBL | +23.5 | $23.5K | End_of_run — **Insufficient_cash** |
| DVN | +19.8 | $19.7K | Stage3 — Stop_too_wide |
| PWR | +15.2 | $15.2K | Stop_hit — **Insufficient_cash** |
| ODFL | +14.1 | $14.0K | End_of_run — **Insufficient_cash** |
| PHM | +12.7 | $12.7K | End_of_run — **Insufficient_cash** |
| XOM, BKNG, SBAC, REGN, DVA … | +6 to +8 | | mostly **Insufficient_cash** |

The strategy *identified* these but couldn't fund them — capital was tied up. Cell-E's
envelope (`min_cash_pct=0.30` + `max_position_pct_long=0.14` → ~5 concurrent slots) means
when the slots are full, new breakouts get `Insufficient_cash`, even the eventual
monsters.

**Finding 3 — the actual over-trades.** Same return as the optimal, but **280 trades @
33% win / 23% DD** vs the optimal's **47 @ 83% / ~0% DD**. The actual sprays capital across
many mediocre positions (churned by laggard rotation), exhausting cash for the few
right-tail winners. The lever is **capital allocation / concentration / turnover**, not
entry selection. This is `project_edge_is_the_fat_tail` viewed from the capacity side: the
winners are identifiable, but the envelope can't hold cash for them.

**Caveat:** "reserve cash for JBL" isn't directly closeable (hindsight). But turnover /
concentration / cash-floor are *structural, real-time-controllable* knobs — that's the
testable direction.

---

## Report #2 — deep full-cycle: sp500-2000 PIT (515), 2000-2026, long-only, A-D-live

Actual run: **+871.0% / 939 trades / 37.7% win / −27.4% MaxDD** (consistent with the
barbell engine-lo leg — the production engine on the full cycle ≈ 871%).

Optimal lens: **NOT obtained** — the CSV-mode forward-scan over 1373 Fridays × 515 symbols
ran **1h46m still in the scan phase** (no candidates emitted), so it was killed to free
the container for the overnight broad run (the user's priority). The deep scan is
super-linear: each Friday's stage classification walks a longer bar history than the
2019-2023 window, and the in-process 28y CSV snapshot is large. **Tooling lesson:** the
optimal/all-eligible forward-scan doesn't scale to deep multi-decade CSV windows without
the snapshot-warehouse path (#1743) + a precompute/memoization pass. Deep cross-check of
the capacity finding is **deferred** (re-run via `--snapshot-dir` + bumped cache, off-peak).

---

## Report #3 — BROAD deep: top-3000-1998, 1998-2026, long-only, snapshot mode

Enabled by #1743 (`--snapshot-dir` against `/tmp/snap_top3000_1998_2026`, 3015 syms,
`SNAPSHOT_CACHE_MB=4096`). Chained job: **STEP 1** actual run (top-3000 × 28y backtest,
snapshot mode) → **STEP 2** optimal lens. Launched overnight 2026-06-25 ~06:26.

### STEP 1 — broad actual run: COMPLETE ✅

First honest **complete-top-3000** (3000 names, not a survivor subset) production
long-only run over 28y, snapshot mode against the warehouse:

**+698.8% / 1145 trades / 34.9% win / −39.9% MaxDD / Sharpe 0.50** (open_positions_value
$7.94M on $1M start).

Cross-cut vs the narrower runs (different universe/window, so directional not exact):

| run | universe | window | return | MaxDD | Sharpe |
|---|---|---|---:|---:|---:|
| broad | top-3000 (3000) | 1998-2026 | 698.8% | 39.9% | 0.50 |
| deep | sp500-2000 (515) | 2000-2026 | 871.0% | 27.4% | — |
| recent | sp500 (500) | 2019-2023 | 23.5% | 23.4% | 0.36 |

The **broader top-3000 universe has LOWER return AND higher DD** than the narrower 515-name
sp500 — more volatile small/mid-caps + the dot-com bust (1998-2002, which the 2000-start
deep run partly misses) widen the drawdown. ⚠ `open_positions_value ≈ final NAV` → the
698.8% is **MTM-heavy / terminal-unrealized-inflated** (`project_broad_universe_790`): the
robust signal is the *shape* (broad = wider DD, lower risk-adjusted) not the headline %.
This re-confirms `project_factor_lens_regime_governs_edge` ("top-3000 vs top-1000/narrow"
breadth tradeoffs) and that **breadth is a DD/return tradeoff, not free return.**

### STEP 2 — broad optimal lens (missed-trades): re-launched, best-effort overnight

(My first chained launch mis-parsed the relative output-root path and skipped STEP 2;
re-launched correctly — confirmed "universe=3000 / using snapshot warehouse (3015
entries) / scanning 1478 Fridays", which **validates #1743's snapshot path on top-3000
end-to-end**.)

**OUTCOME: OOM-killed mid-scan (~1h, RSS 7.1 GB on the 7.75 GB container), no output.**
The bottleneck is **memory, not cache** (the 4096 MB snapshot cache was ample — the
3000-symbol working set is only ~420 MB). The hog is the **`forward_table`**: a per-symbol
`weekly_outlook list` across all 1478 Fridays for 3000 symbols (~4.4M stage-classified
records held in RAM at once). It blew the ceiling before even finishing the scan phase
(scoring would add more). So the broad missed-trades lens is **infeasible as-is** — the
fix is not "faster"/"more cache" but **memory-bounded**: stream/chunk the forward_table
(e.g. score per-symbol then drop, or window the Friday calendar), or run on a bigger box.
The **capacity thesis from report #1 stands regardless** — it doesn't depend on the broad
lens.

---

## Synthesis & future plans

Standing on report #1 (the only *optimal-lens* result that completed) + the deep & broad
*actual* runs (the optimal lenses for those didn't finish — a tooling-scale limit, noted).
The "better trades we're not making" answer is **report #1's**; the deep/broad actuals add
the universe/regime picture.

1. **Stop tuning entry selection.** Two independent lenses (this + cascade-reweight
   WF-CV) now say the same thing: picking is near-optimal; there's no alpha in "better
   entries."
2. **The live lever is the capital envelope.** `Insufficient_cash` is the dominant miss
   reason → test, as proper default-off axes under WF-CV + the confirmation grid:
   - **concentration / position count** (fewer, larger positions — does holding cash for
     fewer high-conviction names beat spraying across ~5 slots?);
   - **turnover / laggard-rotation cadence** (the rotation churn is what exhausts cash —
     does slower rotation preserve dry powder for breakouts?);
   - **cash-floor `min_cash_pct`** (does a lower floor fund more winners, or just add DD?).
   Each is a real-time-controllable structural knob, not a hindsight wish.
3. **Watch the over-trading / DD asymmetry.** Optimal hits the same return at ~0% DD in
   1/6 the trades — the actual's 23% DD is "self-inflicted" via churn. This is where the
   barbell / diversification layers were already pointing (`project_barbell_on_stocks`):
   the engine's DD is structural over-trading, addressable without touching the fat tail.
4. **Breadth is a DD/return tradeoff, not free return (deep + broad actuals).** top-3000
   1998-2026 (699%/39.9%DD/0.50) vs sp500-515 2000-2026 (871%/27.4%DD): going broader
   *widened* drawdown and *lowered* risk-adjusted return — the small/mid-cap tail + dotcom
   adds volatility, and the headline % is MTM-inflated. So "trade a broader universe" is
   not itself a lever; it interacts with the *capacity* problem above (more candidates
   competing for the same ~5 funded slots → even more `Insufficient_cash` misses). The two
   findings compound: **breadth makes the capacity bottleneck worse, which is why the
   capital-envelope levers (concentration / turnover / cash-floor) are the priority — they
   gate how broad you can usefully go.**

### Verdict on the original question
*"What better trades are we not making?"* — **Not better *picks* (the cascade is
near-optimal); better *funding*.** The strategy correctly identifies the winners (JBL +23R
et al.) but runs out of cash to take them because it sprays capital across many mediocre,
high-turnover positions. The next experiments are capital-allocation knobs, run as
default-off axes through the standard WF-CV + confirmation-grid pipeline — **not** another
round of entry-signal tuning.

### Next-session actionable queue
1. Build `min_cash_pct` / position-count / laggard-rotation-cadence as default-off
   `Weinstein_strategy.config` axes (most are already config fields) → WF-CV each on the
   sp500-2000 deep basis → confirmation grid. (`experiment-gap-closing` skill.)
2. Merge #1743 (snapshot-mode runners; CI green, needs QC) — unblocks broad diagnostics.
3. Make the optimal/all-eligible forward-scan **memory-bounded** so the deep/broad optimal
   lenses can finish: the `forward_table` materializes every symbol's full per-Friday
   outlook list in RAM (OOM'd at ~7 GB on top-3000). Stream it — score per-symbol then
   drop, or window the Friday calendar — rather than holding all ~4.4M records at once.
   (Not a cache/speed fix; it's a working-set fix.)
4. Fix the all-eligible post-step fixtures-root bug (below).

### Harness note (surfaced this session)
The all-eligible **auto-emit post-step** resolves the universe via `Fixtures_root.resolve()`
(→ `data/backtest_scenarios/`) and ignores `scenario_runner`'s `--fixtures-root`, so it
silently fails (swallowed `Sys_error`) for any scenario whose universe lives under
`test_data/`. Pre-existing; worth a follow-up (thread `--fixtures-root` into the post-step).
`optimal_strategy` is unaffected (it reads the universe from `universe.txt`).
