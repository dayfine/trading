#!/bin/sh
# check_universe_deps.sh — H-CHECK-CACHE-BLIND mechanical guard.
#
# Rule: any trading/devtools/checks/*.sh script that calls repo_root()
# (either the shared _check_lib.sh helper, or a private reimplementation
# of the same pattern — e.g. record_qc_audit.sh's own _repo_root()) reads
# a path that a dune (deps ...) list cannot express, because dune deps are
# resolved relative to the workspace root and cannot reach above it. If
# that script's dune rule does not declare (universe), a warm `_build`
# treats the rule as fully determined by its declared deps and silently
# skips re-running it when the real file the script reads has changed —
# `dune runtest` returns a stale cached PASS. This is the class PR #2143
# fixed for exactly one rule (run_in_env_root_check.sh); this check closes
# it mechanically across the rest of trading/devtools/checks/dune instead
# of relying on case-by-case discovery.
#
# Method: parse trading/devtools/checks/dune into per-rule blocks (each
# rule is blank-line-delimited and starts with "(rule" at column 0 — true
# for every current rule in this file; see the parser's own self-check in
# check_universe_deps_test.sh). H-CHECK-DUNE-COMMENT-GLUED-RULE: a record
# may carry a ";"-led explanatory comment glued directly above the rule
# with no intervening blank line (dune permits this); such a record's raw
# text starts with ";", not "(rule", so leading whole-line comments are
# stripped from each record BEFORE the "(rule" classification test, not
# after — see strip_leading_comments() below. strip_comments() (applied
# once a record is classified as a rule) also strips TRAILING same-line
# comments, not just whole-line ones, so a stray %{dep:...}-shaped snippet
# inside a trailing comment cannot hijack the run-target regex below.
# Candidate scripts are found RECURSIVELY
# under trading/devtools/checks/ (any *.sh whose body contains the
# substring "repo_root"), not just at the top level — see the CANDIDATES
# scan below. For every candidate, find the rule that runs it (its
# %{dep:...} run-target) or, if it is never itself a run-target, the rule
# that lists it as a dep. FAIL if that rule lacks "(universe)" and the
# script is not listed in universe_deps_exceptions.conf.
#
# universe_deps_exceptions.conf entries must each carry a "# review_at:
# <value>" annotation (never / M1-M7 / YYYY-MM-DD, same convention as
# linter_exceptions.conf); an entry with no parseable review_at is itself
# a FAIL from this script (#2148 FLAG-1 — an unconstrained exceptions list
# silently disables the guard forever for whatever script it lists).
#
# This rule's OWN dune wiring declares (universe) — a cache-blindness
# linter that is itself cache-blind (i.e. whose own PASS/FAIL could go
# stale on a warm build) defeats its purpose. See the dune file's rule
# for this script.
#
# How to re-verify by hand:
#   sh trading/devtools/checks/check_universe_deps.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

# Use repo_root() (not the sandboxed $(dirname "$0")) so this scan always
# sees the real, current tree — matching the established pattern used by
# no_python_check.sh / agent_compliance_check.sh for whole-repo scans.
REPO_ROOT="$(repo_root)"
CHECKS_DIR="${REPO_ROOT}/trading/devtools/checks"
DUNE_FILE="${CHECKS_DIR}/dune"
EXCEPTIONS_FILE="${CHECKS_DIR}/universe_deps_exceptions.conf"

[ -f "$DUNE_FILE" ] || die "check_universe_deps: $DUNE_FILE not found"

