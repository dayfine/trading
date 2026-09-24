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
#   sh dev/scripts/codex_review.sh <PR> [--no-post] [--dry-run] [--force]
#     --no-post   run and validate, print the report path, do not post
#     --dry-run   print the prompt that would be sent and exit (no codex call)
#     --force     skip the sampling draw and the daily cap (see BUDGET)
#   Env:
#     CODEX_REVIEW=off   the fallback switch: exit 0 immediately, do nothing
#     CODEX_REVIEW_SAMPLE=<p>       probability a call actually reviews (default 0.25)
#     CODEX_REVIEW_MAX_PER_DAY=<n>  daily cap on live codex runs (default 3)
#     CODEX_REVIEW_LOG_DIR=<dir>    where the daily run log lives (default dev/_tmp/codex)
#
# BUDGET (issue #2905 -- "budget some reviews by codex")
#   The dispatcher may call this on every PR that reaches MERGE; the script
#   decides whether a live run happens. Two guards, both above the LIB seam
#   and offline-tested:
#     sampling  should_sample PR SHA P -- a deterministic draw from cksum of
#               "PR:SHA" (0..9999) / 10000 < P. Same tip, same answer, so a
#               re-run never flips a sampled-out PR into a review or vice
#               versa. Bypassed by --force or by a review/codex-* label.
#     cap       daily_count LOG >= CODEX_REVIEW_MAX_PER_DAY -> exit 0 "cap".
#               codex-cli 0.154.0 exposes NO usage or quota query (checked
#               `codex --help`, `codex login --help`: only login status /
#               doctor), so the per-day cap is the proxy for "check usage
#               before running". Bypassed by --force or review/codex-required.
#   Every live run appends "PR SHA" to /reviews-<date>.log
#   (dev/_tmp is gitignored). The A/B side -- did Codex agree with the Claude
#   gates? -- is dev/scripts/codex_agreement_row.sh, run at merge time.
#
# COST (issue #2922 item 2)
#   There is no quota query, but `codex exec --json` streams JSONL events and
#   each `turn.completed` event carries `usage` {input_tokens,
#   cached_input_tokens, output_tokens, reasoning_output_tokens} (0.154.0;
#   input_tokens INCLUDES the cached part). The events land next to the report
#   as REPORT.events.jsonl, and once codex exits -- success or failure -- the
#   run's log line is completed in place to
#     PR SHA in=<n> cached=<n> out=<n> reasoning=<n> wall=<s>s
#   or, when no turn completed (quota hit, crash), the measured proxy
#     PR SHA tokens=na events=<n> wall=<s>s
#   so "no usage" is never recorded as zero. codex_agreement_row.sh reads the
#   in/out figures into the A/B table's cost column.
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
  # --json: stdout becomes the JSONL event stream the caller captures for
  # usage_fields (COST above); the report itself still comes from -o.
  codex -C "$_wt" exec -s read-only --ephemeral --json $_model_args -o "$_report" "$(cat "$_promptfile")"
}

# usage_fields EVENTS -> "in=N cached=N out=N reasoning=N", summed over every
# turn.completed event's usage in the JSONL file EVENTS; "tokens=na events=N"
# when no such event exists (absent file = 0 events). Non-JSON lines are
# skipped, not fatal: the stream is whatever codex printed.
usage_fields() {
  [ -f "$1" ] || { echo "tokens=na events=0"; return 0; }
  jq -Rrs '
    [split("\n")[] | fromjson? | select(type == "object")] as $ev
    | [$ev[] | select(.type == "turn.completed" and (.usage | type) == "object") | .usage] as $u
    | if ($u | length) == 0 then "tokens=na events=\($ev | length)"
      else "in=\([$u[].input_tokens // 0] | add) cached=\([$u[].cached_input_tokens // 0] | add) out=\([$u[].output_tokens // 0] | add) reasoning=\([$u[].reasoning_output_tokens // 0] | add)"
      end' "$1"
}

