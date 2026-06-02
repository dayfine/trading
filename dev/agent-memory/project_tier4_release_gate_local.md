---
name: tier-4 release-gate is local-only — checklist landed
description: GHA workflow can't run tier-4 (data path mismatch); release-gate runs locally via dev/scripts/perf_tier4_release_gate.sh; checklist in dev/notes/tier4-release-gate-checklist-2026-04-28.md (PR #655)
type: project
originSessionId: 1b3c22f4-6967-4e7d-bdd3-6cfe881e12e5
---
Tier-4 release-gate (`.github/workflows/perf-release-gate.yml`) is fundamentally broken on GHA: scenarios use `Full_sector_map` sentinel = "load all symbols from sectors.csv". Workflow sets `TRADING_DATA_DIR=$WS/trading/test_data` (7-symbol CI fixture). Per-cell exits in 0-1s on universe load.

**Why:** runner size is fine (8 GB at N=1000 fits per engine-pool matrix `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`). The issue is purely data-path mismatch — full sectors.csv (~10K symbols) + per-symbol bars live under `data/`, not in the in-repo `trading/test_data/`.

**Decision:** scope tier-4 OUT of GHA. Run locally at release-cut time via `dev/scripts/perf_tier4_release_gate.sh` inside the devcontainer with the canonical `data/` mounted. The GHA workflow stays in the repo as a placeholder but disabled (or remove the cron — it's `workflow_dispatch`-only already).

**How to apply:** when cutting a release, walk `dev/notes/tier4-release-gate-checklist-2026-04-28.md` (PR #655). Pre-flight `data/` freshness via `ops-data`, invoke `dev/scripts/perf_tier4_release_gate.sh` in the devcontainer, capture metrics, run `release_perf_report` against current vs prior release dirs, decide go/no-go, optionally tighten `expected` ranges in `goldens-broad/*.sexp`. GHA workflow stays as smoke-shape, no scheduled cron.
