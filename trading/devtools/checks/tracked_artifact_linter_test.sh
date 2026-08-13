#!/bin/sh
# Fixture-driven self-test for tracked_artifact_linter.sh
# (H-TRACKED-ARTIFACT-SELF-TEST, filed 2026-08-09 during PR #2252 rework /
# qc-behavioral review).
#
# tracked_artifact_linter.sh's core logic is non-trivial (allow-list prefix
# construction from linter_exceptions.conf, `-i -c --exclude-per-directory=.gitignore`
# semantics, the anchored-`^prefix` allow-list match, and the git-error
# short-circuit added by PR #2252) and had no fixture coverage. This test
# builds real throwaway git repos under `mktemp -d` (real `git init`, real
# `.gitignore`, real `git add -f`) and exercises the four cases
# qc-behavioral verified by hand during that review:
#
#   1. Novel .gitignore pattern, positive control: a freshly force-added
#      file matching a .gitignore pattern that has NO tracked_artifact
#      allow-list entry -> expect exit 1, path named in output.
#   2. Contains-but-not-prefixed, negative control: an allow-list entry
#      whose prefix is a SUBSTRING of a violating path but not an anchored
#      prefix (entry "foo/bar" vs. path "xfoo/bar/baz") -> expect exit 1
#      (NOT allow-listed). Pins the anchored `^prefix` semantics documented
#      in the linter's own header and in linter_exceptions.conf's
#      `tracked_artifact` banner.
#   3. Unignored-artifact-type limitation: a force-added file that matches
#      NO .gitignore pattern at all -> expect exit 0. This is a documented
#      blind spot (see tracked_artifact_linter.sh "What this does NOT
#      catch"); the fixture pins that the blind spot is exactly this shape
#      and not wider.
#   4. Git-error path (added by PR #2252's rework): the git invocation
#      fails (here: REPO_ROOT points at a directory that isn't a git repo
#      at all) -> expect the distinct
#      "FAIL: tracked_artifact_linter -- could not read the git index: ..."
#      message and exit 1, NOT a silent "0 violations" false-OK. This is
#      the exact CI failure class (`fatal: detected dubious ownership`)
#      PR #2252's rework fixed; this fixture pins it against regressing
#      back to the pre-fix `set -e`-kills-silently shape.
#   5. Developer-local excludes, added when the linter moved from
#      `--exclude-standard` to `--exclude-per-directory=.gitignore`: one
#      repo with a tracked file matched only by `.git/info/exclude`, a
#      tracked file matched only by `core.excludesFile`, and a tracked
#      file matched by the repo's own `.gitignore` -> expect exit 1 naming
#      ONLY the last one. Carrying all three shapes in one repo means the
#      fixture cannot be satisfied by a linter that simply stopped
#      ignoring things. Mutation that reddens it: reinstating
#      `--exclude-standard` (either developer-local path then appears in
#      the violation list).
#
# Each of fixtures 1-3 runs against a PRIVATE copy of the linter (plus
# _check_lib.sh) in its own mktemp'd "checks dir", paired with a
# controlled linter_exceptions.conf -- because tracked_artifact_linter.sh
# resolves EXCEPTIONS_CONF relative to its OWN script location
# ($(dirname "$0")/linter_exceptions.conf), not via REPO_ROOT. This keeps
# each fixture's allow-list independent of both the real repo's
# linter_exceptions.conf and of each other. REPO_ROOT (an explicit env-var
# override honored by _check_lib.sh's repo_root()) points the linter at a
# separate, real throwaway git repo per fixture. Same two-knob pattern as
# run_in_env_root_check.sh (copies the script under test into a fixture
# tree) and check_universe_deps_test.sh (REPO_ROOT override).
#
# How to re-verify by hand:
#   sh trading/devtools/checks/tracked_artifact_linter_test.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

LINTER="$(dirname "$0")/tracked_artifact_linter.sh"
LIB="$(dirname "$0")/_check_lib.sh"
[ -f "$LINTER" ] || die "tracked_artifact_linter_test: $LINTER not found"

if ! command -v git >/dev/null 2>&1; then
  echo "OK: tracked_artifact_linter_test — SKIPPED (git not on PATH)."
  exit 0
fi

PASS=0
FAIL=0

