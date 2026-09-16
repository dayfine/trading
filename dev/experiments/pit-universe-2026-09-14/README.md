# PIT universe migration — step 2: fetch the union of the yearly top-3000 lists (2026-09-14)

Plan: `dev/plans/pit-universe-migration-2026-09-14.md` (step 2 of 6). Recipe: the 2026-09-08
gap fetch (`dev/experiments/warehouse-rebuild-2026-09-06/fetch_gap.sh` — EODHD `/api/eod`,
`>200`-row floor, `_old` synthetic twins skipped) run on the host against the CSV store
`data/<first>/<last>/<sym>/data.csv`, followed by the **vintage-date check** before anything
is rebuilt (first bar ≤ earliest list date + 90 d; the TMS lesson).

## Inputs

| list | names | how |
|---|---:|---|
| union of `top-3000-{2000..2025}` absent from the store, minus `_old` twins | 2,483 | `results/union_missing_before.txt` |
| `top-3000-1999` absent from the store (governs Jan–May 2000 under D2) | 424 | second pass, `results/fetch1999_2026-09-14.log` |

Store before: 9,093 symbols. Two runs of `fetch.sh` (8-way parallel), 10:45–10:51 PT, 2,907
requests, no throttling seen — the plan's "1–2 days quota-bound" estimate was wrong by ~300×.

## Results

| pass | OK | MISS | dead (last bar < 2026-08-01) | late (quarantined) |
|---|---:|---:|---:|---:|
| union 2000–2025 | 2,394 | 89 | 2,105 (88%) | 3 |
| 1999 | 404 | 20 | 395 (98%) | 0 |

- **MISS (109, `results/fetch_miss.txt`):** `rows=0` "Ticker Not Found" (16: 9 in the union pass + 7 in the 1999 pass), short real series under
  the 200-row floor, warrants/units (`-WS`, `-U`, `-W`), and `1`-suffixed legacy tickers
  (`BR1`, `EC1`, `PD1`, …) — the same classes as the 24 misses of 09-08. None is fetchable
  under this recipe; they stay absent and the runner skips them.
- **LATE (3, `results/vintage_check_late.txt`, quarantined to `/tmp/pit-fetch/quarantine/`
  and listed in `results/quarantine.txt`):** APXT (2021 list, first bar 2025-11-17), EXCE
  (2013 list, first bar 2019-07-30), TMS (2010 list, first bar 2025-04-21). All three are a
  new listing under a dead member's ticker; the row floor cannot catch them, the date check
  does. **TMS was already quarantined on 09-08 — into `/tmp`, which did not protect the store
  from a re-fetch.** From now on the quarantine list lives in the repo (`results/quarantine.txt`)
  and any fetch script must skip it.
- **The dead-name share (88% / 98%) is the point of the migration:** these are the names the
  year-2000 vintage record never sees and the survivor-tilted vintages under-weight
  (`project_pit_survivorship_inflation`).

## Coverage after (store 11,888 symbols)

Two conventions, stated separately because step 3b consumes one of them:

- **Real names.** Union 2000–2025: 10,008 − 92 = 9,916 = **99.1%** have bars; the 92 still-absent
  real names are `results/union_missing_after.txt` (the 89 union-pass MISSes + the 3 quarantined).
- **Counting absent `_old` twins as uncovered** (the per-vintage convention below, and what the
  D6 manifest check will see): union 2000–2025 = 10,008 − 92 − 379 = 9,537 = **95.3%**. The 379
  `_old` synthetic rename twins with no CSV were never in the fetch list (`fetch.sh` skips
  `*_old*`; `skip=0` because the input list already excluded them); the warehouse twin pass
  (`-dedupe-rename-twins`) resolves them against their survivors, so step 3b must expect
  ~471 union names absent from the manifest, not 92, and must account for them by class.

Per vintage, all 27 lists (`have` = members with a CSV; absent split into `_old` twins vs real):

