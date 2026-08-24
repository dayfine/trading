---
name: project-record-basis-divergence-0823
description: "Issue #2503: identical grid1-null config diverges from week one between 08-22 main and 2b11c60dd (305%→243%, 1270→1182 trades, MaxDD 39→24.5) — unflagged default-path behavior change suspected in #2492/#2500/#2501; bisect with 6mo probes pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: 41ec5d1b-6286-4c79-b63e-e9772f9eb5d9
  modified: 2026-08-24T11:52:40.254Z
---

Found 08-24 by the instrumented run: `instr-null` (verbatim grid1-null config,
main 2b11c60dd) vs the recorded grid1-null baseline (built ~08-22 main):
return 305.25→243.06, trades 1270→1182, MaxDD 39.10→24.48, Sharpe ~equal.
Divergence starts by 2000-01-29 (new run enters `AGN_old` etc.) — from-day-one
decision-path change, not mid-history drift.

Controls verified: config identical, warehouse `/tmp/snap_top3000_dedup_v5thin_adj`
untouched since 07-28, zero test_data commits, nondeterminism fixed since #2279.
RESOLVED 08-24: 6mo control probe at e64f8655b matches current main —
#2492/#2500/#2501 EXONERATED; 08-22 main already produced the "new" behavior.
The recorded baseline descends from an early-August (ladder-3-era) build with
uncommitted params ("renamed for the shared output root" per its own spec
comment). instr-null (build 2b11c60dd, params committed) proposed as the new
pinned record baseline. See #2503 comments.

Durable lesson: funding-grid never committed its params.sexp → baseline
code_version unrecoverable, which cost a day of suspicion against innocent
PRs — **ALWAYS commit params.sexp per arm.**

Bisect plan (issue #2503): 6-month probes (2000-01-01→06-30) at e64f8655 /
4141beda5 / b128b1d9e — divergence visible by 2000-01-29 so 6mo discriminates.

**Until resolved: no absolute comparison between pre-08-23 recorded runs and
current-main runs.** Within-build pairs (e.g. instr-null vs instr-unfreeze)
remain valid.
