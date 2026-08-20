#!/bin/sh
# Tests for prune_candidates.sh.
#
# Every case below was mutation-verified against a deliberately broken copy
# of the script during development (same discipline as
# dev/scripts/prior_cell_check_test.sh -- see its header for why "a test
# that cannot fail is not a test").
#
# Fixtures are throwaway git repos (mktemp -d + `git init`) so
# PRUNE_CANDIDATES_ROOT can point the script at them instead of the real
# repo, and so git-log-based dating (which the script uses instead of
# filesystem mtime -- see the script header on why mtime is useless under a
# fresh GHA checkout) is under full test control via GIT_AUTHOR_DATE /
# GIT_COMMITTER_DATE.
set -u

SCRIPT="$(cd "$(dirname "$0")" && pwd)/prune_candidates.sh"
PASS=0
FAIL=0

check() { # name expected_rc expected_substring command...
  name=$1
  want_rc=$2
  want_sub=$3
  shift 3
  out=$("$@" 2>&1)
  rc=$?
  if [ "$rc" = "$want_rc" ] && { [ -z "$want_sub" ] || echo "$out" | grep -qF -- "$want_sub"; }; then
    PASS=$((PASS + 1))
    echo "  PASS: $name"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $name (rc=$rc want=$want_rc)"
    echo "$out" | sed 's/^/        /'
  fi
}

# check_not: assert a substring is ABSENT from stdout (used to pin exclusion
# behaviour -- e.g. a cited doc must not appear in the candidates table).
check_not() { # name expected_rc forbidden_substring command...
  name=$1
  want_rc=$2
  forbid_sub=$3
  shift 3
  out=$("$@" 2>&1)
  rc=$?
  if [ "$rc" = "$want_rc" ] && ! echo "$out" | grep -qF -- "$forbid_sub"; then
    PASS=$((PASS + 1))
    echo "  PASS: $name"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $name (rc=$rc want=$want_rc, forbidden string present or rc mismatch)"
    echo "$out" | sed 's/^/        /'
  fi
}

_git_commit() { # date "msg" path...
  d="$1"
  msg="$2"
  shift 2
  ( cd "$FIXTURE" \
    && git add "$@" >/dev/null 2>&1 \
    && GIT_AUTHOR_DATE="${d}T12:00:00" GIT_COMMITTER_DATE="${d}T12:00:00" \
       git -c commit.gpgsign=false commit -q -m "$msg" >/dev/null 2>&1 )
}

_init_fixture_repo() {
  FIXTURE=$(mktemp -d)
  ( cd "$FIXTURE" \
    && git init -q \
    && git config user.email t@t \
    && git config user.name t \
    && git config commit.gpgsign false )
  mkdir -p "$FIXTURE/dev/notes" "$FIXTURE/dev/plans" "$FIXTURE/dev/status" \
    "$FIXTURE/.claude" "$FIXTURE/dev/experiments/_ledger" \
    "$FIXTURE/trading/trading/weinstein/strategy/lib" \
    "$FIXTURE/trading/test_data"
  # A minimal-but-present CLAUDE.md / .claude entry so _is_cited's file-source
  # loop has something to stat without erroring.
  echo "fixture claude.md" >"$FIXTURE/CLAUDE.md"
  echo "fixture rule" >"$FIXTURE/.claude/placeholder.md"
  _git_commit "2025-01-01" "seed" CLAUDE.md .claude/placeholder.md
}

# ==============================================================================
# FIXTURE A: a complete, self-consistent tree where every sanity probe passes
# and every checker has a mix of candidates and correctly-excluded items.
# Reused across most of the "happy path" assertions below.
# ==============================================================================
_init_fixture_repo
TODAY=2026-08-20

# --- Checker 1 fixture: three priorities docs -------------------------------
# uncited (candidate), cited-via-dev/plans (excluded), newest (excluded as
# newest regardless of citation).
echo "old uncited doc, ten lines total" >"$FIXTURE/dev/notes/next-session-priorities-2026-01-01.md"
for i in 1 2 3 4 5 6 7 8 9; do echo "line $i" >>"$FIXTURE/dev/notes/next-session-priorities-2026-01-01.md"; done
_git_commit "2026-01-01" "add old uncited priorities doc" dev/notes/next-session-priorities-2026-01-01.md

echo "old cited doc" >"$FIXTURE/dev/notes/next-session-priorities-2026-01-05.md"
_git_commit "2026-01-05" "add old cited priorities doc" dev/notes/next-session-priorities-2026-01-05.md

echo "newest doc" >"$FIXTURE/dev/notes/next-session-priorities-2026-08-19.md"
_git_commit "2026-08-19" "add newest priorities doc" dev/notes/next-session-priorities-2026-08-19.md

