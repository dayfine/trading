#!/bin/sh
# codex_agreement_row.sh -- one A/B row per PR: did the advisory Codex review
# agree with the two Claude gates at the same tip? (issue #2905)
#
# WHY: .claude/rules/cross-agent-review.md keeps Codex advisory until its
# verdicts have agreed with the Claude gates "across enough PRs to trust it".
# Nothing recorded that agreement, so the promotion question could never be
# answered. This script derives the row from the review bodies with the SAME
# reader pr_gate_status.sh uses (`_gate`), so a verdict here means what the
# gate loop meant by it.
#
# USAGE
#   sh dev/scripts/codex_agreement_row.sh <PR> [--append]
#     prints one markdown table row; --append also appends it to
#     dev/reviews/codex-agreement.md (created with a header when missing).
#   Run it when a PR that had a live Codex review reaches MERGE, so all three
#   verdicts exist at the tip. A PR with no Codex review at the tip prints a
#   row whose codex column is "none" -- still useful: it records a sampled-out
#   or failed run next to the Claude verdicts.
#
# ROW  | date | PR | tip | struct | behav | codex | agree | codex-only items | claude-only items | codex tok in/out | note |
#   agree = yes when codex == behav-or-struct combined ("rework" if either
#   Claude gate is rework, else "ok"); "n/a" when codex is none/stale.
#   items = count of "### " headings under a "## NEEDS_REWORK Items" heading in
#   each body, a proxy for findings; the note column is for the human read.
#   codex tok in/out = the input/output tokens of the live Codex run at this
#   tip, read from the codex_review.sh run log ($CODEX_REVIEW_LOG_DIR, default
#   dev/_tmp/codex, any reviews-<date>.log; issue #2922 item 2). input
#   includes the cached part. "n/a" when no run is logged or the run recorded
#   tokens=na (no completed turn) -- a missing cost is never written as 0.
#
# Offline seam: CODEX_AGREEMENT_LIB=1 sources the functions only.
set -eu
HERE=$(dirname "$0")
REPO=${REPO:-dayfine/trading}
_ROOT=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null || echo .)
AGREEMENT_FILE=${AGREEMENT_FILE:-"$_ROOT/dev/reviews/codex-agreement.md"}
CODEX_LOG_DIR=${CODEX_REVIEW_LOG_DIR:-"$_ROOT/dev/_tmp/codex"}

