#!/bin/sh
# codex_review.sh -- run an ADVISORY Codex review of one PR and post it as a PR
# review whose first heading is "## Codex review -- <title>", which is what the
# CODEX column of dev/scripts/pr_gate_status.sh reads.
#
# WHY THIS EXISTS (.claude/rules/cross-agent-review.md)
#   A second reviewer with a different failure profile is useful, but the merge
#   decision stays on CI + qc-structural + qc-behavioral (Claude). This script
#   keeps Codex in the advisory seat: it never posts under a gate heading, it
#   never runs dune (no container slot), and it needs no `gh` write access of
#   its own -- the controller posts the report after validating its shape.
#
# USAGE
#   sh dev/scripts/codex_review.sh <PR> [--no-post] [--dry-run]
#     --no-post   run and validate, print the report path, do not post
#     --dry-run   print the prompt that would be sent and exit (no codex call)
#   Env:
#     CODEX_REVIEW=off   the fallback switch: exit 0 immediately, do nothing
#     CODEX_MODEL=<m>    optional model override passed as -m
#     REPORT_DIR=<dir>   where the report file lands (default /tmp)
#
# SHAPE OF THE REPORT (validated before posting; see validate_report)
#   line 1      : Reviewed SHA: <full 40-char head sha>
#   1st heading : ## Codex review -- <PR title>      (never a gate heading)
#   ...         : ## Verdict  followed by APPROVED | NEEDS_REWORK
#   Any line opening "## Structural QC", "## Behavioral QC" or "## qc-" fails
#   validation: those are the Claude gate headings and pr_gate_status.sh would
#   attribute the review to that gate (the #2620 false-green shape).
set -eu

REPO="${REPO:-dayfine/trading}"
REPORT_DIR="${REPORT_DIR:-/tmp}"

# validate_report FILE SHA -> 0 if the report has the advisory shape, else 1 with
# one "codex_review: ..." line per defect on stderr.
validate_report() {
  _f=$1; _sha=$2; _bad=0
  _first=$(sed -n '1p' "$_f")
  if [ "$_first" != "Reviewed SHA: $_sha" ]; then
    echo "codex_review: first line must be 'Reviewed SHA: $_sha' (got: $_first)" >&2; _bad=1
  fi
  _heading=$(grep -m1 '^#\{1,4\} ' "$_f" || true)
  case "$_heading" in
    "## Codex review "*) ;;
    *) echo "codex_review: first heading must start with '## Codex review ' (got: $_heading)" >&2; _bad=1 ;;
  esac
  if grep -qiE '^#{1,4} +(qc[- ])?(structural|behavioral)\b' "$_f"; then
    echo "codex_review: report carries a Claude gate heading (structural/behavioral); refusing to post" >&2; _bad=1
  fi
  # The heading must be exactly "Verdict" (optionally with a colon): the CODEX
  # reader requires the token to follow "^#+ +Verdict" directly, so a heading
  # like "## Verdict explanation" would validate here yet read as "unclear"
  # there (advisory Codex review 5194074884 of #2798). The token is the next
  # non-blank line, matching the reader's gap class.
  _verdict=$(awk 'f && NF {print; exit} /^#+ +Verdict[ :]*\r?$/ {f=1}' "$_f" | tr -d ' \r')
  case "$_verdict" in
    APPROVED|NEEDS_REWORK) ;;
    *) echo "codex_review: '## Verdict' must be followed by APPROVED or NEEDS_REWORK (got: ${_verdict:-<none>})" >&2; _bad=1 ;;
  esac
  return $_bad
}