# The citation, in dev/plans/ (one of the four shared citation sources).
echo "See dev/notes/next-session-priorities-2026-01-05.md for context." >"$FIXTURE/dev/plans/citer.md"
_git_commit "2026-01-06" "cite the 01-05 doc from a plan" dev/plans/citer.md

# checker1's pinned production anchor (real-repo file+needle, replicated here
# so the anchor probe passes in the fixture too -- see the script's checker1
# comment for why the anchor is a hardcoded real pair).
echo "See dev/notes/next-session-priorities-2026-05-15.md for context." >"$FIXTURE/dev/plans/sector-concentration-cap-2026-05-15.md"
_git_commit "2026-05-15" "anchor file" dev/plans/sector-concentration-cap-2026-05-15.md

# A citation living ONLY in dev/notes/ must NOT count -- pins the "deliberately
# not dev/notes" design choice (a note's own liveness is unverified, so it
# cannot vouch for another doc's liveness).
mkdir -p "$FIXTURE/dev/notes"
echo "next-session-priorities-2026-01-01.md was a great read" >"$FIXTURE/dev/notes/some-other-note.md"
_git_commit "2026-01-07" "a note mentioning the uncited doc (must not count)" dev/notes/some-other-note.md

# --- Checker 2 fixture: dirs spanning quarantine + citation ------------------
# fuzz-startdate-crash: production's mandatory pinned anchor -- old, uncited.
mkdir -p "$FIXTURE/dev/experiments/fuzz-startdate-crash"
echo "a" >"$FIXTURE/dev/experiments/fuzz-startdate-crash/a.txt"
_git_commit "2026-01-01" "add fuzz-startdate-crash" dev/experiments/fuzz-startdate-crash/a.txt

# old-and-uncited: > 30 days before TODAY (2026-08-20), never mentioned
# anywhere -- must appear as a candidate.
mkdir -p "$FIXTURE/dev/experiments/old-and-uncited-2026-05-01"
echo "a" >"$FIXTURE/dev/experiments/old-and-uncited-2026-05-01/a.txt"
_git_commit "2026-05-01" "add old-and-uncited dir" dev/experiments/old-and-uncited-2026-05-01/a.txt

# old-but-cited: > 30 days old, but its name is cited from dev/status/ -- must
# be EXCLUDED (citation beats age).
mkdir -p "$FIXTURE/dev/experiments/old-but-cited-2026-05-02"
echo "a" >"$FIXTURE/dev/experiments/old-but-cited-2026-05-02/a.txt"
_git_commit "2026-05-02" "add old-but-cited dir" dev/experiments/old-but-cited-2026-05-02/a.txt
echo "see dev/experiments/old-but-cited-2026-05-02 for the run" >"$FIXTURE/dev/status/some-track.md"
_git_commit "2026-05-03" "cite old-but-cited from status" dev/status/some-track.md

# recent-and-uncited: touched WITHIN the 30-day quarantine window (2026-08-05
# is 15 days before TODAY) -- must be EXCLUDED regardless of citation, because
# the citation graph lags creation by days (the exact false-positive this
# quarantine exists to prevent -- see script header).
mkdir -p "$FIXTURE/dev/experiments/recent-and-uncited-2026-08-05"
echo "a" >"$FIXTURE/dev/experiments/recent-and-uncited-2026-08-05/a.txt"
_git_commit "2026-08-05" "add recent-and-uncited dir" dev/experiments/recent-and-uncited-2026-08-05/a.txt

# --- Checker 3 fixture: strategy config + ledger + specs --------------------
cat >"$FIXTURE/trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli" <<'EOF'
type config = {
  enable_test_dead_flag : bool; [@sexp.default false]
      (** A direct default-off flag, tab-indented below to also pin
          [[:space:]] matching indented/tabbed declarations that a
          non-portable `\s` pattern (BSD grep does not expand `\s` inside a
          POSIX/extended regex) would silently miss. *)
	  stops_config : Stop_types_fixture.config;
      (** Nested fast-crash stop, referenced below as
          [stops_config.catastrophic_stop_pct]; default is a no-op. *)
}
EOF
_git_commit "2026-01-01" "add fixture strategy config" trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli

mkdir -p "$FIXTURE/trading/trading/weinstein/stops/lib"
cat >"$FIXTURE/trading/trading/weinstein/stops/lib/stop_types_fixture.mli" <<'EOF'
type config = {
  catastrophic_stop_pct : float; [@sexp.default 0.0]
      (** Fast-crash absolute stop pct; 0.0 is a no-op. *)
}
EOF
_git_commit "2026-01-01" "add fixture nested stop config" trading/trading/weinstein/stops/lib/stop_types_fixture.mli