# --- Candidate scripts: any *.sh anywhere under CHECKS_DIR, RECURSIVELY
# (excluding _check_lib.sh itself, which defines the helper but is never a
# dune run-target) whose body contains an actual repo_root call site:
# "$(repo_root)" / "(repo_root)" or the private-reimplementation form
# "$(_repo_root)" / "(_repo_root)" — i.e. "repo_root" immediately followed
# by a closing paren. This deliberately does NOT match on the bare
# substring "repo_root" (a false-positive risk proven by
# check_universe_deps_test.sh assertion 5: a script that merely mentions
# another script's filename like "helper_with_repo_root.sh" in a comment
# or echo string must NOT be treated as a repo_root() caller).
#
# Recursive via `find -exec` (not a `./*.sh ./*/*.sh` glob list) so scripts
# at any subdirectory depth are covered, not just one level down — this
# closes the #2148 FLAG-2 residual (the previous top-level-only glob
# missed deep_scan/_lib.sh and deep_scan/main.sh). Candidate names below
# the top level come back path-qualified, e.g. "deep_scan/_lib.sh" — the
# awk dep-matching and exceptions-list lookup below both already accept
# '/' in script names (see the depsonly character class and the plain
# string-equality allow-list check).
#
# H-CHECK-UNIVERSE-DEPS-SCANS-COMMENTS: strip whole-line "#" shell
# comments from each candidate file BEFORE grepping for a call site, so a
# comment that merely quotes call syntax as documentation prose (e.g.
# `# REPO_ROOT="$(_repo_root)"` inside an explanatory comment) is not
# mistaken for a real call site. This mirrors the strip_comments() awk
# helper further down in this script, which strips dune's ";"-led
# whole-line comments before parsing a rule block — same principle (a
# line whose first non-whitespace character is the comment leader is
# prose, not code) applied to shell's "#" leader instead of dune's ";".
# It is a separate implementation rather than a call into that helper:
# strip_comments() is an awk function embedded in the single awk program
# below that parses DUNE_FILE's text in paragraph (RS="") mode; this scan
# runs earlier, in `sh`, over individual candidate *.sh files one at a
# time via `find`/`grep`, well before that awk program is ever invoked —
# there is no shared process or string to call the same function on.
#
# Only a WHOLE-LINE comment (first non-blank character on the line is
# "#") is stripped — never any "#" occurring later on a line. This
# deliberately preserves detection of:
#   - a real call site on a line that also carries a trailing "# ..."
#     comment (e.g. `REAL="$(repo_root)" # note`)
#   - "${var#prefix}" / "${#arr[@]}" shell parameter-expansion syntax
#     appearing elsewhere in the file, which never starts a comment-only
#     line
# See check_universe_deps_test.sh assertions 8-10 for the pinned
# false-positive (comment-only mention, must NOT be flagged) and
# false-negative (real call site plus trailing-comment / "#"-expansion
# noise, must still be flagged) regression fixtures.
_strip_hash_comments() {
  awk '$0 !~ /^[ \t]*#/'
}

CANDIDATES=$(
  cd "$CHECKS_DIR" && find . -name '*.sh' -type f -print | {
    while IFS= read -r f; do
      if _strip_hash_comments <"$f" 2>/dev/null | grep -qE 'repo_root\)'; then
        printf '%s\n' "$f"
      fi
    done
  } | sed 's#^\./##' | grep -v '^_check_lib\.sh$' || true
)

if [ -z "$CANDIDATES" ]; then
  echo "OK: check_universe_deps — no repo_root()-calling scripts found (unexpected; audit by hand)."
  exit 0
fi

TMP_CAND=$(mktemp)
trap 'rm -f "$TMP_CAND"' EXIT
printf '%s\n' "$CANDIDATES" > "$TMP_CAND"

RESULT_FILE=$(mktemp)
trap 'rm -f "$TMP_CAND" "$RESULT_FILE"' EXIT