# is_docs_only "<paths, one per line>" -> 0 when every path is docs (same
# allowlist as pr_gate_status.sh); an advisory review of prose is wasted work.
is_docs_only() {
  for f in $1; do
    case "$f" in
      *.md) ;;
      dev/notes/*|dev/plans/*|dev/reviews/*|dev/status/*) ;;
      *) return 1 ;;
    esac
  done
  return 0
}

# codex_invoke WT REPORT PROMPTFILE -> runs Codex read-only in WT and leaves the
# report at REPORT. Plain `codex exec` (read-only sandbox is its default), NOT
# `codex exec review`: that subcommand refuses a custom PROMPT alongside --base
# (measured on 0.154.0: "the argument '--base <BRANCH>' cannot be used with
# '[PROMPT]'"), and the prompt is what carries the machine-parsed format. The
# invocation shape is pinned by codex_review_test.sh with a stub codex on PATH
# -- the first live run (PR #2798) failed exactly here.
codex_invoke() {
  _wt=$1; _report=$2; _promptfile=$3
  _model_args=""
  [ -n "${CODEX_MODEL:-}" ] && _model_args="-m $CODEX_MODEL"
  # shellcheck disable=SC2086
  # -s read-only is explicit: `codex exec` takes the sandbox mode from user/project
  # config otherwise, so a dispatcher configured for workspace-write would
  # launch a writable reviewer (advisory Codex review 5194019340 of #2798).
  codex -C "$_wt" exec -s read-only --ephemeral $_model_args -o "$_report" "$(cat "$_promptfile")"
}

# post_report PR SHA REPORT -> posts the report as a COMMENTED PR review pinned
# to SHA; prints the review id; non-zero when the API call fails or returns no
# id. Captured, not piped: under POSIX sh `gh api ... | sed` returns sed's
# status, so a failed post exited 0 -- the advisory Codex review of #2798 found it.
post_report() {
  _pr=$1; _sha=$2; _report=$3
  _id=$(gh api -X POST "repos/$REPO/pulls/$_pr/reviews" -f event=COMMENT -f commit_id="$_sha" -F body=@"$_report" --jq '.id') || return 1
  [ -n "$_id" ] || return 1
  echo "codex_review: posted review id $_id"
}

# reader_agrees FILE SHA -> 0 when the real CODEX reader (pr_gate_status.sh
# _gate, sourced through its LIB seam) reads the same verdict validate_report
# saw ("ok" for APPROVED, "rework" for NEEDS_REWORK). A report can pass the
# line-oriented validator yet read "unclear" there -- two verdict headings
# with different tokens, or the only verdict inside a fenced block (advisory
# Codex review 5194134240 of #2798) -- so posting requires the reader's word.
reader_agrees() {
  _f=$1; _sha=$2
  _want=$(awk 'f && NF {print; exit} /^#+ +Verdict[ :]*\r?$/ {f=1}' "$_f" | tr -d ' \r')
  case "$_want" in APPROVED) _want=ok ;; NEEDS_REWORK) _want=rework ;; *) return 1 ;; esac
  _got=$( PR_GATE_STATUS_LIB=1 . "$(dirname "$0")/pr_gate_status.sh"; _gate "$(jq -nc --arg b "$(cat "$_f")" '[{body: $b}]')" codex "$_sha" )
  if [ "$_got" != "$_want" ]; then
    echo "codex_review: the CODEX reader reads '$_got' where the validator saw '$_want'; refusing to post" >&2
    return 1
  fi
}

# build_prompt PR SHA TITLE REPO -> the review prompt on stdout. Everything the
# reviewer is told to read is pinned to the detached checkout at SHA (an
# immutable revision), never the live PR: a push during the review must not
# change what the report's "Reviewed SHA" line vouches for (advisory Codex
# review 5194134240 of #2798). No backticks: this text is emitted verbatim.
build_prompt() {
  _pr=$1; _sha=$2; _title=$3; _repo=$4
  cat <<PEOF
Review PR #$_pr (head $_sha, title: $_title) of $_repo as an independent ADVISORY reviewer.
You are in a detached checkout of exactly $_sha. Read ONLY that checkout: the change is
'git diff origin/main...HEAD' and the file list is 'git diff --name-only origin/main...HEAD'
(do not use 'gh pr diff' or 'gh pr view' -- the live PR may have moved past this revision).
Look for: correctness defects, missing or weak tests for claims the diff makes, contract drift
between .mli docstrings / commit messages and the code, and violations of the repo rules under
.claude/rules/ (test-patterns.md, experiment-flag-discipline.md, config-default-blast-radius.md,
universe-discipline.md where relevant). Do NOT run dune, do not modify files, do not commit,
push or post to GitHub.
Report format (machine-parsed; follow exactly):
  line 1: Reviewed SHA: $_sha
  first heading: ## Codex review — $_title
  then a findings table (| # | Check | Status | Notes |), a '## Quality Score' (1-5),
  exactly ONE '## Verdict' heading whose next line is exactly APPROVED or NEEDS_REWORK
  (never inside a code fence, never repeated), and '## NEEDS_REWORK Items'
  (Finding / Location / Required fix) when applicable.
Never use the headings 'Structural QC', 'Behavioral QC' or 'qc-...' anywhere: those name the
Claude merge gates and your review is advisory, not a gate. Do not mention those gates.
PEOF
}

# Sourcing with CODEX_REVIEW_LIB=1 stops here (offline tests).
[ "${CODEX_REVIEW_LIB:-}" = 1 ] && return 0

if [ "${CODEX_REVIEW:-on}" = off ]; then
  echo "codex_review: disabled (CODEX_REVIEW=off); nothing done"
  exit 0
fi

PR=""; POST=1; DRY=0
for a in "$@"; do
  case "$a" in
    --no-post) POST=0 ;;
    --dry-run) DRY=1 ;;
    -*) echo "codex_review: unknown flag $a" >&2; exit 2 ;;
    *) PR=$a ;;
  esac
done
[ -n "$PR" ] || { echo "usage: sh dev/scripts/codex_review.sh <PR> [--no-post] [--dry-run]" >&2; exit 2; }
for t in gh jq git codex; do
  command -v "$t" >/dev/null 2>&1 || { echo "codex_review: $t not on PATH" >&2; exit 2; }
done

ROOT=$(git rev-parse --show-toplevel)
META=$(gh pr view "$PR" --repo "$REPO" --json headRefOid,title,files)
SHA=$(printf '%s' "$META" | jq -r .headRefOid)
TITLE=$(printf '%s' "$META" | jq -r .title)
FILES=$(printf '%s' "$META" | jq -r '.files[].path')
if is_docs_only "$FILES"; then
  echo "codex_review: PR #$PR is docs-only; no advisory review (CI is the gate)"
  exit 0
fi

# One directory per invocation (PID-suffixed): concurrent runs on the same PR
# must not overwrite each other's prompt or validated report before it is
# posted (advisory Codex review 5194186949 of #2798). The report path is
# printed on success and failure so it can always be retrieved.
RUN_DIR="$REPORT_DIR/codex-review-pr-$PR-$$"
mkdir -p "$RUN_DIR"
REPORT="$RUN_DIR/report-$SHA.md"
PROMPT="$RUN_DIR/prompt.txt"
build_prompt "$PR" "$SHA" "$TITLE" "$REPO" > "$PROMPT"
if [ "$DRY" = 1 ]; then
  echo "codex_review: dry run -- prompt for PR #$PR at $SHA:"; echo; cat "$PROMPT"; exit 0
fi

WT="$ROOT/.claude/worktrees/codex-review-pr-$PR-$$"
cleanup() { git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true; git -C "$ROOT" worktree prune >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM
git -C "$ROOT" fetch -q origin "pull/$PR/head"
git -C "$ROOT" worktree add --detach "$WT" "$SHA" >/dev/null

codex_invoke "$WT" "$REPORT" "$PROMPT" >/dev/null 2>"$REPORT.stderr" || {
  echo "codex_review: codex exec failed (stderr in $REPORT.stderr)" >&2; exit 1; }

if ! validate_report "$REPORT" "$SHA"; then
  echo "codex_review: report at $REPORT did not validate; NOT posted" >&2
  exit 1
fi
reader_agrees "$REPORT" "$SHA" || { echo "codex_review: report at $REPORT validated but the CODEX reader disagrees; NOT posted" >&2; exit 1; }
echo "codex_review: report validated (validator + CODEX reader agree): $REPORT"
if [ "$POST" = 1 ]; then
  post_report "$PR" "$SHA" "$REPORT" || { echo "codex_review: POST failed; the validated report is at $REPORT" >&2; exit 1; }
else
  echo "codex_review: --no-post; not posted"
fi
