# Next-session priorities — 2026-07-04 (rev 2: #1843 root-cause RETRACTED)

**Supersedes** `next-session-priorities-2026-07-03.md`. Main is green.

> **rev 2 note:** the first revision of this doc (merged in #1844) set a P0
> based on #1843's "add channel never functioned / StopLimit(close,close)"
> finding. **That finding was retracted** — it was an artifact of a real
> reporting bug (`Metrics.extract_round_trips` chimeras sibling round-trips).
> Adds fill routinely (4/4 sp500 f001; 19/20 broad f011). The corrected
> record is `dev/experiments/scale-in-participation-2026-07-03/RESULTS.md`;
> the ledger + writeup amendments were replaced in the correction PR.

## What 2026-07-03→04 delivered (merged)

- **#1843** participation measurement: the P0 question is answered and valid
  — freed cash reaches the near-misses (79–92% linkage), ½-sizing converts
  size into breadth ~1:1, fat-tail tax visible per-decision. The add-channel
  "root cause" section of that PR was subsequently retracted (see above);
  the REJECT verdict and all three original ledger WHYs stand unchanged.
- **#1844** first revision of this handoff (P0 superseded by rev 2).
- Correction PR (this one): RESULTS.md rewritten with retraction, ledger +
  writeup amendments replaced, this doc revised.

## P0 — fix `Metrics.extract_round_trips` for sibling positions — **DONE (#1847, merged 2026-07-04)**

Shipped as planned: quantity-aware FIFO pairing (`List.fold` + `_pair_step` /
`_close_round_trip` / `_pop_matching_entry`), bit-identical for
single-position streams (all goldens / default runs unaffected), TDD'd with 4
sibling regression tests (qty pairing, same-day unordered exits, equal-qty
FIFO, mismatched-qty FIFO fallback) + updated `metrics.mli` docstring.
Gates: CI green + qc-structural + qc-behavioral APPROVED at tip (one rework
commit for the nesting linter). **Caveat that persists: trades.csv /
win_rate / total_trades from scale-in runs executed BEFORE #1847 remain
unreliable — re-run, don't reuse.**

## P1 — carried prerequisites for the untested full-size+adds shape

1. **Explicit `add_fraction` knob** (`Scale_in_detector.config`): v1 sizes
   adds as `1 − initial_entry_fraction`, so full-size entries get zero-size
   adds. Default = derived legacy value (bit-identical, R1).
2. **Live add-order shape:** live path emits `StopLimit(close, close)` for
   adds (`Weinstein_order_gen._entry_order`) = adverse-selection shape; the
   simulator fills at Market (documented TODO divergence). Needs a fillable
   live shape (stop-market above close) before any promotion. Live-only —
   does not affect backtests.

(The "add/exit-coherence gate" from rev 1 is DROPPED — the observed
"add/exit collisions" were chimera artifacts, not real behavior.)

## Other open threads (carried)

- **Catastrophic-stop sibling alignment** (#1831 review): inert while
  `catastrophic_stop_pct = 0.0` + scale-in off.
- **Docker.raw at 55 GB** — recompact via Docker Desktop GUI (user action)
  before the next multi-hour sweep.
- P2/P4 from the 2026-07-02 doc (≤4-week gate tuning; continuous-RS display)
  remain open, unchanged.

## Process notes

- **The retraction lesson (screen-rigor applies to harness data too):** the
  wrong #1843 conclusion came from trusting trades.csv as ground truth for a
  sibling-position mechanism. Round-trip-derived artifacts (trades.csv,
  win_rate, total_trades) are NOT valid for scale-in runs until P0 lands.
  When measuring a new mechanism, verify the reporting layer handles the
  mechanism's new structure before reading conclusions off it — trace the
  pipeline (emit → order → fill) at least once.
- Instrumented reruns (temp eprintf, revert via `jj restore --from
  main@origin`) remain bit-identical and cheap — the trace that caught this
  took one 11-min rerun.
- jj: after a squash-merge + fetch, the local commit is auto-abandoned and
  disk can show pre-merge content — `jj new main@origin` before trusting
  disk state. Position `@` first, write second.
