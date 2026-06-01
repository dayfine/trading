# Next-session priorities — 2026-06-03

**Supersedes:** `next-session-priorities-2026-06-02.md`. Its P0 (diagnose the Cell E
2020-2026 stall) is **done** and the finding reshapes the roadmap; its P1 (trader-dials
package) is **demoted to dead** by that finding; its P2.1 (population-aware DSR) shipped
(#1407). This is the forward plan.

## State of the world (2026-06-02 EOD)

Main green. The 06-02 session delivered the **Cell E stall diagnosis** (the 06-02 P0
lead) plus two PRs:

- **#1408** (docs) — `dev/notes/cell-e-2020-2026-stall-diagnosis-2026-06-02.md`.
- **#1407** (code) — `rank_variants --lifetime-trials` (population-aware Deflated
  Sharpe; bit-identical when omitted). P2.1 of the population-search apparatus.

### The diagnosis (the load-bearing learning — read it)

`memory/project_cell_e_2020_stall_regime.md` + the doc. Headline: the Cell E
2020-2026 stall is a **payoff-geometry inversion, NOT a hit-rate decline.**

| | 2010-2019 | 2020-2026 |
|---|--:|--:|
| win rate | 38.6% | 37.1% (≈flat) |
| avg stop-out loss | −0.96% | **−2.52%** (2.6× deeper) |
| avg winner | +11.26% | **+7.64%** |
| avg winner hold | 106d | **63d** |
| realized **profit factor** | **1.78** | **0.88** |

The edge was the asymmetry (tiny losses, big winners), not the hit rate. Post-2020
both sides inverted: losers fall 2.6× deeper (vol), winners shrink + shorten across
*every* exit channel (trends are shorter/shallower). **This explains why all three
timing-knob tweaks failed** (continuation #1366, hysteresis, early-admission, MA-dial):
the two degraded quantities pull stop placement in *opposite* directions, so each knob
tuned **one side of a two-sided regime change**. The regime moved, not the parameters.

**Rules out:** rotation churn (the *healthy* mechanism, +$503k/69% win), idle capital,
faster-MA. Laggard rotation works; the entry edge is what collapsed.

## The two genuine levers (everything else is dead)

The diagnosis kills the timing-knob direction outright and leaves exactly two:

### P0 · Broad-universe test — knob-free, DATA-GATED (lever #1)

Post-2020 SP500 leadership was narrow (mega-cap); the surviving *trends* may have been
in mid/small-caps the SP500 universe doesn't contain. A broad-3000 / Russell test might
restore the +11%/106d winners **without changing a single parameter** — making the
"stall" a universe artifact, not a strategy defect.

**Blocker (the actual task):** committed `test_data` is SP500-only — broad-3000 coverage
is ~0% (the `broad-3000-2010` universe is a synthetic alphabetical list, mostly tickers
with no bars). The cost-test worktree has only ~857 deep SP500+delisted names, not a
breadth expansion. So lever #1 = **a real EODHD fetch of ~2500 broad symbols' 2020-2026
bars** via the `fetch-historical-data` skill, then re-run the exact 06-02 diagnostic
(`dev/backtest/cell-e-stall-diag/`) on the broad universe and compare realized PF +
payoff geometry vs the SP500 baseline. Multi-hour, supervised (API limits). This is the
single highest-information next experiment.

### P1 · Regime / breadth ENTRY throttle — the tension-free mechanism (lever #2)

The ONLY mechanism class that escapes the stops-vs-winners tension, because it gates
*entry count* not the stop: fewer entries in low-trend-quality / narrow-breadth tape →
fewer −2.52% deep losers, while the stop on surviving winners is untouched.
Weinstein-faithful (tighten the macro/breadth gate; spine intact). Candidates:
- **Breadth gate** — A/D or %-above-30wk-MA threshold (2023 was 88% index-"Bullish" yet
  25% win — the index gate is blind to narrow breadth; the run already loads "AD breadth
  bars", under-weighted today).
- **Macro-Neutral as no-buy** — 2022's bleed entered through Neutral/Bullish bear-rally
  blips.
- **Trend-quality regime filter** — rolling measure (recent realized winner-hold, or %
  of universe in sustained Stage 2) that throttles new deployment when trends aren't
  extending.

Build with full `experiment-gap-closing` discipline: default-off axis
(`experiment-flag-discipline`), deep cell + confirmation grid (`promotion-confirmation`).
**Mandatory regime cell: a sustained-trend window (2010-2019 or deep pre-2009)** — a
throttle tuned to dodge 2021-2025 chop must NOT strangle the 2010-2019 / 2020-COVID-V
regimes where the fast breakouts *made* the money (+$396k in 2020 alone). That
cross-regime test is the gate, and it's why lever #1 (broad-universe) ranks first: it can
restore the edge *without* a throttle that risks the good regimes.

## P2 · Population-search apparatus — continue (infra, safe autonomous)

P2.1 (population-aware DSR) shipped (#1407). Remaining, per
`dev/plans/population-search-2026-05-31.md` + `experiment-platform-2026-05-29.md`:
- **Durable ledger-write CLI** — the ledger write was done by throwaway exes rebuilt 4×.
- **Multi-regime battery as a fixed artifact** — the (universe × period) cells with ≥1
  deep; the fitness function the apparatus optimizes against.
- **Versioned goal + ledger-rescore tool.**

## Demoted / dead

- **Trader-dials package** (06-02 P1) — the diagnosis shows the trader dials
  (continuation, sizing, faster exit) tune the *timing* dimension that's proven dead and
  regime-sensitive. Do not build the coherent-package test; it would tune one side of the
  two-sided regime change like its predecessors. Only revisit if lever #1/#2 both fail.
- **Any new entry/exit timing knob** — settled dead three times over.

## Backlog
Deep-bar build for 2005/2015/2020 PIT snapshots (feeds the battery + lever #1 fetch),
DSR into the BO tuner, cross-sectional rotation (`french_weinstein_rotation`).

## Ramp-up reminders
- **Step 0: main CI green** (`gh run list --branch main --limit 3`). Newest = this doc.
- **Code PRs need `gh pr merge --admin --squash`** (QC posts APPROVED as comments;
  author==reviewer blocks `--approve`). Confirm `state=MERGED` BEFORE deleting the branch
  (`feedback_admin_merge_qc_comment_prs`). **`gh pr edit` needs org token scopes we don't
  have** — set the body at `gh pr create` time; can't edit after.
- **Data path nesting is FIRST/LAST letter** (`AAPL` → `test_data/A/L/AAPL`), not
  first/second. (Cost me an audit this session.)
- **Before any deep/multi-fold run: purge `/tmp/panel_runner_csv_snapshot_*`**
  (`project_panel_runner_tmp_leak`, #1393).
- **The cost-test worktree holds the deep SPY 1993 + SP500 2000 PIT data** — reusable,
  rebuildable via `build_deep_universe.sh`.
