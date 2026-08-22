#!/bin/sh
# Unit tests for pr_gate_status.sh's _gate verdict reader. Offline: the fixtures
# are review bodies, so no `gh` call is made.
#
# The regression that motivated this file: on PR #2417 the *structural* review
# carried a "### Notes for Behavioral QC" section. The matcher looked for the
# gate word anywhere in a heading, so that review's APPROVED was read as the
# behavioral verdict as well, and the PR printed `pass / ok / ok  MERGE` while
# qc-behavioral had never been dispatched. On an autonomous merge path that is a
# PR merged with one gate silently unrun.
set -eu

HERE=$(dirname "$0")
PR_GATE_STATUS_LIB=1
export PR_GATE_STATUS_LIB
# shellcheck source=/dev/null
. "$HERE/pr_gate_status.sh"

TIP=7dc57cc06aa1b2c3d4e5f60718293a4b5c6d7e8f
fails=0
# Total assertion count, derived from an actual counter rather than a literal
# in the closing printf (F3, qc-behavioral rework iteration 2, review
# 4991759359) -- a hardcoded number at the bottom of the file drifts silently
# every time a case is added or removed, since nothing forces the two to stay
# in sync. Both `check` and `check_backend_fails` (the only two assertion
# entry points in this file) increment it.
total=0

check() {
  _name=$1; _want=$2; _got=$3
  total=$((total + 1))
  if [ "$_got" = "$_want" ]; then
    printf 'ok   %s\n' "$_name"
  else
    printf 'FAIL %s: want %s, got %s\n' "$_name" "$_want" "$_got"
    fails=$((fails + 1))
  fi
}

# One review body per fixture, wrapped as the [{body}] shape _gate expects.
reviews() { jq -nc --arg b "$1" '[{body: $b}]'; }

STRUCT_WITH_BEHAV_SECTION="Reviewed SHA: 7dc57cc06

## Structural QC — base-broken-2026-08-19

### File Scope
Nothing leaked.

### Notes for Behavioral QC
Recompute the cohort totals from joined.tsv.

## Verdict

APPROVED"

REAL_BEHAVIORAL="Reviewed SHA: 7dc57cc06

## Behavioral QC — base-broken (PR #2417)

qc-structural already returned APPROVED at this tip.

## Verdict

APPROVED"

QC_PREFIXED_HEADING="Reviewed SHA: 7dc57cc06

## qc-behavioral verdict

## Verdict

NEEDS_REWORK"

STALE_BEHAVIORAL="Reviewed SHA: deadbeef

## Behavioral QC — an earlier tip

## Verdict

APPROVED"

# 1. THE REGRESSION. A structural review that merely *mentions* the other gate in
#    a section heading must not supply that gate's verdict.
check "notes-for-behavioral does not satisfy the behavioral gate" \
  none "$(_gate "$(reviews "$STRUCT_WITH_BEHAV_SECTION")" behavioral "$TIP")"

# 2. ...while still counting as the structural verdict it actually is.
check "same review still satisfies the structural gate" \
  ok "$(_gate "$(reviews "$STRUCT_WITH_BEHAV_SECTION")" structural "$TIP")"

# 3. A real behavioral review is matched on its own heading, even though its body
#    quotes the structural gate's approval.
check "real behavioral review is matched" \
  ok "$(_gate "$(reviews "$REAL_BEHAVIORAL")" behavioral "$TIP")"

# 4. ...and does not leak into the structural gate.
check "real behavioral review does not satisfy structural" \
  none "$(_gate "$(reviews "$REAL_BEHAVIORAL")" structural "$TIP")"

# 5. The "qc-<kind>" heading spelling is accepted, and NEEDS_REWORK reads through.
check "qc-prefixed heading, rework verdict" \
  rework "$(_gate "$(reviews "$QC_PREFIXED_HEADING")" behavioral "$TIP")"

# 6. A verdict pinned to an older SHA is stale, never ok.
check "verdict at a superseded sha is stale" \
  "stale(deadbeef)" "$(_gate "$(reviews "$STALE_BEHAVIORAL")" behavioral "$TIP")"

# 7. No reviews at all.
check "no reviews" none "$(_gate '[]' behavioral "$TIP")"

# --- Cases 8-11 exist because qc-behavioral mutation-tested cases 1-7 and found
# --- two guards the function documents but nothing pinned. Each of these fails
# --- against the corresponding mutation.

# 8. GUARD: verdict comes from the "## Verdict" SECTION, not the first
#    APPROVED/NEEDS_REWORK token. Reviews quote each other constantly, so a
#    first-token reader returns `ok` for a review that says rework -- which is
#    `pass:ok:ok MERGE` on a PR that was told to rework.
QUOTES_APPROVED_BUT_REWORKS="Reviewed SHA: 7dc57cc06

## Behavioral QC — quoting the other gate

qc-structural already returned APPROVED at this tip, and the earlier behavioral
pass was also APPROVED before the rework.

## Verdict

NEEDS_REWORK"

check "verdict section wins over quoted APPROVED tokens" \
  rework "$(_gate "$(reviews "$QUOTES_APPROVED_BUT_REWORKS")" behavioral "$TIP")"

