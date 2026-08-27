# Next-session priorities — 2026-08-27 (bug burn-down)

Supersedes `next-session-priorities-2026-08-25-post-overnight.md`. User
directive for this session: **burn down low-to-medium complexity open bugs.**
Long arcs (#2405 clock re-flip multi-cell run, #2489 decision, #2403 residual
soak flips) stay parked unless explicitly picked up.

## State at session start (verified 2026-08-27)

- **Main GREEN** — 4 consecutive CI successes since the one red at `42c66a29`
  (2026-08-26 11:03, cause = #2564's racy pipefail, self-cleared next commit).
- **Zero open PRs.**
- Watchdog **#2562 still open + stale** → close with recovery comment (P0,
  dispatcher-side, done this session).
- Since the 08-25 handoff, 08-26 sessions shipped: #2549 #2550 #2551 #2552
  #2553/#2557 #2554 #2561 (closed #2380) #2563 #2568 #2569 (unblocks #2405).

## The burn-down (this session)

Wave 1 — three agents, `isolation: worktree`, cap 3, no backtests running:

| # | Issue | Scope | Agent |
|---|---|---|---|
| 1 | **#2564** `record_qc_audit_test.sh` racy `echo \| grep -q` under `pipefail` — 32 sites, latent random red on the REQUIRED `build-and-test` gate; fired on main at 42c66a29 | Replace all 32 pipe sites with herestring/bash-substring; guard note near `set -euo pipefail`. Check whether #2440 (scenario 22 CI-only fail) is the same class — if plausibly yes, say so on #2440. | harness-maintainer |
| 2 | **#2565** `test_csv_snapshot_builder_cleanup` subject `.exe` not a build dep — 2 tests assert on a shell error string when missing | Declare dune dep; make `_run_subject` fail loudly on 126/127/missing binary. | feat-backtest |
| 3 | **#2559** RSS digit-fusion unfixed in 5 sibling scripts incl. `perf_tier1_smoke.sh` (backs REQUIRED PR gate) | Extract `_parse_gnu_time_rss` to `dev/lib/`, source from all 6 call sites (incl. the already-fixed postsubmit script), generalize the RED-verified smoke test to cover the shared helper, correct the stale 12.4 GB explanation in `golden-runs-sp500-15y.yml` + widen the caveat sentence in `container-capacity-scheduling.md`. | harness-maintainer |

Wave 2 — after a wave-1 slot frees:

| # | Issue | Scope | Agent |
|---|---|---|---|
| 4 | **#2558 + #2570** `goldens_affected_check` matching-side blind spots (one PR, two closes) | (a) zero-override default change ⇒ affects-ALL, FAIL and list full golden set (#2558); (b) default-VALUE-change ⇒ goldens overriding at the new value are NOT affected, non-overriding goldens ARE — emit distinct `FAIL (default-flip: N goldens inherit)` (#2570). `paired-run-done` label stays the resolution path. Replay #2555 and #2569 diffs as fixtures — both must FAIL post-fix. | harness-maintainer |

QC loop per `pr-gate-loop.md`: CI green → qc-structural → qc-behavioral →
merge, batched by phase, verdicts at tip. All four PRs touch code — full three
gates, no docs-only skips.

## Explicitly out of scope this session

- **#2567** silent-null effectiveness linter — design work (linter or QC row),
  medium-large; queue behind the burn-down.
- **#2382** notional/exposure across-tick leak — measure-before-build research,
  not a bug fix; needs the bind-rate count first.
- **#2394** long-cascade RS phase — its own condition ("only once some config
  arms `min_rs_normalized`") not yet verified true; check before building.
- **#2547** custom-universe GHA flake — needs flake-rate data accumulation, not
  a code fix yet (artifacts now uploading since #2549).
- **#2539** SC-code baseline burn-down — mechanical but large; backlog.

## Parked arcs (next sessions)

1. **#2405** clock re-flip 0→26 + 156w candidate + SMCI/freeze adjudication —
   preconditions ALL met (#2569 shipped the fill-model default). Needs the
   multi-cell paired-run day: container-exclusive, hours. Do not start under
   agent waves.
2. **#2489** §2.2/arc reclassification — ASKABLE; audit data landed in #2568.
3. **#2403 residual** — shared live-base include (~200 lines), soak flips
   (custom gated on #2547 flake understanding).
4. P4s: #2407, #2409, #2006, #2406; #1729 (P3/L data); #2408 (P1 research
   surface, needs container-exclusive time).
