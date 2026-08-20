#!/bin/sh
# prune_candidates.sh -- verified repo-compression worklist, never a deletion.
#
# WHY THIS EXISTS. Every prune list built by hand in this repo has shrunk by
# half or more once each row was actually verified (dev/plans/arc-readiness-
# 2026-08-20.md Axis 3): a Rule-4 flag-retirement pass read as 5 deletions and
# was 2; a "145 orphaned files" sweep was 53; a "106 superseded docs" count was
# 84. The headline always overstates because the per-row verification IS the
# work, and nobody budgets it -- so compression never happens. This script
# automates the verification (not the deletion) so acting on its output is a
# mechanical, human-reviewed docs-only PR instead of a research task.
#
# This script PROPOSES ONLY. It never deletes, never edits, never writes
# outside dev/health/ (and only when the caller redirects stdout there). No
# deletion logic exists anywhere in this file, not even behind a flag.
#
# USAGE
#   sh dev/scripts/prune_candidates.sh                # report to stdout
#   sh dev/scripts/prune_candidates.sh > dev/health/prune-candidates-$(date +%Y-%m-%d).md
#
# EXIT CODES
#   0  ran to completion (the report may legitimately list zero candidates
#      for any given checker -- "nothing to prune this week" is a real state)
#   1  a checker's sanity probe failed -- the checker's own matching
#      machinery is not finding a fact we KNOW is true of this repo, so its
#      output cannot be trusted. See "SANITY PROBES" below.
#   2  usage error
#
# SANITY PROBES (the single most important property of this script)
#
# Each checker below runs a probe against a known-present fact of the real
# repo BEFORE trusting its own output, and aborts nonzero if the probe fails.
# This is not decorative: on 2026-08-20 a flag-eligibility check used a `\s`
# pattern, which BSD grep (the local dev machine) does not expand inside a
# POSIX/extended regex -- it silently matched nothing, so EVERY flag's
# live-reference count read as zero, and the check reported a false clean
# bill of health ("every flag already unreferenced, safe to remove"). A
# checker whose match primitive is broken must not be allowed to report an
# empty-therefore-safe result; it must say so and stop. This is why every
# checker's very first move re-derives a fact this file's own comments
# assert is true today, and refuses to proceed if it isn't.
#
# Every regex below uses the POSIX bracket class [[:space:]], never \s,
# because BSD grep does not expand \s inside a POSIX/extended regex and a
# \s pattern there matches nothing -- which for a checker means reporting
# "found none", i.e. a false clean bill of health.
#
# What the suite can actually pin is TAB TOLERANCE, not the absence of \s:
# GNU grep in the CI container does expand \s, so the portability rule
# itself is unreachable from a test. The checker-3 fixture is therefore
# tab-indented on the line the anchored grep scans; mutating
# ^[[:space:]]* to ^ * turns 26/0 into 23/3. Do not "simplify" that tab.
#
# QUARANTINE (checker 2 only)
#
# A "cited by nothing" test also catches THIS WEEK's work, because the
# citation graph (a PR landing that cites a new experiment dir) lags the
# experiment dir's own creation by days. Measuring citation absence without
# a recency floor would have proposed dev/experiments/rt-freshness-seeded-
# 2026-08-20 -- an open, in-flight experiment -- on 2026-08-20 itself. So
# checker 2 excludes anything touched (by git history, not filesystem mtime
# -- a fresh GHA checkout stamps every file with checkout time, making
# mtime useless here) within the last 30 days.
#
# A PATH NAME IS NOT ITS CONTENT
#
# None of the three checkers below infer anything from a universe-suggestive
# directory name (e.g. trading/test_data/goldens-sp500-historical/ actually
# holds top-3000 scenarios, not S&P 500 ones -- see
# .claude/rules/universe-discipline.md). If a future checker reasons about
# which universe a scenario measures, it MUST read the scenario's own
# `universe_path` field, never match on a directory or file name.
#
# CITATION SOURCES (checkers 1 and 2 DELIBERATELY DIFFER -- do not "fix" this
# back to a shared list; the asymmetry is load-bearing, not an oversight)
#
# Both checkers ask "is this basename cited anywhere", but the answer to
# "does dev/notes/ count as a citation source" is opposite for the two:
#
# - Checker 1 (superseded priorities docs): dev/notes/ is EXCLUDED. Its
#   target category IS dev/notes/ prose write-ups, whose own liveness is
#   unverified -- one priorities doc mentioning another's filename doesn't
#   make the mentioned one live, it just means two dead docs cite each
#   other. Measured: including dev/notes/ here collapses the candidate
#   count from 84 to 5 (rework iteration 1, 2026-08-20) -- almost every
#   "citation" was exactly this circularity, not a real reference.
# - Checker 2 (orphaned experiment dirs): dev/notes/ is INCLUDED. An
#   experiment dir mentioned in a note (e.g. a trade-forensics writeup, a
#   next-session-priorities doc) IS a genuine reference -- deleting the dir
#   breaks that citation, unlike checker 1's self-referential case. Measured:
#   excluding dev/notes/ here overstated candidates 5x (44 dirs / 292 files
#   vs. 7 dirs / 58 files with it included; independent hand-verification
#   landed at 53 files / 18 dirs, corroborating the dev/notes-included
#   figure once the age-quarantine boundary is also accounted for).
#
# Both checkers still share: dev/experiments/_ledger/, dev/plans/,
# dev/status/, .claude/, CLAUDE.md.
CITE_DIRS_CHECKER1="dev/experiments/_ledger dev/plans dev/status .claude"
CITE_DIRS_CHECKER2="dev/experiments/_ledger dev/plans dev/status .claude dev/notes"
#
# SCOPING NOTE: every helper below declares its loop/temp variables with
# `local` (a dash/bash extension, not strict POSIX, but syntax-checked by
# `dash -n` per posix_sh_check.sh and universally supported on the shells
# this script runs under). Earlier drafts reused bare variable names (e.g.
# `f`, `d`) across nested function calls with no `local`, and a callee's
# loop silently clobbered its caller's loop variable mid-iteration -- every
# checker-1 candidate row printed as "CLAUDE.md" because `_is_cited`'s
# internal `for f in $CITE_FILES` overwrote the caller's `for f in $all_docs`.
# `local` is what prevents that class of bug from coming back.