# 9. GUARD: the LAST matching review wins. A rework cycle leaves the superseded
#    verdict earlier in the array; reading the first re-greens a reworked PR.
TWO_AT_SAME_TIP=$(jq -nc --arg a "Reviewed SHA: 7dc57cc06

## Behavioral QC — first pass

## Verdict

APPROVED" --arg b "Reviewed SHA: 7dc57cc06

## Behavioral QC — second pass, after new evidence

## Verdict

NEEDS_REWORK" '[{body: $a}, {body: $b}]')

check "newest review wins at the same tip" \
  rework "$(_gate "$TWO_AT_SAME_TIP" behavioral "$TIP")"

# 10. GUARD: a heading QUOTED INSIDE A FENCE is evidence, not a verdict. Found
#     by a reviewer who pasted another PR's heading list into a review and
#     thereby satisfied that other gate.
STRUCT_QUOTING_A_BEHAVIORAL_HEADING="Reviewed SHA: 7dc57cc06

## Structural QC — quoting evidence

The other PR's review opens with:

\`\`\`
## Behavioral QC — some other PR
## Verdict
NEEDS_REWORK
\`\`\`

## Verdict

APPROVED"

check "fenced heading does not satisfy the quoted gate" \
  none "$(_gate "$(reviews "$STRUCT_QUOTING_A_BEHAVIORAL_HEADING")" behavioral "$TIP")"
check "...and the quoting review still counts as its own gate" \
  ok "$(_gate "$(reviews "$STRUCT_QUOTING_A_BEHAVIORAL_HEADING")" structural "$TIP")"

# 11. A body with NO verdict section must return "unclear" -- not crash the run.
#     jq's `|` binds looser than `//`, so the fallback chain used to re-apply
#     `.body` to a string, exit 5, and kill the caller mid-table under `set -eu`.
NO_VERDICT_SECTION="Reviewed SHA: 7dc57cc06

## Behavioral QC — an unfinished review

Ran out of budget before reaching a verdict."

check "missing verdict section is unclear, not a crash" \
  unclear "$(_gate "$(reviews "$NO_VERDICT_SECTION")" behavioral "$TIP")"

# --- Cases 12-14: the three leaks qc-behavioral found still open after the
# --- first rework. Each is the SAME false-green as case 10, in a notation the
# --- fence stripper or the verdict regex did not cover.

# 12. A `~~~` fence is still a fence.
TILDE_FENCED="Reviewed SHA: 7dc57cc06

## Structural QC — quoting with tildes

~~~
## Behavioral QC — some other PR
## Verdict
APPROVED
~~~

## Verdict

APPROVED"

check "tilde-fenced heading does not satisfy the quoted gate" \
  none "$(_gate "$(reviews "$TILDE_FENCED")" behavioral "$TIP")"

# 13. An indented fence is still a fence.
#     ⚠ The quoted heading is FLUSH LEFT while the fence markers are indented.
#     The first version of this fixture indented the heading too, which made it
#     pass on pre-fix code (the heading regex needs `^#`, so an indented heading
#     never matched in the first place) — a vacuous test that looked green for
#     the wrong reason. Found by qc-behavioral on #2420.
INDENTED_FENCE="Reviewed SHA: 7dc57cc06

## Structural QC — quoting inside a list item

    \`\`\`
## Behavioral QC — some other PR
    \`\`\`

## Verdict

APPROVED"

check "indented-fence heading does not satisfy the quoted gate" \
  none "$(_gate "$(reviews "$INDENTED_FENCE")" behavioral "$TIP")"

# 14. An INDENTED verdict heading is a quotation, not this review's verdict.
#     No fence at all here -- four spaces is how a quoted block often arrives.
INDENTED_VERDICT="Reviewed SHA: 7dc57cc06

## Behavioral QC — quoting the prior verdict inline

The prior review ended:

    ## Verdict

    APPROVED

## Verdict

NEEDS_REWORK"

check "indented Verdict heading does not supply the verdict" \
  rework "$(_gate "$(reviews "$INDENTED_VERDICT")" behavioral "$TIP")"

# 15. THE SUITE IS OFFLINE. Sourcing the script must not invoke `gh` -- the
#     library guard has to sit above every side effect, not merely above the
#     main loop. It did not, so `gh pr list` ran at source time: harmless on a
#     laptop with `gh` on PATH, exit 127 in CI. Re-source with a PATH that has
#     no `gh` and confirm the functions still load.
#     Pinned with a `gh` STUB that leaves a marker file: shadowing `gh` on PATH
#     proves a call did not happen, rather than merely that it would fail.
offline_probe() {
  _dir=$(mktemp -d)
  printf '#!/bin/sh\ntouch "%s/called"\n' "$_dir" > "$_dir/gh"
  chmod +x "$_dir/gh"
  PATH="$_dir:$PATH" PR_GATE_STATUS_LIB=1 sh -c '. "$1"' _ "$HERE/pr_gate_status.sh" >/dev/null 2>&1
  if [ -e "$_dir/called" ]; then printf 'gh-was-called'; else printf 'offline'; fi
  rm -rf "$_dir"
}
check "sourcing makes no gh call" offline "$(offline_probe)"

# 17. OVER-STRIPPING MUST NOT GO GREEN, in THIS shape. A lone `~~~` opens a
#     fence that never closes, so the stripper eats the rest of the body
#     including this review's own "## Verdict". An earlier version of this
#     matcher had an inline `Verdict:` fallback that, in this exact shape,
#     matched a QUOTED foreign verdict and returned `ok` -- the exact false
#     green the fence work exists to prevent, reached by being too eager
#     rather than too lax. That fallback is now deleted outright (not merely
#     anchored -- anchoring it to `^` only moved the hole to column 0, see
#     case 18 below), so with "## Verdict" as the sole verdict source, THIS
#     fixture's quotation (inline "Verdict:" prose, no heading) never matches
#     at all, the real heading is erased by the unclosed fence, and the result
#     is "unclear". That is NOT a general fail-safety property of
#     over-stripping, only of this shape: when the quotation before the
#     unpaired fence IS itself a "## Verdict" heading, it survives as the sole
#     match and wins outright -- see case 26 (probe p8), a known, pre-existing
#     false green in that shape, not fixed by this suite.
OVERSTRIP_WITH_QUOTED_VERDICT="Reviewed SHA: 7dc57cc06

## Behavioral QC — over-stripped by a stray separator

The prior pass ended with Verdict: APPROVED, which I disagree with.

~~~

## Verdict

NEEDS_REWORK"

check "over-stripping never yields ok" \
  unclear "$(_gate "$(reviews "$OVERSTRIP_WITH_QUOTED_VERDICT")" behavioral "$TIP")"

# 18. The shape case 17 MISSED. Case 17 embeds its quoted verdict mid-sentence,
#     so anchoring the inline fallback to `^` appeared to fix it — while a
#     quotation pasted FLUSH LEFT, which is how quotations normally arrive,
#     still matched at column 0. That was a regression against the pre-fence
#     code (rework -> ok), not a leftover residual: the anchor moved the hole
#     rather than closing it. The inline fallback is now deleted outright, and
#     this fixture is the one that forced it. Found by qc-behavioral on #2420.
OVERSTRIP_FLUSH_LEFT_QUOTE="Reviewed SHA: 7dc57cc06

## Behavioral QC — quoting the other gate at column zero

The structural pass signed off with:

Verdict: APPROVED

~~~

## Verdict

NEEDS_REWORK"

check "flush-left quoted verdict + unpaired fence never yields ok" \
  unclear "$(_gate "$(reviews "$OVERSTRIP_FLUSH_LEFT_QUOTE")" behavioral "$TIP")"

# 19. ...and with the stray separator removed, the same body reads its OWN
#     verdict correctly. Isolates the mechanism: it is the over-strip that
#     hides the real heading, not the quotation itself.
FLUSH_LEFT_QUOTE_NO_FENCE="Reviewed SHA: 7dc57cc06

## Behavioral QC — quoting the other gate at column zero

The structural pass signed off with:

Verdict: APPROVED

## Verdict

NEEDS_REWORK"

check "same body without the stray fence reads its own verdict" \
  rework "$(_gate "$(reviews "$FLUSH_LEFT_QUOTE_NO_FENCE")" behavioral "$TIP")"

# 20. #2421 / #2425. A review that quotes ANOTHER gate's "## Verdict" heading
#     flush left -- no fence, no indent needed at all -- puts a second,
#     disagreeing "## Verdict" heading into the body. #2421 originally fixed
#     this case by taking the LAST match, which returned "rework" here -- but
#     that policy is exactly as unsound as the first-match bug it replaced:
#     "last" only wins when the leaked heading happens to sit ABOVE the real
#     one. Cases 23/24 below are the mirror shape (leak AFTER the real
#     verdict) and show last-match producing a false "ok" there. #2425
#     replaced "pick a position" with "disagreeing matches -> unclear": still
#     never a false green, and it no longer matters which side the quotation
#     leaked to.
QUOTES_A_VERDICT_HEADING_FLUSH_LEFT="Reviewed SHA: 7dc57cc06

## Behavioral QC — my review

The structural pass ended:

## Verdict

APPROVED

## Verdict

NEEDS_REWORK"

check "quoted flush-left Verdict heading disagreeing with the real one reads unclear (#2421/#2425)" \
  unclear "$(_gate "$(reviews "$QUOTES_A_VERDICT_HEADING_FLUSH_LEFT")" behavioral "$TIP")"

# 21. Symmetric case to #20: a review states its OWN verdict first, then
#     appends an addendum quoting a DIFFERENT verdict below it. Under #2421's
#     last-match policy this was a known, accepted gap -- the addendum's
#     quotation won outright, reading "ok" for a review that actually said
#     NEEDS_REWORK. #2425's disagreeing-matches-are-unclear rule resolves it:
#     two distinct verdict tokens in the body -> "unclear", not a guess. Still
#     not the review's true verdict, but no longer a false green, so this is
#     now a real assertion rather than a printed note (the note form let a
#     mutation flip the printed word from ok to rework with the suite still
#     exiting 0 -- exactly the coverage-in-appearance defect #2390/#2424 exist
#     to close).
ADDENDUM_QUOTES_A_DIFFERENT_VERDICT_AFTER="Reviewed SHA: 7dc57cc06

## Behavioral QC — my review

## Verdict

NEEDS_REWORK

Addendum: for context, the prior structural pass ended:

## Verdict

APPROVED"

check "addendum quoting a different verdict after the real one reads unclear, not the addendum's token (#2425)" \
  unclear "$(_gate "$(reviews "$ADDENDUM_QUOTES_A_DIFFERENT_VERDICT_AFTER")" behavioral "$TIP")"

# 23. #2425 regression probe (review finding A1/p1): a verdict quoted inside an
#     HTML comment -- not a fence, so strip_fences never touches it -- placed
#     AFTER the real "## Verdict" section. Under #2421's last-match policy this
#     read "ok" on a review that said NEEDS_REWORK: a false green, and a
#     regression against pre-#2421 main (which read this correctly via
#     first-match, since the leak sat below the real verdict). Confirmed red
#     against the unfixed tip (ef758806) before this fix: reads "ok" there.
HTML_COMMENT_VERDICT_AFTER="Reviewed SHA: 7dc57cc06

## Behavioral QC — my review

## Verdict

NEEDS_REWORK

<!--
## Verdict

APPROVED
-->"

check "verdict quoted inside an HTML comment after the real one does not win (#2425)" \
  unclear "$(_gate "$(reviews "$HTML_COMMENT_VERDICT_AFTER")" behavioral "$TIP")"

# 24. #2425 regression probe (review finding A1/p3b/n3/n4): strip_fences is a
#     parity toggle, not a fence stack (see its doc comment). In a nested fence
#     -- an outer 4-backtick block containing an inner 3-backtick block -- the
#     inner-open flips `.inside` back to false, so content between the
#     inner-open and inner-close is treated as unfenced and leaks into $clean.
#     Placed AFTER the real "## Verdict" section, this was another false "ok"
#     under last-match. Confirmed red against the unfixed tip before this fix.
NESTED_FENCE_INNER_LEAK_AFTER="Reviewed SHA: 7dc57cc06

## Behavioral QC — my review

## Verdict

NEEDS_REWORK

Quoting for context:

\`\`\`\`
some intro
\`\`\`
## Verdict

APPROVED
\`\`\`
some outro
\`\`\`\`"

check "verdict leaked from a nested fence's inner block, after the real one, does not win (#2425)" \
  unclear "$(_gate "$(reviews "$NESTED_FENCE_INNER_LEAK_AFTER")" behavioral "$TIP")"

# 25. Companion to case 24, correcting the PR body / status-doc claim that the
#     nested-fence residual sits "between the outer-open and inner-open"
#     (review finding CP2-a). It does not: a heading placed there is still
#     inside the outer fence at that point (`.inside` has been flipped true by
#     the outer-open and not yet flipped back by the inner-open), so it is
#     correctly stripped either way. Pinned so the wrong description does not
#     resurface as a "residual" that needs fixing.
NESTED_FENCE_BETWEEN_OUTER_AND_INNER_OPEN="Reviewed SHA: 7dc57cc06

## Behavioral QC — my review

## Verdict

NEEDS_REWORK

Quoting for context:

\`\`\`\`
## Verdict

APPROVED
\`\`\`
some inner fence content
\`\`\`
\`\`\`\`"

check "heading between a nested fence's outer-open and inner-open does not leak (CP2-a correction)" \
  rework "$(_gate "$(reviews "$NESTED_FENCE_BETWEEN_OUTER_AND_INNER_OPEN")" behavioral "$TIP")"

# 26. #2425 review probe p8, KNOWN PRE-EXISTING false green -- NOT introduced or
#     fixed by this PR, pinned so it is not silently rediscovered as new. An
#     unpaired fence (opens, never closes) puts strip_fences into "inside" for
#     the rest of the body, which erases the review's OWN "## Verdict" section.
#     What survives is only the QUOTED heading that sits BEFORE the unpaired
#     fence -- a single match, so the disagreeing-matches guard (case 20/21/
#     23/24) has nothing to disagree with, and that quoted "APPROVED" wins
#     outright. Distinct from case 17 (quotation is inline "Verdict:" text, not
#     a heading, so it never matches at all -> "unclear") and case 18 (same,
#     flush left) -- here the quotation IS a real "## Verdict" heading, which
#     is what lets it win. See the CP4-ii-scoped comment on case 17 below.
OVERSTRIP_HEADING_BEFORE_UNPAIRED_FENCE="Reviewed SHA: 7dc57cc06

## Behavioral QC — my review

The prior pass ended:

## Verdict

APPROVED

~~~

## Verdict

NEEDS_REWORK"

check "quoted Verdict heading before an unpaired fence still wins -- known pre-existing gap, not fixed here (#2425)" \
  ok "$(_gate "$(reviews "$OVERSTRIP_HEADING_BEFORE_UNPAIRED_FENCE")" behavioral "$TIP")"

# 27. CRLF line endings. A pasted-in review body can carry \r\n rather than
#     plain \n; the gap between the "## Verdict" heading and its token used to
#     be matched by a class with no \r in it, so the trailing \r broke the
#     match entirely and the gate read "unclear" instead of the real verdict.
#     Built with printf (not a shell here-doc) so the \r bytes are real, not a
#     literal backslash-r.
CRLF_BODY=$(printf 'Reviewed SHA: 7dc57cc06\r\n\r\n## Behavioral QC crlf review\r\n\r\n## Verdict\r\n\r\nNEEDS_REWORK\r\n')
check "CRLF body still reads its own verdict" \
  rework "$(_gate "$(reviews "$CRLF_BODY")" behavioral "$TIP")"

# --- #2432 defect 1: inter-review disagreement ACROSS MULTIPLE REVIEWS -----
# All of cases 8-27 above are disagreement WITHIN one review body. `_gate`
# used to pick the LAST matching review outright and trust its verdict alone;
# these pin the fix -- aggregate every CURRENT-tip review for the gate and
# never silently read "ok" through an unresolved NEEDS_REWORK from an earlier
# one at the same sha.

# 28. THE #2423 SHAPE: an earlier NEEDS_REWORK, then a LATER APPROVED from an
#     unrelated second QC pass that never saw the finding -- same sha, so
#     nothing here is "stale". The old last-review-wins reader read this "ok"
#     and PR #2423 merged past an unresolved finding. Must now read "unclear",
#     never "ok".
BLIND_REWORK_THEN_APPROVED=$(jq -nc --arg a "Reviewed SHA: $TIP

## Behavioral QC — first pass

## Verdict

NEEDS_REWORK" --arg b "Reviewed SHA: $TIP

## Behavioral QC — second, unrelated pass

## Verdict

APPROVED" '[{body: $a}, {body: $b}]')

check "#2423 shape: blind APPROVED after NEEDS_REWORK at the same sha is unclear, not ok" \
  unclear "$(_gate "$BLIND_REWORK_THEN_APPROVED" behavioral "$TIP")"

# 29. THE #2452 SHAPE: same sequence of tokens, but the later review EXPLICITLY
#     cites the prior review by id and re-verifies its finding -- a genuinely
#     resolved body-only fix (PR #2452, the same morning #2423 was found). A
#     design that special-cased "the later review mentions the earlier one" to
#     auto-clear would still not be reliably text-matchable (see the reasoning
#     in _gate's own MULTI-REVIEW AGGREGATION comment) -- so this ALSO reads
#     "unclear", by design: the script surfaces ADJUDICATE rather than
#     guessing either way. A human reading both bodies resolves it in about
#     two minutes, same as happened for #2452 itself.
RESOLVED_REWORK_THEN_APPROVED=$(jq -nc --arg a "Reviewed SHA: $TIP

## Behavioral QC — my review (id 4990775807)

## Verdict

NEEDS_REWORK

Finding CP2: claim X is not pinned by a test." --arg b "Reviewed SHA: $TIP

## Behavioral QC — re-review

Re-reviewing my own prior pass (id 4990775807): re-verified claim X field by
field against source; CP2 is now cured by a PR-body-only edit, no tip move
required.

## Verdict

APPROVED" '[{body: $a}, {body: $b}]')

check "#2452 shape: even a self-citing, re-verified APPROVED after NEEDS_REWORK reads unclear (adjudicate, not auto-clear)" \
  unclear "$(_gate "$RESOLVED_REWORK_THEN_APPROVED" behavioral "$TIP")"

# 30. Acceptance case (c): a single clean APPROVED at the tip is unaffected --
#     the overwhelmingly common case must still read straight through as "ok".
CLEAN_SINGLE_APPROVED=$(jq -nc --arg a "Reviewed SHA: $TIP

## Behavioral QC — only pass

## Verdict

APPROVED" '[{body: $a}]')

check "acceptance (c): single clean APPROVED at the tip still reads ok" \
  ok "$(_gate "$CLEAN_SINGLE_APPROVED" behavioral "$TIP")"

# --- #2432 defect 2: gh absent must fail loudly, never print an empty table -
# `_detect_backend` picks gh (if present), else curl+$GH_TOKEN, else nothing.
# Probed with PATH narrowed to a directory that intentionally does or does not
# contain a stub gh/curl -- `command -v` is a shell builtin, so this needs no
# network and does not depend on whether the host actually has gh/curl
# installed.

_detect_backend_probe() {
  # $1 = PATH to use for the probe (a stub dir, or an empty dir)
  # $2 = GH_TOKEN value to use ("" means unset)
  _p=$1; _t=$2
  (
    PATH=$_p
    if [ -n "$_t" ]; then GH_TOKEN=$_t; export GH_TOKEN; else unset GH_TOKEN; fi
    _detect_backend
  )
}

# Fails the check unless _detect_backend itself returns non-zero (no backend
# available) -- a plain string `check` can't express "must fail", hence this
# separate helper.
check_backend_fails() {
  _name=$1; _p=$2; _t=$3
  total=$((total + 1))
  if _detect_backend_probe "$_p" "$_t" >/tmp/pr_gate_backend_out 2>/dev/null; then
    printf 'FAIL %s: want detection failure, got backend=%s\n' \
      "$_name" "$(cat /tmp/pr_gate_backend_out)"
    fails=$((fails + 1))
  else
    printf 'ok   %s\n' "$_name"
  fi
  rm -f /tmp/pr_gate_backend_out
}

GH_STUB_DIR=$(mktemp -d)
printf '#!/bin/sh\ntrue\n' > "$GH_STUB_DIR/gh"
chmod +x "$GH_STUB_DIR/gh"

CURL_STUB_DIR=$(mktemp -d)
printf '#!/bin/sh\ntrue\n' > "$CURL_STUB_DIR/curl"
chmod +x "$CURL_STUB_DIR/curl"

EMPTY_DIR=$(mktemp -d)

check "backend: gh on PATH is preferred" \
  gh "$(_detect_backend_probe "$GH_STUB_DIR" "")"

check "backend: gh absent, curl + GH_TOKEN present -> curl fallback" \
  curl "$(_detect_backend_probe "$CURL_STUB_DIR" "dummy-token")"

check_backend_fails \
  "backend: curl present but GH_TOKEN unset -> no backend (must not silently pick curl)" \
  "$CURL_STUB_DIR" ""

check_backend_fails \
  "backend: neither gh nor curl on PATH -> no backend" \
  "$EMPTY_DIR" ""

rm -rf "$GH_STUB_DIR" "$CURL_STUB_DIR" "$EMPTY_DIR"

# --- END-TO-END probes: the REAL script, not just _gate/_detect_backend ----
# Same fixtures as above, run through the actual entry point (PR_GATE_STATUS_LIB
# unset) with PATH/env fully controlled and no network, so the NEXT-ACTION
# column and the loud-failure behavior are proven exactly as the orchestrator
# experiences them, not just at the library-function level.

SH_BIN=$(command -v sh)
REAL_BIN_PATH=/usr/bin:/bin

_e2e_probe() {
  # $1 = extra PATH dir to prepend (stub binaries), $2 = GH_TOKEN ("" = unset),
  # remaining args = argv for pr_gate_status.sh.
  _extra=$1; _t=$2; shift 2
  (
    PATH="$_extra:$REAL_BIN_PATH"
    if [ -n "$_t" ]; then GH_TOKEN=$_t; export GH_TOKEN; else unset GH_TOKEN; fi
    unset PR_GATE_STATUS_LIB PR_GATE_STATUS_BACKEND
    "$SH_BIN" "$HERE/pr_gate_status.sh" "$@"
  )
}

# 31. Defect 2, END TO END: neither gh nor curl+token available -> the real
#     script must exit non-zero with a clear, actionable stderr message, and
#     must NEVER print the table header. The OLD code did not fail this
#     cleanly either way: with no args it died mid-assignment on `gh pr list`
#     (raw `gh: not found`, exit 127, no header -- already non-zero, but no
#     diagnosis and no remediation); with explicit PR numbers it printed the
#     header FIRST and only then crashed on the first `gh pr view` -- a
#     misleading partial table. `_e2e_probe` here is called with an explicit
#     PR number (99) specifically to probe the WORSE of those two old shapes;
#     the fixed script must refuse before printing anything in either case.
#     `if ... ; then ... else e2e_rc=$? ; fi` (not a bare `x=$(...)`) because a
#     bare failing command substitution under `set -eu` would abort THIS test
#     script too -- exactly the trap documented above for the script under
#     test, so the test harness has to dodge it deliberately.
E2E_EMPTY_DIR=$(mktemp -d)
if e2e_out=$(_e2e_probe "$E2E_EMPTY_DIR" "" 99 2>&1); then
  e2e_rc=0
else
  e2e_rc=$?
fi
case "$e2e_out" in
  *"cannot read GitHub PR state"*) msg_ok=yes ;;
  *)                               msg_ok=no ;;
esac
case "$e2e_out" in
  *NEXT-ACTION*) header_leaked=yes ;;
  *)             header_leaked=no ;;
esac
check "defect 2 e2e: gh+curl both unavailable exits non-zero" \
  nonzero "$( [ "$e2e_rc" -ne 0 ] && echo nonzero || echo zero )"
check "defect 2 e2e: ... with the loud stderr message" yes "$msg_ok"
check "defect 2 e2e: ... and never prints the table header (no false-clean empty table)" \
  no "$header_leaked"
rm -rf "$E2E_EMPTY_DIR"

# Stub `gh`, driven entirely by env vars set per-test (GATE_PR_NUMBER /
# GATE_TIP / GATE_REVIEWS_JSON / GATE_FILES / GATE_CHECKS) instead of the
# network -- lets the same fixtures used against `_gate` above run through the
# full script, including the CI-check summarizing and the NEXT-ACTION mapping.
GH_E2E_STUB_DIR=$(mktemp -d)
cat > "$GH_E2E_STUB_DIR/gh" <<'STUB'
#!/bin/sh
case "$1 $2" in
  "pr list")
    printf '%s\n' "$GATE_PR_NUMBER"
    ;;
  "pr view")
    jq -n --arg tip "$GATE_TIP" --argjson reviews "$GATE_REVIEWS_JSON" --arg files "$GATE_FILES" \
      --argjson labels "${GATE_LABELS_JSON:-[]}" \
      '{headRefOid: $tip,
        files: ($files | split("\n") | map(select(length > 0) | {path: .})),
        reviews: $reviews,
        labels: $labels}'
    ;;
  "pr checks")
    printf '%s\n' "$GATE_CHECKS" | awk 'NF{print "check-name\t" $0 "\tlink"}'
    ;;
esac
STUB
chmod +x "$GH_E2E_STUB_DIR/gh"

GATE_PR_NUMBER=501
GATE_TIP=$TIP
GATE_FILES="trading/foo/bar.ml"
GATE_CHECKS="pass"
# Default: no labels. Case B1 below overrides this to a do-not-merge label to
# pin the HARD-hold path through both backends' curl/gh reshape.
GATE_LABELS_JSON='[]'
export GATE_PR_NUMBER GATE_TIP GATE_FILES GATE_CHECKS GATE_LABELS_JSON

# 32. Defect 1, END TO END (gh backend): the #2423 shape must never reach
#     MERGE -- NEXT-ACTION reads ADJUDICATE.
GATE_REVIEWS_JSON=$BLIND_REWORK_THEN_APPROVED
export GATE_REVIEWS_JSON
row=$(_e2e_probe "$GH_E2E_STUB_DIR" "" 501 | tail -1)
case "$row" in
  *ADJUDICATE*) got=ADJUDICATE ;;
  *MERGE*)      got=MERGE ;;
  *)            got=other ;;
esac
check "defect 1 e2e (gh backend): #2423 shape never reaches MERGE" ADJUDICATE "$got"

# 33. Acceptance case (c), END TO END (gh backend): a clean single APPROVED
#     (both gates) with passing CI still reaches MERGE.
GATE_REVIEWS_JSON=$(jq -nc --arg s "Reviewed SHA: $TIP

## Structural QC — clean pass

## Verdict

APPROVED" --arg b "Reviewed SHA: $TIP

## Behavioral QC — clean pass

## Verdict

APPROVED" '[{body: $s}, {body: $b}]')
export GATE_REVIEWS_JSON
row=$(_e2e_probe "$GH_E2E_STUB_DIR" "" 501 | tail -1)
case "$row" in
  *MERGE*) got=MERGE ;;
  *)       got=other ;;
esac
check "acceptance (c) e2e (gh backend): clean approvals + passing CI reach MERGE" MERGE "$got"

# 35. B1 (qc-behavioral rework iteration 1, review 4991549803): the do-not-merge
#     HARD hold (`.claude/rules/pr-merge-gates.md` Rule 0 -- the guard whose
#     absence let #2384 merge 30 min after being drafted, a -40.91pp regression,
#     #2396) is the one curl-reshape field the 39-case suite never touched: both
#     e2e stubs hardcoded `labels: []`, so not one assertion exercised a
#     non-empty label list on either backend. This is otherwise the SAME clean
#     pass:ok:ok reviews as case 33 -- only the label changes -- so a HOLD here
#     that was a MERGE before pins the label is actually load-bearing in the
#     gh-backend reshape, not just present in the response shape.
GATE_LABELS_JSON='[{"name": "do-not-merge"}]'
export GATE_LABELS_JSON
row=$(_e2e_probe "$GH_E2E_STUB_DIR" "" 501 | tail -1)
case "$row" in
  *"HOLD -- do-not-merge label"*) got=HOLD ;;
  *MERGE*)                        got=MERGE ;;
  *)                              got=other ;;
esac
check "B1 e2e (gh backend): do-not-merge label HOLDs a pass/ok/ok PR, never MERGE" HOLD "$got"
GATE_LABELS_JSON='[]'
export GATE_LABELS_JSON

rm -rf "$GH_E2E_STUB_DIR"

# 34. Defect 2's NICE-TO-HAVE, END TO END (curl backend): with `gh` absent
#     entirely, the curl+$GH_TOKEN REST fallback must be able to drive the
#     whole script to the same clean MERGE result -- not just fail loudly.
#     Stub `curl` inspects the request URL (the last https:// argument) and
#     returns canned JSON per REST endpoint instead of hitting the network.
CURL_E2E_STUB_DIR=$(mktemp -d)
cat > "$CURL_E2E_STUB_DIR/curl" <<'STUB'
#!/bin/sh
url=""
for a in "$@"; do
  case "$a" in
    https://*) url=$a ;;
  esac
done
case "$url" in
  */pulls\?state=open*)
    jq -n --arg n "$GATE_PR_NUMBER" '[{number: ($n | tonumber)}]'
    ;;
  */pulls/*/files*)
    printf '%s\n' "$GATE_FILES" | jq -R -s 'split("\n") | map(select(length > 0) | {filename: .})'
    ;;
  */pulls/*/reviews*)
    printf '%s\n' "$GATE_REVIEWS_JSON"
    ;;
  */commits/*/check-runs*)
    printf '%s\n' "$GATE_CHECKS" | jq -R -s '
      split("\n") | map(select(length > 0)) | map(
        if . == "pending" then {status: "queued", conclusion: null}
        elif . == "pass" then {status: "completed", conclusion: "success"}
        else {status: "completed", conclusion: "failure"} end)
      | {check_runs: .}'
    ;;
  */pulls/*)
    jq -n --arg tip "$GATE_TIP" --argjson labels "${GATE_LABELS_JSON:-[]}" \
      '{head: {sha: $tip}, labels: $labels}'
    ;;
esac
STUB
chmod +x "$CURL_E2E_STUB_DIR/curl"

row=$(_e2e_probe "$CURL_E2E_STUB_DIR" "dummy-token" 501 | tail -1)
case "$row" in
  *MERGE*) got=MERGE ;;
  *)       got=other ;;
esac
check "defect 2 nice-to-have e2e (curl backend): clean approvals + passing CI reach MERGE with no gh at all" \
  MERGE "$got"

# 36. B1, curl backend counterpart to case 35: the do-not-merge label must
#     survive the REST reshape (`_pr_meta_curl`'s `$pr.labels | map({name: .name})`)
#     exactly as it does through `gh --json labels`, on the SAME clean
#     pass:ok:ok reviews as case 34.
GATE_LABELS_JSON='[{"name": "do-not-merge"}]'
export GATE_LABELS_JSON
row=$(_e2e_probe "$CURL_E2E_STUB_DIR" "dummy-token" 501 | tail -1)
case "$row" in
  *"HOLD -- do-not-merge label"*) got=HOLD ;;
  *MERGE*)                        got=MERGE ;;
  *)                              got=other ;;
esac
check "B1 e2e (curl backend): do-not-merge label HOLDs a pass/ok/ok PR, never MERGE" HOLD "$got"
GATE_LABELS_JSON='[]'
export GATE_LABELS_JSON

rm -rf "$CURL_E2E_STUB_DIR"

# --- B2 (qc-behavioral rework iteration 1, review 4991549803): a review with no
# parseable "Reviewed SHA" is not merely "harmless because a later review
# supersedes it" (the docstring's claim, corrected above in _gate) -- it is
# treated as current AT EVERY TIP, FOREVER, which the single-review reader this
# replaces never had to reckon with (there was no "every tip" -- only ever the
# last review). Two fixtures: the mechanism in isolation, then the live shape
# (PR #2397 carries a 7-char "Reviewed SHA", one character short of the
# `{8,40}` capture bound, so it parses as no sha at all).

# 37. A sha-less review's "current" status does not depend on the tip: the SAME
#     review, with the SAME single verdict, reads identically against two
#     tips that share no prefix in either direction -- proving it is not being
#     matched against $tip at all, unlike every sha-bearing fixture above
#     (case 6's STALE_BEHAVIORAL is the direct contrast: a real sha pins a
#     verdict to the tip it was written for, and going stale is the point).
NO_SHA_AT_ALL="## Behavioral QC — no Reviewed SHA field in this body at all

## Verdict

NEEDS_REWORK"

check "sha-less review reads rework at tip A" \
  rework "$(_gate "$(reviews "$NO_SHA_AT_ALL")" behavioral aaaaaaaa1111)"
check "...and STILL reads rework at an unrelated tip B (never goes stale)" \
  rework "$(_gate "$(reviews "$NO_SHA_AT_ALL")" behavioral bbbbbbbb2222)"

# 38. THE LIVE SHAPE: PR #2397 carries "Reviewed SHA: 9346b3b" -- 7 hex
#     characters -- on two gate-matching reviews. Under the ORIGINAL `{8,40}`
#     bound this was one character short, so both parsed as sha-less and,
#     under aggregation, were "current" at any tip forever; a real, later,
#     current-tip APPROVED could never clear the disagreement, and the gate
#     read `unclear` permanently. That was a PARSE ARTIFACT, not a genuine
#     rework-loop shape or a #2423-style blind supersede (qc-behavioral rework
#     iteration 2, review 4991759359, F1/F2) -- #2397's real tip DID move
#     (9346b3b -> de734f2d1960), exactly as the process intends.
#
#     FIXED (F2): the bound is now `{7,40}`, so these two reviews parse a
#     real 7-char sha and are matched against the tip like any other review.
#     The two assertions below USED TO pin the buggy `unclear` result; they
#     are retargeted here to pin the CORRECT, fixed behaviour instead. This is
#     not a weakened test -- it is the same fixture, characterising the
#     defect before the fix and the fix's actual effect after it, so a future
#     reader does not mistake the change in expected value for a regression.
SHORT_SHA_REWORK_THEN_APPROVED=$(jq -nc --arg a "Reviewed SHA: 9346b3b

## Behavioral QC — first pass (short sha)

## Verdict

NEEDS_REWORK" --arg b "Reviewed SHA: 9346b3b

## Behavioral QC — second pass (short sha)

## Verdict

APPROVED" '[{body: $a}, {body: $b}]')

check "PR #2397 shape at an UNRELATED tip: both 7-char-sha reviews now parse a real (stale) sha and are excluded -- reports stale, not unclear" \
  "stale(9346b3b)" "$(_gate "$SHORT_SHA_REWORK_THEN_APPROVED" behavioral cccccccc3333)"

SHORT_SHA_PLUS_REAL_CURRENT_APPROVAL=$(jq -nc --arg a "Reviewed SHA: 9346b3b

## Behavioral QC — first pass (short sha)

## Verdict

NEEDS_REWORK" --arg b "Reviewed SHA: 9346b3b

## Behavioral QC — second pass (short sha)

## Verdict

APPROVED" --arg c "Reviewed SHA: cccccccc3333

## Behavioral QC — third pass, a REAL review at the current tip

## Verdict

APPROVED" '[{body: $a}, {body: $b}, {body: $c}]')

check "...adding a third, real, current-tip APPROVED now clears it cleanly: the two short-sha reviews go stale and only the current one counts -- ok, not unclear (this is the actual #2397 fix)" \
  ok "$(_gate "$SHORT_SHA_PLUS_REAL_CURRENT_APPROVAL" behavioral cccccccc3333)"

if [ "$fails" -gt 0 ]; then
  printf 'FAIL: pr_gate_status linter -- %d test(s) failed.\n' "$fails"
  exit 1
fi
printf 'OK: pr_gate_status -- %d tests clean.\n' "$total"
