# Next-session priorities — 2026-06-01

**SUPERSEDED by `next-session-priorities-2026-06-02.md`** — the P0 SPY reference
strategy + trader/investor presets shipped (#1397/#1401); the mode comparison is
done (trader rejected, selection ≫ timing). Read the 2026-06-02 doc for the
forward plan (lead = the Cell E 2020-2026 stall).

**Supersedes:** `next-session-priorities-2026-05-31.md` (its P0/P2 shipped; P1
cancelled; P3 partial — see below). Read that doc for the full 2026-05-31
session record; this one is the forward plan.

## State of the world (as of 2026-05-31 EOD)

Main green. The 2026-05-31 session shipped 7 PRs (#1387-#1391, #1394) + issue
#1393. Net effect:

- **Three strategy mechanisms now REJECTED, two of them on deep multi-regime
  data:** early-admission (deep 2000-2026), exit-timing surface (repaired
  2010-2026 **and** deep 2000-2026), stage3 hysteresis (subsumed by exit-timing).
  Pattern: **single-knob tweaks to Weinstein entry/exit timing are a dead end on
  the SP500 universe.** Every one is a bull-regime artifact at best, a net drag at
  worst.
- **Deep-history infra exists and is proven end-to-end:** `build_deep_universe.sh`
  (#1388) + PIT snapshots 2000/2005/2010/2015/2020 (#1386/#1390) + the deep
  exit-timing run (#1394). The 27y deep cell is now a one-command battery cell.
- **The strategic direction is written down:** population search over the
  discrete feature space (`dev/plans/population-search-2026-05-31.md`, #1389),
  gated on a regime-diverse battery + population-aware deflation + a versioned
  goal.

## The fork (needs a human call — do NOT auto-dispatch)

Three mechanism-rejections in a row say the lever is **not** more entry/exit-knob
tweaks. The open question is which direction to invest:

- **(A) Build the population-search apparatus** (the user's 2026-05-31 vision).
  Low-risk infra, high strategic value, and the natural endpoint of the
  experiment-platform program. Concrete sub-steps in P1 below.
- **(B) Broader universe first** (per `project_strategic_pivot_broader_first`) —
  Russell-3000 / top-3000. The rejections are all SP500-specific; mechanisms may
  behave differently on a broader, higher-dispersion universe (early-admission was
  a *return*-booster there, per `project_early_admission_mechanism`).
- **(C) A genuinely different mechanism class** — cross-sectional rotation
  (`french_weinstein_rotation`), not another timing knob. Per
  `feedback_strategy_mechanic_changes_too_explorative` this needs strong basis;
  the autopsy's remaining gap modes are the place to look for it.

Confirm the fork with the user before dispatching. The default lean (mine): **A**
— it's the apparatus that makes B and C *trustworthy*, and it's infra not
strategy-exploration, so it's the safest high-value work to do unsupervised.

## P0 · SPY single-instrument reference strategy (user-requested 2026-05-31)

Build a **new, separate** Weinstein strategy that trades **only SPY** (single
instrument) on 30-week-MA stage timing — long when SPY is in Stage 2 (above a
rising 30-week MA), flat/short in Stage 4 — reusing what we have. It is a
**testbed + reference**, NOT a production strategy and NOT a change to the main
strategy's defaults. It cuts both ways:

- **Direction-finder for the main strategy.** SPY is the cleanest possible
  signal: no cross-sectional selection, no position sizing, no sector
  concentration, no macro-gate confound (SPY *is* the market). A mechanism that
  helps here is a strong candidate to port to the main multi-symbol strategy; one
  that doesn't help even on the clean signal almost certainly won't survive the
  noisier 500-symbol setting. It is the cheapest way to triage the autopsy's gap
  modes — and a direct test of whether this session's three rejections
  (early-admission, exit-timing, hysteresis) are *universe-specific* (they were
  all measured on the 500-symbol SP500) or *mechanism-dead* (fail on SPY too).
- **Realistic bound on the autopsy.** The trade-autopsy's missed-gain figures
  (e.g. late_reentry + stage3_false_positive ~+2734% over 27y×12sym) are
  **perfect-hindsight per-trade upper bounds**. A *tradeable* SPY stage strategy
  gives a **realizable** number — how much of that claimed headroom a disciplined
  rule actually captures — which bounds how much of the autopsy is real vs.
  hindsight artifact. The autopsy is a labeller (`project_stage3_hysteresis_*`);
  this puts a floor and a ceiling around its claims.

**Reuse (the "try to reuse what we have" ask):** the existing `STRATEGY` module
type + `on_market_close`; the stage classifier + 30-week MA; the Weinstein
trailing-stop machinery; the simulator; the **BAH-SPY benchmark** (already exists,
PR #882) as the bar to beat. A 1-symbol universe. **Strip** the screener cascade /
ranking / sizing / macro gate — for a single instrument they're degenerate; the
strategy is pure stage-timing on SPY's own series. Needs **SPY bars** (the ETF,
`SPY.US`, tradeable since 1993 — fetch via `build_deep_universe.sh` / the
`fetch-historical-data` skill; we have GSPC.INDX deep to 1999 for cross-check but
SPY is the tradeable instrument).

**The test.** vs BAH-SPY on the deep window (incl. dot-com + GFC): Weinstein's
whole claim is that Stage-4 exits dodge the big drawdowns, so stage-timed SPY
should win on **risk-adjusted** terms (Sharpe/Calmar) even if it trails on raw
return in a bull run. Then **tweak toward the autopsy headroom** — apply the same
gap-mode mechanisms (earlier re-entry, stage3 hysteresis/exit-margin, early
Stage-2 admission) as axes on SPY and see which, if any, recover gain on the clean
signal. Record in the ledger like any surface; the deep cell is mandatory.

**Caveat.** SPY-only is a *market-timing* strategy, a different beast from the
stock-picking main strategy — it informs direction and bounds the autopsy; it is
not itself the product. Lands as a new strategy module behind its own scenario;
touches no existing default (per `experiment-flag-discipline`).

### Build plan (scoped 2026-05-31 — Explore reuse map)

**Reuse as-is:** `Strategy_interface.STRATEGY` (symbol-agnostic `on_market_close`,
`trading/trading/strategy/lib/strategy_interface.mli`), `Stage.classify` (pure,
`analysis/weinstein/stage/lib/stage.mli`), `Macro.analyze`, `Weinstein_stops`,
`Bar_reader`, and the **already-wired `Bah_benchmark` strategy +
`universes/spy-only.sexp`** as the benchmark/universe.

**New (the clean path — do NOT try to run the main strategy on a 1-symbol
universe; its screener/ranking/sizing are too entangled):**
- `trading/trading/weinstein/strategy/lib/spy_only_weinstein_strategy.{mli,ml}`
  (~250-350 lines). Friday: `Stage.classify` SPY → Stage2 buy `floor(cash/close)`,
  Stage3→4 sell-all; daily: `Weinstein_stops` trailing. Reuses macro gate
  optionally (degenerate for SPY — make it a no-op/flag).
- `trading/test_data/backtest_scenarios/spy-only-stage2.sexp` scenario.
- Wire `Spy_only_weinstein` into `Strategy_choice.{mli,ml}` + `Panel_runner`
  `_build_strategy` (mirror the `Bah_benchmark` arm).

**Data:** SPY bars present **2009-2026** (`test_data/S/Y/SPY/`) — enough for a
first cut. **Deep 1998/2000-2026 SPY needs a fetch** (the autopsy ran SPY
1998-2025, so it's available via the `fetch-historical-data` skill) — follow-on,
required before the deep-cell test.

**Sequence:** (1) module + scenario + tests, first result vs **BAH-SPY** on
2009-2026 — does stage-timing win risk-adjusted (Sharpe/Calmar)? (2) fetch deep
SPY, re-test on 2000-2026. (3) add the autopsy gap modes as axes (stage3
hysteresis/exit-margin, early-admission, re-entry) — the same knobs rejected on
500-symbol — and see which recover gain on the clean SPY signal. Ledger each;
deep cell mandatory.

**Autopsy headroom (the bound):** late_reentry +1557% / stage3_false_positive
+1176% / late_stage2_admission +505% (`dev/notes/trade-autopsy-2026-05-29.md`,
SPY + 11 SPDR ETFs 1998-2025). These are perfect-hindsight upper bounds; the SPY
strategy's realized capture is the floor that bounds them.

## P1 · Population-search apparatus — the buildable, low-risk path toward (A)

Each step is independently valuable even if the full multi-arm engine is never
built; each gates the next. All are infra/tooling (feat-agent dispatchable):

1. **Population-aware deflation in `rank_variants`** — today Deflated Sharpe's
   `n_trials` = one matrix size. Add a `--lifetime-trials N` flag so best-of-N
   deflation counts the whole search's trial budget, not one surface. (Issue this
   first; it's the smallest, and it's the correctness fix that prevents
   parallel search from lying.)
2. **A committed `rank-variants` / `write-ledger` CLI** — the ranking + ledger
   write were done by throwaway exes rebuilt 4× this program
   (`project_promotion_confirmation_grid`). Ship the durable bins so future runs
   don't hand-author sexp. (`rank_variants.exe` already exists and is committed —
   verify it covers the need; the *ledger-write* path is what's missing.)
3. **The multi-regime battery as a fixed artifact** — build deep bars for the
   5 PIT snapshots (`build_deep_universe.sh --snapshot <path>`), define the
   battery (which (universe × period) cells, with ≥1 deep), pin it. This is the
   fitness function the whole apparatus optimizes against.
4. **Versioned goal + ledger-rescore tool** — the goal (metric + battery) as a
   pinned artifact; a tool that re-scores the append-only ledger under a revised
   goal and reports which verdicts flip. (Per #1389 — needed before any
   goal-revision is trustworthy.)

## P2 · Panel_runner /tmp leak fix — issue #1393 (quick infra win)

Per-fold snapshot cleanup works on success but ORPHANS on crash/kill → ENOSPC
filled the container this session (1895 dirs / 53GB). Add an `at_exit` / Fork_pool
teardown that purges `/tmp/panel_runner_csv_snapshot_*` on abnormal exit. Small,
self-contained, dispatchable. Reduces a recurring sweep hazard.
(`project_panel_runner_tmp_leak`.)

## P3 · Deep-history — remaining open

- **Dynamic-membership rebalanced backtest:** check whether
  `build_universe -change-log` can drive a *properly rebalanced* point-in-time
  backtest (vs today's pinned-cohort). The pinned-2000-cohort deep run is a fixed
  survivorship-aware snapshot; a rebalanced one would be more realistic.
- Build deep bars for the 2005/2015/2020 snapshots when a battery run needs them
  (feeds P1.3).

## Backlog (deferred, needs the fork resolved first)

Cross-sectional rotation (`french_weinstein_rotation`), Russell-3000 broader
universe, DSR into the BO tuner.

## Session ramp-up reminders

- **Step 0: main CI green** (`gh run list --branch main --limit 3`). Newest
  priorities = this doc.
- **Before any deep/multi-fold WF run: purge the Panel_runner leak**
  (`docker exec trading-1-dev bash -c 'rm -rf /tmp/panel_runner_csv_snapshot_*'`)
  and check `df -h /tmp` — it fills silently (`project_panel_runner_tmp_leak`).
- Deep bars live **uncommitted** in the `cost-test` worktree (1999-2026 incl.
  delistings) — reusable for cheap deep re-runs; rebuildable via
  `build_deep_universe.sh` if gone.
- Three mechanism-rejections this program say: **don't re-test entry/exit-timing
  knobs.** Any new mechanism must clear the deep cell early.