# finish_run LOG PR SHA FIELDS -> completes the LAST line of LOG that is
# exactly "PR SHA" (the one record_run wrote for this run) to "PR SHA FIELDS".
# Line count is unchanged, so daily_count and the cap are unaffected. A LOG
# with no such line is left alone (nothing to complete).
finish_run() {
  [ -f "$1" ] || return 0
  _n=$(awk -v k="$2 $3" '$0 == k { n = NR } END { print n + 0 }' "$1")
  [ "$_n" -gt 0 ] || return 0
  awk -v n="$_n" -v f="$4" 'NR == n { $0 = $0 " " f } { print }' "$1" > "$1.tmp.$$" && mv "$1.tmp.$$" "$1"
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
# sample_draw PR SHA -> integer 0..9999, deterministic in (PR, SHA). cksum is
# POSIX; awk does the arithmetic so no shell integer-width assumptions.
sample_draw() {
  printf '%s:%s' "$1" "$2" | cksum | awk '{ print $1 % 10000 }'
}
# should_sample PR SHA P -> 0 when this tip is in the sample (draw/10000 < P),
# 1 otherwise. P is a decimal in [0,1]; P=1 always samples, P=0 never does.
should_sample() {
  _d=$(sample_draw "$1" "$2")
  awk -v d="$_d" -v p="$3" 'BEGIN { exit !(d / 10000 < p + 0) }'
}
# daily_count LOG -> number of live runs recorded in LOG (0 when absent).
daily_count() {
  if [ -f "$1" ]; then grep -c . "$1"; else echo 0; fi
}
# record_run LOG PR SHA -> append one "PR SHA" line (mkdir -p the dir).
record_run() {
  mkdir -p "$(dirname "$1")" && printf '%s %s\n' "$2" "$3" >> "$1"
}
# has_label LABELS_LINES NAME -> 0 when NAME is one of the newline-separated labels.
has_label() {
  printf '%s\n' "$1" | grep -qx "$2"
}

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

PR=""; POST=1; DRY=0; FORCE=0
for a in "$@"; do
  case "$a" in
    --no-post) POST=0 ;;
    --dry-run) DRY=1 ;;
    --force)   FORCE=1 ;;
    -*) echo "codex_review: unknown flag $a" >&2; exit 2 ;;
    *) PR=$a ;;
  esac
done
[ -n "$PR" ] || { echo "usage: sh dev/scripts/codex_review.sh <PR> [--no-post] [--dry-run] [--force]" >&2; exit 2; }
for t in gh jq git codex; do
  command -v "$t" >/dev/null 2>&1 || { echo "codex_review: $t not on PATH" >&2; exit 2; }
done

ROOT=$(git rev-parse --show-toplevel)
META=$(gh pr view "$PR" --repo "$REPO" --json headRefOid,title,files,labels)
SHA=$(printf '%s' "$META" | jq -r .headRefOid)
TITLE=$(printf '%s' "$META" | jq -r .title)
FILES=$(printf '%s' "$META" | jq -r '.files[].path')
if is_docs_only "$FILES"; then
  echo "codex_review: PR #$PR is docs-only; no advisory review (CI is the gate)"
  exit 0
fi
LABELS=$(printf "%s" "$META" | jq -r ".labels[].name")
SAMPLE_P=${CODEX_REVIEW_SAMPLE:-0.25}; CAP=${CODEX_REVIEW_MAX_PER_DAY:-3}
RUN_LOG="${CODEX_REVIEW_LOG_DIR:-$ROOT/dev/_tmp/codex}/reviews-$(date +%F).log"
if [ "$FORCE" = 0 ] && ! has_label "$LABELS" review/codex-requested && ! has_label "$LABELS" review/codex-required; then
  if ! should_sample "$PR" "$SHA" "$SAMPLE_P"; then
    echo "codex_review: PR #$PR at $SHA sampled out (CODEX_REVIEW_SAMPLE=$SAMPLE_P, draw $(sample_draw "$PR" "$SHA")); --force or a review/codex-* label overrides"
    exit 0
  fi
fi
if [ "$FORCE" = 0 ] && ! has_label "$LABELS" review/codex-required && [ "$(daily_count "$RUN_LOG")" -ge "$CAP" ]; then
  echo "codex_review: daily cap reached ($(daily_count "$RUN_LOG")/$CAP live runs in $RUN_LOG); --force or review/codex-required overrides"
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
record_run "$RUN_LOG" "$PR" "$SHA"

T0=$(date +%s); CODEX_RC=0
codex_invoke "$WT" "$REPORT" "$PROMPT" >"$REPORT.events.jsonl" 2>"$REPORT.stderr" || CODEX_RC=$?
finish_run "$RUN_LOG" "$PR" "$SHA" "$(usage_fields "$REPORT.events.jsonl") wall=$(( $(date +%s) - T0 ))s"
[ "$CODEX_RC" = 0 ] || {
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
