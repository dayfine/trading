#!/bin/sh
# Linter: tracked-build-artifact check.
#
# Fails if a file is TRACKED in git while also matching a .gitignore
# pattern. `git add -f` (or a file that was tracked BEFORE its .gitignore
# pattern existed) silently defeats the ignore rule, so the file keeps
# being rewritten -- and re-dirtying the working tree -- on every build.
# This is the #2248 bug class (trading/compile_commands.json was tracked
# and re-committed three times: #1299, #2085, #2129) generalized to a check
# for the *class*, not just that one path. See dev/status/cleanup.md,
# entry `tracked_artifact_linter`.
#
# ---------------------------------------------------------------------------
# Design trade-off (read before editing this script or its exceptions)
# ---------------------------------------------------------------------------
#
# The filed finding offered two fix shapes:
#   (a) DYNAMIC -- "after a clean `dune build`, `git status --porcelain` is
#       empty". Catches any artifact type, including ones nobody predicted,
#       but it presumes a build JUST ran, is sensitive to unrelated
#       working-tree dirt, and is awkward inside a dune sandboxed rule
#       (shelling to git mid-build, with an unclear cwd, from inside the
#       very build whose outputs it would be measuring). Not used here.
#   (b) STATIC -- "no path matching known artifact patterns appears in
#       `git ls-files`". Dune-safe and deterministic, but a hand-maintained
#       pattern list only catches artifact kinds someone already
#       enumerated; a brand-new artifact type sails through silently --
#       the exact class-vs-instance gap the finding exists to close.
#
# This check is STATIC (like (b)) but sidesteps the hand-maintained-list gap
# by using `git ls-files -i -c --exclude-per-directory=.gitignore` as the
# primitive instead of a second pattern list: it reports every file that is
# BOTH tracked AND ignored, using .gitignore itself as the single source of
# truth for "what counts as an artifact." Any pattern added to .gitignore
# (*.cmi, *.install, compile_commands.json, a brand-new entry added next
# month, ...) is automatically covered with zero duplication here -- this
# closes the *class*, including future artifact kinds, as long as they get
# a .gitignore entry (see "what this does NOT catch" below).
#
# CAUTION verified against real data before picking this shape: a naive
# "fail on any output" gate does NOT work. On main today,
# `git ls-files -i -c --exclude-per-directory=.gitignore` returns ~1334
# hits, and 1285 of them are `trading/test_data/**/data.csv` /
# `data.metadata.sexp` --
# deliberately committed golden bars. Their .gitignore pattern was added
# later to protect *new* fetches only; .gitignore's own comment says so
# explicitly ("Already-tracked golden bars are UNAFFECTED"). The remaining
# 49 are pre-existing, pre-this-linter commits under three
# `dev/backtest/scenarios-2026-04-14-*/` run dirs and four
# `dev/experiments/*/` run dirs -- real debt, but out of scope for this PR
# (filed as a harness follow-up; see dev/status/harness.md).
#
# So the policy is default-DENY (any tracked+ignored file is a violation)
# with an explicit, narrow ALLOW-list of path prefixes recorded in
# linter_exceptions.conf under the `tracked_artifact` key -- same
# convention as this file's `magic_numbers` / `mli_coverage` entries.
# Anything NOT on that allow-list is a hard FAIL, including future artifact
# classes that aren't yet enumerated anywhere -- that is the property a
# hand-maintained pattern list (shape (b) as originally proposed) cannot
# offer.
#
# What this DOES catch: any file tracked in git that also matches a
# CURRENT .gitignore pattern and is not explicitly allow-listed --
# including .gitignore patterns added after this check was written, with
# zero maintenance to this script.
#
# What this does NOT catch: a build artifact of a kind nobody has added to
# .gitignore at all. If dune starts emitting a brand-new artifact type that
# was never ignored, this check stays silent until someone adds the
# .gitignore pattern -- at which point it starts protecting that pattern
# automatically, with no further changes here. Closing that residual gap
# needs property (a) above (a post-build `git status --porcelain` gate,
# run outside `dune runtest` e.g. as a separate CI step); we judged the
# dune-sandbox awkwardness not worth it given there are zero known
# instances of an unignored artifact type today. It also does NOT catch a
# force-added artifact under an existing broad ALLOW-list prefix: the
# `trading/test_data` exception (`review_at: never`) covers all 1285 files
# in that subtree for the golden-bars use case, but the same prefix match
# silently exempts ANY future artifact kind added under that subtree too,
# not just golden bars -- e.g. a force-added `compile_commands.json`
# dropped into `trading/test_data/` would pass with exit 0 (demonstrated
# during qc-behavioral review of this check).
#
# Considered and rejected: also using `git ls-files -i -o` (-o = "other",
# i.e. untracked-but-ignored) to warn about ignored-but-not-yet-tracked
# artifacts sitting in the tree. Rejected because that set is EXPECTED to
# be large and constantly changing (every build's compile_commands.json,
# every _build/ output, ...) -- it is precisely what .gitignore is working
# as designed to hide, not a violation.
#
# `git ls-files -i -c --exclude-per-directory=.gitignore` needs the REAL
# working tree (a dune sandbox mirror under _build/default/ has no .git
# directory), so this
# script resolves repo_root() and runs git there rather than from its own
# sandboxed cwd. The owning dune rule declares (universe) because git's
# tracked/ignored state can change independent of any dune-tracked source
# file -- same reasoning as no_python_check.sh / status_file_integrity.sh /
# index_size_linter.sh (see check_universe_deps.sh for the mechanical
# guard that enforces this).

