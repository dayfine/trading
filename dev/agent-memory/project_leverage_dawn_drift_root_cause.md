---
name: leverage-dawn-drift-root-cause
description: "07-26 dawn-surface baseline drift = mid-run workspace mutation, not code; M4 .827 is the clean baseline; sweeps must build/run from pinned worktrees"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3f2dbf6c-5e5e-4297-9d15-8571a3c1ccb4
---

The 2026-07-26 leverage-dawn surface's baseline (.766/34.6/17.7) vs M4's
(.827/36.2/14.1) drift was root-caused 2026-07-27 (issue #2108, PR #2109):
the run executed from the parent workspace tree while the 07-26 morning
session mutated it mid-run (picks-stack commits, jj snapshots, git-head
import at 11:53 PT inside the 09:55–17:41 PT run window). Fingerprint:
baseline folds 000-008 (early wall-clock) differ, 009-012 bit-identical to
M4. Controlled repros — clean 96c4c5f build × both specs × cache 1024/4096 ×
**the actual dawn-run binary** — all reproduce M4's fold-000 85.13/1.472
bit-exactly; the run's 59.80 is irreproducible from committed state.

- **Clean baseline of record: M4's .827/36.2/14.1** (chain HEAD=0764fdebc —
  the ledger's "7ef57ed2" was wrong). Never reuse the dawn run's .766.
- Suspects #2085 / #2081 exonerated. SNAPSHOT_CACHE_MB (1024 vs 4096) does
  NOT change results.
- Dawn-run folds 000-008 (all arms) untrusted. Hygienic full re-run
  (pinned worktree, 2026-07-27, `/tmp/sweeps/leverage-dawn-v2-clean/`)
  **RE-CERTIFIED THE REJECT**: baseline 13/13 bit-identical to M4 (parity
  restored); dawn Sharpe .616→.437 monotone, MaxDD 22.7→44.9, best gate
  5/13 — all cells FAIL; falsifier fold-012 fired in every arm. Ledger
  `2026-07-27-leverage-dawn-clean-rerun` (PR #2119). Cite clean-rerun
  numbers, never the 07-26 dawn-cell aggregates.
- Durable fix: `sweep-hygiene.md` §Pinned-worktree builds — chains build+run
  from `git worktree add --detach <sha>`, log the RUN TREE's HEAD, abort on
  dirty. A parent-tree `git rev-parse HEAD` label lies when jj @ tracks a
  different commit than git HEAD.

Single-fold bisect harness (reusable): `/tmp/sweeps/drift-bisect/` — mini
spec = one 730d fold of the 13x2y window + one no-op corner variant; ~12 min
per datapoint at parallel 2. [[leverage-dawn-reject]] [[chain-scripts-single-instance]]
