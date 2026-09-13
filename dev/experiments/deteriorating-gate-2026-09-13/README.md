# Deteriorating-breadth long gate — three-salt read on `_v10dedup` (2026-09-13)

**Status: PRE-REGISTERED** (written before any cell ran). Mechanism: `deteriorating_blocks_longs`
(issue #2755, PR #2759) — a default-off long-admission gate that rejects new longs when
`Macro.result.breadth_state = Deteriorating`; inert unless `macro_config.breadth_direction.enabled`.

## Why

Entries made while breadth is Deteriorating lose in both books over 2000–2026 (record bundle n=80,
29% win, −$604k; `stop-width-cadence-surface-2026-09-05/README.md` §"Breadth state across 27 years").
Nothing blocks them: the macro gate blocks only `Bearish`; `neutral_blocks_longs` would also kill
`Recovering`, the best cohort. Sizing the stop by state (item 3, ledger
`2026-09-09-stop-width-by-macro-state-surface`) was the wrong instrument and is REJECT-as-default.

## Design (binary, no value search)

| | |
|---|---|
| warehouse | `/tmp/snap_top3000_2000_v10dedup` (rename twins dropped, MEL quarantined) |
| null | the committed `stop-width-by-state-2026-09-08/results/a0-breadth-on-null-s{0,1,2}-v10-*` cells (build 969637974): **382.74 / 311.75 / 639.74 %**, 710 / 707 / 728 trades, maxDD **37.60 / 32.75 / 42.96** (salts 0 / 1 / 2) |
| arm | `specs/a3-deteriorating-gate.sexp` = the a0 spec + ONE override `((deteriorating_blocks_longs true))` |
| build | main after #2759 merges, pinned in `.claude/worktrees/sweep-detgate`; runtime-inert vs 969637974 apart from #2759 by construction (only #2758's default-off builder flag and docs merged in between — verify at launch with `git log 969637974..HEAD --oneline`) |
| salts | 0, 1, 2 (`TRADING_PATH_SEED_SALT`), two concurrent lanes (`chain.sh A a3-deteriorating-gate:0 a3-deteriorating-gate:2`, `chain.sh B a3-deteriorating-gate:1`) |
| pairing gate | `validator_diff.exe -check V6 -report null=<a0-v10> -report gate=<a3-v10>` exit 0 per salt, V6 = 0 on both |
| read | per salt: level, **realised** P&L (closed trades), unrealised (open MTM — decomposed by name), maxDD, trade count, exit mix; join on `symbol|entry_date` (position_id is not shared across arms) for shared / null-only / arm-only P&L; count of Deteriorating-state entries removed (from `trade_audit.sexp`) |

**Pre-registered decision rule (from #2755):** the gate CLEARS if realised P&L AND maxDD both improve
vs the a0-v10 null at ≥ 2 of 3 salts. Otherwise the state-conditioning idea retires
(REJECT-as-default; keep-as-axis only if one salt shows a large, name-attributable win worth a
regime read). No per-state value search — 80 / 36 entries per cohort is below the 230-trade
measurability floor. Level (total_return_pct) is reported but NOT a criterion: the null's salt-2
640% is $3.84M of open MTM on three names.

**Expected mechanism if it works:** ~80 fewer entries over 26y (the Deteriorating cohort), those
entries were −$604k realised on the record, so the realised delta should be of that order plus
whatever the freed cash buys instead (the substitution is the unknown — the freed slots may land on
worse names). maxDD should improve only if the removed entries cluster inside the drawdown windows
(2001–02, 2008, 2020, 2022).

## Log

(filled as cells finish; per-arm raw artifacts committed under `results/` — never read a number
from the chain log, the second-finishing lane's summary line can carry both arms.)

- 03:50 PT 09-13: #2759 merged (squash 31e4bb9c3; two QC rounds — rework iteration 1 threaded `~macro_trend`
  into `longs_admitted_by_breadth` so flag-off is bit-identical by construction, and added the strategy-level
  fresh-candidate pin; probes A–E all caught at 4fdaab859). Worktree `sweep-detgate` pinned at 31e4bb9c3.
  Runtime drift vs the null's build 969637974, by inspection of `git log 969637974..31e4bb9c3`: #2759 itself
  (flag-off identity pinned by `test_deteriorating_blocks_longs_off_is_identity` + the widened truth table),
  #2758 (build-time builder flag, default-off, warehouse already built), #2750 (V18 validator check — post-run
  report only), #2767 (devtools test), ops/docs/harness. No a0 tripwire cell re-run (3 h); accepted by inspection.

- 06:31 PT: **salt 1 = 229.23% / 675 trades / Sharpe 0.370 / maxDD 34.68** (wall 9,544 s; `results/a3-deteriorating-gate-s1-v10-*`)
  vs the null's **311.75 / 707 / 0.427 / 32.75**. V16/V17 PASS, **V6 = 0 on both, `validator_diff -check V6` exit 0**.
  **The gate LOSES at salt 1 on both criteria:** realised $2.94M → $2.12M (**−$816k**), unrealised $0.31M → $0.28M,
  maxDD **worse** (32.8 → 34.7). Exit mix `stop_loss` 458 → 436, `laggard_rotation` 236 → 223 (fewer trades, same shape).
  Join (`symbol|entry_date`): 384 shared +$1.72M → +$1.81M (drift +$95k: LOGI +$42k, MKSI +$26k); **null-only 323
  trades +$1.22M** (BBWI 2020-08-08 +$377k, NVDA 2020-04-06 +$316k, BPT 2022-01-22 +$298k, B 2025-08 +$203k, UTHR
  2020-12 +$166k) vs **gate-only 291 trades +$0.31M** (AEIS 2025-06-24 +$483k, UPBD +$238k, AN +$224k; MTCH 2020-06
  −$239k, CLE −$131k, CNMD −$122k). Only 32 net entries disappear (707 → 675) but ~320 re-draw: blocking a week's
  candidates shifts every later fill, so most of the delta is path re-draw, not the removed cohort itself. The
  removed 2020 names (NVDA 04-06, BBWI 08-08, UTHR 12-02) are COVID-recovery monsters — Deteriorating fired inside a
  Bullish/Neutral tape during the recovery (the audit shows 52 Deteriorating weeks, 17 Recovering). The gate is live
  in the sim: on every Deteriorating week `long_top_n_admitted` = 0 (see the effectiveness table below). Open names
  ADTN EXTR PKE QCOM URI (null) vs AVT QCOM SNA SXT URI (gate).

  Effectiveness table (salt-1 arm, from `trade_audit.sexp`'s weekly cascade rows — weeks / Σ`long_top_n_admitted` / Σ`entered`):

  | breadth_state | weeks | long_top_n | entered |
  |---|---:|---:|---:|
  | Bullish_breadth | 720 | 14,400 | 818 |
  | Neutral_breadth | 148 | 2,960 | 320 |
  | Recovering | 17 | 329 | 64 |
  | **Deteriorating** | **52** | **0** | **0** |
  | Bearish_breadth | 398 | 0 | 0 |

  Deteriorating weeks by year: 2000:3 2007:3 2014:2 2015:2 2018:4 2019:2 2020:6 2021:2 **2022:10 2023:10** 2025:5 2026:3 —
  the state fires mostly in the 2022–23 chop and inside the 2020 recovery, i.e. exactly where the record's late-cycle
  monsters (NVDA, BBWI, UTHR) were bought.

- 06:36 PT: **salt 0 = 179.91% / 700 trades / Sharpe 0.325 / maxDD 39.62** (wall 9,859 s; `results/a3-deteriorating-gate-s0-v10-*`)
  vs the null's **382.74 / 710 / 0.445 / 37.60**. V16/V17 PASS, **V6 = 0 on both, `validator_diff -check V6` exit 0**.
  **The gate LOSES at salt 0 on both criteria, harder:** realised $3.24M → $1.54M (**−$1.70M**), unrealised $0.78M → $0.37M,
  maxDD **worse** (37.6 → 39.6). Exit mix `stop_loss` 450 → 459, `laggard_rotation` 244 → 227 — the gate hands exits
  BACK to stops (the opposite of the direction every winning lever has shown). Join: 389 shared +$1.08M → +$1.19M
  (drift +$116k: CSL, AMKR, QGEN); **null-only 321 trades +$2.16M** (BBWI 2020-08-08 +$532k, NVDA 2020-04-06 +$450k,
  UPBD 2020-12-21 +$324k, KR 2014 +$268k, B 2025 +$267k, IPIXQ 2004 +$256k) vs **gate-only 311 trades +$0.35M**
  (AEIS 2025-06-24 +$382k, BBWI 2020-08-**05** +$280k — the same name bought three days earlier at a smaller size,
  MKSI +$267k, CLB +$254k; MTCH 2020-06 −$193k, CLE −$142k). Open names ADTN ARW ONTO QCOM (null) vs AVT NOK QCOM SXT URI.
  **Two of three salts have now failed both pre-registered criteria, so the decision rule is settled: the gate does
  not clear.** Salt 2 runs to completion for the band. The same two names head the null-only list at both salts
  (NVDA 2020-04-06, BBWI 2020-08-08) — `Deteriorating` fires INSIDE the 2020 recovery (6 of its 52 weeks are 2020),
  which is where the record's monsters are bought; blocking admission there is anti-predictive by construction,
  the same shape as `project_cascade_selection_inversion` and `project_edge_is_the_fat_tail`.

- 09:16 PT: **salt 2 = 197.90% / 690 trades / Sharpe 0.336 / maxDD 40.04** (wall 9,575 s; `results/a3-deteriorating-gate-s2-v10-*`)
  vs the null's **639.74 / 728 / 0.526 / 42.96**. V16/V17 PASS, **V6 = 0 on both, `validator_diff -check V6` exit 0**.
  Realised $2.70M → $1.46M (**−$1.25M**); unrealised $3.84M → $0.63M (the null's level is its three open names ADTN/MU/URI —
  the band caveat, not a gate effect); maxDD **better** here (43.0 → 40.0), the one criterion the gate wins at one salt.
  Exit mix `stop_loss` 481 → 458, `laggard_rotation` 233 → 218. Join: 395 shared +$0.77M → +$0.84M (drift +$78k);
  **null-only 333 trades +$1.94M** (NVDA 2020-04-06 +$308k for the third time, KLIC 2020-11-09 +$302k, BPT 2022-01-22
  +$290k, IPIXQ 2004 +$255k, TK 2022-11 +$199k, AROC 2023-11 +$186k, UTHR 2020-12 +$163k) vs **gate-only 295 trades
  +$0.61M** (CLS 2023-07-01 +$522k, AN 2020-08-04 +$181k; MTCH 2020-06-18 −$199k for the third time, BCRX −$86k).
  Open names ADTN MU URI (null) vs ADTN ALKS ARW NOK URI.

## Three-salt read (all on `_v10dedup`, build 31e4bb9c3 vs null build 969637974; V6 = 0 on all six cells)

| salt | null a0-v10 (level / trades / Sharpe / maxDD) | gate a3 | Δ level | realised Δ | unrealised Δ | maxDD |
|---|---|---|---:|---:|---:|---|
| 0 | 382.74 / 710 / 0.445 / 37.60 | 179.91 / 700 / 0.325 / 39.62 | −203pp | **−$1.70M** | −$0.40M | **worse** (+2.0) |
| 1 | 311.75 / 707 / 0.427 / 32.75 | 229.23 / 675 / 0.370 / 34.68 | −83pp | **−$0.82M** | −$0.03M | **worse** (+1.9) |
| 2 | 639.74 / 728 / 0.526 / 42.96 | 197.90 / 690 / 0.336 / 40.04 | −442pp | **−$1.25M** | −$3.21M (null's open MTM) | better (−2.9) |

**Pre-registered rule: clears only if realised P&L AND maxDD both improve at ≥ 2 of 3 salts. Result: realised 0 of 3,
maxDD 1 of 3. The gate does not clear — REJECT.**

**Why (the transferable part).** `Deteriorating` is a *direction* label on breadth inside a Bullish/Neutral tape. Over
2000–2026 it fires on 52 weeks — 6 in 2020, 20 in 2022–23 — i.e. during fast recoveries and chop, which is exactly
where the record's late-cycle monsters are bought (NVDA 2020-04-06 is null-only at all three
salts; UTHR 2020-12-02 at two — salts 1 and 2, absent from both arms at salt 0; BBWI 2020-08-08 at two; KLIC 2020-11-09 at one). Blocking admission on that label removes the fat tail the
strategy's edge consists of (`project_edge_is_the_fat_tail`), and the freed slots buy ordinary names (AEIS, AN, CLS)
that do not replace it. The 09-04 observation that Deteriorating-state *entries* lost −$604k on the record was a
cohort read below the 230-trade floor (`feedback_perturb_before_believing_a_cohort_split`) — on a paired,
salted run the cohort's removal costs $0.8–1.7M realised per salt, because ~320 later fills re-draw too (only 10–38
net entries disappear but 290–330 change). The exit mix shifts toward stops (salt 0: 450 → 459 `stop_loss`,
244 → 227 rotations) — the opposite of every lever that has ever helped.

**Classification (experiment-flag-discipline Rule 4): REJECT-do-not-revive for admission gating on `Deteriorating`.**
*(Superseded — see the amendment below; the paragraph is kept as the record of what was first written.)*
Unlike the per-state stop width (kept as a regime axis), there is no untested neighbour here: the flag is binary,
the state is the book's directional read, and the result is anti-predictive by mechanism, not by noise. The flag
stays default-off (R1) and becomes a retirement candidate after three sessions per Rule 4. This closes the
state-conditioning line opened by the 09-04 yearly review (item 3 stop-width-by-state: REJECT-as-default; item 3'
admission gate: REJECT-do-not-revive). Forward guidance unchanged: the record's gap is entry-side but
*tail-preserving* levers only — breadth of the funnel, not narrowing it by regime labels.

## Amendment 2026-09-13 (#2780) — classification is REJECT-as-default-but-legitimate-axis, not do-not-revive

A post-merge audit (#2780) found the REJECT correct and independently re-derived (V6 = 0 on all six cells; realised
−$1,699,946 / −$815,935 / −$1,247,695; maxDD 1 of 3) but the **do-not-revive** classification not earned:

- The pre-registered failure branch above reads *"REJECT-as-default; keep-as-axis only if …"*. Escalating the
  consequence to do-not-revive after the numbers were seen is the defect class pre-registration exists to prevent.
- Rule 4 defines do-not-revive as failure *across every tested context*; its exemplar (early-admission) earned it on a
  27-year cross-regime reversal. This experiment is one period × one universe × one preset; salts perturb the fill
  path and are not independent contexts (`promotion-confirmation.md`). The mechanism's own causal story is
  regime-scoped (52 `Deteriorating` weeks, concentrated in 2020 and 2022–23), so a different composition vintage is
  precisely the untested neighbour. The sibling instrument (per-state stop width, 09-09) received keep-as-axis on the
  same evidential shape.

**Amended classification: REJECT-as-default-but-legitimate-axis.** `deteriorating_blocks_longs` stays default-off and
searchable; it is removed from the Rule-4 retirement worklist. It earns do-not-revive only if a second broad cell on a
different vintage (2009 or 2019 `_v10dedup`, three salts, paired against that vintage's own null) also fails both
pre-registered criteria. The forward guidance is unchanged and lives in `memory/project_deteriorating_gate_reject`:
regime labels applied to admission are anti-predictive because the label turns over inside the moves the edge comes
from; entry-side work must be tail-preserving.

Two factual corrections to the durable records (ledger notes, this README, the #2776 body): **UTHR 2020-12-02 is
null-only at two salts (1 and 2), not three — at salt 0 it appears in neither arm** (verified from the committed
`trades.csv`: null UTHR entries 2002-11-21 / 2014-08-29 at salt 0). NVDA 2020-04-06 (all three), BBWI 2020-08-08 (two)
and KLIC 2020-11-09 (one) stand. The ledger's `mean_calmar 0.0000` placeholders for the gate cells are filled from
`actual.sexp` `calmar_ratio`: gate **0.1000 / 0.1327 / 0.1051** vs null 0.1629 / 0.1676 / 0.1827 — worse at every
salt, which strengthens the REJECT.