# Ledger REJECT entries for both flags.
cat >"$FIXTURE/dev/experiments/_ledger/2026-01-02-test-dead-flag.sexp" <<'EOF'
((date 2026-01-02) (slug test-dead-flag)
 (hypothesis "enable_test_dead_flag helps")
 (verdict Reject)
 (notes "REJECT(do-not-revive): fixture entry for enable_test_dead_flag."))
EOF
cat >"$FIXTURE/dev/experiments/_ledger/2026-01-03-catstop.sexp" <<'EOF'
((date 2026-01-03) (slug catstop)
 (hypothesis "catastrophic_stop_pct helps")
 (verdict Reject)
 (notes "REJECT(promotion): fixture entry for catastrophic_stop_pct."))
EOF
_git_commit "2026-01-02" "add ledger rejects" dev/experiments/_ledger/2026-01-02-test-dead-flag.sexp dev/experiments/_ledger/2026-01-03-catstop.sexp

# enable_test_dead_flag: referenced ONLY inside its own dead experiment dir --
# must report ELIGIBLE.
mkdir -p "$FIXTURE/dev/experiments/dead-flag-grid-2026-01-04"
echo "((enable_test_dead_flag true))" >"$FIXTURE/dev/experiments/dead-flag-grid-2026-01-04/cell.sexp"
_git_commit "2026-01-04" "dead flag's own experiment record" dev/experiments/dead-flag-grid-2026-01-04/cell.sexp

# catastrophic_stop_pct: referenced from a LIVE spec outside dev/experiments/
# -- must report NOT ELIGIBLE.
echo "((stops_config ((catastrophic_stop_pct 0.10))))" >"$FIXTURE/trading/test_data/live-scenario.sexp"
_git_commit "2026-01-05" "live spec referencing catastrophic_stop_pct" trading/test_data/live-scenario.sexp

# An odoc-style bracket cross-reference must NOT count as a live .ml
# assignment -- pins the docstring-vs-code false positive an earlier draft
# of this script had (`Friday ticks, when [config.enable_late_stage2_stop_
# tighten = true], raise ...` in the real repo's weinstein_strategy.ml).
mkdir -p "$FIXTURE/trading/trading/weinstein/strategy/lib"
cat >"$FIXTURE/trading/trading/weinstein/strategy/lib/weinstein_strategy_fixture.ml" <<'EOF'
(* Friday ticks, when [config.enable_test_dead_flag = true], raise the stop. *)
let default_config = { enable_test_dead_flag = false }
EOF
_git_commit "2026-01-06" "docstring reference + default_config, not a live assignment" trading/trading/weinstein/strategy/lib/weinstein_strategy_fixture.ml

# ==============================================================================
# Assertions against FIXTURE A
# ==============================================================================
echo "== Fixture A: happy path =="

check "exits 0 on a fully-consistent fixture" 0 "" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker1: reports exactly 1 candidate" 0 "Candidates: 1 files, 10 total lines" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker1: lists the uncited doc" 0 "next-session-priorities-2026-01-01.md" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check_not "checker1: does NOT list the cited doc as a candidate row" 0 "| dev/notes/next-session-priorities-2026-01-05.md |" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check_not "checker1: a note-only mention does not exclude a candidate (dev/notes is not a citation source)" 0 "Candidates: 0 files" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

# 3 candidate dirs: old-and-uncited, fuzz-startdate-crash, AND
# dead-flag-grid-2026-01-04 (checker3's own fixture dir for the ELIGIBLE
# flag case, which is itself old + uncited by the shared citation sources --
# it is only "cited" in the .sexp sense checker3 reads, which checker2 does
# not consult). Both checkers correctly seeing it independently is the
# right behaviour, not a fixture bug.
check "checker2: reports exactly 3 candidate dirs" 0 "Candidates: 3 dirs" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker2: 30-day quarantine EXCLUDES the recent-and-uncited dir" 0 "" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"
check_not "checker2: recent-and-uncited dir does not appear in candidates table" 0 "recent-and-uncited-2026-08-05" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker2: 30-day quarantine INCLUDES an old dir past the boundary" 0 "old-and-uncited-2026-05-01" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check_not "checker2: citation excludes an old-but-cited dir even though it is old enough" 0 "old-but-cited-2026-05-02" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker3: [[:space:]] matches a tab-indented flag declaration" 0 "enable_test_dead_flag" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

