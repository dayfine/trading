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
