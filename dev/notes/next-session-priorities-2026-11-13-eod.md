# Next-session priorities — 2026-11-13 EOD (supersedes 2026-11-13)

The price-band tiebreak read NOT LIVE as written, yet P beat S in 5/5 seeds. The user judged that real and approved
two follow-ups, which are **running on cloud now**: a one-cell binding diagnostic and two confirmation cells (K=5
paired each). Main CI green at `04ca2ff0b`. Ground rules from 2026-11-10 §0 still hold: backtests run in the cloud;
the local container is for QC and short smokes only (the user asked twice today whether the local VM was busy).

## 1. Merged today (since the 11-13 morning handoff)

| PR | what |
|---|---|
| #3592 | results-only lane accepts `*.tsv` (gate script, its test, mutation test, `pr-merge-gates.md`, `qc-results.md`) |
| #3584 | chain-w artifacts (W0, Wtd, #3183), body carries the W0 ≠ rk-k0 parity trace (#3475 dedupe + #3483 fill order) |
| #3595 | price-band K=5 results: **NOT LIVE as written** (≤ $14 entry share 1.219× < 1.3×); full reading in the README §Results |
| #3594 | entry-timing screen: only the stale-E cap survives; 37–66 % of its gain is position size, not price |
| #3597 | pre-registration: one S-k0 `--emit-candidates` cell for the exact binding rate + the breakout sub-gate read |
| #3599 | chain fix: the warehouse `.done` marker moved outside the verified dir (it aborted the first #3597 launch on resume) |
| #3598 | pre-registration: confirmation cells C1 (2013–26, top-3000) and C2 (top-1000, 2000–26), K=5 paired each |

**The price-band read in one paragraph** (`memory/project_trait_y_low_price`). P (= record + `Price_band_seeded`)
beat S in 5/5 seeds, median Δ ln(1+R) +0.348, about 2.2–2.4 SD under a shared-draw bound (1/252 is only a floor:
the five P cells share one fixed cross-band order). The ≤ $14 band carries ~82 % of the one-arm gain. About 70 % of
the gap is 2010–12 entries (MERC, ATML, WAL, DINO, REGN) plus ADMA 2023. 2018–23 went against P in 5/5 seeds, and
median max DD was +5.6 pp deeper. The liveness proxy (entry share × 1.3) was the wrong measure: the band order changes
the top-20 on 67 % of the Fridays both arms record, mostly by demoting ≥ $33 names.

## 2. In flight (cloud)

