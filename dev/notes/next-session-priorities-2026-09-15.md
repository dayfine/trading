# Next-session priorities — 2026-09-15 (supersedes 2026-09-14)

Written during the autonomous 2026-09-14 session (10:31 PT → ~20:00 PT, with a 14:50–17:05 PT rate-limit gap). The
09-14 doc's P0 — migrate the record to a point-in-time top-3000 universe — is three steps in; this doc carries the
live state of steps 3b/4 and what the next session does with the result.

## Merged this session (three gates or docs-only; every verdict at the current tip)

- **PIT migration:** #2808 plan + decisions D1–D8; #2809 step-2 fetch record (one rework iteration); **#2816 step 3a
  `universe_schedule`** (one rework iteration; Codex advisory pass found the sector-rotation gap first).
- **Queue/orchestrator PRs from the gap:** #2805 opam weekly; #2806 Codex's 422-guard test (closes #2753); #2813
  R7 = Fail for `force_liquidation` exits (closes the #2800 follow-up; one rework iteration); #2814 QC score
  lexicon check; #2819 orchestrator fail-closed draft hold (closes #2639); #2821 per-file follow-up overload
  (closes #2742); docs/ops #2807, #2811, #2817, #2818, #2820.

## PIT migration — state at write time

| step | state |
|---|---|
| 1 decisions | MERGED #2808. D1 May-31 anchor; D2 list dated YYYY-05-31 governs `[YYYY-05-31, next)`, first entry governs earlier; D4 dropped names held to normal exit; D6 runs stage the union; D7 `universe_schedule` default `[]` bit-identical. |
| 2 fetch | MERGED #2809. 2,798 names in 6 min; 3 ticker reuses quarantined (APXT, EXCE, TMS — quarantine list now in-repo); every vintage 2000–2025 ≥ 95.7%, 1999 96.2%; union 99.1% of real names, **95.3% counting the 379 absent `_old` twins** (the D6 manifest check sees ~471 absent, not 92). Store 9,093 → 11,888. |
| 3a mechanism | MERGED #2816 (`3a20f4987`). `Scenario.universe_schedule` → `Universe_schedule` (`load` rejects `Full_sector_map` and empty lists; `sector_map_of_unscheduled ~runner_name` is the single guarded resolver for every non-scenario runner) → `run_backtest ?universe_membership_at` → `pi && scheduled` in `_membership_at_callback_of`. Residual (non-blocking): the `(pi=true, sched=true)` truth-table row is unpinned — add the one-line test with step 4's spec. |
| 3b warehouse | **DONE 21:55 PT.** Single-pass 10,504-name build OOM-killed (exit 137); four-chunk `-incremental` build succeeded (9,513 snaps). The chain's D6 check then caught 523 absent members: the union carries both tickers of every rename (vintage lists already list both legs, e.g. 2005 has ABFS and ARCB) and the twin pass dropped 446 legs — 86 of them FALSE transitive drops (match < 0.95, some overlap 0; **issue #2823**). Fix without code: alias the 360 legit legs into the 27 lists (per-list dedupe; effective breadth ≈ 2,900 unique instruments/yr) → untracked `sweep-pit/trading/test_data/backtest_scenarios/pit-v11/composition/`; rebuild the 84 false legs as their own series (chunk 5, no dedupe) → manifest 9,597; D6 clean (absent real = 97 MISS + 3 quarantined + MEL). Alias map `/tmp/pit-fetch/specs/alias2.resolved`; chunk logs + twin reports already in `results/`. |
| 4 null band | **RUNNING — ONE worker at a time.** Lane A launched 21:54 PT (`chain-pit.sh A a0-pit-null:0 a0-pit-null:2`, nohup, survives session exit); lane B (salt 1) was STOPPED at 21:56 because two workers hit 6.5 GB on the 9.6k-name warehouse (a single worker sits at ~5.5–6.5 GB: the union-wide `_classify_all` screen — the plan's optional pre-prune is now worth building). Spec `/tmp/pit-fetch/specs/a0-pit-null.sexp` points at `pit-v11/composition/…`. Artifacts `/tmp/sweeps/pit-null/`, logs `/tmp/pit-run/chain-A.log`, per-cell `/tmp/pit-run/A/*.log`. |
| 5 grid rule | `promotion-confirmation.md`: universe diversity = breadth tier of the same construction; period = disjoint sub-windows. Docs PR after the band exists. |

Everything staged under `/tmp/pit-fetch/` (specs, scripts, logs, quarantine) is host-only and NOT in VCS — commit
the scripts + per-cell artifacts into `dev/experiments/pit-universe-2026-09-14/` with the step-4 record.

## P0 for the next session

1. **Resume step 4.** `grep RESULT /tmp/pit-run/chain-A.log` — expect `RESULT a0-pit-null-s0-v11 => …` and `…-s2-v11 => …` then `LANE A DONE` (~3 h per cell from 21:54 PT). If lane A is still running, do NOT dispatch agents (container-exclusive). When `LANE A DONE`: `nohup sh /tmp/pit-fetch/chain-pit.sh B a0-pit-null:1 > /tmp/pit-run/nohup-B.out 2>&1 &` (one worker). If a cell shows `<no result>` with no exception in its log, it was OOM-killed — rerun it alone. V6 must be 0 on every salt (false-twin caveat).
2. **Write the step-4 record**: `dev/experiments/pit-universe-2026-09-14/README.md` §"Step 4 — record band on the PIT
   universe": the 3-salt band (realised, MTM, maxDD, trades), V6 = 0 required on every salt (cross-chunk twin caveat),
   the by-vintage membership funnel, and the comparison note — levels are NOT comparable to the year-2000 vintage
   band (312 / 383 / 640 %); state the new band and stop. Ledger entry under `dev/experiments/_ledger/`
   (`2026-09-15-pit-universe-record-baseline`), memory `project_record_rebase_2026_09_15`.
3. **Goldens**: no committed golden uses a schedule yet, so nothing re-pins; add ONE scheduled smoke golden (the
   `panel-golden-2019-full` two-list arm from `test_universe_schedule_e2e.ml` is already the fixture) so CI exercises
   the seam end to end.
4. **Step 5** grid-rule docs PR; then the top-of-funnel screen (breakout-gate width, top-N) on the new band —
   `experiment-gap-closing`, pre-register first.

## Carried / small

- Tier-3 write-back owed to `docs/design/weinstein-book-reference.md` §5.1: the #2813 review settled "breaker ⇒ R7
  Fail regardless of stage" from Chapter 6's stop-discipline rules (protective stop entered at purchase, ≤ 15 %
  initial risk, no single position may cripple the portfolio) — paraphrase with a chapter citation. Also the
  L6 taxonomy question: whether the breaker shape belongs under R7 or its own rating id (`R7 = Fail` is now two-meaning).
- `dev/status/harness.md` still says the publisher suite went "59 → 76"; measured baseline was 74 (#2814 review).
- `.claude/rules` / memory: `gh pr review` takes `--body-file <path>` (`-F` IS `--body-file`); `-F body=@file` is the
  `gh api` form. One qc-structural agent posted with `gh pr comment` again despite the brief — converted; the tell is an
  `issuecomment-…` URL in the agent's report.
- Rule-4 hygiene, orchestrator D2 push, #2729 residuals, #2793 (Codex): unchanged from 09-14.

## Ops notes

- **`build_snapshots` loads every CSV before writing; ~3,000 names fit in 7.75 GB, ~10,500 do not** — chunk with
  `-incremental` into one dir. `pgrep -x build_snapshots` (15-char process name), not `build_snapshots.exe`.
- **Host disk was 24 GB free at 19:30 PT with 23 Time Machine local snapshots**; `tmutil thinlocalsnapshots /
  40000000000 3` → 69 GB in seconds. Check before any long run (`sweep-hygiene.md` wants > 50 GB).
- **An orphaned `dune runtest` from a deleted QC worktree ran 3 h at 100 % of a core** until killed; after every agent,
  list `pgrep -x dune` cwds and kill any `(deleted)`.
- The session hit the rate limit at ~12:35 PT (reset 14:50); one feat dispatch died at start and was re-dispatched at
  17:05 with no lost work. Check the clock on every resume.
- Orchestrator cron (GHA, 00:17 / 05:17 PT) opened six PRs during the gap; all were gated and merged locally. It runs
  on GHA, so it cannot contend with the container.
