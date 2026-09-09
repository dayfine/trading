---
name: record-rebase-2026-09-09
description: ⭐ RECORD BAND on the DEDUPED 2000 warehouse (`_v10dedup`, V6 = 0): 312 / 383 / 640% (salts 1/0/2), maxDD 32.8–43.0, 707–728 trades, build 969637974 — supersedes the 09-07 `_v7mark` band (181–562, median 263). Salt 2's 640 = $3.84M unrealised on ADTN/MU/URI: quote the band, never the top. `_v10dedup` is a NEW path draw vs `_v7mark` (diverges 2005-02-04), not record-minus-twins.
metadata:
  type: project
---

**Cells** (`dev/experiments/stop-width-by-state-2026-09-08/results/a0-breadth-on-null-s{0,1,2}-v10-*`; a0 = record spec + breadth read ON with an empty map, shown inert = the record at three salts on `_v7mark`; r0 tripwire on `_v10dedup` 09-09 14:03 = a0-s0-v10 byte-identical):

| salt | return | trades | Sharpe | maxDD | realised | unrealised | open |
|---|---:|---:|---:|---:|---:|---:|---|
| 0 | 382.74 | 710 | 0.445 | 37.60 | $3.24M | $0.78M | 4 |
| 1 | 311.75 | 707 | 0.427 | 32.75 | $2.94M | $0.31M | 5 |
| 2 | 639.74 | 728 | 0.526 | 42.96 | $2.70M | $3.84M | ADTN MU URI |

Warehouse: `/tmp/snap_top3000_2000_v10dedup` (2907 snaps; 83 twin groups / 91 symbols dropped, MEL quarantined; `warehouse-dedup-2026-09-08/`). V16/V17 PASS, V6 = 0 every cell. Exit mix ≈ 450–480 `stop_loss` / 235–245 `laggard_rotation`; force liquidations 2–3 (GERN, AWRE = special distribution, BCRX/CLE).

**Rules:** every arm on the 2000 vintage after 09-09 pairs against THIS band at the same salt on `_v10dedup`, gated by `validator_diff -check V6` = 0 (#2735). Never quote a `_v7mark` (V6 > 0) figure as the comparator again. The v7→v10 null-vs-null join (465 shared keys, 349 re-sized, first divergence 2005-02-04) means dedupe re-draws the whole path — a new warehouse = a new band, always three salts.

Supersedes [[record-rebase-2026-09-07]] (the `_v7mark` band; keep for the twin-inflation history). Related: [[stop-buffer-by-macro-state-axis]], [[warehouse-vintage-coverage]].
