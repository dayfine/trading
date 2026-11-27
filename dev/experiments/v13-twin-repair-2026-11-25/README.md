# pit-v13 rename-twin repair (2026-11-25)

Fixes defect D1 of universe-depth K=5 (#3721, `../universe-depth-2026-11-23/RESULTS.md` §1.3 and D1/D2) and extends
the twin check (#3713). The v13 lists held one instrument under two symbols in the same year, so every paired read
failed V6. There were two classes:

- pairs v12 had already dropped and v13 let back in (CMD/CMN, EURN/CMBT and 918 other list cells);
- aliases new to the lists, mostly from the 11-23 fetch (GLPG/LKFT, KONA/KONAQ, NCS/CNR_old2).

## Method (host-only, POSIX sh + awk)

1. **Whole-union v13 scan.** Run the v12 scan unchanged on the v13 lists: `LISTS=<pit-v13/composition>
   sh ../v12-twin-scan-2026-10-22/twin-scan.sh <out>`, then `LAST_YEAR=2026 sh ../v12-twin-scan-2026-10-22/window-drops.sh
   <out>`. `LAST_YEAR` is new; its default of 2025 keeps v12's behaviour. This is the evidence v12 used:
   - fingerprints and a full return compare of every candidate pair, over the bar store at
     `/Users/difan/Projects/trading-1/data` (11-23 fetch included);
   - the `Twin_detector` Returns criterion and the later-last-bar survivor rule;
   - a per-list window decision.

   The union is 13,171 symbols, every one with a CSV. That gave 435 candidates and 317 confirmed twins. 2,862 (list,
   pair) cells have both legs in one list, and 2,121 of them are one series in that list's window (262 pairs). The
   scan runs in about 3 minutes. Scanning the union is enough because a list can only double-hold a pair whose legs
   are both list members, so a store symbol outside every list cannot double a holding.
2. **`repair.sh <out>`.** It builds the new rows, applies them and rewrites `pit-v13/twin-drops.txt`. Steps:
   - **Inherited.** Every `pit-v12/twin-drops.txt` row is checked against both v13 lists of its year (top-3000 and
     top-4000). Where both legs are present, v12's decision is kept (918 rows, 95 pairs).
   - **Scan.** It adds the scan's drop cells, less `exclude-pairs.txt`, with a v12 pair turned to v12's direction (1,107
     rows).
   - **Nesting** (added 2026-11-26, #3732 QC). A top-4000-Y cell whose dropped leg stays in top-3000-Y, while its
     survivor is not there (it ranks 3001-4000), is flipped: top-4000-Y keeps the top-3000 leg and drops the other.
     So top-3000-Y stays inside top-4000-Y, and the top-3000 lists are the same as in #3727. 72 rows are flipped
     (`src=...,nest` in `new-rows.txt`).
   - **Chains.** One row per (list, dropped symbol), with survivor chains resolved.
   - **Apply.** `apply-drops.sh` cuts the entries. 36 existing v13 rows had a survivor that this repair dropped. They
     are re-pointed (`via=`) so they still describe the list.

   The script is deterministic. Re-run from the pre-repair lists, it reproduced the committed lists, `twin-drops.txt`
   and `new-rows.txt` byte for byte. A second run applies nothing.
3. `composition.md5` regenerated. `composition-raw.md5` describes the pre-alias raw lists and is unchanged.

## Result

| | before | after |
|---|---:|---:|
| `twin-drops.txt` rows | 15,592 | 17,617 (+2,025) |
| top-3000 entries (29 lists) | 80,866 | 80,078 (−788) |
| top-4000 entries (29 lists) | 107,831 | 106,594 (−1,237) |
| union top-3000 / top-4000 | 10,388 / 13,171 | 10,290 / 13,061 |
| schedule union 1999-2025, top-3000 (S3) / top-4000 (U4) | 9,679 / 12,330 | 9,583 / 12,221 |

The named pairs (count of lists holding both legs, before → after):

| pair | before | after |
|---|---:|---:|
| GLPG/LKFT | 20 | 0 |
| CMD/CMN | 11 | 0 |
| KONA/KONAQ | 4 | 0 |
| NCS/CNR_old2 | 9 | 3 |
| EURN/CMBT | 19 | 0 |

The three NCS/CNR_old2 lists left are `top-3000-2019`, `top-4000-2019` and `top-4000-2012`. The window rule kept
them as distinct series:
- in 2019 there are 7 shared return pairs, none matching (NCS's last bar is 2019-07-09);
- in 2012 the match is 0.035.

The held cell, `top-3000-2017`, is dropped (252 pairs, match 1.0000).

**New pairs** (`results/new-pairs.txt`): there are 164 pairs that `pit-v12/twin-drops.txt` does not name. For each,
the file gives:
- how many list cells it is dropped from (in a flipped top-4000 cell the other leg leaves);
- which legs are absent from every pit-v12 list;
- whether the dropped leg is in EODHD's delisted list (`data/delisted_symbols.sexp`,
  `/api/exchange-symbol-list/US?delisted=1`);
- the scan's whole-history evidence.

What the file shows:
- In 156 of the 164 pairs, at least one leg is new to the lists, which is the 11-23 class.
- The dropped leg is EODHD-delisted in 149 pairs (KONAQ, NCS and the many `…Q` bankruptcy tickers).
- GLPG/LKFT: one series from 2015-05-14 to 2026-05-07 (run 2,761) with 2,922 identical raw closes. GLPG's file ends
  2026-05-07 and LKFT's continues, so GLPG leaves 20 lists.

**Caveat on the survivor.** The survivor is the leg with the later last bar in the store, so it is sometimes the
vendor alias. Examples: PPLI for MTCH (36 lists), LKFT for GLPG, KYOAY for KYOCY. Inside a dropped window both files
carry the same bars, so a backtest is unaffected by which leg stays. Live picks read the v12 lists, not these.

## The check

`trading/devtools/checks/pit_twin_cooccur_check.sh` now checks every `pit-vN` vintage that has a `twin-drops.txt`,
in version order. It replaces the one pit-v12 rule, which closes #3713. For each vintage it runs these tests:
- **its own rows**, as before;
- **every earlier vintage's rows**: it fails when any same-year list of the vintage holds both legs. The year comes
  from the list name, so v12's top-1000 and top-3000 rows reach v13's top-3000 and top-4000 lists.
- **nesting** (pit-v13 on, added 2026-11-26): every top-N list must be inside the same year's larger lists, so a
  top-3000-Y name missing from top-4000-Y fails. pit-v12 is not checked, because it is not nested (see below).

Its self-test covers the inherited and nesting cases. The membership read is a single awk pass, so the whole check runs in
about 2 s.

- **Pre-repair v13** (`results/check-pre-repair.txt`) fails: `FAIL: pit-v13: pit-v12 twin pairs are both back in a
  same-year list`, with 920 (list, pair) cells, CMN/CMD and EURN/CMBT among them.
- **After the repair** it passes: `OK: pit-v12: 784 own twin drops hold`, `OK: pit-v13: 17617 own twin drops hold`
  and `OK: pit-v13: no pit-v12 twin pair co-occurs in a same-year list`.
- **The #3727 lists** (main at 96b4eb2b, `results/check-main-96b4eb2b.txt`) fail the nesting test with 71
  (list, symbol) cells, PPHM in `top-3000-2004` among them. The nested lists pass it.

**Limit.** The check can only see twins that some drops file has recorded. A brand-new alias, like GLPG/LKFT, is
found by the scan, not by the check. Every new list build must re-run step 1. The pairs recorded here become
inherited rows for the next vintage.

## Nesting fix (2026-11-26, #3732 QC)

#3727 decided each list on its own. When one twin leg ranks inside top-3000 and the other only in 3001-4000, the
pair co-occurs only in top-4000. So only top-4000 dropped a leg, and the survivor rule sometimes dropped the leg that
top-3000 keeps. The result was 71 name-years (29 symbols) in `top-3000-Y` but not in `top-4000-Y`. Example: PPHM is in
`top-3000-2004`, while `top-4000-2004` held CDMO and no PPHM. The pre-repair lists had 0 such cells.

The nesting step above re-derives every file from the pre-repair lists. The top-3000 lists are unchanged from #3727.
20 top-4000 lists change: each flipped cell keeps the other leg. `twin-drops.txt` still has 17,617 rows, 72 of them
flipped. `composition.md5` is `140ae53e42ab75d812ebbe4350fd5688` (was `d587c509…`). The S3 schedule union stays
9,583, and U4's goes from 12,215 to 12,221.

## Dollar volume: the twin legs' ADVs differ by split factors (finding, not fixed)

The lists rank on `Dollar_volume_basis.True_dollars` (`--true-dollar-volume`, #3136): raw close × stored volume /
F(t). F(t) is the product of each symbol's **own** `splits.csv` factors after t. A split counts only when the close
confirms it, and it is dropped when the volume check finds the stored volume raw across that split. Two twin legs
carry the same close series but differently restated volume columns, so the basis can scale them differently.
`results/adv-ratio.txt` gives the ratio for every repair row whose two legs are both ranked in a pre-repair list:

| ratio between the legs' ADV | rows | pairs |
|---|---:|---:|
| within 5 % | 1,313 | 203 |
| an integer factor of 2 or more (within 2 %) | 287 | 59 |
| other | 425 | 83 |

Of the 72 flipped nesting rows, 51 are integer factors and only 3 are within 5 %. So the nesting break is this
mis-scaling: the leg the basis over-scales ranks inside top-3000.

**Specimen: PPHM / CDMO 2004, ratio 7.00.** Both files hold the 2009-10-19 1:5 and 2017-07-10 1:7 reverse splits,
and both have the same raw close.
- CDMO's volume is restated smoothly through both splits: 35,598 shares on 2009-10-13 and 69,042 on 2009-10-19.
- PPHM's volume is raw before 2009 (1,245,945, then 345,214 and 54,314 across the split), and its 2017 step does not
  match 1:7 (1.5M to 0.6M).
- The volume check therefore drops PPHM's 2009 split but keeps the 2017 one, and multiplies PPHM's raw pre-2009
  volume by 7.
- The two files agree on raw shares × raw close in 2004: PPHM 404,079 × $2.24 against CDMO 11,545 × 35 × $2.24. So
  CDMO's $1.18M is about right, and PPHM's $8.27M is 7× too high. The leg that holds top-3000-2004 is the mis-scaled
  one.

**Not confined to the repair.** This is how the list builder scores any file whose volume column is restated for
some splits and not others. The twin cells only make it visible, because there two files of one instrument can be
compared. About 35 % of twin rows differ by more than 5 %, and nothing makes non-twin files immune. So ranks, and
membership at the 3000 / 4000 edges, can be off for other symbols in pit-v12 and pit-v13 alike. Fixing it means
changing `Dollar_volume_basis`, for example a per-segment volume restatement test, and rebuilding the lists. That is
outside this PR, which only restores nesting and keeps the top-3000 leg as #3727 ranked it.

**Also found:** pit-v12 is not nested either. 31 name-years of `top-1000-Y` are missing from `top-3000-Y`: the #3388
dedupe dropped the leg in top-3000 only, for example FORD/FWDI 2005, TROV/CRDF 2015 and USU/LEU 2005 and 2009.
pit-v12's lists are left as they are. The nesting test starts at pit-v13 (`TWIN_NEST_FROM`, default 13).

## Warehouse

No rebuild is needed. The lists only lose symbols, so every list symbol is still in the `v13pit-12710` manifest. The
dropped legs stay in the warehouse unused, as in the v12 repair.

## Files

- `repair.sh`, `new-pairs.sh`: the scripts.
- `results/`:
  - from the scan: `symbols.txt`, `candidates.txt`, `compare.txt`, `twins.txt`, `cooccur.txt`, `windows.txt`,
    `drops.txt`;
  - `new-rows.txt`: the 2,025 rows added, with `src=v12|scan`;
  - `new-pairs.txt`;
  - `check-pre-repair.txt`;
  - `check-main-96b4eb2b.txt`: the nesting failure on the #3727 lists;
  - `adv-ratio.txt`: the ADV ratio between twin legs.

There are no prices: the files hold symbols, dates, counts and match statistics only.
