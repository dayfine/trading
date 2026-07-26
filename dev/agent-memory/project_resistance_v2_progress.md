---
name: resistance-v2-progress
description: "resistance-v2: BUNDLE (w30+vc+floors-zero) promotion chain running — sp500 cell CONFIRMS (w15 .737/w30 .570 vs .396, beats w-only grid); lever (f) age-banded hist CODE MERGED #2015 (default-off, v4 rebuild gated); stages 2/3 (broad-2011 + rolling-start) pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: 16236ad0-8d54-442f-9ba7-9f11f9bbadf2
---

2026-07-15 session shipped the resistance-v2 core (plan #1974,
`dev/plans/resistance-v2-supply-sketches-2026-07-15.md`; track file of
record `dev/status/resistance-v2.md`):

- **#1975 PR-B merged**: 24 sketch fields appended to Snapshot_schema
  (13→37; `Res_max_high_{130,260,520}w`, `Res_bars_seen`, `Res_hist of int`
  ×20), computed per-day by `Snapshot_pipeline.Resistance_sketch`. No
  format-version bump — schema-hash gate. **Every local warehouse is now
  stale (dedup-v2 28y included); rebuild required before any snapshot-mode
  run.** Virgin test is `breakout >= Res_max_high_520w` (>=, not >) —
  bit-equal to v1 incl. tie, parity-pinned after a qc-behavioral rework.
- **#1979 PR-C merged**: `Resistance_supply` — continuous score [0,1]
  (proximity-weighted hist mass sat. at 8 bars; horizon floors .4/.25/.1
  only when hist blind; virgin 0; Insufficient 0.5 so unknown ≠ virgin).
- **#1982 PR-B2 merged**: deep-history feed (`compute_windowed`,
  `?deep_bars` sketch-only, `-sketch-deep-days` 3650) — 13 columns
  bit-identical basis-guard pinned.
- **#1983 PR-D merged**: `w_overhead_supply : int option` default None
  replaces binary `_resistance_signal` with `round(w×(1−score))` when
  armed; `Resistance_sketch_reader`; live CSV path stays v1 (get_sketch
  → None). 1 QC rework (replace-not-add + reader-guard pins).
- **Warehouse rebuild launched 07-15 EOD** (detached in container):
  `/tmp/snap_top3000_dedup_v3_sketch`, log `/tmp/wh_rebuild.log`.
- **PR-E RAN 07-16: false virgins were LUCK** (not structure). Surface
  w_overhead_supply {−15,0,15,30} + baseline, 13×2y folds top-3000
  record convention on dedup-v3 sketch warehouse: MONOTONE improvement
  with positive weight (Sharpe .691→.860, MaxDD 16.6→14.0, w30 wins
  return too); prefer-overhead refuted; w=0 ≈ neutral. Verdict
  Inconclusive (t≈1.5 n=13 pre-deflation; winner on boundary) — no
  promotion, mechanism stays default-off. Follow-up: extend {45,60} +
  min_history/insufficient axes. Ledger
  2026-07-16-resistance-supply-weight-surface. Third path-lottery
  artifact confirmation: single-path 28y deltas are not decision-grade.
- New gotcha: PR with mergeStateStatus DIRTY runs NO pull_request
  workflows ("no checks reported" ≠ CI outage — rebase first).

Gotchas hit: qc-structural misses nesting linter (again — #1979 caught by
CI only); status files need `## Status`/`## Last updated:`/`## Interface
stable` headings with BARE values; `_index.md` Next-task ≤160 chars.

**FINAL (07-17): grid 3/3 CONFIRM → mechanism ACCEPT.** Home curve
concave, peak w≈45 (Sharpe .691→.897→.772@60); sp500 cell w15 .623 vs
.396 (optimum shifts lower on narrow breadth); 2011 cell w30 .825 vs
.619 with fold-σ collapse .566→.223. Robust value **w=30**. Ledger
`2026-07-17-resistance-supply-confirmation-grid`. **Promotion =
HUMAN-GATED**: 28y single-path w30 +1,991% vs baseline +7,914% (same
1,187 trades, DD 29 vs 32.3) — the penalty forfeits the crash-recovery
monster cohort. AXTI forensic: score CORRECT at the $2.18 entry (97/130
recent weeks overhead); virgin at $11-17 in Dec-25/Jan-26 but
stale-inadmissible (early_stage2_max_weeks) → "supplied monsters:
denied at birth, stale at redemption." Decision inputs: rolling-start
terminal-wealth distribution; possibly build virgin-crossing
re-admission first. Five levers designed default-off (track file §3).

