#!/bin/sh
# Offline test for dev/scripts/lane_board.sh and dev/scripts/lane_handoff.sh
# (async lane board, .claude/rules/async-lanes.md). A fake `gh` on PATH serves
# fixtures and logs every mutation; a stub gate script replaces
# pr_gate_status.sh. Pins the turn rules:
#   rework -> theirs; green + no QC -> ours; all ok -> merge; 49 h silent ->
#   user (one board comment); a non-lane PR is ignored; over cap -> "can hand
#   out: 0"; lane_handoff.sh iteration 3 -> refuses and labels turn/user.
set -eu
. "$(dirname "$0")/_check_lib.sh"
ROOT=$(repo_root)
BOARD="$ROOT/dev/scripts/lane_board.sh"
HANDOFF="$ROOT/dev/scripts/lane_handoff.sh"
for f in "$BOARD" "$HANDOFF"; do
  [ -f "$f" ] || { echo "FAIL: $f missing" >&2; exit 1; }
done
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/bin"
FAILS=0
fail() { echo "FAIL: $1" >&2; FAILS=$((FAILS + 1)); }
expect() { # expect <file> <extended-regex> <label>
  grep -Eq "$2" "$1" || { fail "$3 (no match for: $2)"; sed 's/^/    | /' "$1" >&2; }
}
refute() {
  if grep -Eq "$2" "$1"; then fail "$3 (unexpected match for: $2)"; fi
}

# Fake gh: serves $FX/* fixtures, logs mutations to $FX/calls.log.
cat > "$W/bin/gh" <<'EOF'
#!/bin/sh
FX=${FX:?}
case "$1 $2" in
  "pr list") cat "$FX/prlist.json" ;;
  "pr view") n=$3; if [ -f "$FX/view_$n.json" ]; then cat "$FX/view_$n.json"; else exit 1; fi ;;
  "issue list") case "$*" in *agent/codex*) cat "$FX/issues_codex.json" ;; *) cat "$FX/issues_jules.json" ;; esac ;;
  "issue view") cat "$FX/issueview_$3.json" ;;
  "label list") cat "$FX/labels.json" ;;
  "api "*) echo "https://github.com/x/pull/1#pullrequestreview-9" ;;
  *)
    echo "$*" | tr '\n' ' ' >> "$FX/calls.log"; echo >> "$FX/calls.log"
    prev=""
    for a in "$@"; do
      [ "$prev" = "--body-file" ] && cp "$a" "$FX/board.md"
      prev=$a
    done
    ;;
esac
EOF
chmod +x "$W/bin/gh"

NOW=1792000000
ago() { jq -rn --argjson n "$NOW" --argjson h "$1" '$n - 3600 * $h | todate'; }
view() { # view <n> <commit-age-h> [comments-json]
  printf '{"commits":[{"committedDate":"%s"}],"comments":%s,"reviews":[]}\n' "$(ago "$2")" "${3:-[]}" > "$FX/view_$1.json"
}
pr() { # pr <n> <branch> <labels-json> <body>
  printf '{"number":%s,"title":"PR %s","body":"%s","headRefName":"%s","labels":%s}' "$1" "$1" "$4" "$2" "$3"
}
newfx() {
  FX="$W/fx$1"; mkdir -p "$FX"; export FX
  echo '[]' > "$FX/labels.json"; echo '[]' > "$FX/issues_codex.json"; echo '[]' > "$FX/issues_jules.json"
}
run_board() {
  PATH="$W/bin:$PATH" PR_GATE_STATUS="$FX/gate.sh" NOW=$NOW REPO=dayfine/trading sh "$BOARD" "$@" > "$FX/out.txt" 2>&1 \
    || { fail "lane_board.sh exited non-zero"; cat "$FX/out.txt" >&2; }
}
gates() { # header + rows on stdin -> stub gate script
  { echo '#!/bin/sh'; echo "cat <<'G'"; echo 'PR CI STRUCT BEHAV CODEX VERIFIES NEXT-ACTION'; cat; echo 'G'; } > "$FX/gate.sh"
}

