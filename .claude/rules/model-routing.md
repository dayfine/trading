# Model and effort routing — spend by consequence, not by role

User direction, 2026-10-04: *"do dynamic model and effort level ... for important tasks / analysis, use a
better model / spend more effort, e.g. analyzing results and draw conclusion (that affect the direction of
next iteration)"* and *"lets making sure we are spending tokens smartly"*.

A task's model and effort follow **what its output decides**, not which agent type happens to run it.

| class | what it decides | examples | model / effort |
|---|---|---|---|
| **Direction** | the next iteration | applying a pre-registered rule to a finished run, the "why", screen verdicts, phase-2 / promote / close decisions | `results-analyst` (opus, `max`) |
| **Gate** | whether a PR merges | qc-results (`xhigh`), qc-behavioral (opus, `high`), qc-structural (haiku, `medium`: mostly mechanical, CI is authoritative on linters) | as set in each agent's frontmatter |
| **Build** | code that the gates then check | feat-* / harness-maintainer with a clear brief | agent default; pass `model: sonnet` on the Agent call for a small, fully specified change |
| **Lookup** | nothing durable | doc questions, "does X exist", file searches | `model: haiku` on the Agent call |

## How it is set

- **Effort** lives only in the agent definition (`effort:` in `.claude/agents/<name>.md` frontmatter:
  `low | medium | high | xhigh | max`). The Agent tool has no per-call effort parameter, so a task that needs
  more effort goes to an agent type defined with it.
- **Model** can be set per call (the Agent tool's `model` override), which beats the definition.
- **The main session's effort is the user's setting.** When a direction-class reading is due, dispatch
  `results-analyst` rather than writing it inline, or tell the user that this session's effort will set
  its depth.

## The direction-class pipeline

1. The chain finishes. The dispatcher commits the artifacts, then builds and renders the review packs.
2. `results-analyst` gets the pre-registration commit, the artifact paths and the rendered images, and
   returns a draft.
3. The dispatcher spot-checks two or three numbers in the draft against the artifacts, then commits and
   opens the results PR.
4. `qc-results` reviews the PR as usual. The analyst never reviews its own reading.

For a verdict that closes a programme or promotes a mechanism, a second independent analyst read, given
no access to the first, is worth its cost (the `blind-judge` skill). Flag any disagreement to the user.

## Measuring it

Token rows carry `agent_type`, and the model too once the usage report records it.
`perf-review-weekly.md` §Usage review reads tokens per model and per QC verdict. If direction-class
analysts cost more than they change, or if structural QC at `medium` starts missing what CI then catches,
change the table here and record the numbers that drove the change.
