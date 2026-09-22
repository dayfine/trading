#!/bin/sh
# Offline tests for dev/scripts/codex_review.sh: the report validator (the only
# thing standing between a Codex report and a posted PR review) and the
# CODEX_REVIEW=off fallback switch. No codex or gh call is made.
set -eu
HERE=$(dirname "$0")
CODEX_REVIEW_LIB=1
export CODEX_REVIEW_LIB
# shellcheck source=/dev/null
. "$HERE/codex_review.sh"

SHA=7dc57cc06aa1b2c3d4e5f60718293a4b5c6d7e8f
fails=0; total=0
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT

check() {
  _name=$1; _want=$2; _got=$3
  total=$((total + 1))
  if [ "$_got" = "$_want" ]; then printf 'ok   %s\n' "$_name"
  else printf 'FAIL %s: want %s, got %s\n' "$_name" "$_want" "$_got"; fails=$((fails + 1)); fi
}
rc() { if validate_report "$1" "$SHA" 2>/dev/null; then echo 0; else echo 1; fi; }

printf 'Reviewed SHA: %s\n\n## Codex review — thing (PR #1)\n\n| # | Check | Status |\n|---|---|---|\n\n## Quality Score\n\n4\n\n## Verdict\n\nAPPROVED\n' "$SHA" > "$D/good.md"
check "good report validates" 0 "$(rc "$D/good.md")"

printf 'Reviewed SHA: %s\n\n## Codex review — thing\n\n## Verdict\n\nNEEDS_REWORK\n\n## NEEDS_REWORK Items\n\n- x\n' "$SHA" > "$D/rework.md"
check "NEEDS_REWORK verdict validates" 0 "$(rc "$D/rework.md")"

printf 'Reviewed SHA: deadbeef\n\n## Codex review — thing\n\n## Verdict\n\nAPPROVED\n' > "$D/sha.md"
check "wrong Reviewed SHA fails" 1 "$(rc "$D/sha.md")"

printf '## Codex review — thing\n\nReviewed SHA: %s\n\n## Verdict\n\nAPPROVED\n' "$SHA" > "$D/line1.md"
check "Reviewed SHA not on line 1 fails" 1 "$(rc "$D/line1.md")"

printf 'Reviewed SHA: %s\n\n## Structural QC — thing\n\n## Verdict\n\nAPPROVED\n' "$SHA" > "$D/struct.md"
check "structural gate heading fails" 1 "$(rc "$D/struct.md")"

printf 'Reviewed SHA: %s\n\n## Codex review — thing\n\n## Behavioral QC notes\n\n## Verdict\n\nAPPROVED\n' "$SHA" > "$D/behav.md"
check "interior behavioral gate heading fails" 1 "$(rc "$D/behav.md")"

printf 'Reviewed SHA: %s\n\n## Codex review — thing\n\n## qc-structural\n\n## Verdict\n\nAPPROVED\n' "$SHA" > "$D/qc.md"
check "qc- prefixed heading fails" 1 "$(rc "$D/qc.md")"

printf 'Reviewed SHA: %s\n\n## Codex review — thing\n\nAPPROVED\n' "$SHA" > "$D/noverdict.md"
check "missing ## Verdict fails" 1 "$(rc "$D/noverdict.md")"

printf 'Reviewed SHA: %s\n\n## Codex review — thing\n\n## Verdict\n\nLGTM\n' "$SHA" > "$D/token.md"
check "non-canonical verdict token fails" 1 "$(rc "$D/token.md")"

printf 'Reviewed SHA: %s\n\n## Verdict\n\nAPPROVED\n' "$SHA" > "$D/noheading.md"
check "Verdict as the first heading (no Codex review heading) fails" 1 "$(rc "$D/noheading.md")"

check "docs-only: md + dev/notes paths" 0 "$(if is_docs_only "README.md
dev/notes/x.md"; then echo 0; else echo 1; fi)"
check "docs-only: an .ml path is not docs-only" 1 "$(if is_docs_only "trading/x.ml
README.md"; then echo 0; else echo 1; fi)"

rc=0; out=$(CODEX_REVIEW=off CODEX_REVIEW_LIB= sh "$HERE/codex_review.sh" 999999 2>&1) || rc=$?; out="$out
rc=$rc"
check "CODEX_REVIEW=off exits 0 without doing anything" "rc=0" "$(printf "$out" | tail -1)"
check "CODEX_REVIEW=off says so" 1 "$(printf '%s' "$out" | grep -c 'disabled (CODEX_REVIEW=off)')"

rc=0; out=$(CODEX_REVIEW_LIB= sh "$HERE/codex_review.sh" 2>&1) || rc=$?
check "no PR argument exits 2" "rc=2" "rc=$rc"