# ---------------- scenario 1: the turn rules ------------------------------
newfx 1
{
  printf '['
  pr 101 codex/a '[{"name":"author/codex"}]' 'x'; printf ','
  pr 102 jules/b '[]' 'x'; printf ','
  pr 103 other/c '[{"name":"author/codex"}]' 'x'; printf ','
  pr 104 jules/d '[{"name":"turn/claude"}]' 'x'; printf ','
  pr 105 feat/not-a-lane '[]' 'x'; printf ','
  pr 106 codex/e '[]' 'Closes #201'
  printf ']\n'
} > "$FX/prlist.json"
view 101 5; view 102 3; view 103 2; view 104 49; view 106 1
gates <<'G'
101    pass     rework         none           none      -         rework
102    pass     none           none           none      -         dispatch qc-structural
103    pass     ok             ok             none      -         MERGE
104    pass     none           none           none      -         dispatch qc-structural
106    pass     stale(abc1234) none           none      -         re-run qc-structural
G
cat > "$FX/issues_codex.json" <<'J'
[{"number":201,"title":"covered by PR 106","labels":[],"createdAt":"2026-01-01T00:00:00Z","comments":[]},
 {"number":202,"title":"never handed out","labels":[],"createdAt":"2026-01-01T00:00:00Z","comments":[]}]
J
printf '[{"number":203,"title":"handed out","labels":[],"createdAt":"2026-01-01T00:00:00Z","comments":[{"author":{"login":"dayfine"},"createdAt":"%s","body":"<!-- lane-handoff task -->\\n@jules go"}]}]\n' "$(ago 2)" > "$FX/issues_jules.json"
run_board
B="$FX/board.md"
expect "$B" '^\| #101 .*\| theirs \|' "rework review -> theirs"
expect "$B" '^\| #102 .*\| ours \|' "green CI, no QC -> ours"
expect "$B" '^\| #103 .*\| merge \|' "all gates ok -> merge"
expect "$B" '^\| #104 .*\| user \| .* \| 49 \|' "49 h silent -> user"
expect "$B" '^\| #106 .*\| ours \|' "stale gate -> ours"
expect "$B" '^\| #202 .*\| ours \|' "issue never handed out -> ours"
expect "$B" '^\| #203 .*\| theirs \|' "issue handed out, no PR -> theirs"
refute "$B" '#105' "non-lane PR ignored"
refute "$B" '^\| #201 ' "issue covered by a PR gets no row of its own"
expect "$B" 'Can hand out: 0' "CODEX lane: 3 open PRs -> can hand out 0 (101, 103, 106)"
expect "$B" 'Can hand out: 1' "JULES lane: 2 open PRs -> can hand out 1"
expect "$B" '^- #104 ' "stale section lists 104"
C="$FX/calls.log"
expect "$C" 'pr edit 101 .*--add-label turn/codex' "label: 101 turn/codex"
expect "$C" 'pr edit 102 .*--add-label turn/claude' "label: 102 turn/claude"
expect "$C" 'pr edit 103 .*--add-label turn/claude' "label: 103 (merge) turn/claude"
expect "$C" 'pr edit 104 .*--add-label turn/user .*--remove-label turn/claude' "label: 104 turn/user, old turn label removed"
expect "$C" 'issue edit 203 .*--add-label turn/jules' "label: issue 203 turn/jules"
expect "$C" 'label create turn/user' "missing labels are created"
refute "$C" 'edit 105' "no edit on the non-lane PR"
n=$(grep -c 'issue comment 3330' "$C" || true)
[ "$n" = 1 ] || fail "exactly one board comment expected, got $n"
expect "$C" 'issue comment 3330 .*#104' "board comment names 104"

# Second run: 104 already carries turn/user -> no new board comment.
printf '[%s,%s]\n' "$(pr 104 jules/d '[{"name":"turn/user"}]' x)" "$(pr 101 codex/a '[{"name":"author/codex"},{"name":"turn/codex"}]' x)" > "$FX/prlist.json"
rm -f "$C"
run_board
n=$(grep -c 'issue comment' "$C" 2>/dev/null || true)
[ "${n:-0}" = 0 ] || fail "already-user item must not comment again (got $n)"
refute "$C" 'edit 104' "no relabel when label already right"

