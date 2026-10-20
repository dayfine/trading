# Async lanes: GitHub as the message board

Codex and Jules work outside this session. The loop that keeps them moving, with progress checked
periodically and feedback going both ways, runs on GitHub itself. User direction, 2026-10-18.

**Status: unverified.** Whether an `@codex` / `@jules` mention on a PR or issue actually starts a task is
confirmed only by the trial in #3324. Until that lands, treat the hand-off step as a request, and
fall back to the lanes' existing start methods if a mention does nothing.

Observed so far: `chatgpt-codex-connector` answers every `@codex` mention within seconds with "create an
environment for this repo". Until #3324 registers the Codex environment, every mention gets that automatic
reply, and no Codex hand-offs go out. The board ignores that reply (it is not a Codex move).

## The loop

1. **The board shows whose turn it is.** Issue #3330 (pinned) is rewritten every 3 h by
   `.github/workflows/lane-board.yml`, which runs `dev/scripts/lane_board.sh` (shell + `gh` + `jq`; no model
   calls). Each lane PR and lane issue carries exactly one label: `turn/claude`, `turn/codex`, `turn/jules`
   or `turn/user`. The turn rules are in the script header; `merge` shows as `turn/claude`.
2. **Claude's turns get processed** (`turn/claude`: a QC wave, a merge, a hand-off to post, an issue to hand
   out):
   - at session start, `session-rampup.md` Step 0b;
   - in each orchestrator cron slot, `lead-orchestrator.md` Step 2a2, which runs the QC waves and merges
     and hands out up to the cap. It posts no hand-offs (see 3).
3. **Hand-offs come from a local session**, with `sh dev/scripts/lane_handoff.sh <PR|issue> rework|task`.
   It posts from the user's `gh` login. A bot-token mention may not trigger either agent, so the workflow
   and the GHA orchestrator never call it. Rework is capped at iteration 2; at iteration 3 the script
   refuses and sets `turn/user` (`feat-agent-dispatch.md` section 3).
4. **External agents answer on GitHub**: a push, or a reply comment on the PR or issue. A push, or a reply
   after our hand-off, moves the turn back to us at the next board run (we must read and answer the
   reply, even when a rework gate still reads `rework`). A rework gate with no reply or push since the
   hand-off stays `theirs`. An issue that a lane PR now mentions (`#N`) loses its `turn/*` label.
A hand-off is either a `<!-- lane-handoff` marker or a word-bounded `@codex` / `@jules` mention
   in a comment/review by someone outside that lane. Connector setup replies remain excluded.
   For an issue with no covering PR, a `codex/*` or `jules/*` branch with no open lane PR is also a
   lane move when its name or head commit message mentions `#N`. The board uses the head's committer
   date and matches only that issue's lane; it lists branches once (paginated) and reads each
   eligible head once.
5. **48 h of silence** from either side turns the item `turn/user` (except items ready to merge), and the board gets one comment. The user
   decides: nudge, reassign, or close. An issue never handed out stays `turn/claude`: it is backlog, not stuck.

## Turn table

| Item | Condition | Turn |
|---|---|---|
| PR | Lane reply after our hand-off | `turn/claude` (read and answer) |
| PR | Rework gate, newer hand-off than lane move, or CI fail/missing | Lane's turn |
| PR | CI pending, or green with a missing/stale QC gate | `turn/claude` |
| PR | CI pass and both QC gates ok/skip | `turn/claude` (merge) |
| Issue without covering PR | Handed off, no lane reply or matching branch head since | Lane's turn |
| Issue without covering PR | Never handed off, or lane reply/branch head after hand-off | `turn/claude` |
| Handed-off issue / non-merge PR | No move for more than 48 h | `turn/user` |

## Caps

At most 3 open PRs per external lane. The board prints `Can hand out: N` per lane; hand out only up to N.

## What does not change

All three Claude gates (CI, qc-structural, qc-behavioral at the current tip) apply to every external-lane PR
(`pr-merge-gates.md`, `cross-agent-review.md`). The board decides who moves next; it never approves or merges.
A `do-not-merge` label still holds.

## Tests

`trading/devtools/checks/lane_board_test.sh` pins the turn rules with a fake `gh`: rework is theirs, green CI
with no QC is ours, all gates ok is merge, 49 h of silence is user, a non-lane PR is ignored, over cap shows
`can hand out: 0`, and `lane_handoff.sh` iteration 3 refuses. It also pins manual mentions,
word boundaries, non-lane authors, setup-noise exclusion, matching branch names/messages, lane and
issue-number boundaries, pagination and the exclusion of branches with open PRs.
