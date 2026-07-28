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
# check_universe_deps_test.sh). For every candidate script (one whose body
# contains the substring "repo_root"), find the rule that runs it (its
# %{dep:...} run-target) or, if it is never itself a run-target, the rule
# that lists it as a dep. FAIL if that rule lacks "(universe)" and the
# script is not listed in universe_deps_exceptions.conf.
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

# --- Candidate scripts: any *.sh (excluding _check_lib.sh itself, which
# defines the helper but is never a dune run-target) whose body contains
# an actual repo_root call site: "$(repo_root)" / "(repo_root)" or the
# private-reimplementation form "$(_repo_root)" / "(_repo_root)" — i.e.
# "repo_root" immediately followed by a closing paren. This deliberately
# does NOT match on the bare substring "repo_root" (a false-positive risk
# proven by check_universe_deps_test.sh assertion 5: a script that merely
# mentions another script's filename like "helper_with_repo_root.sh" in
# a comment or echo string must NOT be treated as a repo_root() caller).
CANDIDATES=$(cd "$CHECKS_DIR" && grep -lE 'repo_root\)' ./*.sh 2>/dev/null \
  | sed 's#^\./##' | grep -v '^_check_lib\.sh$' || true)

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
function strip_comments(b) {
  gsub(/(^|\n)[ \t]*;[^\n]*/, "\n", b)
  return b
}
BEGIN {
  # NOTE: RS is a single global setting in awk -- it applies to explicit
  # getline < file reads too, not just the main input. Read the
  # newline-delimited exceptions/candidates files FIRST under the
  # default RS="\n", THEN switch to paragraph mode ("") for the main
  # dune-file input below. Getting this order backwards was caught by
  # check_universe_deps_test.sh assertion 5 in development: with RS=""
  # active during the getline loops, the whole candidates file was read
  # as one blank-line-delimited "record" instead of one filename per line.
  RS = "\n"

  nallow = 0
  if (exceptions != "") {
    while ((getline aline < exceptions) > 0) {
      sub(/#.*/, "", aline)
      gsub(/^[ \t]+|[ \t]+$/, "", aline)
      if (aline != "") { nallow++; allow[aline] = 1 }
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
/^\(rule/ {
  block = strip_comments($0)
  hasuniv = (block ~ /\(universe\)/) ? 1 : 0

  runtarget = ""
  if (match(block, /\(run[ \t\n]+(sh|bash)[ \t\n]+%\{dep:[A-Za-z0-9_.]+\}/)) {
    seg = substr(block, RSTART, RLENGTH)
    sub(/.*%\{dep:/, "", seg)
    sub(/\}.*/, "", seg)
    runtarget = seg
  }

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
      print "FAIL: " s " calls repo_root() but is not referenced by any runtest rule in dune -- audit by hand"
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
