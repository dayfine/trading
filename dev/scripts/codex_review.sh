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
  _verdict=$(awk 'f && NF {print; exit} /^#+ +Verdict/ {f=1}' "$_f" | tr -d ' \r')
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
  codex -C "$_wt" exec --ephemeral $_model_args -o "$_report" "$(cat "$_promptfile")"
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

REPORT="$REPORT_DIR/codex-review-pr-$PR-$SHA.md"
PROMPT="$REPORT_DIR/codex-review-pr-$PR-prompt.txt"
# Unquoted heredoc so $PR/$SHA/$TITLE expand; no backticks anywhere inside it
# (they would execute -- the first dry run pasted `gh pr diff` output into the
# prompt this way).
cat > "$PROMPT" <<PEOF
Review PR #$PR (head $SHA, title: $TITLE) of $REPO as an independent ADVISORY reviewer.
Scope = the PR's own file list (gh pr view $PR --json files). You are in a detached checkout of the PR head;
read the change with 'gh pr diff $PR' (or 'git diff origin/main...HEAD') and the files themselves.
Look for: correctness defects, missing or weak tests for claims the diff makes, contract drift
between .mli docstrings / PR body and the code, and violations of the repo rules under
.claude/rules/ (test-patterns.md, experiment-flag-discipline.md, config-default-blast-radius.md,
universe-discipline.md where relevant). Do NOT run dune, do not modify files, do not commit,
push or post to GitHub.
Report format (machine-parsed; follow exactly):
  line 1: Reviewed SHA: $SHA
  first heading: ## Codex review — $TITLE
  then a findings table (| # | Check | Status | Notes |), a '## Quality Score' (1-5),
  '## Verdict' whose next line is exactly APPROVED or NEEDS_REWORK, and
  '## NEEDS_REWORK Items' (Finding / Location / Required fix) when applicable.
Never use the headings 'Structural QC', 'Behavioral QC' or 'qc-...' anywhere: those name the
Claude merge gates and your review is advisory, not a gate. Do not mention those gates.
PEOF
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
echo "codex_review: report validated: $REPORT"
if [ "$POST" = 1 ]; then
  post_report "$PR" "$SHA" "$REPORT" || { echo "codex_review: POST failed; the validated report is at $REPORT" >&2; exit 1; }
else
  echo "codex_review: --no-post; not posted"
fi
