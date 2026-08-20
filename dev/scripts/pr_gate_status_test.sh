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

check() {
  _name=$1; _want=$2; _got=$3
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

# 17. OVER-STRIPPING MUST NOT GO GREEN. A lone `~~~` opens a fence that never
#     closes, so the stripper eats the rest of the body including this review's
#     own "## Verdict". An earlier version of this matcher had an inline
#     `Verdict:` fallback that, in this exact shape, matched a QUOTED foreign
#     verdict and returned `ok` -- the exact false green the fence work exists
#     to prevent, reached by being too eager rather than too lax. That fallback
#     is now deleted outright (not merely anchored -- anchoring it to `^` only
#     moved the hole to column 0, see case 18 below), so with "## Verdict" as
#     the sole verdict source, an over-stripped body loses its own heading
#     entirely and reads "unclear", fail-safe.
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

# 20. #2421. A review that quotes ANOTHER gate's "## Verdict" heading flush left
#     -- no fence, no indent needed at all -- has that quotation read as its own
#     verdict, because `capture()` (no /g) returns the FIRST match in the body
#     and the quoted heading sits above the review's real one. Distinct from
#     case 14 (indented quote) and cases 17-19 (fence-adjacent): this one needs
#     no fence and no indentation, just a second "## Verdict" heading earlier in
#     the body. The review's own verdict is the LAST "## Verdict" section.
QUOTES_A_VERDICT_HEADING_FLUSH_LEFT="Reviewed SHA: 7dc57cc06

## Behavioral QC — my review

The structural pass ended:

## Verdict

APPROVED

## Verdict

NEEDS_REWORK"

check "quoted flush-left Verdict heading above the real one does not win (#2421)" \
  rework "$(_gate "$(reviews "$QUOTES_A_VERDICT_HEADING_FLUSH_LEFT")" behavioral "$TIP")"

# 21. Symmetric case to #20, deliberately NOT required to pass: a review states
#     its OWN verdict first, then appends an addendum quoting a DIFFERENT
#     verdict below it. Taking the last unfenced "## Verdict" section (the #2421
#     fix) reads the addendum's quotation, not the review's real verdict, here.
#     This is a known, accepted gap -- see the comment above _gate's verdict
#     extraction and the PR body for #2421. Not asserted against; recorded so a
#     future reader does not "rediscover" it as new. (No `check` call: this is
#     documentation of current behavior, not a requirement.)
ADDENDUM_QUOTES_A_DIFFERENT_VERDICT_AFTER="Reviewed SHA: 7dc57cc06

## Behavioral QC — my review

## Verdict

NEEDS_REWORK

Addendum: for context, the prior structural pass ended:

## Verdict

APPROVED"

printf 'note %s: known gap, addendum-quoted verdict read as %s (see #2421)\n' \
  "symmetric addendum case is NOT handled by last-match" \
  "$(_gate "$(reviews "$ADDENDUM_QUOTES_A_DIFFERENT_VERDICT_AFTER")" behavioral "$TIP")"

# 22. CRLF line endings. A pasted-in review body can carry \r\n rather than
#     plain \n; the gap between the "## Verdict" heading and its token used to
#     be matched by a class with no \r in it, so the trailing \r broke the
#     match entirely and the gate read "unclear" instead of the real verdict.
#     Built with printf (not a shell here-doc) so the \r bytes are real, not a
#     literal backslash-r.
CRLF_BODY=$(printf 'Reviewed SHA: 7dc57cc06\r\n\r\n## Behavioral QC crlf review\r\n\r\n## Verdict\r\n\r\nNEEDS_REWORK\r\n')
check "CRLF body still reads its own verdict" \
  rework "$(_gate "$(reviews "$CRLF_BODY")" behavioral "$TIP")"

if [ "$fails" -gt 0 ]; then
  printf 'FAIL: pr_gate_status linter -- %d test(s) failed.\n' "$fails"
  exit 1
fi
printf 'OK: pr_gate_status -- %d tests clean.\n' 21
