---
name: project-env-cloud-label
description: "GitHub label `env/cloud` (created 2026-09-27) marks issues a Claude Code cloud session can do end to end — code + tests + QC in the CI image, no warehouse/backtest/book."
metadata:
  node_type: memory
  type: project
  originSessionId: 13438ee6-bde6-4f74-839d-eef43a46dd35
  modified: 2026-09-28T05:28:52.826Z
---

User 2026-09-27, after cloud-authored PR #2997 merged: a cloud session is "another container to do some work" while the local container runs backtests.

Label `env/cloud` = cloud-suitable: code/test/QC only, no local data warehouse (`/tmp/snap_top3000_pit_v11pit`), no `.sweep-output` artifacts, no book file (book never leaves the machine). First tagged: #2975, #2984, #2989, #2998, #2999.

**Why:** local container is exclusive to one backtest at a time and no agents may run beside a multi-hour backtest ([[feedback-container-capacity-scheduling]]); cloud sessions have no such limit.

**How to apply:** when filing an issue that needs no local data, add `env/cloud`. When a cloud PR arrives, its QC verdicts may be run in the authoring session and posted as PR reviews at the tip — check they are at the current tip and that CI (not the author's claim) is green; they carry no mutation probes, so note that before merging. Local-only work (backtests, book-faithfulness reads, artifact analysis) stays untagged.
