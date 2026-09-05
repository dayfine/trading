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
#
# Cases 41-42 (PR #2622 rework iteration 1, qc-behavioral review 5075369988)
# exist because #2620's fix moved gate attribution onto `first_heading_text`
# (the review's OWN first heading, fence-stripped) without a fixture landing
# alongside it that actually exercises the fence-stripping *inside that
# function specifically*. Every pre-existing fenced fixture (TILDE_FENCED,
# OVERSTRIP_*, STRUCT_QUOTING_A_BEHAVIORAL_HEADING) places its real heading
# BEFORE the fence, so `first_heading_text` returns before ever reaching the
# fence -- deleting `strip_fences` from inside `first_heading_text` (leaving
# `review_result`'s separate copy untouched) left the whole suite green while
# producing a live false-MERGE/false-BLOCK pair. Case 41
# (FENCE_BEFORE_FIRST_HEADING) puts the fence FIRST, so it is the only
# fixture that can reach that fence-strip call at all.
#
# Case 42 (FIRST_HEADING_NOT_GATE_WORD) exists because the SAME #2620 change
# left the `^`-anchor guard in the kind test (the #2417 fix, cases 1-2 above)
# without a pin: case 1's interior "### Notes for Behavioral QC" is no longer
# even consulted post-#2620 (only the first heading is), so it now passes for
# an unrelated reason and the anchor itself goes untested. Case 42 puts the
# non-anchored gate-word text in the review's FIRST heading instead, so
# dropping the `^` anchor (matching "behavioral" anywhere in the heading
# rather than only at its start) is the one and only thing that flips it.
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
# Optional $2 sets commit_id (#2626: the curl backend's REST-projected field
# that review_result falls back to when the body has no "Reviewed SHA" line) --
# omitted by every pre-existing call site, which keeps them producing the
# exact same {body: ...}-only shape as before this addition.
reviews() {
  jq -nc --arg b "$1" --arg c "${2:-}" \
    '[{body: $b} + (if $c == "" then {} else {commit_id: $c} end)]'
}

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

# 39. #2620, THE LIVE SHAPE on PR #2619: a structural review carries an
#     INTERIOR heading -- "## Behavioral equivalence verification" -- that
#     happens to START with the gate word "Behavioral". The heading-anchor
#     guard (cases 1-2 above) only checks that a matching heading starts with
#     the gate word; it says nothing about WHERE in the body that heading
#     sits, so this interior one used to satisfy the behavioral gate on its
#     own even with ZERO qc-behavioral reviews posted, and the PR printed
#     `pass / ok / ok  MERGE`. Confirmed RED against the unfixed matcher
#     (reads "ok" there) before landing `first_heading_text`. Fixed: only the
#     review's own FIRST heading is ever consulted for gate attribution.
STRUCT_WITH_INTERIOR_BEHAVIORAL_WORD_HEADING="Reviewed SHA: $TIP

## Structural QC — SC2012 burn-down (PR #2619)

### Behavioral equivalence verification

Confirmed the find-replacement preserves the ls-pattern's exclusion semantics.

## Verdict

APPROVED"

check "#2620: interior heading starting with the gate word does not satisfy the behavioral gate" \
  none "$(_gate "$(reviews "$STRUCT_WITH_INTERIOR_BEHAVIORAL_WORD_HEADING")" behavioral "$TIP")"
check "#2620: same review still satisfies its own (structural) gate" \
  ok "$(_gate "$(reviews "$STRUCT_WITH_INTERIOR_BEHAVIORAL_WORD_HEADING")" structural "$TIP")"

# 40. Happy-path guard for the #39 fix: a well-formed behavioral review, whose
#     OWN first heading names the gate, must still be matched -- proves
#     `first_heading_text` did not narrow attribution so far that a real
#     review stops counting.
WELL_FORMED_BEHAVIORAL_REVIEW="Reviewed SHA: $TIP

