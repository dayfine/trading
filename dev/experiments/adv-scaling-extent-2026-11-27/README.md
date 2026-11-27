# How far the mixed-restatement dollar-volume error reaches into the PIT lists (2026-11-27)

This is measurement only. The builder and the committed lists are unchanged.

The finding comes from #3734 (`../v13-twin-repair-2026-11-25/README.md` §"Dollar volume", on `data/v13-twin-nesting`).
The lists rank on `Dollar_volume_basis.True_dollars`: raw close × stored volume / F(t). F(t) multiplies the file's
own close-confirmed splits after t. The volume test (`volume_restated`) drops a split from F when the file's volume
looks un-restated across it. It decides each split on its own, so one file can be scored as raw across one split
and restated across another. PPHM in 2004 is the specimen: its 2009 1:5 split was dropped and its 2017 1:7 split
applied, so it scores 7× too high. This run asks how many list cells in pit-v12 and pit-v13 depend on that per-split
decision.

## The rule compared

The code is `trading/analysis/data/universe/lib/dollar_volume_basis.ml`: `close_confirmed_splits`, then
`volume_restated` per split (|log factor| ≥ log 3 and a 10-bar median volume jump share ≥ 0.5 means raw), then
`applied_splits`. It is used by `Build_from_individuals._dollar_volume_score`.

**Consistent rule, per-file vote.** A file's volume column is on one basis for all its splits. The vendor restates
a column as a whole when it back-adjusts, so a column that is raw across one split and restated across another is
much more likely to be a misread of the noisy 10-bar step than a real state.
- Every close-confirmed split that the current rule can test (|log factor| ≥ log 3, share measurable) votes with
  its jump share, weighted by |log factor|.
- If the weighted share is at least 0.5 (the current cut), the file is raw for every split, so F = 1. Otherwise
  every close-confirmed split is applied.
- A file with no testable split is restated, which is what the current rule does too.

The close test, the window, the 30-bar minimum and the $2e11 bar cap are unchanged.

The two rules differ only on **mixed files**: files where the current rule applies some close-confirmed splits but
not all. On every other file they give the same score. A mixed file under the current rule is inconsistent by
construction, so it is mis-scaled in at least one segment.

The vote is not always right either. Jump shares on serial reverse-splitters swing from −6 to +2, because offerings
and volume spikes sit on the split dates (`results/mixed-files.tsv`). PPHM and CISS look right under the vote. AIKI's
2012 rank goes from 2964 to 79, which is implausible for that name. So the counts below measure how many cells
**depend on the restatement decision**, not how many are wrong under the current rule. To bound that, `bounds.tsv`
also ranks two one-basis extremes. Each moves only the mixed files: all-restated (every close-confirmed split
applied) and all-raw (none applied).

## Method

1. `scan.sh` builds a throwaway OCaml scanner inside the checkout. It drives `Universe.Dollar_volume_basis` and
   `Composition_inputs`, runs it in the container and then deletes it. It takes each vintage's own
   `inventory.sexp`, the store's `symbol_types.sexp` (equity-like only) and the builder's activity filter, at
   May 31 of each year. It scores every candidate once per rule: v12 for 1998–2025, v13 for 1998–2026. The scores
   stay in the scratch `$WORK`. About 4 minutes per vintage.
2. `rank.sh` ranks each year's pool under each rule. On ties it keeps inventory order, like the builder's stable
   sort. Each list's own `twin-drops.txt` legs are left out of the cells under every rule. Then it counts. Host
   only, about 20 s.

**Reproduction** (`results/validation.tsv`, current rule against the committed lists):
- **pit-v13** reproduces. Over 58 lists, 185,381 cells match, 4 are in mine only, and 1,291 are committed only. The
  committed-only cells are alias survivors (ALPN, IQV, CLVT), which the twin aliasing put into the lists under a
  name the ranker never scores.
- **pit-v12** matches 103,590 cells. 1,605 are committed only and 7,702 are mine only (~7 %). The mine-only cells
  are mostly the legs v12 removed with the v11 alias maps (`alias2.resolved`, `alias3.txt`), which
  `twin-drops.txt` does not record. Some come from store refreshes since 10-07.

So the v12 pool is about 7 % wider than the real one at the list edge. The mixed-file effect is a property of the
file, so the v12 counts are the right size but not cell-exact.

## Results

Thresholds, fixed by the brief before any count was read:
- **contained:** under about 1 % of list cells change band per year;
- **material:** over about 3 %, or concentrated in some years.

The share is the number of cells that leave the list under the rule, divided by the list's cells (one leaves for
each one that enters).

