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

**Launching + building (2026-10-08).** Start sessions with RemoteTrigger `create` (`job_config.ccr.environment_id = env_011CV2KYxeXLs26U85qQo3rV` "Default", `sources` = the GitHub repo, `run_once_at` a minute ahead). The environment has no setup script, but sessions CAN build: dockerd is available, the CI image `ghcr.io/dayfine/trading-ci:latest` is preloaded, and a `trading-1-dev` container may already exist. For a git worktree, run a second container with both mounts (`-v $REPO:/workspaces/trading-1 -v $REPO:$REPO`) so the worktree's `.git` pointer resolves. A brief that does not spell this out gets a session that assumes "no toolchain" and does read-only QC (happened 10-08 on the #3202/#3207/#3208 lane). Cloud sessions end their turn when idle: tell them to poll CI with a Monitor until-loop. They never merge; the local dispatcher merges on green gates.
