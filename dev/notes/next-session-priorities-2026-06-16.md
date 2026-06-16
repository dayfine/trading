# Next-session priorities — 2026-06-16 (overnight handoff)

**Supersedes** `next-session-priorities-2026-06-15.md`. Written during the
autonomous overnight session (user away ~10h). Check main CI green first
(`session-rampup`).

---

## ⛔ The 26y rolling-start matrix is NOT running — paused for a perf fix you must pick

The 2000-2026 (26y) top-3000 rolling-start factor matrix was killed mid-run. It
projected **~60-108h** (2.5-4.5 days) and OOM'd the 7.8 GB container at any
useful cache size. Per your "measure & optimize before rerunning" directive I
diagnosed it instead of riding it out.

**Full writeup: `dev/experiments/panel-runner-perf-2026-06-16/ANALYSIS.md`** —
read it. Summary:

- **Root cause (measured + code):** the snapshot LRU (`daily_panels.ml`) caches
  each symbol's **entire history file**; for top-3000 × 26y that's a **~2.95 GB
  working set, independent of the backtest window** (a 1.3y probe used the same
  ~3.6 GB as 26y). The weekly full-universe screen keeps all 3015 symbols hot,
  so `cache=1024` thrashes → re-decode every scan → 98% CPU → the ~50× slowdown.
- **Fork-doubling OOM:** the parent holds ~3 GB of (freed-but-not-returned)
  factor-precompute memory; each `Fork_pool` child COW-inherits it → cache≥2048
  OOM'd at the fork.

**Shipped tonight (safe, behavior-preserving): PR #1614 — `Gc.compact ()` before
the fork.** Makes the parent lean so children don't double the footprint;
validated past the prior OOM point. Necessary but not sufficient (the cache
byte-estimate undercounts ~1.6×, so cache big enough to hold the working set
still exceeds 7.8 GB).

### YOUR DECISION before any rerun (pick one):
1. **Bump Docker RAM to 12-16 GB** (Settings → Resources → Apply & restart),
   relaunch at `cache=4096`. With #1614 it fits → ~50× faster → matrix **~2-6h**.
   Fastest unblock, no code.
2. **Window-prune the `Daily_panels` cache** (code fix, no RAM): cap per-symbol
   cached rows to a ~35wk sliding window → working set 2.95 GB → ~90 MB → fits
   `cache=1024`, helps every broad run. Shared infra; needs golden bit-identity
   review — I did NOT land it autonomously (silent pruning errors would drift
   results). Recommended durable fix.
3. **Stopgap `cache=2048` + #1614** (fits post-compact): ~2-3× faster (~20-40h).

I recommend **(1) now to unblock, (2) as the real fix**. Don't rerun until one
is in. Rerun command + scenario/warehouse paths are in the ANALYSIS.md repro section.

---

## ✅ Done tonight (autonomous)

- **PR #1614** — `Gc.compact` perf fix (qc-structural + qc-behavioral APPROVED;
  auto-merging on CI). The only post-QC change was trimming a comment to satisfy
  the 300-line file-length linter (no logic change).
- **PR #1601** (weekly opam deps) — MERGED.
- **PR #1604** (harness: wire `record_qc_audit_test.sh`) — auto-merging (was
  just behind main; rebased).
- **PR #1612** (short-side ranking differentiation) — MERGED via the GHA queue I
  set up: the live 2026-06-12 picks showed all shorts at uniform grade C/score
  50; root cause was Virgin==Clean support flattening + RS=None on the fresh
  universe. feat-weinstein added `w_virgin_support` (Virgin→70 > Clean→65). The
  GHA handoff worked end-to-end.
- **Branch cleanup** — deleted 27 stale merged/orphan remote branches; only
  `main` + (briefly) the in-flight PR branches remain.

## Pipeline / recs status (unchanged from 06-15)
- Live weekly picks baseline = **2026-06-12** (`dev/weekly-picks/58ff1e79/`),
  Bearish macro → no longs (correct), Stage-4 short watchlist (now differentiated
  by #1612). 3 days stale; no auto-regen. Runbook in the 06-15 doc §pipeline.

## GHA status
Orchestrator is healthy but idle on features (the dispatchable backlog is
warehouse-gated/local or human-gated). The one fixture-testable GHA item
(short-side ranking) shipped (#1612).

## Locked priority order (unchanged; from 06-14 grill)
`[0 DONE] recs` → `[1] policy universe (deprioritized)` → `[2] factor-lens 5b
(columns DONE #1607; causal analysis BLOCKED on the matrix rerun above)` →
`[3] WF-CV the 28y` → `[4] margin / long-short (oversight-gated, Phase 5)`.
The factor-lens causal analysis is the thing blocked by the matrix perf issue.
