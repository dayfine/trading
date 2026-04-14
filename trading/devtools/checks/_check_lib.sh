# Shared helpers for shell checks under trading/devtools/checks/.
#
# Source this file from any check script:
#   . "$(dirname "$0")/_check_lib.sh"
#
# --------------------------------------------------------------------
# Two distinct "roots" — use the correct one for the files you read.
# They differ in WHERE they point and HOW they interact with dune's
# sandboxed file-copying model.
# --------------------------------------------------------------------
#
#   repo_root    Git repo root. Example: /workspaces/trading-1
#                Contains: .git, .claude/, dev/, trading/
#
#                USE WHEN: reading files that live OUTSIDE the dune
#                dependency graph — e.g. .claude/agents/*.md or
#                dev/status/*.md. Those paths are NOT mirrored into
#                the dune sandbox at all, so any relative traversal
#                from the sandboxed script will silently miss them.
#
#                HOW: `git rev-parse --show-toplevel`. Git walks up
#                from the process's cwd (which is always inside the
#                repo when `dune runtest` invokes the script), so it
#                finds the repo root correctly whether the script is
#                being run from the source tree or from the sandbox.
#
#                NOTE: This intentionally escapes dune's hermeticity —
#                the scripts scan real source files, not a mirror.
#                That's the correct behaviour for the files this
#                helper targets: they aren't dune-tracked sources.
#
#   trading_dir  Dune workspace root — the directory containing
#                dune-project, analysis/, base/, devtools/, and
#                trading/ (nested). Example (source): /workspaces/trading-1/trading
#                                  Example (sandbox): _build/default (a mirror)
#
#                USE WHEN: reading OCaml sources (lib/*.ml, test/*.ml,
#                dune files). This is where most existing checks live.
#
#                HOW: `$(dirname "$0")/../..`. This is the same
#                expression existing scripts used before the
#                extraction; the helper exists to name it, not to
#                change its semantics. When invoked via dune runtest,
#                the sandbox puts scripts at _build/default/devtools/
#                checks/SCRIPT.sh, so `../..` resolves to
#                _build/default/ — dune's mirror of the source tree.
#                That mirror contains exactly the files dune declared
#                as deps, which preserves hermeticity: a check only
#                re-runs when its declared deps change.
#
# --------------------------------------------------------------------

repo_root() {
  # Resolve the git repo root without relying on `git rev-parse` (which is
  # unreliable under CI's safe.directory setup: actions/checkout writes the
  # safe.directory entry into a TEMPORARY HOME (/__w/_temp/<uuid>/.gitconfig)
  # that our workflow's HOME=/home/opam never sees, so git refuses to operate
  # and rev-parse returns nothing).
  #
  # Strategy: walk up from the script's own directory looking for a marker
  # that's only at the repo root (.git or .claude). This works the same in
  # the dune sandbox (script copied under _build/default/...) and from a
  # direct shell invocation — the walk crosses the sandbox boundary and
  # reaches the real repo root either way.
  #
  # Optional env var override REPO_ROOT lets callers pin it explicitly.
  if [ -n "${REPO_ROOT:-}" ] && [ -d "$REPO_ROOT" ]; then
    echo "$REPO_ROOT"
    return 0
  fi
  dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -d "$dir/.git" ] || [ -d "$dir/.claude" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  echo "FAIL: could not locate repo root by walking up from $(dirname "$0")" >&2
  exit 1
}

trading_dir() {
  # IMPORTANT: return a relative path, not absolute.
  # Running dune sandboxes check scripts with a restricted filesystem view
  # rooted at the sandbox cwd; resolving `$(cd "$(dirname "$0")/../.." && pwd)`
  # to an absolute path escapes that view so `find` sees zero files.
  # The relative form preserves sandbox-relative traversal, matching the
  # behaviour of the pre-library `$(dirname "$0")/../..` expression.
  echo "$(dirname "$0")/../.."
}

die() {
  echo "FAIL: $*" >&2
  exit 1
}
