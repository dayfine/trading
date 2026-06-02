---
name: project_panel_runner_tmp_leak
description: "Panel_runner leaks per-fold /tmp/panel_runner_csv_snapshot_* dirs (~28M each, never cleaned); they accumulate across sessions and fill the container overlay → walk-forward runs die with ENOSPC mid-run"
metadata:
  node_type: memory
  type: project
  originSessionId: 06e65263-c45b-4e42-8886-80b198264969
---

**The leak.** Every walk-forward fold's `Panel_runner` builds an in-process CSV
snapshot at `/tmp/panel_runner_csv_snapshot_<hash>/` (one per job: ~530 symbols,
~26-30 MB for deep 1999-2026 data, smaller for 2010-2026). In the **normal**
path these ARE cleaned per-fold (verified: a live 510-job run held only ~8
snapshot dirs, disk flat). **The leak is on ABNORMAL exit** — a run that
crashes (ENOSPC, exception) or is killed (`kill -TERM` per sweep-hygiene)
orphans its in-flight + already-built snapshots, which then persist forever.
Over many crashed/killed runs they accumulate. Observed 2026-05-31: **1895
orphaned dirs ≈ 53 GB**, container `/tmp` (overlay, 79 GB) at **100%** — and
this pre-existing pile is what made a fresh deep run die on ENOSPC, which
orphaned *more*, a vicious cycle.

**Symptom.** A walk-forward run dies partway with:
`Fork_pool: job index N raised: (Failure "Csv_snapshot_builder: ... <SYM>.snap:
No space left on device")`. The logic is fine — it's disk. Note this is the
CONTAINER overlay filling, distinct from the host-disk / Docker.raw growth in
`.claude/rules/sweep-hygiene.md`; `df -h /` on the HOST can look healthy (74 GB
free) while the container `/tmp` is full.

**Fix (immediate).** No run active → purge:
`docker exec trading-1-dev bash -c 'rm -rf /tmp/panel_runner_csv_snapshot_*'`.
Freed 50 GB instantly. A single 51-fold × 10-variant deep run only needs ~14 GB
of snapshots; the pre-existing leak from prior sessions is what fills the disk.

**Pre-flight before any multi-fold deep run:** check + purge first —
`docker exec trading-1-dev bash -c 'ls -d /tmp/panel_runner_csv_snapshot_* 2>/dev/null | wc -l; df -h /tmp | tail -1'`.
Deep (pre-2009) snapshots are ~2× the size of 2010-2026 ones, so deep runs are
the most exposed.

**Real fix (open — issue #1393):** the per-fold cleanup works on success; it
needs to also fire on **abnormal exit** — an `at_exit` / signal handler (or
Fork_pool teardown) that purges `/tmp/panel_runner_csv_snapshot_*` when a run
crashes or is killed. Related: [[project_deep_history_infra]],
`.claude/rules/sweep-hygiene.md`.
