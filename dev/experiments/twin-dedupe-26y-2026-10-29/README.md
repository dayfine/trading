# twin-dedupe-26y-2026-10-29: the full rename-twin dedupe (#3388), applied and measured paired on the record

**Pre-registration.** Nothing has run. Everything below is fixed before the first cell launches.

Refs #3388. Applies the scan's full proposal (`../v12-twin-scan-2026-10-22/results/drops.txt`), of which #3391 applied
only the CMN/CMD rows, and pre-registers the paired 26y read that measures it as a universe change.

## Why

The v12 twin scan confirmed 107 pairs where one list holds the same instrument twice in the window it governs (a
rename with a backfilled successor file, a warrant file carrying the common's quotes, a vendor copy of a preferred
series). A backtest can buy such a pair twice on one day, which V6 catches only after the fact. #3391 fixed the one
twin that broke chain V's V6 gate. The rest were left because applying them moves every 26y number, so the change is
to be measured before it becomes the record's universe.

## What this PR changes

1. **`apply-full-dedupe.sh`** (POSIX sh + awk, host-only):
   - filters `drops.txt` (790 rows) against `exclude-pairs.txt` in both orders. Only the 6 BML-P-G/H/J/L rows drop out
     (that exclusion postdates `drops.txt`): 784 rows;
   - resolves survivor chains per list. While (list, S) is itself a dropped key, S becomes that key's survivor (its
     first row in file order), with a cycle guard; a re-pointed row carries `via=<original S>`. 67 rows are
     re-pointed. Without this, a row such as `top-1000-1998 BAC-WS-B BAC-WS-A` would leave the list with neither leg
     (BAC-WS-A leaves for BAC) and `pit_twin_cooccur_check.sh` fails it;
   - applies the rows not already in `pit-v12/twin-drops.txt` with `../v12-twin-scan-2026-10-22/apply-drops.sh`: 779
     rows, 713 entries in 54 lists (a symbol can lose to two survivors in one list and is removed once);
   - rewrites `pit-v12/twin-drops.txt` with all 784 rows. A second run applies nothing.

   `sh trading/devtools/checks/pit_twin_cooccur_check.sh` prints `OK: ... 784 per-list twin drops hold`.
2. **`pit-v12/composition.md5`** regenerated (`md5 -r *.sexp` in `composition/`). The 27 scheduled top-3000 lists'
   concatenated md5 goes from `51fba79e26a6273845c37c13f6aae070` to `369b988f703e2aa71d5248e5843d6ecb`, and their
   union from 9,222 to 9,185 symbols (dd is a subset of cur).

**The record moves to the deduped lists either way.** Holding one instrument twice is a defect, not a dial, so the read
below sizes the change; it does not decide whether to keep it.

## Design

- **Arms.** Per seed k, `td-cur-k<k>` (main's lists before this PR, CMN/CMD dropped only) and `td-dd-k<k>` (the
  deduped lists). Both are `../record-kseed-2026-10-27/specs/rk-k<k>.sexp` from line 5 on, with a new header, name and
  description. The cur specs name `pit-v12-current/composition/`, which the chain stages from `BASE` (`7615dde7d`, main
  before this PR) into the run tree, untracked. Nothing else differs.
- **Cells.** k = 0, 1, 2 (K = 3 pairs), 26y 2000-01-01 → 2026-06-26, top-3000 PIT v12 schedule (27 yearly lists,
  broad, U1 passes), path salt 0, Seeded tie order. Order: cur-k then dd-k, for k = 0..2, one cell at a time, after a
  half-year preflight of cur-k0 and dd-k0.
- **Build.** A pinned worktree at origin/main once this PR has merged (`.claude/worktrees/sweep-td`), one build for all
  six cells. `launch` checks: the dd specs equal rk-k<k> below the header; each cur spec equals its dd spec except the
  list directory; the cur lists' md5 is `51fba79e…` and the run tree's `369b988f…`; the unions are 9,222 and 9,185 and
  dd's is a subset of cur's.