set -u

if [ $# -ne 0 ]; then
  echo "usage: $0" >&2
  echo "  writes the prune-candidates report to stdout; redirect to a file." >&2
  exit 2
fi

# ROOT / TODAY are overridable so the test suite can point every checker at a
# throwaway fixture tree and a fixed clock instead of the real repo + wall
# clock. Production runs (local or GHA) never set these.
ROOT="${PRUNE_CANDIDATES_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TODAY="${PRUNE_CANDIDATES_TODAY:-$(date -u +%Y-%m-%d)}"

CITE_FILES="CLAUDE.md"

# Portable YYYY-MM-DD -> epoch seconds. BSD date (macOS, dev machines) and
# GNU date (GHA's ubuntu-latest / trading-ci image) take incompatible flags
# for this, so try both rather than picking one and breaking the other host.
_to_epoch() {
  local d
  d="$1"
  date -j -f "%Y-%m-%d" "$d" "+%s" 2>/dev/null && return 0
  date -d "$d" "+%s" 2>/dev/null && return 0
  return 1
}

_age_days() {
  # Whole days between $1 (YYYY-MM-DD, past) and TODAY. Empty/unparseable
  # input is treated as "infinitely old" (never 0), so a dating failure
  # cannot accidentally quarantine-protect a candidate forever.
  local past pe te
  past="$1"
  pe=$(_to_epoch "$past") || { echo 999999; return; }
  te=$(_to_epoch "$TODAY") || { echo 999999; return; }
  echo $(( (te - pe) / 86400 ))
}

_is_cited() {
  # $1 = literal substring (a basename) to search for.
  # $2 = space-separated list of citation-source dirs to check (caller
  #      MUST pass its own list explicitly -- checker 1 and checker 2 use
  #      different lists; see the CITATION SOURCES header comment above for
  #      why. There is deliberately no default here: a silently-reused
  #      default is exactly how a future edit could re-collapse the two
  #      checkers back onto one shared (and wrong-for-one-of-them) list.)
  # Returns 0 (cited) if found, 1 (not cited) otherwise.
  #
  # Deliberately `grep -rl`, NOT `find | xargs grep -l`: when a citation-
  # source directory is empty (or has zero matching files), BSD xargs (the
  # default on macOS dev machines) does not invoke grep at all and the
  # PIPELINE STILL EXITS 0 -- which this function's `if ...; then return 0`
  # then misreads as "a citation was found". That is invariant-2's exact
  # failure shape (silence read as success) reached through a different
  # mechanism than the [[:space:]]-vs-\s bug: an empty citation-source dir
  # would have made every priorities doc / experiment dir look cited, the
  # false-CLEAN direction. `grep -r` has no such empty-input special case on
  # either BSD or GNU grep: zero matches is always exit 1.
  local needle dirs d dir f fp
  needle="$1"
  dirs="$2"
  for d in $dirs; do
    dir="$ROOT/$d"
    [ -d "$dir" ] || continue
    if grep -rl -F -- "$needle" "$dir" >/dev/null 2>&1; then
      return 0
    fi
  done
  for f in $CITE_FILES; do
    fp="$ROOT/$f"
    [ -f "$fp" ] || continue
    if grep -l -F -- "$needle" "$fp" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

_flag_classification() {
  # $1 = flag name (already known to have a ledger REJECT and to pass the
  # live-reference test -- callers should not bother invoking this
  # otherwise; a live-referenced flag is NOT ELIGIBLE regardless of
  # classification, per Rule 4's own precedence).
  #
  # Prints one of: ELIGIBLE | KEEP-AXIS | KEEP-PROMOTED | DEFER |
  # NEEDS-CLASSIFICATION -- per experiment-flag-discipline.md Rule 4:
  # "A REJECT with neither classification is not retirement-eligible --
  # record the classification first, don't guess it at removal time."
  # ELIGIBLE requires an explicit, recorded do-not-revive classification;
  # its absence is NEEDS-CLASSIFICATION, never a default ELIGIBLE.
  #
  # PRIMARY SOURCE: the newest dev/notes/mechanism-flag-inventory-*.md
  # ("newest wins" per experiment-flag-discipline.md's own pointer to this
  # file as "the retirement worklist"). Rule-4 rework iteration 1
  # (2026-08-20) found the concrete failure this guards against: a naive
  # "does 'ELIGIBLE' print" check with no classification test at all
  # reported `enable_continuation_buys` as ELIGIBLE, when the inventory's
  # own row for it reads "**KEEP-AXIS -- reclassified 2026-08-13**" --
  # the flag has an uncancelled regime-gated revival path and is the
  # Trader preset's config home (dev/plans/continuation-retirement-
  # 2026-08-13.md). KEEP-type classifications are checked FIRST and
  # unconditionally, precisely so a flag like this can never fall through
  # to an eligible-sounding match elsewhere in its own inventory entry
  # (its row's prose also contains "RETIRE" -- "Was a RETIRE row" -- which
  # a less careful check could mistake for a live classification).
  #
  # FALLBACK (inventory silent on this flag): the flag's own ledger REJECT
  # file(s), and any dev/agent-memory/project_*.md file(s) they cite, for an
  # explicit "do-not-revive" marker. This fallback carries a NEGATION GUARD
  # found necessary during rework: dev/agent-memory/project_continuation_
  # combined_rejected.md contains the literal substring "do-not-revive"
  # inside the sentence "No do-not-revive is recorded anywhere, opposite is:
  # this memory names..." -- a bare substring search over that file would
  # have reported the flag ELIGIBLE from the exact document explaining why
  # it is not. The guard excludes any line where a negation word appears
  # immediately before the phrase.
  local flag inv_file matches ledger_dir ledger_hits lf mem_names mem mp
  flag="$1"

  inv_file=$(ls -1t "$ROOT"/dev/notes/mechanism-flag-inventory-*.md 2>/dev/null | head -1)
  if [ -n "$inv_file" ]; then
    matches=$(grep -F -- "$flag" "$inv_file" 2>/dev/null)
  else
    matches=""
  fi

  if [ -n "$matches" ]; then
    if printf '%s\n' "$matches" | grep -qE 'KEEP-PROMOTED'; then
      echo "KEEP-PROMOTED"
      return
    fi
    if printf '%s\n' "$matches" | grep -qE 'KEEP-AXIS|(->|→)[[:space:]]*KEEP\b'; then
      echo "KEEP-AXIS"
      return
    fi
    if printf '%s\n' "$matches" | grep -qE '\bDEFER\b'; then
      echo "DEFER"
      return
    fi
    if printf '%s\n' "$matches" \
      | grep -viE '(not|likely|un)[[:space:]]*eligible' \
      | grep -qiE '\beligible\b'; then
      echo "ELIGIBLE"
      return
    fi
    if printf '%s\n' "$matches" | grep -qE '\bRETIRE\b' \
      && ! printf '%s\n' "$matches" | grep -qE 'RETIRE[[:space:]]*\(confirm\)'; then
      echo "ELIGIBLE"
      return
    fi
  fi

  ledger_dir="$ROOT/dev/experiments/_ledger"
  ledger_hits=$(find "$ledger_dir" -name '*.sexp' 2>/dev/null | xargs grep -l -F -- "$flag" 2>/dev/null)
  for lf in $ledger_hits; do
    if grep -iE 'do.not.revive' "$lf" 2>/dev/null \
      | grep -viE '(no|not|isn.t|opposite of)[[:space:]]+do.not.revive' | grep -q .; then
      echo "ELIGIBLE"
      return
    fi
    mem_names=$(grep -oE 'project_[a-z0-9_]+' "$lf" 2>/dev/null | sort -u)
    for mem in $mem_names; do
      mp="$ROOT/dev/agent-memory/${mem}.md"
      [ -f "$mp" ] || continue
      if grep -iE 'do.not.revive' "$mp" 2>/dev/null \
        | grep -viE '(no|not|isn.t|opposite of)[[:space:]]+do.not.revive' | grep -q .; then
        echo "ELIGIBLE"
        return
      fi
    done
  done

  echo "NEEDS-CLASSIFICATION"
}

# ----------------------------------------------------------------------------
# Checker 1 -- superseded priorities docs
# ----------------------------------------------------------------------------
# Every dev/notes/next-session-priorities-* except the newest (by git commit
# recency, not filename lexical order -- naming has drifted over months:
# plain dates, -PM/-am/-pm/-EOD/-overnight suffixes, a stray "b" variant --
# and is not a reliable sort key), that is cited by nothing in the shared
# citation sources.
checker1() {
  local notes_dir all_docs f cdate ce newest newest_epoch
  local candidates total_lines cited_others older_count lines
  local anchor_plan anchor_needle anchor_ok cand_count

  notes_dir="$ROOT/dev/notes"
  all_docs=$(cd "$notes_dir" 2>/dev/null && ls next-session-priorities-*.md 2>/dev/null | sort)
  if [ -z "$all_docs" ]; then
    echo "FAIL(checker1): no next-session-priorities-*.md found under dev/notes/ -- expected many; the glob or ROOT is wrong." >&2
    return 1
  fi

  # newest = most recently touched in git history (fresh GHA checkouts give
  # every file the same mtime, so filesystem mtime cannot answer "newest").
  newest=""
  newest_epoch=-1
  for f in $all_docs; do
    cdate=$(cd "$ROOT" && git log -1 --format=%cd --date=format:%Y-%m-%d -- "dev/notes/$f" 2>/dev/null)
    [ -n "$cdate" ] || cdate="$TODAY"
    ce=$(_to_epoch "$cdate") || ce=0
    if [ "$ce" -gt "$newest_epoch" ]; then
      newest_epoch="$ce"
      newest="$f"
    fi
  done

  candidates=""
  total_lines=0
  cited_others=0
  older_count=0
  for f in $all_docs; do
    [ "$f" = "$newest" ] && continue
    older_count=$((older_count + 1))
    if _is_cited "$f" "$CITE_DIRS_CHECKER1"; then
      cited_others=$((cited_others + 1))
      continue
    fi
    lines=$(wc -l < "$notes_dir/$f" | tr -d ' ')
    candidates="$candidates$f|$lines
"
    total_lines=$((total_lines + lines))
  done

  # SANITY PROBE: a known citation must still resolve. If it doesn't, either
  # the anchor file was pruned (update the anchor below) or the citation
  # grep itself is broken -- in which case EVERY older doc would silently
  # fall into "candidates" (the exact false-clean-bill-of-health failure
  # this file's header describes), so trusting the count here would be
  # actively dangerous, not just unhelpful. Structural backstop: if there
  # is at least one older doc but the grep found zero citations among all
  # of them, that is the same failure signature even if the specific named
  # anchor below has since been pruned -- abort on either condition.
  anchor_plan="dev/plans/sector-concentration-cap-2026-05-15.md"
  anchor_needle="next-session-priorities-2026-05-15.md"
  anchor_ok=1
  if [ -f "$ROOT/$anchor_plan" ] && grep -qF -- "$anchor_needle" "$ROOT/$anchor_plan" 2>/dev/null; then
    anchor_ok=0
  fi
  if [ "$anchor_ok" -ne 0 ] && [ "$older_count" -gt 0 ] && [ "$cited_others" -eq 0 ]; then
    echo "FAIL(checker1): sanity probe failed -- $anchor_plan no longer cites $anchor_needle, AND zero of $older_count older priorities docs were found cited anywhere. This is the false-clean-bill-of-health signature (citation grep matching nothing); refusing to report." >&2
    return 1
  fi

  echo "## Checker 1 -- superseded priorities docs"
  echo
  echo "Newest (kept): \`dev/notes/$newest\`"
  echo
  cand_count=$(printf '%s' "$candidates" | grep -c . || true)
  echo "Candidates: $cand_count files, $total_lines total lines (cited-elsewhere and excluded: $cited_others)."
  echo
  if [ "$cand_count" -gt 0 ]; then
    echo "| file | lines |"
    echo "|---|---:|"
    printf '%s' "$candidates" | while IFS='|' read -r cf cl; do
      [ -n "$cf" ] || continue
      echo "| dev/notes/$cf | $cl |"
    done
  fi
  echo
}

# ----------------------------------------------------------------------------
# Checker 2 -- orphaned experiment dirs
# ----------------------------------------------------------------------------
# Directories directly under dev/experiments/ (excluding _ledger), cited by
# nothing in the shared citation sources, AND last touched (by git history)
# more than 30 days before TODAY.
checker2() {
  local exp_dir all_dirs base d cdate age fcount
  local candidates total_files probed_known_orphan dir_count

  exp_dir="$ROOT/dev/experiments"
  if [ ! -d "$exp_dir" ]; then
    echo "FAIL(checker2): $exp_dir does not exist." >&2
    return 1
  fi

  all_dirs=$(find "$exp_dir" -mindepth 1 -maxdepth 1 -type d ! -name '_ledger' -exec basename {} \; | sort)
  if [ -z "$all_dirs" ]; then
    echo "FAIL(checker2): dev/experiments/ has no subdirectories besides _ledger -- expected many; ROOT is probably wrong." >&2
    return 1
  fi

  candidates=""
  total_files=0
  probed_known_orphan=0
  for base in $all_dirs; do
    d="dev/experiments/$base"
    cdate=$(cd "$ROOT" && git log -1 --format=%cd --date=format:%Y-%m-%d -- "$d" 2>/dev/null)
    if [ -z "$cdate" ]; then
      # No git history for a tracked path is unexpected; err toward NOT
      # proposing it rather than risk quarantine-bypassing an untraceable dir.
      continue
    fi
    age=$(_age_days "$cdate")
    [ "$age" -lt 30 ] && continue
    _is_cited "$base" "$CITE_DIRS_CHECKER2" && continue
    fcount=$(find "$ROOT/$d" -type f | wc -l | tr -d ' ')
    candidates="$candidates$d|$fcount|$age|$cdate
"
    total_files=$((total_files + fcount))
    [ "$base" = "fuzz-startdate-crash" ] && probed_known_orphan=1
  done

  # SANITY PROBE: dev/experiments/fuzz-startdate-crash (last touched
  # 2026-05-02, cited nowhere) is a known-orphaned dir as of this writing.
  # Unlike checker 1's probe, this one is NOT gated on the anchor existing --
  # if it's absent, that is itself a probe failure, not a reason to skip.
  # A probe that silently no-ops when its anchor is missing provides no
  # safety net (that was an earlier draft's bug: the fixture test below could
  # never exercise the failure path, because a fixture without a literal
  # `fuzz-startdate-crash` directory just skipped the check instead of
  # catching that the check never ran). Either the git-log dating or the
  # citation-exclusion grep is broken in the false-safe direction (silently
  # treating real orphans as cited/recent/absent), or this repo's anchor dir
  # has genuinely been removed -- in which case update the anchor name here;
  # do not weaken the check to a conditional one.
  if [ "$probed_known_orphan" -ne 1 ]; then
    echo "FAIL(checker2): sanity probe failed -- dev/experiments/fuzz-startdate-crash was not flagged as an orphan candidate (either missing entirely, or excluded by dating/citation logic). Refusing to report; if the anchor dir has legitimately been removed from this repo, update the anchor name in this script." >&2
    return 1
  fi

  dir_count=$(printf '%s' "$candidates" | grep -c . || true)
  echo "## Checker 2 -- orphaned experiment dirs"
  echo
  echo "Candidates: $dir_count dirs, $total_files total files (uncited AND untouched >= 30 days)."
  echo
  if [ "$dir_count" -gt 0 ]; then
    echo "| dir | files | age (days) | last touched |"
    echo "|---|---:|---:|---|"
    printf '%s' "$candidates" | while IFS='|' read -r cd_ cf ca cc; do
      [ -n "$cd_" ] || continue
      echo "| $cd_ | $cf | $ca | $cc |"
    done
  fi
  echo
}

# ----------------------------------------------------------------------------
# Checker 3 -- Rule-4 flag eligibility
# ----------------------------------------------------------------------------
# For each default-off mechanism flag reachable from weinstein_strategy_
# config.mli (declared directly, or as a nested dotted reference like
# [stops_config.catastrophic_stop_pct] whose own default is itself a no-op)
# that has a ledger REJECT, report eligibility per
# .claude/rules/experiment-flag-discipline.md Rule 4: eligible only if the
# flag is referenced by NO committed *.sexp file outside dev/experiments/
# (a mention inside dev/experiments/ is that flag's own experiment record,
# not a live reference) and by no non-default assignment in trading/**/*.ml
# outside test directories.
checker3() {
  local strategy_mli direct_flags dotted_leaves leaf default_line
  local nested_flags all_flags flag ledger_hits has_reject lf
  local spec_hits live_specs total_specs sf rel
  local ml_hits live_ml classification
  local report eligible_count not_eligible_count needs_class_count probed_catstop verdict
  local catstop_line catstop_live

  strategy_mli="$ROOT/trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli"
  if [ ! -f "$strategy_mli" ]; then
    echo "FAIL(checker3): $strategy_mli not found." >&2
    return 1
  fi

  # Direct bool fields declared `[@sexp.default false]` in the strategy config.
  direct_flags=$(grep -oE '^[[:space:]]*[a-z_][a-z_0-9]*[[:space:]]*:[[:space:]]*bool;[[:space:]]*\[@sexp\.default[[:space:]]+false\]' "$strategy_mli" \
    | grep -oE '^[[:space:]]*[a-z_][a-z_0-9]*' | sed -E 's/^[[:space:]]+//')

  # Nested dotted references (`[foo.bar]`) documented in this file. Keep only
  # the leaf name, and only if that leaf's OWN declaration elsewhere under
  # trading/trading/weinstein/ carries a no-op default (false/0.0/0/None) --
  # this is what filters out incidental doc refs like [portfolio.cash] or
  # [weinstein.screener] that are not default-off mechanism flags at all.
  dotted_leaves=$(grep -oE '\[[a-z_][a-z_0-9]*\.[a-z_][a-z_0-9]*\]' "$strategy_mli" \
    | tr -d '[]' | sed -E 's/^[a-z_0-9]+\.//' | sort -u)

  nested_flags=""
  for leaf in $dotted_leaves; do
    default_line=$(grep -rE "^[[:space:]]*${leaf}[[:space:]]*:.*\[@sexp\.default" \
      "$ROOT/trading/trading/weinstein" --include='*.mli' 2>/dev/null | head -1)
    [ -n "$default_line" ] || continue
    case "$default_line" in
    *"[@sexp.default false]"* | *"[@sexp.default 0.0]"* | *"[@sexp.default 0]"* | *"[@sexp.default None]"*)
      nested_flags="$nested_flags $leaf"
      ;;
    esac
  done

  all_flags=$(printf '%s %s' "$direct_flags" "$nested_flags" | tr ' ' '\n' | grep -v '^$' | sort -u)

  report=""
  eligible_count=0
  not_eligible_count=0
  needs_class_count=0
  probed_catstop=0
  for flag in $all_flags; do
    # Must have a ledger REJECT to be in Rule-4 scope at all.
    ledger_hits=$(find "$ROOT/dev/experiments/_ledger" -name '*.sexp' 2>/dev/null | xargs grep -l -F -- "$flag" 2>/dev/null)
    has_reject=0
    for lf in $ledger_hits; do
      grep -q '(verdict Reject)' "$lf" 2>/dev/null && has_reject=1 && break
    done
    [ "$has_reject" -eq 1 ] || continue

    [ "$flag" = "catastrophic_stop_pct" ] && probed_catstop=1

    spec_hits=$(find "$ROOT" -name '*.sexp' -not -path '*/_build/*' 2>/dev/null | xargs grep -l -F -- "$flag" 2>/dev/null)
    live_specs=0
    total_specs=0
    for sf in $spec_hits; do
      total_specs=$((total_specs + 1))
      rel=${sf#"$ROOT"/}
      case "$rel" in
      dev/experiments/*) : ;; # own experiment record, not live
      *) live_specs=$((live_specs + 1)) ;;
      esac
    done

    # Live .ml assignment: a line assigning the flag to something other than
    # its own no-op default, outside test/ directories. Excludes: the field
    # declaration line itself (has `[@sexp.default`); an odoc cross-reference
    # like `[config.<flag> = true]` in a docstring, which reads a value
    # inside square brackets rather than assigning one (this codebase's
    # convention throughout weinstein_strategy_config.mli / .ml docstrings,
    # e.g. `Friday ticks, when [config.enable_late_stage2_stop_tighten =
    # true], raise ...` -- a prose reference, not code); and the
    # default_config assignment line itself, `<flag> = <no-op>;`.
    ml_hits=$(find "$ROOT/trading" -name '*.ml' -not -path '*/test/*' -not -path '*/_build/*' 2>/dev/null \
      | xargs grep -nE "${flag}[[:space:]]*=[[:space:]]*" 2>/dev/null)
    live_ml=0
    if [ -n "$ml_hits" ]; then
      live_ml=$(printf '%s\n' "$ml_hits" \
        | grep -v '\[@sexp\.default' \
        | grep -vE "\[[a-zA-Z_.]*${flag}[[:space:]]*=[[:space:]]*(true|false)\]" \
        | grep -vE "${flag}[[:space:]]*=[[:space:]]*(false|0\.0|0|None)[[:space:];]" \
        | grep -c . || true)
    fi

    # Live-reference is a hard gate, checked BEFORE classification: a flag
    # with any live spec or .ml reference is NOT ELIGIBLE no matter what a
    # do-not-revive record says (Rule 4's "Unused" precondition). Only when
    # live-reference is clean does the do-not-revive CLASSIFICATION even
    # get consulted -- see _flag_classification's header for why a REJECT
    # with no recorded classification must never default to ELIGIBLE.
    if [ "$live_specs" -eq 0 ] && [ "$live_ml" -eq 0 ]; then
      classification=$(_flag_classification "$flag")
      case "$classification" in
      ELIGIBLE)
        eligible_count=$((eligible_count + 1))
        verdict="ELIGIBLE"
        ;;
      KEEP-AXIS | KEEP-PROMOTED | DEFER)
        not_eligible_count=$((not_eligible_count + 1))
        verdict="NOT ELIGIBLE (classified $classification)"
        ;;
      *)
        needs_class_count=$((needs_class_count + 1))
        verdict="NEEDS-CLASSIFICATION"
        ;;
      esac
    else
      not_eligible_count=$((not_eligible_count + 1))
      verdict="NOT ELIGIBLE"
    fi
    report="$report$flag|$verdict|$total_specs|$live_specs|$live_ml
"
  done

  # SANITY PROBE: catastrophic_stop_pct is a known-live flag (135 committed
  # specs today, including the live record-baseline convention) with a
  # ledger REJECT (2026-07-09-catstop-deep-wfcv.sexp). If the enumeration
  # above didn't even reach it, or reached it with live_specs == 0, the
  # dotted-flag discovery or the [[:space:]] field-declaration matching is
  # broken -- exactly the false-clean-bill-of-health failure this file's
  # header describes.
  if [ "$probed_catstop" -ne 1 ]; then
    echo "FAIL(checker3): sanity probe failed -- catastrophic_stop_pct was not discovered as a Rule-4-eligible-to-check flag (expected: nested dotted reference in weinstein_strategy_config.mli with a no-op default, plus a ledger REJECT). Flag discovery is broken; refusing to report." >&2
    return 1
  fi
  catstop_line=$(printf '%s' "$report" | grep '^catastrophic_stop_pct|')
  catstop_live=$(printf '%s' "$catstop_line" | cut -d'|' -f4)
  if [ "${catstop_live:-0}" -eq 0 ]; then
    echo "FAIL(checker3): sanity probe failed -- catastrophic_stop_pct reports 0 live spec references; it is known to have well over 100 (e.g. a staging-record-convention spec). The live-reference count is broken in the false-safe direction; refusing to report." >&2
    return 1
  fi

  echo "## Checker 3 -- Rule-4 flag eligibility"
  echo
  echo "Flags with a ledger REJECT: $((eligible_count + not_eligible_count + needs_class_count)) (eligible: $eligible_count, not eligible: $not_eligible_count, needs classification: $needs_class_count)."
  echo
  if [ -n "$report" ]; then
    echo "| flag | eligibility | total specs | live specs | live .ml assignments |"
    echo "|---|---|---:|---:|---:|"
    printf '%s' "$report" | while IFS='|' read -r rflag rverdict rtotal rlive rlivem; do
      [ -n "$rflag" ] || continue
      echo "| $rflag | $rverdict | $rtotal | $rlive | $rlivem |"
    done
  fi
  echo
}

echo "# Prune candidates -- $TODAY"
echo
echo "Verified compression worklist. This report PROPOSES rows for human review;"
echo "it deletes nothing. See dev/scripts/prune_candidates.sh header for method."
echo

rc=0
checker1 || rc=1
checker2 || rc=1
checker3 || rc=1

exit "$rc"
