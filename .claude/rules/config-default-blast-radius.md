# Config-default blast radius — a config-default PR needs a paired golden run

**When a PR changes a strategy-config DEFAULT, the author must run every
golden that arms the affected knob, PAIRED (base vs the PR), by hand, before
merging** — not rely on CI, which only checks the goldens that run on `push:
main`.

## Why

PR #2384 flipped `entry_order_max_rest_weeks` `0 -> 26` with fully green
CI. The one golden the change actually moved
(`sp500-2019-2023-armed-stoplimit.sexp`, **-38.42pp**) lives under
`goldens-sp500/`, which only `.github/workflows/golden-runs-sp500-5y.yml`
runs — `on: push: branches: [main]`, never on the PR — and that workflow
runs with `continue-on-error: true` during soak. A regression that size
could merge on fully green PR checks, and did. See issue #2393,
`dev/experiments/clock26-golden-ab-2026-08-19/`.

The failure mode is structural, not a one-off: PR-time gates
(`build-and-test`, `perf-tier1-smoke`) never run the multi-minute
sp500/broad goldens by design (too slow for a PR). A config-default change
is invisible to CI exactly where it would show up.

## The rule

A PR is a **config-default change** if it touches a `[@sexp.default ...]`
value in `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml`
or `.mli`, or adds/changes a knob in
`dev/weekly-picks/live-config-overrides.sexp`. For such a PR, before
requesting merge:

1. **Grep the golden/scenario specs for the affected knob:**
   ```sh
   grep -rl '<knob>' trading/test_data/ .github/workflows/
   ```
   Also grep the knob's own `.mli` docstring for `[bracket]` citations to
   OTHER knobs — a golden can be affected without ever naming the changed
   knob itself, if it arms a knob the changed one's behaviour is *gated
   by* (exactly the #2384 shape: the affected golden names
   `enable_sim_entry_stoplimit`, never `entry_order_max_rest_weeks` — see
   the knob's own docstring, which says so explicitly). Read the
   docstring, don't just grep the exact identifier.

2. **Run each matching golden BY HAND, PAIRED** — base vs the PR, changing
   only the one knob (a one-line spec diff, or `--config-overrides` on the
   CLI if the runner supports it):
   ```sh
   docker exec trading-1-dev bash -c \
     'cd /workspaces/trading-1/trading && eval $(opam env) && \
      dune exec trading/backtest/scenarios/bin/scenario_runner.exe -- \
        --spec <golden.sexp> --config-overrides "((<knob> <old-value>))"'
   # then again with <new-value>
   ```

3. **Paste the paired table in the PR body** before requesting merge:
   ```
   | arm            | return | trades | maxDD |
   |----------------|-------:|-------:|------:|
   | <knob>=<old>   | ...    | ...    | ...   |
   | <knob>=<new>   | ...    | ...    | ...   |
   ```
   Zero matching goldens (the common case) → state that explicitly in the
   PR body ("grepped `trading/test_data/` + `.github/workflows/` for
   `<knob>`; zero golden specs and zero docstring-cited knobs match; no
   paired run needed") so the reviewer doesn't have to re-derive it.

## What QC can check

- **B1 — the grep happened.** A PR that changes a `[@sexp.default ...]`
  value or a `live-config-overrides.sexp` knob must state, in its body,
  either the paired table (step 3) or the explicit zero-match statement.
  FAIL if neither is present.
- **B2 — the table is paired, not single-arm.** A pasted table with only
  one row (just the new value) doesn't answer the question this rule
  exists for. FAIL if the old-value arm is missing.
- **B3 — the automated backstop ran.** The `goldens-affected` PR job
  (`.github/workflows/goldens-affected.yml`,
  `trading/devtools/checks/goldens_affected_check.sh`) is the mechanical,
  faster version of step 1 — it must be green at the current PR tip.
  "Green" means either (a) the job found no affected golden on its own
  (the common case), or (b) the job found one, the author did the paired
  run (steps 2-3 above) and pasted the table in the PR body, and a
  maintainer applied the `paired-run-done` label after eyeballing that
  table — see "Resolving a legitimate FAIL" below. A red job with no
  label is a FAIL; a green job (plain or acknowledged) is a PASS. See
  that job's own header for what it can and cannot detect; it does not
  replace this rule, it enforces the trigger condition for it.

## Resolving a legitimate FAIL (the `paired-run-done` label)

The `goldens-affected` job is a pure function of the diff: for a PR that
*legitimately* trips it (the config default is genuinely, intentionally
being changed), doing everything this rule asks — the paired run, the
pasted table — does not change what's in the diff, so the job would FAIL
forever with no way to go green. That is an unsatisfiable condition for a
conformant author, and `pr-merge-gates.md` treats any `FAIL:` line as
non-negotiable, so a real config-default PR would be permanently
unmergeable without this path.

The resolution is a label, not prose in the PR body — automation reads
labels and failing checks, not TODO comments (`pr-merge-gates.md` Rule 0's
"do-not-merge" lesson applies in reverse here: what must let a PR merge
also has to be expressed in automation vocabulary):

1. Do steps 1-3 above: grep, run the paired golden(s), paste the table in
   the PR body.
2. A maintainer (or the author, after self-review) reads the pasted
   table and, if it's satisfactory, applies the **`paired-run-done`**
   label to the PR.
3. `goldens-affected.yml` reads the PR's labels from the triggering event
   (no extra API call) and exports `GOLDENS_AFFECTED_ACK=1` to
   `goldens_affected_check.sh` when the label is present. The script then
   prints `OK (acknowledged): ...` instead of `FAIL: ...` — exit 0 — while
   still listing every affected golden in the notice, so the record of
   *what* was acknowledged survives in the job log.
4. The label is a checkable record that a human looked at the table, not
   a verification that the table's numbers are correct — the same way
   qc-structural/qc-behavioral APPROVED reviews record human-equivalent
   judgment, not a proof. Applying the label without reading the table
   defeats the rule this whole file exists to enforce.

`sh dev/scripts/pr_gate_status.sh` treats an acknowledged (label-driven)
green identically to a plain green — both read as `ci=pass` once the job
exits 0. Removing the label after the job last ran does NOT retroactively
fail it; a rework commit re-triggers the job and re-evaluates the label at
the new tip, same as any other CI check.

## Relationship to the automated check

`goldens_affected_check.sh` automates step 1 mechanically (exact knob-name
match in a golden's `config_overrides`, plus a best-effort docstring
cross-reference scan) and blocks the PR with a FAIL-and-list when it finds
a match, rather than merely reminding. It is not a substitute for this
rule — a knob relationship undocumented in the `.mli` (no `[bracket]`
citation) is a false negative for the automated check but is exactly what
this rule's step 1 (grep + read the docstring, don't just grep the exact
name) still catches by human judgment.
