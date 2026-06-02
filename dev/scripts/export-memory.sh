#!/bin/sh
# Export the agent's curated, durable project knowledge to dev/agent-memory/.
#
# The canonical memory store lives in the agent's local ~/.claude tree (loaded
# into context at session start). This script snapshots the *project*- and
# *reference*-typed memories into the repo so they are shared, versioned, and
# backed up. It is a point-in-time export: re-run + commit to refresh.
#
# Curation (what is NOT exported):
#   - feedback-typed memories: agent-process / "how to work" notes, not project
#     knowledge.
#   - dated session-log snapshots (project_20YY-* — historical diaries,
#     superseded by the dev/notes handoff docs). Self-maintaining via the
#     filename pattern.
#   - the explicit STALE list below: memories whose specific content has been
#     superseded and is now misleading.
#
# Usage: sh dev/scripts/export-memory.sh   (from anywhere in the repo)
set -eu

# Memories that are stale/misleading and should not be checked in (space-sep,
# basenames without .md). Add here when a finding is superseded.
STALE="project_sp500_baseline_conflict"

root=$(git rev-parse --show-toplevel)
# The local memory dir is ~/.claude/projects/<abs-repo-path with / -> ->/memory
mangled=$(printf '%s' "$root" | sed 's#/#-#g')
memdir="$HOME/.claude/projects/$mangled/memory"
dest="$root/dev/agent-memory"

if [ ! -d "$memdir" ]; then
  echo "export-memory: local memory dir not found: $memdir" >&2
  echo "  (run from a machine whose ~/.claude store has this project's memories)" >&2
  exit 1
fi

is_stale() {
  for s in $STALE; do
    [ "$1" = "$s" ] && return 0
  done
  return 1
}

rm -rf "$dest"
mkdir -p "$dest"

count=0
for f in "$memdir"/*.md; do
  base=$(basename "$f")
  [ "$base" = "MEMORY.md" ] && continue
  # include only project/reference-typed memories
  grep -qE '^[[:space:]]*type: (project|reference)' "$f" || continue
  # exclude dated session-log snapshots
  case "$base" in project_20[0-9][0-9]-*) continue ;; esac
  # exclude the explicit stale list
  is_stale "${base%.md}" && continue
  cp "$f" "$dest/"
  count=$((count + 1))
done

# Rebuild the index README.
index="$dest/README.md"
{
  echo "# Agent memory — durable project knowledge"
  echo ""
  echo "Versioned snapshot of the Claude Code agent's **project** and **reference**"
  echo "memories for this repo: distilled, cross-linked conclusions and gotchas from the"
  echo "Weinstein trading-system work. The canonical copy lives in the agent's local"
  echo "\`~/.claude\` store (loaded at session start); refresh this snapshot with"
  echo "\`sh dev/scripts/export-memory.sh\` + commit."
  echo ""
  echo "Excluded: agent-process (\`feedback\`-typed) memories, dated session-log"
  echo "snapshots (\`project_20YY-*\`), and superseded entries (see the script's STALE"
  echo "list). Generated file — edit the source memories, not this directory."
  echo ""
  echo "## Index"
  echo ""
  for f in "$dest"/*.md; do
    base=$(basename "$f")
    [ "$base" = "README.md" ] && continue
    desc=$(awk '/^description:/{sub(/^description: */, ""); gsub(/^"|"$/, ""); print; exit}' "$f")
    printf -- '- [`%s`](./%s) — %s\n' "$base" "$base" "$desc"
  done
} >"$index"

echo "export-memory: wrote $count project/reference memories + index to dev/agent-memory/"