## qc-behavioral review — PR #2619

Reviewed the diff end to end; no findings.

## Verdict

APPROVED"

check "well-formed behavioral review (first heading names the gate) still reads ok" \
  ok "$(_gate "$(reviews "$WELL_FORMED_BEHAVIORAL_REVIEW")" behavioral "$TIP")"

# 41. #2622 rework (qc-behavioral 5075369988, CP4 finding 1): the fence comes
#     FIRST, quoting the OTHER gate's heading, and the review's OWN real
#     heading follows, unfenced. Every pre-existing fenced fixture places the
#     real heading before the fence, so none of them can reach the
#     fence-strip call inside `first_heading_text` -- this one is built
#     specifically so `first_heading_text` cannot return before it does.
#     Confirmed RED (both assertions) with `strip_fences` deleted from inside
#     `first_heading_text` only (`review_result`'s copy left intact) --
#     without the strip, the fenced "Structural QC" heading becomes the
#     unmutated body's first raw heading line, so structural wrongly reads
#     "ok" (false-MERGE) and behavioral wrongly reads "none" (false-BLOCK).
FENCE_BEFORE_FIRST_HEADING="Reviewed SHA: $TIP

\`\`\`
## Structural QC — quoted from the other review
\`\`\`

## Behavioral QC — PR #2622

## Verdict

APPROVED"

check "#2622: a heading quoted in a fence BEFORE the real first heading does not satisfy the quoted gate" \
  none "$(_gate "$(reviews "$FENCE_BEFORE_FIRST_HEADING")" structural "$TIP")"
check "#2622: ...and the real first heading after the fence still satisfies its own gate" \
  ok "$(_gate "$(reviews "$FENCE_BEFORE_FIRST_HEADING")" behavioral "$TIP")"

# 42. #2622 rework (qc-behavioral 5075369988, CP4 finding 2): the #2417
#     anchor guard (cases 1-2) lost its only pin as a side effect of #2620 --
#     case 1's interior heading is no longer consulted at all post-#2620, so
#     it now passes for a different reason and never exercises the `^`
#     anchor in the kind test. This fixture puts the gate word inside the
#     review's FIRST heading, but not at its start, so it is the anchor
#     itself -- not the interior-vs-first distinction #39/#40 already pin --
#     that decides the outcome. Confirmed RED with the `^` dropped from the
#     kind test (`^(qc[- ])?" + $kind + "\\b"` -> `(qc[- ])?" + $kind +
#     "\\b"`): the gate word then matches anywhere in the heading, so this
#     review wrongly satisfies the behavioral gate.
FIRST_HEADING_NOT_GATE_WORD="Reviewed SHA: $TIP

### Notes for Behavioral QC

Recompute the cohort totals from joined.tsv.

## Verdict

APPROVED"

check "#2622: a first heading with the gate word NOT at its start does not satisfy the gate (anchor guard)" \
  none "$(_gate "$(reviews "$FIRST_HEADING_NOT_GATE_WORD")" behavioral "$TIP")"

# 43-45. #2626: a review whose body carries no "Reviewed SHA" line at all used
# to be treated as current-at-every-tip-forever -- reachable simply by an
# agent forgetting one line of prose (observed live on PR #2625: one
# gate-matching review had no "Reviewed SHA" line and read "ok" against a tip
# a rework had already moved past). `review_result` now falls back to the
# review's `commit_id` field (the REST API always supplies it; the curl
# backend projects it into the reviews array `_gate` consumes) whenever the
# body yields no sha.
NO_SHA_LINE_STALE_COMMIT="## Behavioral QC — PR #2626, no Reviewed SHA line

Reviewed the diff end to end; no findings.

## Verdict

APPROVED"

