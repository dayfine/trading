# Engineering Principles

This document captures the guiding principles behind the development practices
and agentic harness for this project. It is intentionally separate from the
implementation details in `CLAUDE.md` (what to do) and `harness-engineering-plan.md`
(how the harness works) — this document explains *why*.

Principles here are meant to be stable over time, but not frozen. As new patterns
emerge from experience, add them. When a principle turns out to be wrong or too
narrow, revise it. The goal is a living foundation that future agents and humans
can reason from, not a fixed rulebook.

**Related docs:**
- `CLAUDE.md` — concrete code patterns derived from these principles
- `docs/design/harness-engineering-plan.md` — harness design derived from these principles
- `docs/design/dependency-rules.md` — architectural boundaries derived from these principles

---

## I. Code Quality

### Structural constraints over instruction constraints

Encoding a rule as a deterministic check (linter, type system, test) is more
reliable than instructing an agent to follow it. A linter fires on every run for
every agent, without interpretation. A prompt instruction may or may not be
followed consistently.

When a rule can be made structural, make it structural. When a QC agent repeatedly
flags the same class of problem, ask: can this be linted? Over time, the QC
checklist should shrink as items migrate into deterministic gates.

*Source: OpenAI harness engineering experience — "fleet-wide multiplier" effect.*

### Every violation is a signal to improve the structure

When an agent produces a NEEDS_REWORK for a recurring reason, the correct response
is not only to fix the specific instance but to ask whether the system can be
changed to make the violation impossible or automatically detectable. Fixes are
local; structural improvements are permanent.

### Pure functions for all analysis logic

Analysis functions (stage classification, screener scoring, RS calculation) must
be pure: same inputs → same outputs, no hidden state, no IO. This is non-negotiable
for reproducibility. A backtest that produces different results on two runs is
worthless. A bug that can't be reproduced is unfixable.

### All parameters in config, never hardcoded

Every threshold, weight, lookback period, and limit must be a field in the config
record — never a numeric literal in the implementation. This enables backtesting,
parameter tuning, and sensitivity analysis without code changes. It also makes
the system's assumptions explicit and auditable.

### Build alongside existing modules, don't modify them

When adding Weinstein-specific logic, build new modules alongside the existing
ones (`Portfolio`, `Orders`, `Position`, `Strategy`) rather than modifying them.
Existing modules are tested and working; changes to them have broader impact and
require justification that the change generalizes beyond the current feature.

Exception: if a change genuinely improves the shared module for all strategies
(not just Weinstein), it is appropriate — but it requires explicit behavioral QC
judgment that the change is strategy-agnostic.

---

## II. Agentic Harness

### Feedforward and feedback are both required

A harness that only evaluates output (feedback) will see the same mistakes
repeatedly because agents start each session without awareness of prior failures.
A harness that only instructs agents upfront (feedforward) produces untested
assumptions. Both are required: inject the right context before the agent starts,
and evaluate the output after.

*Source: Martin Fowler — "Feedforward (Guides)" and "Feedback (Sensors)" as dual
control dimensions.*

### Deterministic before agentic

In a pipeline of checks, run deterministic checks first. They are fast, cheap,
100% reliable, and require no tokens. Only route to an LLM agent when the check
requires semantic judgment that cannot be expressed deterministically.

A structural QC agent should never re-check what a linter already checked. An
orchestrator should run `dune build && dune runtest` before spawning any reviewer.

*Source: Stripe Minions — "blueprints" interleave deterministic nodes with agentic
subtasks.*

### Every harness component encodes an assumption about model capability

When a harness component is added, it is because the model cannot reliably handle
that concern on its own. As model capability improves, some components become
unnecessary overhead. Periodically review harness components and remove those
whose assumptions are no longer valid. A leaner harness is a better harness.

*Source: Anthropic — "every component in a harness encodes an assumption about
what the model can't do on its own."*

### Diminishing returns bound iteration

After a small number of build-fix cycles within a single session, additional
iterations rarely produce new progress. Cap iteration and report the blocker
rather than looping indefinitely. This applies to both feat-agents (build-fix
cycles) and orchestrator retry logic (NEEDS_REWORK rounds).

*Source: Stripe Minions — "diminishing marginal returns for many LLM iterations."*

### Non-determinism requires structured output

LLM reviewers can disagree with themselves across runs. In a manual workflow this
is annoying; in an automated system it is a correctness problem. QC agents must
produce structured, per-item output (PASS/FAIL/FLAG/NA per checklist item) so
that verdicts are traceable, comparable, and mechanically derivable — not inferred
from narrative prose.

### Curate tool access per agent type

An agent with access to tools it will never legitimately use is an agent with a
larger possibility space than necessary. Narrow the tool set to what the agent
actually needs. This improves reliability, reduces distraction, and limits the
blast radius of mistakes.

*Source: Stripe Minions — "reducing available tools by up to 80% improved agent
performance."*

---

## III. Architecture

### Same pipeline for live and simulation

The analysis and screening code is identical in live and simulation modes. The
`DATA_SOURCE` interface is the seam: live mode calls the broker API, simulation
mode replays from cache or generates synthetically. Nothing in the analysis or
strategy layer should know which mode it is running in.

This principle makes backtests trustworthy (same code path as live) and makes
simulation cheap to build (no parallel implementation).

### Architecture boundaries are explicit, documented, and enforced

Dependency rules between modules should be written down in a canonical document
(`docs/design/dependency-rules.md`) before they are enforced. A rule that exists
only as a linter check — with no written rationale — is fragile: the next agent
to touch the code may not understand why the rule exists and work around it.

Rules have a lifecycle: discovered → proposed → monitored (soft check) → enforced
(hard gate). Promotion through the lifecycle requires human approval.

### Discovery before enforcement

Before adding a new architectural constraint, understand the actual dependency
graph. Constraints imposed without understanding the existing state will produce
false positives and erode trust in the gate system. The architecture analyzer
scans first; rules are proposed from evidence, not assumed.

### Layer boundaries are directional, not binary

The question is not "can A import B?" but "in which direction can dependencies
flow?" Lower layers should not know about higher layers. The simulation layer
wraps the pipeline but must not leak into it. The live execution layer uses the
same pipeline as simulation but must not import simulation-specific code.

When a proposed core module modification is reviewed, the relevant question is:
does this change respect the directional layer boundary, or does it introduce an
upward dependency?

---

## IV. Development Process

### Test-driven development

Write the interface and skeleton first (it should build). Write tests for the
desired behavior (most will fail). Then implement until tests pass. This produces
cleaner interfaces (the test is the first client) and makes the intent of the
code explicit before the implementation exists.

### Incremental commits

One module pair (`.ml` + `.mli`) at a time. Each increment should build and have
passing tests before the next one begins. Large changes that cannot be reviewed
incrementally are harder to QC and harder to revert.

### Design docs drive implementation

New features begin with a design doc approved by a human. The feat-agent reads
the design doc at session start and derives its work from it. Agents do not
invent requirements; they implement what is specified. When a requirement is
ambiguous, the agent surfaces the ambiguity for human clarification rather than
guessing.

### The harness is a living system

The harness itself should be treated as a product: designed, evolved, and
improved based on evidence from real agent runs. When the harness prevents a
real bug, that is signal to keep or strengthen the component. When a component
never fires, that is signal to review whether the assumption it encodes is still
valid. Maintain the harness as deliberately as the trading system itself.
