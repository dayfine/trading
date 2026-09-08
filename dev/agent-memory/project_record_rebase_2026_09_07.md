---
name: project_record_rebase_2026_09_07
description: "CANONICAL RECORD re-based 2026-09-07 on the clean 2000-vintage warehouse (snap_top3000_2000_v7mark, build #2695 b48537469, record convention, guards default): 263% median, 181-562% across salts 0-2, 705-755 trades, Sharpe 0.32-0.52, maxDD 42-45%; every cell V16/V17 clean (0 fallback exits, 0 stale entries; STMP delisted at $329.61). Supersedes 302.65% (defective warehouse). The +300pp at salt 1 = AEIS-2025 (+$973k) and MOS-2006 (+$806k) monsters, salt-1-only. Quote the band, never one draw."
metadata:
  type: project
---

**Record (2026-09-07):** `dev/experiments/warehouse-rebuild-2026-09-06/README.md` §Step 6.
Spec `rec26y-new` (record convention, `entry_max_bar_age_days 0`, `stale_exit_without_prior_bar false`,
`stale_exit_after_days 5`), warehouse `/tmp/snap_top3000_2000_v7mark` (2,999 names; #2691 build-time
series-tail truncation; #2695 survivor markers, 2,217 marked), build b48537469 (= merged b0b411df6).

| salt | return % | trades | Sharpe | maxDD | realised P&L | drivers |
|---|---:|---:|---:|---:|---:|---|
| 0 | 263.16 | 707 | 0.39 | 42.37 | +$2.44M | LOGI/BBWI/NVDA 2020 |
| 1 | 561.61 | 705 | 0.52 | 45.15 | +$4.97M | + AEIS 2025 +$973k, MOS 2006 +$806k |
| 2 | 180.89 | 755 | 0.32 | 42.18 | +$1.74M | |

369 trades shared by all three salts. Old record (defective warehouse): 302.65 (s0) / 180.23 (s1).
Drawdown is ~6pp worse on clean data across all salts — dissect before re-stating any
stop-width read. 5y cells: 2000 = 76.69% / 98; 2019 = 42.37% / 175 (warehouse survivor-tilted).
**Acceptance criteria that make this the record:** V16 = 0 fallback exits, V17 = 0 stale
entries on every cell; the 7 former blank rows render `delisted`; STMP exits at $329.61.
Related: [[project_delisting_guards_2672]], [[project_record_rebase_2026_09_03]],
[[project_edge_is_the_fat_tail]], [[project_clock52_promoted]].
