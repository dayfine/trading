# Build 0 — A-D breadth wiring + payoff (2026-06-22)

The EOD handoff's P0: wire real Advance-Decline breadth so the decline-character
classifier's A-D-lead leg (inert all session at `~ad_bars:[]`) functions. Two
independent threads pointed here — `slow_grind_gate` over-restricting and the
arming-speed catch/whipsaw coupling both blamed the inert A-D leg.

## It was a DATA gap, not a wiring gap

The A-D plumbing is already complete:
- `trading/trading/backtest/lib/runner.ml:_load_ad_bars` calls
  `Weinstein_strategy.Ad_bars.load ~data_dir` by default (only `skip_ad_breadth=
  true` short-circuits to `[]`). Every backtest this session logged "Loading AD
  breadth bars..." — it was loading.
- `Ad_bars.load` composes Unicorn (official NYSE breadth 1965-2020) + Synthetic
  (computed from the universe), threaded through `Weinstein_strategy.make
  ~ad_bars` → the live macro → the decline-character.

A-D was inert only because **`data/breadth/` was empty** (the gitignored deep
store had no breadth CSVs; `Ad_bars.load` returns `[]` on missing files —
graceful degradation). `pipeline.ml:103`'s `~ad_bars:[]` is a *separate*
snapshot-mode confidence field, not the CSV-mode strategy path.

**Fix (no code change, no golden re-pin):**
1. Seed the committed Unicorn CSVs into `data/breadth/` (`nyse_advn/decln.csv`).
2. `compute_synthetic_adl.exe -data-dir <data>` → generated
   `synthetic_advn/decln.csv` covering **1998-01-05 → 2026-06-22** from the deep
   universe. Validates at **0.92-0.93 Pearson correlation** vs official NYSE
   breadth over 780 overlapping dates — a faithful proxy.

`Ad_bars.load` now returns real data → the A-D-Line indicator is live. (The
breadth CSVs live in gitignored `data/breadth/` — an experiment input, not
committed. Regenerate with the two steps above.)

## Payoff — A-D-live re-screen vs the A-D-inert baseline (faithful-short deep, 2000-2010)

| arm | A-D inert | A-D LIVE | Sharpe (live) | Calmar (live) |
|---|---|---|---|---|
| 00 long-only | 327.1% / 31.6%DD | **419.3% / 27.4%** | 1.040 | 0.590 |
| 01 ungated longshort | 475.6% / 27.6% | **518.6% / 25.3%** | 1.123 | 0.713 |
| 02 neutral_blocks_shorts | 475.6% | 518.4% | 1.124 | 0.713 |
| 03 slow_grind_gate | 367.1% / 26.7% | **466.3% / 22.9%** | 1.082 | **0.745** |
| 04 both | 367.1% | 466.3% | 1.082 | 0.745 |

### Two findings

**1. A-D-live lifts the WHOLE strategy (the broad payoff).** Even long-only jumps
+92pp (327→419%) with −4pp MaxDD and Sharpe 0.90→1.04. The A-D-Line sharpens the
**macro entry gate** (better trend reads → better entry timing), not just the
short leg. This is the single biggest effect in the table and it is universe-wide.

**2. A-D-live FLIPS the `slow_grind_gate` verdict (the targeted payoff).** With A-D
inert, slow_grind *taxed* the edge (367 vs 475 ungated, −108pp — it could only
throw shorts away). With the A-D-lead leg live:
- The return tax **halves** (466 vs 518, −52pp).
- slow_grind keeps **6 shorts netting +$432K** — *more* than the un-gated 25
  shorts net +$203K. The A-D-lead leg lets it select the genuine
  sustained-distribution bear shorts and drop the squeeze-prone ones (exactly the
  separation the rate signal alone could not make — see
  `fast-v-min-rate-surface`).
- slow_grind now has the **best MaxDD (22.9%) and best Calmar (0.745)** of any
  arm.

So `slow_grind_gate` moves from **"reject — taxes the edge"** to **"the
risk-adjusted (drawdown) winner, A-D-informed"**: lower raw return than ungated
(the long-side capital-interaction confound persists) but the best DD and Calmar,
on genuinely higher-quality shorts. **It is now WF-CV-worthy.**

`neutral_blocks_shorts` (02) stays ≈ ungated (still inert — all shorts are
Bearish-tape even with A-D live), consistent with the prior screens.

## Implications (decisions for the next session)

1. **A-D-live should likely become the DEFAULT basis.** It is core Weinstein
   doctrine (the A-D line is his primary breadth gauge) AND it improves results
   broadly (+92pp/−4pp-DD on long-only alone). Making it the default means
   generating + **committing** synthetic breadth into `test_data/breadth/` and
   **re-pinning all goldens** — the "attended, behavior-changing" Build 0 the
   handoff flagged. This is the real next step and it is now well-motivated.
2. **Every A-D-inert WF-CV this session is on the OLD basis.** The
   `neutral_blocks_shorts` cell-1/grid, the arming-speed WF-CV, and the threshold
   surface all ran A-D-inert. They should be re-run on the A-D-live basis before
   any promotion — neutral likely holds (still inert), but slow_grind and
   arming-speed should be re-screened with A-D live (the latter's catch/whipsaw
   separation may now be possible — A-D-lead distinguishes crash from dip).
3. **Escalate `slow_grind_gate` to WF-CV on the A-D-live basis** — does the best-
   Calmar result hold across folds?

## Caveats
- Synthetic breadth from the ~731 deep-fetched names (broad but not the full
  Russell 3000); 0.92-0.93 corr vs official is strong. A-D-live runs are ~3-5×
  slower per tick (real per-tick breadth macro cost).
- Single deep window (2000-2010); the cross-arm comparison is internally valid
  (all share the same A-D). WF-CV is the next rigor step.
