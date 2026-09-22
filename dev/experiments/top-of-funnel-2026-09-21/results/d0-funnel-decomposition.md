# d0 — PIT-band funnel decomposition (null s0, `--emit-candidates`)

Cell `d0-funnel-diag-s0-v11`: the `a0-pit-null` config unchanged, salt 0, run with `--emit-candidates` so
`candidates.sexp` carries every weekly cascade population with its drop phase. Run 2026-09-21 13:25–20:49 PT on
`sweep-funnel` @ `ad5a9e04e`, warehouse `/tmp/snap_top3000_pit_v11pit` (9,364 entries), cap 12,000.

**Tripwire: MATCH.** `trades.csv` md5 `c1352be681e2eea3bf50d5c58a94f8a7` = the committed null s0; 457.01 % / 732 trades /
maxDD 40.64 / Calmar 0.165, V6 = 0 (`validator_diff -check V6` exit 0). The build the arm runs on reproduces the band.

**Cost of the diagnostic (perf note):** wall 26,681 s (7h25m) vs 3h37m–4h19m for the same cell without emission;
peak RSS 7.60 GB vs ~4.2 GB; `candidates.sexp` 945 MB / 19.0 M lines (not committed). `--emit-candidates` roughly
doubles the cell. Cache line: `hits=153.6M misses=6.30M miss_absent=6.29M evictions=0 n_symbols_absent=551` — every
miss is the 551 absent names, none are evictions.

Derivation: `funnel.awk` streams `candidates.sexp` into `date,kind,key,count` rows (`kind` ∈ outcome / gate / grade);
`results/d0-funnel-by-year.csv` is the per-year roll-up. Both awk, run in the container.

## The funnel, 2000-01 → 2026-06 (1,335 Fridays, 3,058,821 candidate rows)

| phase | rows | share |
|---|---:|---:|
| Dropped_at_breakout | 2,439,811 | 79.8 % |
| — Stage_setup | 2,111,432 | 69.0 % |
| — Breakout_volume | 297,667 | 9.7 % |
| — Rs_declining | 30,712 | 1.0 % |
| Dropped_at_grade | 30,006 | 1.0 % |
| Dropped_at_rs | 50,007 | 1.6 % |
| **Dropped_at_top_n** | **516,323** | **16.9 %** |
| Admitted (≤ 20 / week) | 22,674 | 0.7 % |

Per week: ~2,290 candidates → ~1,830 die at the breakout gate (1,580 of them Stage_setup, i.e. not a Stage-2 breakout
this week) → ~60 at grade/RS → **~390 survive every gate and are cut by the top-N cap** → 17 admitted on average
(the 20-cap is short only in 2001–02 and 2008–09).

## The cap binds essentially every week

| measure | value |
|---|---:|
| weeks with ≥ 1 Dropped_at_top_n | 1,323 / 1,335 (**99.1 %**) |
| weeks with ≥ 20 Dropped_at_top_n (arm's slots 21–40 fill completely) | 1,285 / 1,335 (96.3 %) |
| mean Dropped_at_top_n per cap-bound week | 390 (105 in 2001, 638 in 2013) |

So the pre-registered "inert arm expected if cap-bound weeks < 10 %" branch does not apply: the arm changes the
admitted list in 96 % of weeks. Whatever the arm does downstream is a real read of capacity, not a scoping artifact.

## What the marginal 21–40 look like (grade mix)

| outcome | A_plus | A | B | C | D | F |
|---|---:|---:|---:|---:|---:|---:|
| Admitted | 94.4 % | 5.2 % | 0.3 % | 0.1 % | 0 | 0 |
| Dropped_at_top_n | 8.7 % | 40.5 % | 32.2 % | 18.6 % | 0 | 0 |

Ranking is by score with an alphabetical tiebreak (`project_screener_alphabetical_tiebreak`), so the cut at 20 falls
*inside* the A_plus block whenever more than 20 A_plus names survive the gates. Mean **33.8 A_plus names per week are
dropped at top-N**; in **786 / 1,335 weeks (59 %) ≥ 20 A_plus are dropped**, so the arm's extra 20 slots fill with
A_plus names that differ from the admitted 20 only by ticker order. In 196 weeks (15 %) no A_plus is dropped and the
extra slots take A / B names (2001: 17 such weeks; 2008–09 and 2021: 13–17).

Per-year A_plus-dropped ≥ 20 weeks (from `d0-funnel-by-year.csv`): 2005–06 43–46/51, 2014–16 38–42/50, 2021 17/50,
2009 13/49 — the marginal-40 list is deepest in trending years and thinnest in the post-crash and 2021 years.

## Implication for reading the arm

- The arm's mechanism is **alphabetical-lottery breadth within A_plus**: names ranked 21–40 are score-tied with names
  1–20. The paired read therefore tests whether *more* score-tied Stage-2 breakouts per week helps (more shots at the
  fat tail, per `project_edge_is_the_fat_tail`) or hurts (more stale-entry breadth, whipsaw premium), not whether
  ranking skill exists (it does not; `project_cascade_selection_inversion`).
- The screener admits 20/week but the book only fills ~28 entries/year, so the binding constraint below the screener
  is slots + cash + trigger. If the arm's trade list is nearly identical to the null's (shared ≫ arm-only in
  `paired.sh`), capacity at the screener was never the leak and the funnel's monster loss at top-N (#2490, 36 %) is
  actually a downstream-slot loss. That is a finding, and it redirects the next lever to slot policy, not cap width.
- Read by entry-year; scope to 2022–25 separately (the ≥ +20 % winner share fell 10 % → 2 % there).
