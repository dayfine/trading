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
# regex below uses the POSIX bracket class [[:space:]], never \s, and why
# every checker's very first move re-derives a fact this file's own
# comments assert is true today and refuses to proceed if it isn't.
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
# CITATION SOURCES (checkers 1 and 2 share this definition)
#
# A file is "cited" if its basename (checker 1) or a directory's basename
# (checker 2) appears, as a literal substring, in any file under:
#   dev/experiments/_ledger/, dev/plans/, dev/status/, .claude/, CLAUDE.md
# Deliberately NOT dev/notes/: notes are exactly the kind of prose write-up
# whose own liveness is unverified (checker 1's target category is notes),
# so a mention in a note does not establish that the mentioned thing is live.
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

CITE_DIRS="dev/experiments/_ledger dev/plans dev/status .claude"
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
  # $1 = literal substring (a basename) to search for across the shared
  # citation sources. Returns 0 (cited) if found, 1 (not cited) otherwise.
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
  local needle d dir f fp
  needle="$1"
  for d in $CITE_DIRS; do
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
    if _is_cited "$f"; then
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
    _is_cited "$base" && continue
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
  local ml_hits live_ml
  local report eligible_count not_eligible_count probed_catstop verdict
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

    if [ "$live_specs" -eq 0 ] && [ "$live_ml" -eq 0 ]; then
      eligible_count=$((eligible_count + 1))
      verdict="ELIGIBLE"
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
  echo "Flags with a ledger REJECT: $((eligible_count + not_eligible_count)) (eligible: $eligible_count, not eligible: $not_eligible_count)."
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
