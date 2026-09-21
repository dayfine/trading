---
name: project_snapshot_cache_handle_cap_thrash
description: v2 warehouse cache binds on the mmap-HANDLE cap not MB; knob SNAPSHOT_MAX_MMAP_HANDLES shipped #2882 (2026-09-20) — 4-month PIT smoke 27m23s → 6m15s, evictions 5.34M → 0, byte-identical output; chain default 12,000
metadata:
  type: project
---

**Finding (2026-09-20, index-veto salt 0 / #2839 comments):** on a v2 columnar
warehouse `Daily_panels` charges an mmap entry only its int32 date index, so
`SNAPSHOT_CACHE_MB` never binds; the hard-coded 256 open-handle cap in
`daily_panels.ml` was the effective cache size. A weekly pass over 9,915 PIT
symbols cycled that LRU: 118.5M misses / 112M evictions per 26y cell, identical
on null and arm; wall variance (arm +43 %, s0 8h33m vs null 5h58m) = per-miss
cost (openfile + fstat + whole-file map + header parse). The 36,000 s cell guard
then killed the arm's salt 1 at 92.5 % done.

**Fix shipped:** PR #2882 (merged 477522b7c, 2026-09-20 22:50 PT) —
`Daily_panels.create_with_handle_cap ~max_mmap_handles`; `create` reads env
`SNAPSHOT_MAX_MMAP_HANDLES` (default 256, unchanged); the panel-runner cache-cap
line logs it. Smoke (4-month PIT spec, 9,915 symbols, salt 0): cap 256 27m23s /
569 misses per symbol / 5.34M evictions vs cap 12,000 **6m15s** / 31 per symbol /
**0 evictions**, `actual.sexp` + `trades.csv` md5 identical. Budget for 12k
readers: ~0.3 GB heap, 1 fd + 1 mapping each (fd limit 1,048,576,
`vm.max_map_count` 262,144).

**How to apply:** every chain script sets `SNAPSHOT_MAX_MMAP_HANDLES` ≥
n_symbols (index-veto `chain-veto.sh` default 12,000). A PIT 26y cell should
drop from 6–11 h toward the classification floor; measure it on the first
relaunched cell and record here. Follow-ups: #2878 occupancy/heap on the cache
line (`ready-for-agent`, needs the container); #2839 stays open until the 26y
number is in. Related: [[feedback_weekly_perf_review_budget]],
[[project_snapshot_format_v2]], [[feedback_container_capacity_scheduling]].
