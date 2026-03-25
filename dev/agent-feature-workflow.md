# Feature Agent Workflow

Read by all feature agents at session start. Contains the shared workflow,
commit discipline, and session procedures.

## Branch setup

**Always branch from `main@origin`.** Never branch from another feature branch,
even if that feature is a dependency. Wait for dependencies to land in `main`
first (the dependency gate in your agent file enforces this).

```bash
jj git init --colocate 2>/dev/null || true
jj git fetch

# If your feature branch already exists on the remote (resuming a session):
jj new feat/<your-feature>@origin

# If starting fresh (bookmark does not exist on remote yet):
jj new main@origin
jj bookmark create feat/<your-feature> -r @
jj git push --bookmark feat/<your-feature>
```

Never commit to `main` directly.

## Development workflow

Work **one module at a time**. Full cycle per module:

1. Write `.mli` interface + skeleton → `dune build` passes → **commit**
2. Write tests → **commit**
3. Implement → `dune build && dune runtest` passes → **commit**
4. `dune fmt` → **commit if anything changed**

Build/test inside Docker:
```bash
docker exec <container-name> bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && dune build && dune runtest'
```

Commit and push after each step:
```bash
jj describe -m "your commit message"   # no git add needed
jj bookmark set feat/<your-feature> -r @
jj git push --bookmark feat/<your-feature>
```

Check your work:
```bash
jj status      # what changed
jj diff        # full diff
jj log -n 10  # recent history
```

## Commit discipline

- **One module per commit** — never batch multiple modules together
- **Target 200–300 lines per commit** (hard max ~400 including tests)
- **Push after every commit** — don't accumulate local-only work
- Each commit must build cleanly on its own

## At the end of every session

Before returning:

1. `dune build && dune runtest` passes clean on your branch
2. All changes committed and pushed — nothing uncommitted
3. `dev/status/<your-feature>.md` updated (see your agent file for the exact fields)
4. If all work is complete and tests pass: set status to `READY_FOR_REVIEW`