**07-17 PM divergence forensic** (note
`dev/notes/resistance-supply-divergence-forensic-2026-07-17.md`):
"identical 1,187 trades" was WRONG — count identical (capacity-bound),
book 69% different (367/1,187 shared; 820 swapped each side). Cohort
P&L: baseline-only +$64.7M of which **AXTI = $62.6M**; w30-only +$7.0M
→ ex-AXTI w30's replacement book WINS (+7.0 vs +2.1, better DD).
Equity-ratio timeline: w30 loses ONLY in post-crash recovery windows
(2000-04 ratio→0.70; 2020-26 0.99→0.26 incl AXTI), and outperforms
+2.4pp/yr for 2005-2019 (ratio 0.70→0.99). Cost = one regime class +
one lottery ticket, mapping 1:1 to the regime-softener and
virgin-crossing levers. Rolling-start distribution sweep launched
07-17 PM (`/tmp/sweeps/rolling-start-promo/`, 13 paired biennial
starts, ~15-18h; twin scenario
`test_data/backtest_scenarios/staging-rolling-start/top3000-2000-2026-rc-w30.sexp`,
uncommitted).

**07-18 session — decision inputs executed:**
- **Rolling-start (input #1)**: w30 wins 9/12 paired biennial starts
  (median +1.15pp CAGR/yr, MaxDD better ALL 12), 3 losses −5.8..−8.5pp/yr
  = exactly the recovery-window starts (2000/2008/2010). Systematic
  regime tail, not luck. Note `resistance-supply-rolling-start-2026-07-18.md`.
- **vc lever (input #2)**: #1997 built (Stage-2-gated staleness bypass) —
  run 1 NEVER fired: `is_virgin` needs breakout ≥ max_520w but the sketch
  max INCLUDES the current week's own high → unsatisfiable while climbing
  (AXTI Jan-06: close 20.17, max 20.345 = own high, hist_sum 0). Fix
  #2002 (3-pass QC): arm = `is_virgin || is_clear_of_supply` (all hist
  bins zero). Run 2: **vc-only $88.2M > baseline $80.1M** (+10%, Sharpe
  equal, DD lower) standalone; **w30+vc $21.6M ≈ w30** — AXTI STILL
  blocked: redeemed names score the `recent_far_floor` 0.4 (own run sets
  max_high_130w) → 18/30 pts → lose cap-20 race. **Floor axis (lever c,
  + recent_far_floor) = the pairing dial.** Note
  `virgin-crossing-pair-runs-2026-07-18.md`; PR #2004.
- Also merged: margin M1b-1 #1998 (entry-walk leverage, default-off;
  M1b-2 A1 seam = decision items in margin-realism.md).
- **Overnight: vc-flag WF-CV** on home grid (13×2y, flag isolated,
  /tmp/sweeps/vc-flag-broad) — decides if vc-only's +10% is real.
- Ops: harness "worktree" for feat agents = GIT worktree (jj boilerplate
  gets overridden — margin agent worked pure-git, fine); jj rebase of @
  orphans uncommitted files into parked commits (recover via
  `jj restore --from <parked>`); QC self-approve blocked on own PRs →
  verdict lives in comment body.

**07-19 — the surfaces landed; candidate = the BUNDLE:**
- **vc-flag WF-CV: ledger REJECT** — inert 9/13 folds (bit-identical);
  2y fold resets rarely complete the stale-then-redeemed setup. LAW:
  fold-reset WF-CV under-powers rare long-memory admission levers —
  use contiguous/rolling-start lenses for that class.
