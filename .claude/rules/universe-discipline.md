# Universe discipline — sp500 is a test fixture, not a measurement surface

**Never measure performance on the S&P-500 universe. Use it only for sanity
checks and rule validation.** Every number that informs a build/no-build,
promote/reject, ACCEPT/REJECT, or "mechanism X does Y" verdict must come from a
**broad** universe — top-3000 (or the widest PIT composition the window
supports).

User instruction, 2026-08-20: *"we do NOT care about running on S&P500 universe.
even 5y should run on broad."*

## The line

| purpose | sp500 OK? |
|---|---|
| Golden / regression pin — "did this commit change behaviour?" | **yes** |
| Determinism tripwire — "does salt 0 still reproduce draw X?" | **yes** |
| Mechanism liveness — "does this flag fire at all / is this knob wired?" | **yes** |
| Smoke test, CI speed, plumbing check | **yes** |
| **Null / noise-floor measurement meant to generalise** | **NO** |
| **A/B or surface that produces a verdict on a mechanism** | **NO** |
| **A confirmation-grid cell** | **NO** |
| **Any figure quoted as evidence in a writeup's conclusion** | **NO** |

The distinction is *purpose*, not file. `universes/sp500.sexp` appears in ~78
committed specs and most of those are legitimate — they pin behaviour, they do
not measure it.

## Why — the concrete episode

PR #2436 (2026-08-20) measured the 5-year drawdown null on **sp500-500, 187
traded names** and concluded that `Range_top_breakout` "fails its first
independent cell", because that cell reversed the 26y top-3000 result on every
metric.

That comparison moved **period AND universe at once**. The record hedged it
("does not attribute the reversal") and shipped anyway — so a merged conclusion
now rests on a cell whose universe was never the right control. The re-run
(`dev/experiments/rt-freshness-broad5y-2026-08-20/`, top-3000 PIT-2019, same
window) exists solely to find out which axis produced the reversal.

`project_cell_e_2020_stall_regime` had already recorded that **broad universe is
THE lever** — an sp500 cell was never going to answer a question about breadth-
sensitive behaviour. The rule exists because that memory did not stop it.

## Consequence for the confirmation grid

`promotion-confirmation.md` §"The grid" previously offered *"SP500-510 vs
top-3000"* as an example of universe diversity. **That is superseded.** Grid
universe diversity must be **broad-vs-broad** — a different PIT snapshot, a
different breadth tier (top-1000 vs top-3000), or a different composition
vintage. Narrowing to a large-cap index is not a diversity axis; it is a
different experiment.

The early-admission worked example in that file used SP500 cells. It stays as a
historical record, but a grid built that way today does not satisfy the rule.

## What QC can check

- **U1 — measurement universe.** Any PR whose writeup quotes a performance
  figure in support of a conclusion: the producing spec's `universe_path` must
  not be an sp500/large-cap index. FAIL if a verdict rests on one.
- **U2 — declared purpose.** An sp500 spec is fine when the record says what it
  is *for* (golden, tripwire, liveness, smoke). FAIL if an sp500 run is
  presented as evidence about strategy behaviour without that framing.
- **U3 — grid cells.** A confirmation-grid cell on an index universe is a FAIL
  regardless of its result.
- **U4 — PIT year tracks the window.** When moving a broad cell to a different
  period, the composition vintage moves with it (`top-3000-2019.sexp` for a 2019
  window, not `top-3000-2000.sexp`). A stale vintage is a different defect, not
  a control.

Mechanically: grep the diff's specs for `universe_path`, and check any spec whose
numbers appear in the writeup's conclusions.

## Related

- `promotion-confirmation.md` — the grid; its universe-diversity axis is
  constrained by this file.
- `mechanism-validation-rigor.md` — a screen on the wrong universe fails check 1
  (estimand) before any of the other six.
- `memory/project_cell_e_2020_stall_regime` — broad universe is the lever.
- `memory/project_broad_universe_semantics`,
  `memory/project_pit_survivorship_inflation`.