# --dry-run mutates nothing.
rm -f "$C"
run_board --dry-run
[ ! -s "$C" ] || fail "--dry-run must not mutate"
expect "$FX/out.txt" 'planned label edits' "--dry-run prints the plan"

# ---------------- scenario 2: over cap ------------------------------------
newfx 2
{
  printf '['
  pr 301 codex/a '[]' x; printf ','; pr 302 codex/b '[]' x; printf ','
  pr 303 codex/c '[]' x; printf ','; pr 304 codex/d '[]' x
  printf ']\n'
} > "$FX/prlist.json"
for n in 301 302 303 304; do view $n 1; done
gates <<'G'
301    pass     none           none           none      -         x
302    pass     none           none           none      -         x
303    pass     none           none           none      -         x
304    pass     none           none           none      -         x
G
run_board
expect "$FX/board.md" 'Open PRs: 4 of 3\. \*\*Can hand out: 0\*\*' "over cap -> can hand out: 0"
expect "$FX/board.md" 'Open PRs: 0 of 3\. \*\*Can hand out: 3\*\*' "empty JULES lane -> can hand out: 3"

# ---------------- scenario 2b: replies, connector noise, header rules -----
newfx 4
cm() { printf '{"author":{"login":"%s"},"createdAt":"%s","body":"%s"}' "$1" "$(ago "$2")" "$3"; }
HO='<!-- lane-handoff rework iter=1 -->'
NOISE='To use Codex here, create an environment for this repo.'
{
  printf '['
  pr 601 codex/a '[]' x; printf ','; pr 602 codex/b '[]' x; printf ','
  pr 603 codex/c '[]' x; printf ','; pr 604 codex/d '[]' x; printf ','
  pr 605 codex/e '[{"name":"author/codex"}]' 'Closes #704'; printf ','
  pr 606 codex/f '[]' x; printf ','; pr 607 jules/g '[]' x; printf ','
  pr 608 jules/h '[]' x
  printf ']\n'
} > "$FX/prlist.json"
view 601 20 "[$(cm dayfine 5 "$HO"),$(cm chatgpt-codex-connector 2 'I fixed it')]"
view 602 20 "[$(cm dayfine 5 "$HO")]"
view 603 20 "[$(cm dayfine 5 "$HO"),$(cm 'chatgpt-codex-connector[bot]' 4 "$NOISE")]"
view 604 20 "[$(cm dayfine 5 "$HO"),$(cm chatgpt-codex-connector 4 "$NOISE")]"
view 605 1; view 606 2; view 607 2; view 608 100
gates <<'G'
601    pass     rework         none           none      -         x
602    pass     rework         none           none      -         x
603    pass     none           none           none      -         x
604    pass     none           none           none      -         x
605    pass     none           none           none      -         x
606    FAIL     none           none           none      -         x
607    pending  none           none           none      -         x
608    pass     ok             ok             none      -         MERGE
G
cat > "$FX/issues_codex.json" <<J
[{"number":701,"title":"replied","labels":[],"createdAt":"2026-01-01T00:00:00Z","comments":[$(cm dayfine 10 '<!-- lane-handoff task -->'),$(cm 'chatgpt-codex-connector[bot]' 2 'done')]},
 {"number":702,"title":"only noise","labels":[],"createdAt":"2026-01-01T00:00:00Z","comments":[$(cm dayfine 10 '<!-- lane-handoff task -->'),$(cm 'chatgpt-codex-connector[bot]' 9 "$NOISE")]},
 {"number":704,"title":"now covered","labels":[{"name":"turn/codex"}],"createdAt":"2026-01-01T00:00:00Z","comments":[]}]
