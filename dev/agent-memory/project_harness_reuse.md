---
name: Harness reuse / extraction plan
description: Plan for extracting reusable .claude/ + dev/ + GHA harness from this repo for use in a future new project; not started, deferred for "soon" revisit
type: project
originSessionId: 1b3c22f4-6967-4e7d-bdd3-6cfe881e12e5
---
User wants to reuse the orchestrator + agent + status/health/daily harness in a future new project. Discussion held 2026-04-26; **action deferred** ("we will revisit it soon"). Recommendation locked: **Option 1 — fork + strip**, preceded by mechanical prep work in this repo.

**Why:** Reusing 80% of something with a one-shot fork is cheaper than building a perfectly-portable framework. The current `lead-orchestrator.md` works *because* it is concrete (knows about `dev/status/_index.md`, `feat-*` agents, etc.) — over-abstracting loses ergonomic clarity. Submodule path (Option 3) has open questions about Claude Code's agent-loading from non-`.claude/agents/*.md` paths.

**How to apply:** When the user asks to revisit, start with the prep work (which makes any future extraction mechanical), THEN do the fork-and-strip.

## Three reusability layers

| Layer | Examples | Reuse strategy |
|---|---|---|
| **Generic harness** | `lead-orchestrator`, `harness-maintainer`, `health-scanner`, `code-health`, `qc-structural` checklist *shape* (not the OCaml-specific checks), `worktree-isolation.md`, the `dev/status/`+`dev/health/`+`dev/daily/`+`dev/budget/` directory contract, GHA workflows (`orchestrator.yml`, `image.yml`, `deps-update.yml`, `health-deep-weekly.yml`), `agent-feature-workflow.md`, orphan-PR / cron / cost-capture patterns | Reusable wholesale w/ small parameterization (image refs, track names, language-specific lints) |
| **Templates** | `dev/status/_index.md` skeleton, `dev/plans/README.md`, status-file shape, `feat-agent-template.md` | Empty skeletons the new project fills in |
| **Project-specific** | `feat-weinstein`, `feat-backtest`, `ops-data`, `qc-behavioral` (domain rules), `weinstein-book-reference.md`, `ocaml-patterns.md`, `test-patterns.md`, `no-python.md`, `ci.yml`, `perf-tier1.yml`, `release_perf_report` plan, OCaml linters | Don't try to reuse |

## Extraction options considered

1. **Fork + strip** (RECOMMENDED). Copy `.claude/` + `dev/` skeleton + workflows into the new repo, delete the project-specific files using a frontmatter marker convention. One-shot; drift accumulates, no upstream sync. Cheapest first try.
2. **Bootstrap script.** Extracts marked files from this repo into a new repo; re-runnable. Worth it only if doing this twice.
3. **Submodule for generic core.** `.claude/harness/` as a submodule; project keeps its own `.claude/agents/feat-*.md`. Updates flow via submodule bump. Tradeoffs: Claude Code's agent-loading from submodule paths is unverified; more friction for the human.

## Prep work to do **in this repo** before any extraction

- Add `harness: reusable | template | project` frontmatter to every `.claude/agents/*.md` and `.claude/rules/*.md`. Cheap, mechanical, makes the strip grep-able.
- Extract parameterizable bits in `lead-orchestrator.md` (section names, default tracks, image references, repo URL) into a config block at the top.
- Same for `orchestrator.yml`: secret names + image refs + branch patterns are the project-specific bits; everything else is reusable.

## Trap to avoid

Over-abstracting the orchestrator pattern into a fully data-driven framework. The current concrete approach is the readable approach.

## Revisit plan

Triggers a re-discussion when: (a) the user is bootstrapping a new project, OR (b) the user asks "let's pick up the harness reuse work". When triggered: re-read this memory, re-read `.claude/agents/lead-orchestrator.md` + `.github/workflows/orchestrator.yml` (those are the load-bearing files), then start with the prep work.
