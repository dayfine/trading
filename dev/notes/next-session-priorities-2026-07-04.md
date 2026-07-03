# Next-session priorities — 2026-07-04

**Supersedes** `next-session-priorities-2026-07-03.md`. Main is green; the
participation-measurement P0 is done and merged (#1843).

## What the 2026-07-03 PM session delivered (merged)

**P0 participation measurement → a finding bigger than the plan anticipated**
(`dev/experiments/scale-in-participation-2026-07-03/RESULTS.md`, ledger +
writeup amended in-place):

- **The scale-in add channel never functioned.** Adds emit as zero-width
  `StopLimit(close, close)` at Friday's close of a *strength*-signalling
  stock (`Weinstein_order_gen._entry_order` reused verbatim): gap-up triggers
  the stop, limit can never fill → press-the-winner is structurally
  unreachable; only adverse fills (retreat-to-close) are possible. 4/4 fills
  observed across all cells collided with same-day parent exits. Instrumented
  f011: 20–22 funded orders per variant, 1 filled each.
- **either_loose's broad "risk-smoothing" re-attributed:** Friday
  cash-reservation throttle (funded-but-unfillable adds deduct ≈$590–736k
  cumulative/fold from the same-Friday entry budget) + path divergence — not
  continuation-adds. In-fold-011 proof: pullback has more breadth (120
  entries vs 98) yet ≈ baseline; either_loose delivers the entire improvement.
- **Confirmed:** ½-sizing→breadth near-lossless (79–92% of new names =
  baseline `Insufficient_cash` near-misses; skips/Friday flat ~10); fat-tail
  tax visible per-decision ($169k→$98k avg entry, never restored).
- REJECT stands; scale-in stays a default-off axis.

## P0 — make the add channel physically testable (small code build)

The "untested promising shape" (full-size entries + continuation adds) is
blocked on three concrete defects, all now pinned:

1. **Fillable add order type.** Adds need stop-market above Friday close (or
   market-at-open), not zero-width `StopLimit(close, close)`. Scope: either a
   dedicated translation for `ManualDecision`-reasoned `CreateEntering` in
   `Weinstein_order_gen`, or an explicit order-type field on the transition.
   Default-off / no-op for existing paths (experiment-flag-discipline R1).
2. **Explicit `add_fraction` knob** in `Scale_in_detector.config` (v1 sizes
   adds as `1 − initial_entry_fraction` → full-size entries get zero-size
   adds). Default = the current derived value for backward-compat.
3. **Add/exit-coherence gate:** don't emit adds for symbols the same tick's
   laggard/stop/stage channels are exiting (all 4 observed fills were these
   collisions).

Then: fresh surface (full-size + adds via fixed order path) through
experiment-gap-closing WF-CV. Cheap, well-scoped, high information: it tests
the *designed* mechanism for the first time.

## Other open threads (carried)

- **Catastrophic-stop sibling alignment** (#1831 review): inert while
  `catastrophic_stop_pct = 0.0` + scale-in off; align to memoized pre-advance
  state if a spec ever arms both.
- **Docker.raw at 55 GB** (> 30 GB preflight threshold) — recompact via
  Docker Desktop GUI (user action) before the next multi-hour sweep.
- P2/P4 from the 2026-07-02 doc (≤4-week gate tuning; continuous-RS display)
  remain open, unchanged.

## Process notes (this session)

- jj `@`-left-behind bit again at session start (working copy sat on the
  pushed handoff commit; experiment files snapshotted into it). Recovered via
  `jj new main@origin` + `jj restore --from <old-commit> <paths>`. Rule
  stands: **position `@` first, write second.**
- After a squash-merge + `jj git fetch`, the local commit is auto-abandoned
  and the working copy can silently show PRE-merge file content — `jj new
  main@origin` before trusting disk state.
- Temp instrumentation (eprintf in a lib) + revert via `jj restore --from
  main@origin <file>` worked cleanly; instrumented results were bit-identical
  to uninstrumented (safe pattern for measurement reruns).
- Killed a 10h orphan `dune build` (dead QC wrapper, jjws-qc1833) holding a
  worktree; check `ps -o etime` for orphans before long runs.
