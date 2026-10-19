# Cloud environment

Use the managed Docker runtime and run `sh .codex/cloud-setup.sh` from the
repository root for setup and task startup. Setup downloads the pinned CI image
through `crane export` and imports its flattened filesystem, avoiding Docker vfs
layer duplication. The imported image has no original image configuration;
the script explicitly supplies its user, opam variables and working directory.
During a cold import, budget space for both the flat tar and the imported image
at once; the script removes the tar after import, including on failure.
Requires Docker, curl, tar, sha256sum and an x86-64 Linux host. Keep registry
credentials and the platform proxy configuration unchanged. Networked commands
inside the container require the platform CA mounted read-only and the relevant
tool's trust setting (see the cloud runtime instructions).

Startup reuses the container and copies `.codex/dune-workspace.cloud` to
`/tmp/trading-cloud-workspace`. Run it from the original repository root, not a
worktree; it checks for the workspace template before any Docker operation and
refuses to reuse a container mounted from another root. Every startup removes
the unused `5.3` switch (if present) and `/home/opam/opam-repository`, retaining
the active `5.3.0+flambda` switch. Do not
remove another task's container to resolve that refusal.

## Disk and validation

The machine has 32 GB disk. A full build uses approximately 13 GB even with
stripped native symbols. Build and test focused targets only, with `-j 4` and
the workspace below. CI and Claude QC own full-build, full-test and linter gates.
The linker flag removes native debugging symbols. Do not clean another task's
build outputs or run builds concurrently.

Create an isolated worktree as AGENTS.md requires. Inside `trading-1-dev`, change
to `/workspaces/trading-1/.claude/worktrees/<your-worktree>/trading`, then run:

```sh
eval "$(opam env)"
export TRADING_DATA_DIR=$PWD/test_data
dune build --root . --workspace /tmp/trading-cloud-workspace -j 4 @fmt
dune build --root . --workspace /tmp/trading-cloud-workspace -j 4 trading/orders
dune runtest --root . --workspace /tmp/trading-cloud-workspace -j 4 trading/orders
```

Replace `trading/orders` with the directories touched by your task. The global
format check is cheap; avoid a full build or full runtest on this machine.

## Network and identity

The intended agent-phase policy is restricted egress with only the
package-manager preset, no additional `api.github.com` host and no GitHub token
in the environment. Use the connected GitHub integration for PRs and replies.
Changing this document does not change the enforced environment policy.

The attached managed runtime's `ccarenv_b64_...` ID and source configuration ID
are runtime identifiers. Neither has been verified as an ID accepted by
`codex cloud exec --env`. GitHub connector repository access and a working
attached runtime do not by themselves verify that `@codex` dispatch is wired to
this environment. Check the Codex cloud environment settings and a fresh task
before recording that acceptance condition as complete.
