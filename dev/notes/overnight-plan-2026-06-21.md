# Overnight autonomous plan — 2026-06-21 (10-12h, user AFK)

**User priority (explicit):** (3) **robustify/maximize the engine edge** FIRST →
(1) **correct-window barbell weight** → (2) **build deployable overlay** if time.
**Gate #2 build is GREENLIT** (default-off, backward-compatible).

**The reframe that set this priority:** the engine (Cell-E long-only, top-3000)
beats S&P on the full cycle — `project_deep_1998_2026_contiguous`: realized
**+1552% vs SPX +599%**, ~+3.3pp/yr, MaxDD 35.9% vs ~55%. My barbell grid +
breadth work used **2000-26** (a dot-com-PEAK start) which *erases* that edge
(engine ≈ +332% ≈ S&P over that window) and made the barbell look like it must
weight the floor 70%. On the CORRECT window the engine is strong, so the barbell's
job is **drawdown insurance**, and the right floor weight is the **lightest** that
tames the ~36% DD without surrendering the edge — almost certainly **far below
70/30**. Everything below is on **1998-2026** unless stated.

## Hard guardrails for the unattended run (DO NOT violate)

- **`weinstein-faithful-core.md`:** spine fixed (stage-off-MA, buy only Stage 2,
  breakout+volume, sell Stage 3/4, stop below base, macro/sector gates, RS
  selection). Adapt only the DIALS (MA period, entry mode, sizing, exit
  aggressiveness) and only as **coherent presets**, never knob-soup.
- **`edge_is_the_fat_tail` (8 rejections) + `accuracy_is_unreachable`:** do NOT
  screen winner/loser-touching levers (trim/rotate/re-time/cap), entry/cascade/
  short-pick selection (dead 5×), or stop/sizing knobs. "Maximize the edge" here =
  (a) characterize the EXISTING edge honestly, and (b) compare FAITHFUL PRESETS —
  not invent mechanisms.
- **`mechanism-validation-rigor.md`:** a read-only screen may say "no-build
  decision," never "rejected." Report distributions + realized-vs-MTM, not point
  estimates.
- **`experiment-flag-discipline.md`:** any new config lands default-off + as an axis.
- Merge gates: docs/research → admin-merge after CI; code → 3 gates. Don't pile on a red main.

## Compute budget reality

Each top-3000 deep run ≈ 80min, container serial (parallel=1 for N=3000). ~6-7
runs fit in 10-12h. The warehouse `/tmp/snap_top3000_1998_ls` (top-3000-1998
bars, 1.3G) is ALREADY BUILT and reused by every phase below — do NOT rebuild it.
**No concurrent feat-agent during backtests** (container contention,
`sweep-hygiene.md`) — gate #2 build runs LAST, after backtests free the container.

## Phase 0 — finish short-supply screen (RUNNING, ~finishing)
Loosened `short_min_price 17→5` long-short, top-3000 1998-26. On completion:
decompose `trades.csv` side=SHORT by exit-year P&L + win/loss distribution vs the
06-20 baseline (37 shorts, lost in 2008). Verdict per `mechanism-validation-rigor`
(distribution, not "rejected"). Likely closes the short line → barbell is the bear
hedge. Write `dev/backtest/short-supply-screen-2026-06-21/FINDINGS.md`, PR, merge.

## Phase A — engine edge: honest 1998-26 baseline + cheap robustness (PRIMARY)
1. **One** long-only Cell-E run, 1998-26, top-3000 (reuse warehouse). Spec:
   `engine-top3000-1998-deep.sexp` (config = canonical Cell-E long-only; match the
   established deep baseline cost model — per-share $0.01). ~80min.
