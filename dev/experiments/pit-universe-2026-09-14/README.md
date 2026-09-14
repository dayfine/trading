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