set -e

. "$(dirname "$0")/_check_lib.sh"

command -v git >/dev/null 2>&1 || die "tracked_artifact_linter: git not found on PATH"

REPO_ROOT="$(repo_root)"
EXCEPTIONS_CONF="$(dirname "$0")/linter_exceptions.conf"

# Build the allow-list prefix pattern from linter_exceptions.conf's
# `tracked_artifact <prefix> <reason>  # review_at: <value>` entries.
ALLOW_PATTERN=""
if [ -f "$EXCEPTIONS_CONF" ]; then
  while IFS= read -r line; do
    case "$line" in
      '#'* | '') continue ;;
    esac
    linter=$(printf '%s' "$line" | awk '{print $1}')
    prefix=$(printf '%s' "$line" | awk '{print $2}')
    if [ "$linter" = "tracked_artifact" ] && [ -n "$prefix" ]; then
      if [ -n "$ALLOW_PATTERN" ]; then
        ALLOW_PATTERN="${ALLOW_PATTERN}|^${prefix}"
      else
        ALLOW_PATTERN="^${prefix}"
      fi
    fi
  done < "$EXCEPTIONS_CONF"
fi

# `-c safe.directory="$REPO_ROOT"` -- required so this works inside dune's
# sandboxed CI environment. `actions/checkout` adds a safe.directory
# exception, but it writes that into a TEMPORARY HOME
# (/__w/_temp/<uuid>/.gitconfig) that the dune-sandboxed subprocess running
# this script does not inherit; without the -c override every git
# invocation here fails with "fatal: detected dubious ownership" (see
# repo_root()'s comment above for the same class of issue with
# `git rev-parse`). Passed per-invocation via -c (not written to any
# .gitconfig) so it doesn't mutate shared state other checks/processes
# might rely on. $REPO_ROOT is the directory we `cd` into immediately
# before running git, so it is exactly the directory git's ownership check
# is evaluated against -- no need for a blanket `safe.directory=*`.
#
# `--exclude-per-directory=.gitignore` instead of `--exclude-standard` --
# QC residual R4, completed. --exclude-standard reads THREE sources: the
# repo-controlled `.gitignore` files, plus `.git/info/exclude` and any
# configured `core.excludesFile`, both of which are developer-local. Only
# repo-controlled patterns can legitimately define "what counts as an
# artifact" for a merge-gating check; a developer-local exclude makes the
# check report a legitimately-tracked source file as a violation on one
# machine and not on CI.
#
# The original R4 fix pinned `core.excludesFile=/dev/null`, which closed
# the second source but left `.git/info/exclude` -- which has no config
# knob to neutralise -- still live. That gap was not hypothetical: Claude
# Code writes `**/.claude/scheduled_tasks.lock` and
# `**/.claude/settings.local.json` into `.git/info/exclude`, and both of
# those paths are TRACKED on main, so `dune runtest` failed on every
# developer machine with those entries while CI (a fresh checkout, empty
# info/exclude) stayed green -- a local-only red that hides real failures
# behind noise.
#
# --exclude-per-directory reads ONLY the named per-directory file, at every
# level of the traversal, and consults neither developer-local source. It
# is exactly the "repo-controlled patterns only" invariant this check
# needs, expressed positively rather than by subtracting one leak at a
# time. Measured on main 2026-08-13: --exclude-standard returns 1336 hits,
# --exclude-per-directory=.gitignore returns 1334, and a `comm` of the two
# sorted outputs differs by exactly the two info/exclude paths above and
# nothing else. `core.excludesFile` is no longer overridden because it is no
# longer read.
#
# That measurement establishes the SET IDENTITY and nothing more. It does
# NOT establish that nested `.gitignore` files are still honoured, though an
# earlier draft of this comment claimed it did: `git ls-files -i -c
# --exclude-from=.gitignore`, which reads the root file and performs no
# per-directory traversal whatsoever, returns the identical 1334 on this
# tree -- because both nested `.gitignore` files that exist here
# (`trading/analysis/data/sources/eodhd/` → `secrets`,
# `dev/experiments/cell-e-15y-2026-05-07/` → `trade_audit.sexp`) match ZERO
# tracked files and so cannot move either count. Nested traversal is
# guaranteed by git's own definition (--exclude-standard IS
# --exclude-per-directory=.gitignore plus the two local sources) and is
# pinned behaviourally by fixture 5's `sub/nested.subartifact`, NOT by the
# numbers above. Keep it that way: this check's whole subject is silent
# wrong answers, and `--exclude-from` reads as a tightening in the same
# direction, so an unpinned invariant here is a plausible future edit that
# narrows the check to the root file with nothing to catch it.
#
# Capture git's exit status explicitly (VAR=$(cmd) && CODE=0 || CODE=$?,
# not the sete_diagnostics_check.sh anti-pattern of a bare `VAR=$(cmd);
# CODE=$?`, which trips `set -e` on the assignment itself before CODE=$? is
# ever reached -- see H-CHECK-SETE-DIAGNOSTICS and jj_workspace_smoke.sh
# for the same idiom). This is what actually fixes the CI failure this
# rework addresses: previously a git error (e.g. the dubious-ownership
# fatal) produced empty stdout, which read as "zero tracked+ignored files"
# -- a false OK -- right up until `set -e` killed the script on the failed
# assignment with no FAIL: line at all. Now a git failure is reported
# explicitly and distinctly from "0 violations found".
TRACKED_IGNORED=$(cd "$REPO_ROOT" && git -c safe.directory="$REPO_ROOT" ls-files -i -c --exclude-per-directory=.gitignore 2>&1) && GIT_CODE=0 || GIT_CODE=$?