| list | cells (all years) | leave, consistent | max year | leave, all-restated | max year | leave, all-raw | max year |
|---|---:|---:|---:|---:|---:|---:|---:|
| v12 top-1000 | 27,796 | 59 (0.21 %) | 0.50 % (1998) | 169 (0.61 %) | 1.01 % (2004, 2017) | 57 (0.21 %) | 0.50 % |
| v12 top-3000 | 83,496 | 135 (0.16 %) | 0.27 % | 150 (0.18 %) | 0.27 % | 112 (0.13 %) | 0.27 % |
| v13 top-3000 | 79,485 | 176 (0.22 %) | 0.41 % (2016) | 281 (0.35 %) | 0.72 % | 126 (0.16 %) | 0.32 % |
| v13 top-4000 | 105,900 | 184 (0.17 %) | 0.37 % (2014) | 242 (0.23 %) | 0.45 % | 146 (0.14 %) | 0.26 % |

Per year (`results/per-year.tsv`):
- **Mixed files** in the pool: v12 62–104 a year (120 files in all), v13 85–149 (179 files). That is 1.2–2.2 % of
  the pool. Of each top-3000 list, 26–53 cells (v12) and 24–45 cells (v13) are mixed files.
- **Pool scores that move by more than 2 %**: v12 12–50 a year, v13 10–71.
- **Crossings of the 1000 / 3000 / 4000 edges**: v12 0–10 / 2–16 / 0–12 a year, v13 0–10 / 2–23 / 4–27. A
  crossing is a cell that enters or leaves at that edge.
- The effect is largest before 2012 and falls to 1–3 cells a year after 2020, as the store's split histories
  shorten.

Movers:
- **Direct movers** (`top-movers.tsv`, `repeat-movers.tsv`): PPHM (10 v12 top-3000 years, out), VHI, VICL, AKER,
  MTW, APTO, DRL and CISS (out); NJDCY, BF-A, CDR, INVO, DDD, XTLB and AIKI (in).
- **Large caps on a knife edge.** MTW's 2016 4.416 "split" is the Manitowoc Foodservice spin-off. COO's 2024 4:1
  split has share 0.70, and its file vote is 0.48. Each moves by a factor of about 4 (v12 top-1000, 8–10 years).
- **The rest are displaced.** Of the 270 v12 top-3000 cells (1998–2025) that change, 178 belong to names whose
  score moved. The other 92 are names next to the 3000 edge (ranks 2993–3008) pushed across it.
- **One extra twin.** WFT (v13 only) is unranked under the current rule: its 2019 1:1441 split pushes every pre-2019
  bar over the $2e11 cap. Under the vote it ranks 119–467 in 2008–2017. It is a third leg of WFTIF/WFTLF, so its
  entry would be a twin, not a new name. Neither the current rule nor all-restated ranks it.

### v12 record lists (top-3000, 1999–2025)

The record rides on these lists. Per year, 2–16 cells change, so 1–8 names leave, which is 0.03–0.27 % of each
list (`results/record-list.tsv`). Every year has at least one change, and none comes near the 1 % line.
- **1999–2012** carry the most: 8–16 cells a year. The repeat leavers are PPHM (2000, 2005, 2007, 2010–2012), VHI,
  VICL, MTW, APTO and DRL 2007 (rank 750 → 3033). Each is a single-symbol event at the 3000 edge.
- **2013–2025:** 2–12 cells a year. The notable ones are AKER 2014–2019 (rank ~2300–2700 → ~4400), UCAR 2024
  (995 → 3138) and CISS 2025 (1576 → 4809).

CISS in v12 top-1000-2024 sits at rank 6 under the current rule. That is a 2,100× over-score of a micro-cap: four
reverse splits are applied and the fifth, 1:40, is dropped. Under the vote it ranks 2864. That cell is a real error
in a v12 list.

## Verdict: contained

Under the vote rule, at most 0.50 % of a list's cells change in any year, and the multi-year average is 0.16–0.22 %.
Even the all-restated bound peaks at 1.01 % in only two v12 top-1000 years, and stays under 0.8 % everywhere else.
There is no concentration: every year is under the 1 % line, and the per-year counts fall smoothly from about 2010
on. All four families are well under the 3 % "material" line. That includes the v12 top-3000 lists the record
rides on: 0.16 % overall, 0.27 % at most, and the largest years are 1999–2012.

What the verdict does not cover:
- It measures **membership**. Rank-reading consumers, like the CISS 2024 rank 6, see larger errors on those few
  names.
- The v12 pool is reconstructed about 7 % wide at the edge. See Reproduction above.

Fixing the rule (a per-file basis, or segment-wise tests) stays a builder change plus a list rebuild. On these counts
it is not urgent for the record, and it should ride on the next list build rather than force one.

## Files

- `scan.sh`: the scanner and its embedded OCaml. It needs `TREE` and `WORK`; see the header.
- `rank.sh`: ranks and counts. It needs `WORK` and `OUT`.
- `results/`, all symbols, ranks, counts, split dates and factors, with no prices or volumes:
  - `per-year.tsv`, `bounds.tsv`;
  - `top-movers.tsv` (with the current / consistent ADV ratio), `repeat-movers.tsv`, `record-list.tsv`;
  - `mixed-files.tsv`: every mixed file, with each close-confirmed split as date:factor:jump-share:applied and its
    vote;
  - `validation.tsv`.