| vintage | have / 3,000 | absent `_old` | absent real | have % |
|---|---:|---:|---:|---:|
| 1999 | 2886 | 94 | 20 | 96.2% |
| 2000 | 2984 | 2 | 14 | 99.5% |
| 2001 | 2940 | 47 | 13 | 98.0% |
| 2002 | 2916 | 70 | 14 | 97.2% |
| 2003 | 2910 | 75 | 15 | 97.0% |
| 2004 | 2891 | 95 | 14 | 96.4% |
| 2005 | 2876 | 106 | 18 | 95.9% |
| 2006 | 2871 | 115 | 14 | 95.7% |
| 2007 | 2876 | 113 | 11 | 95.9% |
| 2008 | 2870 | 121 | 9 | 95.7% |
| 2009 | 2885 | 108 | 7 | 96.2% |
| 2010 | 2872 | 117 | 11 | 95.7% |
| 2011 | 2886 | 102 | 12 | 96.2% |
| 2012 | 2892 | 97 | 11 | 96.4% |
| 2013 | 2881 | 108 | 11 | 96.0% |
| 2014 | 2892 | 95 | 13 | 96.4% |
| 2015 | 2890 | 95 | 15 | 96.3% |
| 2016 | 2894 | 93 | 13 | 96.5% |
| 2017 | 2907 | 82 | 11 | 96.9% |
| 2018 | 2925 | 67 | 8 | 97.5% |
| 2019 | 2935 | 57 | 8 | 97.8% |
| 2020 | 2940 | 50 | 10 | 98.0% |
| 2021 | 2927 | 34 | 39 | 97.6% |
| 2022 | 2966 | 28 | 6 | 98.9% |
| 2023 | 2978 | 14 | 8 | 99.3% |
| 2024 | 2986 | 12 | 2 | 99.5% |
| 2025 | 2993 | 6 | 1 | 99.8% |

Every vintage 2000–2025 has ≥ 95.7% of its members with bars (1999: 96.2%); the real-name
residue is ≤ 20 per vintage except 2021 (39, mostly SPAC units/warrants and 2021 IPOs that
the 200-row floor rejects). Before-values for the twelve vintages sampled in the plan §0
table: 1999 2,371, 2003 2,531, 2006 2,547, 2012 2,645, 2015 2,605, 2018 2,773, 2021 2,640,
2024 2,824, 2025 2,954 (2000 / 2009 / 2019 unchanged at 2,984 / 2,885 / 2,935).

## Open question from the plan (§5), answered

"Why do the lists contain names the store lacks?" — EODHD returned a real series for 2,394
of the 2,483 names (96.4%), so the 2026-06-05 list build did see bars for them; the store had
since lost or never carried them on this machine. The lists are consistent with the vendor
and need no provenance note; nothing is rebuilt.

## Next

- Step 3a (`universe_schedule` mechanism) — in flight, `feat-backtest`, branch
  `feat/pit-universe-schedule`.
- Step 3b — `_v11pit` warehouse from the union superset (1999–2025 ∪ `GSPC.INDX` ∪ the
  `_v10dedup` manifest extras), after 3a merges; container-exclusive.

## Step 3b addendum (2026-09-15) — the chunked build missed every cross-chunk rename twin

The first step-4 cell (salt 0, launched 21:54 PT 09-14 on the 9,597-entry `_v11pit`) ended two ways at
once: it hit the chain's 6 h `CELL_TIMEOUT` at ~96 % of the window (last trade 2025-05-15; a PIT cell on
the 10k-name union runs ~6.3 h, 2.3× the 2.7 h `_v10dedup` cell, because `_classify_all` stage-classifies
the whole union every Friday), and its partial validator report showed **V6 = 3 twin positions**
(ALTM/LTHM, GTM/ZI, GEAR/VSTO) — all three pairs split across the four build chunks, exactly the caveat the
chunked rebuild recorded. V6 sees only twins that were *held at the same time*; the real count was found by
scanning:

| scan | how | result |
|---|---|---|
| full union (10,504 names) | `build_snapshots -dedupe-rename-twins` on the superset | **OOM (exit 137, 5 min)** — the twin pass loads every symbol's bars before detecting |
| six chunk-PAIR unions (5,253 names each) | same command; `rename_twin_report.txt` is written before the per-symbol loop, so the build is killed once it exists (`step4/twin-scan/pair-scan.sh`) | 179–203 groups per pair, ~35 min each; a single pair scan was observed at ~4.3 GB by `docker stats` mid-run (the `peak seen` value in `pair-scan.log` is sampled after `pkill` and is a post-kill residual, not a peak) |

