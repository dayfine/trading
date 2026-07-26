# Next-session priorities — 2026-07-23

**Supersedes** `next-session-priorities-2026-07-19.md`. The 07-19→07-23
sessions completed the ENTIRE resistance-v2 program: bundle evidence
chain (grid split + rolling-start repair) → lever-(f) built, surfaced,
REJECTED at both fold and 28y-path lenses → sketch v5 sparse storage
(user-designed) shipped + certified at every scale → **THE BUNDLE
PROMOTED (PR #2047, user R3 approval 07-23)** → first live picks on the
promoted screen (#2050) → README deep-headline generator (#2054).
Margin M1-M3 also merged (#2016 M3a tiers, #2017 M3b buy-in stress).

## ~~P0 — Margin M4~~ DONE 07-23/24 (same session that wrote this doc)

**M4 COMPLETE — leverage REJECT.** All three stages ran: parity gates all
bit-identical; squeeze cells do-no-harm + forced-cell engagement proven;
priced surface all six cells FAIL the gate (Sharpe .827→.56→.34 monotone
in leverage, 2× = DD 89% + less raw return than 1.33×). Ledger
`2026-07-24-margin-m4-leverage-surface`; record
`dev/notes/margin-m4-validation-2026-07-23.md`; PR #2063. No default
flips. Follow-up issues: #2057 (margin exit labels missing from
round-trip outputs), #2059 (LH phantom-short + dup row in record basis),
#2060 (mean-ADV entry gate spoofable — LINK −$1.58M specimen). The tax
lens P1 below is now the **top item for next session**. Original M4
protocol text kept below for reference:

### (original P0 text — executed)

`dev/plans/levered-longshort-margin-realism-2026-07-14.md` §M4. Three
stages, run in order; no levered number is quoted anywhere before all
three pass:

1. **Parity gates** (cheap, run first): margin-off ≡ baseline and
   `req=1.0/rate=0` ≡ E-capped, bit-identical (R1 per milestone).
2. **Squeeze stress cells**: GME-window + 2008 + dot-com, short book
   armed WITH M3a tier tables + M3b `short_buyin_stress_mode`;
   force-cover ordering audited per event.
3. **Leverage surface**: `initial_long_margin ∈ {1.0, 0.75, 0.5}` ×
   short sleeve on/off via experiment-gap-closing (WF-CV + DSR), then
   promotion-confirmation grid WITH a bear-regime cell. Bar: priced
   leverage must clear the UNLEVERED frontier (leverage amplifies both
   tails — MTM-up is not the question).

Basis notes: warehouses of record `/tmp/snap_top3000_dedup_v5thin`
(1.3G) + `/tmp/snap_sp500_2000_2026_v5thin` (324M); the promoted
default config IS the new baseline (28y record +8,689%/DD 30.3,
`staging-leverf-28y/top3000-2000-2026-rcb-f000.sexp`, all four arms'
actuals in `trading/dev/backtest/scenarios-2026-07-22-231614/`).

## P1 — small follow-ups from the picks run (#2050 findings)

- `render_weekly_report.exe` does not surface the v2 resistance grade
  in Markdown (sexp-only today) — small renderer fix.
- Stray `"Weinstein_types."` prefix in grade strings (cosmetic).
- `fetch_finviz_sectors` manifest never built (~3h scrape; didn't skew
  07-17 picks — sector labels came from the pinned universe).
- Optional: prior-week picks backfill (as-of 07-10) if the user wants
  the comparison.

## ~~P1b — regime-dependency evaluation~~ DONE 07-24 — memo `regime-dependency-evaluation-2026-07-24.md`

Verdict: leverage-dawn is the ONLY payload earning a designed WF-CV
surface (realistic lagging label keeps ~15× of the 46× hindsight bound,
but ⅔ of it is one fold + ≥50% intra-era DDs — design constraints in
memo §3); macro-directed shorts NO surface (45/47 shorts already enter
Bearish, conditioning cuts sleeve value 1.37×→1.18×, fold deltas are
funding-reshuffle chaos); SPY-switch stays dead per 06-27. Surface
design goes to user for scheduling. Original text below:

### (original P1b text — executed)

User question after the M4 fold table: the leverage surface is barbell-shaped
— should the system be macro/regime-DIRECTED? Evaluate impact + candidate
refinements, understanding-first (same posture as the parked regime-barbell
program; NOT a build/WF-CV session unless a screen is decisive):

1. **Impact screen (read-only, existing outputs):** quantify regime-conditional
   deltas across the three payload candidates on the 13-fold table + the
   28y record path: (a) leverage 1.33× (today's hindsight bound ~45×,
   real-time-label leak = 2024 melt-up-lag fold), (b) the short sleeve
   (P1a: hedge-shaped, pays early bears; today: +.06 Sharpe at cash-account,
   invariant to leverage), (c) SPY-vs-strategy switch (the original barbell
   screen, +1295% single-path). One comparable table: payload × regime-label
   accuracy sensitivity.
2. **Macro-directed shorts (user sketch: more/more-aggressive shorts when
   macro bearish):** inventory what's ALREADY BUILT default-off before
   proposing anything new — `neutral_blocks_shorts` (Bearish-only shorts,
   #1696), slow-grind gate, M3a borrow gate + tiers. The P1a finding to
   reconcile: UNGATED short sleeve dominated (gates block early-bear
   hedges) — "more aggressive when bearish" must not re-block the hedge
   value it's chasing. Screen: short-sleeve fold deltas conditioned on
   macro_trend state at entry, using existing longshort outputs.
3. **Proceeds caution is RESOLVED** — M4 certified `margin_config.enabled`
   locks short proceeds as 150% collateral (no Run-E fiction); any
   macro-directed short config runs margin-armed by convention.
4. Output: a decision memo naming which payload (if any) earns a designed
   WF-CV surface + which regime signal (lagging trend classifier only —
   no-reversal-timing stands; 2024 fold = standing falsifier).

## P1 — tax lens Phase 1 (USER-SCHEDULED 2026-07-23 for next session)

Issue #2006 — build the report-layer after-tax exe. Spec fully pinned
(issue comment 07-19: year-end payment, no in-year loss deduction,
carryforward ST-first, ST 35% / LT ≥365d 23.8%, realization basis).
Reference numbers ALREADY refreshed to the promoted-bundle basis
(07-23 issue comment): pre-tax $87.9M → after-tax $26.9M, CAGR 18.4%
→ 13.2%. Two things the exe must surface beyond the prototype:
per-trade days-to-LT at exit (AXTI exited ST by 29 days = ~$2.7M
extra tax — measure only, no tax-aware exit mechanics), and the
carryforward trajectory (peaks $3.5M; whipsaw years pay $0).
Clean feat-backtest dispatch; not GHA-scoped.

## P2 — carried
- Trader-preset bundle audit; floor-quality P1b step 3; decision_audit
  Phase-2.
- Lever (b) regime-softener remains the designed default-off axis for
  the bundle's known bull-era-broad wash (2011-cell); no build gate
  currently.
- v3 warehouses (`snap_top3000_dedup_v3_sketch` 3.3G + sp500 851M)
  deletable on user OK (certified basis preserved in goldens).

## Operational lessons (07-20→23) — all in memory files

- Chain scripts: `flock` single-instance + hard abort after EVERY
  stage (`feedback_chain_scripts_single_instance` — the double-launch
  race cost 6h + a phantom bug hunt).
- Agents STILL end turns "waiting for build events" despite lead
  constraints (4× this session) — kick template in
  `feedback_agents_background_wait_stall`; expect to use it.
- Background `sleep`-based polls get reaped; persistent Monitors
  survive. Merge polls: re-arm on kill.
- The worktree reaper bit two agents mid-task — WIP-push-first is
  mandatory in every brief.
- Panel cache materializes whole files: warehouse SIZE is the memory
  ceiling, not column count read (that's why v5 PR 4 dropped the dense
  columns rather than relying on lazy paging).
- jj gotcha (recurred this session): writing a file then `jj new
  main@origin` strands it in the old @; write files AFTER settling @.
