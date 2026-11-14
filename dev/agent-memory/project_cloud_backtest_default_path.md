---
name: project-cloud-backtest-default-path
description: Agreed 2026-10-31 — backtests move to cloud by default once data identity, checkpoint/resume and RAM fit are proven; staged plan
metadata:
  type: project
---
User agreed (2026-10-31) to make cloud the default place for backtests/chains/sweeps, local kept for interactive debug, book work and fallback.

Gates before the default flips: (1) data identity — private bucket holds the PIT warehouse + snapshots, manifest root (#3476, tool #3493) proves cloud == local; fresh EODHD fetch is NOT the record's data (revisions). (2) long cells survive the session — checkpoint/restore #3477 (#3485 = PR 3). (3) RAM fits — 26y cell peaks ~5.9 GB RSS / 2.5 GB heap.

Staged plan: manifest → bucket (user creates) → paired broad-5y local vs cloud at same SHA, byte-identical, record wall/RAM/session limit → 26y with a deliberate kill+resume → flip default.

First cloud smoke 2026-10-31 (issue #3476 comment): 50 large caps + SPY/GSPC/11 sector ETFs, 2024, completed in 12.7 s; fetch 63 series 35 MB 31 s; cold build 6.5 min. Snags: root-owned checkout vs uid 1000 image, single-dash fetcher flags, proxy CA missing in image trust store, no start-date flag, runner needs breadth/macro/sectors.csv/universe, gh issue comment blocked (use MCP). Fold these into docs/howtos/claude_cloud_sessions.md.

Progress 2026-11-01: bucket created (R2 `trading-data`, private, creds in ~/.config/trading/r2.env chmod 600); full data/ uploaded as bars/data-20261101.tar.gz (613 MB, 2.1 GB raw, 11,888 symbols); script `dev/scripts/r2_bars.sh` in PR #3499 (rework iter 1). #3485 merged (checkpoint PRs 0-4 on main; 5-7 left). User still to add R2_* secrets + `*.r2.cloudflarestorage.com` allowlist to the cloud env.

QUEUED DECISION (user agreed 2026-11-01): after the 26y cloud kill+resume passes, SHRINK local Docker VM 7.75 GB -> ~5 GB (keep 3-agent cap), watch `docker stats` peak over a full 3-agent QC wave, then -> ~4 GB if well under. Also drop local snapshot warehouses from Docker.raw (likely 10-20 GB). Do NOT shrink before that gate: a verdict-bearing 26y still needs ~6 GB locally. Open item: perf_pit_smoke.sh (~4.5 GB, full warehouse) must move to cloud or run on a temporarily raised VM. Context: 16 GB Mac, VM footprint 8.2 GB fixed, swap hit 10.7/12 GB on 11-01 with an emulator open.

**Why:** frees the 7.75 GB local container (QC never waits on a chain), parallel seeds/grids, removes host disk/swap pressure.
**How to apply:** don't move a verdict-bearing run to cloud before gate (1) passes; related [[project-eodhd-terms-private-bucket]], [[project-env-cloud-label]].

**2026-11-02 progress.** User added R2 secrets + allowlist. Data identity PASSED: cloud pull 32 s, manifest root e0348f01 equal on both sides (11,888 symbols). Parity cell (goldens-broad bull-crash-2015-2020 at 2210132b2) FAILED: cloud 51.3 %/203 trades vs local 99.5 %/179. Cause #3506: shard path uses the raw last char, so `*_old` symbols (stored under uppercase shard `C/D/COMP_old`) only resolve on case-insensitive macOS; Linux (cloud AND GHA) silently drops ~30 of top-1000-2015. Fix + cloud rerun dispatched (cloud session `issue-3506-shard-case`). Cloud cell: 5 min, 0.5 GB RSS; warehouse build 3 min. Gate (1) is now "parity after #3506", not "data identity".

**2026-11-02 parity, second cause:** after #3510 the cloud still read 985/30 vs local 988/27. The Mac store had the shard dir itself named `data/L/d` (LGND, LLL_old, LNKD); macOS resolves it, the R2 tarball carried it verbatim, Linux missed it. Renamed to `L/D`, re-pushed as `bars/data-20261102` (sha fa41c258…). The hash manifest root matched despite this, so it does not check path case — check `ls data/*/ | grep '[a-z]'` before any push.

**2026-11-02: data identity CONFIRMED.** Cloud parity rerun at 20824663d (archive data-20261102) byte-identical to local on actual/trades/equity/audit; #3506 closed. Gate 1 done; next: #3477 PR 6/7 (PR 6 cloud session trig_01SZvJmku2i6WuUxn9Kg1H6X), then 26y kill+resume.

**2026-11-09: DEFAULT FLIPPED.** rk-k0 (26y record cell) reproduced byte-identically in cloud (attempt 3) from R2 `v12wk-9236` + `corpact-2026-10-27` (dividends/splits tarball, bars-only warehouse otherwise misses dividends). Trap: builds before #3510 (e.g. record SHA fc78391dd) read raw-case shard `L/d/*_old`; main reads `L/D`. Tarball stays upper-case; pre-#3510 runs move `*/D/*_old` to `*/d/` after unpacking (howto, #3557). Runbook line in docs/howtos/claude_cloud_sessions.md. Next: Docker VM shrink 7.75→5 GB (user setting); #3535 item 2 twin-dedupe decision.

**2026-11-08: Docker VM shrunk to 5 GB / 6 CPUs** (user applied in Docker Desktop; was 7.75 GB / 10). Settings file is TCC-protected: the terminal cannot edit it, so the user changes it in the UI. Next step per plan: watch `docker stats` peak over a full 3-agent QC wave, then consider 4 GB.