# claude_combined STRUCT BEHAV -> rework | ok | pending
claude_combined() {
  case "$1:$2" in
    rework:*|*:rework) echo rework ;;
    ok:ok)             echo ok ;;
    *)                 echo pending ;;
  esac
}
# agree CLAUDE CODEX -> yes | no | n/a
agree() {
  case "$2" in
    ok|rework) if [ "$1" = "$2" ]; then echo yes; else echo no; fi ;;
    *) echo n/a ;;
  esac
}
# rework_items REVIEWS_JSON KIND -> number of "### " headings after the
# "## NEEDS_REWORK Items" heading in the newest body whose FIRST heading
# names KIND (structural | behavioral | codex); 0 when none. First heading
# only, as in pr_gate_status.sh first_heading_text: a structural body that
# quotes "## Behavioral QC" further down must not count as a behavioral
# review (pr-gate-loop.md; qc-behavioral CP1-A on #2907).
rework_items() {
  printf '%s' "$1" | jq -r --arg kind "$2" '
    def first_heading: [match("(?m)^#{1,4} +(?<h>.*)$")] | if length == 0 then "" else .[0].captures[0].string end;
    [ .[] | select(((.body // "") | first_heading) | test("^(qc[- ])?" + $kind + "\\b"; "i")) ]
    | if length == 0 then "" else (last | .body) end' \
  | awk 'f && /^### / { n++ } /^## +NEEDS_REWORK Items/ { f=1 } END { print n + 0 }'
}
# codex_tokens PR TIP -> "<in>/<out>" from the newest run-log line for exactly
# (PR, TIP) across $CODEX_LOG_DIR/reviews-*.log, else "n/a" (no line, or a
# line recorded as tokens=na / never completed by codex_review.sh finish_run).
codex_tokens() {
  cat "$CODEX_LOG_DIR"/reviews-*.log 2>/dev/null \
  | awk -v pr="$1" -v sha="$2" '
      $1 == pr && $2 == sha { i = ""; o = ""
        for (k = 3; k <= NF; k++) {
          if ($k ~ /^in=[0-9]+$/)  i = substr($k, 4)
          if ($k ~ /^out=[0-9]+$/) o = substr($k, 5)
        }
        last = (i != "" && o != "") ? i "/" o : "n/a" }
      END { print (last == "" ? "n/a" : last) }'
}
# agreement_row PR TIP REVIEWS_JSON [NOTE] -> the markdown row (no trailing newline issues).
agreement_row() {
  _pr=$1; _tip=$2; _reviews=$3; _note=${4:-}
  _s=$( PR_GATE_STATUS_LIB=1 . "$HERE/pr_gate_status.sh"; _gate "$_reviews" structural "$_tip" )
  _b=$( PR_GATE_STATUS_LIB=1 . "$HERE/pr_gate_status.sh"; _gate "$_reviews" behavioral "$_tip" )
  _c=$( PR_GATE_STATUS_LIB=1 . "$HERE/pr_gate_status.sh"; _gate "$_reviews" codex "$_tip" )
  _claude=$(claude_combined "$_s" "$_b")
  _codex_items=$(rework_items "$_reviews" codex)
  _claude_items=$(( $(rework_items "$_reviews" structural) + $(rework_items "$_reviews" behavioral) ))
  printf '| %s | #%s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n' \
    "$(date +%F)" "$_pr" "$(printf '%s' "$_tip" | cut -c1-9)" "$_s" "$_b" "$_c" \
    "$(agree "$_claude" "$_c")" "$_codex_items" "$_claude_items" "$(codex_tokens "$_pr" "$_tip")" "$_note"
}
ensure_header() {
  if [ ! -f "$1" ]; then
    mkdir -p "$(dirname "$1")"
    printf '%s\n' \
      '# Codex vs Claude review agreement (issue #2905)' '' \
      'One row per PR that reached MERGE after a live advisory Codex review; appended by' \
      '`sh dev/scripts/codex_agreement_row.sh <PR> --append`. `agree` compares the Codex' \
      'verdict with the combined Claude verdict (rework if either gate said so). Read the' \
      'table monthly: the promotion path in `docs/howtos/codex_pr_reviews.md` becomes a' \
      'discussable option only after >= 20 rows with agree >= 90 % and no Codex-only' \
      'false rework (`.claude/rules/cross-agent-review.md`).' '' \
      '| date | PR | tip | struct | behav | codex | agree | codex-only items | claude-only items | codex tok in/out | note |' \
      '|---|---|---|---|---|---|---|---|---|---|---|' > "$1"
  fi
}

[ "${CODEX_AGREEMENT_LIB:-}" = 1 ] && return 0
PR=""; APPEND=0; NOTE=""
for a in "$@"; do
  case "$a" in
    --append) APPEND=1 ;;
    --note=*) NOTE=${a#--note=} ;;
    -*) echo "codex_agreement_row: unknown flag $a" >&2; exit 2 ;;
    *) PR=$a ;;
  esac
done
[ -n "$PR" ] || { echo "usage: sh dev/scripts/codex_agreement_row.sh <PR> [--append] [--note=...]" >&2; exit 2; }
for t in gh jq; do command -v "$t" >/dev/null 2>&1 || { echo "codex_agreement_row: $t not on PATH" >&2; exit 2; }; done
TIP=$(gh pr view "$PR" --repo "$REPO" --json headRefOid --jq .headRefOid)
REVIEWS=$(gh api "repos/$REPO/pulls/$PR/reviews?per_page=100" --jq '[.[] | {body: .body, commit_id: .commit_id}]')
ROW=$(agreement_row "$PR" "$TIP" "$REVIEWS" "$NOTE")
printf '%s\n' "$ROW"
if [ "$APPEND" = 1 ]; then ensure_header "$AGREEMENT_FILE"; printf '%s\n' "$ROW" >> "$AGREEMENT_FILE"; echo "codex_agreement_row: appended to $AGREEMENT_FILE"; fi
