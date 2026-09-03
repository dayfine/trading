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

# F2 rework requirement: checker 1 must STILL propose a priorities doc whose
# ONLY citation is from ANOTHER priorities doc (not just an arbitrary note --
# this is the specific circularity the checker1-vs-checker2 citation-source
# asymmetry exists to prevent collapsing on). 01-02 is cited only by 01-03,
# and 01-03 is itself uncited by any real source -- both must be candidates.
echo "doc cited only by another priorities doc" >"$FIXTURE/dev/notes/next-session-priorities-2026-01-02.md"
_git_commit "2026-01-02" "add doc cited only by another priorities doc" dev/notes/next-session-priorities-2026-01-02.md
echo "See dev/notes/next-session-priorities-2026-01-02.md for backstory." >"$FIXTURE/dev/notes/next-session-priorities-2026-01-03.md"
_git_commit "2026-01-03" "priorities doc citing 01-02 (a dev/notes-only citation)" dev/notes/next-session-priorities-2026-01-03.md

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

# F2 rework requirement: checker 2 must NOT propose a dir whose ONLY citation
# is in dev/notes/ (unlike checker 1, dev/notes/ IS a citation source for
# checker 2 -- a note genuinely referencing an experiment dir means deleting
# it breaks that reference; see the CITATION SOURCES header comment for the
# measured 5x overstatement this fixes). Old enough to clear quarantine, and
# NOT cited by ledger/plans/status/.claude/CLAUDE.md -- only by a dev/notes
# writeup.
mkdir -p "$FIXTURE/dev/experiments/notes-only-cited-2026-05-04"
echo "a" >"$FIXTURE/dev/experiments/notes-only-cited-2026-05-04/a.txt"
_git_commit "2026-05-04" "add dir cited only via dev/notes" dev/experiments/notes-only-cited-2026-05-04/a.txt
echo "see dev/experiments/notes-only-cited-2026-05-04 in this writeup" >"$FIXTURE/dev/notes/some-writeup-2026-05-05.md"
_git_commit "2026-05-05" "cite the dir from a dev/notes writeup (checker2-only citation source)" dev/notes/some-writeup-2026-05-05.md

