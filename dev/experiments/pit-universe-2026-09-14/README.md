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

- **MISS (109, `results/fetch_miss.txt`):** `rows=0` "not found" (9), short real series under
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

## Coverage after (store 11,888 symbols; `results/union_missing_after.txt` = the 92 real names still absent)

| vintage | before | after | | vintage | before | after |
|---|---:|---:|---|---|---:|---:|
| 1999 | 2,371 | **2,886** | | 2015 | 2,605 | **2,890** |
| 2000 | 2,984 | 2,984 | | 2018 | 2,773 | **2,925** |
| 2003 | 2,531 | **2,910** | | 2019 | 2,935 | 2,935 |
| 2006 | 2,547 | **2,871** | | 2021 | 2,640 | **2,927** |
| 2009 | 2,885 | 2,885 | | 2024 | 2,824 | **2,986** |
| 2012 | 2,645 | **2,892** | | 2025 | 2,954 | **2,993** |

Every vintage 2000–2025 is now ≥ 95.7% covered (the residue is the MISS classes above plus
`_old` twins); the union 2000–2025 is 10,008 − 92 = 99.1%.

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