# Bracket with set +e/-e (not `cmd; CODE=$?`) so a non-zero awk exit
# doesn't abort the script under `set -e` before the exit code is
# captured — the exact diagnostic-swallowing shape this repo's
# H-CHECK-SETE-DIAGNOSTICS item tracks.
set +e
awk -v exceptions="$EXCEPTIONS_FILE" -v candfile="$TMP_CAND" '
function strip_trailing_comment_line(line,    i, n, c, prev, inquote, out) {
  # Quote-aware scan of a SINGLE physical line: truncate at the first ";"
  # that is not inside a double-quoted dune string. Dune permits a literal
  # ";" as string content -- e.g. (setenv MSG "step one; step two" ...) is
  # legal and the "MSG" value really does contain a ";" -- so a ";" seen
  # while inquote is true is live content, not a comment leader, and must
  # be preserved (measured against a real `dune build @sub/runtest` run;
  # see the PR discussion for the exact repro). A `\"` escape does not
  # toggle quote state, matching how dune escapes quotes in strings.
  inquote = 0
  out = ""
  n = length(line)
  for (i = 1; i <= n; i++) {
    c = substr(line, i, 1)
    if (c == "\"") {
      prev = (i > 1) ? substr(line, i - 1, 1) : ""
      if (prev != "\\") inquote = !inquote
      out = out c
      continue
    }
    if (c == ";" && !inquote) break
    out = out c
  }
  return out
}
function strip_comments(b,    lines, n, i, out) {
  # Whole-line comments: a ";" that is the first non-whitespace character
  # after the start of the block or a newline.
  gsub(/(^|\n)[ \t]*;[^\n]*/, "\n", b)
  # H-CHECK-DUNE-COMMENT-GLUED-RULE shape 2: TRAILING same-line comments,
  # i.e. a ";" preceded by real content earlier on the same line. Applied
  # AFTER the whole-line pass above, so only ";" characters that survived
  # (never a line-start one) reach this pass. Quote-aware, per physical
  # line, via strip_trailing_comment_line() above: a survivor ";" is only
  # treated as a comment leader when it falls OUTSIDE a double-quoted
  # string on its own line -- an unconditional "delete to end-of-line"
  # here would also delete a live quoted ";" and anything after it on that
  # line (measured false-FAIL / false-OK regression; see the PR
  # discussion), which is why this is quote-aware rather than a single
  # gsub.
  n = split(b, lines, "\n")
  out = ""
  for (i = 1; i <= n; i++) {
    out = out strip_trailing_comment_line(lines[i])
    if (i < n) out = out "\n"
  }
  return out
}
function strip_leading_comments(b) {
  # H-CHECK-DUNE-COMMENT-GLUED-RULE shape 1: strip contiguous whole-line
  # ";" comments from the very FRONT of a paragraph-mode record, so a rule
  # with an explanatory comment glued directly above it (no blank line
  # separating them) is still classified as a rule by the /^\(rule/ test
  # below. A record that is ENTIRELY comment lines (a genuinely
  # commented-out / dead rule) reduces to its FINAL comment line, not the
  # empty string: awk paragraph mode ($0 under RS="") strips the trailing
  # newline off the record, so the last ";"-led line has no trailing "\n"
  # left for the "\n"-anchored sub() below to consume, and the loop stops
  # one line early. That reduced text still starts with ";" (never "(rule"),
  # so classification is unaffected and still fails the test below --
  # see check_universe_deps_test.sh assertion 13 -- but the mechanism is
  # "stops at the last line", not "reduces to empty".
  while (b ~ /^[ \t]*;[^\n]*\n/) {
    sub(/^[ \t]*;[^\n]*\n/, "", b)
  }
  return b
}
BEGIN {
  # NOTE: RS is a single global setting in awk -- it applies to explicit
  # getline < file reads too, not just the main input. Read the
  # newline-delimited exceptions/candidates files FIRST under the
  # default RS="\n", THEN switch to paragraph mode ("") for the main
  # dune-file input below. Getting this order backwards was caught by
  # check_universe_deps_test.sh assertion 1 in development: with RS=""
  # active during the getline loops, the whole candidates file was read
  # as one blank-line-delimited "record" instead of one filename per line,
  # so no candidate resolved and the guard exited 0 silently instead of
  # failing on sample_check.sh missing (universe) -- see #2148 review
  # FLAG-3 (the comment previously mis-credited "assertion 5").
  RS = "\n"

  # Each exceptions entry must carry a "# review_at: <value>" annotation
  # (same trailing-comment convention as linter_exceptions.conf) with a
  # value of "never", an M1-M7 milestone, or a YYYY-MM-DD date -- see
  # .claude/rules/code-health-discipline.md and #2148 review FLAG-1
  # (an exceptions list with no review_at field is unconstrained forever;
  # this makes a missing/unparseable review_at a hard FAIL, not a silent
  # skip). Actual expiry (has the milestone/date passed) is checked
  # separately by the weekly deep_scan/check_11_linter_expiry.sh, which
  # already owns that cadence for the sibling linter_exceptions.conf file.
  nallow = 0
  nbadreviewat = 0
  if (exceptions != "") {
    while ((getline eline < exceptions) > 0) {
      gsub(/^[ \t]+|[ \t]+$/, "", eline)
      if (eline == "" || eline ~ /^#/) continue

      review_at = ""
      if (match(eline, /#[ \t]*review_at:[ \t]*.*/)) {
        review_at = substr(eline, RSTART, RLENGTH)
        sub(/^#[ \t]*review_at:[ \t]*/, "", review_at)
        gsub(/[ \t]+$/, "", review_at)
      }

      aline = eline
      sub(/#.*/, "", aline)
      gsub(/[ \t]+$/, "", aline)
      if (aline == "") continue

      nallow++
      allow[aline] = 1

      valid_review_at = 0
      if (review_at ~ /^never([ \t(]|$)/) valid_review_at = 1
      else if (review_at ~ /^M[1-7]([ \t(]|$)/) valid_review_at = 1
      else if (review_at ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) valid_review_at = 1

      if (!valid_review_at) {
        nbadreviewat++
        badreviewat[nbadreviewat] = aline
      }
    }
    close(exceptions)
  }

  ncand = 0
  while ((getline cline < candfile) > 0) {
    gsub(/^[ \t]+|[ \t]+$/, "", cline)
    if (cline != "") { ncand++; cand[ncand] = cline }
  }
  close(candfile)

  RS = ""
}
{
  # H-CHECK-DUNE-COMMENT-GLUED-RULE: strip leading comments BEFORE the
  # "(rule" classification test below, not after -- see the
  # strip_leading_comments doc comment above.
  rec = strip_leading_comments($0)
}
rec ~ /^\(rule/ {
  block = strip_comments(rec)
  hasuniv = (block ~ /\(universe\)/) ? 1 : 0

  # H-CHECK-RUNTARGET-PATHQUAL: the run-target name class must admit "/"
  # (and "-"), because the candidate scan above is recursive and yields
  # path-qualified names like "deep_scan/_lib.sh". A rule written as
  # (run sh %{dep:deep_scan/foo_check.sh}) would otherwise not match
  # here, and the script would fall through to the dep-list branch below
  # -- which resolves to whichever OTHER rule happens to list it as a
  # plain dep, inheriting the (universe) status of THAT rule instead of
  # its own. The misattribution is silent in both directions: a false
  # FAIL when the owning run-target rule is clean, and (worse) a false OK
  # when the owning run-target rule is the cache-blind one. See
  # check_universe_deps_test.sh assertions 11-14.
  #
  # NOTE: no apostrophes anywhere in this awk program -- it is a single-
  # quoted shell string, so one would terminate it early.
  runtarget = ""
  if (match(block, /\(run[ \t\n]+(sh|bash)[ \t\n]+%\{dep:[A-Za-z0-9_.\/-]+\}/)) {
    seg = substr(block, RSTART, RLENGTH)
    sub(/.*%\{dep:/, "", seg)
    sub(/\}.*/, "", seg)
    runtarget = seg
  }

  # This class is deliberately NOT widened alongside the run-target one
  # above. Its job is to drop %{dep:...} wrappers so they are not counted
  # as plain deps; widening it to "/" would ALSO drop a path-qualified
  # %{dep:...} written in a DEPS position (not a run position), which the
  # run-target branch by construction never matches -- that script would
  # then resolve to no rule at all and be reported as unreferenced. The
  # narrower class leaves such a dep visible to the fallback below; and
  # because the run-target branch is consulted first, the resulting leak
  # of a path-qualified run-target into this dep list is inert.
  depsonly = block
  gsub(/%\{dep:[A-Za-z0-9_.]+\}/, "", depsonly)
  gsub(/[^A-Za-z0-9_.\/-]/, " ", depsonly)
  nd = split(depsonly, arr, " ")
  deps = ""
  for (i = 1; i <= nd; i++) {
    if (arr[i] ~ /\.sh$/) deps = deps "|" arr[i] "|"
  }

  nrules++
  rt[nrules] = runtarget
  hu[nrules] = hasuniv
  dp[nrules] = deps
}
END {
  fail = 0
  for (i = 1; i <= nbadreviewat; i++) {
    print "FAIL: universe_deps_exceptions.conf entry \"" badreviewat[i] "\" has no parseable \"# review_at: <value>\" annotation (expected \"never\", an M1-M7 milestone, or a YYYY-MM-DD date, same convention as linter_exceptions.conf) -- an exception with no review_at silently disables this guard for that script forever; see .claude/rules/code-health-discipline.md"
    fail++
  }
  for (c = 1; c <= ncand; c++) {
    s = cand[c]
    if (s in allow) {
      print "SKIP (exceptions list): " s
      continue
    }
    found = 0
    ok = 0
    owner = ""
    for (r = 1; r <= nrules; r++) {
      if (rt[r] == s) {
        found = 1
        ok = hu[r]
        owner = "run-target"
        break
      }
    }
    if (!found) {
      for (r = 1; r <= nrules; r++) {
        if (index(dp[r], "|" s "|") > 0) {
          found = 1
          ok = hu[r]
          owner = "dep of rule with run-target " (rt[r] == "" ? "(none)" : rt[r])
          break
        }
      }
    }
    if (!found) {
      print "FAIL: " s " calls repo_root() but is not referenced by any runtest rule in dune -- audit by hand. If this script is intentionally never a dune run-target or dep (e.g. an orchestrator-invoked entrypoint run outside `dune runtest` by construction), add it to universe_deps_exceptions.conf with that evidence rather than wiring it into dune just to silence this check."
      fail++
      continue
    }
    if (!ok) {
      print "FAIL: " s " calls repo_root() (reads outside the dune workspace root) but its owning rule (" owner ") does not declare (universe). A warm _build will silently skip re-running it when the file(s) it reads change (H-CHECK-CACHE-BLIND). Add (universe) to that rule deps, or add \"" s "\" to universe_deps_exceptions.conf with recorded evidence if the read is provably already covered or dead."
      fail++
    } else {
      print "OK: " s " -- owning rule (" owner ") declares (universe)"
    }
  }
  if (fail > 0) {
    print "FAIL: check_universe_deps -- " fail " script(s) missing (universe) coverage"
    exit 1
  }
  print "OK: check_universe_deps -- all repo_root()-calling scripts covered by (universe) or the exceptions list"
}
' "$DUNE_FILE" > "$RESULT_FILE" 2>&1
AWK_EXIT=$?
set -e

cat "$RESULT_FILE"

if [ "$AWK_EXIT" -ne 0 ]; then
  exit 1
fi
exit 0
