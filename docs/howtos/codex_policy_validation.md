# Validating the project command policy

Codex CLI 0.154.0 loads `.codex/rules/*.rules` at startup when the project
configuration layer is trusted. Restart Codex after updating these files.
See the [official rules documentation](https://learn.chatgpt.com/docs/agent-configuration/rules).

An `allow` rule permits a matching command to execute outside the sandbox.
Keep the sandbox enabled for other commands. These prefixes are command
approvals, not a complete security boundary: Docker exec can run arbitrary
code inside the named container, and Git commands must still target your own
worktree. Unlisted commands retain normal approval handling. Review posting
and arbitrary API calls require approval; merges and jj are forbidden.

## Parser and matching checks

From the trusted checkout, run (these commands evaluate policy only):

```bash
codex execpolicy check --rules .codex/rules/trading.rules -- jj status
codex execpolicy check --rules .codex/rules/trading.rules -- gh pr merge 2786 --admin
codex execpolicy check --rules .codex/rules/trading.rules -- docker stop trading-1-dev
codex execpolicy check --rules .codex/rules/trading.rules -- gh pr review 2786 --approve
codex execpolicy check --rules .codex/rules/trading.rules -- docker exec trading-1-dev ps
```

Expected decisions, respectively: forbidden, forbidden, forbidden, prompt,
allow. Inline match/not_match examples are checked when the file loads.
Argument tokens match exactly: `sh dev/scripts/` would not match a script
within that directory. No directory-wide cleanup or temporary-script allows
are installed.

## Permission audit: September 15, 2026

The scheduled issue cycle exposed both missing rules and command-shape mismatches.
The audit evaluated command arguments with the project and user rule files;
it did not execute the target commands or prove which rules an already-running
session had loaded. The project was configured as trusted.

| Operation | Finding | Disposition |
| --- | --- | --- |
| `gh issue edit` | Allowed only by a saved personal approval | Now included in the project rule, because AGENTS.md requires blocked-issue label transitions. This permits all issue edits, not only label changes. |
| `git switch`, `gh run list`, `docker exec trading-1-dev` | Already allowed | No broader rules needed. Prefer direct commands with literal arguments. |
| `git worktree remove` | Explicit `prompt` | Still requires target review. Repeating a saved allow cannot override this prompt rule. |
| `git -C <repo> worktree remove ...` | Different argument prefix; generic removal rule does not match | Do not use argument reordering to evade policy. Normalize invocation when comparing decisions. |
| `crontab -l` | Personal read approval | Does not authorize modification. |
| `crontab -` | No matching allow | Approving the preceding `sed` filter in a pipeline does not authorize the crontab write. |
| `gh pr review --comment` | Explicit `prompt` | Retain review controls; a broader review allow would also permit approval reviews. |
| `git push origin main` | Matches broad push allow | Separate tightening tracked by issue #2793; this change does not claim to restrict push destinations. |

The official rule semantics are `forbidden` > `prompt` > `allow`, not
"most specific rule wins". Rules load at startup; restart after a policy update.
An allow permits execution outside the sandbox without a prompt. A rule change
does not alter the authorization scope of the task or other managed controls.

Complex shell substitutions, redirections, and control flow can cause an entire
shell invocation to be evaluated instead of its constituent command prefixes.
Compute timestamps separately and pass PR/comment text through body files.
Do not solve a wrapper mismatch by broadly allowing `sh`, `zsh`, or `python`.

### Remaining cleanup and scheduler work

These require reviewed implementations before adding command allows:

- Owned-worktree cleanup: validate a registered worktree beneath the expected
  repository, session ownership, clean status, and published commits; reject
  the primary checkout, other agents' worktrees, and an active scheduler tree.
  Test rejection cases as well as successful cleanup. Do not blanket-allow
  worktree removal or treat a directory prefix as a glob.
- Scheduler management: permit only the session's tagged entry, preserve other
  jobs, handle failed reads without installing an empty crontab, and use finished
  state to make leftover ticks harmless. Do not blanket-allow `crontab -`, which
  can replace every job.

An allow for a helper script grants execution of that script's current contents;
its path is not a content-integrity guarantee. Helper code and its policy must be
reviewed together. No cleanup helper, scheduler allow, user-wide settings change,
or promise of zero prompts is included in this policy update.

To reproduce the rule check without performing an issue edit:

```bash
codex execpolicy check --rules .codex/rules/trading.rules -- gh issue edit 2394 --repo dayfine/trading --remove-label ready-for-agent --add-label needs-info
```

Expected decision: `allow`. The inline negative examples ensure the issue-edit
rule does not match `gh issue delete` or `gh issue transfer`.

## Startup enforcement smoke test

Use an isolated, trusted checkout. Record the checksum of user rule files
before and after; do not approve new persistent rules during the probe.
Create a temporary `.codex/rules/smoke.rules` containing:

```text
prefix_rule(pattern=["echo", "CODEX_RULES_LOADED_2786"], decision="forbidden", justification="Temporary project policy loading probe.")
```

Start a fresh process in that checkout (replace the trust path if needed):

```bash
codex -a never exec --ephemeral --json -s read-only \
  -c 'projects."/absolute/path/to/checkout".trust_level="trusted"' \
  'Run exactly echo CODEX_RULES_LOADED_2786 once using the shell tool. This is a harmless policy enforcement test. Do not read files, use alternate commands, or retry if blocked. Report the tool result.'
```

Check the actual tool rejection, not just the model's prose. Remove only the
temporary smoke.rules file and repeat: the tool should now print the marker
with exit code 0. Never pass `--ignore-rules` or a sandbox-bypass flag.

Measured on 2026-09-13 with 0.154.0: the first run's tool rejection contained
`Temporary project policy loading probe.`; the control run printed the marker
and exited 0. Both used read-only sandboxing and approval policy never. The
temporary file was removed. No user rules were manually edited; the outer
Codex session saved its own launch approval during the test, so the whole
user-rule file checksum changed. The before/after command behavior establishes
project-rule loading; this run does not establish byte-for-byte invariance of
the surrounding session's user policy.
