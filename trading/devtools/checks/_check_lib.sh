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
# Print the repo's currently-staged-as-a-new-file path set, one RECORD per
# line, each record TAB-separated as:
#   <2-char-porcelain-code><SP><path><TAB><cacheinfo-or-empty>
# This is the "before" baseline to diff against after running jj commands
# that might snapshot the working copy. Covers EVERY shape a new file can
# be staged in:
#   " A path"   -- intent-to-add (git diff-index X=unchanged, Y=Added).
#                  No real content is staged (the index entry points at
#                  the empty blob, e69de29...), so the cacheinfo field is
#                  left empty -- there is nothing to restore beyond
#                  leaving the path alone.
#   "A. path"   -- ANY real `git add` of a new file, where the second
#                  porcelain column can be space (plain add, unmodified
#                  since -- "A "), 'M' (added, then edited -- "AM"), or
#                  another worktree-vs-index delta. The cacheinfo field
#                  records `<mode>,<blob-sha>` from `git ls-files -s` for
#                  the path's INDEX entry -- the exact content the caller
#                  staged, independent of whatever the worktree holds.
# Capturing every 'A'-prefixed shape, not just the unmodified "A " one,
# matters for jj_ita_guard_restore below: `jj workspace forget` reshapes
# ANY real-add path -- add-only OR add-then-edit alike -- into the ITA
# shape (" A", empty blob) as a side effect on the default workspace's
# index, destroying the staged blob in the process. Reproduced 2026-09-25
# (qc-behavioral rework iteration 2, #2956): a `git add`-then-edited new
# file (index content X, worktree content Y -- "AM" in porcelain) went
# into `jj workspace forget` as "AM" and came out as " A" with the staged
# blob replaced by the empty one, discarding X entirely -- while the
# worktree file itself (Y) was untouched. A snapshot that only recorded
# the plain "A " shape would miss this path outright; recording ONLY
# status lines with no blob info would, at restore, have to fall back to
# re-`git add`ing the path, which stages the CURRENT worktree content (Y)
# rather than what the caller actually staged (X). See
# jj_ita_guard_restore below and dev/status/harness.md.
#
# NOTE: intent-to-add is NOT visible via `git diff --cached` -- git
# deliberately suppresses ITA entries from that comparison (an ITA entry
# carries no real staged content, just a placeholder), so `git diff
# --cached --name-only` silently returns nothing for exactly the entries
# this guard needs to see. The reliable signal is porcelain status, per
# the shapes above. Confirmed by side-by-side repro during the
# 2026-09-25 investigation -- see dev/status/harness.md.
jj_ita_guard_snapshot() {
  _snap_repo="$1"
  git -C "$_snap_repo" status --porcelain=v1 --untracked-files=no 2>/dev/null \
    | grep -E '^A|^ A ' \
    | while IFS= read -r _snap_line; do
        _snap_path=$(printf '%s' "$_snap_line" | cut -c4-)
        case "$_snap_line" in
          A*)
            _snap_cacheinfo=$(git -C "$_snap_repo" ls-files -s -- "$_snap_path" 2>/dev/null \
              | awk '{print $1","$2}')
            printf '%s\t%s\n' "$_snap_line" "$_snap_cacheinfo"
            ;;
          *)
            printf '%s\t\n' "$_snap_line"
            ;;
        esac
      done \
    || true
}

# jj_ita_guard_restore <repo> <before-snapshot>
# For every path that is CURRENTLY intent-to-add (' A'):
#   - if it was plain untracked before the guard started (absent from
#     <before-snapshot> in any shape) -- this is exactly the jj-triggered
#     pollution the guard exists to undo. `git reset -- <path>` removes it
#     from the index entirely (it has no HEAD blob), returning it to plain
#     untracked (`??`).
#   - if it was already ITA before the guard started -- no-op. An ITA
#     entry never carries real content, so there is nothing to restore
#     beyond leaving the path alone; it is already the right shape.
#   - if it was staged with real content before the guard started (ANY
#     'A'-prefixed shape -- "A ", "AM", ...) and a later jj call reshaped
#     it into ITA -- restore the EXACT recorded index entry via
#     `git update-index --add --cacheinfo <mode>,<sha>,<path>`, using the
#     mode+blob jj_ita_guard_snapshot captured BEFORE the jj calls ran.
#     This writes the caller's staged content back bit-for-bit and clears
#     the ITA flag jj set, regardless of what the worktree currently
#     holds -- unlike re-`git add`ing the path, which would stage the
#     CURRENT worktree content and silently destroy a staged-then-edited
#     (AM) file's originally-staged blob (X) in favor of its edited
#     worktree content (Y).
# Safe to call even if nothing changed; never touches a path that was
# already staged before the guard started, in EITHER shape -- and never
# substitutes worktree content for the caller's staged content.
jj_ita_guard_restore() {
  _guard_repo="$1"
  _guard_before="$2"
  _guard_before_file=$(mktemp)
  printf '%s\n' "$_guard_before" >"$_guard_before_file"

  # Every path staged (in any shape) before the guard started -- never
  # reset one of these, no matter what shape it shows up in now.
  _guard_before_paths_file=$(mktemp)
  cut -f1 "$_guard_before_file" | cut -c4- | sort -u >"$_guard_before_paths_file"

  # path<TAB>mode,sha for paths staged with real content (any
  # 'A'-prefixed shape) before the guard started -- the exact blob to
  # restore if a later jj call reshapes the path into ITA.
  _guard_before_cacheinfo_file=$(mktemp)
  while IFS= read -r _guard_line; do
    [ -n "$_guard_line" ] || continue
    _guard_status=$(printf '%s' "$_guard_line" | cut -f1)
    _guard_cacheinfo=$(printf '%s' "$_guard_line" | cut -f2)
    [ -n "$_guard_cacheinfo" ] || continue
    _guard_path=$(printf '%s' "$_guard_status" | cut -c4-)
    printf '%s\t%s\n' "$_guard_path" "$_guard_cacheinfo" >>"$_guard_before_cacheinfo_file"
  done <"$_guard_before_file"
  rm -f "$_guard_before_file"

  git -C "$_guard_repo" status --porcelain=v1 --untracked-files=no 2>/dev/null \
    | grep '^ A ' \
    | cut -c4- \
    | while IFS= read -r _guard_path; do
        [ -n "$_guard_path" ] || continue
        _guard_saved_cacheinfo=$(awk -F'\t' -v p="$_guard_path" '$1 == p {print $2}' "$_guard_before_cacheinfo_file")
        if [ -n "$_guard_saved_cacheinfo" ]; then
          git -C "$_guard_repo" update-index --add --cacheinfo "${_guard_saved_cacheinfo},${_guard_path}" >/dev/null 2>&1
        elif grep -Fxq "$_guard_path" "$_guard_before_paths_file"; then
          : # Already ITA before the guard started -- already the right shape.
        else
          git -C "$_guard_repo" reset -- "$_guard_path" >/dev/null 2>&1
        fi
      done \
    || true

  rm -f "$_guard_before_paths_file" "$_guard_before_cacheinfo_file"
  return 0
}