# --- Checker 3 fixture: strategy config + ledger + specs --------------------
cat >"$FIXTURE/trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli" <<'EOF'
type config = {
	enable_test_dead_flag : bool; [@sexp.default false]
      (** A direct default-off flag, deliberately TAB-indented. This is the
          line checker 3's anchored grep scans, so the tab pins that the
          leading-whitespace class is tab-tolerant: mutating
          [^[[:space:]]*] to [^ *] turns 26/0 into 23/3.

          Keep the tab. An earlier version of this fixture was
          space-indented while its comment claimed otherwise, so the
          tab-hostile mutant still shipped 26/0 — the assertion existed in
          four places and was pinned in none.

          Note (not testable here): [[:space:]] is also the portable choice
          because [\s] is a GNU extension with no meaning in POSIX ERE, so an
          implementation may read it as whitespace, as a literal [s], or as
          undefined. Every grep on hand expands it, so CI cannot pin that —
          tab tolerance is the property this fixture actually proves. *)
  enable_test_unclassified_flag : bool; [@sexp.default false]
      (** A flag with a ledger REJECT but NO recorded do-not-revive
          classification anywhere (no inventory row, no ledger/memory
          marker) -- must report NEEDS-CLASSIFICATION, never default to
          ELIGIBLE (F1, rework iteration 1, 2026-08-20). *)
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
# This flag's ledger entry deliberately contains "do-not-revive" INSIDE A
# NEGATION -- "NO do-not-revive classification recorded" -- mirroring the
# real dev/agent-memory/project_continuation_combined_rejected.md counter-
# example found during rework (that memory's sentence "No do-not-revive is
# recorded anywhere" would be misread as a confirmation by a bare substring
# search). This pins _flag_classification's negation guard directly, not
# just via the inventory path.
cat >"$FIXTURE/dev/experiments/_ledger/2026-01-08-test-unclassified-flag.sexp" <<'EOF'
((date 2026-01-08) (slug test-unclassified-flag)
 (hypothesis "enable_test_unclassified_flag helps")
 (verdict Reject)
 (notes "Reject(promotion): NO do-not-revive classification recorded for this fixture entry."))
EOF
_git_commit "2026-01-02" "add ledger rejects" dev/experiments/_ledger/2026-01-02-test-dead-flag.sexp dev/experiments/_ledger/2026-01-03-catstop.sexp dev/experiments/_ledger/2026-01-08-test-unclassified-flag.sexp

# enable_test_dead_flag: referenced ONLY inside its own dead experiment dir --
# must report ELIGIBLE.
mkdir -p "$FIXTURE/dev/experiments/dead-flag-grid-2026-01-04"
echo "((enable_test_dead_flag true))" >"$FIXTURE/dev/experiments/dead-flag-grid-2026-01-04/cell.sexp"
_git_commit "2026-01-04" "dead flag's own experiment record" dev/experiments/dead-flag-grid-2026-01-04/cell.sexp

# catastrophic_stop_pct: referenced from a LIVE spec outside dev/experiments/
# -- must report NOT ELIGIBLE.
echo "((stops_config ((catastrophic_stop_pct 0.10))))" >"$FIXTURE/trading/test_data/live-scenario.sexp"
_git_commit "2026-01-05" "live spec referencing catastrophic_stop_pct" trading/test_data/live-scenario.sexp

# enable_test_unclassified_flag: live-ref CLEAN (referenced only inside its
# own dev/experiments dir), but no do-not-revive classification anywhere --
# must report NEEDS-CLASSIFICATION, not ELIGIBLE.
mkdir -p "$FIXTURE/dev/experiments/unclassified-flag-grid-2026-01-08"
echo "((enable_test_unclassified_flag true))" >"$FIXTURE/dev/experiments/unclassified-flag-grid-2026-01-08/cell.sexp"
_git_commit "2026-01-08" "unclassified flag's own experiment record" dev/experiments/unclassified-flag-grid-2026-01-08/cell.sexp

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

# 3 candidates: 01-01 (uncited, 10 lines), 01-02 (cited only by 01-03, a
# priorities doc -- dev/notes is not a checker-1 citation source), and 01-03
# itself (uncited by any real source). 12 total lines. 01-05 (cited via
# dev/plans) is the only exclusion, hence "excluded: 1".
check "checker1: reports exactly 3 candidates, 12 total lines" 0 "Candidates: 3 files, 12 total lines (cited-elsewhere and excluded: 1)." \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker1: lists the uncited doc" 0 "next-session-priorities-2026-01-01.md" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check_not "checker1: does NOT list the cited doc as a candidate row" 0 "| dev/notes/next-session-priorities-2026-01-05.md |" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check_not "checker1: a note-only mention does not exclude a candidate (dev/notes is not a citation source)" 0 "Candidates: 0 files" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

# F2 rework requirement, pinned explicitly: a priorities doc cited ONLY by
# another priorities doc is STILL a candidate -- dev/notes/ never counts as
# a checker-1 citation source, even when the citer is itself the same
# category of document.
check "checker1: a doc cited only by another priorities doc is still a candidate" 0 "| dev/notes/next-session-priorities-2026-01-02.md |" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

# 4 candidate dirs: old-and-uncited, fuzz-startdate-crash, dead-flag-grid
# (checker3's own ELIGIBLE-flag fixture dir), and unclassified-flag-grid
# (checker3's own NEEDS-CLASSIFICATION-flag fixture dir) -- all old and
# uncited by the checker-2 citation sources. They are only "cited" in the
# .sexp sense checker3 reads, which checker2 does not consult; both
# checkers correctly seeing their own dirs independently is right, not a
# fixture bug.
check "checker2: reports exactly 4 candidate dirs" 0 "Candidates: 4 dirs" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker2: 30-day quarantine EXCLUDES the recent-and-uncited dir" 0 "" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"
check_not "checker2: recent-and-uncited dir does not appear in candidates table" 0 "recent-and-uncited-2026-08-05" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker2: 30-day quarantine INCLUDES an old dir past the boundary" 0 "old-and-uncited-2026-05-01" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check_not "checker2: citation excludes an old-but-cited dir even though it is old enough" 0 "old-but-cited-2026-05-02" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

# F2 rework requirement, pinned explicitly: unlike checker 1, checker 2 DOES
# treat dev/notes/ as a citation source, so a dir cited only from a
# dev/notes/ writeup must be EXCLUDED, not proposed.
check_not "checker2: a dir cited only via dev/notes is NOT proposed" 0 "notes-only-cited-2026-05-04" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker3: anchored flag grep tolerates a TAB-indented declaration" 0 "enable_test_dead_flag" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

# total specs = 2: the grid cell AND the ledger entry itself (its notes
# prose names the flag) -- both under dev/experiments/, so live_specs stays 0.
check "checker3: dead flag referenced only under dev/experiments/ is ELIGIBLE" 0 "| enable_test_dead_flag | ELIGIBLE | 2 | 0 | 0 |" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker3: flag referenced by a live spec is NOT ELIGIBLE" 0 "| catastrophic_stop_pct | NOT ELIGIBLE | 2 | 1 | 0 |" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker3: an odoc bracket cross-reference is not counted as a live .ml assignment" 0 "" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

# F1 rework requirement, pinned explicitly: a flag with a ledger REJECT, a
# clean live-reference check, but NO recorded do-not-revive classification
# anywhere must report NEEDS-CLASSIFICATION -- never a default ELIGIBLE.
# Its ledger notes contain "NO do-not-revive classification recorded",
# which also pins the negation guard: a bare substring search for
# "do-not-revive" would have misread this exact sentence as confirmation.
check "checker3: a flag with no recorded classification is NEEDS-CLASSIFICATION, not ELIGIBLE" 0 "| enable_test_unclassified_flag | NEEDS-CLASSIFICATION | 2 | 0 | 0 |" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check_not "checker3: the unclassified flag never prints as ELIGIBLE" 0 "| enable_test_unclassified_flag | ELIGIBLE |" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="$TODAY" sh "$SCRIPT"

check "checker3: overall tally reflects 1 eligible, 1 not eligible, 1 needs classification" 0 "Flags with a ledger REJECT: 3 (eligible: 1, not eligible: 1, needs classification: 1)." \
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
# FIXTURE E: F1 rework regression pin -- the inventory-file classification
# path (checker3's PRIMARY source), mirroring the exact shape of the real
# bug report: enable_continuation_buys' inventory row reads "**KEEP-AXIS --
# reclassified 2026-08-13**, see Correction log" AND its own prose contains
# the word "RETIRE" ("Was a RETIRE row; the seed was..."). A naive "does
# 'ELIGIBLE' appear near this flag" check, or a check that finds the FIRST
# recognizable keyword instead of checking KEEP-type classifications first
# and unconditionally, would misread this exact row.
# ==============================================================================
_init_fixture_repo
echo "newest doc" >"$FIXTURE/dev/notes/next-session-priorities-2026-08-19.md"
_git_commit "2026-08-19" "newest doc" dev/notes/next-session-priorities-2026-08-19.md
echo "See dev/notes/next-session-priorities-2026-05-15.md for context." >"$FIXTURE/dev/plans/sector-concentration-cap-2026-05-15.md"
_git_commit "2026-05-15" "anchor file (satisfies checker1)" dev/plans/sector-concentration-cap-2026-05-15.md
mkdir -p "$FIXTURE/dev/experiments/fuzz-startdate-crash"
echo "a" >"$FIXTURE/dev/experiments/fuzz-startdate-crash/a.txt"
_git_commit "2026-01-01" "fuzz-startdate-crash (satisfies checker2)" dev/experiments/fuzz-startdate-crash/a.txt

cat >"$FIXTURE/trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli" <<'EOF'
type config = {
  stops_config : Stop_types_fixture.config;
      (** Nested fast-crash stop; the searchable mechanism flag is
          [stops_config.catastrophic_stop_pct]; satisfies checker3's own
          live-flag sanity probe. *)
  enable_test_keepaxis_flag : bool; [@sexp.default false]
      (** inventory says KEEP-AXIS; must never print ELIGIBLE *)
  enable_test_bare_retire_flag : bool; [@sexp.default false]
      (** inventory says bare RETIRE (no "(confirm)"); must print ELIGIBLE *)
}
EOF
_git_commit "2026-01-01" "fixture strategy config with two inventoried flags" trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli

mkdir -p "$FIXTURE/trading/trading/weinstein/stops/lib"
cat >"$FIXTURE/trading/trading/weinstein/stops/lib/stop_types_fixture.mli" <<'EOF'
type config = {
  catastrophic_stop_pct : float; [@sexp.default 0.0]
      (** Fast-crash absolute stop pct; 0.0 is a no-op. *)
}
EOF
_git_commit "2026-01-01" "fixture nested stop config" trading/trading/weinstein/stops/lib/stop_types_fixture.mli

cat >"$FIXTURE/dev/experiments/_ledger/2026-01-02-catstop.sexp" <<'EOF'
((date 2026-01-02) (slug catstop) (verdict Reject)
 (notes "fixture entry for catastrophic_stop_pct"))
EOF
cat >"$FIXTURE/dev/experiments/_ledger/2026-01-03-keepaxis.sexp" <<'EOF'
((date 2026-01-03) (slug keepaxis) (verdict Reject)
 (notes "fixture entry for enable_test_keepaxis_flag"))
EOF
cat >"$FIXTURE/dev/experiments/_ledger/2026-01-04-bare-retire.sexp" <<'EOF'
((date 2026-01-04) (slug bare-retire) (verdict Reject)
 (notes "fixture entry for enable_test_bare_retire_flag"))
EOF
_git_commit "2026-01-02" "ledger rejects" \
  dev/experiments/_ledger/2026-01-02-catstop.sexp \
  dev/experiments/_ledger/2026-01-03-keepaxis.sexp \
  dev/experiments/_ledger/2026-01-04-bare-retire.sexp

# catastrophic_stop_pct: live spec outside dev/experiments/ -- keeps it
# NOT ELIGIBLE via live-ref, satisfying checker3's sanity probe.
echo "((stops_config ((catastrophic_stop_pct 0.10))))" >"$FIXTURE/trading/test_data/live-scenario.sexp"
_git_commit "2026-01-05" "live spec referencing catastrophic_stop_pct" trading/test_data/live-scenario.sexp

# Both inventoried flags: live-ref CLEAN (referenced only in their own
# experiment dirs), so their final verdict comes entirely from the
# inventory classification path under test.
mkdir -p "$FIXTURE/dev/experiments/keepaxis-grid-2026-01-06"
echo "((enable_test_keepaxis_flag true))" >"$FIXTURE/dev/experiments/keepaxis-grid-2026-01-06/cell.sexp"
_git_commit "2026-01-06" "keepaxis flag's own experiment record" dev/experiments/keepaxis-grid-2026-01-06/cell.sexp
mkdir -p "$FIXTURE/dev/experiments/bare-retire-grid-2026-01-07"
echo "((enable_test_bare_retire_flag true))" >"$FIXTURE/dev/experiments/bare-retire-grid-2026-01-07/cell.sexp"
_git_commit "2026-01-07" "bare-retire flag's own experiment record" dev/experiments/bare-retire-grid-2026-01-07/cell.sexp

# The inventory file itself -- mirrors dev/notes/mechanism-flag-inventory-
# 2026-08-09.md's real enable_continuation_buys row verbatim in shape.
cat >"$FIXTURE/dev/notes/mechanism-flag-inventory-2026-08-09.md" <<'EOF'
# Mechanism-flag inventory (fixture)

| `enable_test_keepaxis_flag` | `Weinstein_strategy_config` | `false` | REJECT as default | **KEEP-AXIS -- reclassified 2026-08-13**, see Correction log | Was a RETIRE row; retirement-eligible once the axis program closes. |
| `enable_test_bare_retire_flag` | `Weinstein_strategy_config` | `false` | REJECT | RETIRE | The canonical do-not-revive case. |
EOF
_git_commit "2026-01-08" "add fixture inventory doc" dev/notes/mechanism-flag-inventory-2026-08-09.md

check "checker3: inventory KEEP-AXIS row is NOT ELIGIBLE despite 'RETIRE' appearing in its own prose" 0 "| enable_test_keepaxis_flag | NOT ELIGIBLE (classified KEEP-AXIS) |" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="2026-08-20" sh "$SCRIPT"

check_not "checker3: the KEEP-AXIS flag never prints as bare ELIGIBLE" 0 "| enable_test_keepaxis_flag | ELIGIBLE |" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="2026-08-20" sh "$SCRIPT"

check "checker3: inventory bare-RETIRE (no confirm) row is ELIGIBLE" 0 "| enable_test_bare_retire_flag | ELIGIBLE |" \
  env PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY="2026-08-20" sh "$SCRIPT"

rm -rf "$FIXTURE"

# ==============================================================================
# FIXTURE F: the git safe.directory / dubious-ownership regression (issue
# #2633). prune-candidates-weekly failed its last 2 scheduled GHA runs
# because actions/checkout@v4 registers its safe.directory exception under a
# TEMPORARY HOME and restores the real HOME before this script's step runs,
# so every `git log` call here died with "fatal: detected dubious ownership"
# under the container's `--user 0`. The old call sites redirected git's
# stderr to /dev/null and never checked its exit status, so the failure
# surfaced as checker2's sanity probe reporting a FABRICATED cause ("was not
# flagged as an orphan candidate") instead of the real one.
#
# git's own GIT_TEST_ASSUME_DIFFERENT_OWNER=1 (a documented git test-support
# env var, present since the safe.directory feature landed) reproduces
# "dubious ownership" without needing an actual UID mismatch -- exactly the
# failure mode a differently-privileged GHA container hits. Paired with a
# throwaway, empty HOME (so no ambient `git config --global safe.directory`
# exception can mask the bug), this fixture is a faithful, portable
# reproduction of the GHA failure that needs no container or root.
# ==============================================================================
_init_fixture_repo
echo "newest doc" >"$FIXTURE/dev/notes/next-session-priorities-2026-08-19.md"
_git_commit "2026-08-19" "newest doc" dev/notes/next-session-priorities-2026-08-19.md
echo "See dev/notes/next-session-priorities-2026-05-15.md for context." >"$FIXTURE/dev/plans/sector-concentration-cap-2026-05-15.md"
_git_commit "2026-05-15" "anchor file (satisfies checker1)" dev/plans/sector-concentration-cap-2026-05-15.md
mkdir -p "$FIXTURE/dev/experiments/fuzz-startdate-crash"
echo "a" >"$FIXTURE/dev/experiments/fuzz-startdate-crash/a.txt"
_git_commit "2026-01-01" "fuzz-startdate-crash (satisfies checker2)" dev/experiments/fuzz-startdate-crash/a.txt

cat >"$FIXTURE/trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli" <<'EOF'
type config = {
  stops_config : Stop_types_fixture.config;
      (** Nested fast-crash stop, referenced below as
          [stops_config.catastrophic_stop_pct]; satisfies checker3's own
          live-flag sanity probe so the whole script can reach exit 0. *)
}
EOF
_git_commit "2026-01-01" "fixture strategy config" trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli
mkdir -p "$FIXTURE/trading/trading/weinstein/stops/lib"
cat >"$FIXTURE/trading/trading/weinstein/stops/lib/stop_types_fixture.mli" <<'EOF'
type config = {
  catastrophic_stop_pct : float; [@sexp.default 0.0]
}
EOF
_git_commit "2026-01-01" "fixture nested stop config" trading/trading/weinstein/stops/lib/stop_types_fixture.mli
cat >"$FIXTURE/dev/experiments/_ledger/2026-01-03-catstop.sexp" <<'EOF'
((date 2026-01-03) (slug catstop) (verdict Reject)
 (notes "fixture entry for catastrophic_stop_pct."))
EOF
_git_commit "2026-01-03" "ledger reject" dev/experiments/_ledger/2026-01-03-catstop.sexp
echo "((stops_config ((catastrophic_stop_pct 0.10))))" >"$FIXTURE/trading/test_data/live-scenario.sexp"
_git_commit "2026-01-05" "live spec referencing catastrophic_stop_pct" trading/test_data/live-scenario.sexp

# GIT_TEST_ASSUME_DIFFERENT_OWNER=1 is git's own test-support switch for the
# safe.directory ownership check (present in this git binary -- verified via
# `strings $(command -v git) | grep GIT_TEST_ASSUME_DIFFERENT_OWNER`). A
# throwaway empty HOME means no ambient safe.directory exception is present,
# matching the GHA step exactly.
CLEAN_HOME=$(mktemp -d)

check "exits 0 under forced dubious ownership with a clean HOME (the GHA failure mode)" 0 "" \
  env HOME="$CLEAN_HOME" GIT_TEST_ASSUME_DIFFERENT_OWNER=1 \
  PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY=2026-08-20 sh "$SCRIPT"

check "checker2 still dates fuzz-startdate-crash correctly under forced dubious ownership" 0 \
  "| dev/experiments/fuzz-startdate-crash | 1 | 231 | 2026-01-01 |" \
  env HOME="$CLEAN_HOME" GIT_TEST_ASSUME_DIFFERENT_OWNER=1 \
  PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY=2026-08-20 sh "$SCRIPT"

check_not "no git dubious-ownership fatal leaks into the report" 0 "dubious ownership" \
  env HOME="$CLEAN_HOME" GIT_TEST_ASSUME_DIFFERENT_OWNER=1 \
  PRUNE_CANDIDATES_ROOT="$FIXTURE" PRUNE_CANDIDATES_TODAY=2026-08-20 sh "$SCRIPT"

rm -rf "$CLEAN_HOME"
rm -rf "$FIXTURE"

# ==============================================================================
# Usage errors
# ==============================================================================
check "unexpected argument exits 2" 2 "usage:" sh "$SCRIPT" some-argument

echo
echo "prune_candidates_test: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ] || exit 1
