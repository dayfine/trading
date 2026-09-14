# Next-session priorities — 2026-09-14 (supersedes 2026-09-13)

Written 02:40 PT 2026-09-14 (autonomous 16:31 PT 09-13 → 02:40 PT 09-14, user away from ~21:40 PT). Every queue item of
the 09-13 doc is resolved; one code PR (#2800) is open and waiting on its gates.

## Merged this session (all three gates or docs-only; every verdict at the current tip)

- **#2791** grid interim; **#2794** item-4 confirmation-grid verdict + force-liquidation dissection + item-6 screen;
  **#2795** memory snapshot; **#2792** deteriorating-gate ledger amendment (closes #2780); **#2796** probe pre-registration;
  **#2799** probe verdict + artifacts.
- **#2786** Codex command policy (verified with `codex execpolicy check`); **#2785** Codex review howto (taken over,
  re-framed as advisory-by-default); **#2797** Codex's `fix(ci)` trust step (#2653) — the first Codex-authored PR through
  the loop; **#2798** cross-agent review harness (below).

## Two results that change what comes next

1. **12%-weekly confirmation grid FAILS** (`cadence-12w-v10-2026-09-13/README.md` §verdict; ledger
   `2026-09-13-stop-width-12pct-weekly-confirmation-grid`, twelve cells): both 5y vintage cells lose realised AND maxDD
   at 3 of 3 salts (2019: $469k→$166k / 22.6→30.9, $258k→$207k / 22.5→31.1, $245k→$213k / 22.8→31.2; 2009: $106k→−$23k /
   17.9→27.1, $277k→$10k / 20.4→25.2, $77k→−$12k / 17.1→25.4). Wide-weekly keeps its 26y single-surface ACCEPT and stays a
   default-off axis; **not promotable**. Why: shared trades run wider everywhere, but chop-year entries (2021, 2010) bleed
   12% instead of 4%, and the 26y's biggest 2019–23 winners (CLS, BFX, TTEC, CLFD, $2.6M) are absent from the 2019
   composition (only 1,023 of ~2,980 names shared with the 2000 one). No promotion PR, no 10% neighbour arm, item-3
   cancel-on-Bearish no-build (that cohort is positive on the record; brief parked below).
2. **Concentration/deployment probe REJECT** (`concentration-deploy-2026-09-13/`, pre-registered #2796; ledger
   `2026-09-14-concentration-deploy-probe`, seven cells; memory `project_concentration_deploy_probe_reject`):
   c2 (exposure 0.85 + cash floor 0.15) is **bit-identical to the null** — neither knob binds at 0.14/position; c1
   (per-position 0.25) fails realised AND Calmar at 3 of 3 salts (−$421k / −$892k / −$963k; maxDD 32.8→46.7 at s1). The
   shared trades earn more, but a fuller-per-name book holds fewer names when the 2020 monsters screen in (NVDA/BBWI
   null-only); the Recovering-week cohort (11–20 trades) flips sign with the salt; the one salt-robust cost is
   Bearish-week resting fills at the bigger ticket (negative on the arm at all 3 salts, positive on the null at all 3).
   **Item 6 (deployment ramp) = no-build. The entry gap is top-of-funnel (breakout gate, top-N), not funding or sizing.**

Force liquidations on the wide cells (item 2): all `Per_position` breaker fires labelled `stop_loss`; 6/7 real earnings
gaps, 1 phantom (SGP_old1 post-merger stub prints, −$60k/salt). Item-6 screen: `long_top_n_admitted` = 20 every week in
spring 2020 while 1–3 fill — which is what the probe then tested.

## Cross-agent review is set up (#2798, `.claude/rules/cross-agent-review.md`)

- Codex is an **advisory** reviewer; Claude qc-structural + qc-behavioral remain the gates for every PR. `pr_gate_status.sh`
  has a fourth `CODEX` column; labels `author/codex`, `review/codex-requested` (hint), `review/codex-required` (timed HOLD
  on a would-be MERGE, 3 h → `review/codex-timeout`), and `CODEX_REVIEW=off` neutralises everything.
- `sh dev/scripts/codex_review.sh <PR>`: detached worktree at the head → `codex -C … exec -s read-only --ephemeral -o …`
  → validator + the real `_gate` reader must agree → post under `## Codex review — …`. 40 offline tests; 94 gate-reader
  tests; mutation pins 16/16.
