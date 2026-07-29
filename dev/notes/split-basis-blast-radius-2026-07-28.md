# Split-basis blast radius — record-convention re-measure (2026-07-28)

Closes the measurement owed by issue #2133 defect 2 / `dev/notes/
next-session-priorities-2026-07-28.md` P0 (task #12): the promoted
resistance-v2 bundle's evidence and the 28y record-of-record row were
measured on **split-blind** side-tables (raw weekly high/mid anchored at the
raw `Close`). #2145 fixed the machinery hash-gated but deliberately left
every backtest warehouse bit-identical until this deliberate re-measure.

Ledger: `dev/experiments/_ledger/2026-07-28-split-basis-blast-radius.sexp`.

## Method

1. **`rebuild_weekly_sidetables.exe`** (PR #2153, `analysis/scripts/
   rebuild_weekly_sidetables/`): clones a warehouse with `.weekly`
   side-tables rebuilt on the adjusted basis; `.snap` files hard-linked;
   cloned manifest stamps `Weekly_sidetable.format_hash` (`128e4c1e…`).
   Two non-obvious problems it had to solve:
   - **The deep prefix is not in the `.snap`.** The original build fed 3650
     calendar days of pre-window CSV history into the weekly series
     (`Build_runner._deep_bars`); `.snap` holds window bars only (AA.weekly
     starts 1989-01-06, AA.snap starts 1999-01-04). A snap-only rebuild
     would shallow every early-window sketch and confound history depth
     with basis. The migrator re-reads deep bars from the CSV store with
     the same window arithmetic.
   - **The CSV store has drifted off the warehouse's adjusted basis.**
     EODHD rebases `adjusted_close` across the whole history whenever a new
     dividend lands; the 07-23 refetch moved most dividend payers (PFE:
     snap/CSV ratio 1.017493, constant over 27 years). Deep bars are
     re-pinned by the median snap/CSV ratio sampled at 5 overlap dates
     (stability tolerance 1e-3 — above the feed's 4-decimal rounding
     noise, far below revision-class disagreement).
2. **v5thin clone** `/tmp/snap_top3000_dedup_v5thin_adj`: 2,894/2,908
   symbols rebuilt with **exact week-skeleton parity** (only mid/high moved
   — the expected shape of a pure basis change). 14 refused the deep
   re-pin (`Fallback_unstable_basis`: revision-class **raw** restatements
   since 06-26 — e.g. HON's post-window corporate action rewrote historical
   raw closes; these rebuild snap-only, i.e. shallow prefix). LH + ONTO
   rebuilt but with skeleton drift (CSV restatements). Full detail:
   `migration_report.sexp` (archived under `/tmp/sweeps/basis-blast/`).
3. **Two arms, one binary**, pinned worktree @ `9f50de924` (clean tree,
   flock, per `sweep-hygiene.md`): `staging-record-convention/
   top3000-2000-2026-record-convention` (promoted-bundle defaults), cache
   1024, committed `test_data` as `TRADING_DATA_DIR`.

## Result

| Arm | Return | Trades | Win rate | MaxDD |
|---|---:|---:|---:|---:|
| Raw control (= pinned record) | +8,689.4% | 1,172 | 38.5% | 30.3% |
| **Split-safe (honest)** | **+8,366.8%** | **1,122** | **37.7%** | **37.1%** |

- **Control reproduces the record** (+8,689 / 30.3 recorded; trades 1,172
  vs 1,170 recorded — negligible bookkeeping delta). The #2145 old-hash
  bit-compat claim holds at path level on current main.
- **Blast radius: −322pp return (−3.7% relative), −50 trades, MaxDD
  +6.8pp (30.3 → 37.1).** The return flattering is mild; the **risk
  number was materially flattered** — the honest MaxDD is 37.1%, worse
  than the pre-bundle Run-D row's 32.3% (which is itself split-blind-era
  and not directly comparable).

## Why (trade-level)

- Entry churn is broad: ~190 symbols entered only under raw grades, ~140
  only under adjusted. Overhead-grade changes reshuffle the cap-20
  screener boundary, so marginal candidates swap wholesale (the known
  tied-cohort sensitivity), while the top of the book is stable.
- The fat-tail engine is intact: AXTI realized $64.1M vs $65.8M. Largest
  per-symbol swings: FARM +$2.1M, FDX +$1.3M, BKE +$1.1M appear/improve
  under honest grades; AXTI −$1.7M, PEGA −$0.9M under raw.
- Net: split-blind grading was systematically admitting a slightly
  luckier marginal cohort (CLMB-class forward-split names graded falsely
  Clean) and blocking some honest ones; the aggregate return effect is
  small but the drawdown clustering is not.

## Standing after this measurement

- The **record-of-record row is basis-flattered**; the honest number on
  the same warehouse/scenario is **+8,367% / MaxDD 37.1%**. Re-pinning the
  record (and `deep_headline_records.sexp`) = **user decision (R3)** — no
  claim changed by this memo beyond the caveat added to
  `dev/backtest/DEEP_RESULTS.md`.
- The bundle's **promotion evidence is not re-certified**: fold-level
  13×2y WF-CV surface (baseline .827) was split-blind. Open follow-up:
  re-run that surface against the adjusted clone (spec
  `test_data/walk_forward/leverf-band-weight-BROAD-2000-2026.sexp`) to
  check the promotion decision itself survives honest grading.
- Other warehouses still raw-basis: `/tmp/snap_sp500_2000_2026_v5thin`
  (324M — same migration is one command now), plus any older v2/v4 dirs.
- P1 (unchanged, next): #13 floor wick-vs-close anchoring; #2122 slice (a)
  validator wired into the generator.

## Addendum (2026-07-29) — fold-level re-cert

Ledger: `2026-07-29-split-basis-fold-recert`. Same 13×2y broad grid the
promotion evidence used (`margin-m4-broad-13x2y-2000-2026`), promoted-bundle
defaults, run against the split-safe clone from the same pinned worktree:

| Basis | mean Sharpe | mean return % | mean MaxDD % | Calmar |
|---|---:|---:|---:|---:|
| Split-blind (was the basis of record) | .827 | 36.17 | 14.05 | 1.309 |
| **Honest (adjusted)** | **.765 ± .462** | **28.49 ± 26.49** | **15.93** | **.897** |

- Fold-level flattering: −.062 Sharpe / −7.7pp mean fold return / +1.9pp DD.
- Internal parity: a no-op default variant is bit-identical to baseline on all
  13 folds (worst gap 0.0000) — adjusted read path deterministic, axis
  plumbing certified on the new hash.
- ⚠ The honest .765 numerically resembles the *contaminated* 07-26 baseline
  (.766, #2108) — coincidence; that one was environmental and raw-basis.
  Never conflate them.
- **From 2026-07-29 the honest fold baseline of record is .765/28.49/15.93 on
  the adjusted clone.** New fold-level experiments must run on split-safe
  warehouses and compare against it, not .827. Standing REJECTs citing .827
  (margin M4, leverage-dawn, leverf-age) remain qualitatively safe — losing
  margins dwarf the basis shift — but their baselines read as raw-basis.
- Not settled: bundle-vs-**alternatives** honest margin (pre-bundle / w15 /
  floors arms were never run adjusted). If the R3 record re-pin wants that
  margin, it's a further comparison grid.
- sp500 cell (universe-diversity leg — landed 07-29, ledger
  `2026-07-29-split-basis-sp500-cell`): raw +1,476.6% / MaxDD 30.5 / 1,183
  trades vs honest +1,289.9% / MaxDD 28.8 / 1,102 trades. Return flattering
  proportionally LARGER than broad (−12.6% rel vs −3.7%), but MaxDD
  **improves** 1.7pp — the DD flattering is a broad-universe marginal-cohort
  composition effect, not universal. Honest grading costs return everywhere;
  risk direction is universe-dependent. Grid complete for the R3 decision.

Spec (worktree-local, reproducible): `basis-recert-BROAD-2000-2026.sexp` —
record-convention base, Rolling 13×730d 2000-01-01..2026-04-30, single no-op
`overhead_supply` value at the promoted defaults, gate Sharpe 7/13.

## Artifacts

- Runs: `/tmp/sweeps/basis-blast/{raw,adj}/` (`trades.csv`,
  `equity_curve.csv`, `actual.sexp`, `params.sexp`) +
  `migration_report.sexp` + `walk_forward_report.md` + `aggregate.sexp`
  (fold re-cert); logs `/tmp/sweeps/basis-blast-{raw,adj}.log`,
  `/tmp/sweeps/basis-recert.log`.
- Tool: PR #2153; migration re-runnable in ~4 min for any warehouse.
