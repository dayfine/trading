# Next-session priorities — 2026-08-08

**Supersedes** `next-session-priorities-2026-08-04.md` (its P0 — the 07-31 live
run — shipped 08-02 via #2179; the 08-04 doc predates this whole fill-model
faithfulness arc and is now stale). This session (08-07/08) ran the fill-model
faithfulness program end to end: two default-off fixes, a validation invariant,
an evaluation harness, a confound resolution, an honest A/B ladder, and a
trade-level dissection that found the real lever.

## Shipped this session (all through full gates)

- **#2227** fill-model findings + plan docs.
- **#2236** V12 stop-gate-consistency invariant (`Post_run_validator`) — the
  standing guard for stop-vs-fill faithfulness.
- **#2230** faithfulness-report harness (per-year whipsaw / hold / stop-width +
  2-arm divergence); reproduces the manual numbers.
- **#2237** confound resolution: the "94% deep stops" were an **E-basis metric
  artifact**, not a gate breach; committed record scenario regens
  bit-identical.
- **#2238** **Fix #1** `sim_entry_fill_next_open` (default-off) — Market entry
  fills at the next fresh bar's open, not the stale signal-bar open.
- **#2241** **Fix #2** `freeze_entry_at_first_breakout` (default-off) — resting
  entry E pinned to the first-qualifying breakout, no weekly chase.
- **#2245** ladder v2 A/B results + **`trade-dissection` skill** + the P0 plan
  below.
- **#2242** fill-basis `stop_fill_distance_pct` trades.csv column (append-only;
  gate-basis distance, so analyses stop reading the E-basis artifact).

## What the session established (the load-bearing findings)

1. **Honest A/B (ladder v2, `dev/notes/fill-model-ladder-v2-2026-08-08.md`):**
   the record rule survives an honest next-open fill — **+7,321%** (vs +8,367%
   stale-fill baseline; ~12.5% cost), still ~24× the honest book ticket
   (+310%). The edge is NOT the optimistic stale-open fill.
2. **The real lever (`project_entry_E_stale_high_bug` ⭐):** the entry level
   **E (`suggested_entry`) is anchored to a stale year-old high** —
   `scan_max_high` over 8–60 weeks back (`stock_analysis.ml:283`,
   `screener.ml:127`). **35%** of trades have E ≥ 1.2× the fill (mean 1.29×);
   **64%** have the E-derived screener stop land ABOVE the fill. AXTI 2025:
   close 2.03, E 4.05 (2×) → record ignores E, buys at market 2.05, rides to
   $56M; book's limit at 4.05 fills 2.5 months late at 4.13, whipsawed out next
   day. Book §5.1: stop = below support floor; ">15% risk = prefer other
   candidates" is a **screening filter**, not the `stop_anchor_at_entry_base`
   tighten-to-fit mechanism (which exists only to paper over inflated E). Our
   arm labels are inverted: the "record" stop is the book-faithful one.

## P0 — faithful StopLimit entry with the right basis

**Plan: `dev/plans/entry-ticket-right-basis-2026-08-08.md` (on main).** The
record's Market entry is theoretically wrong (no breakout discipline — buys at
market whether or not price broke out). Weinstein's entry is a StopLimit at the
breakout level; we want that, but resting at a **reachable current-range top**
(not the stale 52-wk E), with a **support-floor stop** (never E-derived), and
the 15% rule recast as a **candidate filter**.

Build order (cheapest, highest-leverage first — all default-off → axis → grid):

1. **Audit-field add** (cheap): log `close_at_decision`, `ma_value`,
   `local_range_top` on the audit `entry_decision`, so E-provenance is visible
   in the artifact and `trade-dissection` doesn't need `dump_snap` to see
   close-vs-E.
2. **Entry-ticket local-range anchor** — anchor the ticket to
   `local_range_top` (short window, ~4–8 wks) while the 52-wk breakout stays a
   screening/scoring signal. Window is an axis to sweep.
3. **Support-floor stop + 15%-as-filter** — stop = support floor off a sane
   basis; drop `stop_anchor_at_entry_base` as the stop mechanism; a >15%
   floor-stop drops the candidate (not re-anchors).
4. **Ladder v3** — faithful-StopLimit vs record vs current-book, top-3000 26y,
   + `trade-dissection` on the top divergences → then WF-CV + confirmation grid
   before any promotion (`promotion-confirmation`).

Use the **`trade-dissection` skill** to verify each change at trade level, and
**`screen-rigor`** on any read-only screen. Every change default-off; `main`
behavior unchanged until a spec flips it (`experiment-flag-discipline` R1/R2);
spine intact (`weinstein-faithful-core` — this *increases* faithfulness).

## Not blocking / context-on-demand

- **V12 position_id join** — under-counts on resting-order (StopLimit) arms
  because the audit decision date ≠ trade entry_date; join by position_id.
  Follow-up when the book arm's validation matters.
- Ladder v2 artifacts kept at `.sweep-output/ladder-v2-artifacts/` (local);
  confound regen at `.sweep-output/confound-regen-artifacts/`.
- Warehouse `/tmp/snap_top3000_dedup_v5thin_adj` (1.3G) — verify present before
  any re-run (ephemeral `/tmp`).

## State at handoff

Main green, working copy on main, disk ~52G free, no stray worktrees, no
running sweeps. All 8 PRs above merged. Memory refreshed
(`project_entry_E_stale_high_bug` ⭐, `project_fill_model_inversion` updated).
