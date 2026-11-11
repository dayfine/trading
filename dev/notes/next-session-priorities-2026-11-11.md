# Next-session priorities — 2026-11-11 (supersedes 2026-11-10)

Overnight session 11-11 00:00 → ~03:00 PT: one QC/merge wave, no backtests. Open issues: **9**. Main CI green.
Ground rules from 2026-11-10 §0 still hold (backtests in the cloud, local container for QC only).

## 1. Merged overnight

| PR | what |
|---|---|
| #3572 | review pack: stop < 2 % of E, E ≥ 10 % under close, vintage-frozen trail |
| #3573 | stops: `Tighten_trigger` records why a stop tightened (walkthrough D3); byte-identical goldens |
| #3574 | dead code: 9 executables + 42 unused vals (rework 2 re-exported every val a doc still cites) |
| #3576 | scheduled workflows bill `ANTHROPIC_API_KEY` when set, else the OAuth token (no change until the secret exists) |
| #3577 | QC agents treat CI `build-and-test` as the build of record; the dispatcher owns CI waits |

#3577 effect: structural re-reviews went from 40–74 min (cold local builds, killed and fallen back on CI) to ~1–2 min.

## 2. Open

| PR | state |
|---|---|
| #3578 | follow-up to #3577 (CI pending → reviewer stops; cancelled/timed_out = no run). All gates green; merges once main CI is green |
| #3571 | chain-w pre-registration: **draft, rework cap reached**, see §4 |

## 3. Queue

1. **Create the API key** (user, 11-11): Console workspace with a monthly spend limit → key →
   `gh secret set ANTHROPIC_API_KEY --repo dayfine/trading`. Other repos get their own keys. After it lands,
   note in `dev/status/cost-tracking.md` that orchestrator `total_cost_usd` rows are now real API dollars.
2. **#3571 decision** (§4), then launch the chain-w cells in the cloud (#3136, #3109, #3183).
3. **Screen the 38 near-tightening stop exits** now that #3573 records the trigger (cloud).
4. Refresh `trading/test_data/S/Y/SPY` past 2026-09-28 before the next Monday weekly-start run.
5. Local budget backfill 11-03 … 11-11 (`budget_local_record.sh --date D`, no other session live).
6. Linter candidate from #3574 QC: for each `val` removed from an `.mli`, grep surviving docs for links to it
   (`odoc_dangling_ref_check.sh` only matches `Module._private`; the repo never runs `dune build @doc`).

7. **#3578 QC gaps (one small PR):** word the CI rule as "status ≠ completed → stop" and "conclusion ∉ {success,
   failure} → no completed run" (covers waiting/requested/neutral/stale/startup_failure); drop "each QC agent
   pays its own full build" in `qc-structural-authority.md`; align `skipped` with `pr_gate_status.sh`; pin the
   no-run sentence in `agent_standing_rules_check.sh` and its `_test.sh`.

**Docker 4 GB check: answered, keep 5 GB.** Peak during a 3-reviewer cold-build wave was 3.23 GiB
(00:32 PT 11-11). With #3577 reviewers no longer cold-build, so the peak should drop; re-measure after a few
waves before lowering.

## 4. Decisions waiting (deferred to 11:00 PT)

**#3571 T3 first-divergence rule** (qc-results review 5856023459). The first decision the true-dollar gate
changes can be a placed ticket that never fills; its cash draw pushes a lower-ranked rival out, whose row has
an id below F, so T3 FAILs a correct run (~3–4 % of runs on rk-k0's audit: 99 of 665 placed entries never
filled, 20 squeezed a rival). Errs conservative but `collect` drops `trade_audit.sexp`, so a false FAIL costs
a ~4 h rerun to trace.
- **A.** F from decisions (audit extract, unfilled tickets included; divisor read over the ADV window). Cleaner, more script work.
- **B (recommended).** Keep row-based F; commit the audit extract; trace any differing row below F before scoring FAIL. A few README sentences.

Either is a third rework past the cap, so it needs the user's go.