- **Warehouse.** `/tmp/snap_top3000_pit_v12wk` (9,236 symbols), reused; checked against the set derived from the cur
  union, which holds dd's. MEL (no CSV) stays in both arms, so both read `n_symbols_absent=1`.
- **Cost.** record-kseed's cells took 12,336–23,162 s, so six cells are about 25–40 h. `CELL_TIMEOUT` 60,000 s =
  1.5 × the slowest same-shape cell on the ledger (vcv-M-s2, 39,142 s).

## Gates

1. **V6 on dd.** Every dd cell's validator reads `V6 INVARIANT PASS`. A dd cell that does not logs `GATE-FAIL`, and
   its seed's pair leaves the read. `validator_diff -check V6` dd vs cur is run and logged
   (`td-dd-k<k>-s0.v6diff-cur.log`). It is descriptive: cur is expected to hold twins dd removed, so a cur-side V6
   specimen is the defect being sized, not an exclusion.
2. **Cell health.** A cell with no `actual.sexp`, or with `n_symbols_absent` other than 1, has no RESULT; its pair
   leaves the read.
3. **Same build.** One run tree, one build, one warehouse for all six cells. Per seed, dd and cur `params.sexp` must be
   equal once `(universe_size N)` is masked (cur 9,222, dd 9,185). A difference elsewhere voids that pair (`summary` prints it).

Fewer than 2 included pairs: no read; an issue names the failing cells. The record still moves to the deduped lists.

## What is read (`sh chain.sh summary`)

1. **Per-seed paired effect.** d = ln(1 + R_dd) − ln(1 + R_cur), R = total_return_pct / 100; then mean d, sample SD
   and the sign count over the included pairs. Sharpe, max DD, Calmar and trades are reported per cell.
2. **Movement class**, |mean d| in units of the record band's SD (0.2254, record-kseed):
   - **≤ 1 band SD:** the dedupe moves the record by less than its own seed noise. The record band is re-measured on the
     deduped lists at the next re-baseline, not now.
   - **1–2 band SD:** a real level shift. The record band and every 26y lever read on the record config move to the
     deduped lists before the next verdict; the record memory and the ledger take the shift.
   - **> 2 band SD:** the twins carried a material share of the record. Before the record takes the new level, the
     pair whose trades move most is traced to the twin rows that caused it (`trade-dissection`), and the result goes
     to the user.
3. **dd against the band.** The dd median ln(1 + R) against the record band (median 2.7819, SD 0.2254) in SD units,
   with the same three classes. Descriptive: the band was measured on cur.
4. **cur reproduces rk-k<k>.** Each cur cell's `actual.sexp` is compared byte for byte with
   `../record-kseed-2026-10-27/results/rk-k<k>-s0-actual.sexp`. A difference means the run tree moved since
   record-kseed (another merge); the paired read stands, since both arms share the build, but the writeup names it.
5. **Review pack** (all six cells), built in the run tree, rendered and looked at per `backtest-result-review.md`;
   each signal bullet is confirmed, refined or rejected in the writeup.

## Out of scope

- **The monthly lists.** `dev/scripts/build_monthly_universe_warehouse.sh` `post` re-keys `pit-v12/twin-drops.txt`
  (a pair's dropped leg leaves every monthly list holding both legs, whatever the window). With 784 rows instead of 5,
  its `check_may31` would no longer reproduce the yearly lists byte for byte, so the next monthly build needs the
  re-key restated per window first. `pit-v12-monthly/` is not touched here.
- **The warehouse.** No rebuild: the lists only lose symbols, and a warehouse symbol in no list is never a candidate.

## How to run

```sh
PREREG=<this commit> sh dev/experiments/twin-dedupe-26y-2026-10-29/chain.sh launch   # host, after merge; detaches `run`
tail -f /tmp/td-run/chain.log
```

`run` copies results into `/tmp/td-run/results` and writes `summary.txt`; the pack goes to
`.sweep-output/review-twin-dedupe-build/`.