**Binding diagnostic (#3597)** — `PB_SHA=645065bb2`, one S-k0 cell with `--emit-candidates`, ~6 h from 03:25 UTC.
- Session `session_013VUubi8cMTgUKsKZPiU76x` (trigger `trig_012Ta2TaVpEnqWBBuYjuGwPk`); 16 GB host.
- Pushes `experiment/price-band-binding-cell` (`results/cell/`) on DONE or ABORT.
- `experiment/price-band-binding-results` holds only the first launch's abort log (resume bug, fixed by #3599);
  delete that branch once the cell lands.
- The read runs inside the session; `rules.txt` prints the pre-registered outcome mechanically
  (Rule 1: CLOSE-AXIS / PARK / FRESH; Rule 2: UNDERPOWERED / DIAL-STUDY / NO CONCLUSION / NOTHING).

**Confirmation cells (#3598)** — `PB_SHA=04ca2ff0b`, one session per seed, each runs C1 S, C1 P, C2 S, C2 P
(~5.5 h from 03:41 UTC). Triggers: k0 `trig_01MLpFQz7Phk9bexyPkbAwHN`, k1 `trig_017v9T2nmFcY76qLNu9rNjPR`,
k2 `trig_01JxnEpew3dFHJxdXeFAGR57`, k3 `trig_01EXk5JG9oq1rXeMawtV8MSc`, k4 `trig_01Un8Bf9hxLPShitLRaKBtFs`.
Sessions (all on 16 GB hosts, chains launched 03:41 UTC under `setsid nohup`): k0 `session_013VUubeRLaBDHszQXUThkfP`,
k1 `session_013VUubgK8pKAwQXR2pxEaRL`, k2 `session_013VUubhozB1pNMfzhGMh7x7`, k3 `session_013VUubgKSfscFfkVfHyfMZ5`,
k4 `session_013VUubeiMm728Sif2STEpYi`. Each pushes `experiment/price-band-confirm-kK` with `results/kK`.

Check a session: `RemoteTrigger list_runs <trigger>` then `get_run_log <session>`. Correct a live session with a
`persist_session` trigger (`docs/howtos/claude_cloud_sessions.md`).

## 3. Queue

1. **Binding diagnostic results PR.** Commit `results/cell/` (results-only), read `rules.txt`, spot-check, qc-results.
   It is mechanical (pre-registered ladder); a results-analyst pass is still due for the "why" if Rule 1 says FRESH.
2. **Confirmation results PR.** Gather the five branches; run `read/decide.sh` per cell; review pack for one
   seed per cell; `results-analyst` (opus, max) applies the #3598 rule (liveness B ≥ 33 % and G ≥ 40 pp → return
   median Δ ≥ max(0.20, m_S), ≥ 4/5 → arm-median DD ≤ 3.0 pp → trim-3 concentration ≥ 4/5); spot-check; qc-results.
   Both cells PASS → ESCALATE (promotion candidate: walk-forward with DSR and the grid still required; nothing flips
   a default). If #3597 says CLOSE-AXIS or PARK while #3598 says ESCALATE, nothing escalates automatically: raise it
   with the user. A 100+-file results PR needs `PR_GATE_STATUS_BACKEND=curl` until #3596 lands.
3. **Stale-E cap (#3594)**: default-off flag + K=5 paired 26y run. The test must report the price/size split
   (`results/sizing.txt` method), because a cash-limited book can eat the size half.
4. **chain-w reading (#3584 merged)**: review pack, `perf_long_cells.sh update`, the T1–T3 read; the README §Log
   should carry the parity trace. Also fix chain-w's `chain.sh:78/:81` `.done` marker (same latent bug as #3599).
5. **#3596**: gh backend of `pr_gate_status.sh` fails closed at 100+ files; paginate with `gh api --paginate`.
6. Carried from 11-11 / 11-13: #3587 `.mli` wording follow-up; SPY refresh ends 2026-09-28; the 38 near-tightening
   stops; dangling-doc linter; #3578 QC gaps.

## 4. Decisions waiting (deferred to 11:00 PT)

- **The default checkout is stale.** `/Users/difan/Projects/trading-1` sits on `kkrwwqyn` (budget files
  `dev/budget/local-2026-11-03.json`, `-11-04.json`, unpushed) whose parent is `b54e44ea9`. Agents read rules and
  their own definitions from it, so a qc-results reviewer refused #3597 as "not results-only" (it saw the pre-#3592
  lane). Options: (A, recommended) push the two budget files as a docs-only PR and move the default checkout to
  main; (B) rebase `kkrwwqyn` onto main and keep it local; (C) leave it and keep telling reviewers to read rules
  from `origin/main`. A and B touch the user's unpushed commit, so they wait for the user.

## 5. Lessons recorded today

- **Liveness from the mechanism's footprint**, never a downstream share × multiplier (price-band repeated the
  floor-nearest error; `memory/project_trait_y_low_price`).
- **Chain markers live outside verified dirs** (#3599); a resume path that never ran is untested.
- **Results lanes**: `.tsv` is an artifact (#3592); K=5 results PRs exceed the gh backend's 100-file read (#3596).
- **Reviewer worktrees need unique paths**: two qc-results agents collided in `scratchpad/wt` today.
- **Session time**: the review pack takes ~1 h per 10 cells on the host; run it detached (`nohup`) so the 1 h
  background cap does not kill it.
