# Next-session priorities — 2026-11-14 EOD (supersedes 2026-11-14)

The stale-E line is closed (#3621, NEITHER PASSES). The program turns to the axis observatory
(`dev/plans/axis-observatory-2026-11-14.md`, user 11-14): keep paired runs going and read each arm as its log-NAV
gap to the baseline over 2000–2026, not as an endpoint. P1 of that plan, a one-cell gate funnel, is running in the
cloud. Ground rules unchanged: backtests in the cloud, local container for QC and smokes, feat agents build + fmt
locally and let CI run tests.

## 1. Merged this session (11-14 PT afternoon → evening)

| PR | what |
|---|---|
| #3615 | price-band README nits |
| #3616 | goldens check skips brand-new fields (#3614 closed) |
| #3618 | budget files local-2026-11-03/04 |
| #3619 | build agents run tests on CI; standing-rules pins |
| #3620 | CLAUDE.md / orchestrator pre-flight / goldens limitation follow tests-on-CI |
| #3621 | stale-E cap K=5 read: **NEITHER PASSES** (C NO-BUILD by the harm bar, G INCONCLUSIVE by the D bar); price files in `dayfine/trading-results` b46c88db |
| #3622 | plan: axis observatory |
| #3623 | Friday pipeline demo (folded #3624's anti-drift test): synthetic one-Friday trace, nine stages, prose built from the run's config; `dune exec trading/weinstein/strategy/friday_demo/bin/friday_demo_main.exe` from `trading/` |
| #3625 | pure `Entry_stop_check.evaluate` + `?on_walk_report` (unspent long cash, held set, stop-check closure) |
| #3626 | `candidates.sexp`: per-row `rank`, `walk`, `shadow` (upper-bound buyability for top-N-cut names); per-week `tickets_placed`, `long_cash_left_pct`, `long_resting_reserved_pct` |
| #3628 | gate-funnel pre-registration (`dev/experiments/gate-funnel-2026-11-15/`) |

Filed: #3627 (`Matchers.float_equal` passes when either side is NaN).

## 2. In flight

**Gate-funnel cell**, cloud routine `trig_01EGdsscqsgyTNNLHwbG7h5T`, scheduled 2026-11-15 06:48Z, build GF_SHA
`47b7c476a` (#3628's merge). One record S k0 26y cell with `--emit-candidates`, read in-session, about 3–7 h. It
publishes mark-free outputs to branch `experiment/gate-funnel-results` and price-bearing ones to
`dayfine/trading-results` main (first cloud push there: check the PUBLISH private line).
- Validity: tripwire md5 = #3602/#3595 S k0 (also the 26y proof that capture changes no trade); SK1–SK3 hard-gate the read.
- Rule 1 (gate-before-cap): CLOSE if X net · f < 25; else REFINE, BUILD only on three bars; else PARK. Prior: CLOSE
  (09-22 top-N 40: slots and cash bind, not candidate supply).
- Rule 2: ranking re-test after the #2380 RS fix (A+ vs A, both halves, ≥ 2 pp and ≥ 1.3× monster rate).
- Descriptive: the funnel by year, per-gate counterfactual rides, the macro counterfactual as a labelled proxy.

## 3. Queue

1. **Gate-funnel read** when the branch lands: results PR from `experiment/gate-funnel-results` naming the
   trading-results commit, `results-analyst` (opus), spot-check, `qc-results`. Quote the README's rule wording, not
   `rules.awk`'s ("gate-before-cap dead" there is cosmetic, per qc-results 5909442402).
2. **Observatory P2**: `obs_read.sh` (D(t) curves, yearly increments, step attribution), `surface.tsv`, the curves
   page, the baseline-drift lane. Order the P3 dial queue from the funnel.
3. **Code health**: `screener.ml` is at 498/500 lines; extract the candidate-evaluation block (`_evaluate_candidates`
   and `rank_survivors`) into its own module before anything else touches the file.
4. **#3627** float_equal NaN.
5. **Chain templates** push price files to `dayfine/trading-results` (cloud access works since 11-14; the gate-funnel
   chain is the first to do it; fold its `collect`/`publish` split into the template).
6. Carried: pack render blank-slice check (`review_pack_render.sh` + test); #3613 split resting orders; stop traded
   days before the exit fill (TRW-wein-742, #3075 class); the two stale-E transferable rules into the rigor rule and
   the screen-rigor skill; entry-timing-screen README estimand note; orchestrator CI pre-flight fallback; D1 td-full
   shadowing fix; #3587; SPY refresh; 38 near-tightening stops; dangling-doc linter; #3578; `pr_gate_status` 3000-file
   sentinel; the #3610 README / 11-14 handoff wording that cites "sub-top-1000 names" as a reason against the
   price order (user 11-14: scope, not a defect).

## 4. Decisions waiting (deferred to 11:00 PT)

- **Frozen pre-registration text on main quotes a few smoke-year fill prices** (`dev/experiments/stale-e-cap-k5-2026-11-14/README.md`,
  from #3608; qc-results 3621 note 5). Options: (A, recommended) leave it, as history before 11-14 is not scrubbed;
  (B) redact those numbers in place with a note, which edits a frozen pre-registration (harmless to its rule). Your call
  under the data-terms decision.

## 5. Lessons

- **A stacked pair squash-merged needs its child re-reviewed anyway**, so fold a small child into its parent when the
  parent is going back for rework (#3624 into #3623 saved a cycle).
- **Tests named for a contract can be vacuous.** Two reviews found pins that never exercised their path (#3626's
  byte-identity test cut no names; the Seeded date was unpinned). Ask reviewers to run the mutation, not read the test.
- **Check what a cash figure nets before a screen reads it.** `long_cash_left_pct` ignored resting tickets on the
  default path; the 09-22 top-N result says resting tickets are the mechanism, so the screen would have overstated
  free cash. The reserve field fixed it before the run.
- **A demo's prose is a contract.** The first Friday trace was numerically right and wrong in five sentences; building
  the prose from the run's config fixed the class.