2. From that ONE run compute:
   - **vs-S&P:** total + annualized return vs GSPC BAH over 1998-26; is the
     ~+3pp/yr edge intact on CURRENT code (18 days of fixes since the +1552% run)?
   - **realized vs MTM:** from `trades.csv` (closed P&L) vs terminal NAV — is the
     edge real or terminal-MTM on a few monsters (`broad_universe_790_mtm_inflated`)?
   - **cheap rolling-start proxy:** post-process the equity curve for return/DD/
     Sharpe over every [start-year, 2026] sub-window (NOT fresh re-runs — note the
     proxy caveat: positions carry over). Proper fresh-start matrix is already in
     `project_rolling_start_matrix` (~+3pp both regimes) — cite, don't re-run
     (rolling_start_eval at N=3000 = days of compute).
   - Write `dev/backtest/engine-edge-1998-2026/FINDINGS.md`.
   This run's equity curve is ALSO the barbell engine leg for Phase B (shared).

## Phase B — correct-window barbell weight surface (user priority #1)
1. SPY-only floor run, 1998-26 (`floor-1998-deep.sexp`, cheap ~minutes).
2. Blend (`blend.awk` from `dev/backtest/barbell-grid-2026-06-20/`) the Phase-A
   engine vs the 1998-26 floor across the **FULL** weight grid:
   **w_floor ∈ {0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.7}**. Find the **knee** — the
   lightest floor weight that meaningfully cuts the ~36% engine MaxDD while keeping
   most of the engine's S&P edge. Report return / Sharpe / MaxDD / Calmar / Ulcer
   per weight, vs S&P BAH.
3. **Sub-window robustness** (cheap, post-process the SAME two curves over
   1998-2008 crash-heavy / 2009-26 bull): is the knee weight stable across
   regimes? This is the promotion grid done on the CORRECT window.
4. Write `dev/backtest/barbell-grid-2026-06-20/BREADTH-CORRECT-WINDOW.md` (or a new
   dir) — the honest barbell-vs-S&P picture + the recommended LIGHT weight.

## Phase C — faithful-preset comparison (the "maximize" lever, IF feasible)
Only if Phases A/B leave time AND the trader/investor preset bundle is
config-expressible on the full engine (check `dev/plans/weinstein-trader-investor-
presets-2026-05-31.md`; SPY-only presets exist as `spy-trader/investor.sexp`).
Run the investor (current) vs trader preset (10wk MA, continuation entry, full
sizing, earlier Stage-3 exit) as WHOLE presets on 1998-26 top-3000 (~80min each).
Compare edge + DD. Default-off; record, do not promote without WF-CV + grid.
If presets are NOT cleanly config-ready, SKIP — do not build new mechanisms.

## Phase D — gate #2 deployable overlay build (GREENLIT, LAST)
After backtests free the container. Dispatch a feat-agent (worktree-isolated,
docker dune) to build per `dev/plans/barbell-deployable-overlay-2026-06-21.md`:
**Option A sleeve orchestration**, behind a **default-off** flag
(`enable_barbell` / `barbell_floor_weight` / `barbell_rebalance_weeks`), **no core
edits**. Tests: (a) daily-rebalance reproduces `blend.awk` at a known weight; (b)
w=1.0 ≡ pure floor, w=0.0 ≡ pure engine (backward-compat); (c) weekly tracks daily.
Use the LIGHT weight from Phase B as the documented (not defaulted) target. 3-gate
merge. feat-agent dispatch rules: `feat-agent-dispatch.md` + `worktree-isolation.md`.

## Phase E — wrap (every cycle, and at end)
- Update `dev/notes/next-session-priorities-2026-06-22.md` with results + open items.
- Refresh memory: `project_barbell_on_stocks` (correct-window weight),
  `project_deep_1998_2026_contiguous` (current-code re-confirm), short-supply verdict.
  `sh dev/scripts/export-memory.sh` + commit docs-only.
- Keep main green; verify `gh pr checks` before every merge.

## Success criteria (what "focused on the right thing" means here)
1. An HONEST "engine vs S&P on 1998-26, current code" number (real, not MTM-mirage).
2. The barbell weight surface on the CORRECT window → the lightest DD-insurance
   weight that keeps the edge (the number the user actually needs).
3. Short line closed (or escalated with evidence).
4. Deployable overlay built default-off (if time) — usable without changing main.
Everything default-off; main always shippable; no rejected-lever grinding.