Per pair (`step4/twin-scan/analyze-pair.sh`) a leg is a real cross-chunk twin only on a **direct** edge
(overlap ≥ 200 bars, match ≥ 0.95), when its survivor is not a **hub** (> 4 legs: CISXF 65, BWLP, LNSPF,
IBDRY, BCAL — the flat/zero-return series class behind the false transitive drops in #2823), when it is not
one of the 84 legs deliberately restored in chunk 5, and when both legs are still indexed. That leaves
**239 edges / 233 legs** (`all-drop-edges.txt`: ELV/ANTM, DXC/CSC, CPAY/FLT, EXE/CHK, AABA/YHOO,
TFC/BBT_old, TPR/COH, AXON/TASR, KDP/DPS, LHX/HRS, JEF/LUK, GEN/NLOK, LUMN/CTL, BKNG/PCLN_old …).

Fix, no code: chunk 6 = one `-incremental -dedupe-rename-twins` rebuild whose universe is the 460 legs of
those pairs together, so the detector resolves each component and `Build_runner` drops the losers from the
manifest (9,597 → 9,363 in 40 s; `rename_twin_report_chunk6.txt`). One collateral: EMBT fell into the
{CISXF, ZAZZT, ZBZZT} test-ticker component and was rebuilt alone without dedupe (chunk 7 → **9,364**).
The 233 dropped legs were then aliased into the 27 yearly lists (`alias-lists.pl`, `alias3.txt`; per-list
dedupe) — union 10,133 → 9,900, effective breadth per year 2,792–2,993 (`step4/specs/composition-counts.txt`,
md5s in `composition-md5.txt`). D6 at relaunch: absent = 551 (450 `_old`, 101 real = 97 MISS + 3 quarantined +
MEL), unchanged.

Not reproducible from the repo alone: the as-run lists carry the 09-14 alias pass (`alias2.resolved`, 360
legs) plus a handful of hand edits that the two alias maps do not regenerate byte-for-byte (1–5 symbol lines
per list). Decision item: commit the 27 as-run lists (10 MB) under `pit-v11/composition/`, or keep them as
a host archive and pin by md5.

Lane A relaunched 07:45 PT 09-15 with `CELL_TIMEOUT=36000` (10 h), all three salts serial in one lane
(two workers exceed the container).

## Step 4 — record band on the PIT universe (2026-09-16, LANE A DONE 03:18 PT)

Spec `step4/specs/a0-pit-null.sexp`: the a0 null (record spec, `entry_order_max_rest_weeks 0`) with a
27-entry `universe_schedule` 1999–2025 (D1/D2 dating), run tree `sweep-pit @ 3a20f4987`, warehouse
`_v11pit` at 9,364 entries. Artifacts `step4/results/`.

| salt | return % | trades | Sharpe | maxDD % | realised P&L | unrealised | open | V6 | V16 | V17 | wall |
|---|---:|---:|---:|---:|---:|---:|---|---|---|---|---|
| 0 | 457.01 | 732 | 0.482 | 40.64 | $3.85M | $0.92M | 5 | PASS (0) | 2 (CLE 2014, ASPS 2017 — force_liquidation quality flags, same as the 2000-vintage band) | PASS | 5h58m |
| 2 | 152.03 | 762 | 0.297 | 51.32 | $1.40M | $0.29M | 5 (CBL EQNR FROG GE QCOM) | PASS (0) | 2 (same CLE, ASPS) | PASS | 7h05m |
| 1 | 188.05 | 766 | 0.329 | 53.05 | $1.67M | $0.41M | 7 (ETON EXEL FROG FTNT GE QCOM SXT) | PASS (0) | 1 (CLE) | PASS | 6h30m |

Levels are **not comparable** to the year-2000 vintage band (312 / 383 / 640 %, `_v10dedup`): different
construction (dated membership vs one survivor-tilted list), different warehouse. State the new band and
stop; every later arm pairs against THIS band at the same salt on `_v11pit`, gated by `validator_diff -check V6`.

**The band: 152 / 188 / 457 % (salts 2 / 1 / 0), median 188; maxDD 40.6–53.0; 732–766 trades; V6 = 0 on every
salt** (`validator_diff -check V6` over the three reports: `0 | 0 | 0 | agree`, exit 0). Quote the band, never a
salt. Salt 0's 457 is the salt-lottery top (final value $5.57M vs $2.52M / $2.88M) — the same shape as the
2000-vintage band's salt-2 640, and the spread across salts is wider here (3.0× vs 2.1×).

Exit mix per salt: stop_loss 495 / 530 / 530, laggard_rotation 221 / 221 / 223, delisted 4–6, extension_stop 2–4,
liquidity_exit 2–3, force_liquidation 1–2 (CLE 2014 on every salt, ASPS 2017 on s0/s2 — the V16 quality flags),
stage3_force_exit 1. The `delisted` exits are new relative to the 2000 vintage: a PIT schedule holds names that
later leave the market, and D4 (dropped names held to normal exit) lets `active_through` end them.

Comparison note — **do not read a level into the drop from 312 / 383 / 640.** The two bands differ in construction
(dated membership with ~2,800 effective names per year vs one survivor-tilted 3,000-name list), in warehouse
(`_v11pit` 9,364 vs `_v10dedup` 2,907 entries) and in path draw (every cell is a new draw at its salt). The
`project_warehouse_vintage_coverage` measurement already put the survivorship cost of a frozen vintage at −12 to −23pp
on a 5y window; a 26y window compounds it, so a lower PIT band is the expected direction, not a finding about the
strategy. The record is now this band: every later arm pairs against `a0-pit-null-s{0,1,2}-v11` at the same salt
on `_v11pit`, gated by `validator_diff -check V6`.

Cell cost: 5h58m / 7h05m / 6h30m at ~5.5–6.5 GB (single worker). Issue #2839 tracks cutting that without changing
stage continuity; membership pruning is explicitly out of scope (user decision 2026-09-15).

Inputs committed with this record: the 27 as-run lists under `trading/test_data/backtest_scenarios/pit-v11/composition/`
(md5s = `step4/specs/composition-md5.txt`), the spec, the chain + rebuild + twin-scan scripts, the alias maps, and
the per-cell artifacts under `step4/results/` (the precedent set: actual / params / summary / trades / validator /
open_positions / force_liquidations; trade_audit and equity_curve stay on the host under `/tmp/sweeps/pit-null/`).

## Drawdown dissection — 2021-11 → 2025-04 on the PIT band (2026-09-16, read-only)

Asked because the band's NAV, not its realised P&L, is what matters. Like-for-like at salt 0 the PIT NAV path ends
above the 2000-vintage path (5.57 vs 4.83 $M) and leads it for most of 2004–2021; the "much worse" band is entirely
the last five years on salts 1/2. Every arm on every universe peaks in late 2021 ($4.7–6.1M) and gives back 38–53 %
by 2024–25; PIT s0 recovers on one 2025 trade (ECHO +$647k), s1/s2 never do (2.88 / 2.52 $M; CAGR 4.1 / 3.6 %).

| salt | peak | trough | depth | exits in window: n / realised | marks on open positions |
|---|---|---|---:|---|---:|
| 0 | 2021-11-29 $5.94M | 2024-08-05 $3.53M | −40.6 % | 119 / −$1.37M (28 wins +$1.55M, 91 losses −$2.92M) | −$1.04M |
| 1 | 2021-02-11 $5.52M | 2025-04-07 $2.59M | −53.0 % | 190 / −$1.00M (55 / +$2.77M, 135 / −$3.77M) | −$1.93M |
| 2 | 2021-11-09 $4.66M | 2025-04-07 $2.27M | −51.3 % | 155 / −$1.46M (39 / +$1.18M, 116 / −$2.64M) | −$0.94M |

Entries dated 2021-11-01..2025-04-30, three salts pooled (453 trades, −$5.18M; the same window on the 2000-vintage
band: 402 trades, −$2.29M — same direction, 2.3× deeper here):

| entry year | n | P&L | losers | avg win | avg loss | exits |
|---|---:|---:|---:|---:|---:|---|
| 2022 | 126 | −$2.43M | 82 % | $24k | −$28k | 115 stop_loss / 11 laggard |
| 2023 | 144 | −$0.68M | 72 % | $52k | −$25k | 105 / 37 / 2 delisted |
| 2024 | 137 | −$1.39M | 69 % | $25k | −$25k | 96 / 41 |
| 2025 (to Apr) | 38 | −$0.45M | 76 % | $17k | −$21k | 36 / 2 |
| baseline 2010–2019 | 856 | +$4.29M | 65 % | $51k | −$19k | — |

Four mechanisms, in order of size:

1. **The macro composite outvotes a Stage-4 index (2022: −$0.8M per salt here, −$0.34M per salt on the old
   universe).** SPX closed below its 30-week MA from 2022-01-21 through November with the MA falling from April —
   Stage 4 by the book's own primary read ("most important single indicator", reference §2.1). `Macro.analyze`
   weights the index stage 3.0 against A-D line 2.0 + momentum 2.0 + NH-NL 1.5 + global 1.5 = 7.0, with
   `confidence = bullish / active > 0.65 → Bullish`: when the four breadth-type indicators flip bullish on a bear
   rally the index's Bearish 3.0 is outvoted (7 / 10 = 0.70). The weekly `trend` read **Bullish** for Jan–Feb,
   Jun–Jul and Oct–Dec 2022 and Neutral for most of the rest; it was Bearish for only a handful of weeks. Result:
   126 entries in 2022 (103–117 per salt under a Bullish label), 82 % losers, median hold 15 days vs 37 in the
   baseline, 55 % stopped out within 20 days. The macro gate never fired because the composite never said Bearish.
   Whether an index-in-Stage-4 veto (index stage as a hard gate, composite for aggressiveness only) is the faithful
   reading is a tier-1/tier-2 question — `weinstein-book-reference.md` §2.1 supports the index as primary; the book
   also uses the other gauges. Not settled here.
2. **Winner quality collapsed.** Entries reaching ≥ +20 %: 2.0 % of window entries (9 of 453, one ≥ +50 %) vs
   10.0 % in the baseline (86 of 856, 24 ≥ +50 %). Same avg-loss magnitude, half the avg win: the fat tail that pays
   for the stops (`project_edge_is_the_fat_tail`) was absent for three years, on both universes.
3. **Recent-vintage cohort (universe-specific).** Names absent from every list ≤ 2018 (the 2020–21 IPO/SPAC
   cohort: AXSM, BEAM, GETY, BLNK …) are 18–22 % of window entries but 40–50 % of the window loss (−$0.73 / −$0.87 /
   −$0.54M; 90 % losers). The frozen 2000 list could never hold them — this is the honest universe's cost, not a
   mechanism.
4. **Marks on positions open at the peak** (−$0.9 to −1.9M): the 2021 peak embedded unrealised gains on names
   like AMD / ON / CYTK / MPWR (s0) or ZS / WSC / FND (s1) that exited later with smaller gains.

**Consequence for the queue.** The largest single, universe-independent lever identified on the honest band is
mechanism 1. Proposed first experiment (pre-register before running): `macro_index_stage_veto : bool
[@sexp.default false]` — a Stage-3→4 / Stage-4 primary index blocks long entries regardless of composite confidence
(composite still governs aggressiveness) — as a 3-salt surface against `a0-pit-null-s{0,1,2}-v11` with
`validator_diff -check V6`, criteria realised AND Calmar at ≥ 2 of 3 salts, plus the paired 2022 entry cohort as
the mechanism read. Book check (tier 2, local) on the index-veto question comes first. Top-of-funnel work moves
behind it. Artifacts: `step4/results/*-trades.csv`, host `/tmp/sweeps/pit-null/*-equity_curve.csv`,
`*-macro_trend.sexp` (copies under `/tmp/twin-scan/`, not committed: 150 KB each × 3).
