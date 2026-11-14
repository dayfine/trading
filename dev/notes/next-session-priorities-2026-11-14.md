# Next-session priorities — 2026-11-14 (supersedes 2026-11-13 EOD)

The price-band order is closed on both reads: the binding diagnostic said CLOSE-AXIS (#3602) and the confirmation cells
said NO-BUILD (#3610). The stale-E cap is the live lever. Its K=5 run (S, C = cap, G = cap with the stop gate on the
uncapped entry) launched in five cloud sessions at 13:53Z on 11-14 and should land around 21:00Z. Ground rules from
2026-11-10 §0 still hold: backtests run in the cloud; the local container is for QC and short smokes. New since 11-13:
**feat agents don't run local `dune runtest`**: local build + fmt, push, CI runs the tests (user, 11-13;
`memory/feedback_feat_agents_tests_on_ci`).

## 1. Merged this session (2026-11-13 PT evening → 11-14 UTC)

| PR | what |
|---|---|
| #3601 | chain-w `chain.sh`: warehouse `.done` marker outside the verified dir (same latent bug as #3599) |
| #3603 | `pr_gate_status.sh` gh backend paginates the PR file list (#3596 closed) |
| #3604 | `entry_cap_local_range_weeks` (stale-E cap H2′), default 0 = off; caps a long's ticket at the last-N-week high |
| #3602 | price-band binding cell + reading: **CLOSE-AXIS** (Rule 1 branch 3), Rule 2 NO CONCLUSION (immaterial); ledger `2026-11-14-price-band-binding` (Reject, keep-as-axis) |
| #3606 | `perf_long_cells.sh` records cloud cells (Z stamp, per-cell cap, per-seed spec names); 12 cloud rows |
| #3605 | chain-w reading: #3136 decided (no list/warehouse rebuild for the gate basis), #3183 M1–M4 measured, #3109 not run |
| #3607 | perf ledger: spec and cap precedence pinned; six twin-dedupe rows backfilled |
| #3609 | `entry_cap_stop_gate_on_uncapped` (default off): with the stale-E cap binding, stop-gate decisions read the uncapped E; trigger, stop and size stay at E′ (arm G of #3608) |
| #3610 | price-band confirmation read: **NO-BUILD** (C2 top-1000 FAIL, C1 INCONCLUSIVE); ledger `2026-11-14-price-band-confirm` (Reject, keep-as-axis) |
| #3608 | stale-E cap K=5 pre-registration: S / C (cap) / G (cap + uncapped gate), combined C/G outcome table, G check = 0 gate admissions, mark-free committed reads |

**Price-band order, closed** (`memory/project_trait_y_low_price`).
- **Binding (#3602).** The order changes the top 20 on 69 % of open dates, but 95 % of top-20 slots never fund. So it
  re-draws ~84 funded tickets in 26 years ≈ one expected doubler ≈ 0.10–0.18 log, under the 0.2 floor.
- **Confirmation (#3610).** C2 (top-1000, 2000–26) FAIL: median Δ ln −0.280, 1/5 seeds positive. C1 (top-3000,
  2013–26) INCONCLUSIVE: +0.139 vs δ 0.20, drawdown +3.83 pp, trim 1/5.
- **Why.** #3595's +0.348 came from a few cheap names below the top 1,000 by dollar volume (+197 of +205 pooled points;
  MERC, WAL, DINO, REGN, ADMA), replicated across seeds.
- **Design lesson.** C1 replayed #3595's 2013–26 half: same-seed paths re-synchronise within 2–6 years (Seeded hashes
  seed|date|ticker; sizes are NAV fractions). A nested window on the parent's seeds re-measures the parent, so period
  cells must be disjoint (`memory/project_26y_path_noise_floor`).
- **New #3109 specimen.** CERN 2013-07-01 in C2 S-k0: `close` already post-split, `adjusted_close` steps ×2, the
  detector doubled a held position (+9.9 % NAV in a day). No outcome change. No review-pack signal flags it: a
  detector candidate (RV3).

**chain-w in one paragraph** (`memory/project_true_dollar_gate_chain_w`). `true_dollar_volume` moves ~1 % of placed
decisions; the gate's own trades net −0.03 % NAV; the −0.055 log level gap is displacement, 84 % one trade (OPSW 2007).
**Defect D1**: td-full step 2 lets the 650 committed short `data.csv` files shadow the full store (V7/V13/V17 counts in
every run since are partly artifacts; #3610 saw the same). Fix before any flag-on run or V7/V13 comparison.

## 2. In flight

**Stale-E cap K=5, five cloud sessions** (pre-reg `dev/experiments/stale-e-cap-k5-2026-11-14/`, SC_SHA `aab06026`).
Launched 13:53Z 11-14; S → C → G per seed, ~7 h each, resumable per arm. Triggers: k0 `trig_014UXV3ooLzFfew1XGfaBF9u`,
k1 `trig_018wwnd3Kp1iavdFc7evhvZ5`, k2 `trig_01YX4yDJB3MCefcL94tYPKGt`, k3 `trig_01YCPHWEbjogX6XmSaqFih4g`, k4
`trig_01BJmzmbM6s5bKPtDfKVSEKy`. Each pushes `experiment/stale-e-cap-k5-kK` on DONE, or its log on ABORT.
- **Why arm G.** The smoke found 19 of C's 21 capped tickets in 2000 were *admissions*: the lower E pulls the base stop
  inside the 15 % max-stop gate. The screen only measured re-pricing. G keeps the gate on the uncapped E, so it places
  the record's names, cheaper and larger (smoke: exactly S's 19 tickets, 3 capped, 0 admissions).
