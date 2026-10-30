# pit-v12 whole-universe rename-twin scan and per-list dedupe (2026-10-22)

Refs #3266 (chain V, `dev/experiments/verify-chain-v-2026-10-19/README.md` §1, §5, defect D1) and the #3057 detector
work. User-approved plan "(a) minimal", 2026-10-22.

## Why

Every chain-V cell bought CMN and CMD (Cantel Medical, old and new ticker) on 2009-11-09 and sold both on
2010-03-22, so every M-vs-N pair failed the V6 gate. Both symbols were in `pit-v12/composition/top-3000-2009.sexp`.
The v12 build had run the six cross-chunk pair scans (`rebaseline-v12-2026-10-08/warehouse-build/`), but with the
whole-overlap rule only (match fraction >= 0.95). CMN/CMD scores 0.933, because CMD's file carries another
instrument's quotes for most of 2016 (#3057 root cause). It is in no v12 twin report. The #3057 run criterion
(`-twin-min-matching-run`) was never armed on a v12 build.

## Method (host-only, POSIX sh + awk, no warehouse, no container)

1. `twin-scan.sh <out>`: the union of all 56 pit-v12 lists (9,279 symbols, every CSV present). Each symbol emits
   fingerprints (an anchor date plus its next 3 adjusted-close returns, rounded to 1e-3, flat windows skipped).
   Pairs that share at least 8 fingerprints get a full compare with the `Twin_detector` `Returns` unit: return pairs
   on consecutive shared dates, `|ra - rb| <= 1e-3`. A pair is **confirmed** when overlap >= 200 and (match >= 0.95
   or longest matching run >= 250, the #3057 N). The survivor is the later last bar, ties to the smaller symbol,
   which is the detector's rule. There are no chunks, so cross-chunk pairs are scanned like any other. Wall time
   was 14 min, and the scratch file of 4.9M fingerprints (~170 MB) was deleted afterwards.
2. `window-drops.sh <out>`: a confirmed pair can be one instrument for only part of its history. Examples are a
   ticker reused by a second company, a warrant file carrying the common's quotes, and a backfilled spin-off. So the
   decision is made **per list**, over the window that list governs, `[May 31 Y, May 31 Y+1)`. The loser leaves
   that list when, inside the window, at least 20 matching units are real moves (|r| >= 0.3 %) and the series are
   one (match >= 0.95, or a matching run >= 60 days). `exclude-pairs.txt` is never dropped: GOOG/GOOGL and
   LGF-A/LGF-B are share classes (`share_classes.sexp`, #3015 flag), and IAC/MTCH is a spin-off (#2782).
3. `apply-drops.sh <drops> <lists>` cuts each named entry out of its list by paren depth. It checks that the
   survivor is in the list, that the entry count falls by exactly the number of removals, and that the parens
   balance. Weights are not renormalised, as with `alias-lists.pl`; the schedule reads membership only.

## Result (`results/`)

| stage | count |
|---|---:|
| candidates (>= 8 shared fingerprints) | 193 (`candidates.txt`, `compare.txt`) |
| confirmed twins | 134 (131 by the run rule, 3 by fraction: DPW/GPUS, EURN/CMBT, MOSC/MOSC-U) (`twins.txt`) |
| confirmed, in no common list | 7 |
| (pair, list) cells where both legs are members | 1,112 (`windows.txt`) |
| **dropped** (one series in that list's window) | **790 entries, 107 pairs, 102 distinct legs, 54 of 56 lists** (`drops.txt`; 551 top-3000, 239 top-1000) |

**CMN/CMD was found.** It co-occurs in top-3000 2005, 2009, 2013, 2014 and 2015, and CMN is dropped from all five.
The window evidence for 2009 is 252 return pairs, match 1.0000, run 252 and 175 identical raw closes. 2015 is
dropped on the run rule: the two are one series from June to December 2015 (run 150), before CMD's file switches
instrument.

top-3000-2009 alone loses 31 legs. Among them are CMN, NCR (VYX carries NCR's history), CHFC (TCF), ETE (ET),
SSRI (SSRM) and the warrant files BAC-WS-A/B, C-WS-A, COF-WS, AIG-WS and STI-WS-A/B, which carry the common's quotes.

The largest classes:
- **Rename with a backfilled successor file**: NCR/VYX (39 lists), ETE/ET (19), SSRI/SSRM (16), QSII/NXGN (16),
  TIVO1/TIVO (17), CHFC/TCF (11), EBR/AXIA (15) and LB_old1/BBWI (25).
- **Warrant files that copy the common**: BAC-WS-A/B (34 each), C-WS-A (34), COF-WS (32), STI-WS-A/B (32) and
  AIG-WS (23).
- **Vendor copies of preferred series**: BML-P-*.

Pairs that the window rule kept in some lists (`windows.txt`, decision `keep`) are distinct series there. Examples
are MEE/FLR after 2000 (Massey, spun off as the old Fluor shell) and ATH/ELV after Anthem's ticker moved.

## Warehouse

No warehouse rebuild is needed for the M-pre3339 s0 rerun. A scheduled run's candidate set is the list membership
(`Universe_schedule.members_at`), and staging is the union of the list symbols (`union_sector_map`). A warehouse
symbol that is in no list is never a candidate. The lists only lose symbols, so every list symbol is still in the
9,236-symbol `_v12pit` / `_v12wk` manifest, and the launch guard that every list symbol be in the manifest holds.
The extra legs stay in the warehouse unused.

## Limits

- Same-company pairs with different adjustment histories can match on fewer than 60 consecutive days in a window, so
  they stay listed. The scan finds only what its returns criterion sees.
- Prefilter recall is not proven: a twin with fewer than 8 shared fingerprints (under about 56 aligned moving days)
  is not compared. The threshold is 4x looser than one 250-day run needs.
- The survivor is the later last bar. In a partial window (CMN/CMD 2015) that keeps the leg whose file later turns
  into another instrument, which is the detector's rule, kept as is.

## Applied scope (2026-10-22)

**This PR applies only the CMN/CMD rows** (`results/drops-applied-cmn.txt`: CMN leaves top-3000 2005, 2009, 2013, 2014
and 2015). That is the user-approved minimal fix for #3266: the twin that failed chain V's V6 gate. The scan's full
proposal (`results/drops.txt`, 790 entries in 54 lists) changes the universe far more than one twin, and every 26y
number would move with it; it is filed as its own issue, to be measured as a universe change before it is applied.
`pit-v12/twin-drops.txt` therefore holds 5 rows today.

**Superseded 2026-10-29 (#3388).** The full proposal is now applied by
`../twin-dedupe-26y-2026-10-29/apply-full-dedupe.sh`: `drops.txt` less the 6 BML-P rows (excluded after this scan
ran), survivor chains resolved per list, 784 rows in `pit-v12/twin-drops.txt`. The paired 26y read that sizes the
change is pre-registered there.
