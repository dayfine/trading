---
name: docker-raw-auto-trim
description: Docker Desktop 29.4 auto-TRIMs Docker.raw within seconds of in-VM deletes (47→33 GB on 09-09 with no GUI step); the real hog is container /tmp — 732 leaked bar_reader_in_memory_* dirs (9.4 GB) + stale agent _build scratch (qcb*/bd*/wt-build, 1.3 GB each). Delete inside first; "Apply & restart" recompaction is unnecessary.
metadata:
  type: project
---

**Measured 2026-09-09 23:10 PT.** `docker exec trading-1-dev rm -rf /tmp/bar_reader_in_memory_* /tmp/qcb2574 /tmp/bd2565* /tmp/wt-build` took the container overlay 47 → 32 GB, and `du -sh Docker.raw` on the host read 33 GB (from 47) within a minute, host free 25 → 62 GB. No Docker Desktop restart. `docker system df` is useless here (reports the 30.9 GB writable layer as 0 reclaimable).

**Where the space goes:** `panel_runner`/`scenario_runner` leak one `/tmp/bar_reader_in_memory_<hex>` per run ([[panel-runner-tmp-leak]]); 732 of them had accumulated since July. QC/feat scratch dirs named `/tmp/qcb<PR>`, `/tmp/bd<PR>*`, `/tmp/wt-build` are full dune `_build` trees (1.3 GB each) nobody removes. Warehouses `/tmp/snap_top3000_*` are 0.5–1.3 GB each; keep the current basis ([[record-rebase-2026-09-09]]: `_v10dedup` ×3) and whatever committed reads cite (`_v7mark` ×3); the rest are deletion candidates but a rebuild costs hours, so ask first.

**How to apply:** when `Docker.raw` > 30 GB or host free < 50 GB (`sweep-hygiene.md` pre-launch), run `docker exec trading-1-dev du -sh /tmp/* | sort -rh | head`, delete the leaked/scratch classes, re-read `du -sh Docker.raw` a minute later. Reach for the GUI recompaction only if it did not shrink. Defunct `scenario_runner` zombies under PID 1 (8 seen, weeks old) hold no memory or disk — ignore.