- **floor-axis surface: Inconclusive-promising** — under w30+vc,
  floors 0/0/0 recovers +5.2pp mean return at equal DD (10/13 Sharpe
  wins vs baseline 0.827/36.2%/14.1 vs 0.691/31.7%/16.6); half-floors
  worst of three (threshold-shaped harm). The horizon-floor staircase
  WAS the redeemed-cohort tax; measured-empty hist > max skepticism.
  Honest: plain w30 keeps best mean Sharpe 0.860.
- **Promotion memo** `resistance-supply-promotion-memo-2026-07-19.md`:
  option B = bundle grid (sp500 + 2011 cells) + bundle rolling-start
  (recovery-window repair check) then promote the BUNDLE as a unit;
  bare w30 not recommended. Ledger entries + memo + handoff = PR #2012.
- Lever (f) age-banded hist (20 price × 4 age bands, score-time
  weights) recorded in track §3(f); moderate signal, gated on bundle.
- Margin: M1b-2 #2005 (portfolio debit, Option A user-approved) + M2
  #2010 (maintenance force-reduce, weakest-first incremental) merged;
  M3 squeeze next. Tax lens issue #2006 spec'd (ST 35 / LT 23.8 /
  carryforward; Run D $80.1M → $26.84M reference; strategy is
  accidentally tax-efficient — stops harvest losses).
- Ops: GitHub auto-merge won't self-update BEHIND branches (cron
  summaries strand armed PRs — self-healing monitor pattern); agent
  kill -TERM'd a 0%-CPU dune parent = fork-pool coordinator (nearly
  killed a 6h surface) — briefs must say KILL NOTHING during sweeps;
  walk_forward "running variant" log lines batch ahead of completion.
v3 warehouses certified (28y baseline = Run D to 13 decimals; sp500 v3
built); dedup-v2 deletable. [[project_edge_is_the_fat_tail]]
[[false-virgins-load-bearing]]

**07-19 PM autonomous session — bundle chain + lever (f) landed:**
- **Bundle-studies chain launched** (sp500 grid → broad-2011 grid →
  bundle rolling-start; `/tmp/sweeps/bundle-{sp500,2011,rolling}/`).
  **Stage 1 sp500 cell DONE, CONFIRMS the bundle**: bundle-w15 Sharpe
  .737±1.09 (19/26 wins, return 13.9% vs 6.3%), bundle-w30 .570
  (16/26, best MaxDD 9.7 vs 10.6) vs baseline .396 — both beat the
  w-only 07-17 cell (w15 .623/w30 .552), so floors-zero+vc ADD on
  sp500 too. Formal gate FAIL is only the zero-tolerance worst-fold
  rule (same as every accepted surface). Stages 2/3 verdicts pending.
- **Lever (f) MERGED #2015** (squash `97f1c06c2`): `Res_hist` 20 →
  80 band-major cols (20 price × 4 age bands 0-26/26-78/78-130/
  130-520w, window extends to 520w; schema 37→97, hash bump); four
  `band_weight_*` score-time config fields default 1/1/1/0 =
  bit-identical (parity tests); v3 warehouses still read via reader
  width-probe (last v4 cell present ⇒ reshape, absent ⇒ legacy pack
  into youngest band). NO rebuild — v4 gated on bundle verdict.
  QC: structural 1 rework (nesting depth 7 in live_resistance_sketch
  → helper extraction), behavioral 5/5. Follow-up: `dump_snap.ml`
  iterates n_hist_buckets → dumps only band-0 of a v4 warehouse.
- **Stage 2 broad-2011 cell: bundle does NOT confirm** — baseline
  .619, bundle-w15 .525 (3/7), bundle-w30 .599±.674 (4/7) ≈ wash.
  Killer contrast: w-ONLY 2011 cell had w30 .825 with fold-σ .223 —
  vc+floors-zero destroyed that (σ .223→.674). On 2011-26 broad the
  floor staircase WAS the value (suppresses re-admitted stale cohort);
  across 2000-26 it's the redeemed-cohort tax. Regime-dependent
  floors. Grid disagrees (sp500 CONFIRM / 2011 REGRESS) → stage-3
  rolling-start fully decisive: bundle's case = repairing the
  2000/2008/2010 recovery-window tail. No repair ⇒ keep axes. Repair
  ⇒ user chooses bundle (tail fix, 2011 wash) vs plain w30 (best
  single-surface Sharpe .860, known tail).
