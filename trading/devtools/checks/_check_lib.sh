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
  #
  # H-REPO-ROOT-SET-BUT-INVALID-SILENT-FALLTHROUGH: a REPO_ROOT that is SET
  # but fails the `[ -d ]` guard (nonexistent path, or a path that exists
  # but is a regular file, not a directory) is a hard error here -- it is
  # far more likely a typo/misconfiguration than a deliberate request to
  # fall back to the walk-up. Silently falling through used to write the
  # audit record into a root the caller never chose, with rc=0 and no
  # diagnostic -- exactly the failure shape this whole helper exists to
  # prevent, just reachable via malformed input instead of valid input.
  #
  # REPO_ROOT='' (empty string) is treated the SAME as unset, not as
  # "set but invalid": `${REPO_ROOT:-}` is empty for both an unset and an
  # empty-string REPO_ROOT (the `:-` operator triggers on null-or-unset),
  # so the two cases already collapse into the walk-up branch below by
  # shell construction. This is a deliberate choice, not an oversight: an
  # empty override is indistinguishable from "no override supplied", and
  # every existing caller relies on the no-REPO_ROOT case falling through
  # to the walk-up (that's the only path production uses -- REPO_ROOT is
  # test-only plumbing). Treating '' as a hard error would NOT protect
  # against a genuine typo (an empty value can't carry a wrong path) and
  # WOULD risk breaking a caller that does `REPO_ROOT= some_command` to
  # mean "no override".
  if [ -n "${REPO_ROOT:-}" ]; then
    if [ -d "$REPO_ROOT" ]; then
      echo "$REPO_ROOT"
      return 0
    fi
    echo "FAIL: REPO_ROOT is set to '$REPO_ROOT' but is not a directory" >&2
    exit 1
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

# --------------------------------------------------------------------
# jj-colocation intent-to-add guard.
#
# Any `jj` command invoked against a colocated repo (`-R <repo>` pointing
# at the DEFAULT workspace's own directory) snapshots that workspace's
# working copy as a side effect, even for commands that look read-only
# (`workspace list`) or that operate on a DIFFERENT workspace
# (`workspace add`). The snapshot exports untracked files sitting in that
# working copy into the colocated git index as intent-to-add (` A`)
# entries -- indistinguishable from `git add -N` in `git status`, and
# counted by `git ls-files` as tracked. Reproduced 2026-09-25 (harness
# item T3-ITA): `jj_workspace_smoke.sh`'s three `jj -R "$REPO" ...` calls
# turned an untracked `dev/daily/<date>*.md` into ` A` in the caller's
# real checkout, which silently changed
# `orchestrator_fastexit_gate.sh _current_summary_path`'s run-count (it
# counted the polluted entry via `git ls-files`). See
# dev/status/harness.md for the full writeup.
#
# `jj workspace forget` (already run in the caller's cleanup) does NOT
# undo this -- it only removes the *other* workspace's registration, not
# the export side effect on the default workspace's index. The only
# correct fix is to detect exactly what a jj invocation staged and
# unstage precisely that, so real pre-existing staged state (a legitimate
# `git add` a caller had in flight before calling us) is left untouched.
#
# Usage:
#   _before=$(jj_ita_guard_snapshot "$REPO")
#   ... run jj commands against "$REPO" ...
#   jj_ita_guard_restore "$REPO" "$_before"

# jj_ita_guard_snapshot <repo>
# Print the repo's currently-intent-to-added path set, one per line
# (possibly empty). This is the "before" baseline to diff against after
# running jj commands that might snapshot the working copy.
#
# NOTE: intent-to-add is NOT visible via `git diff --cached` -- git
# deliberately suppresses ITA entries from that comparison (an ITA entry
# carries no real staged content, just a placeholder), so `git diff
# --cached --name-only` silently returns nothing for exactly the entries
# this guard needs to see. The reliable signal is porcelain status: an
# ITA entry is the only case that renders as "<space>A<space>path" (git
# diff-index X=unchanged, Y=Added-in-worktree); a real `git add` of a new
# file renders "A<space><space>path" (X=Added) instead. Confirmed by
# side-by-side repro during the 2026-09-25 investigation -- see
# dev/status/harness.md.
jj_ita_guard_snapshot() {
  git -C "$1" status --porcelain=v1 --untracked-files=no 2>/dev/null \
    | grep '^ A ' \
    | cut -c4- \
    || true
}

# jj_ita_guard_restore <repo> <before-snapshot>
# Unstage (`git reset --`) any path that is staged now but was NOT staged
# in <before-snapshot>. For a path with no HEAD blob (the intent-to-add
# case this guard exists for), `git reset -- <path>` removes it from the
# index entirely, returning it to plain untracked (`??`) -- exactly
# reverting the jj-triggered export. Safe to call even if nothing
# changed; never touches a path that was already staged before the guard
# started (a caller's own legitimate staged changes survive untouched).
jj_ita_guard_restore() {
  _guard_repo="$1"
  _guard_before="$2"
  _guard_after=$(jj_ita_guard_snapshot "$_guard_repo")
  # `comm` needs two sorted FILES, not process substitution (`<(...)` is a
  # bashism -- these scripts are POSIX sh, per .claude/rules/no-python.md's
  # "POSIX sh only" tooling rule).
  _guard_before_file=$(mktemp)
  _guard_after_file=$(mktemp)
  printf '%s\n' "$_guard_before" | sort >"$_guard_before_file"
  printf '%s\n' "$_guard_after" | sort >"$_guard_after_file"
  _guard_new=$(comm -13 "$_guard_before_file" "$_guard_after_file")
  rm -f "$_guard_before_file" "$_guard_after_file"
  if [ -n "$_guard_new" ]; then
    printf '%s\n' "$_guard_new" | while IFS= read -r _guard_path; do
      [ -n "$_guard_path" ] && git -C "$_guard_repo" reset -- "$_guard_path" >/dev/null 2>&1
    done
  fi
  return 0
}