J
cat > "$FX/issues_jules.json" <<J
[{"number":703,"title":"silent after hand-off","labels":[],"createdAt":"2026-01-01T00:00:00Z","comments":[$(cm dayfine 49 '<!-- lane-handoff task -->')]}]
J
run_board
B="$FX/board.md"; C="$FX/calls.log"
expect "$B" '^\| #601 .*\| ours \|' "rework hand-off then reply, no push -> ours"
expect "$B" '^\| #602 .*\| theirs \|' "rework hand-off, no reply -> theirs"
expect "$B" '^\| #603 .*\| theirs \|' "connector setup reply (with [bot]) is not a move"
expect "$B" '^\| #604 .*\| theirs \|' "connector setup reply (no [bot]) is not a move"
expect "$B" '^\| #606 .*\| theirs \|' "CI FAIL -> theirs"
expect "$B" '^\| #607 .*\| ours \|' "CI pending -> ours"
expect "$B" '^\| #608 .*\| merge \|' "merge idle 100 h stays merge, never user"
expect "$B" '^\| #701 .*\| ours \|' "issue handed out then agent replies -> ours"
expect "$B" '^\| #702 .*\| theirs \|' "issue with only connector noise after hand-off -> theirs"
expect "$B" '^\| #703 .*\| user \|' "issue handed out and silent 49 h -> user"
expect "$C" 'issue comment 3330 .*#703' "silent issue raises one board comment"
refute "$B" '^\| #704 ' "covered issue has no row"
expect "$C" 'issue edit 704 --repo dayfine/trading --remove-label turn/codex' "covered issue loses its stale turn label"
refute "$C" 'edit 704 .*--add-label' "covered issue gets no new turn label"
# noise must not reset the idle clock: 603's only non-noise move is the 5 h hand-off
expect "$B" '^\| #603 .*\| 5 \|' "noise does not reset idle"

# ---------------- scenario 3: lane_handoff.sh -----------------------------
newfx 3
cat > "$FX/view_401.json" <<'J'
{"number":401,"labels":[{"name":"author/codex"},{"name":"turn/codex"}],"headRefName":"codex/x","url":"https://github.com/dayfine/trading/pull/401","comments":[]}
J
run_handoff() { PATH="$W/bin:$PATH" REPO=dayfine/trading sh "$HANDOFF" "$@" > "$FX/out.txt" 2>&1; }
run_handoff 401 rework --iter 1 || fail "handoff iteration 1 should succeed"
expect "$FX/calls.log" 'pr comment 401 .*@codex rework iteration 1 of 2' "iteration 1 posts the hand-off"
expect "$FX/calls.log" 'pullrequestreview-9' "hand-off links the NEEDS_REWORK review"
expect "$FX/calls.log" 'second commit' "hand-off asks for a second commit"
rm -f "$FX/calls.log"
if run_handoff 401 rework --iter 3; then fail "iteration 3 must refuse"; fi
expect "$FX/out.txt" 'exceeds the cap' "iteration 3 explains the refusal"
expect "$FX/calls.log" 'pr edit 401 --repo dayfine/trading --add-label turn/user --remove-label turn/codex' "iteration 3 sets turn/user"
refute "$FX/calls.log" 'comment' "iteration 3 posts nothing"
# iteration inferred from earlier rework hand-offs on the PR
cat > "$FX/view_402.json" <<'J'
{"number":402,"labels":[{"name":"author/jules"}],"headRefName":"jules/y","url":"https://github.com/dayfine/trading/pull/402","comments":[{"body":"<!-- lane-handoff rework iter=1 -->"},{"body":"<!-- lane-handoff rework iter=2 -->"}]}
J
if run_handoff 402 rework; then fail "third inferred rework must refuse"; fi
# task hand-off on an issue
echo '{"number":501,"labels":[{"name":"agent/jules"}],"url":"https://github.com/dayfine/trading/issues/501","comments":[]}' > "$FX/issueview_501.json"
rm -f "$FX/calls.log"
run_handoff 501 task || fail "task hand-off should succeed"
expect "$FX/calls.log" 'issue comment 501 .*@jules please take this issue' "task mentions @jules"
expect "$FX/calls.log" 'Closes #501' "task asks for Closes #N"

[ "$FAILS" = 0 ] || { echo "lane_board_test: $FAILS failure(s)" >&2; exit 1; }
echo "OK: lane_board_test"
