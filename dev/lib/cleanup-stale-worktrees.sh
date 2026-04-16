#!/usr/bin/env bash
# Remove stale agent-created worktrees + jj workspaces.
#
# Background: the `isolation: "worktree"` Agent-tool parameter created
# `.claude/worktrees/agent-<id>/` dirs as git worktrees. These weren't
# cleaned up on subagent exit; after many runs they accumulate. This
# repo picked up 43 stale entries before we switched to per-subagent
# trap cleanup (see lead-orchestrator.md Step 4, 2026-04-16).
#
# Usage:
#   dev/lib/cleanup-stale-worktrees.sh              # remove entries > 7 days old
#   dev/lib/cleanup-stale-worktrees.sh --all        # remove every agent-* entry
#   dev/lib/cleanup-stale-worktrees.sh --dry-run    # list what would be removed
#
# Safe to re-run. Targets .claude/worktrees/agent-* (git worktrees from the
# older isolation mode) and .claude/jj-ws/agent-* (jj workspaces from the
# new mode). Leaves main repo + .jj state alone.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

MODE="stale"
for arg in "$@"; do
  case "$arg" in
    --all)     MODE="all" ;;
    --dry-run) MODE="${MODE}-dry" ;;
    *) echo "Usage: $0 [--all] [--dry-run]" >&2; exit 1 ;;
  esac
done

WORKTREE_DIR="$REPO_ROOT/.claude/worktrees"
JJ_WS_DIR="$REPO_ROOT/.claude/jj-ws"

# ----- git worktrees -----
if [ -d "$WORKTREE_DIR" ]; then
  # Build the candidate list, filtering by age when MODE is stale-*.
  if [[ "$MODE" == stale* ]]; then
    FIND_AGE="-mtime +7"
  else
    FIND_AGE=""
  fi
  # shellcheck disable=SC2086
  mapfile -t WORKTREES < <(find "$WORKTREE_DIR" -maxdepth 1 -type d -name "agent-*" $FIND_AGE 2>/dev/null || true)

  if [ ${#WORKTREES[@]} -eq 0 ]; then
    echo "no stale git worktrees under $WORKTREE_DIR"
  else
    echo "git worktrees to remove: ${#WORKTREES[@]}"
    for wt in "${WORKTREES[@]}"; do
      if [[ "$MODE" == *-dry ]]; then
        echo "  would remove: $wt"
      else
        # Prefer `git worktree remove` so the main repo's bookkeeping is
        # updated. Fall back to rm -rf + git worktree prune if remove
        # fails (e.g. the worktree's .git pointer is already stale).
        if git worktree remove --force "$wt" 2>/dev/null; then
          echo "  removed: $wt"
        else
          rm -rf "$wt"
          echo "  rm -rf (git worktree remove failed): $wt"
        fi
      fi
    done
    # Clean up dangling worktree metadata in the main repo.
    if [[ "$MODE" != *-dry ]]; then
      git worktree prune
    fi
  fi
fi

# ----- jj workspaces -----
if [ -d "$JJ_WS_DIR" ]; then
  if [[ "$MODE" == stale* ]]; then
    FIND_AGE="-mtime +7"
  else
    FIND_AGE=""
  fi
  # shellcheck disable=SC2086
  mapfile -t JJ_WORKSPACES < <(find "$JJ_WS_DIR" -maxdepth 1 -type d -name "agent-*" $FIND_AGE 2>/dev/null || true)

  if [ ${#JJ_WORKSPACES[@]} -eq 0 ]; then
    echo "no stale jj workspaces under $JJ_WS_DIR"
  else
    echo "jj workspaces to remove: ${#JJ_WORKSPACES[@]}"
    for ws in "${JJ_WORKSPACES[@]}"; do
      NAME="$(basename "$ws")"
      if [[ "$MODE" == *-dry ]]; then
        echo "  would forget + rm -rf: $ws"
      else
        # `jj workspace forget` drops the workspace metadata from the
        # shared jj repo; rm -rf removes the directory. Forget first so
        # jj doesn't complain about missing dirs on future commands.
        (cd "$REPO_ROOT" && jj workspace forget "$NAME" 2>/dev/null) || true
        rm -rf "$ws"
        echo "  forgot + removed: $ws"
      fi
    done
  fi
fi