- **The rule.** C vs S as pre-registered (the flag as built). G vs S under the same bars (the screen's lever). C vs G
  attributes only (Δk_CG = Δk_CS − Δk_GS). A combined table picks the outcome; an ADMISSIONS win is read against the
  stop-width history before any promotion work. The README predicts KEEP-AXIS (screen: +0.05..+0.15 log < δ).
- **Validity gates.** The S tripwire must match #3595's md5 (hard); V6 for C and G against S; G check = 0 gate
  admissions.

## 3. Queue

1. **Stale-E cap K=5 read** when all five branches land (README §Launching, After the runs): gather into one results
   PR, `read/split.sh` on the host, one review pack over the fifteen cells (render it detached: `nohup` packs per cell,
   ~10 min/arm on the host; a run_in_background wait dies at its limit), results-analyst (opus), spot-check,
   qc-results.
2. **D1 td-full shadowing** (chain-w): fix in the chain template / td-full staging before any `data.csv`-reading run;
   file it under the data umbrella (#3384/#3239) with its closing run.
3. **#3109 CERN specimen**: add it to the issue (phantom split on a held position; `raw_confirm_min_share` would reject
   it), plus a unit test for an exit order filled on a split's effective date (the 2013-07-01 exit sold the pre-split
   count and left the rescaled remainder open).
4. **#3610 README nits** (qc-results, non-blocking): l.519 and l.1004 say V7/V13/V17 counts match within pairs (they
   differ by path; the shadowing files are the same); §Why 3 calls the both-placed channel cash (mostly AVGO).
5. **Harness gap**: the goldens check's docstring cross-reference flags goldens for a brand-new default-off field named
   in `[brackets]` (#3604 and #3609 worked around it with `{i name}`). File an issue.
6. Carried: #3587 `.mli` wording; SPY refresh ends 2026-09-28; the 38 near-tightening stops; dangling-doc linter;
   #3578 QC gaps; `pr_gate_status.sh` gh backend fails open at GitHub's 3,000-file cap (add a `length >= 3000 →
   sentinel` check).

## 4. Decisions waiting (deferred to 11:00 PT)

- **Committed artifacts vs EODHD terms (the repo is PUBLIC).**
  - The arm-G agent and qc-results found that committed results let anyone back out raw closes. The main route is that
    every results PR's per-arm `equity_curve.csv` + `trades.csv` reveal daily closes: while one position is held, ΔNAV
    net of interest = qty × Δclose (confirmed to ~1 cent). Smaller routes: marked read lines for open positions
    (#3610 `report-1.txt:90`, TWLO, open in C1 S-k4: entry price × pnl % gives its 2026-06-25 close).
  - Options: **(A, recommended)** keep the practice: these are derived records of our own simulated trades, not the
    feed, and the repo has always held them. **(B)** strip prices going forward: chain templates commit returns-only
    trades, a coarsened or NAV-free equity curve, and reads mask open rows; costs traceability for every future
    results PR. **(C)** B plus scrubbing history, which rewrites a public repo and breaks every PR link.
  - Applied meanwhile (reversible): #3608's read prints no mark-derived value (open legs out of every printed sum and
    line; bars print pass/fail only). Not changed: #3608's superseded commit fe4d7ca89 and qc-results review
    5904331801 quote one recovered close (EOG 2000-12-28); squash kept it off main, the PR page keeps it.
- **The default checkout is stale** (still). `/Users/difan/Projects/trading-1` sits on `kkrwwqyn` (unpushed budget
  files `dev/budget/local-2026-11-03.json`, `-11-04.json`) on `b54e44ea9`; its `pr_gate_status.sh` routes `.tsv`
  results PRs to qc-structural (pre-#3592). Options: (A, recommended) push the two budget files as a docs-only PR and
  move the checkout to main; (B) rebase `kkrwwqyn` onto main, keep it local; (C) leave it. A and B touch your
  unpushed commit.
- **Agent standing rules still say "scoped local dune runtest".** You asked for tests on CI; briefs say so by hand.
  Option: a harness PR changing the feat-* standing rules block (and `agent_standing_rules_check.sh`). Recommended,
  reversible; waiting only because it changes every agent's definition.
- **Arduino worktrees, if you want disk back** (host 93 % used, 34 GiB free): `~/Projects/wt` holds 814
  Arduino-Source worktrees, 48 GB. Not touched; another project's sessions own them.

## 5. Housekeeping done

- Deleted `experiment/price-band-binding-results` (abort log only) at `e4d176c037f85b0ed23a14b60a71e5b92cb78a83`;
  restore with `git push origin e4d176c037f8:refs/heads/experiment/price-band-binding-results`.
- Disk: removed ~2.2 GB of merged-PR workspaces from the session scratchpad; jj workspaces forgotten.

## 6. Lessons

- **A deciding input needs its own sanity check.** The binding rule turned on a −0.1 pp mean whose D/T coverage class
  came from `STORE_END` = the latest bar of an uneven store. Pre-registrations: give mean-difference clauses a
  tolerance or a paired statistic, lift bars a minimum count, and class coverage against an end date every name
  reaches.
- **Smoke a mechanism's admissions, not just its fills.** The stale-E screen replayed only trades the code took, so it
  could not see that a lower trigger admits names at the stop gate. The one-year smoke caught it before 35 cloud hours
  were spent; arm G now separates the channels.
- **Results PR bodies name the memory updated** (qc-results R9 failed #3602 and #3595 on it).
- **The perf ledger silently skipped every cloud cell for two weeks.** A collector that drops unknown formats
  should say so; worth a "0 rows from a log with RESULT lines" warning.
- **Long host jobs need `nohup`, not `run_in_background`.** The review pack (~3 h for 20 arms) was killed at the
  background limit and could not resume.