- **Stage 3 rolling-start (07-20): RECOVERY WINDOWS REPAIR** — the
  decisive read. 2000/2008/2010 starts: w30 −5.84/−6.68/−8.54 →
  bundle +0.41/+0.16/−1.92 pp/yr vs baseline. Bundle vs baseline
  9/12 wins, median +2.08pp/yr, worst −1.92; worst-start realized
  edge +7.79% (baseline +6.35, bare w30 −1.27) = best floor of all
  three; MaxDD median 28.76/worst 30.99 (baseline 32.2/40.5). Cost
  vs bare w30 = mid-bull give-back (2016 −2.91, 2022 −2.53) — the
  2011-cell effect path-wise. FULL EVIDENCE: grid split + tail
  repair → ledger `2026-07-20-bundle-promotion-studies`
  (Inconclusive-pending-human), note
  `bundle-studies-results-2026-07-20.md`, PR #2021. Options: A
  promote BUNDLE (recommended: decisive-lens dominance + best edge
  floor), B keep axes pending lever (f), C bare w30 (not
  recommended). USER GATE — no flip without them.
- **USER DECISION 07-20: lever (f) + scenarios ON TOP OF the bundle
  BEFORE promo** (option B-variant). Chain launched 16:02 UTC
  (`/tmp/sweeps/leverf-studies-chain.sh`): sp500 v4 rebuild →
  top3000 dedup v4 rebuild (twin-basis returns, csv-data-dir
  /workspaces/trading-1/data) → (f) band-weight surface on bundle
  base (`leverf-band-weight-BROAD-2000-2026.sexp`: bands 1/1/1/0 =
  v4 CERTIFICATION row, must reproduce floor-axis bundle Sharpe
  .827; 1/1/1/{.25,.5} = measured-old-supply weight; 1/.7/.5/.25 =
  full age decay; × w30 × vc). v3 warehouses kept until certified.
  After broad read: sp500 (f) cell, then promotion decision WITH (f)
  evidence. Rebuild recipes recovered from /tmp logs
  (chain_sp500_wh.log, warehouse_dedup_v2.log).
- **07-20 PM: v4 rebuilds DONE fast** (sp500 9min/521 syms/2.2G;
  top3000 52min/2908 syms/8.4G — both verify-clean, twin groups 83 =
  v2 parity). **BUT broad (f) surface NOT VIABLE on 7.8G Docker VM**:
  8.4G v4 warehouse thrashes (worker D-state, RSS 5.5G, ~2h/fold vs
  15min on v3 3.3G) — killed at fold 3, chain exit:143. Panel memory
  ceiling returns at v4 scale ([[project_panel_runner_memory_ceiling]]
  said 12-16GB RAM = the fix). PIVOT: (f) surface relaunched on
  sp500 v4 (2.2G fits; spec leverf-band-weight-SP500-2000-2026.sexp,
  w15 basis, cert row = bundle-sp500 w15 .737/19-26-wins). BROAD (f)
  surface BLOCKED on user Docker Desktop RAM bump → 12-16GB.