# 43. RED/GREEN pin: with the body carrying no sha and commit_id pointing at
#     an OLD commit (not the current tip), the review must read stale, not
#     "ok forever". Reverting the commit_id fallback in review_result (so
#     $sha stays "" whenever the body has none) turns this case RED: the
#     review is then treated as always-current and reads "ok" against a tip
#     it was never posted against.
check "#2626: sha-less review body falls back to a STALE commit_id" \
  "stale(aaaaaaaa)" \
  "$(_gate "$(reviews "$NO_SHA_LINE_STALE_COMMIT" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")" behavioral "$TIP")"

# 44. Happy-path guard: the same sha-less body, but commit_id matches the
#     current tip -- the fallback must also correctly read "ok", not just
#     correctly detect staleness.
check "#2626: sha-less review body falls back to a CURRENT commit_id" \
  ok \
  "$(_gate "$(reviews "$NO_SHA_LINE_STALE_COMMIT" "$TIP")" behavioral "$TIP")"

# 45. Precedence guard: when the body DOES carry a "Reviewed SHA" line, that
#     value wins even if commit_id disagrees -- a review can still explicitly
#     declare it reviewed a different sha than the one it was posted against.
BODY_SHA_WINS_OVER_COMMIT_ID="Reviewed SHA: deadbeef

## Behavioral QC — PR #2626, body sha overrides commit_id

## Verdict

APPROVED"

check "#2626: body Reviewed SHA line takes precedence over commit_id" \
  "stale(deadbeef)" \
  "$(_gate "$(reviews "$BODY_SHA_WINS_OVER_COMMIT_ID" "$TIP")" behavioral "$TIP")"

# 46-50. H-GATEPARSER-NO-MUTATION-COVERAGE (dev/status/harness.md): three
# mutations of the kind test / heading regex survived the #2622/#2625 sweep
# unpinned -- (k) dropping `\b` from the kind test, (f) widening `#{1,4}` to
# `#{1,6}`, (g) relaxing the required `" +"` after the hashes to `" *"`. Each
# was confirmed to flip a real gate attribution by hand-applying the mutation
# and re-running this file; see the harness.md entry for the measured table.
#
# 46. (k): drop `\b` from the kind test. "Behaviorally" shares its first ten
#     letters with "behavioral" -- with the `\b` boundary guard in place
#     (post-#2622 case 42 restored the `^` anchor but not this guard), the
#     match correctly fails because a word character ('l') follows on both
#     sides of the would-be boundary. Confirmed RED (reads "ok" instead of
#     "none") with `\\b` deleted from the kind-test pattern.
HEADING_STARTS_WITH_KIND_WORD_PLUS_MORE="Reviewed SHA: $TIP

## Behaviorally equivalent refactor

## Verdict

APPROVED"

check "(k): a first heading that merely STARTS WITH the kind word (no boundary after it) does not satisfy the gate" \
  none "$(_gate "$(reviews "$HEADING_STARTS_WITH_KIND_WORD_PLUS_MORE")" behavioral "$TIP")"

# 47. (f) direction 1 -- false-MERGE: a stray six-hash line ("######") is not
#     a heading *under this parser's deliberate `#{1,4}` window* (after
#     consuming up to 4 '#', the remaining '#' characters block the required
#     run of spaces, so the line never matches) and is correctly skipped.
#     NOTE: "######" IS a valid h6 in CommonMark. The reason it does not count
#     here is this parser's own 1..4 window, NOT markdown syntax. An earlier
#     draft of this comment said "is not a markdown heading", which is false
#     and would mislead anyone reasoning about widening the window
#     (qc-behavioral, PR #2635). The next matching line is
#     "## Verdict", which does not name any gate, so structural correctly
#     reads "none". Confirmed RED (reads "ok") with `#{1,4}` widened to
#     `#{1,6}`: the six-hash line then matches as the first heading, its
#     captured text starts with "Structural", and the review's own (unrelated)
#     Verdict gets attributed to the structural gate.
SIX_HASH_LINE_READS_AS_STRUCTURAL_HEADING="Reviewed SHA: $TIP

