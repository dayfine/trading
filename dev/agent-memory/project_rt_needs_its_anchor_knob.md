---
name: project-rt-needs-its-anchor-knob
description: "entry_freshness_basis=Range_top_breakout is INERT-or-worse without entry_anchor_local_range_weeks=4 — it measures freshness against local_range_top, which that knob defines. Armed alone in the live picks generator it produced ZERO candidates; adding the anchor restored 20. Every ladder-v4 rt arm sets 4; the record-convention base and the live config set it zero times."
metadata:
  node_type: memory
  type: project
  originSessionId: 7959dddf-3101-4cab-8f02-c90b77a7d8fd
  modified: 2026-08-21T03:21:03.474Z
---

**`Range_top_breakout` has a prerequisite knob, and arming it alone fails
silently.** Its own `.mli` says so:

> "Freshness is measured from the breakout above the ticket anchor
> (`entry_anchor_local_range_weeks` → `Stock_analysis.t.local_range_top` —
> deliberately the *same* level the resting order uses…). A non-late Stage-2
> candidate is admitted iff the close is at or within `proximity_pct` (5%)
> below that anchor **and** the MA is not declining **and** the anchor clears
> the MA."

At the knob's `0` default the anchor is unset, so the "within 5% below anchor"
test has nothing to bind against.

## Measured, 2026-08-20 (live weekly picks, as-of 2026-08-14, top-3000)

| config | long candidates |
|---|---:|
| live baseline | **20** (bit-identical to the committed `f88c277d5` report) |
| + rt, **no anchor** | **0** |
| + rt, **`entry_anchor_local_range_weeks 4`** | **20** |

With the anchor: 17 of 20 unchanged, PAY/TPC/INVX out, DRI/BLK/NDAQ in.

## Who sets it

- **Every ladder-v4 rt arm** sets `entry_anchor_local_range_weeks 4`.
- `staging-record-convention/*` (including `fullbook-graded`) sets it **zero
  times** — so any bundle built on that base inherits the `0` default.
- `dev/weekly-picks/live-config-overrides.sexp` sets it **zero times**.

So the trap is specifically: build an rt bundle on the record-convention base,
inherit `0`, and get a silent zero.

## Why it is a trap rather than an error

The generator's `--config-overrides` documents that **unknown keys fail
loudly** — and `entry_freshness_basis` IS a known key, so it parses, validates
and arms. Nothing warns. The failure surfaces only as an empty candidate list,
which reads like a market condition rather than a misconfiguration.

⚠ **A backtest smoke does NOT catch it.** Armed without the anchor, a 1-year
2019 top-3000 cell still produced 93 trades vs 35 for the control — a large,
plausible-looking delta. That proved the field was **read**; it did not prove
it was **correctly configured**. Liveness is not correctness — the same gap as
a test that exercises a predicate without pinning its bounds
([[feedback-pin-every-element-of-a-category]]).

## The check

Before arming any basis/mode flag, grep its `.mli` docstring for the fields it
*reads*, and confirm each is set in the same overlay. Arming a consumer without
its producer is a distinct failure class from a wrong value, and it is quieter.

Related: [[project-entry-E-stale-high-bug]] (same knob at `0` makes
`_build_candidate` fall back to the resistance `breakout_price`),
[[project-stop-gate-not-entry-anchor]],
[[project-rangetop-freshness-is-a-drawdown-lever]].
