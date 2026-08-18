# AXTI's entry construction, re-derived from raw daily bars

Independent check of the 08-16 dissection (`project_stop_gate_not_entry_anchor`),
using only `data/A/I/AXTI/data.csv` — no audit artifact, no strategy code. It
also supplies the fixture for the unit test that pins this construction (the
"Task 20" item: a `goldens-small` scenario cannot reproduce these decisions,
because a small universe changes ranking, sector RS and the macro gate; the
*entry construction* is what is pinnable).

## The weekly bars (Mon–Fri buckets, from daily OHLC)

| week ending | high | low | close |
|---|---|---|---|
| 2025-03-07 | 1.6550 | 1.4550 | 1.62 |
| 2025-03-14 | 1.8100 | 1.5100 | 1.80 |
| 2025-03-21 | 1.8984 | 1.6450 | 1.68 |
| 2025-03-28 | 1.8300 | 1.4500 | 1.48 |
| 2025-04-04 | 1.5500 | 1.1800 | 1.24 |
| 2025-04-11 | 1.4800 | 1.1300 | 1.16 |
| 2025-04-17 | 1.2700 | 1.1300 | 1.19 |
| 2025-04-25 | 1.4500 | 1.1400 | 1.42 |
| 2025-05-02 | 1.5700 | 1.2600 | 1.39 |
| 2025-05-09 | 1.3900 | 1.2300 | 1.25 |
| 2025-05-16 | 1.5500 | 1.3200 | 1.49 |
| 2025-05-23 | 1.6100 | 1.3800 | 1.46 |
| 2025-05-30 | 1.6000 | 1.4500 | 1.51 |
| **2025-06-06** | 1.8300 | 1.4700 | 1.78 |
| **2025-06-13** | **2.7000** | 1.8000 | 2.16 |
| **2025-06-20** | 2.1800 | 1.8100 | 1.84 |
| **2025-06-27** | 2.2301 | 1.8000 | 2.03 |

The 2.70 is a single day: 2025-06-12, which traded 6.81 M shares against a
~300 k daily average — the breakout bar.

## The construction reproduces exactly

- **Anchor window.** The four bars ending on the decision week (06-06, 06-13,
  06-20, 06-27) have max high **2.70** = the recorded `local_range_top`.
- **Entry.** `E = 2.71`, i.e. the range top plus a one-cent buffer — the
  recorded value, and history-independent as #2350 established (the window is
  4 *bars*, not a function of run length).

So both quantities the dissection reported are reproducible from public bars.

## Why the ticket could never be admitted — arithmetic, not policy

A book-faithful stop sits under the base. The base here is the April–May
consolidation, lows **1.13–1.47**. From `E = 2.71`:

| stop placed at | distance from E |
|---|---|
| base low 1.13 | **58.3%** |
| base low 1.45–1.47 | **45.8–46.5%** |
| 4-week low 1.80 | **33.6%** |

`max_stop_distance_pct = 0.15` requires a stop at **≥ 2.30**, which is inside
the decision week's own trading range (low 1.80) — not a structural level at
all. The candidate is therefore rejected by the width gate under *any* base-
anchored stop, which is what the artifact shows: **21 `Stop_too_wide`
rejections**, never an anchor problem.

**The general statement.** A stock that runs ~50% off its base in three weeks
has a book-faithful stop more than 15% below its breakout **by arithmetic**. So
`max_stop_distance_pct` does not filter "risky" entries in any behavioural
sense — it filters *fast movers off deep bases*, which is the same population
`project_faithful_ticket_structural_exclusion` identified and the same one
`dev/notes/demoted-wide-cohort-derivable-2026-08-18.md` finds the gate reaching
(only `Support_floor` stops, mean 13.2%, are anywhere near it).

AXTI then went 2.03 → 11.76 (5.8×) in four months.

## What the unit test should pin

Using the 17 weekly bars above as a committed fixture:

1. `local_range_top = 2.70` from the 4-bar anchor window at 2025-06-27.
2. `E = 2.71`.
3. `Stop_width_mode.gate` returns `Drop` under `Drop_over_max` @ 0.15,
   `Admit_sized_down` under `Size_down` with a ceiling above ~0.47, and `Admit`
   under `Demote_over_max` with the same ceiling — one assertion per mode, so
   the three policies are pinned against one real, reproducible candidate.

Nothing here is a claim that admitting AXTI would have been *right*; the
counterfactual is untested. What is pinned is that the exclusion is structural
and arithmetic, so a debate about it is a debate about the ceiling, not about
the anchor or the classifier.
