---
name: project_ops_fastpath_bypassed_qc
description: "2026-08-13: PR #2309, titled 'ops(budget): record …($32.1972)' and described as 'additive observational data only', actually carried the full P0.1 linter FEATURE diff onto main and merged with ZERO reviews. The ops fast-path label is what waved it through. Verify gh pr view <N> --json files on any ops/budget/daily PR before merging."
metadata: 
  node_type: memory
  type: project
  originSessionId: fb5eee5b-32ea-4e7b-9429-8f3f1f94d659
  modified: 2026-08-13T20:18:14.433Z
---

**What happened.** PR **#2309** on 2026-08-13 was titled
`ops(budget): record 2026-08-13-31700595897 ($32.1972)` and described as
*"Automated budget-record landing… Additive observational data only."* Its actual
file list:

```
dev/budget/2026-08-13-31700595897.json              <- what the title describes
trading/devtools/checks/linter_file_length.sh       <- P0.1 FEATURE code
trading/devtools/checks/linter_file_length_test.sh  <- P0.1 FEATURE code
trading/devtools/checks/dune
dev/status/cleanup.md, dev/status/harness.md
```

It merged with **zero reviews** (`gh pr view 2309 --json reviews` → `[]`),
bypassing both qc-structural and qc-behavioral. The P0.1 `.mli` file-length
linter is therefore on `main` un-QC'd, and PR **#2308** — the branch that was
*supposed* to carry it through the gates — is now a byte-identical no-op
(verified: all three code files `git diff origin/main origin/harness/mli-file-length-coverage`
are empty).

Found by the #2308 behavioral agent, which noticed its review target was
identical to main and traced back to find why. Independently verified.

**Why it matters.** The bypass was not a human waving a rule; it was an
automated ops fast-path whose *label* ("budget record", "observational data
only") is what earned the no-review treatment, while its *content* was a feature
branch's diff. Nothing in the title, body, or the docs-only heuristics would
catch it — only the file list does. Because it is automated, it recurs.

**How to apply.** Before merging ANY `ops/*`, `budget`, or `daily` PR — and
before trusting a "docs-only / additive data only" claim from any automation:

```sh
gh pr view <N> --json files --jq '[.files[].path]'
```

If a single path is outside `dev/budget/`, `dev/daily/`, `dev/health/`,
`dev/audit/` or `dev/status/`, it is not an ops record and needs the full three
gates regardless of its title. `dev/scripts/pr_gate_status.sh` already computes
the docs-only classification from the file list rather than the title, so
running it on ops PRs surfaces this — the failure was merging without looking.

**Open follow-up:** the linter code on main carries an un-actioned CP4 finding
from #2308's behavioral review — the header justifies tracking `.ml` and `.mli`
populations separately (so one population's `@large-module` markers cannot
subsidize the other's 11% opt-out cap) with no fixture exercising that guard.
The fix belongs on a new PR against main, not on #2308, which is now a no-op.

The fix itself is sound and was independently verified: `TOTAL_MLI=439` (was 0,
proving the blind spot is genuinely closed) and `weinstein_strategy_config.mli`
measures **97 signature lines** against the 500 hard limit, so counting signature
lines rather than raw lines removed the need for extraction without adding a
single `@large-module` marker or limit bump.

Related: [[feedback_pr_merge_gates]], [[feedback_pr_merge_ci_gate]],
[[feedback_docs_only_admin_merge]].
