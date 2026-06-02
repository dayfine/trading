---
name: jst bug — conflicted bookmarks break submit
description: jst (jj-stack) fails with "commitId":<Error: No"... when ANY local bookmark is in conflict state; clear conflicts before running jst submit
type: project
originSessionId: a7312fb7-b055-4c2e-bf6f-63a86e731f0f
---
**Symptom:**
```
$ jst submit feat/foo/bar
An error occurred: Unexpected token '<', ..."commitId":<Error: No"... is not valid JSON
```

**Root cause:** jst's internal jj template uses `normal_target.commit_id()` on every local bookmark. When a bookmark is in conflict state, jj returns the literal string `<Error: No normal target>` from that template — which then gets fed into JSON.parse and breaks the whole graph-building step. It's NOT auth, NOT network, NOT specific to the bookmark you're submitting — any conflicted bookmark anywhere in the repo causes the failure.

**Fix:**

1. Find conflicted bookmarks — `jj git fetch` will print a warning block:
   ```
   Warning: These bookmarks have conflicts:
     chore/gitignore-dev-data-perf
     ...
   ```
   Or list them: `jj bookmark list --conflicted`
2. For each conflicted bookmark, either:
   - **Resolve**: `jj bookmark set <name> -r <desired-commit>` to pick a single target
   - **Delete**: `jj bookmark forget <name>` if the bookmark is obsolete (typically merged feature branches whose local + remote drifted)
3. Re-run `jst submit`.

**Why:** jst (https://github.com/keanemind/jj-stack) builds its change graph from ALL local bookmarks, not just the one you pass to submit. The template iterates every bookmark and any single conflicted one corrupts the JSON output. Upstream issue worth filing.

**How to apply:** When jst fails with the `<Error: No normal target>` pattern, do not retry blindly — go fix the conflicted bookmarks first. Either resolve or forget the obsolete ones. Was reproduced 2026-05-11 with ~6 stale conflicted bookmarks (chore/gitignore-dev-data-perf, cleanup/nesting-entry-audit-capture, docs/experiments-status-reconcile, docs/g14-deep-dive, docs/g7-finding, docs/optimal-strategy-improvements). After clearing, jst submit worked.

**Workaround when jst is broken:** use `gh pr create --base <previous-bookmark> --head <this-bookmark>` per commit. Slower but reliable.
