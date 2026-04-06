# Harness Engineering Plan

This document defines the strategy for evolving the agentic development harness
from a basic Generator/Evaluator loop into a layered system of deterministic
gates, specialized reviewers, behavioral verification, and automated feedback
loops.

**Tracking status:** `dev/status/harness.md`

**Guiding principles:** `docs/design/engineering-principles.md` — the *why* behind this plan.

**Reference reading:**
- Anthropic: [Building long-running agentic apps](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- Martin Fowler: [Harness Engineering](https://martinfowler.com/articles/harness-engineering.html)
- Stripe: [Minions — one-shot end-to-end coding agents (part 1)](https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents)
- Stripe: [Minions — one-shot end-to-end coding agents (part 2)](https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents-part-2)
- OpenAI: [Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering)

---

## Target State

The mature system has three human responsibilities:

1. **Requirements** — write and approve design docs and AJD agent definitions for
   new features. This is the primary creative input.
2. **Controls** — define and tune quality thresholds: gate criteria, merge policy,
   performance benchmarks, escalation rules. These are checked into the repo and
   versioned.
3. **Results** — read the daily orchestrator summary and periodic performance
   reports. Evaluate milestone outcomes (does the system trade well?). Handle
   escalations.

Everything else — agent dispatch, QC, PR creation, merging, health scanning — is
automated. The human does not review individual PRs in steady state.

### Human interface artifacts

| Artifact | Frequency | Human action |
|---|---|---|
| Daily orchestrator summary (`dev/daily/`) | Daily | Read; handle escalations |
| Performance gate report | At each M5/M7 gate | Approve thresholds |
| Health scan report (`dev/health/`) | Weekly | Review; create follow-up items |
| Escalation notices (in daily summary) | As triggered | Unblock and decide |

### Escalation policy

Automation pauses and flags for human review when:
- Any QC NEEDS_REWORK on the same feature for 3+ consecutive runs (design problem)
- Performance gate regression on any PR
- A feat-agent proposes modifying an existing core module (Portfolio, Orders,
  Position, Strategy, Engine) rather than building alongside
- A behavioral QC finding indicates a requirement is ambiguous or missing from the
  design doc
- The health scanner reports design doc drift (module structure no longer matches
  `weinstein-trading-system-v2.md`)
- A new architectural decision is needed that is not covered by existing design docs

All other outcomes (clean passes, expected NEEDS_REWORK resolved on retry) proceed
automatically.

### Auto-merge criteria

A PR merges automatically when all of the following hold:
- All deterministic gates pass (`dune fmt --check`, `dune build`, `dune runtest`,
  architecture layer test, golden scenarios, performance gate)
- `qc-structural` APPROVED
- `qc-behavioral` APPROVED
- No escalation flags raised by either QC agent
- Feature is within the scope of an existing design doc (no new architectural
  decisions)

If the auto-merge criteria are met but a human escalation flag exists, the PR is
created and held — the daily summary surfaces it for human decision.

---

## Background

The project already has several harness elements in place:

- `CLAUDE.md` as the repository-local source of truth for agent behavior
- `feat-*` agents as generators, `qc-reviewer` as evaluator (GAN-inspired split)
- `lead-orchestrator` for parallel agent dispatch and dependency sequencing
- `dune build && dune runtest` as the primary deterministic gate
- Status files + interface stability gates for sequencing

The gaps are: the QC reviewer conflates structural and behavioral concerns; there
are no format or architecture enforcement gates; the feedback loop requires
manual human dispatch at every step; and there is no behavioral verification
tied to actual trading performance.

---

## Architecture: Harness Layers

```
┌─────────────────────────────────────────────────────────────┐
│  HUMAN  (requirements · controls · results)                  │
│  Design docs | Quality thresholds | Daily summary review     │
└──────────────────────────┬──────────────────────────────────┘
                           │ daily trigger
┌──────────────────────────▼──────────────────────────────────┐
│  ORCHESTRATOR  (lead-orchestrator, runs daily)               │
│  Read status | Inject context | Dispatch agents | Report     │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│  GENERATORS  (feat-* agents)                                 │
│  Implement design | Write tests | Update status              │
└──────────────────────────┬──────────────────────────────────┘
                           │ READY_FOR_REVIEW
┌──────────────────────────▼──────────────────────────────────┐
│  EVALUATORS  (qc-structural → qc-behavioral, sequential)     │
│  Code patterns | Domain correctness | APPROVED / REWORK      │
└──────────────────────────┬──────────────────────────────────┘
                           │ APPROVED
┌──────────────────────────▼──────────────────────────────────┐
│  DETERMINISTIC GATES  (dune runtest, always binary)          │
│  fmt | build | tests | arch layer | golden (M4+) | perf (M5+)│
└──────────────────────────┬──────────────────────────────────┘
                           │ all pass
         ┌─────────────────┴─────────────────────┐
         │ no escalation flags                    │ escalation flag
         ▼                                        ▼
  ┌─────────────┐                       ┌──────────────────────┐
  │  AUTO-MERGE │                       │  HOLD → daily summary│
  └─────────────┘                       │  human decision       │
                                        └──────────────────────┘

Async: health-scanner (weekly) → dev/health/YYYY-MM-DD.md
```

---

## Tier 1 — Immediate (no new infrastructure required)

### T1-A: Hard deterministic gates

Add `dune fmt --check` as a required step before any PR, alongside the existing
`dune build && dune runtest`. This enforces formatting as a structural property,
not a style suggestion.

Add an **architecture layer test**: a single OCaml test file that verifies no
module under `analysis/` imports from `trading/trading/`. Encodes the dependency
boundary as a deterministic node that fails `dune runtest`.

**T1-A+: Custom structural linters** — encode CLAUDE.md code patterns as
deterministic checks that fail `dune runtest`, so they are enforced mechanically
rather than by QC agents (which are probabilistic). Key principle: *structural
constraints are more effective than instruction constraints* — when an expert's
"taste" becomes a linter, it is a fleet-wide multiplier on every agent run.

Linters to implement:
- **Function length**: OCaml AST-based check, >50 lines = test failure (hard
  limit from CLAUDE.md)
- **Magic numbers**: grep-based check for numeric literals in
  `analysis/weinstein/` not routed through a config record
- **Missing `.mli` coverage**: public functions in `.ml` that are not exported
  in the corresponding `.mli`

Once these are linters, `qc-structural` no longer needs to check them —
it gets cheaper, faster, and fully deterministic for these items. Every
subsequent NEEDS_REWORK finding should prompt the question: *can this be
made a linter?* Over time, the QC checklist shrinks as items migrate into
deterministic gates.

### T1-B: Split `qc-reviewer` into two specialized agents

The current monolithic reviewer mixes code quality and domain correctness. Split
into:

**`qc-structural`** (fast, cheap, runs first):
- Hard checks: `dune build`, `dune runtest`, `dune fmt --check`
- Code pattern checks: function sizes, no magic numbers, config completeness,
  `.mli` coverage, internal helpers prefixed with `_`
- Architecture checks: no modifications to Portfolio/Orders/Position/Strategy;
  no `analysis/` → `trading/` imports
- If FAIL: stops here, behavioral review does not run

**`qc-behavioral`** (domain-focused, runs after structural passes):
- Uses `weinstein-book-reference.md` as the authority for domain rules
- Checks: stage classification rules match book definitions exactly
- Checks: stop-loss rules match Weinstein's trailing stop methodology
- Checks: screener cascade logic (macro gate → sector filter → scoring → ranking)
  matches design spec
- Checks: test cases are testing the right domain behaviors, not just passing
- Does not check code style — that is structural's responsibility

Update `lead-orchestrator` to spawn both QC agents: structural first, behavioral
only if structural passes.

### T1-C: Formalize evaluation criteria in agent definitions

Add a `## Acceptance Checklist` section to each `feat-*.md` agent definition
with explicit objective items. These map directly to what the QC agents check,
making the evaluation method ($K$) a first-class artifact of each agent's AJD.

### T1-E: Pre-flight context injection (feedforward layer)

The harness is currently feedback-heavy (QC agents, gates, escalation). This
adds the **feedforward** side: ensuring agents have the right information
*before* they start, not just after they fail.

On every feat-agent dispatch (not just retries), the orchestrator injects:
- Current `dune runtest` failure summary for the feature's test directory
- Last QC review findings for this feature (if any prior review exists)
- Open follow-up items from the feature's status file
- Relevant sections of the design doc for this feature (not the whole doc)

This is a deterministic step in the blueprint — the orchestrator runs these
checks and assembles the context before spawning the agent. The T3-C item
(dynamic context injection) is absorbed here; it applies from the first run,
not just on retry.

### T1-F: Lead-orchestrator blueprint format

Define an explicit **blueprint** for each feature lifecycle — a sequence of
deterministic nodes and agentic steps, rather than treating everything as agent
spawns. Deterministic nodes are shell commands run by the orchestrator directly;
agentic steps are agent spawns.

Example blueprint for a feature:

```
[preflight: inject context (deterministic)]
→ [feat-agent: implement (agentic)]
→ [dune fmt --check (deterministic)]
→ [dune build && dune runtest (deterministic)]
→ [qc-structural (agentic)]
→ [qc-behavioral, if structural APPROVED (agentic)]
→ [gate suite: arch layer test + golden + perf (deterministic)]
→ [merge decision: auto or HOLD (deterministic)]
```

The blueprint makes the boundary between deterministic and agentic work
explicit. Deterministic nodes are not token-consuming agent calls — they are
cheap, fast, and 100% reliable. The agent's job is only to do work the
deterministic nodes cannot.

### T1-G: Max-iterations policy in feat-agent definitions

Agents can spin indefinitely on a failing test — each iteration costs tokens,
time, and budget. Diminishing returns set in quickly. Define a maximum
build-fix iteration limit in each feat-agent definition: if the agent has
attempted N fix cycles without passing `dune build && dune runtest`, it must
stop, report its partial state and the blocker, and let the orchestrator decide
(retry vs. escalate). Recommended cap: 3 build-fix cycles per session.

### T1-H: Tool curation per agent type

Reducing available tools improves agent performance by narrowing the
unconstrained possibility space. Each agent definition specifies its allowed
tool subset — agents do not get tools they will never legitimately use.

Suggested subsets:
- **feat-agents**: Read, Write, Edit, Glob, Grep, Bash (build/test only), WebFetch
- **qc-structural**: Read, Glob, Grep, Bash (read-only: build/test/lint)
- **qc-behavioral**: Read, Glob, Grep (no write, no shell — review only)
- **health-scanner**: Read, Glob, Grep, Bash (read-only) — no modifications
- **lead-orchestrator**: all tools (it is the coordination layer)

### T1-D: QC non-determinism policy

LLM reviewers can disagree with themselves: NEEDS_REWORK on one run, APPROVED on
the next, same code. In a manual workflow this is annoying; in an auto-merge
system it is a correctness problem.

Policy: both QC agents must produce **structured output** (a filled checklist with
per-item PASS/FAIL/NA, not freeform prose) so that decisions are traceable and
comparable across runs. The overall verdict (APPROVED / NEEDS_REWORK) is derived
mechanically from the checklist, not inferred from narrative.

Additionally, `qc-structural` must produce the same verdict on the same commit
(it is fully deterministic — checklist items are grep/build/test results). If it
does not, that is a harness bug. `qc-behavioral` is inherently softer, so its
checklist items must be scoped to verifiable claims ("stage classifier test covers
all 4 stage transitions: YES/NO") not subjective judgements.

The checklists for each agent are defined alongside the agent in its `.md` file
and versioned with it.

---

## Tier 2 — At M5 (backtesting infrastructure ready)

### T2-A: Golden scenario test suite

A set of data-driven regression tests with fixed synthetic or real historical
inputs and known-correct outputs. These run as part of `dune runtest` and serve
as behavioral unit tests for the domain logic — making the Weinstein book rules
executable and verifiable.

Examples:
- Stage 2 breakout: price series with 30-week MA rising, price above MA, volume
  expansion → screener must grade A or A+
- Stage 3 top: price above MA but MA flattening → screener must not generate a
  buy candidate
- Stop state machine: given entry price, stop price, trailing rules → assert
  exact stop price at each week step
- Macro gate: bearish macro score → assert zero buy candidates regardless of
  individual stock quality

Files: `analysis/weinstein/screener/test/regression_test.ml`,
`trading/weinstein/simulation/test/regression_test.ml`

### T2-B: Performance gate

After a reference backtest is established (default config, fixed historical
period), encode minimum performance thresholds as a test in
`trading/weinstein/simulation/test/performance_gate_test.ml`. The reference
config and expected metric values are checked into
`dev/benchmarks/reference_backtest.json`.

Gate behavior: any PR touching screener, stage, RS, stops, or order_gen must
pass this test. The specific threshold values (Sharpe, max drawdown, win rate)
are set empirically from the first calibration run — not guessed in advance.

Note: simulation tests that use randomness must be seeded deterministically so
this gate does not produce false failures.

### T2-C: Walk-forward regression gate (M7)

Once the parameter tuner is built, check in `dev/benchmarks/best_config.json`
(the best config from the last tuning run). Add a test asserting that
`out_of_sample_sharpe(best_config)` stays above a threshold. Any change to
analysis logic that degrades this requires explicit human sign-off.

### T2-D: Live trading gate (M6 — unconditional human sign-off)

M6 connects the system to a real broker with real money. This is categorically
different from all prior milestones and is **exempt from auto-merge** regardless
of gate results.

Rules:
- Any PR that touches the live execution path (broker client, order submission,
  live DATA_SOURCE) requires explicit human review and approval, unconditionally
- This rule is encoded as a hard override in `dev/config/merge-policy.json`:
  no amount of gate passes unlocks auto-merge for these paths
- Before M6 go-live, a paper-trading validation period (minimum 4 weeks, same
  code as live) must show performance consistent with the backtesting baseline
- The paper-trading result is written to `dev/milestones/m6-paper-trading.md`
  and reviewed by the human before the live flag is enabled

This is the one gate the human never delegates.

---

## Tier 3 — Ongoing infrastructure

### T3-A: Health scanner agent (`health-scanner`)

Two modes — **fast** (runs after every orchestrator run) and **deep** (runs
weekly). Does NOT make changes — only reports findings.

**Fast scan** (post-run, lightweight, ~1 minute):
- Stale status files: READY_FOR_REVIEW features with no QC review within 24h
- New numeric literals in `analysis/weinstein/` added in this run (grep delta)
- Any `dune build` or `dune runtest` failures on `main` since last run

**Deep scan** (weekly, writes to `dev/health/YYYY-MM-DD.md`):
- **Dead code**: OCaml unused-variable warnings, functions in `.ml` not exported
  in `.mli` and not called anywhere
- **Design doc drift**: module structure vs. what `weinstein-trading-system-v2.md`
  describes (renamed modules, missing interfaces, undocumented new modules)
- **TODO/follow-up accumulation**: open follow-up items across all status files,
  surfacing any older than two weeks
- **Config completeness drift**: numeric literals in `analysis/weinstein/` not
  routed through the config record (grep-based check)
- **Size violations**: functions >35 lines, files >300 lines
- **Stale status files**: features in unexpected states
- **QC calibration audit**: compare past QC verdicts (from audit trail) against
  regression history — identify checklist items that passed but later caused
  regressions, flag them as candidates for strengthening or linting
- **Harness scaffolding review**: flag harness components (QC checklist items,
  orchestrator steps) that have not triggered a correction in the last N runs —
  candidates for removal as model capability grows. Principle: *every harness
  component encodes an assumption about what the model cannot do on its own;*
  review those assumptions periodically.

### T3-B: AVR loop closure in `lead-orchestrator`

Currently the loop requires a human to notice a feature is ready and manually
trigger QC. Close the loop:

1. After spawning a feat-agent and receiving its result, check if it
   self-reported READY_FOR_REVIEW in its status file
2. If yes, automatically spawn `qc-structural` in the same orchestrator run
3. If structural passes, spawn `qc-behavioral`
4. Write combined result to `dev/reviews/<feature>.md`
5. Human only reads the final report and makes the merge decision

The human remains in the final gate; the loop closure eliminates manual dispatch.

### T3-C: Dynamic operational context injection

*Superseded by T1-E* — pre-flight context injection is now a Tier 1 item that
applies on every dispatch, not just retries. T3-C is retained only for
enhancements beyond the T1-E baseline: injecting cross-feature context (e.g.,
a related feature just merged and changed a shared type), or summarizing
multi-run QC trends rather than just the last single review.

### T3-D: Audit trail for automated decisions

Every automated action (QC verdict, auto-merge, gate result, escalation) writes
a structured record to `dev/audit/YYYY-MM-DD-<feature>.json` containing:
- Timestamp, feature name, commit hash
- Which agent ran, with what prompt hash (so agent definition version is traceable)
- Gate results (each gate: PASS/FAIL + value)
- QC checklist results (per-item, not just overall verdict)
- Final action taken (MERGED / HELD / ESCALATED) and reason
- **`harness_gap` field** (on NEEDS_REWORK records): the QC agent's assessment
  of whether the finding is a candidate for a deterministic linter/test, or
  requires ongoing inferential review. This is the mechanism by which QC
  findings migrate into gates over time — the health scanner's QC calibration
  audit reads these fields and surfaces patterns.

This is the primary debugging surface when a regression gets through. The health
scanner includes an audit trail integrity check: every merged commit in `main`
since auto-merge was enabled must have a corresponding audit record.

### T3-F: Architecture graph analyzer and dependency rules

The current architecture layer test (T1-A) hardcodes one known boundary. As the
system grows, more boundaries emerge — simulation vs. live execution, analysis
vs. order generation, data layer vs. everything else — and hardcoded rules won't
keep up.

**Three-state rule lifecycle:**

| State | Enforcement | Who manages |
|---|---|---|
| `proposed` | None — under discussion | Human reviews and approves |
| `monitored` | Soft — health-scanner reports violations | Agent surfaces, human decides |
| `enforced` | Hard — fails `dune runtest` | Deterministic gate |

**Canonical source of truth: `docs/design/dependency-rules.md`**

A document that lists all known architectural dependency rules with:
- The rule itself (module A cannot import from module B)
- The rationale (why this boundary exists)
- The current state (`proposed` / `monitored` / `enforced`)
- The enforcement mechanism (for `enforced` rules: which dune test)

The first entries should document the existing known boundaries:
- `analysis/` cannot import from `trading/trading/` (currently enforced by T1-A)
- `trading/weinstein/simulation/` cannot be imported by the live execution path
  (simulation wraps the pipeline; it must not leak into live code)
- `analysis/` can only receive data via the `DATA_SOURCE` interface, not by
  importing concrete data-layer implementations directly

**Architecture analyzer (runs as part of T3-A deep scan):**

1. Scan the actual import graph of the codebase (grep `open`/`include` in `.ml`
   files, build a module → module dependency map)
2. Compare against `dependency-rules.md`:
   - Flag violations of `monitored` and `enforced` rules
   - Flag dependencies present in the codebase but not covered by any rule
     (undocumented dependencies → proposed rule candidates)
   - Flag rules that are vacuously true (module renamed or deleted)
3. Output: a proposed diff to `dependency-rules.md` for human review — new
   proposed rules for undocumented dependencies, rule promotions where violations
   are consistently zero

**Rule promotion path:**

When the analyzer reports zero violations of a `monitored` rule for N consecutive
deep scans, it proposes promoting the rule to `enforced` and generates the
corresponding dune check. The human approves the promotion; the generated check
gets committed as a T1-A+ style linter. The architecture test suite grows
organically from the doc rather than being hand-maintained.

### T3-E: Cost and token budget visibility

Each orchestrator run records estimated token usage and cost per agent spawn to
`dev/daily/<date>.md` (alongside the existing summary). The orchestrator has a
configurable per-run budget cap in `dev/config/merge-policy.json`; if a run
would exceed it, it spawns the highest-priority agents first and defers the rest
to the next run, noting this in the summary.

This prevents runaway costs during periods of high activity (many features
in-flight simultaneously) and gives the human a cost signal in the artifact they
already review.

---

## Maintenance Cycles

The harness is primarily designed for forward feature work, but the codebase also
accumulates maintenance debt: cross-cutting refactors, pattern consistency fixes,
and quality improvements. Without an explicit model for this, maintenance work
either blocks features silently or never happens.

### The two classes of maintenance work

**Blocking refactors** — refactoring that must complete before a feature's next
phase can start. Example: a state machine wrapper that both `weinstein_stops` and
`stage` depend on before their respective clean-up work can proceed. These are
urgent: they sit on the critical path.

**Non-blocking refactors** — improvements that should happen eventually but don't
block anything now. These accumulate in `## Followup / Known Improvements` sections
of status files. Individual items are small; the risk is that they pile up into an
unmanageable backlog.

### Maintenance cycle triggers in `lead-orchestrator`

The orchestrator checks two conditions at the start of each run **before**
dispatching feat-agents:

1. **Blocking refactors** (immediate): read `## Blocking Refactors` from every
   feature status file. If any are non-empty, dispatch a refactor work item for
   each one before spawning the dependent feat-agent. The refactor item goes
   through the full blueprint (agent → gates → QC → merge) just like a feature.

2. **Non-blocking accumulation** (scheduled): count total open followup items
   across all status files. If the count exceeds a threshold (default: 10 items),
   replace one feature slot in the current run with a maintenance cycle — an agent
   pass focused on clearing the oldest/highest-value followup items. After the
   threshold is crossed, one maintenance cycle runs per N feature cycles
   (default: every 3rd run). The threshold and ratio live in
   `dev/config/merge-policy.json`.

### Status file conventions

Feature status files gain two sections:

```markdown
## Blocking Refactors
- [ ] <description> — blocks: <next phase>
  (empty when nothing is blocking)

## Followup / Known Improvements
- <description>
- <description>
  (items accumulate here; cleared by maintenance cycles)
```

The lead orchestrator reads `## Blocking Refactors` as a prerequisite check.
The health-scanner deep scan counts `## Followup / Known Improvements` items
and reports the total in its weekly output, with a flag when the threshold is
crossed.

### Refactor agent

Refactor work items use the same feat-agents (each feat-agent owns its own
module scope). For cross-cutting refactors (touching multiple feature areas),
a standalone prompt is passed to the most appropriate feat-agent with a
`## Refactor Mode` header instead of the normal feature development prompt.
The refactor mode prompt includes:
- The specific pattern or abstraction to implement
- The files to change
- The expected quality improvement (what metric improves, by how much)
- The same MAX ITERATIONS cap and TDD workflow as feature work

### Quality metrics

Refactors should produce measurable improvements. Two metrics are tracked:

**Cyclomatic complexity (CC)**: extend the function length linter (already uses
`compiler-libs`) to also compute CC per function. CC = number of branches
(match arms, if/else, when guards) + 1. Report functions with CC > 10 as
warnings (not failures — CC is a quality signal, not a hard gate like length).
Store per-function CC in `dev/metrics/cc-YYYY-MM-DD.json` after each
orchestrator run so trends are visible.

**QC quality score**: add a `## Quality Score` section to qc-behavioral output:
a 1–5 integer rating with a one-sentence rationale, covering code clarity,
abstraction appropriateness, and domain model fidelity. This is explicitly
subjective (the agent's judgment) and is not used as a hard gate. It goes into
the audit trail (`dev/audit/`) so the health-scanner can track per-feature
quality trends over time and flag regressions.

### Relationship to existing harness items

- T3-A deep scan: add followup-item counting and CC trend analysis to the deep
  scan report
- T3-D audit trail: QC quality score goes in the audit record alongside the
  checklist results
- T1-A+: CC linter extension (quality signal only, not a gate) — implement
  alongside the existing fn_length_linter using the same compiler-libs
  infrastructure

---

## Tier 4 — Continuous Development Loop (target end state)

This tier completes the automation vision. Items here depend on Tier 3 being
in place.

### T4-A: Automated PR creation

When the orchestrator receives APPROVED from both QC agents for a feature, it
automatically creates a PR using `gh pr create`. The PR description is generated
from the feature's status file and QC review. No human action required to open
the PR.

### T4-B: Auto-merge on clean pass

When all deterministic gates pass and no escalation flags are present, the
orchestrator merges the PR automatically (`gh pr merge --squash`). The merge is
recorded in the daily summary. The human sees: "3 features merged today, 1 held
for escalation."

The merge policy (which gate failures block auto-merge, which trigger escalation
vs. hard block) is defined in `dev/config/merge-policy.json` and versioned — the
human controls it without touching agent code.

### T4-C: Requirements intake workflow

Formalizes how new work enters the system so the human interface is consistent:

1. Human writes or updates a design doc in `docs/design/`
2. Human creates or updates the corresponding `feat-*.md` agent definition
3. Human adds an entry to `dev/decisions.md` if there are constraints or
   priority notes
4. On next orchestrator run, the new feature is automatically picked up

No manual agent dispatch or status file bootstrapping required.

### T4-D: Milestone evaluation reports

At each project milestone (M4 merge, M5 first backtest, M7 tuner result), the
orchestrator generates a milestone evaluation report summarizing:
- What was built (modules, test coverage, interfaces)
- Behavioral verification results (golden scenario pass rates)
- Performance metrics (M5+: Sharpe, drawdown, win rate vs. benchmarks)
- Open items and recommended next design focus

The human reads this report to decide whether to proceed to the next milestone
or redefine requirements.

### T4-E: Rollback and recovery protocol

Defines what happens when a regression gets through — a behavioral bug that
passed QC, a performance drop discovered post-merge, or an escalation that was
auto-resolved incorrectly.

**Detection:** The health-scanner's weekly run includes a `main` performance
check: run the reference backtest against the current `main` and compare to
`dev/benchmarks/reference_backtest.json`. If performance degrades beyond a
threshold since the last known-good baseline, raise an escalation.

**Recovery workflow:**
1. Human identifies the regressing commit via audit trail (`dev/audit/`)
2. Revert commit is created and auto-merged (bypass standard QC — revert is
   always safe to merge)
3. The feat-agent for the reverted feature is requeued with the QC findings
   appended to its operational context
4. The specific gate or checklist item that failed to catch the regression is
   identified and strengthened (new test case, tighter threshold, new checklist
   item)

**"Emergency stop":** A file `dev/config/automation-enabled.json` contains a
single boolean flag. Setting it to `false` pauses all auto-merge and auto-PR
creation without touching agent code. The orchestrator checks this file at the
start of each run. This is the kill switch.

---

## Implementation Sequence

| Phase | Item | Trigger |
|---|---|---|
| Now | T1-A: `dune fmt --check` gate | — |
| Now | T1-A: Architecture layer test | — |
| Now | T1-A+: Custom linters (function length, magic numbers, .mli coverage) | — |
| Now | T1-B: Split qc-reviewer into structural + behavioral | — |
| Now | T1-C: Add Acceptance Checklist to feat-*.md agents | — |
| Now | T1-D: Structured QC checklist output (non-determinism policy) | — |
| Now | T1-E: Pre-flight context injection on every dispatch | — |
| Now | T1-F: Lead-orchestrator blueprint format (deterministic vs agentic nodes) | — |
| Now | T1-G: Max-iterations policy in feat-agent definitions | — |
| Now | T1-H: Tool curation per agent type in agent definitions | — |
| After M4 merges | T2-A: Golden scenario tests (screener + stops) | — |
| At M5 | T2-B: Performance gate + reference_backtest.json | Backtesting built |
| At M7 | T2-C: Walk-forward regression gate | Tuner built |
| Before M6 | T2-D: Live trading gate + paper-trading validation | Before M6 |
| After M5 stable | T3-A: health-scanner agent (fast + deep scan modes) | — |
| After M5 stable | T3-B: AVR loop closure in orchestrator | — |
| After M5 stable | T3-C: Cross-feature context injection (beyond T1-E baseline) | — |
| Before T4-B | T3-D: Audit trail + harness_gap field on NEEDS_REWORK records | — |
| After M5 stable | T3-E: Cost/token budget visibility in daily summary | — |
| After M5 stable | T3-F: Create dependency-rules.md + architecture graph analyzer in health-scanner | — |
| After T3-F | T3-F: Promote monitored rules to enforced gates as violations reach zero | — |
| After T3 complete | T4-A: Automated PR creation | — |
| After T3-D + T4-A | T4-B: Auto-merge + automation-enabled.json kill switch | — |
| After T4-B | T4-C: Requirements intake workflow | — |
| At each milestone | T4-D: Milestone evaluation reports | M4, M5, M7 |
| After T4-B stable | T4-E: Rollback/recovery protocol + health regression check | — |
