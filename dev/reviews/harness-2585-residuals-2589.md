Reviewed SHA: feeb193f9a0da9c6f74a80c0ac59a1ca7e5cde13

## Structural QC — PR #2589

**Reviewed SHA:** `feeb193f9a0da9c6f74a80c0ac59a1ca7e5cde13`

_Posted by the GHA orchestrator on behalf of `qc-structural` (the agent has no `gh`/API access in this runtime). Verdict and checklist are the agent's; provenance noted so it is not misread as a self-review._

### Hard gates

| Gate | Result |
|---|---|
| H1 `dune build @fmt` | **PASS** |
| H2 `dune build` | **PASS** |
| H3 `dune runtest` | **PASS** — `adapter_effectiveness_check_test` 10/10; `deep_scan_linter_expiry_check` all assertions incl. new 3c/3d/3e |

### Structural checklist

| # | Check | Status | Notes |
|---|---|---|---|
| P1 | Functions ≤ 50 lines | NA | Shell; linter is OCaml-only |
| P2 | No magic numbers | PASS | |
| P3 | Config completeness | NA | Shell scripts |
| P4 | Public-symbol export hygiene | NA | Shell scripts |
| P5 | Internal helper naming | PASS | `ok()`, `bad()`, `write_adapter()`, `reset_pin_and_exceptions()` properly scoped |
| P6 | Test patterns (`.claude/rules/test-patterns.md`) | NA | Shell test scripts, not OCaml; Matchers/`assert_that` rules apply to OCaml only |
| A1 | Core module modification | NA | Isolated to `trading/devtools/checks/` |
| A2 | `analysis/` → `trading/trading/` tier boundary | NA | No `(libraries ...)` stanzas in the diff |
| A3 | No unnecessary modifications | PASS | 3 files: the two check scripts + `dev/status/harness.md`. `_index.md` untouched per contract. File list taken from `git diff --name-only $(git merge-base HEAD origin/main) HEAD`, **not** a git-ancestry walk (the #687 false-positive shape) |

### Additional checks

- **POSIX sh**: `posix_sh_check.sh` passes (85 scripts); no bashisms introduced.
- **Assertions actually execute** (the #2580 assertion-8 failure mode): 3c, 3d and 3e all appear in executed output, not merely in source.

### Independent non-vacuity reproduction

Not taken on trust from the author's transcript:

- **3c** pins the roll-up `W: …fixture_expired_field… has passed` line emitted when `check_11_linter_expiry.sh` is invoked with both `REPORT_FILE` and `FINDINGS_FILE` — i.e. `main.sh`'s real calling convention, not a synthetic one.
- **3d (MUTATION C)** — delete the date-branch `add_warning()` call: per-file `[EXPIRED]` detail survives, roll-up `W:` line disappears, assertion goes RED. Proves the **wiring** is load-bearing rather than a separate regex incidentally matching.
- **3e (MUTATION D)** — keep the call, corrupt its message: detail line and `W:` structure both survive, but the `W:` line no longer names the field; assertion goes RED. A second, independent break direction, which is what makes 3c's grep non-vacuous.

## Quality Score

**4** — Clean, mutation-proof harness fix; two independent break directions pin a real gap. No structural violations.

## Verdict

**APPROVED**
## Behavioral QC — PR #2589

**Reviewed SHA:** `feeb193f9a0da9c6f74a80c0ac59a1ca7e5cde13`

_Posted by the GHA orchestrator on behalf of `qc-behavioral` (no `gh`/API in this runtime). Verdict, attack log and observations are the agent's._

**⚠ Correction to my earlier structural-QC comment on this PR:** its `Reviewed SHA` read `feeb193fbc1de13b47f9c86dd2c8bcbea2b7fb2c`. **That SHA does not exist.** The structural agent reported only the short `feeb193f` and I expanded it into a fabricated 40-hex tail rather than resolving it. The correct tip — for both reviews — is `feeb193f9a0da9c6f74a80c0ac59a1ca7e5cde13`, and `dev/reviews/harness-2585-residuals-2589.md` has been corrected. This is the failure the 2026-08-27 summary logged as a `[low]`: a bogus sentinel reads as valid-but-non-matching, so `pr_gate_status.sh` would treat the structural verdict as permanently **stale**. Mine, not the reviewer's.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|---|---|---|
| CP1 | `.mli` docstring claims pinned | NA | Pure shell PR; script headers graded under CP4 |
| CP2 | PR-body "what it does" claims have committed tests | PASS | 3c → `deep_scan_linter_expiry_check.sh:230-243`; 3d → `:250-265`; 3e → `:272-288`. The "main.sh's real calling convention" claim verified: `deep_scan/main.sh:47` passes the findings file as `$2`, `:110-111` routes `W: ` into `## Warnings` (`:174`) |
| CP3 | Identity/invariant tests pin identity, not size | NA | 3c greps `^W: .*fixture_expired_field.*has passed` — content, not "a W: line exists". Attack B1 shows that distinction is load-bearing |
| CP4 | Guards named in docstrings have a test for the guarded scenario | PASS | Header R-5 block (`:37-52`) names three scenarios; 3c/3d/3e cover each |

### Weinstein domain checklist

**A1, S1–S6, L1–L4, C1–C3, T1–T4 — all NA.** Pure harness PR: shell test infrastructure under `trading/devtools/checks/`, no domain logic, no strategy config, no core-module change. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". No `BOOK-CHECK-NEEDED` items arise.

### Attack log — 13 independent non-vacuity attacks

The reviewer did not reproduce the author's transcript; it mutated the **real** `check_11_linter_expiry.sh` / `deep_scan/_lib.sh` in place and restored after each round.

**Direction 1 — break `add_warning()` internals, call site intact**

| # | Mutation | Result |
|---|---|---|
| A1 | `add_warning()` gutted to `{ :; }` | **CAUGHT** |
| A2 | counter increments but `$1` dropped (`W: (dropped)`) | **CAUGHT** — a `W:` line exists; the content grep rejects it |
| A3 | `flush_findings` emits `WARN: ` not `W: ` | **CAUGHT** |

**Direction 2 — call runs, cannot produce the roll-up**

| # | Mutation | Result |
|---|---|---|
| B1 | date branch retargeted `add_warning` → `add_info`, identical message, **decoy `W:` line still present** | **CAUGHT** — the strongest single result: the `^W: ` anchor + field-name content defeats "a W: line exists" vacuity |
| B2 | retargeted to `echo >&2` | **CAUGHT** |
| B3 | `flush_findings` call deleted | **CAUGHT** |

**Direction 3 — the #2580 shape: reword the call site so the test's own matcher can't see it, protection intact**

| # | Mutation | Result |
|---|---|---|
| C1 | `has passed` → `is in the past` | **RED (fail-closed)** |
| C2 | `${decl}` moved after `has passed` | **RED (fail-closed)** |
| C3 | reworded so 3e's `sed` becomes a no-op | **RED (fail-closed)** |

**Direction 4 — fixture tampering:** D1 entry removed, D2 date → 2099, D3 `review_at` removed — **all CAUGHT at 3a** with correct diagnosis.

**Direction 5 — E2 (see O2 below): NOT CAUGHT.**

**Decisive CI-level check.** The guard is red *through dune*, not just by hand: applying the exact R-5 repro to the real script and running `dune runtest devtools/checks/` gives **exit 1**. The rule at `trading/devtools/checks/dune:321-325` carries `(deps _check_lib.sh (universe))`, so it re-runs every time and dune's cache cannot hide it — the failure mode `code-health-discipline.md` records.

**12 of 13 attacks caught or fail-closed.**

### The author's self-declared limits — both verified accurate

- *"the missing-`review_at` branch never calls `add_warning()`"* — confirmed at `check_11_linter_expiry.sh:130-137`; attack D3 independently shows detail-only output.
- *"fixture is date-based only, so the milestone branch (~line 166) is unexercised"* — confirmed; the fixture's `review_at` has no `M[1-7]` token and the sibling conf files in the fake root are empty.

### Observations (non-blocking)

- **O1 — fails closed, but the printed diagnosis misleads.** C1/C2 print "…NOT surfaced in the roll-up W: findings line" while the dumped findings file two lines below plainly shows the correct `W:` line. Safe direction, but costs a future reworder minutes. Cheap fix: have 3d/3e assert their `sed` actually changed the file and fail with "the mutation's sed pattern no longer matches".
- **O2 — the one green-while-broken evasion (attack E2).** Special-casing the roll-up per label *inside* the shared `_scan_exceptions_conf` kills the warning for `linter_exceptions.conf` and `universe_deps_exceptions.conf` while the suite stays **green (exit 0)**. The header's "the function is shared, so it drops identically for all three" is true and explains why the bug was systemic, but reads as though the AE fixture protects all three — it does not. Requires a deliberate targeted edit, not R-5's accidental shape. Cheap to close: the fake root already creates an empty `linter_exceptions.conf` at `:158`; add one expired line and a second `^W: ` assertion. Suggest filing `H-EXPIRY-ROLLUP-SHARED-FN-ASSUMED`, `harness_gap: LINTER_CANDIDATE`.
- **O3 — the uncovered set is two branches wider than declared.** `_scan_exceptions_conf` has two further `add_warning` sites nothing exercises: conf-file-not-found (`:113`) and unrecognised-`review_at`-format (`:184`). The note is phrased non-exhaustively so it is not false, but the accurate summary is "the date-expired branch is the only one of the five `add_warning` sites in this function that is pinned."
- **O4 — producer half pinned, consumer half not.** Nothing pins that `main.sh:47` still passes a findings file or that `:110` still routes `W:` into `## Warnings`. Mitigating: `_run_check` is shared by all 12 checks, so that break is far louder. Out of R-5's declared scope.
- **O5 — two off-by-one counts in `dev/status/harness.md`.** R-1a's note says "all 9 assertions pass"; the runner reports **10**. R-5's says "prints 5 `OK:` lines"; it prints **6**. Both in verification instructions, not contract claims. Everything else in both notes was checked line by line and is accurate — including that the header already carried the corrected framing before the R-1a edit.

## Quality Score

**4** — Good. The central claim survived 13 independent attacks, including three built specifically to reproduce #2580's vacuous-green shape, and the guard was confirmed red *through dune*. Held below 5 by the one green-while-broken evasion (O2), an uncovered-branch set two wider than declared (O3), misleading diagnostics on benign rewording (O1), and two off-by-one counts (O5).

## Verdict

**APPROVED**