###### Structural QC (quoted)

Some quoted text under a deep heading level, not this review's real content.

## Verdict

APPROVED"

check "(f) 1/2: a six-hash line is not a heading under #{1,4} -- does not satisfy the structural gate" \
  none "$(_gate "$(reviews "$SIX_HASH_LINE_READS_AS_STRUCTURAL_HEADING")" structural "$TIP")"

# 48. (f) direction 2 -- false-BLOCK: same defect, opposite failure mode. A
#     six-hash "scratch note" line precedes the review's real
#     "## Behavioral QC" heading; under `#{1,4}` it is skipped and the real
#     heading is used, correctly reading "ok". Confirmed RED (reads "none")
#     with `#{1,4}` widened to `#{1,6}`: the scratch-note line becomes the
#     FIRST heading (masking the real one, per `first_heading_text`'s
#     first-match-only contract from case 39/40), and "scratch note" does not
#     name the behavioral gate.
#
#     THIS CASE PINS TWO MUTATIONS, NOT ONE. It also goes RED under mutation
#     (g) (`" +"` -> `" *"`, pinned by cases 49/50): dropping the required
#     space likewise lets "###### scratch note" match and mask the real
#     heading. Do NOT delete this case as "(f)-redundant" if (f) is ever
#     re-pinned elsewhere -- doing so silently unpins (g)'s masking direction
#     too. (Mutation (f) does not reciprocally trip 49/50.) See
#     dev/status/harness.md, H-GATEPARSER-NO-MUTATION-COVERAGE.
SIX_HASH_LINE_MASKS_REAL_HEADING="Reviewed SHA: $TIP

###### scratch note

## Behavioral QC — PR #2622

## Verdict

APPROVED"

check "(f) 2/2: a six-hash line before the real heading does not mask it -- behavioral gate still reads ok" \
  ok "$(_gate "$(reviews "$SIX_HASH_LINE_MASKS_REAL_HEADING")" behavioral "$TIP")"

# 49. (g) direction 1 -- false-MERGE: "#structural notes worth reading later"
#     has a single '#' immediately followed by text, no space -- under the
#     required `" +"` this is NOT a heading (an issue-reference-style line,
#     not markdown), so it is skipped and the review's real first heading
#     ("## Behavioral QC ...") is used, correctly reading "none" for the
#     structural gate. Confirmed RED (reads "ok") with `" +"` relaxed to
#     `" *"`: the no-space line then matches, its captured text starts with
#     "structural", and it wins as the first heading over the real one.
NO_SPACE_AFTER_HASH_READS_AS_HEADING="Reviewed SHA: $TIP

#structural notes worth reading later

## Behavioral QC — PR #XXXX real heading

## Verdict

APPROVED"

check "(g) 1/2: a hash with no following space is not a heading -- does not satisfy the structural gate" \
  none "$(_gate "$(reviews "$NO_SPACE_AFTER_HASH_READS_AS_HEADING")" structural "$TIP")"

# 50. (g) direction 2 -- false-BLOCK: same defect, opposite failure mode. A
#     stray "#2622 follow-up notes" line (also no space after the single '#')
#     precedes the review's real "## Behavioral QC" heading; under `" +"` it
#     is skipped and the real heading wins, correctly reading "ok". Confirmed
#     RED (reads "none") with `" +"` relaxed to `" *"`: the stray line becomes
#     the first heading, masking the real one, and "2622 follow-up notes"
#     does not name the behavioral gate.
NO_SPACE_AFTER_HASH_MASKS_REAL_HEADING="Reviewed SHA: $TIP

#2622 follow-up notes

## Behavioral QC — PR #XXXX real heading

## Verdict

APPROVED"

check "(g) 2/2: a hash with no following space before the real heading does not mask it -- behavioral gate still reads ok" \
  ok "$(_gate "$(reviews "$NO_SPACE_AFTER_HASH_MASKS_REAL_HEADING")" behavioral "$TIP")"

