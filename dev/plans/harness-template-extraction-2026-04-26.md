# Plan: extract Claude Code harness into a reusable template repo (2026-04-26)

## Status

PROPOSED. No work started. Companion to memory entry
`project_harness_reuse.md` (2026-04-26 discussion).

## Why

The orchestrator + agent + status/health/daily harness in this repo
(`.claude/` + `dev/` + `.github/workflows/`) is ~80% reusable across
future projects. Today it's tangled with project-specific bits
(Weinstein domain, OCaml lints, `feat-backtest`, etc.). Extracting
the generic layer into a template repo makes new projects start with
working orchestration on day one.

This plan does the extraction in **two phases**:

1. **Prep** — entirely in this repo. Mechanical, reviewable, leaves
   this repo strictly improved (frontmatter is metadata; nothing
   breaks). After Phase 1, extraction is a grep + copy.
2. **Extract** — one-shot copy into a new `dayfine/agent-harness`
   GitHub repo. Adds a small CLI for new-project init + selective
   sync.

Phase 2 only needs `gh repo create` and a small shell script. No
fancy tooling.

## Scope

### In scope

- Adding `harness: reusable | template | project` frontmatter to
  every `.claude/agents/*.md` and `.claude/rules/*.md`.
- Splitting QC agents along the **methodology / authority** seam:
  `qc-structural.md`, `qc-behavioral.md` keep the generic protocol;
  per-project authority + conventions move to
  `.claude/rules/qc-*-authority.md`.
- Hoisting parameterizable bits in `lead-orchestrator.md` and
  `.github/workflows/orchestrator.yml` into a top-of-file config
  block so the new project edits one section instead of grep-finding
  references throughout.
- Phase 2: scaffolding CLI (`bin/agent-harness`) — ~200 LOC POSIX
  shell. `agent-harness init <new-repo>` clones the template,
  strips `harness: project` files, and replaces `<TODO>`
  placeholders. `agent-harness sync --reusable-only` re-applies
  generic upstream updates.

### Out of scope

- Submodule-based sharing (per memory: Claude Code's agent-loading
  from submodule paths is unverified; team-friction concerns).
