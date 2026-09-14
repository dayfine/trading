# Next-session priorities — 2026-09-14 (supersedes 2026-09-13)

Written 04:05 PT 2026-09-14 (autonomous 16:31 PT 09-13 → 04:05 PT 09-14, user away from ~21:40 PT). Every queue item of
the 09-13 doc is resolved and merged; no PR is open.

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
   12% instead of 4%, and the 26y's biggest 2019–23 winners (CLS, BFX, TTEC, CLFD, $2.6M) are absent from the year-2019
   vintage composition (only 1,023 of ~2,980 names shared with the year-2000 vintage list — 3,000 symbols as of 2000-05-31, held fixed). No promotion PR, no 10% neighbour arm, item-3
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
- First OCaml advisory dry run done on #2800 with `review/codex-requested`: one finding, real (V16 gap), fixed before the
  Claude gates ran. Codex queue: #2653 merged (#2797). Codex has `codex-2753-publisher-guard` and `codex-2788-behavioral-tools` worktrees
  but no PRs yet; #2793 (git push tightening) is queued. `AGENTS.md` carries the cross-agent section.

## #2800 MERGED 04:04 PT — breaker exits now labelled `force_liquidation` (queue item 4 done)

- `feat(backtest): label breaker exits force_liquidation in trades.csv` — three commits: the feature; a nesting-linter
  refactor after CI's `FAIL: nesting linter` on `_transition_of_event`; V16 registration after the advisory Codex review
  (5196263561) found the new token absent from `_default_fallback_exit_labels`. Gates: structural APPROVED (5196712236,
  dune 0/0/0), behavioral APPROVED (5196864221, four probes RED). Also deleted the dead `Trades_stream` relabel (keyed on
  the breaker's fire date, never the D1 exit date) and moved three breaker-row diagnostic columns to the non-stop-exit
  convention — judged inseparable from the label change.
- **Follow-up (small):** one `test_trade_audit_ratings.ml` case pinning R7 = `Fail` for a `force_liquidation`-labelled
  `Strategy_signal` (the path is live; only unpinned).
- Read-side effect: `read.sh`'s `force_liquidation` exit-mix row and V16's fallback count are non-zero on any run with
  breaker exits from now on; pre-09-14 artifacts still carry them as `stop_loss` — use `force_liquidations.sexp` there.

## Open PRs

None at 04:05 PT.

## P0 for the next session — migrate the record to a point-in-time top-3000 universe (user decision, 04:45 PT 09-14)

**Terminology first, because it misled:** `top-3000-2000.sexp` is the **year-2000 vintage** list — the 3,000 highest
dollar-volume names as of **2000-05-31** — held **fixed for all 26 years** of the record (`Composition_from_individuals`,
3,000 entries; likewise `top-3000-2009` = 2009-05-31 and `top-3000-2019` = 2019-05-31). It is 3,000 symbols from the year
2000, not 2,000 symbols. Say "year-2000 vintage" or "2000-05-31 list", never "the 2000 list".

**Why migrate (found by the confirmation grid):** the two vintages share only 1,023 of ~2,980 names. Anything that listed
or grew into the top 3,000 after 2000 is invisible to the 26y record (ZS, ETSY…), and every name still trading in 2023 is
a survivor by construction — CLS, BFX, TTEC, CLFD alone are $2.6M of the 26y wide arm's 2019–23 gain and are not in the
2019 list. Paired verdicts on one list stay valid (the tilt hits null and arm alike —
`project_composition_golden_survivor_bias`), but (a) the headline levels carry a large survivorship inflation
(`project_pit_survivorship_inflation`), (b) "vintage diversity" in a grid moves the universe more than the period, and
(c) live trading screens the *current* top 3,000, so the backtest does not model membership drift — and the next
queue item (top-of-funnel: breakout gate, top-N) is a membership question. Measure that on a survivor list and you
measure the wrong estimand.

**Plan (pre-register before building; one PR per step):**
1. **Decisions to record first** (a docs PR): membership = top 3,000 by prior-year dollar volume, fixed at each year
   start (no look-ahead), delisted names included; held positions in a name that drops out of the list are **held to
   their normal exit** (no forced sell — a forced sell would invent a mechanism); one snapshot convention (the current
   files use May-31; pick year-start or May-31 and keep it everywhere).
2. **List builder:** extend the yearly top-1000 builder (`top-1000-1998.sexp` … exist) to top-3000 for 2000–2026 from
   the delisted-inclusive EODHD coverage (`project_eodhd_delisted_unlock`); coverage check first
   (`fetch-historical-data` skill). ops-data / feat-data.
3. **Warehouse `_v11pit`:** union of the yearly lists (larger than 3,000 symbols → longer cells; budget ~3 h per 26y
   cell). Fold in the **SGP_old1 truncation** at the 2009-11 merger and the **#2782 spin-off twins** — this is the
   cheapest moment for both. Keep `_v10dedup` until the new band exists.
4. **New record band:** the a0 null at 3 salts on `_v11pit` (~9 h container, two lanes) → new ledger baseline; re-pin the
   goldens that move (one PR, `config-default-blast-radius.md` paired statement). Ledger note: every pre-migration 26y
   verdict is a paired read on the year-2000 vintage list and stays valid as a relative read.
5. **Grid rule update** (`promotion-confirmation.md`): with a PIT universe, "universe diversity" = breadth tier
   (top-1000 vs top-3000), not vintage; period diversity = disjoint sub-windows of the same construction.
6. Only then the top-of-funnel screen (breakout-gate width, top-N) on the new band.

Cost: ~1 day of agent time for 1–2, hours of container for 3, ~9 h for 4, one goldens PR. Everything below in the
queue rides in the same rebuild.

## Queue (in order)

0. **The P0 above** — universe migration, steps 1–5, before any new measurement.
1. **Entry side, top of funnel** (on the new band): breakout-gate width and top-N as a surface (3 salts, V6 gate), reading
   the monster funnel (`project_monster_funnel_top_of_funnel`: 87% die at the breakout gate + top-N).
   `experiment-gap-closing` skill; pre-register before launching.
2. **SGP_old1 truncation** + the #2782 spin-off twins — folded into P0 step 3.
3. Rule-4 hygiene: nothing retires (deteriorating gate keep-as-axis; 12%-weekly ACCEPT-not-promoted; 0.25/position
   REJECT-as-default). Note in the flag inventory if refreshed.
4. Carried: orchestrator D2 push (09-10 item 5); #2729 residuals; #2793 (Codex).

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
