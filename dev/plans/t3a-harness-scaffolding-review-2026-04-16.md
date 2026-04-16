# Plan: T3-A Harness Scaffolding Review (Check 7 in deep_scan.sh)

**Date:** 2026-04-16
**Item:** T3-A — `health-scanner` deep scan, harness scaffolding review
**Branch:** `harness/t3a-harness-scaffolding-review`

---

## 1. Context

`trading/devtools/checks/deep_scan.sh` currently implements six checks:
1. Dead code detection
2. Design doc drift
3. TODO/FIXME/HACK accumulation
4. Size violations
5. Follow-up item count
6. QC calibration audit

T3-A in `dev/status/harness.md` has one remaining open sub-item:
"harness scaffolding review (flag unused harness components)".

The design in `docs/design/harness-engineering-plan.md` §T3-A states:
> **Harness scaffolding review**: flag harness components (QC checklist items,
> orchestrator steps) that have not triggered a correction in the last N runs —
> candidates for removal as model capability grows.

The task prompt narrows the definition of "harness components" to:
- Shell scripts in `trading/devtools/checks/`
- OCaml linter binaries in `trading/devtools/{fn_length_linter,cc_linter,nesting_linter,...}`
- Agent-compliance helpers

"Unused" = not referenced from dune files, GitHub workflow YAMLs, other
`devtools/checks/*.sh` scripts, or any `.claude/agents/*.md` definition.

Output shape: Check 7 appends to `dev/health/<DATE>-deep.md` under
`## Harness Scaffolding` with per-item PASS or WARNING lines.
No FAILs — this is a heuristic audit, not a gate.

---

## 2. Approach

Implement Check 7 as a shell function block inside `deep_scan.sh`, following
the same pattern as Checks 1–6: iterate over harness component files, test
each one against the heuristics, accumulate findings into `WARNINGS`/`INFO`
via `add_warning`/`add_info`, and write a dedicated detail section
`## Harness Scaffolding` at report-generation time.

**Three heuristics (kept minimal to avoid noise):**

### H1: Shell script not referenced anywhere meaningful
A script in `trading/devtools/checks/` is "unused" if its filename does not
appear in:
- Any `dune` file under `trading/devtools/checks/`
- Any `.github/workflows/*.yml` file
- Any other `*.sh` file under `trading/devtools/checks/` (source/called chain)
- Any `.claude/agents/*.md` agent definition

`_check_lib.sh` is exempt — it's a library, not a standalone script.
`deep_scan.sh` is also exempt — it's run manually/externally, not from dune.

### H2: OCaml linter binary not attached to any dune runtest rule
A linter binary (`fn_length_linter.exe`, `cc_linter.exe`, etc.) is unused if
its basename does not appear in the `dune` file under `trading/devtools/checks/`
as a `%{exe:...}` reference.

### H3: Agent definitions referencing a harness script path that no longer exists
Scan `.claude/agents/*.md` for path patterns like `devtools/checks/*.sh`,
`trading/devtools/checks/*.sh`, or similar. For each match, check whether the
path resolves to a real file from repo root.

**Why these three and not others:**
- H1 and H2 cover the primary "dead harness component" risk — scripts/binaries
  that were scaffolded but never wired in.
- H3 covers the inverse — agent definitions that refer to deleted paths (broken
  references). These are operationally dangerous: the health-scanner might try
  to invoke a script that no longer exists.
- We do NOT invent a "hasn't triggered a correction in N runs" metric because
  there is no audit trail that records which harness check fired and caused a
  rework. That metric would require T3-D audit trail integration and is out of
  scope for this item.

**Output:** `## Harness Scaffolding` section appended to the existing deep
report. Each harness component gets one line:
- `PASS: <component>` — all heuristics clear
- `WARNING: <component> — <reason>`

No FAIL lines (this is advisory, not a gate).

---

## 3. Files to change

| File | Change |
|---|---|
| `trading/devtools/checks/deep_scan.sh` | Add Check 7 block + `## Harness Scaffolding` section in report |
| `.claude/agents/health-scanner.md` | Update Phase 2 Step 8 to describe Check 7 and its output format |
| `docs/design/harness-engineering-plan.md` | Annotate T3-A harness-scaffolding-review as complete |
| `dev/status/harness.md` | Flip `[~]` → `[x]` with completion note |
| `dev/plans/t3a-harness-scaffolding-review-2026-04-16.md` | This plan file |

No dune file changes required — `deep_scan.sh` is not wired into `dune runtest`
(it runs weekly, standalone).

---

## 4. Risks / unknowns

- **False positives on H1**: `write_audit.sh` and `deep_scan.sh` are run
  by humans or the health-scanner agent directly, not from dune or workflows.
  These must be explicitly exempted from H1.
- **Sandboxing**: The `deep_scan.sh` script uses `repo_root` from `_check_lib.sh`
  when run standalone. Check 7 uses the same `$REPO_ROOT` that the rest of the
  script already computes.
- **`TRADING_IN_CONTAINER` vs local paths**: The script already handles this
  via `_check_lib.sh`'s `repo_root()` function. No new path logic needed.

---

## 5. Acceptance criteria

- `sh trading/devtools/checks/deep_scan.sh` produces a `dev/health/YYYY-MM-DD-deep.md`
  that contains a `## Harness Scaffolding` section.
- All current scripts in `trading/devtools/checks/` that ARE referenced get
  PASS lines.
- The section reports WARNING for any component that genuinely matches a
  heuristic.
- `dune build && dune runtest` continues to pass (no changes to dune-tracked
  files that could break the build).
- health-scanner.md Phase 2 Step 8 describes what Check 7 does and what
  output format it produces.

---

## 6. Out of scope

- Wiring Check 7 into `dune runtest` — deep_scan.sh is intentionally standalone
- Heuristic for "hasn't triggered a correction in N runs" (requires audit trail integration)
- Checking `write_audit.sh` or `ops-data` agent scripts beyond what H1 covers
- Any changes to feature code under `trading/trading/`, `trading/analysis/`, or
  `analysis/`