- npm/cargo-style packaging (text files aren't libraries; the
  metaphor doesn't fit).
- Automatic sync / version-pinning / semver. Drift is acceptable.
- Migrating this repo to consume from the template post-extraction.
  This repo stays as-is (the template's parent fork).

## Reusability layers (recap from memory)

| Layer | Examples | `harness:` value |
|---|---|---|
| Generic harness | `lead-orchestrator`, `harness-maintainer`, `health-scanner`, `code-health`, `qc-structural` (methodology only), `qc-behavioral` (methodology only), `worktree-isolation.md`, `dev/status` + `dev/health` + `dev/daily` + `dev/budget` directory contracts, GHA workflows (`orchestrator.yml`, `image.yml`, `deps-update.yml`, `health-deep-weekly.yml`), `agent-feature-workflow.md`, orphan-PR / cron / cost-capture patterns | `reusable` |
| Templates | `dev/status/_index.md` skeleton, `dev/plans/README.md`, status-file shape, `feat-agent-template.md` | `template` |
| Project-specific | `feat-weinstein`, `feat-backtest`, `ops-data`, `qc-*-authority.md` (Weinstein domain rules), `weinstein-book-reference.md`, `ocaml-patterns.md`, `test-patterns.md`, `no-python.md`, `ci.yml`, `perf-tier1.yml`, `release_perf_report` plan, OCaml linters | `project` |

## Phase 1 — prep work (in this repo)

### PR 1: frontmatter pass (~30-45 min, mechanical)

Add YAML frontmatter to every `.claude/agents/*.md` and
`.claude/rules/*.md` if missing, and add the `harness:` field to
every existing one.

```yaml
---
harness: reusable    # or template | project
---
```

Verification: a one-line grep check `grep -L 'harness:'
.claude/agents/*.md .claude/rules/*.md` returns empty. Could be
codified as a `devtools/checks/harness_frontmatter_check.sh` linter
that fires from `dune runtest` — optional, low value pre-extraction
since the repo only has ~30 such files.

LOC: 30 files × +1-2 lines = ~50 lines.

### PR 2: split QC agents along methodology / authority seam

Split each of these into two files:

- `.claude/agents/qc-structural.md` (`harness: reusable`) — generic
  structural-review protocol: build health, code-pattern checks,
  architecture constraints concept, FAIL-format, when-to-run.
  Removes references to `csv_storage.ml`, `tiered_runner.ml`, OCaml
  lint names, etc.
- `.claude/rules/qc-structural-authority.md` (`harness: project`) —
  project-specific lint list, architecture constraints, file paths,
  test-framework references.

Same split for `qc-behavioral.md`. Generic file says
"For project-specific authority hierarchy, conventions, and domain
references, consult `.claude/rules/qc-behavioral-authority.md`."
Project file lists the Weinstein book, module docstring conventions,
test framework, etc.

Verification: agents still pass their existing dispatches. Run one
QC dispatch end-to-end and confirm no regression. Could pin a
"protocol-only" e2e test by dispatching qc-structural with a
fake-failure scenario.

LOC: ~300 lines redistributed; net change near zero.

### PR 3: hoist parameterizable bits in lead-orchestrator + orchestrator.yml

Add a `## Configuration` block at the top of each:

```markdown
<!-- Configuration: edit these for a new project -->
- repo_url: <github.com/dayfine/trading>
- container_image: <ghcr.io/dayfine/trading-image>
- track_names: backtest-infra | backtest-perf | data-panels | ...
- feat_agents: feat-weinstein | feat-backtest | ...
- pr_naming_convention: feat/<track>-<short>
```

Then references throughout the file read those values implicitly
("see Configuration block at top"). Same for `orchestrator.yml` —
hoist secret names, image refs, branch patterns, cron slots.

Verification: orchestrator still runs; no behavior change. `dev/daily`
artifacts still produced.

LOC: ~80 lines edited, no net new lines.

### PR 4 (optional): document the layer model in `.claude/README.md`

If `.claude/README.md` doesn't exist, create one explaining the
3-layer model + frontmatter convention + how to add a new project
agent. This README is itself `harness: reusable` so it travels to
the template.

LOC: ~80 lines new.

## Phase 2 — extraction (one-shot, ~1 hour)

After Phase 1, all four PRs merged. Now extract:

### Step 1: scaffold the new repo

```bash
gh repo create dayfine/agent-harness --public --description "Claude Code orchestration harness — generic agents, status/health/daily/budget contracts, GHA workflows" --clone
cd agent-harness
```

### Step 2: copy `harness: reusable | template` files

A small extraction script `bin/extract.sh` walks the source repo,
includes files where the YAML frontmatter has
`harness: reusable | template`, excludes `harness: project`. For
the template skeletons, replaces `<PROJECT_NAME>` etc. placeholders
with literal `<TODO>` markers.

```bash
# Run from this repo's root
sh ../trading-1/bin/extract.sh ../trading-1 ./
```

Result: `agent-harness/.claude/`, `agent-harness/dev/`,
`agent-harness/.github/workflows/` populated with the generic
layer.

### Step 3: write the scaffolding CLI

`bin/agent-harness` (POSIX shell, ~200 LOC):

- `agent-harness init <target-dir>` — clones this template into
  target, runs the strip pass (drops `harness: project` if any
  leaked), substitutes `<TODO>` placeholders interactively or from
  a config file.
- `agent-harness sync --reusable-only` — diffs each file marked
  `harness: reusable` from the upstream template against the local
  copy, presents per-file y/n/skip. No automatic merging; the
  human reviews.
- `agent-harness check` — runs `harness_frontmatter_check.sh`
  equivalent: every `.claude/*.md` file has a `harness:` line.

### Step 4: write the template's own README

`README.md` at the template repo root explains the 3-layer model,
how to use `agent-harness init`, and what the user fills in.
Points back to `.claude/README.md` for the agent layer.

### Step 5: tag v0.1.0

`git tag v0.1.0 && git push --tags`. Future projects pin to a tag;
sync command pulls from tag rather than `main`.

## What if I want to use it in another existing project?

```bash
# In the new project's root
agent-harness init . --skeleton-only
# Manually merge any conflicts; existing files prompt y/n.
```

The CLI is dumb on purpose — no automatic merge logic.

## What if the harness evolves and I want this repo to benefit?

This repo doesn't pull from the template. It stays as the parent
fork. If a generic-agent improvement happens here, the workflow is:

1. Land it in this repo as a normal PR.
2. Cherry-pick the file change(s) into the template repo (manual
   `git cherry-pick` across repos via patch file, or `agent-harness
   sync --upstream`).

If a generic-agent improvement happens in the template repo first
(via another project), pull it back into this repo via the same
manual flow.

For a 1-2-project scale, this is fine. If there are 5+ projects,
revisit a more automated sync.

## LOC budget

| Phase | LOC | Time |
|---|---:|---:|
| PR 1 frontmatter pass | ~50 | 30 min |
| PR 2 QC split | ~300 (redistributed) | 2-3 h |
| PR 3 hoist config | ~80 | 1 h |
| PR 4 README | ~80 | 30 min |
| Phase 2 extraction script + CLI | ~250 | 2-3 h |
| **Total** | **~760** | **~7-8 h** |

## Risks

### R1: agent splits introduce bugs in QC

Splitting `qc-structural` / `qc-behavioral` may miss cross-references.
Mitigation: PR 2 is its own PR; run a real QC dispatch before merge.

### R2: orchestrator config block clashes with current implicit refs

The hoist might miss some hardcoded reference. Mitigation: PR 3 ends
with one full orchestrator dry-run.

### R3: scaffolding CLI bit-rot

If we never use the CLI, drift makes it broken. Mitigation: Phase 2
ends with bootstrapping a real second project (any project — could
be the user's hypothetical next thing). If it works there, the CLI
is good. If not, the only consumer is right there to fix it.

### R4: discoverability across projects

If the harness changes in repo A, repo B doesn't get notified.
Mitigation: accept this. Manual quarterly review.

## Decision items

1. ~~**Repo name**~~ — resolved 2026-04-26. `dayfine/agent-harness`
   created (public, empty, description "Harness template /
   scaffolding for agentic coding"). Agent-agnostic naming reflects
   broader intent even though the current implementation is Claude
   Code-specific (`.claude/` dir, agent `.md` files).
2. ~~**Public or private?**~~ — resolved 2026-04-26. Public.
3. **License**: MIT? The harness is mostly markdown + shell + YAML;
   permissive is fine. Decide before first commit to the new repo.
4. **Phase 1 first, or skip prep and do a dirty extraction?** Plan
   recommends Phase 1; the prep work pays off whether the template
   repo happens or not. The empty `agent-harness` repo doesn't
   force the question — Phase 1 still happens here first.

## Triggers to start

- (a) User starts a new project that wants the harness.
- (b) User schedules a "harness reuse week".
- (c) The current trading project's harness reaches a stable enough
  state that extraction is worth the freeze.

Memory entry `project_harness_reuse.md` carries the locked
recommendation; this plan is the executable form. When triggered,
re-read both, re-read `.claude/agents/lead-orchestrator.md` +
`.github/workflows/orchestrator.yml`, then start with PR 1.

## References

- Memory: `~/.claude/projects/-Users-difan-Projects-trading-1/memory/project_harness_reuse.md`
- Discussion that produced this plan: 2026-04-26 (this session).
- Load-bearing files for any extraction: `.claude/agents/lead-orchestrator.md`,
  `.github/workflows/orchestrator.yml`, `.claude/agents/feat-agent-template.md`,
  `.claude/rules/worktree-isolation.md`.
