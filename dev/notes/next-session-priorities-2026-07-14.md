# Next-session priorities — 2026-07-14

**Supersedes** `next-session-priorities-2026-07-12.md` (its C1-C6 queue is DONE;
P1-P4 research items carried below). Main green.

## What the 07-13/14 marathon shipped (context)

Ten merged PRs + six labeled 28y record runs. Full writeups:
`dev/notes/dedup-record-rerun-2026-07-13.md` (new record basis) +
`dev/notes/armed-run-matrix-2026-07-13.md` (the matrix). Compressed:

1. **C1-C4 correctness sweep merged** (#1939 asset-type blocklist, #1940+#1946
   twin dedup v1+v2 returns-basis, #1941 Insufficient_history label, #1942
   export-join + position_id). **Dedup re-based the record**: 83 duplicate-feed
   groups removed; honest baseline now realized +1,037%/14.4% CAGR vs SPY TR
   +706% (pre-dedup +1670%/+6885% superseded).
2. **Validator at full coverage** (#1947 audit join by position_id; joins
   1171/1171 vs 0/1140 before). V-checks now discriminate configs: V5↔#1942,
   V6↔dedup, V7↔min-hist, V8↔MA-gate all verified both directions.
3. **Armed-run matrix**: ext-stop insurance acceptance PASS (8/8 parabolic tops
   banked, AXTI $59M, Sharpe .68→.82, MaxDD 40.9→32.3); MA-gate surgical +
   (removes AIR-2020 class, V8→PASS); min-hist-520 NOT armable (halves return —
   deletes the resistance signal wholesale on 52-110-bar panels); D = A+B
   additive = **proposed convention**; E long-short = leverage artifact
   (shorts $0.0M / 43 trades; long exposure >NAV 269 wks, peak 158% — dead
   `max_long_exposure_pct` knob).
4. **Audit tooling**: R6 plunge-buy fixed (was a stub; AIR-2020 pinned),
   decision-quality quartiles fixed, `--html` interactive report (#1956 —
   check merged; was QC-double-approved in the CI rerun lottery at session end).
5. **CI diagnosis**: the day's 50-90% build-and-test failures = owl tuner tests
   SIGILL / `Owl_lapacke.potrf` on part of GitHub's runner fleet — **#1955,
   needs human PAT** (portable owl build flags or pinned runners). #1954 merged
   (find-race noise). Interim: rerun on the documented signature.

## P0 — arming package (user-aligned, execute on sign-off)

Per the 07-14 discussion: NO code-default flips; arm via explicit config.
1. Ledger entry: insurance-ACCEPT for `extension_stop(2.0, 0.25)` (basis =
   armed-vs-off event-level record pair, #1695 precedent, WF-CV powerless at
   ~1% event rate) + confirming-evidence note for `reject_declining_ma`
   (WF-CV already in #1775 ARM-FOR-BROAD).
2. Add both overrides to the record-convention staged scenario + the live
   weekly-review config.
3. Cheap robustness backfill: one **sp500-basis armed-vs-off cell** for
   ext-stop (rules out top-3000-specific artifact; ~2 short runs).

## P0b — long-short realism precondition (gates any Run-E conclusion)

1. Wire `max_long_exposure_pct` enforcement into the entry walk (envelope
   knobs are DEAD — `check_limits` zero callers, memory
   `project_envelope_knobs_dead`). Default = no-op/uncapped (R1; long-only
   goldens bit-identical). 2. Pin the margin convention (short proceeds → cash
   vs long buying power up to cap). 3. Re-run E with long ≤100% NAV pinned.
   Expectation: lands near D + small hedge term (shorts made $0).

## P1

- **Resistance history feed** (the real false-virgin fix; min-hist label stays
  default-off): (a) live weekly-review warehouse → ~520 weekly bars (cheap,
  fixes CWST-class live text); (b) backtest = resistance-specific deeper
  window, perf-spike FIRST (NOT global lookback_bars ×10). Then one armed run
  quantifies honest-virgin vs no-signal (Run C says signal removal costs
  ~half the return; this isolates the false-virgin share).
- **#1956 merge completion** if the CI lottery outlasted the session
  (auto-merge armed; QC double-approved at tip 6aaf9453f).
- **#1955 CI fix** — human-gated (user PAT): portable owl build in the GHA
  opam cache or pinned runner generation. Until then rerun-on-signature.

## P2 — research queue (carried from 07-12, unchanged priorities)

- **Trader-preset bundle audit + WF-CV** (presets as wholes per
  weinstein-faithful-core W3; plan `weinstein-trader-investor-presets-2026-05-31.md`).
- **Floor-quality P1b step 3**: SPY-sleeve lens screen vs TR-SPY
  (`Breaker_spy_sleeve` #1913; melt-up-lag anatomy made this the structural
  bull-year answer).
- **decision_audit Phase-2**: forward-return counterfactual of cash-REJECTED
  vs funded (NVDA skipped 6×; new evidence: AIR's three entries were all in
  bad windows, never late-2016/late-2022 — capacity-at-signal keeps surfacing).
- **P3 grind-weeks exposure** (carried).
- **P4 faithful per-week universes** (M6.6 design + cost doc; GME-class
  capture loss).

## Lower-priority follow-ups (accumulated, `[non-blocking]`)

- V6 known-false-positive allowlist in validator config (deferred from #1953;
  ASB/CDX_old + BALL/TAP).
- Stale re-entry gap: CY re-bought 2020-04-25 on 10-day-stale bars then
  stale-exited again — entry-side staleness check (tiny PnL impact).
- Arm `ATB.curated` for the LIVE universe build (+ General::Type enrichment
  feed later); wire `fetch_finviz_sectors` so live picks regain sector spread.
- C6 leftovers: `scenario_runner --validate` post-step; weekly-picks
  validation reuse.
- QC advisory carries: render-substring test for the validator coverage line;
  R6 threshold config-flip test.
- goldens-small still at concentration 0.14 (old carry).
- Memory export refresh (`sh dev/scripts/export-memory.sh`) — new memories:
  `project_rename_twin_dedup_returns_basis`, `project_extension_stop_acceptance`.

## Standing constraints (unchanged)

NO reversal timing; entry-selection/scale-in/reallocation/stop-tuning closed;
Weinstein spine fixed; comparators TOTAL-RETURN; horizon-sweep/rolling-start
before tail-dependent verdicts; container long runs solo; WIP-push ≤30 min.
New: CI failures matching (0 `FAIL:` + SIGILL/potrf in tuner tests) = #1955
runner lottery, rerun; min-hist label floor stays OFF everywhere; Run-E-class
long-short numbers are NOT quotable until P0b lands.
