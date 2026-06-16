# Next-session priorities — 2026-06-17

**Supersedes** `next-session-priorities-2026-06-16-PM.md`. Check main CI green first.

---

## P0 — Snapshot format v2 (columnar mmap): the durable fix that unblocks top-3000

**This is the headline project for a fresh session.** Plan + research:
`dev/plans/snapshot-format-research-2026-06-16.md` (decision, layout, OCaml
library survey, step-by-step S0-S5, acceptance gate). Background:
`dev/experiments/panel-runner-perf-2026-06-16/WINDOW-PRUNE-FINDINGS.md`,
`memory/project_panel_runner_memory_ceiling`.

**Why:** the snapshot warehouse is whole-file sexp → whole-file decode → the
top-3000 26y backtest can't fit the 7.8 GB container at any cache (~2.95 GB
working set, thrashes). The fix is a **memory-mapped columnar (splayed) format**
on `Bigarray.map_file` (stdlib, zero-dep) — gives range-prune + column-prune
together → working set ~2.95 GB → **~130 MB** → fits at `cache≤1024`, no thrash,
no RAM bump, and speeds every broad-universe run.

**Decision already made (don't re-litigate):** implement a **minimal custom
columnar mmap format**, NOT Arrow/Parquet (OCaml Arrow bindings are immature —
C++ libarrow FFI or a young pure-OCaml reimpl; interop we don't need for an
internal, never-committed artifact). Not a novel invention — it's the standard
kdb-splayed / Arrow-IPC / npy mmap pattern, minimally instanced for our fixed
13-float schema. ~150-250 LOC + the `Daily_panels` cache redesign.

**Steps (full detail in the plan doc):** S0 spike (mmap round-trip, bit-identity)
→ S1 `Snapshot_format` v2 writer/reader (bump `schema_hash`) → S2 `Daily_panels`
range/column-aware mmap cache → S3 writers (`build_snapshots`) → S4 regenerate
warehouses + **goldens bit-identical (the gate)** → S5 tighten the over-reads.
**Acceptance:** goldens bit-identical AND the top-3000 26y 2000-26 matrix runs in
7.8 GB at `cache≤1024`, completes in ~hours.

**Low-risk to land:** no committed `.snap` corpora to migrate (0 in git); the
existing `schema_hash` auto-rejects stale local files; all changes golden-gated.

## Fast alternative (independent of P0)

If you want a top-3000 lens **before** the format work: **bump Docker RAM to
12-16 GB**, then rerun the top-3000 2000-26 matrix at `cache=4096` (the #1614
`Gc.compact` fix makes it fit) → ~2-6 h. This holds the whole-file working set in
RAM; it does not need the format change. The two paths are independent — RAM is
the quick unblock, format v2 is the durable fix.

## The payoff (what either path unblocks)

Rerun the **top-3000 2000-26 rolling-start matrix** → re-run the **factor-lens
H1/H2/H3 causal analysis on top-3000**. The top-1000 result
(`dev/experiments/rolling-start-matrix-t1k-2000-2026/ANALYSIS.md`,
`memory/project_factor_lens_regime_governs_edge`) established the **regime-shape**
(H1 dodge-correction r=−0.79 CONFIRMED; H3 entry-supply DEAD — regime governs the
edge, not entry-selection). top-3000 is needed for the **net-edge sign** (top-1000
realized edge was all-negative — the edge needs top-3000 breadth / the fat tail).

## State as of this handoff (2026-06-16 session)
- **All PRs merged, main green, 0 open PRs.** Shipped: #1614 (`Gc.compact`), #1617
  (README top-line numbers, regenerable), #1618/#1620/#1621 (docs/lens/memory),
  branch cleanup (27 stale branches).
- **Lens done** on top-1000 (#1620). **README numbers** on main (1998-12-22 →
  2026-06-12: SPY BAH +888.9%, BRK-B +1132.4%, SPY-Weinstein +408%, Sector-ETF
  +528.9%; both Weinstein trail B&H on this bull window — expected).
- Matrix NOT running (intentionally paused for the format/RAM decision above).
- New memories: `project_panel_runner_memory_ceiling`,
  `project_factor_lens_regime_governs_edge`.

## Deferred / unchanged
- Initiative B (margin / long-short Phase 5) — still oversight-gated, the profit
  lever, unchanged from prior handoffs.
- A2 per-start DD projection bug — still open (affects DD columns, not edge/CAGR).