if [ "$GIT_CODE" -ne 0 ]; then
  echo "FAIL: tracked_artifact_linter -- could not read the git index: ${TRACKED_IGNORED}"
  exit 1
fi

VIOLATIONS=""
if [ -n "$TRACKED_IGNORED" ]; then
  # Read from a heredoc (real fd), not a pipe, so the loop runs in THIS
  # shell and VIOLATIONS accumulated inside it survives past the loop --
  # `echo "$X" | while ...` would run the loop in a subshell under dash and
  # silently drop everything it accumulated. Same pattern as
  # index_size_linter.sh's `done < "$INDEX"`.
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    if [ -n "$ALLOW_PATTERN" ] && printf '%s' "$path" | grep -qE "$ALLOW_PATTERN"; then
      continue
    fi
    VIOLATIONS="${VIOLATIONS}  $path\n"
  done <<EOF
$TRACKED_IGNORED
EOF
fi

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: tracked_artifact_linter -- tracked file(s) also match a .gitignore pattern:"
  printf '%b' "$VIOLATIONS"
  echo ""
  echo "  Each path above is BOTH tracked in git AND matched by .gitignore -- almost"
  echo "  always the result of 'git add -f' bypassing an ignore rule, or a file that"
  echo "  was tracked before its .gitignore pattern existed (the #2248 bug class)."
  echo "  Fix: 'git rm --cached <path>' to untrack it (this is what #2248 did for"
  echo "  trading/compile_commands.json). If it is a deliberate, permanent exception"
  echo "  (like the committed golden bars under trading/test_data/), add a line:"
  echo "    tracked_artifact <path-prefix> <reason>  # review_at: <value>"
  echo "  to linter_exceptions.conf."
  exit 1
fi

echo "OK: tracked_artifact_linter -- no tracked file matches a .gitignore pattern outside allow-listed exceptions."