# total specs = 2: the grid cell AND the ledger entry itself (its notes
# prose names the flag) -- both under dev/experiments/, so live_specs stays 0.
check "checker3: dead flag referenced only under dev/experiments/ is ELIGIBLE" 0 "| enable_test_dead_flag | ELIGIBLE | 2 | 0 | 0 |" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker3: flag referenced by a live spec is NOT ELIGIBLE" 0 "| catastrophic_stop_pct | NOT ELIGIBLE | 2 | 1 | 0 |" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker3: an odoc bracket cross-reference is not counted as a live .ml assignment" 0 "" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

rm -rf "$FIXTURE"

# ==============================================================================
# FIXTURE B: checker 1's sanity probe fires when its target surface is empty
# (no citations anywhere, and the pinned anchor is absent too).
# ==============================================================================
_init_fixture_repo
echo "old uncited doc" >"$FIXTURE/dev/notes/next-session-priorities-2026-01-01.md"
_git_commit "2026-01-01" "old uncited doc" dev/notes/next-session-priorities-2026-01-01.md
echo "newest doc" >"$FIXTURE/dev/notes/next-session-priorities-2026-08-19.md"
_git_commit "2026-08-19" "newest doc" dev/notes/next-session-priorities-2026-08-19.md
# No dev/plans/sector-concentration-cap-2026-05-15.md, no citation anywhere:
# both the pinned anchor AND the structural backstop (older_count>0,
# cited_others==0) should trip.
mkdir -p "$FIXTURE/dev/experiments/_ledger"

check "checker1 sanity probe fires when nothing is cited and the anchor is absent" 1 "FAIL(checker1): sanity probe failed" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="2026-08-20" sh "$SCRIPT"

rm -rf "$FIXTURE"

# ==============================================================================
# FIXTURE C: checker 2's sanity probe fires when its target surface (the
# fuzz-startdate-crash anchor dir) is entirely absent.
# ==============================================================================
_init_fixture_repo
echo "newest doc" >"$FIXTURE/dev/notes/next-session-priorities-2026-08-19.md"
_git_commit "2026-08-19" "newest doc" dev/notes/next-session-priorities-2026-08-19.md
echo "See dev/notes/next-session-priorities-2026-05-15.md for context." >"$FIXTURE/dev/plans/sector-concentration-cap-2026-05-15.md"
_git_commit "2026-05-15" "anchor file (satisfies checker1 only)" dev/plans/sector-concentration-cap-2026-05-15.md
mkdir -p "$FIXTURE/dev/experiments/some-other-dir-2026-01-01"
echo "a" >"$FIXTURE/dev/experiments/some-other-dir-2026-01-01/a.txt"
_git_commit "2026-01-01" "an experiment dir that is NOT the checker2 anchor" dev/experiments/some-other-dir-2026-01-01/a.txt

check "checker2 sanity probe fires when fuzz-startdate-crash is absent" 1 "FAIL(checker2): sanity probe failed" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="2026-08-20" sh "$SCRIPT"

rm -rf "$FIXTURE"

# ==============================================================================
# FIXTURE D: checker 3's sanity probe fires when catastrophic_stop_pct cannot
# be discovered at all (a different flag name only).
# ==============================================================================
_init_fixture_repo
echo "newest doc" >"$FIXTURE/dev/notes/next-session-priorities-2026-08-19.md"
_git_commit "2026-08-19" "newest doc" dev/notes/next-session-priorities-2026-08-19.md
echo "See dev/notes/next-session-priorities-2026-05-15.md for context." >"$FIXTURE/dev/plans/sector-concentration-cap-2026-05-15.md"
_git_commit "2026-05-15" "anchor file (satisfies checker1 only)" dev/plans/sector-concentration-cap-2026-05-15.md
mkdir -p "$FIXTURE/dev/experiments/fuzz-startdate-crash"
echo "a" >"$FIXTURE/dev/experiments/fuzz-startdate-crash/a.txt"
_git_commit "2026-01-01" "fuzz-startdate-crash (satisfies checker2 only)" dev/experiments/fuzz-startdate-crash/a.txt
cat >"$FIXTURE/trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli" <<'EOF'
type config = {
  enable_unrelated_flag : bool; [@sexp.default false]
}
EOF
_git_commit "2026-01-01" "a strategy config with no catastrophic_stop_pct anywhere" trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli

check "checker3 sanity probe fires when catastrophic_stop_pct cannot be discovered" 1 "FAIL(checker3): sanity probe failed" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="2026-08-20" sh "$SCRIPT"

rm -rf "$FIXTURE"

# ==============================================================================
# Usage errors
# ==============================================================================
check "unexpected argument exits 2" 2 "usage:" sh "$SCRIPT" some-argument

echo
echo "prune_candidates_test: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ] || exit 1
