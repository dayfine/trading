---
name: project-codex-weekly-hold-1021
description: Codex weekly hold (10-21) LIFTED 10-22 evening — quota reset early to 0 %; delegate again, guarded by codex_quota.sh
metadata:
  type: project
---
10-21: user said Codex had 23 % weekly left → no new Codex tasks until 10-27 09:48 PT.
10-22 ~22:00 PT: user reported the reset; `codex_quota.sh` read 0 % five-hour and 0 % weekly. Hold lifted; #3394 (review-pack D4/D5/D6/D10) handed off.

**Why:** pacing Codex's quota across projects.
**How to apply:** before each hand-off run `codex_quota.sh --guard 70 --weekly-guard 85`. Codex runs locally (`codex --yolo` in the user's terminal), picking up `agent/codex` + `ready-for-agent` issues; its CI-image builds share the Docker VM, so don't let it build beside a 26y cell.
