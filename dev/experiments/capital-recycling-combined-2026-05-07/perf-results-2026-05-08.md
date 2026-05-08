# Cells A-E perf measurement (Q3) — 2026-05-08

Q3 of `dev/notes/next-session-priorities-2026-05-08.md`. Original experiment
(2026-05-07) captured trading outcomes (`actual.sexp`, `trades.csv`) but not
runtime. This note pins wall + peak RSS for all 5 cells, post-Q1 memory fixes
landing.

## Setup

- Run timestamp: `2026-05-08T163314Z`
- Inside `trading-1-dev` docker container (TRADING_IN_CONTAINER=1)
- After Q1 fixes A/B/C all merged (PRs #988, #992, #993)
- `OCAMLRUNPARAM=o=60,s=512k`
- 1800s per-cell timeout (none hit)
- Artefact dir: `perf-2026-05-08T163314Z/`

## Results

| Cell | Config | Wall (s) | Peak RSS (MB) |
|------|--------|----------|---------------|
| A — baseline                  | Stage3 OFF, Laggard OFF | 248 | 533 |
| B — stage3-k1-only            | Stage3 ON,  Laggard OFF | 285 | 538 |
| C — laggard-h4-only           | Stage3 OFF, Laggard h=4 | 308 | 535 |
| D — stage3-k1 + laggard-h4    | both ON, h=4            | 318 | 538 |
| E — stage3-k1 + laggard-h2    | both ON, h=2 (aggressive) | **331** | **541** |

All 5 cells PASS. No timeouts, no OOMs.

## Interpretation

### Memory: flat

Peak RSS varies <2% across all 5 cells (533–553 MB). Stage3 force-exit and
Laggard rotation add **negligible** memory cost. The expected behavior — both
features add sequencing logic but no new persistent state — is confirmed.

This is consistent with the post-Q1-fix design: per-step retention is the
skinny `Portfolio_summary` (Fix B), and panel data resides in a single shared
`Daily_panels` cache (Fix A). New exit logic doesn't expand step retention.

### Wall: Cell E is 33% slower than baseline

Wall ordering: A < B < C ≈ D < E. Each feature adds a few percent:

- B (Stage3 only): +37s vs A = +15%
- C (Laggard only): +60s vs A = +24%
- D (both, h=4): +70s vs A = +28%
- E (both, h=2): +83s vs A = **+33%**

Stage3 and Laggard costs are **roughly additive** — neither dominates. Cell E
is the worst case because h=2 (faster rotation cadence) generates more
re-evaluations per week.

### 15y extrapolation

Pre-fix 15y vanilla (#993 merge validation): 57 min wall on GHA.

Cell E on 15y projection: 57 × 1.33 ≈ **76 min** wall. Within the 90 min GHA
budget on `golden-runs-sp500-15y.yml`. Stage3 + Laggard are usable on 15y
windows now that memory is bounded.

### Local vs CI baseline

Local Cell A (248s / 533 MB) is faster + lower-RSS than the cited CI vanilla
5y baseline (299s / 766 MB):

- 18% faster wall — partially CI cold-cache, partially Q1 perf side-effects
- 30% lower RSS — Fix B's skinny step_history dominates even at 5y

Re-pinning the 5y CI baseline post-Q1-fix is reasonable follow-up; the prior
766 MB / 299s figures are now stale.

## Follow-up

- Promote `golden-runs-sp500-15y.yml` from cron to per-push once the
  outstanding 15y scenario assertion failure is resolved (Task #16).
- Consider adding Cell E (or E-equivalent) to the perf-tier 3 golden suite as
  a dedicated experiment scenario, so CI tracks Stage3+Laggard regression
  separately from the vanilla baseline.
- Tune Cell E parameters with confidence — runtime is not a blocker.

## Artefacts

- `perf-2026-05-08T163314Z/cell-{A..E}-*.{log,peak_rss,wall_sec}` — per-cell raw output.
- `perf-2026-05-08T163314Z/summary.txt` — table.