ok() {
  printf 'OK: %s\n' "$1"
  PASS=$((PASS + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

BASE_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$BASE_DIR"
}
trap cleanup EXIT INT TERM

# Private fixture "checks dir": a copy of the linter + _check_lib.sh, paired
# with a controlled linter_exceptions.conf. $1 = dir to create,
# $2 = linter_exceptions.conf contents (may be empty).
make_fixture_checks_dir() {
  mkdir -p "$1"
  cp "$LINTER" "$1/tracked_artifact_linter.sh"
  cp "$LIB" "$1/_check_lib.sh"
  printf '%s' "$2" > "$1/linter_exceptions.conf"
}

# Real throwaway git repo: $1 = repo dir.
init_git_repo() {
  mkdir -p "$1"
  git init -q "$1"
  git -C "$1" config user.email "test@example.com"
  git -C "$1" config user.name "tracked_artifact_linter_test"
}

# =============================================================================
# Fixture 1: novel .gitignore pattern, positive control -> exit 1, path named
# =============================================================================

REPO1="${BASE_DIR}/repo1"
init_git_repo "$REPO1"
echo '*.novelartifact' > "${REPO1}/.gitignore"
echo 'data' > "${REPO1}/foo.novelartifact"
git -C "$REPO1" add .gitignore
git -C "$REPO1" add -f foo.novelartifact
git -C "$REPO1" commit -q -m init

CHECKS1="${BASE_DIR}/checks1"
make_fixture_checks_dir "$CHECKS1" ""

set +e
OUT1=$(REPO_ROOT="$REPO1" sh "${CHECKS1}/tracked_artifact_linter.sh" 2>&1)
CODE1=$?
set -e

if [ "$CODE1" -ne 0 ] && echo "$OUT1" | grep -q "foo.novelartifact"; then
  ok "fixture 1 — novel .gitignore pattern with no allow-list entry -> FAIL, names foo.novelartifact"
else
  bad "fixture 1 — expected non-zero exit naming foo.novelartifact; got exit=$CODE1 output=<<$OUT1>>"
fi

# =============================================================================
# Fixture 2: contains-but-not-prefixed, negative control -> exit 1
# (allow-list entry "foo/bar" must NOT match violating path "xfoo/bar/baz")
# =============================================================================

REPO2="${BASE_DIR}/repo2"
init_git_repo "$REPO2"
echo 'xfoo/' > "${REPO2}/.gitignore"
mkdir -p "${REPO2}/xfoo/bar"
echo 'data' > "${REPO2}/xfoo/bar/baz"
git -C "$REPO2" add .gitignore
git -C "$REPO2" add -f xfoo/bar/baz
git -C "$REPO2" commit -q -m init

CHECKS2="${BASE_DIR}/checks2"
make_fixture_checks_dir "$CHECKS2" \
  "tracked_artifact foo/bar substring-of-xfoo/bar/baz-not-a-prefix  # review_at: 2099-01-01
"

set +e
OUT2=$(REPO_ROOT="$REPO2" sh "${CHECKS2}/tracked_artifact_linter.sh" 2>&1)
CODE2=$?
set -e

if [ "$CODE2" -ne 0 ] && echo "$OUT2" | grep -q "xfoo/bar/baz"; then
  ok "fixture 2 — allow-list entry 'foo/bar' does not match 'xfoo/bar/baz' (contains, not anchored prefix) -> FAIL"
else
  bad "fixture 2 — expected non-zero exit naming xfoo/bar/baz (NOT allow-listed); got exit=$CODE2 output=<<$OUT2>>"
fi

# =============================================================================
# Fixture 3: unignored-artifact-type limitation -> exit 0 (documented blind
# spot: a force-added file matching NO .gitignore pattern is invisible to
# `git ls-files -i -c --exclude-per-directory=.gitignore`, so the linter cannot see it)
# =============================================================================

REPO3="${BASE_DIR}/repo3"
init_git_repo "$REPO3"
echo '*.log' > "${REPO3}/.gitignore"
echo 'data' > "${REPO3}/plain.txt"
git -C "$REPO3" add .gitignore
git -C "$REPO3" add -f plain.txt
git -C "$REPO3" commit -q -m init

CHECKS3="${BASE_DIR}/checks3"
make_fixture_checks_dir "$CHECKS3" ""

set +e
OUT3=$(REPO_ROOT="$REPO3" sh "${CHECKS3}/tracked_artifact_linter.sh" 2>&1)
CODE3=$?
set -e

if [ "$CODE3" -eq 0 ] && echo "$OUT3" | grep -q "^OK:"; then
  ok "fixture 3 — force-added file matching no .gitignore pattern is invisible to the linter -> exit 0 (blind spot pinned)"
else
  bad "fixture 3 — expected exit 0 with an OK: line (documented blind spot); got exit=$CODE3 output=<<$OUT3>>"
fi

# =============================================================================
# Fixture 4: git-error path -> distinct FAIL message, exit 1, NOT a silent
# "0 violations" false-OK (the exact class PR #2252's rework fixed)
# =============================================================================

NOT_A_REPO="${BASE_DIR}/not_a_repo"
mkdir -p "$NOT_A_REPO"
# Deliberately no `git init` here -- REPO_ROOT points at a plain directory,
# so the linter's `git ls-files` invocation fails.

set +e
OUT4=$(REPO_ROOT="$NOT_A_REPO" sh "$LINTER" 2>&1)
CODE4=$?
set -e

if [ "$CODE4" -ne 0 ] \
  && echo "$OUT4" | grep -q "FAIL: tracked_artifact_linter -- could not read the git index:" \
  && ! echo "$OUT4" | grep -q "^OK:"; then
  ok "fixture 4 — git invocation failure (non-repo REPO_ROOT) -> distinct FAIL message, exit 1, no false-OK"
else
  bad "fixture 4 — expected non-zero exit with the 'could not read the git index' message and no OK: line; got exit=$CODE4 output=<<$OUT4>>"
fi

# =============================================================================
# Fixture 5: developer-local excludes must NOT produce violations, while
# repo-controlled .gitignore patterns still must. One repo carrying all
# three shapes at once, so the fixture cannot be satisfied by a linter that
# simply stopped ignoring things:
#
#   local_via_info_exclude.txt  tracked, matched ONLY by .git/info/exclude
#   local_via_excludes_file.txt tracked, matched ONLY by core.excludesFile
#   real.novelartifact          tracked, matched by the repo's ROOT .gitignore
#   sub/nested.subartifact      tracked, matched ONLY by sub/.gitignore
#
# The NESTED file is what distinguishes `--exclude-per-directory=.gitignore`
# from a root-only primitive. `git ls-files -i -c --exclude-from=.gitignore`
# reads the root file and does no per-directory traversal at all, yet on this
# repo it returns a byte-identical 1334 hits -- because BOTH nested
# `.gitignore` files that exist here (`trading/analysis/data/sources/eodhd/`
# → `secrets`, `dev/experiments/cell-e-15y-2026-05-07/` → `trade_audit.sexp`)
# match ZERO tracked files. So the 1336 → 1334 measurement quoted for this
# change says nothing whatsoever about nested traversal, and `--exclude-from`
# reads as a tightening in the same direction -- a plausible future edit that
# would silently narrow this merge-gating check to the root file with no
# check in this repo able to tell. `sub/nested.subartifact` is the assertion
# that closes that: it can only be reported if per-directory patterns are
# read at depth.
#
# Expect exit 1 naming real.novelartifact AND sub/nested.subartifact and
# NEITHER developer-local path. `.git/info/exclude` and
# `core.excludesFile` are per-developer state that never reaches CI, so a
# check gated on them reports a legitimately-tracked source file as a
# violation on one machine and not another. See the linter's
# `--exclude-per-directory` comment for the real instance: Claude Code
# writes `**/.claude/scheduled_tasks.lock` and
# `**/.claude/settings.local.json` into `.git/info/exclude`, both of which
# are tracked on main, and `--exclude-standard` turned that into a
# local-only `dune runtest` failure invisible to CI.
# =============================================================================

REPO5="${BASE_DIR}/repo5"
init_git_repo "$REPO5"
echo '*.novelartifact' > "${REPO5}/.gitignore"
echo 'data' > "${REPO5}/real.novelartifact"
echo 'data' > "${REPO5}/local_via_info_exclude.txt"
echo 'data' > "${REPO5}/local_via_excludes_file.txt"
echo 'local_via_info_exclude.txt' >> "${REPO5}/.git/info/exclude"
echo 'local_via_excludes_file.txt' > "${BASE_DIR}/global_excludes"
git -C "$REPO5" config core.excludesFile "${BASE_DIR}/global_excludes"
# The nested pattern is deliberately one the ROOT .gitignore cannot match, so
# reporting it requires reading sub/.gitignore specifically.
mkdir -p "${REPO5}/sub"
echo '*.subartifact' > "${REPO5}/sub/.gitignore"
echo 'data' > "${REPO5}/sub/nested.subartifact"
git -C "$REPO5" add .gitignore sub/.gitignore
git -C "$REPO5" add -f real.novelartifact local_via_info_exclude.txt \
  local_via_excludes_file.txt sub/nested.subartifact
git -C "$REPO5" commit -q -m init

CHECKS5="${BASE_DIR}/checks5"
make_fixture_checks_dir "$CHECKS5" ""

set +e
OUT5=$(REPO_ROOT="$REPO5" sh "${CHECKS5}/tracked_artifact_linter.sh" 2>&1)
CODE5=$?
set -e

if [ "$CODE5" -ne 0 ] \
  && echo "$OUT5" | grep -q "real.novelartifact" \
  && echo "$OUT5" | grep -q "sub/nested.subartifact" \
  && ! echo "$OUT5" | grep -q "local_via_info_exclude" \
  && ! echo "$OUT5" | grep -q "local_via_excludes_file"; then
  ok "fixture 5 — root AND nested .gitignore both caught (real.novelartifact, sub/nested.subartifact) while developer-local .git/info/exclude and core.excludesFile entries are ignored"
else
  bad "fixture 5 — expected non-zero exit naming real.novelartifact and sub/nested.subartifact but NEITHER developer-local path; got exit=$CODE5 output=<<$OUT5>>"
fi

cleanup
trap - EXIT INT TERM

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: tracked_artifact_linter_test — ${PASS} passed, ${FAIL} failed." >&2
  exit 1
fi

echo "OK: tracked_artifact_linter_test — ${PASS} assertion(s) passed, 0 failed."
