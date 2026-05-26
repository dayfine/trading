# feat-agent dispatch — interactive-session rules

Four invariants when dispatching a `feat-*` agent from an interactive
session (the rules `lead-orchestrator` already follows for unattended
overnight runs; lifted here so I do the same inline without booting
the orchestrator).

These supplement, not replace:
- `.claude/rules/worktree-isolation.md` — jj workspace isolation contract.
- `.claude/rules/pr-merge-gates.md` — the 3-gate merge rule.
- `.claude/rules/qc-structural-authority.md` — review surface and FLAG protocol.

## 1. Pre-flight context injection

The dispatch prompt must paste three blocks BEFORE the agent's task
description. Without them, the agent re-discovers state I already have
in hand and burns tokens / makes assumptions that drift from current
reality.

```
### Current test failures in your test directory
<paste `dune runtest <target-test-dir>` output, OR "All passing" if clean>

### Last QC review findings
<paste relevant sections from `gh pr view <N> --json reviews --jq '.reviews[].body'`
 if a prior QC review exists, OR "No prior review" if first dispatch on this track>

### Open follow-up items
<paste the `## Follow-ups` section from `dev/status/<track>.md` if any,
 OR "None" if empty>

---

<the actual task brief goes here>
```

**When to skip:** one-shot atomic fixes (e.g. "rename `foo` to `bar`",
"bump dependency X to Y") where there is no track, no prior review,
and no surrounding test surface. If you're dispatching something that
touches a feature track, all three blocks are required even if a block
is empty — the explicit "None" line is itself signal to the agent that
the slot was checked.

**Cost:** ~30 seconds before dispatch. The opening grep + cat is
amortized many times over by what the agent does NOT have to spelunk.

## 2. PR-creation fallback after the agent returns

Feat-agents sometimes return with the implementation pushed but the
PR not opened — they hit a `gh` failure, ran out of tokens mid-step,
or simply skipped the step. When the agent's report mentions a
bookmark name + commit but doesn't quote a PR URL, verify:

```bash
# Did the agent open the PR?
gh pr list --repo dayfine/trading --head <bookmark-name> --state open
```

If the PR is missing AND the bookmark exists on origin, open it from
the dispatcher side. Use the agent's report text as the PR body
(quoting it verbatim is fine — it's already what would have gone in).

This catches a real failure mode — orchestrator Step 4.5 exists for
exactly this reason. ~10 seconds to verify; saves ~30 minutes of human
notice + re-dispatch.

## 3. Rework iteration cap

When a QC verdict comes back NEEDS_REWORK, the natural impulse is to
re-dispatch the feat-agent in the same session to address findings.
That's fine — and faster than waiting for the next session — but it
needs a soft cap. The orchestrator's default is `rework_cap = 2`
(feat-agent re-dispatched at most twice per track per run; total QC
spawns up to 3).

Same cap applies here:

- **Iteration 0:** first dispatch.
- **Iteration 1:** first rework (after QC NEEDS_REWORK on iter 0).
- **Iteration 2:** second rework (after QC NEEDS_REWORK on iter 1).
- **After iteration 2 still NEEDS_REWORK:** STOP. Leave the PR draft,
  flag in the session summary. Loop is now stuck on a finding that
  needs human intent / scope renegotiation, not more agent cycles.

In the rework brief itself, paste:
- The full QC review comment bodies from `gh pr view <N> --json reviews --jq '.reviews[].body'` (both structural and behavioral).
- The iteration number ("rework iteration 1 of 2") so the agent knows headroom.
- An explicit instruction: "Address every checked-fail item in the review comments. Do not introduce new scope. Commit with `fix(review): address QC rework iteration <N>`."

The point of the cap is the third-iteration STOP. Without it, the
loop drifts on stubborn findings.

## 4. `dev/status/_index.md` reconcile contract

`dev/status/_index.md` is the single-source view of all tracked work
(Track | Status | Owner | Open PR(s) | Next task). Feat-agents must
NOT write to it from inside a feature PR. Two reasons:

1. **Merge conflicts.** Every feature PR that touches `_index.md`
   conflicts with every other concurrent PR that does the same. The
   orchestrator's Step 5.5 contract says "agents write their per-track
   `dev/status/<track>.md`; orchestrator (or dispatcher) mirrors into
   the index."
2. **Stale Last-updated.** If the agent updates the index timestamp
   inside its feature commit, the timestamp reflects when the agent
   wrote — not the actual state at merge. Reconciler-side ownership
   keeps the timestamp meaningful.

**The dispatch prompt should include this line verbatim** (the
contract is easy to forget when an agent is one prompt away from
fixing the obvious-looking drift):

> Do not modify `dev/status/_index.md` from this PR. Update only
> `dev/status/<your-track>.md`; the index reconcile happens after
> merge.

**Exception:** a PR that introduces a brand-new tracked work item
must include the new row in `_index.md` (the orchestrator has no
other signal to invent one). For an existing row, never touch the
index from a feature PR.

## What this file does NOT include

Things the orchestrator does that I have NOT extracted here, because
they are either already covered or not worth the discipline overhead
in interactive mode:

- **Saturated-queue fast-exit** (orchestrator Step 0.5) — autonomous
  no-op logic. In interactive I just respond to the user.
- **Budget guards** (Step 3.75 / 5a budget defer) — only matters for
  unattended cost caps.
- **Daily summary structured format** (Step 7) — interactive sessions
  have the conversation as the durable record; the formal table is
  overkill.
- **Audit records per dispatch** (Step 5 stage 4) — track-pacer +
  `git log` cover the same ground when needed.
- **Drift detection** (Step 1b) — already in
  `feedback_status_refresh_must_verify.md`.
- **Carried-`[critical]` re-verification** (Step 1c) — same memory.

These remain in `lead-orchestrator.md` for unattended overnight use
and stay out of the interactive-mode discipline list.