# Invocation shape (advisory Codex review of #2798, finding 1): a stub codex on
# PATH records its argv; the shape must be plain `exec` with --ephemeral, -o
# REPORT, and the prompt as the LAST argument -- never the `review` subcommand,
# which refuses a custom prompt alongside --base.
mkdir -p "$D/bin"
cat > "$D/bin/codex" <<'CEOF'
#!/bin/sh
printf '%s\n' "$@" > "$CODEX_STUB_ARGV"
exit 0
CEOF
chmod +x "$D/bin/codex"
printf 'the prompt\n' > "$D/prompt.txt"
CODEX_STUB_ARGV="$D/argv" PATH="$D/bin:$PATH" codex_invoke "$D/wt" "$D/report.md" "$D/prompt.txt"
check "codex_invoke: uses plain exec, not the review subcommand" 0 "$(grep -cx review "$D/argv")"
check "codex_invoke: passes --ephemeral" 1 "$(grep -cx -- --ephemeral "$D/argv")"
check "codex_invoke: passes -o REPORT" "$D/report.md" "$(awk 'p{print; exit} $0=="-o"{p=1}' "$D/argv")"
check "codex_invoke: prompt is the last argument" "the prompt" "$(tail -1 "$D/argv")"
check "codex_invoke: -C worktree first" "-C" "$(sed -n 1p "$D/argv")"
check "codex_invoke: sandbox is explicitly read-only" "read-only" "$(awk 'p{print; exit} $0=="-s"{p=1}' "$D/argv")"

# Posting (finding 2): a failed `gh api` must make post_report return non-zero;
# the old pipe into sed masked it under POSIX sh.
# The failure arms are called as AND-OR lists (`post_report … || rc=$?`), the
# same shape as the real call site in codex_review.sh, NOT inside `$(…)`: in a
# command substitution `set -e` stays live and aborts the function on the
# failing assignment, which masked a dropped `|| return 1` (qc-behavioral
# rework iteration 2 of #2798, review 5194837826). In an AND-OR list `set -e`
# is suppressed inside the function, so only the explicit guard can fail it.
cat > "$D/bin/gh" <<'GEOF'
#!/bin/sh
case "$GH_STUB_MODE" in
  fail) echo "gh: HTTP 422" >&2; exit 1 ;;
  failbody) echo 4242; echo "gh: HTTP 500 after body" >&2; exit 1 ;;
  empty) exit 0 ;;
  *) echo 4242 ;;
esac
GEOF
chmod +x "$D/bin/gh"
rc=0; out=$(GH_STUB_MODE=ok PATH="$D/bin:$PATH" post_report 1 "$SHA" "$D/good.md") || rc=$?
check "post_report: success returns 0 and prints the id" "0 codex_review: posted review id 4242" "$rc $out"
rc=0; GH_STUB_MODE=fail PATH="$D/bin:$PATH" post_report 1 "$SHA" "$D/good.md" >/dev/null 2>&1 || rc=$?
check "post_report: a failed gh api returns non-zero" 1 "$rc"
# qc-behavioral rework iteration 1 (#2798, review 5194401789): the fail stub
# above prints nothing, so the empty-id guard fires and the exit-status capture
# was never the thing under test (a `gh api | sed` pipe survived). This arm
# exits non-zero WHILE printing an id, so only the captured status can catch it.
rc=0; GH_STUB_MODE=failbody PATH="$D/bin:$PATH" post_report 1 "$SHA" "$D/good.md" >/dev/null 2>&1 || rc=$?
check "post_report: a failed gh api that still prints an id returns non-zero" 1 "$rc"
rc=0; out=$(GH_STUB_MODE=empty PATH="$D/bin:$PATH" post_report 1 "$SHA" "$D/good.md") || rc=$?
check "post_report: an empty id returns non-zero" 1 "$rc"

# Validator / reader agreement (advisory Codex review 5194074884 of #2798):
# a heading like "## Verdict explanation" used to validate here while the
# CODEX reader (pr_gate_status.sh _gate) reads "unclear" for it. The validator
# now requires the heading to be exactly "Verdict"; and a report that validates
# must read "ok" through the real reader, sourced via its own LIB seam.
printf 'Reviewed SHA: %s\n\n## Codex review — thing\n\n## Verdict explanation\n\nAPPROVED\n' "$SHA" > "$D/verdictx.md"
check "a 'Verdict explanation' heading does not validate" 1 "$(rc "$D/verdictx.md")"
printf 'Reviewed SHA: %s\n\n## Codex review — thing\n\n## Verdict:\n\nNEEDS_REWORK\n' "$SHA" > "$D/verdictcolon.md"
check "a colon-style 'Verdict:' heading validates (reader accepts it too)" 0 "$(rc "$D/verdictcolon.md")"
PR_GATE_STATUS_LIB=1
export PR_GATE_STATUS_LIB
# shellcheck source=/dev/null
. "$HERE/pr_gate_status.sh"
_json() { jq -nc --arg b "$(cat "$1")" '[{body: $b}]'; }
check "compat: a validated APPROVED report reads ok in the CODEX reader" ok "$(_gate "$(_json "$D/good.md")" codex "$SHA")"
check "compat: a validated NEEDS_REWORK report reads rework in the CODEX reader" rework "$(_gate "$(_json "$D/rework.md")" codex "$SHA")"
check "compat: the colon-style report reads rework in the CODEX reader" rework "$(_gate "$(_json "$D/verdictcolon.md")" codex "$SHA")"
check "compat: a validated report never reads on the structural gate" none "$(_gate "$(_json "$D/good.md")" structural "$SHA")"

