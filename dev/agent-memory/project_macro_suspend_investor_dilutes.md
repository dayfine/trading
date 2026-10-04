---
name: project_macro_suspend_investor_dilutes
description: "Macro-suspend 10-04 (PR #3123): investor + entry_ticket_macro_suspend = live (0 Bearish-week fills) but DILUTES 5d+5r 3/3 salts; turn-of-market fills + window-end truncation drive it; no phase 2"
metadata:
  node_type: memory
  type: project
  originSessionId: 0bdb1704-90a7-4760-bb6e-40335d5259c0
  modified: 2026-10-05T01:34:43.699Z
---

**Result (2026-10-04, `dev/experiments/macro-suspend-investor-2026-10-04/`, PR #3123, build 81da500d5, salts 0–2):** msB (`entry_ticket_macro_suspend On_bearish_macro`) vs investor null. V6 exit 0 all pairs; ms0 = 10-02 ia0 on metrics (3 stop-column rows per pair differ: #3100 build change). Live: null 9 Bearish-week fills/salt at 5d (6 closed + 3 open at end), 3 at 5r; msB 0. Calmar lower 3/3 salts both windows → **dilutes**; no 26y phase; default stays Off; no ledger entry.

**Why (decomposed):**
1. Bear-week fills cluster at market turns: 5d's netted −$27k (good to drop) but 5r's +$33k (AIT Oct-2022, STN May-2025 = recovery starts). The gate lags the turn.
2. Suspend re-issues the ticket UNCHANGED → fills whenever price returns to the old trigger: DLX +7 months, STN +11 months, both stopped within days. Visible per trade but SMALL in aggregate: net of displaced null trades the re-shuffled slots cost −$3k to −$5k at 5d, mixed at 5r (QC rework caught the overstatement). Same stale/far-anchor defect as [[project_recovery_reentry_gap]] and the short tickets in [[project_shorts_liveness_dead]].
3. 5d verdict rests on window-end truncation: ONXX/WST/DUK bought May 2012 in Bearish weeks, +$38.7k open at the end; realised alone favours msB +$22–24k with better DD.

**How to apply:** don't revisit suspend-and-resume. If anything, a cancel-and-re-screen on gate reopen (re-qualify against the current base) is the coherent variant — separate pre-registration, not proposed. Count Bearish-week fills over trades.csv AND open_positions.csv (trades-only missed 3 at 5d). Packs: 5d TdVJjCRWwHPmkG9xQsUtvY, 5r FTqbLrE4S1HDCuXfK6PyNf.
