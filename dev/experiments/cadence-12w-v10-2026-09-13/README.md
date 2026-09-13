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