- **Sketch v5 (user-designed sparse storage) PRs 1+2 MERGED overnight
  07-21**: #2026 `Weekly_sidetable` codec (WKSIDE01, format_hash) +
  builder from pipeline's own `Weekly_prefix` + manifest hash field +
  `--emit-weekly-sidetable` (default off); #2027 `Weekly_sidetable_reader`
  (score-time bucketing, bit-exact v5≡v4 property test through real
  pipeline) + three-generation dispatch (side-table→v5, 80col→v4,
  20col→v3) in `Resistance_sketch_reader`. Both through full QC (1
  rework each: version-rejection test; load_gated de-nest). Design:
  `dev/plans/resistance-sketch-v5-weekly-sidetable-2026-07-20.md`
  (now committed via #2032). **PR 3 MERGED #2032 07-21**: threading
  (loader into BOTH `Snapshot_warehouse_reader.build` AND
  `panel_runner._build_snapshot_bar_reader` — the real read path),
  activation = side-table presence (manifest-hash gated, mismatch
  raises), `--emit-weekly-sidetable` on scenario builder; **CERT PASS
  byte-identical** (6 folds × 5 variants, fold_actuals md5
  `a1c9a9e8…` equal, v5-path vs dense-path). v5 warehouses:
  `/tmp/snap_sp500_2000_2026_v5` (521) + `/tmp/snap_top3000_dedup_v5`
  (2908 `.weekly`). sp500 (f) surface on v4: CERT row reproduced
  bundle-w15 .737/19-26 EXACTLY; age verdict U-SHAPED (0→.737,
  .25→.658, .5→**.774** best-all-aggregates, full-decay→.677 —
  non-monotone = noise-suspect, floors-half precedent; within-recent
  decay clearly hurts). **KEY NEGATIVE 07-22: v5 read path does NOT
  fix broad thrash** — panel cache materializes whole 97-col files;
  broad surface on v5 warehouse degraded to D-state ~55min/fold,
  killed. **PR 4 (thin schema: drop 84 dense cols → 13-col .snap +
  side-tables, hash bump, loud-fail when armed+no-sidetable, fixture
  regen, thin-cert vs md5 a1c9a9e8) DISPATCHED** — the real RAM
  unblock; broad (f) surface relaunches on the thin warehouse after.
- **07-22 FINAL READS — evidence set COMPLETE, all at user gate:**
  (1) broad (f) surface on v5thin: age lever REJECT (ledger
  `2026-07-22-leverf-age-band-surface`) — monotone harm .827→.766→.708
  with old-band weight, recent-decay .755; sp500 U-shape (peak .774
  @0.5) does NOT transfer = noise. Age axis CLOSED; 2011-cell
  regression not rescuable by age-banding (remaining: lever b regime
  softener, or accept bull-era wash). (2) v5 FULL-SCALE CERT: thin
  broad row reproduces dense .827/36.17/14.05 to every decimal;
  fold pace ~11min (was unrunnable). Warehouses of record:
  snap_top3000_dedup_v5thin (1.3G) + snap_sp500_2000_2026_v5thin.
  Docs PR #2045. Candidate of record = BUNDLE at default band
  weights; promotion memo options unchanged (A bundle/B axes/C bare
  w30-not-rec). Ops memories added: chain flock+abort race,
  agent background-wait stalls.
- **07-23 THE BUNDLE IS PROMOTED — PR #2047 MERGED (`6a2d9b426`),
  USER-APPROVED R3 GATE.** FOUR defaults flipped as one unit (the
  dispatch named three; the agent correctly identified the fourth):
  `w_overhead_supply` None→Some 30, `virgin_crossing_readmission`
  false→true, **`overhead_supply` None→Some default_config (the
  arming)**, floors 0.4/0.25/0.1→0/0/0. Bands stay 1/1/1/0.
  Companion change: #2038 loud-fail regated on `sketch_warehouse`
  (manifest hash present) so CSV/panel runs degrade to v1 (pinned
  both directions; v3/v4 dense warehouses still serve the sketch via
  the short-circuit — no silent degradation, behavioral-verified).
  Committed goldens bit-identical (CSV-path inert — CI golden
  workflows green = the proof); live weekly-review grade now displays
  v2 "<quality> (0.NN)" by default. New `Entry_walk` module extracted
  (file-length rework). 28y record basis: bundle +8,689%/DD 30.3 vs
  old record +7,914%/32.3. QC: structural + behavioral 5/5 (the
  Inconclusive-grid transparency resolved via promotion-confirmation
  grid-disagreement clause + R3). Tuner BO test errors in first CI
  run = confirmed flakes (passed on rerun untouched).
- Margin M3b MERGED #2017 (deterministic buy-in stress mode,
  `Short_buyin`, margin_call-wins dedup pinned after 1 behavioral
  rework). M1-M3 complete; M4 = last gate before levered numbers.
- Ops proven: feat/QC agents CAN run parallel to a live sweep IF
  each uses repo-local jj workspace with own `_build` + KILL-NOTHING
  brief + never dune in parent (chain execs parent `_build` exes by
  path). Dune-wedge workaround: detached file-logged dune, kill only
  cwd-verified own procs. `gh pr merge --delete-branch` breaks on jj
  detached HEAD → add `-R dayfine/trading`.
