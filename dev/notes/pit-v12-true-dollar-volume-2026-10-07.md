# PIT v12: lists on the true dollar-volume basis (#3136 rebuild, prep stage, 2026-10-07)

User decision 2026-10-07: rebuild the PIT lists and the snapshot warehouse on the true dollar-volume basis
(split-only adjusted, `dollar_volume_basis.ml`, #3164) before shorts Phase B. This note covers the **prep stage**:
inventory, lists, the v11 to v12 membership diff, and the warehouse build script. **The warehouse was not built**
(`dev/scripts/build_pit_warehouse_v12.sh`, run it when the container is free). Nothing under `pit-v11/` or
`goldens-custom-universe/` changed.

## What is in the PR

| path | what |
|---|---|
| `trading/analysis/weinstein/data_source/lib/inventory.ml{,i}` + `test/test_inventory.ml` | `Inventory.build` now also indexes a `data.csv` that has no `data.metadata.sexp` (see finding 1) |
| `trading/test_data/backtest_scenarios/pit-v12/inventory.sexp` | candidate inventory regenerated from the store: 11,888 symbols (v11-era: 5,734, generated 2026-07-12) |
| `trading/test_data/backtest_scenarios/pit-v12/composition/top-{1000,3000}-{1998..2025}.sexp` | 56 lists, `--true-dollar-volume`, same D1/D2 dating (May-31 anchor, Mar-1..May-31 window) and vintages as v11, **twin-aliased with the v11 maps** (finding 3) |
| `pit-v12/composition-raw.md5`, `composition.md5` | md5 of the builder output and of the as-committed (aliased) lists |
| `pit-v12/warehouse-extras.txt` | 15 non-list symbols the v11 warehouse carried (SPDR sector ETFs, global indices) |
| `dev/scripts/pit_v12_compare.sh` | the per-vintage diff used below |
| `dev/scripts/build_pit_warehouse_v12.sh` | the warehouse build (not run) |

Reproduce the lists (container, ~80 min, one job): `build_composition_universes_runner.exe --bars-root
/workspaces/trading-1/data --symbol-types .../symbol_types.sexp --sectors-csv .../sectors.csv --inventory
pit-v12/inventory.sexp --out-dir <dir not named goldens-custom-universe/composition> --start-year 1998 --end-year 2025
--top-n 1000,3000 --true-dollar-volume`, then apply `step4/specs/alias2.resolved` and `step4/twin-scan/alias3.txt`
(in that order) with `step4/twin-scan/alias-lists.pl`. Output md5 equals `composition-raw.md5` before aliasing.
Inputs: `symbol_types.sexp` (generated 2026-05-18, 56,652 symbols; covers all but 4 inventory symbols: BF.B, BRK.B,
MNK, TRB) and `sectors.csv` (2026-07-24) from the store.

## Findings

1. **The inventory tool missed 6,154 of the 11,888 cached symbols.** `build_inventory.exe` read only
   `data.metadata.sexp`; the 2026-09-08 and 2026-09-14 gap fetches wrote bars without it. A rebuild with the old tool
   reproduced 5,734 (the old inventory's size), so the candidate set of any list build was frozen at the 07-12 store.
   Fixed (metadata wins when both exist; range read from the first/last `data.csv` rows otherwise) with a test.
   Against the 2026-07-12 inventory: **0 dropped, 6,154 added**; of the 5,734 kept, 3,161 have a later
   `data_end_date` (store refreshed to 2026-08-17) and 36 an earlier `data_start_date`. Of the added: 478 end on or
   after 2026-06-01 (live names), the rest are delisted (data ends 1999..2026; 143 to 569 per end-year); by start
   decade 3,245 start in the 1990s, 1,544 in the 2000s, 1,076 in the 2010s, 289 in the 2020s. They are the
   2,483 real union names fetched on 2026-09-14 plus the earlier gap fetches.
2. **The basis moves the right way on the specimens.** Rank within the list (1 = largest), adv in dollars:

   | specimen | v11 | v12 |
   |---|---|---|
   | AMZN 2018 | rank 2, 1.42e11 | rank 7, 7.10e9 (exactly the 20:1 factor) |
   | C 2010 | rank 169, 3.98e8 | rank 10, 3.98e9 (exactly the 1:10 reverse-split factor) |
   | AAPL 2010 | rank 4, 1.86e11 | rank 5, 6.65e9 (7:1 and 4:1 splits) |
   | COMP_old 2010 | rank 1, 1.70e12 (a junk bar) | absent (implausible bars rejected) |

   Entries with adv >= 1e11: 2010 v11 4 / v12 0; 2018 3 / 0; 2022 2 / 0.
3. **Twin dedupe is the v11 one, applied to the lists up front.** The builder ranks both legs of a rename (the store
   backfills the new ticker), and v11 removed the loser legs only after the warehouse twin scans, by aliasing them
   into the lists (360 in-chunk legs, 233 cross-chunk legs; `alias2.resolved`, `alias3.txt`). Those maps depend on
   the store's renames, not on the basis, so v12 applies the same two maps to the fresh lists with the same script
   (per-list dedupe, first occurrence kept): effective breadth per vintage 2,781..2,957 after aliasing, against
   v11's 2,792..2,993 (`composition-counts.txt`). Twin legs among the **new** candidates are not in those maps;
   the warehouse script's classify / twin-scan / twin-fix phases find them and print the `alias-lists.pl` command
   that applies the delta, to be committed as a second lists commit. The as-run v11 lists carried a few hand edits the
   maps do not regenerate (v11 README); v12 has none, so the comparison below includes that noise (1..5 lines per list).
4. **Still junk at the top, not caused by the basis.** The 2010 raw head is HSBA 2.9e10, SBER 1.8e10, SOBI,
   CTRA_old, VNA, RAL_old, CELSIA, ISF-CL, C-WS-A (a warrant), BAC-WS-A; 2018 is LDG, SBER, HSBA, CTRA_old,
   LHC-UN / LHC-WS, TNM, then AMZN. These are foreign-currency or unit-confused series and warrants whose
   *average* is large but whose single bars are under the $2e11 cap, so the per-bar rejection does not see them.
   v11 had the same class (HSBA, KBC). They are top-of-list ranks that displace little (each is one slot), but any
   consumer that reads rank, not membership, sees them. Candidate follow-up: a symbol-class filter (warrants `-WS`,
   `_old` synthetics, non-US exchanges) in `Build_from_individuals`, not done here.

## v11 to v12 membership (top-3000, 1999..2025, aliased vs aliased)

`out` = in v11 not in v12; `in` = in v12 not in v11. v11's 1999..2025 only (no 1998 in v11).

| year | n old | n new | kept | in (new only) | out (old only) | out share |
|---|---:|---:|---:|---:|---:|---:|
| 1999 | 2908 | 2897 | 2690 | 207 | 218 | 7.5% |
| 2000 | 2900 | 2898 | 2749 | 149 | 151 | 5.2% |
| 2001 | 2894 | 2887 | 2732 | 155 | 162 | 5.6% |
| 2002 | 2885 | 2880 | 2716 | 164 | 169 | 5.9% |
| 2003 | 2879 | 2877 | 2709 | 168 | 170 | 5.9% |
| 2004 | 2842 | 2833 | 2655 | 178 | 187 | 6.6% |
| 2005 | 2832 | 2823 | 2639 | 184 | 193 | 6.8% |
| 2006 | 2828 | 2818 | 2638 | 180 | 190 | 6.7% |
| 2007 | 2818 | 2810 | 2629 | 181 | 189 | 6.7% |
| 2008 | 2820 | 2809 | 2641 | 168 | 179 | 6.3% |
| 2009 | 2812 | 2802 | 2657 | 145 | 155 | 5.5% |
| 2010 | 2818 | 2809 | 2638 | 171 | 180 | 6.4% |
| 2011 | 2815 | 2804 | 2647 | 157 | 168 | 6.0% |
| 2012 | 2806 | 2798 | 2651 | 147 | 155 | 5.5% |
| 2013 | 2803 | 2790 | 2633 | 157 | 170 | 6.1% |
| 2014 | 2792 | 2781 | 2643 | 138 | 149 | 5.3% |
| 2015 | 2793 | 2782 | 2650 | 132 | 143 | 5.1% |
| 2016 | 2798 | 2784 | 2660 | 124 | 138 | 4.9% |
| 2017 | 2805 | 2796 | 2682 | 114 | 123 | 4.4% |
| 2018 | 2809 | 2802 | 2705 | 97 | 104 | 3.7% |
| 2019 | 2821 | 2813 | 2728 | 85 | 93 | 3.3% |
| 2020 | 2835 | 2832 | 2748 | 84 | 87 | 3.1% |
| 2021 | 2822 | 2811 | 2711 | 100 | 111 | 3.9% |
| 2022 | 2880 | 2876 | 2789 | 87 | 91 | 3.2% |
| 2023 | 2907 | 2903 | 2853 | 50 | 54 | 1.9% |
| 2024 | 2928 | 2925 | 2877 | 48 | 51 | 1.7% |
| 2025 | 2993 | 2957 | 2414 | 543 | 579 | 19.3% |

Spot checks (rank / avg_dollar_volume; rank is within the list, 1 = largest):
- AMZN 2018 (old): rank 2, adv 141997002448.3338
- AMZN 2018 (new): rank 7, adv 7099850122.4166927
- C 2010 (old): rank 169, adv 398441928.41463429
- C 2010 (new): rank 10, adv 3984419284.1463413
- COMP_old 2010 (old): rank 1, adv 1701890341350.8772
- COMP_old 2010 (new): absent
- AAPL 2010 (old): rank 4, adv 186186150183.94147
- AAPL 2010 (new): rank 5, adv 6649505363.7121944

**Headline.** 1.7 to 7.5 % of a vintage leaves (6 to 7 % in 1999..2008, falling to 1.7 %
in 2024), consistent with the measurement note's 2 to 4 % basis effect plus drift and candidate-set growth. **2025
is the outlier: 579 out / 543 in (19.3 %)**, the same vintage the measurement note flagged (its "C\L 570", mostly
candidate-set expansion: the 2025 list is anchored at 2025-05-31, so it is the one vintage most affected by the
store refresh and the 6,154 added candidates). It is not separately attributed to basis vs candidates here; the
raw (pre-alias) comparison against the original `goldens-custom-universe` lists is identical in shape (2025: 580 / 580).

## Raw v12 vs the original goldens lists (before aliasing; same size 3000, so in = out)

The original lists are legacy-basis on the 07-12 inventory, so this is the full "rebuild" effect including the alias-free breadth.

| year | n old | n new | kept | in (new only) | out (old only) | out share |
|---|---:|---:|---:|---:|---:|---:|
| 1999 | 3000 | 3000 | 2781 | 219 | 219 | 7.3% |
| 2000 | 3000 | 3000 | 2844 | 156 | 156 | 5.2% |
| 2001 | 3000 | 3000 | 2835 | 165 | 165 | 5.5% |
| 2002 | 3000 | 3000 | 2827 | 173 | 173 | 5.8% |
| 2003 | 3000 | 3000 | 2825 | 175 | 175 | 5.8% |
| 2004 | 3000 | 3000 | 2809 | 191 | 191 | 6.4% |
| 2005 | 3000 | 3000 | 2805 | 195 | 195 | 6.5% |
| 2006 | 3000 | 3000 | 2806 | 194 | 194 | 6.5% |
| 2007 | 3000 | 3000 | 2807 | 193 | 193 | 6.4% |
| 2008 | 3000 | 3000 | 2821 | 179 | 179 | 6.0% |
| 2009 | 3000 | 3000 | 2844 | 156 | 156 | 5.2% |
| 2010 | 3000 | 3000 | 2818 | 182 | 182 | 6.1% |
| 2011 | 3000 | 3000 | 2830 | 170 | 170 | 5.7% |
| 2012 | 3000 | 3000 | 2843 | 157 | 157 | 5.2% |
| 2013 | 3000 | 3000 | 2830 | 170 | 170 | 5.7% |
| 2014 | 3000 | 3000 | 2851 | 149 | 149 | 5.0% |
| 2015 | 3000 | 3000 | 2855 | 145 | 145 | 4.8% |
| 2016 | 3000 | 3000 | 2861 | 139 | 139 | 4.6% |
| 2017 | 3000 | 3000 | 2875 | 125 | 125 | 4.2% |
| 2018 | 3000 | 3000 | 2895 | 105 | 105 | 3.5% |
| 2019 | 3000 | 3000 | 2907 | 93 | 93 | 3.1% |
| 2020 | 3000 | 3000 | 2912 | 88 | 88 | 2.9% |
| 2021 | 3000 | 3000 | 2889 | 111 | 111 | 3.7% |
| 2022 | 3000 | 3000 | 2904 | 96 | 96 | 3.2% |
| 2023 | 3000 | 3000 | 2945 | 55 | 55 | 1.8% |
| 2024 | 3000 | 3000 | 2948 | 52 | 52 | 1.7% |
| 2025 | 3000 | 3000 | 2420 | 580 | 580 | 19.3% |

## Top-1000 (raw v12 vs original goldens top-1000, not aliased)

Larger churn than the top-3000 because the basis error is concentrated in the big names and the top-1000 is
rank-sensitive: 18.8 % of 1998 leaves, 14 to 16 % in 1999..2006, down to 0.8 % in 2024; 2025 8.2 %.

| year | n old | n new | kept | in (new only) | out (old only) | out share |
|---|---:|---:|---:|---:|---:|---:|
| 1998 | 1000 | 1000 | 812 | 188 | 188 | 18.8% |
| 1999 | 1000 | 1000 | 859 | 141 | 141 | 14.1% |
| 2000 | 1000 | 1000 | 886 | 114 | 114 | 11.4% |
| 2001 | 1000 | 1000 | 875 | 125 | 125 | 12.5% |
| 2002 | 1000 | 1000 | 872 | 128 | 128 | 12.8% |
| 2003 | 1000 | 1000 | 877 | 123 | 123 | 12.3% |
| 2004 | 1000 | 1000 | 847 | 153 | 153 | 15.3% |
| 2005 | 1000 | 1000 | 848 | 152 | 152 | 15.2% |
| 2006 | 1000 | 1000 | 841 | 159 | 159 | 15.9% |
| 2007 | 1000 | 1000 | 881 | 119 | 119 | 11.9% |
| 2008 | 1000 | 1000 | 892 | 108 | 108 | 10.8% |
| 2009 | 1000 | 1000 | 902 | 98 | 98 | 9.8% |
| 2010 | 1000 | 1000 | 891 | 109 | 109 | 10.9% |
| 2011 | 1000 | 1000 | 902 | 98 | 98 | 9.8% |
| 2012 | 1000 | 1000 | 917 | 83 | 83 | 8.3% |
| 2013 | 1000 | 1000 | 917 | 83 | 83 | 8.3% |
| 2014 | 1000 | 1000 | 921 | 79 | 79 | 7.9% |
| 2015 | 1000 | 1000 | 933 | 67 | 67 | 6.7% |
| 2016 | 1000 | 1000 | 929 | 71 | 71 | 7.1% |
| 2017 | 1000 | 1000 | 942 | 58 | 58 | 5.8% |
| 2018 | 1000 | 1000 | 949 | 51 | 51 | 5.1% |
| 2019 | 1000 | 1000 | 960 | 40 | 40 | 4.0% |
| 2020 | 1000 | 1000 | 964 | 36 | 36 | 3.6% |
| 2021 | 1000 | 1000 | 963 | 37 | 37 | 3.7% |
| 2022 | 1000 | 1000 | 976 | 24 | 24 | 2.4% |
| 2023 | 1000 | 1000 | 988 | 12 | 12 | 1.2% |
| 2024 | 1000 | 1000 | 992 | 8 | 8 | 0.8% |
| 2025 | 1000 | 1000 | 918 | 82 | 82 | 8.2% |

## Building the warehouse (`/tmp/snap_top3000_pit_v12pit`), not run

```sh
# 1. a pinned, built, CLEAN tree off this PR's merge commit (sweep-hygiene.md: never build from the parent tree)
git worktree add --detach .claude/worktrees/sweep-pit-v12 <merge-sha>
docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/.claude/worktrees/sweep-pit-v12/trading && eval $(opam env) \
  && dune build analysis/scripts/build_snapshots/build_snapshots.exe'          # detached + log, per the dune-wedge note
# 2. launch detached, container otherwise idle (no agents, no backtest)
RUN_TREE=/workspaces/trading-1/.claude/worktrees/sweep-pit-v12 nohup sh dev/scripts/build_pit_warehouse_v12.sh all \
  > /tmp/pit-v12-build.out 2>&1 &
```

Phases are individually runnable (`preflight superset chunks classify chunk5 twinscan twinfix verify`); the log is
`/tmp/pit-v12-work/build.log`. Guards for the known pitfalls:

| pitfall | guard |
|---|---|
| single-pass build of ~10k names OOM (exit 137 at 7.75 GB, v11) | four chunks (~2,320 names each), keyed on the symbol without `_old[N]` so a twin pair never straddles a boundary; any non-zero exit aborts and names exit=137 as OOM |
| chunked `-incremental` misses cross-chunk rename twins (233 legs in v11) | `twinscan` (six chunk-pair twin passes, killed once the report exists) + `twinfix` (direct edges only: overlap >= 200, match >= 0.95, survivor not a >4-leg hub, leg not a restored false leg) + one dedupe rebuild + collateral rebuild; prints the `alias-lists.pl` command that applies the delta to the lists |
| false transitive drops (86 in v11) | `classify` splits in-chunk drops at match 0.95 (reproduces v11: 360 legit / 86 false on v11's chunk reports; v11's hand-made false-legs file had 84 because IMPX_old and WCAP_old were removed by hand, and v12 deliberately restores them like the other 84); `chunk5` rebuilds the false legs as their own series; an alias cycle aborts |
| `-incremental` manifest clobber (#2669, fixed #2724) | after every build step every manifest entry must have a `.snap` and no `.snap` may be orphaned (in `$OUT`, not in the manifest), else abort. The one legitimate orphan source is the `twinfix` rebuild (chunk6): it drops cross-chunk legs from the manifest but leaves the `.snap` files the chunk builds wrote (v11: 9,364 manifest vs 9,597 `.snap`, 233 legs). Chunk6 is therefore checked with its own symbol set as the orphan allowance, and the dropped legs' `.snap` are deleted afterwards. A clobber orphans thousands of files, so it still aborts. `preflight` also requires #2724 in the run tree's history |
| handle cap (#2882) | `verify` aborts if the manifest exceeds `SNAPSHOT_MAX_MMAP_HANDLES` (default 12,000); every chain on this warehouse exports it |
| contention / disk | `preflight`: no other build/backtest process in the container, host free > 30 GB, refuses an existing `$OUT`, run tree clean |
| store edit | `preflight` asserts the SGP_old1 tail cut (no rows after 2009-11-03) is still in the store |

Size and time, from the v11 build: union 9,286 symbols (1999..2025 lists, aliased, plus the 15 extras, minus MEL and
the 3 quarantined; v11: 9,900 union, 9,364 manifest after dedupe, 3.5 GB). Chunks 28 to 41 min each (about 2 h),
pair scans 33 to 38 min each (about 3.6 h), fixes about 1 min: **about 6 h wall, budget 7**. The warehouse should come
out near 3.3 GB and roughly 9,000 entries. Container-exclusive (a chunk build sits at 5 to 6 GB; the pair scan at about 4.3 GB).

Resume: `twinfix` computes its plan (drop pairs, drop legs, `alias-v12-new.txt`) once, before the chunk6 build, and saves it
(`twinfix.plan`); a rerun reuses it instead of rescanning the post-chunk6 manifest, where the dropped legs are already gone.
A dry harness (`trading/devtools/checks/build_pit_warehouse_v12_guard_smoke.sh`, in `dune runtest`) pins the guard, the
resume and D6 against a fake build.

Verification (`verify`): manifest == `.snap` set (after the prune) and <= the handle cap; D6 (every list symbol is in the
manifest except the v12 expected-absent set: MEL, built from two interleaved issuers and excluded in the
`superset` phase (not in `warehouse_exceptions.sexp`), plus the legs of `alias-v12-new.txt` and the in-chunk alias map, which the lists lose when the
delta is applied. The v11 exemptions do not carry over: all 9,273 v12 list symbols have a CSV, including the 251 `_old`,
and none of the 109 fetch-miss or 3 quarantined names is in a v12 list, so an `_old` series missing from the warehouse is
a real drop; anything unexpected aborts `verify`); six sample symbols (AAPL, AMZN, C, JPM, GSPC.INDX, AAAGY) with `.snap` size vs manifest `byte_size` and
`active_through` vs the last CSV row; warehouse size. Afterwards: copy `terminal_runs.csv`, `splice_actions.csv` and the
rename-twin reports to an experiment dir, and require **V6 = 0** on the first null cell.

## Not done / decisions for the user

- No spec, golden, ledger entry or default points at `pit-v12` yet; step 4 of the migration (the a0 null on v12, 3 salts,
  new record band) and the re-pin of anything that moves are the next stage, after the warehouse exists.
- The v11 lists remain the record's input until then. v12 levels are not comparable to v11 levels (a different construction).
- Junk at the top of the ranking (finding 4) is unchanged; say if you want a class filter before the warehouse build,
  since it changes the lists and therefore the warehouse union.
- The top-1000 lists are aliased with the same maps like the 3000s; the warehouse uses only the top-3000 union.