# --- 51-57: H-QC-VERDICT-NEWLINE-COLLAPSE (dev/status/harness.md, PR #2663) -
# On PR #2663 a qc-structural review was posted APPROVED at the correct tip,
# but the GitHub API returned its body with EVERY newline collapsed -- one
# line reading "...all passing).## VerdictAPPROVED". Every heading regex in
# this parser requires `^` at a REAL line start, so the review failed its
# own heading-attribution test and vanished from $results entirely; the gate
# fell back to an OLDER, genuinely-parseable review and reported the
# misleading `stale(25d1a938)` -- naming the wrong review as the problem and
# telling the operator to "re-run qc-structural" when a review HAD been
# posted, it just could not be read.
#
# Fix: `looks_corrupt` flags a review whose body contains "## Verdict" as a
# loose, unanchored substring but where the real, anchored verdict regex
# never matches it (or the body is long with almost no newlines) -- the
# signature of newline collapse. When such a review sits AT THE CURRENT TIP,
# the gate reports "unreadable(<sha>)" instead of "none"/"stale(<sha>)".
# "unreadable" must never be "ok" (fails closed, same as "unclear") and must
# never be indistinguishable from "stale" (the two need different fixes: a
# re-post vs. a fresh QC pass).

# Single-line body (built with a shell double-quoted string that spans no
# real newline) mimicking the observed corruption: content is otherwise a
# normal checklist review, but "## Verdict" never lands at a genuine line
# start.
NEWLINE_COLLAPSED_APPROVED="Reviewed SHA: $TIP Structural QC checklist: file scope clean, naming consistent, no magic numbers introduced, all tests passing).## VerdictAPPROVED"

# 51. THE REGRESSION ITSELF: a newline-collapsed APPROVED review, alone, at
#     the current tip must read "unreadable(<sha>)" for the gate it would
#     otherwise vanish from -- never "none" (which would read as "nothing
#     posted yet, dispatch QC") and never "ok".
check "newline-collapsed APPROVED at the current tip reads unreadable, not none" \
  "unreadable(7dc57cc0)" "$(_gate "$(reviews "$NEWLINE_COLLAPSED_APPROVED")" behavioral "$TIP")"
check "...and the same for the structural gate (heading is unreadable for BOTH, not just one)" \
  "unreadable(7dc57cc0)" "$(_gate "$(reviews "$NEWLINE_COLLAPSED_APPROVED")" structural "$TIP")"

# 52. CONTROL (the point of a detector is what it does NOT fire on): the
#     identical content, properly newlined, must read completely normally --
#     "ok" for its own gate, and a plain "none" (not "unreadable") for the
#     gate it does not name. Proves the detector keys off newline collapse,
#     not off content ("Structural QC", "checklist", etc).
PROPERLY_NEWLINED_COUNTERPART="Reviewed SHA: $TIP

## Structural QC checklist

File scope clean, naming consistent, no magic numbers introduced, all tests
passing.

## Verdict

APPROVED"

check "control: the properly-newlined counterpart reads ok for its own gate" \
  ok "$(_gate "$(reviews "$PROPERLY_NEWLINED_COUNTERPART")" structural "$TIP")"
check "control: ...and plain none (not unreadable) for the gate it does not name" \
  none "$(_gate "$(reviews "$PROPERLY_NEWLINED_COUNTERPART")" behavioral "$TIP")"

# 53. CONTROL: a genuinely stale prior verdict, with no corruption anywhere in
#     the reviews array, must keep reading "stale(<old-sha>)" -- unaffected by
#     this fix. Reuses STALE_BEHAVIORAL (case 6) to pin the exact previous
#     behaviour still holds.
check "control: genuinely stale verdict (no corruption present) still reads stale, not unreadable" \
  "stale(deadbeef)" "$(_gate "$(reviews "$STALE_BEHAVIORAL")" behavioral "$TIP")"