- **Evidence it earns its keep:** five advisory passes on #2798 itself found 9 items, 8 acted on (the `exec review --base`
  incompatibility, a `gh api | sed` mask, sandbox not explicit, `CODEX_REVIEW=off` not honoured by the reader, a
  validator/reader disagreement, shared report paths, timeout advice on a returned rework); the Claude behavioral gate
  then found the test harness had masked a dropped `|| return 1` (command-substitution `set -e`) — two rework iterations,
  APPROVED at 4f4ffa74. Next: use `review/codex-requested` on the next OCaml PR (#2800 is the candidate) and compare.
- Codex queue: #2653 merged (#2797). Codex has `codex-2753-publisher-guard` and `codex-2788-behavioral-tools` worktrees
  but no PRs yet; #2793 (git push tightening) is queued. `AGENTS.md` carries the cross-agent section.

## Open PR — run the gate loop on it first

- **#2800** `feat(backtest): label breaker exits force_liquidation in trades.csv` (feat-backtest agent, 12 files). CI at 27f3ef0aa failed on ONE finding — `FAIL: nesting linter` for `_transition_of_event` (max depth 7 > 5) — and a
  rework agent was dispatched at 02:50 PT to extract helpers (second commit on the branch); re-check `gh pr checks 2800`. Beyond the label it (a) deleted the dead `Trades_stream` relabel (keyed on the breaker's fire date,
  which never equals the D1 exit date), and (b) moved three diagnostic columns for breaker rows toward the
  `stage3_force_exit` convention (`stop_trigger_kind` → `non_stop_exit`, `days_to_first_stop_trigger` → None, R7 → Fail).
  (b) is scope beyond "only the label moves" — qc-behavioral should judge it; goldens' `actual.sexp` are untouched per the
  agent. Dispatch qc-structural → qc-behavioral (rework cap 2) → merge; consider `review/codex-requested` on it as the
  first OCaml advisory dry run.

## Queue (in order)

1. Gate loop on #2800 (above).
2. **Entry side, top of funnel**: the probe closed the funding/sizing branch. Next screen = breakout-gate width and top-N as
   a surface on the 26y record (3 salts, V6 gate), reading the monster funnel (`project_monster_funnel_top_of_funnel`:
   87% die at the breakout gate + top-N). `experiment-gap-closing` skill; pre-register before launching.
3. **SGP_old1 truncation** at the 2009-11 merger + the #2782 spin-off twins before the next warehouse rebuild (ops-data).
4. Rule-4 hygiene: nothing retires (deteriorating gate keep-as-axis; 12%-weekly ACCEPT-not-promoted; 0.25/position
   REJECT-as-default). Note in the flag inventory if refreshed.
5. Carried: orchestrator D2 push (09-10 item 5); #2729 residuals; #2793 (Codex).

## Ops notes

- **Host memory watchdog kills background shell loops** (twice tonight at ~45–49% free): prefer bounded `Monitor`s that emit
  one event, not `run_in_background` polling loops, for waits > 10 min.
- **A dune runtest wedged in a deleted agent worktree** (structural re-run agent, dead-pipe mode) ran 2h37m at 100% of a core
  with 7 defunct children until killed; the feat agent's repo-wide `@fmt` wedged twice beside it. After every agent:
  `docker exec trading-1-dev sh -c 'for p in $(pgrep -x dune); do readlink /proc/$p/cwd; done'` — kill any whose cwd is
  `(deleted)`.
- **jj snapshot target**: three times tonight files staged for the results commit landed in whatever commit was `@` (a
  takeover / rework branch). `jj log -r @` before every `cp` into `results/`; `memory/feedback_write_then_jj_new_lands_in_previous_commit`.
- perl `-pi` with shell `$vars` in the replacement interpolates them — three broken lines pushed tonight before caught.
  For shell edits use awk/sed with literal quoting or a quoted heredoc + awk splice.
- `chain-grid.sh`/`chain-conc.sh` now copy `equity_curve.csv`; the maxDD episode dates come from it.
- Lane runtimes on the 26y record were ~2.3–2.9 h per cell, not the 1.6 h estimated; plan lanes accordingly.
- Codex's interactive session (pid ~78304) and its worktrees were left untouched.

## Parked briefs

- **`cancel_resting_longs_on_bearish`** (item 3, no-build while wide-weekly is not promoted): new `Weinstein_strategy_config`
  bool `[@sexp.default false]`; read site `weinstein_strategy_screening.ml` `_run_entry_ticket_ttl` → extend
  `Entry_ticket_ttl` with a macro-only predicate (reuse `_macro_admits_side`), longs only, unfilled `Entering` only,
  precedence rescreen > macro > clock; token `entry_ticket_macro_gate_closed` in `test_cancel_reason_closed_list.ml`;
  flag-off bit-identical; W2 = book §Macro.
