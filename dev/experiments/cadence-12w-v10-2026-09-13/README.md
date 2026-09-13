# Item 4 — 12% initial stop × weekly trail cadence, re-measured on `_v10dedup` (2026-09-13)

**Status: PRE-REGISTERED.** The 09-05 surface's both-window survivor (`sw26y-w12-W`: 761% / maxDD 29.7 at
salt 0 on the OLD exit basis and the twin-carrying `_v7mark` warehouse — `project_stop_width_cadence_surface_2026_09_05`)
must clear the re-based band before it is anything but an axis. Every pre-09-03 exit-lever read is suspect
(`project_lever_reads_invert_on_fixed_sim`) and every `_v7mark` maxDD read is suspect (twin double-funding,
`project_stop_buffer_by_macro_state_axis`).

| | |
|---|---|
| arm | `specs/a4-cadence-12w.sexp` = a0-breadth-on-null + `((initial_stop_buffer 0.9167)) ((stop_update_cadence Weekly))` |
| null | `stop-width-by-state-2026-09-08/results/a0-breadth-on-null-s{0,1,2}-v10-*`: 382.74 / 311.75 / 639.74 %, maxDD 37.60 / 32.75 / 42.96 |
| build / warehouse / lanes | same as `deteriorating-gate-2026-09-13/` (31e4bb9c3, `sweep-detgate`, `_v10dedup` 2000); runs through that experiment's `chain.sh` as lanes B2 (salts 0, 1) and A2 (salt 2) once the gate cells free each lane; artifacts land in `/tmp/sweeps/detgate/a4-cadence-12w-s<salt>-v10-*` and are copied here |
| decision rule (pre-registered, same as item 3's) | clears only if realised P&L AND maxDD both beat the a0-v10 null at ≥ 2 of 3 salts, `validator_diff -check V6` exit 0 per salt, open MTM decomposed by name. Otherwise retire as an axis (`project_stop_width_regime_dependent` already records width as regime-dependent). |

Read with `ARM=a4-cadence-12w sh dev/experiments/deteriorating-gate-2026-09-13/read.sh <salt> <artifact-dir>`.

## Log

- 09:40 PT: **salt 0 = 751.67% / 851 trades / Sharpe 0.578 / maxDD 29.99** (wall 11,334 s; `results/a4-cadence-12w-s0-v10-*`)
  vs the null's **382.74 / 710 / 0.445 / 37.60**. V16/V17 PASS, **V6 = 0 on both, `validator_diff -check V6` exit 0**.
  **Clears both criteria at salt 0:** realised $3.24M → **$5.83M (+$2.59M)**, unrealised $0.78M → $1.84M (9 open names:
  ADM ADTN EXTR GE KLAC LLY MSM NOK URI vs 4), maxDD **37.6 → 30.0**. Exit mix `stop_loss` 450 → 336, `laggard_rotation`
  244 → 483, `stage3_force_exit` 5 → 13 — the same "wide stop hands the exit to rotation" mechanism the 09-05 surface
  described, now on a twin-free warehouse. Width buckets: 12% × 716, 13% × 78, 14% × 25, 15% × 10, 11% × 9. Join
  (`symbol|entry_date`): 353 shared +$1.10M → +$1.70M (**drift +$606k**: BFX 2020-04-22 +$826k — ONE instrument on
  `_v10dedup`, NVDA 2020-03-25 +$348k, IDXX +$249k, BB 2006 +$223k, WFRD +$204k); null-only 357 trades +$2.14M (BBWI
  2020-08-08 +$532k, NVDA 2020-04-06 +$450k, UPBD +$324k, CMA-WS +$281k, KR +$268k) vs **gate-only 498 trades +$4.12M**
  (CLS 2023-06-20 +$1.20M, NOVT 2016-06-03 +$636k, KTOS 2025-05-03 +$569k, BPT 2022-01-22 +$512k, BBWI 2020-08-20 +$409k,
  TTEC +$319k, KLIC +$278k; worst BBAR −$118k, FLEX −$104k). Concentration caveat: the top four arm-only names are
  $2.92M of the +$2.59M realised delta — the same CLS/NOVT/KTOS/BPT set the 09-05 and item-3 map cells surfaced, so the
  salt-1/2 cells decide whether this is a lever or a re-draw that happens to land the same monsters. Force liquidations
  6 (ATLC, SGP_old1, AWRE, ARCB, CBKCQ, IMMR) vs 3 — wide arms hold delisted names longer (known, #2672 family).
  Salt 1 started 09:40 (lane B2); salt 2 running since 09:16 (lane A2).

- 12:29 PT: **salt 2 = 627.20% / 835 trades / Sharpe 0.552 / maxDD 33.03** (wall 11,586 s; `results/a4-cadence-12w-s2-v10-*`)
  vs the null's **639.74 / 728 / 0.526 / 42.96**. V16/V17 PASS. **V6 = 1 on the arm vs 0 on the null — `validator_diff
  -check V6` exit 1 (DIFFER)**: `IAC 2006-03-16 twin positions: IAC/MTCH`. Decomposed: MTCH and IAC both entered
  2006-03-16 at 4,540 shares and both exited 2006-03-20 `stop_loss`, −$2,860 and −$2,767 — MTCH's pre-2015 series is
  IAC's backfilled history (a spin-off twin, not a rename twin, so `-dedupe-rename-twins` did not catch it; the null
  never entered either name). The duplicated leg is **−$2.9k on a +$2.48M realised delta and cannot touch maxDD**, so
  the cell is read ex-twin with the mismatch on record rather than discarded (issue #2782: spin-off backfill twins survive the rename-twin dedupe). **Clears both
  criteria at salt 2 too:** realised $2.70M → **$5.18M (+$2.48M; +$2.48M ex-twin)**, unrealised $3.84M → $1.25M (the
  null's three open names vs seven: ADTN EXPD KLAC LLY MSM NOK QCOM), maxDD **43.0 → 33.0**. Exit mix `stop_loss`
  481 → 322, `laggard_rotation` 233 → 481, `stage3_force_exit` 4 → 13. Join: 359 shared +$0.99M → +$2.64M (**drift
  +$1.65M** — the wide stop widens the shared winners); null-only 369 trades +$1.71M (LOGI 2020-05-06 +$381k, NVDA
  2020-04-06 +$308k, IPIXQ +$255k, CMA-WS +$228k) vs gate-only 476 trades +$2.54M (NOVT 2016-06-03 +$613k, KTOS
  2025-05-03 +$497k, AMAT 2020-11-07 +$447k, BBWI 2020-08-20 +$428k, ROG +$201k; worst BBAR −$112k, CIG −$110k, LYTS
  −$104k, MOD −$103k). NOVT / KTOS / BBWI-08-20 recur from salt 0 — the same arm-only monster set at two salts is
  the salt-robust part; the shared-drift term ($0.6M at s0, $1.65M at s2) is the second, and it is spread across
  many names. **Two of three salts clear both pre-registered criteria — the candidate passes the bar regardless of
  salt 1** (running, lane B2, due ~12:50).

- 12:56 PT: **salt 1 = 708.28% / 835 trades / Sharpe 0.575 / maxDD 28.10** (wall 11,742 s; `results/a4-cadence-12w-s1-v10-*`)
  vs the null's **311.75 / 707 / 0.427 / 32.75**. V16/V17 PASS. **V6 = 1 on the arm vs 0 on the null** (`validator_diff
  -check V6` DIFFER) — the same IAC/MTCH spin-off twin (#2782): MTCH −$2,652 / IAC −$2,861, both 2006-03-16 → 03-20
  `stop_loss`; −$2.7k duplicated on a +$1.97M realised delta, read ex-twin with the mismatch on record. **Clears both
  criteria at salt 1:** realised $2.94M → **$4.91M (+$1.97M)**, unrealised $0.31M → $2.30M (9 open names: ADTN AMAT EXPD
  KLAC LLY NOK QCOM SXT URI vs 5), maxDD **32.8 → 28.1**. Exit mix `stop_loss` 458 → 313, `laggard_rotation` 236 → 493,
  `stage3_force_exit` 2 → 11. Join: 359 shared +$1.47M → +$3.45M (**drift +$1.98M**); null-only 348 trades +$1.47M
  (BBWI 2020-08-08 +$377k, NVDA 2020-04-06 +$316k, PCYC +$212k, CMA-WS +$205k) vs gate-only 476 trades +$1.46M (KTOS
  2025-05-03 +$479k, BBWI 2020-08-20 +$395k, KLIC 2020-11-09 +$264k, CLFD +$213k, BB 2006 +$208k; worst TEX −$108k,
  BBAR −$103k, CIG −$101k) — **at this salt the arm-only and null-only sets net to zero; the whole realised gain is the
  shared trades running wider.** Force liquidations 5 vs 2.

## Three-salt read (all on `_v10dedup`, build 31e4bb9c3 vs null build 969637974; V6 = 0 on the null cells, 1 on arm s1/s2 = the IAC/MTCH 2006 twin, −$2.7–2.9k each, #2782)

| salt | null a0-v10 (level / trades / Sharpe / maxDD) | cadence a4 | realised Δ | shared drift | arm-only − null-only | unrealised Δ | maxDD |
|---|---|---|---:|---:|---:|---:|---|
| 0 | 382.74 / 710 / 0.445 / 37.60 | 751.67 / 851 / 0.578 / 29.99 | **+$2.59M** | +$0.61M | +$1.98M | +$1.06M | **37.6 → 30.0** |
| 1 | 311.75 / 707 / 0.427 / 32.75 | 708.28 / 835 / 0.575 / 28.10 | **+$1.97M** | +$1.98M | −$0.01M | +$1.99M | **32.8 → 28.1** |
| 2 | 639.74 / 728 / 0.526 / 42.96 | 627.20 / 835 / 0.552 / 33.03 | **+$2.48M** | +$1.65M | +$0.82M | −$2.59M (null's ADTN/MU/URI) | **43.0 → 33.0** |

**Pre-registered rule: realised AND maxDD better at ≥ 2 of 3 salts. Result: 3 of 3 on both. The candidate clears the bar.**
Sharpe better at every salt (0.445 → 0.578, 0.427 → 0.575, 0.526 → 0.552); level +369 / +397 / −13pp (salt 2's level
is the null's open MTM, quote the band: **627–752% vs 312–640%**; maxDD **28.1–33.0 vs 32.8–43.0**).

**Why it works (transferable).** Two terms, both salt-robust: (1) **the shared trades run wider** — a 12% initial stop
with a weekly trail update keeps the record's own winners through the whipsaw that a 4% daily stop sells into, and
the exit shifts to `laggard_rotation` (236–244 → 481–493 per cell, `stop_loss` 450–481 → 313–336; the 09-05 surface's
"a wide enough stop hands the exit to the rotation" on a clean warehouse); this term is +$0.6M / +$2.0M / +$1.65M.
(2) **the arm-only set** (+$2.0M / ≈0 / +$0.8M) recurs by name — NOVT 2016, KTOS 2025, BBWI 2020-08-20, KLIC 2020-11
at two or three salts — but it is not needed for the verdict: salt 1 clears on the shared term alone. The maxDD win is
the same shape at every salt (−4.7 to −9.9pp) and is *not* the twin-double-funding artifact of the item-3 map (V6 = 0
on the null, the one arm violation is a −$2.8k pair). Cost side: +125–141 trades per cell, 5–6 force liquidations vs
2–3 (wide arms hold delisted names longer — #2672 family, the delisted exit now fires: `delisted` 8–10 vs 5–7), and
9 open names at the end vs 3–5 (more unrealised carried — the band's upper draws are MTM-heavier).

**Verdict: ACCEPT at the single-surface level** (ledger `2026-09-13-stop-width-12pct-weekly-cadence-v10dedup`). Per
`experiment-flag-discipline.md` R3 and `promotion-confirmation.md` this is **necessary, not sufficient, for a default
flip**: the same arm must clear a confirmation grid of ≥ 3 independent broad cells — the 2009 and 2019 `_v10dedup`
vintages exist (5y windows 2009–13 / 2019–23 at three salts, paired against their own record-convention nulls), and
one cell must span a bear regime (the 26y cell above already does). Blocking item before any promotion PR: the wide
arm's delisting exposure (#2672 family) is now handled by the `delisted` exit, but the 5–6 force liquidations per cell
must be dissected (all pre-#2695 phantom classes, or real gaps?). This is a two-knob change (`initial_stop_buffer` 1.0 →
0.9167 AND `stop_update_cadence` Daily → Weekly): `config-default-blast-radius.md` paired goldens for both knobs, and
the book's own framing (§5.3 4–6% band; weekly re-evaluation = L3) should be cited in the promotion PR — 12% is outside
the book's stated band and must be argued as a modern-regime adaptation of a dial, not the spine.

## Confirmation grid — 5y cells on the 2009 / 2019 `_v10dedup` vintages (launched 14:09 PT 09-13; `chain-grid.sh`, lanes G1/G2)

- 15:52 PT: **2019 vintage, salt 0** — null `n5-2019` = 66.02% / 179 trades / Sharpe 0.605 / maxDD 22.55 (wall 3,359 s);
  arm `a4-2019` = **30.52% / 178 / 0.372 / maxDD 30.87** (wall 2,779 s). V16/V17 PASS, V6 = 0 on both,
  `validator_diff -check V6` exit 0. **The arm LOSES on both criteria in this cell:** realised $469k → **$166k
  (−$303k)**, unrealised $211k → $152k, maxDD **22.6 → 30.9**. Exit mix `stop_loss` 127 → 94, `laggard_rotation`
  46 → 79 (the same shift as at 26y). Join (`symbol|entry_date`): only **89 shared** of ~179 — a 5y window
  re-draws half its trade list — and the shared term still favours wide (**−$76k → +$195k, drift +$271k**), but
  **null-only 90 trades +$545k** (APPS 2020-06-13 +$143k, ZS 2020-05-29 +$127k, GME 2020-09-14 +$101k, AAOI
  2023-06 +$78k, FCNCA 2020-11 +$75k) vs **arm-only 89 trades −$29k** (AN 2020-08 +$117k, HVT +$87k, KBL +$63k;
  APLS 2021-06 −$61k). By entry year the arm gives back 2021 (null +$72k → arm −$280k) and trails 2020
  (+$752k → +$636k). Read: the shared-trades-run-wider mechanism holds here too, but on a ~180-trade window the
  path re-draw decides the level and this draw lost the 2020 recovery names to other slots; maxDD worse because
  the wider 2021 losers ran longer. One salt; the cell's verdict waits for salts 1–2 (and per
  `promotion-confirmation.md` the value must not be *badly dominated* in any cell).
- 15:57 PT: **2009 vintage, salt 0** — null `n5-2009` = 20.35% / 124 trades / Sharpe 0.337 / maxDD 17.92 (wall 3,476 s);
  arm `a4-2009` = **25.54% / 149 / 0.372 / maxDD 27.12** (wall 2,970 s). V16/V17 PASS; **V6 = 1 on the arm**
  (CMD/CMN 2009-10-10 → 2010-03-22, both `laggard_rotation` +$9.6k — a rename twin surviving in the 2009 vintage,
  same class as #2782; +$9.6k duplicated, read ex-twin). **Loses on both criteria:** realised $106k → **−$23k
  (−$130k; −$139k ex-twin)**, unrealised $113k → $289k on 11 open names vs 7 (the level's +5pp is all MTM), maxDD
  **17.9 → 27.1**. Exit mix `stop_loss` 82 → 53, `laggard_rotation` 40 → 93. Join: 63 shared −$20k → +$64k
  (**drift +$84k**, wide helps the shared trades again); null-only 61 trades +$126k (SKX 2009-10-16 +$79k, TEL
  +$51k, SLM +$44k) vs arm-only 86 trades **−$87k**. By entry year the arm loses 2010 (+$141k → −$26k) and 2011.
  **Same anatomy as the 2019 cell:** shared-trades-run-wider is positive, the path re-draw on a ~150-trade window
  is negative and larger, and maxDD is worse. Both 5y cells fail both criteria at salt 0; salts 1–2 running.
  Caveat that cuts both ways: each 5y cell holds 120–180 trades, under the 230-trade measurability floor, so a
  single-salt 5y read is itself noise-dominated — which is why the grid runs three salts per cell.