# 54. CONTROL: the SAME collapsed review, evaluated against an UNRELATED tip,
#     must read "none" -- the detector is scoped to the CURRENT tip, not "any
#     corrupt review anywhere in the array flags every gate on every PR".
check "control: a collapsed review at an UNRELATED tip does not trigger unreadable" \
  none "$(_gate "$(reviews "$NEWLINE_COLLAPSED_APPROVED")" behavioral "9999999999999999999999999999999999999999")"

# 55. THE EXACT #2663 SHAPE: an older, properly-formatted, genuinely stale
#     review ("deadbeef") COEXISTS with a newline-collapsed review AT the
#     current tip. Before this fix, $results only ever contained the stale
#     review (the collapsed one never attributes to any heading), so the gate
#     reported "stale(deadbeef)" -- exactly PR #2663's live
#     `stale(25d1a938)` misdiagnosis. Must now read "unreadable(<sha>)",
#     naming the review that actually exists at the tip.
STALE_PLUS_CORRUPT_AT_TIP=$(jq -nc --arg a "Reviewed SHA: deadbeef

## Behavioral QC — an earlier tip

## Verdict

APPROVED" --arg b "$NEWLINE_COLLAPSED_APPROVED" '[{body: $a}, {body: $b}]')

check "#2663 shape: a stale review plus a collapsed review AT the tip reads unreadable, not stale(deadbeef)" \
  "unreadable(7dc57cc0)" "$(_gate "$STALE_PLUS_CORRUPT_AT_TIP" behavioral "$TIP")"

# 56. GUARD: a body that never mentions a verdict at all (case 11's shape --
#     genuinely unfinished, not corrupted) must never be flagged as
#     "unreadable" merely for being short or having few newlines. Re-asserts
#     case 11's fixture directly against this fix's own detector to make the
#     non-interaction explicit rather than relying on case 11 not regressing
#     silently.
check "an unfinished review with no verdict mention anywhere stays unclear, never unreadable" \
  unclear "$(_gate "$(reviews "$NO_VERDICT_SECTION")" behavioral "$TIP")"

# 57. END TO END: the real script (not just _gate) must route a collapsed
#     review to a distinct, loud NEXT-ACTION that is never "MERGE" and never
#     reads as a plain "re-run QC" (stale's action) -- proving the fail-closed
#     property holds through the whole CLI, not just the library function.
NEWLINE_E2E_STUB_DIR=$(mktemp -d)
cat > "$NEWLINE_E2E_STUB_DIR/gh" <<'STUB'
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
chmod +x "$NEWLINE_E2E_STUB_DIR/gh"

GATE_PR_NUMBER=502
GATE_TIP=$TIP
GATE_FILES="trading/foo/bar.ml"
GATE_CHECKS="pass"
GATE_LABELS_JSON='[]'
export GATE_PR_NUMBER GATE_TIP GATE_FILES GATE_CHECKS GATE_LABELS_JSON
GATE_REVIEWS_JSON=$(reviews "$NEWLINE_COLLAPSED_APPROVED")
export GATE_REVIEWS_JSON
row=$(_e2e_probe "$NEWLINE_E2E_STUB_DIR" "" 502 | tail -1)
case "$row" in
  *"RE-POST"*) got=REPOST ;;
  *MERGE*)     got=MERGE ;;
  *)           got=other ;;
esac
check "H-QC-VERDICT-NEWLINE-COLLAPSE e2e: a newline-collapsed review at the tip never reaches MERGE" \
  REPOST "$got"
rm -rf "$NEWLINE_E2E_STUB_DIR"

if [ "$fails" -gt 0 ]; then
  printf 'FAIL: pr_gate_status linter -- %d test(s) failed.\n' "$fails"
  exit 1
fi
printf 'OK: pr_gate_status -- %d tests clean.\n' "$total"
