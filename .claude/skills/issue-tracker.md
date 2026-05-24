# Issue tracker — GitHub Issues (dayfine/trading)

Issues live in this repo's GitHub Issues. Skills `to-issues`, `triage`, `to-prd`, and `qa` interact with them through the `gh` CLI.

## Repo

- **Owner / repo:** `dayfine/trading`
- **CLI:** `gh` (already authenticated in this environment — see `.claude/rules/pr-merge-gates.md` for how this repo uses `gh` throughout)

## Canonical commands

### Create an issue

```bash
gh issue create \
  --repo dayfine/trading \
  --title "<title>" \
  --label needs-triage \
  --body "$(cat <<'EOF'
<body>
EOF
)"
```

### Apply / change labels

```bash
gh issue edit <N> --repo dayfine/trading \
  --add-label "ready-for-agent" \
  --remove-label "needs-triage"
```

### Comment

```bash
gh issue comment <N> --repo dayfine/trading --body "<text>"
```

### List by label

```bash
gh issue list --repo dayfine/trading --label "ready-for-agent" --state open
```

### Close

```bash
gh issue close <N> --repo dayfine/trading --comment "<closing note>"
```

## Conventions specific to this repo

- **Branch naming** follows `feat/<feature-name>` / `harness/<name>` / `ops/<name>` per `CLAUDE.md` §"VCS & PR Workflow". When a triage skill marks an issue `ready-for-agent`, the implementer dispatched off it will use the matching branch prefix.
- **PR comments are the canonical review medium** as of 2026-05-24 (PR #1295 — QC agents post via `gh pr review --comment` rather than writing `dev/reviews/<feature>.md` for new sessions). Issue comments follow the same pattern.
- **All `gh` calls inherit the host's `gh` auth** — no `GH_TOKEN=` plumbing needed in local sessions. For GHA-run scripts, the `GH_TOKEN` is supplied via the workflow's `permissions:` block.

## Where this is referenced

- `CLAUDE.md` §"Agent skills" → "Issue tracker"
- The Matt-Pocock engineering skills read this file when triaging / converting plans to issues / running QA.