# reader_agrees (advisory Codex review 5194134240 of #2798): the real CODEX
# reader must read the validator's verdict before a post happens.
check "reader_agrees: good report" 0 "$(if reader_agrees "$D/good.md" "$SHA"; then echo 0; else echo 1; fi)"
check "reader_agrees: rework report" 0 "$(if reader_agrees "$D/rework.md" "$SHA"; then echo 0; else echo 1; fi)"
printf 'Reviewed SHA: %s\n\n## Codex review — thing\n\n## Verdict\n\nAPPROVED\n\n## Verdict\n\nNEEDS_REWORK\n' "$SHA" > "$D/twoverdicts.md"
check "conflicting verdicts: validator alone passes (first heading)" 0 "$(rc "$D/twoverdicts.md")"
check "conflicting verdicts: reader_agrees refuses" 1 "$(if reader_agrees "$D/twoverdicts.md" "$SHA" 2>/dev/null; then echo 0; else echo 1; fi)"
printf 'Reviewed SHA: %s\n\n## Codex review — thing\n\n```\n## Verdict\n\nAPPROVED\n```\n' "$SHA" > "$D/fenced.md"
check "fenced verdict: reader_agrees refuses" 1 "$(if reader_agrees "$D/fenced.md" "$SHA" 2>/dev/null; then echo 0; else echo 1; fi)"
# build_prompt: pinned to the checkout, never the live PR.
p=$(build_prompt 42 "$SHA" "a title" dayfine/trading)
check "prompt names the sha" 1 "$(printf '%s' "$p" | grep -c "Reviewed SHA: $SHA")"
check "prompt pins the diff to the checkout" 1 "$(printf '%s' "$p" | grep -c "git diff origin/main...HEAD'")"
check "prompt forbids the live PR diff" 1 "$(printf '%s' "$p" | grep -c "do not use 'gh pr diff'")"
check "prompt carries no backticks" 0 "$(printf '%s' "$p" | grep -c '`')"


# Budget guards (issue #2905): deterministic sampling + daily cap, above the seam.
d1=$(sample_draw 2906 "$SHA"); d2=$(sample_draw 2906 "$SHA")
check "sample_draw: deterministic in (PR, SHA)" "$d1" "$d2"
check "sample_draw: in 0..9999" 1 "$(awk -v d="$d1" 'BEGIN { print (d >= 0 && d < 10000) ? 1 : 0 }')"
check "sample_draw: a different tip draws differently (not constant)" 1 "$(n=0; for s in a b c d e f g h; do [ "$(sample_draw 1 "$s")" != "$d1" ] && n=$((n+1)); done; [ "$n" -ge 1 ] && echo 1 || echo 0)"
check "should_sample: P=1 always" 0 "$(should_sample 2906 "$SHA" 1 && echo 0 || echo 1)"
check "should_sample: P=0 never" 1 "$(should_sample 2906 "$SHA" 0 && echo 0 || echo 1)"
check "should_sample: agrees with the draw at P=0.25" "$(awk -v d="$d1" 'BEGIN { print (d / 10000 < 0.25) ? 0 : 1 }')" "$(should_sample 2906 "$SHA" 0.25 && echo 0 || echo 1)"
check "should_sample: roughly a quarter of 400 tips at P=0.25" 1 "$(n=0; i=0; while [ $i -lt 400 ]; do should_sample $i "$SHA" 0.25 && n=$((n+1)); i=$((i+1)); done; [ "$n" -ge 60 ] && [ "$n" -le 140 ] && echo 1 || echo "0 (n=$n)")"
check "daily_count: 0 when the log is absent" 0 "$(daily_count "$D/nolog")"
record_run "$D/logs/reviews-today.log" 1 "$SHA"; record_run "$D/logs/reviews-today.log" 2 "$SHA"
check "record_run + daily_count: two runs" 2 "$(daily_count "$D/logs/reviews-today.log")"
check "record_run: line is 'PR SHA'" "2 $SHA" "$(tail -1 "$D/logs/reviews-today.log")"
check "has_label: present" 0 "$(has_label "kind/harness
review/codex-required" review/codex-required && echo 0 || echo 1)"
check "has_label: prefix is not a match" 1 "$(has_label "review/codex-requested" review/codex-required && echo 0 || echo 1)"
check "--force is accepted by the arg parser (no 'unknown flag')" 0 "$(CODEX_REVIEW_LIB= sh "$HERE/codex_review.sh" --force 2>&1 | grep -c 'unknown flag')"
if [ "$fails" -gt 0 ]; then printf 'FAIL: codex_review -- %d test(s) failed.\n' "$fails"; exit 1; fi
printf 'OK: codex_review -- %d tests clean.\n' "$total"
