# chain-w-2026-11-10: cloud verification chain for #3136, #3109 (with #3104) and #3183

**Status: run 2026-11-12, read 2026-11-13 (§Results).** The pre-registration below is unchanged: every read was
fixed before the first cell launched. The chain ran in a Claude cloud session (`docs/howtos/claude_cloud_sessions.md`).

It answers, or fails to answer, one `[after-merge]` item per issue:

| issue | `[after-merge]` item | what answers it here | backtest? |
|---|---|---|---|
| #3136 | PIT warehouse/universe rebuild decision recorded (reframed 10-19 as a paired v12 26y run, `true_dollar_volume` off vs on, V6-gated, listing the entries that flip) | the pair **W0 / Wtd** | yes, 2 cells of 26y (W0 shared) |
| #3109 (+ #3104) | paired golden run for the `raw_confirm_min_share` default flip (`config-default-blast-radius.md`), with #3104's flip | the pair **W0 / Wrc** plus the 5 `goldens-sp500` pairs | yes, 1 + 10 cells; **needs a prerequisite PR** (§Prerequisite) |
| #3183 | measured effect of the symbol-class filter on per-vintage membership vs pit-v12 | `apply_composition_policy` off vs on over the 56 pit-v12 lists | **no**: a composition-policy run, minutes |

## Design

### Base spec

- **W0 = the current record, `rk-k0`** (`../record-kseed-2026-10-27/specs/rk-k0.sexp`; record N with Seeded tie order
  seed 0; the record the 11-06 decision walkthrough #3546 reads). It is copied byte for byte below a new header; only
  `name` and `description` change. `chain.sh` checks this (`spec_checks`: comments, name, description and whitespace
  dropped, then equal).
  - Investor preset, 2000-01-01 → 2026-06-26, top-3000 pit-v12 schedule, total-return accounting (T-bill cash yield,
    10 bp fee, `dividend_crediting true`, `split_dividend_guard true`), `TRADING_PATH_SEED_SALT=0`.
- **One seed per arm.** The items are an implementation check (#3136), a blast-radius check (#3109) and a count
  (#3183); none is a performance verdict. The 26y single-cell noise floor is about 0.45 log at 2 SD (seed SD 0.225,
  `dev/agent-memory/project_26y_path_noise_floor.md`, record-kseed k0–k4 = 1,192.7–2,218.8 %). A level delta below that
  which is not traced to the lever's own decisions is read as path noise, never as an effect.

### Run tree

The cloud session's checkout at `origin/main`, built there (post-#3510 upper-case shards and post-#3547 relocatable
warehouse reads, so no shard rename and no `/tmp` mount). `chain.sh` refuses to run unless:

- HEAD equals `origin/main` (override `ALLOW_NON_MAIN=1`, logged), and the checkout is clean;
- HEAD contains #3510 `20824663d`, #3547 `8ee1ed797`, #3301 `e05b7e217` (`liquidity_config.true_dollar_volume`),
  #3297 `04273ff7e` (raw-confirm + frozen-adjusted rule) and #3280 `dc090140a` (symbol-class filter). A shallow
  clone is unshallowed first;
- this directory is in the checkout (the pre-registration is merged).

The binary, the image digest and HEAD are logged at the top of `chain.log`.

### Data (all from R2, `dev/scripts/r2_bars.sh`; credentials from the environment, never printed)

| R2 object | used for | where it goes |
|---|---|---|
| `warehouse/v12wk-9236` (`pull-dir`, every file hash-checked) | the bars every 26y cell reads (`--snapshot-dir`) | `.sweep-output/chain-w/warehouse/snap_top3000_pit_v12wk`; manifest must hold 9,236 entries |
| `warehouse/corpact-2026-10-27` | `dividends.csv` / `splits.csv`, exactly the record's set | unpacked into the data dir below |
| `bars/data-20261102` (`pull`, sha256-checked) | `data.csv` per symbol, which **two things read and the warehouse does not hold**: the #3136 true-dollar divisor (`True_dollar_divisor.of_data_dir` reads `<data_dir>/<L1>/<L2>/<SYM>/{data,splits}.csv`; a symbol with no `data.csv` reads divisor 1.0, so without it Wtd would silently equal W0) and the post-run validator's `-data-dir`; also `symbol_types.sexp` for #3183 | the data dir below |

**The data dir `td-full`** (`TRADING_DATA_DIR` of every 26y cell and the validator's `-data-dir`) is built once:

1. the bar store from `bars/data-20261102` (abort on a lower-case shard level: a pre-#3510 layout would hide files);
2. the checkout's committed `trading/test_data` copied over it (committed files win), so every file the record's own
   data dir held (macro T-bill series, NYSE A-D breadth, `share_classes.sexp`, `sectors.csv`, the 650 committed bar
   files) is the same file;
3. `corpact-2026-10-27` unpacked over it, then every `dividends.csv` / `splits.csv` **not** in its `files.txt` deleted
   (the 11-02 bar archive carries a newer set). The deleted list is kept (`td-ca-extra.txt`).

Guards: 11,880 `dividends.csv` (the record's staged count); `AMZN` and `C` (the #3136 specimens) have both `data.csv`
and `splits.csv`; `symbol_types.sexp`, `share_classes.sexp`, the T-bill and A-D files exist.

The difference from the record's own data dir is the extra `data.csv` files of the other ~11,200 symbols, which the
off-arm should not read. **Parity read (P0):** W0's `actual.sexp`, `trades.csv` and `equity_curve.csv` are compared
byte for byte with the committed `rk-k0-s0-*` files. Identical = W0 is the record and every pair links to it. Not
identical = something reads `data.csv` from `TRADING_DATA_DIR` on the off-arm too; every within-chain pair still
shares one data dir and stays valid, but W0 is then reported as "the record on `td-full`", not the record, and the
first differing date is traced before any other read is written.

The 5 `goldens-sp500` cells run exactly as their CI workflow does: `TRADING_DATA_DIR` = the checkout's pristine
`trading/test_data`, CSV bars, no warehouse.

### Prerequisite for the #3109 cells (not on main today)

`raw_confirm_min_share` is **not a strategy-config field**. It is an optional argument of `Split_detector.detect_split`,
`Split_handler.detect_and_apply` and `Stops_split_runner.adjust` / `detect_split`, and no caller passes it
(`simulator.ml` passes only `split_guard`; `weinstein_strategy.ml` `_split_adjust` and `split_ticket_cancel.ml` pass
nothing). So no spec can arm it, no golden arms it, and a default flip cannot be expressed. Checked: the spec
`cw-Wrc.sexp` and all 5 `cw-g-*-rc.sexp` fail `Overlay_validator.apply_overrides` on main with exactly one unresolved
key, `split_raw_confirm_min_share`, and pass with that one line removed.

**Prerequisite PR (default-off, its own three gates):** a config field
`split_raw_confirm_min_share : float option [@sexp.default None]` on `Weinstein_strategy.config`, routed to all three
runtime callers: the simulator's held-position split step (via the backtest's deps, the way `split_dividend_guard`
reaches `split_guard`), `Stops_split_runner.adjust`, and `split_ticket_cancel.ml`'s `detect_split` call (the #3109
10-13 QC note: wire every caller at once). `None` = today's path, bit-identical. It also carries the two QC test notes
(a frozen-day 5:4 test pinning the strict `|f−1| < 0.25` boundary; the asymmetric 4:5 floor documented). The warehouse
builder's `splice_detector.ml` call stays unwired: it shapes the warehouse, not a run, and is out of scope.

The flip value is **0.5** (the value #3105 tested: FUJIY rejected, real 3:2 / 2:1 / 1:10 kept), with
`frozen_adjusted_min_deviation` at its default 0.25, which `raw_confirm_min_share` switches on. This one knob is both
"#3104's flip" (raw-gap confirmation, #3105) and #3109's (frozen-adjusted rejection, #3297). `dividend_threshold` stays
0.05: the dividend-shaped misfires it would catch (DHLGY, WING, EC) are removed on the record by the default-on
`split_dividend_guard` (#3173/#3222), and TDG 2013 is the one neither removes (#3109 10-13 comment).

`chain.sh` detects the field (`grep` of `weinstein_strategy_config.mli` at HEAD). Absent: the Wrc and golden cells are
skipped with `PREREQ_MISSING` in the log, and the rest of the chain runs. The #3109 item then stays open. If the
prerequisite PR names the field differently, the six `*-rc.sexp` specs and `RC_FIELD` are updated in that PR (a
one-line change each); the spec checks still require each to be its base plus that one line.

### Arms

| arm | spec | differs from its base by | base | salt |
|---|---|---|---|---|
| **W0** | `specs/cw-W0.sexp` | (rk-k0, header only) | committed rk-k0 s0 | 0 |
| **Wtd** | `specs/cw-Wtd.sexp` | `((liquidity_config ((true_dollar_volume true))))` | W0 | 0 |
| **Wrc** | `specs/cw-Wrc.sexp` | `((split_raw_confirm_min_share (0.5)))` | W0 | 0 |
| **g-<golden>** | `trading/test_data/backtest_scenarios/goldens-sp500/<golden>.sexp`, as committed at HEAD | (the golden) | — | 0 |
| **g-<golden>-rc** | `specs/cw-g-<golden>-rc.sexp` | `((split_raw_confirm_min_share (0.5)))` (its `perf-tier` comment lines dropped so no tier discovers it) | g-<golden> | 0 |

Goldens: `sp500-2019-2023`, `sp500-2019-2023-long-only`, `sp500-2019-2023-armed-stoplimit`,
`sp500-2019-2023-bah-spy`, `sp500-2019-2023-bah-brk-b`. They are on the sp500 universe as **regression pins**
(`universe-discipline.md` U2: "did this flip change behaviour?"), never as a performance measurement.

### Order, cost, guards

Order: stage → build → spec checks → three 3-month preflights → #3183 policy runs → **W0** → **Wtd** → **Wrc** → the 5
golden pairs (base, then flip) → first-divergence reads → collect. W0 runs first so a mid-chain death still leaves the
base; Wtd before Wrc because #3136 has no prerequisite.

| step | estimate |
|---|---|
| R2 pulls + data dir (3.6 GB warehouse with per-file verify, 613 MB bar archive, overlay) | 0.3–0.5 h |
| build at HEAD | 0.2 h |
| 3 preflights (2026-04-01 → 06-26) | 0.2–0.4 h |
| #3183: 56 lists × 2 policy runs | < 0.2 h |
| 3 × 26y cells, ~1.9 h each in the cloud (rk-k0 measured 6,527–6,870 s; next-session-priorities-2026-11-10, PR #3569) + validator | 5.7–6.0 h |
| 10 golden cells (local 162–958 s each, `perf-long-cells.csv`) | 0.5–1.5 h |
| **total** | **about 7–9 h, central 8 h; about 5 h if the prerequisite is missing (W0 + Wtd only)** |

A session restart is survivable: `sh chain.sh run` again skips every staged step (`.done` markers, verified) and
every cell whose `RESULT` line is in `chain.log`.

- `CELL_TIMEOUT` 21,600 s: 3× the slowest cloud cell of this spec (6,870 s → 20,610 s). `GOLDEN_TIMEOUT` 3,600 s:
  3.8× the slowest local golden cell (958 s).
- Disk ≥ 5 GB free before every cell (the cloud allowance is ~20 GB; the chain holds ~6.5 GB of data).
- A `mkdir` lock; one cell at a time; no agents, no other run in the session.
- Every cell logs `RESULT <tag> => <metrics> <V6/V3/V16/V17 lines> v6diff:… peak_rss_kb=… exit=… <snapshot cache line>
  (wall Ns)` for `perf_long_cells.sh update`. Peak RSS is GNU time inside the image.
- Everything lands under `.sweep-output/chain-w/` (gitignored, in the mount); never `/tmp`.

## Validity gate (every pair)

`validator_diff -check V6` per pair (`mechanism-validation-rigor.md` check 8), written as `<tag>.v6diff-<label>.log`:

- W0 vs the committed `rk-k0-s0-validator.sexp.sexp` (label R);
- Wtd vs W0, Wrc vs W0 (label W0);
- each golden flip vs its golden base (label base).

Exit 0 = the arms hold the same instrument set and a delta can be read as the lever's. Exit 1 = the pair is not read
as a mechanism delta; the differing specimens are traced first. Exit 2 = the comparison did not run; the pair is
unread. V3 (liquidity) is expected to differ in the #3136 pair and is not gated: the validator still scores stored
`close × volume` (#3136 O1), so a true-dollar entry can read as a V3 violation. It is reported, not read.

## Pre-registered reads

### #3136: W0 vs Wtd

- **T1 validity:** V6 diff exit 0.
- **T2 liveness:** `trades.csv` differs. If identical, the read says "no realised entry or exit changed on this path";
  the stage guard has already shown that the divisor's input files exist, and #3301's AMZN-2018 / C-2010 tests pin
  the plumbing, so an identical pair is reported as a finding (the record path is insensitive), not as a failure.
- **T3 attribution (the implementation check):** `firstdiff.txt` joins the two `trades.csv` on `symbol|entry_date`
  (the file is sorted by symbol, not date, so a positional diff would not give the first divergence), orders the
  base-only, arm-only and changed rows by entry date with no truncation, and adds the `equity_curve.csv` first
  differing date. Rows are compared with `position_id` (column 20) blanked. A row that differs only in its id has kind
  `id-shift`: ids come from a process-global counter bumped at decision time, so one gate flip shifts the id of every
  later-decided trade; an `id-shift` row marks that an earlier decision changed and is never a divergence.
  **T3 is read in decision order, not fill order.** `position_id` increases with decision time, and ids before the
  first changed decision are identical in both runs, so they are a common decision clock. Take every `arm-only`,
  `base-only` and `changed-*` row (not `id-shift`) with its id (the arm's for `arm-only`/`changed-arm`, the base's for
  `base-only`/`changed-base`). Let **F** be the smallest id among those rows that sit on a symbol whose divisor is not 1
  at that row's entry date, i.e. its `splits.csv` in `td-full` lists a split after that date that the raw close
  confirms. T3 passes if F exists and **no differing row has an id below F**. Every differing row with an id at or
  above F on a divisor-1 symbol is knock-on (a freed or consumed slot, cash, or a ticket that rests or never fills)
  and is listed as displacement, not counted as a T3 failure, whatever its fill date. A differing row with an id below
  F is **traced before T3 is scored FAIL** (below); only an untraced one fails T3: something other than the gate moved
  first. Every differing entry is listed with its symbol, date, id, side and divisor. Three side classes: blocked →
  admitted (the 10-19 measurement's dominant 1.9 % class), admitted → blocked (the 0.6 % class), and **hold exit
  changed** (the liquidity exit reads the same divisor, `liquidity_exit_runner.ml:52-53`; `min_hold_dollar_adv` is
  500,000 in W0).
  - **Known limitation: F sees only decisions that leave a `trades.csv` row.** A first changed decision that leaves
    no row is invisible to F: a placed ticket that never fills, or a fill the portfolio refuses at fill time for cash
    (`portfolio rejected fill … Insufficient cash`). Its same-tick knock-on (a lower-ranked rival skipped as
    `Insufficient_cash` in one run and placed in the other, or a later fill refused in one run only) then lands
    below F. Measured on rk-k0 (QC review of this PR, iteration 2): 99 of 665 placed tickets never filled, 20–28 of
    those had a lower-ranked `Insufficient_cash` rival in the same tick, and `rk-k0-s0.log` has 43 fill refusals.
    About 3–4 % of correct runs would read as a false FAIL on rows alone. The same gap covers a split inside the
    20-day ADV window that falls before the row's entry (fill) date, which reads divisor 1 at that date; this is rare.
  - **Trace before FAIL.** `chain.sh` extracts each W cell's entry decisions from its `trade_audit.sexp` while it is
    still in the output dir (`<tag>-entries.tsv`: `position_id`, symbol, decision `entry_date`, placed or skipped,
    side, skip reason; collected, unlike the audit). Before T3 is scored FAIL, each differing row below F is traced
    through the two runs' extracts and cell logs (`portfolio rejected fill`). If the row is a same-tick or fill-time
    knock-on of a divisor ≠ 1 decision (a placed decision on a divisor ≠ 1 symbol that is in one extract only, filled
    or not, and whose cash skipped or refused the row's entry in one run), that decision is recorded as the first
    changed decision, F moves to its id, and T3 is read from there. Otherwise no decision is recorded and T3 fails.
    This mirrors the identical-pair branch below.
- **T4 level (reported, no verdict):** total return, end-NAV log ratio, MaxDD, trades, Sharpe, Calmar. A level delta
  below 0.45 log that T3 does not trace to gate decisions is path noise.
- **The decision this pair can record** (the `[after-merge]` item): the pit-v12 lists already rank on true dollars
  (#3164, lists #3182, rebuild decided 10-07, record rebaselined 10-08); the remaining stored-basis reading is the
  liquidity gate, computed at read time from bars. If T1 and T3 pass, Wtd ran on the unchanged `v12wk-9236`
  warehouse and its divergence is wholly the gate's, so **no list or warehouse rebuild is needed for the gate basis**;
  that is recorded on #3136 and the issue's last item is met. If T1 or T3 fails, no decision is recorded and the
  failing specimen becomes the next step. **If the pair is identical or `id-shift` only** (T3 has no F), **no
  decision is recorded**: the run has no liveness counter for the divisor, so an insensitive path cannot be told from
  an inert knob. The next step is to trace first: take a W0 candidate-week from the 10-19 flip list, check its divisor and gate
  outcome by hand, and record the decision only if that shows the gate was live.
- **What it cannot decide:**
  - whether to flip the `true_dollar_volume` default. That is a separate config-default PR with its own paired goldens
    (`config-default-blast-radius.md`; the knob's docstring says so) and, as a look-ahead correction, the
    correctness-flip precedent (#1926, `dividend_crediting`) rather than a performance ACCEPT;
  - whether true dollars help or hurt returns (one seed, 0.45-log floor);
  - the V3 validator basis (O1, a separate follow-up);
  - O2 (a single inflated bar passing a `Mean` gate after division) in general. The T3 list gives each flipped entry's
    symbol and date, so O2 can be checked by hand on exactly those names.

### #3109 / #3104: W0 vs Wrc, and the golden pairs

- **Golden inventory (`config-default-blast-radius.md` step 1).** `grep -rl 'raw_confirm' trading/test_data
  .github/workflows` finds nothing: **zero goldens arm the knob** (it is not a config field yet), so the flip is the
  `AFFECTS-ALL` shape: all 31 goldens inherit it (`goldens-sp500` 5, `goldens-sp500-historical` 8, `goldens-broad` 7,
  `goldens-small` 3, `goldens-custom-universe-scenarios` 3, `goldens-hybrid-tier-experiment` 2, `panel_goldens` 3).
  No `.mli` docstring cites a knob that gates it.
- **Which goldens this chain runs, and why these.** The flip only ever *removes* a detected split (a stricter
  detector), so a golden changes only if its path applies, or cancels a resting ticket on, a split the flip rejects.
  The chain runs the record (the broad 26y cell every verdict reads) and the 5 `goldens-sp500` cells (the set
  `golden-runs-sp500-5y.yml` runs on every push to main, so the first to move after a flip). The other 26 are not
  run here; see the decision rule.
- **Prediction for Wrc (fixed now, from `rk-k0-s0-splits.csv`).** The record applies 14 held-position splits. With
  `|f − 1| ≥ 0.25` and a confirming raw gap, 11 are expected to be kept (TRMB, ADSK, AVD, ENB, EME, GD, DECK, HCSG, FLO,
  GPN, NEOG at 3:2, 2:1, 3:1, 4:3). MMSI 2011-05-06 (5:4) sits exactly on the 0.25 boundary and is kept by the strict
  `<`. The two the flip can drop are **IHG 2012-10-09 (14/15)** and **OKE 2014-02-03 (8/7)**: each is dropped only if
  its raw close does not carry at least half the factor's log-size, or its adjusted close did not move that day.
  Predicted: Wrc's `splits.csv` equals W0's minus at most IHG and OKE, and the trades are identical up to the first
  dropped event. Any other difference (a resting-ticket cancel, a non-held call through the stops runner) is traced.
- **R1 validity:** V6 diff exit 0 on every pair.
- **R2 event read:** `splits.csv` diff per pair (`firstdiff.txt`). Each dropped event is checked against the bar store:
  raw ratio, adjusted ratio, frozen or not, and whether a real corporate action happened that day (as recalled, to be confirmed against the bar store: IHG's October 2012
  14-for-15 share consolidation with a special dividend is a real share change; OKE's February 2014 ONE Gas spin-off is
  not a split). Dropping a real share change is a **defect of the flip**, not a pass.
- **R3 golden table (the flip PR pastes it, `config-default-blast-radius.md` step 3):** for each of the 6 pairs,
  return, trades, MaxDD at `None` and at `0.5`, plus `trades.csv` / `splits.csv` identical or not.
- **Decision rule:**
  - **All 6 pairs identical**, or every difference traces to a dropped event that is not a real share change → the
    evidence supports the default flip on the record and the postsubmit set. The flip PR still trips
    `goldens-affected` as `AFFECTS-ALL`: it cites this chain plus the mechanism argument for the other 26 goldens, and
    the maintainer decides whether that justifies the `paired-run-done` label or asks for their runs first.
  - **A real share change is dropped** (for example IHG) → the flip as specified is not supported; the rule needs a
    carve-out first, and the 26 remaining goldens are not worth running yet.
  - **V6 fails** on a pair → that pair is not read; trace the specimen.
- **What it cannot decide:** whether the flip helps performance, and the 26 unrun goldens' own deltas.

### #3183: symbol-class membership (no backtest)

**Why no backtest:** the item asks for the change in per-vintage membership, a property of the lists. A backtest
would answer a different question (does adopting the filter move the record), which needs its own null comparison
when someone proposes rebuilding the lists with the filter (the issue's 10-07 decision). Needs no warehouse: only the
committed pit-v12 lists and `symbol_types.sexp` (from `bars/data-20261102`).

**Method:** the filter shipped in #3280 lives in `apply_composition_policy` (not in the list builder). For each of the
56 committed lists (`top-{1000,3000}-{1998..2025}`), run it twice: **off** (no class flags; the default invocation,
which also collapses dual-class duplicates) and **on** (`--exclude-warrants --exclude-units --exclude-non-usd`).

**Reads** (`results/3183/membership.csv`, `dropped.csv`, per-list drop reports):

- **M1** per vintage: committed n, off n, on n, and dropped by the filter = off − on, split into warrant / unit /
  non-USD. on − off isolates the filter; off vs committed is the dual-class collapse alone, reported as a control.
- **M2** the dropped names with rank and average dollar volume, and specifically whether the issue's specimens drop
  where they appear (HSBA, CELSIA, SBER, CTRA_old, AIG-WS, C-WS-A, LHC-UN; LDG is per-caller since #3280, so not
  expected).
- **M3** which dropped names rk-k0 actually traded (join with `rk-k0-s0-trades.csv`; CELSIA traded once per #3183),
  as a bound on how far adopting the filter could move the record without running it.
- **M4** the spelling gap QC noted on #3280: members still in the on-lists spelled `-WT`, `-U`, `-R`, `-RI`, `-RT`
  (in the committed lists today, e.g. OIBR-R and GIX-U). Reported, not fixed.

**Estimand gap, stated:** the policy filter drops members without refilling. A builder-level filter would admit the
next-ranked names in their place, so M1's drop count is also the number of names a rebuilt list would admit.

With M1–M4 recorded, #3183's item is met.

## What the chain does not claim

No ACCEPT or REJECT on any mechanism, no default flip, no performance figure as evidence. Each 26y figure is one seed
on a broad universe; the sp500 cells are regression pins.

## After the chain

1. `sh chain.sh collect <repo>/dev/experiments/chain-w-2026-11-10/results` (the chain also collects into
   `.sweep-output/chain-w/results`). `trade_audit.sexp` is left out (large); T3's trace reads
   the `<tag>-entries.tsv` extract instead.
2. Review pack for the 26y cells (`backtest-result-review.md`): `dev/scripts/review_pack.sh --no-container` on W0 /
   Wtd / Wrc, rendered and looked at before the writeup; the look is recorded.
3. `sh dev/scripts/perf_long_cells.sh update <chain.log>`.
4. The results PR carries `Verifies #3136: …`, `Verifies #3183: …` and, if the prerequisite ran and the maintainer
   accepts the 6-pair subset (acceptance recorded in the PR), `Verifies #3109: …` lines, each naming its artifact
   (`issue-hygiene.md` B). Without that acceptance the PR carries
   `Refs #3109 -- remaining: paired runs of the 26 unrun goldens` instead. With the prerequisite not run it carries
   `Refs #3109 -- remaining: the W0 / Wrc pair, the 5 goldens-sp500 pairs and paired runs of the 26 unrun goldens`.
   In both cases the flip stays `AFFECTS-ALL`.

## Launching (cloud session brief)

```
Repo checkout at origin/main. Do not edit tracked files. Run:
  sh dev/experiments/chain-w-2026-11-10/chain.sh run
in the background with its output going to .sweep-output/chain-w/run.out, and re-run the same command after any
restart (it resumes). Never print R2 or EODHD credentials. When CHAIN W DONE appears in
.sweep-output/chain-w/chain.log, copy .sweep-output/chain-w/results into dev/experiments/chain-w-2026-11-10/results
on branch experiment/chain-w-results and open a PR; do not merge, label or push to main.
```

## Results (cloud run 2026-11-12, read 2026-11-13)

Read against the pre-registration at `ca5e8e8b6` (#3571). README and `chain.sh` had not changed before the run; the
results commit `e58de13b2` (#3584) adds only `results/`, and #3601 later moved the warehouse `.done` marker without
touching a read. Every number below comes from the committed file named beside it.
`sh dev/experiments/chain-w-2026-11-10/read/read.sh <bar store> [<corpact dir>]` regenerates every `read/*.txt`. It
needs a bar store for the divisor; the reading used the gitignored `data/` and the local `corpact-2026-10-27`, with
every differing symbol's `splits.csv` identical to td-full's. The `read/*.txt` outputs carry derived divisors and gate
flags only, never a bar.

**What ran** (`results/chain.log`):
- HEAD `b54e44ea9`, image `sha256:3865e48e8a61`.
- Stage OK: warehouse 9,236 entries; td-full 11,880 `dividends.csv` and 11,888 `data.csv`; 0 corporate-action files
  removed (`td-ca-extra.txt` is empty).
- Spec checks and both preflights OK; #3183 policy runs on 56 lists.
- W0: 6,875 s, peak RSS 5.78 GB. Wtd: 6,952 s, 5.75 GB.
- `PREREQ_MISSING` (`split_raw_confirm_min_share` is not a config field at HEAD), so the Wrc cell and the 10 golden
  cells did not run.

### §Log: P0 parity

**W0 is not byte-identical to the record.**
- `actual.sexp`, `trades.csv` and `equity_curve.csv` all differ from `rk-k0-s0-*` (`chain.log` PARITY lines). The
  equity curves first differ on 2004-07-22 (`read/levels.txt`).
- This was traced on #3584 before any other read (comments 6857919745 and 6857960966). The first changed decision is
  W0 placing PRMB on 2004-05-28 (`PRMB-wein-175`, filled 2004-07-22), which the record never placed.

**The cause is two main changes after the record's tree `fc78391dd`, not td-full.**
- #3475's full rename-twin dedupe cut the universe from 9,222 to 9,185 symbols (the cells' sector-map line).
- #3483 changed the same-day fill order. On 2006-05-30 DWSN1 and BRC both fill with cash for one: the record's order
  filled BRC, while W0 fills DWSN1 and refuses BRC (`cw-W0-s0.log`).
- #3483's own paired 26y seed-0 cell read +1,472.62 %, against W0's +1,472.76 %. The remaining ≈0.0001 log is
  untraced: a later commit, or td-full.

**The pair stays valid.** The V6 diff of W0 against the record exits 0 (`cw-W0-s0.v6diff-R.log`). W0 is "the record
path on the current lists and td-full", not the record. The W0 / Wtd pair shares one SHA and one data dir, so it stays
valid.

### 1. The reads, as written

#### #3136: W0 vs Wtd

**T1 validity: PASS.**
- `validator_diff -check V6`, Wtd vs W0: exit=0 (`results/cw-Wtd-s0.v6diff-W0.log`).
- V3 is reported but not gated: it passes in both arms (`cw-{W0,Wtd}-s0.validator.log`).

**T2 liveness: live.**
- `trades.csv` differs: W0 has 576 rows, Wtd 575 (`read/levels.txt`).
- `firstdiff.txt` holds 16 arm-only rows, 17 base-only, 549 changed pairs and 10 id-shift rows.
- The equity curves first differ on 2000-04-14, CVM's fill date.

**T3 attribution: PASS. F = 87 (CVM), and no differing row has an id below F** (`read/t3.txt`).

- **How the divisor was computed.** F is taken at each row's entry date as td-full fed `True_dollar_divisor`:
  - the committed `trading/test_data/.../data.csv` where the checkout has one (107 of the 518 differing symbols),
    otherwise the bar store's;
  - `corpact-2026-10-27` `splits.csv`.

  `read/divisor.awk` re-implements `Dollar_volume_basis.applied_splits` (close confirmation, then the volume check for
  |log f| ≥ log 3) and `split_divisor`. It reproduces #3301's specimens: AMZN 2018-06-14 gives 20, C 2010-06-14 gives
  0.1.
- **F = 87.** CVM is arm-only, decided 2000-02-04 (`CVM-wein-87`) and filled 2000-04-14, with F = 1/7,500.
  - The README's wording (close-confirmed splits, no volume check) gives the same F.
  - The smallest differing id on the base side is 96 (PENN), so nothing sits below F and there is no trace-before-FAIL
    to do.
- **Every differing entry is listed.** All 33 one-arm rows and 549 changed pairs are in `read/t3.txt`, each with
  symbol, entry date, decision date, id(s), three divisors, the $1M gate flags at the decision date (stored / true /
  one-bar) and a class:

  | class | rows | on F ≠ 1 |
  |---|---:|---:|
  | blocked → admitted | 6 | 6 |
  | admitted → blocked | 1 | 1 |
  | hold exit changed | 1 | 1 |
  | displacement | 574 | 122 |

  The 574 displacement rows break down as follows:
  - 26 are one-arm rows whose gate passes on both bases at the decision date. Seven of these sit on F ≠ 1 symbols:
    LECO, ADP, ETN, ROL, EXC, LRCX, MFA.
  - 548 are changed pairs: 547 differ only in quantity (and the P&L and dividends that follow from it), and NXY's
    decision moved one week.
- **Decision level (the README's known limitation).** Comparing the two entries extracts, 40 placed decisions are in
  one extract only.
  - Seven of them are the gate flips below.
  - The other 33 pass the gate on both bases; three of those never filled (UNIZ, WST, TFSM).
  - Four fill refusals differ between the arms (`cw-*-s0.log`): W0 refused BRC 2006-05-30, CLC 2007-07-24 and TVTY
    2007-09-19; Wtd refused ALSK 2006-03-21.
  - So no post-warmup gate decision is missing from the rows (see D2 for the warmup).

**The gate's own decisions, in decision order.** Sources: `read/t3.txt` and `read/impact.txt`; trade rows from
`results/cw-*-s0-trades.csv`. Impact is the trade's P&L as a % of that arm's NAV at entry, signed Wtd − W0.

| decision | symbol | id | class | F | gate stored / true | trade | P&L (impact) |
|---|---|---|---|---|---|---|---|
| 2000-02-04 | CVM | 87 Wtd | blocked → admitted | 1/7,500 | fail / pass | 2000-04-14 → 04-17, stop, −12.78 % | −$12,533 (−1.30 %) |
| Fri 2000-08-18 | PENN (held; entry ids 96 W0 / 98 Wtd) | — | hold exit changed | 4 | $500k floor: pass / fail, first Friday | Wtd liquidity_exit 2000-08-21 @14.62 (+37.65 %); W0 laggard rotation 2000-09-05 @13.81 (+29.99 %) | +$10,185 (+1.13 %) |
| 2005-03-11 | AVD | 200 W0 | admitted → blocked | 2.667 | pass / fail | W0 2005-03-21 → 04-22, stop, −10.48 % | W0 −$19,256 (+0.96 %) |
| 2006-01-20 | SVRA | 230 Wtd | blocked → admitted | 1/1,750 | fail / pass | 2006-01-24 → 05-02, +2.56 % | +$7,848 (+0.36 %) |
| 2006-05-19 | HAFC | 247 Wtd | blocked → admitted | 1/8 | fail / pass | 2006-10-25 → 2007-02-05, −1.15 % | −$1,482 (−0.06 %) |
| 2007-03-23 | VHI | 288 Wtd | blocked → admitted | 1/12 | fail / pass | 2007-03-26 → 05-17, +7.45 % | +$17,179 (+0.61 %) |
| 2021-02-12 | VHC | 1077 Wtd | blocked → admitted | 1/20 | fail / pass | 2021-02-16 → 03-03, −14.04 % | −$165,621 (−1.19 %) |
| 2023-04-14 | MAXN | 1178 Wtd | blocked → admitted | 1/100 | fail / pass | 2023-04-17 → 04-27, −4.28 % | −$66,584 (−0.53 %) |

O2 hand check: none of the six blocked → admitted passes rests on one bar. For all six, the true mean without the
largest bar still clears $1M.

**Displacement decisions** (the gate passes on both bases; F = 1 unless shown; P&L includes dividends):
- 2006:
  - MTB: W0 2006-02-24 (237), Wtd a week later on 03-03 (238).
  - UNIZ: W0 only on 02-24, never filled.
  - ALSK: placed by both on 03-10 (239). Wtd's fill was refused, so this is a W0-only row (+$36,904).
  - ADP: W0 on 03-17 (F 1.139).
  - BRC: placed by both on 05-26. W0's fill was refused, so the row is Wtd-only (−$25,511). W0 placed BRC again on
    06-09 (−$11,511).
  - LECO: Wtd on 06-16 (F 2).
  - POM_old: W0 on 06-23.
  - SEPR: W0 on 06-30 (−$25,452).
- 2007:
  - APOG: Wtd on 01-12 (+$60,625).
  - ETN: W0 on 01-19 (F 2, +$26,987).
  - NXY: W0 on 01-26, Wtd on 02-02; same fill.
  - ROL: W0 on 03-09 (F 5.06).
  - EXC: Wtd on 03-16 (F 1.402, +$66,391).
  - GAS1: W0 on 03-23, Wtd on 03-30; same fill.
  - WST: W0 on 05-11 (F 2), never filled.
  - TFSM: Wtd on 05-18, never filled.
  - PPS: Wtd on 05-25, W0 on 06-01.
  - OPSW: W0 on 06-22 (+$120,560, delisted exit).
  - CLC: placed by both on 06-29. W0's fill was refused, so the row is Wtd-only (−$24,114).
  - B: W0 on 07-27, Wtd on 08-03; same fill.
  - ACO: W0 on 08-03.
  - LRCX: W0 on 08-03 (F 10, −$35,370).
  - TVTY: placed by both on 08-10. W0's fill was refused, so the row is Wtd-only.
  - ORA: Wtd on 08-10 (−$31,113).
  - HMSY: W0 on 08-24 (+$67,069).
  - MFA: Wtd on 10-05 (F 0.25).
  - KOF: W0 on 11-02 (+$29,440).
  - KAI: W0 on 11-09.
  - BKH: W0 on 12-07, Wtd on 12-14; same fill.
- 2021: THO, W0 on 2021-02-12 (−$165,785), the slot VHC took in Wtd.

**T4 level (reported, no verdict).** Sources: `results/cw-*-s0-actual.sexp`, `-summary.sexp`, `-equity_curve.csv`,
`read/levels.txt`.

| | W0 | Wtd |
|---|---:|---:|
| total return | +1,472.76 % | +1,388.08 % |
| end NAV 2026-06-25 | $15,727,554.56 | $14,880,843.60 |
| CAGR | 10.96 % | 10.73 % |
| MaxDD | 27.22 % | 27.22 % |
| trades | 576 | 575 |
| Sharpe | 0.6338 | 0.6173 |
| Calmar | 0.4028 | 0.3943 |

ln(NAV_Wtd / NAV_W0) = −0.0553. That is below the 0.45-log floor and equals 0.25 of the record band's SD (0.225). T3
traces the first divergence to a gate decision; the size of the gap is displacement (§3).

**The decision this pair records.** T1 and T3 pass. Wtd ran on the unchanged `v12wk-9236` warehouse (both cells load
the 9,236-entry manifest and a 9,185-symbol universe), and its divergence is wholly the gate's. So **no list or
warehouse rebuild is needed for the gate basis**. This PR records it on #3136, and the issue's last item is met.

**What it cannot decide** (as pre-registered):
- Whether to flip the `true_dollar_volume` default. That is a separate config-default PR with paired goldens, under the
  correctness-flip precedent (#1926).
- Whether true dollars help or hurt returns: one seed, 0.45-log floor.
- The V3 validator basis (O1).
- O2 in general. It was checked by hand only on the six admitted names, and none is a one-bar pass.

#### #3109 / #3104: not run

`PREREQ_MISSING` (`results/chain.log`, 08:22:08Z): no Wrc or golden cell ran. R1–R3 are unread, the decision rule is
not applied, and the flip stays `AFFECTS-ALL`.

For the rerun: W0 at current main applies 15 held-position splits (`cw-W0-s0-splits.csv`). That is one more than the
14 the Wrc prediction was fixed from: TGI 2011-07-15, 2:1.

#### #3183: symbol-class membership (`results/3183/`, `read/m3183.txt`)

**M1.** Per vintage: committed / off / on; dropped = off − on, split warrant / unit / non-USD (W/U/N); and the
off-vs-committed dual-class collapse (the control).

| vintage | top-1000 c / off / on | dropped (W/U/N) | collapse | top-3000 c / off / on | dropped (W/U/N) | collapse |
|---|---|---|---:|---|---|---:|
| 1998 | 956 / 955 / 950 | 5 (3/0/2) | 1 | 2879 / 2876 / 2870 | 6 (3/1/2) | 3 |
| 1999 | 955 / 954 / 949 | 5 (2/1/2) | 1 | 2882 / 2880 / 2874 | 6 (3/1/2) | 2 |
| 2000 | 961 / 960 / 954 | 6 (2/1/3) | 1 | 2879 / 2876 / 2869 | 7 (3/1/3) | 3 |
| 2001 | 949 / 948 / 943 | 5 (2/0/3) | 1 | 2867 / 2864 / 2857 | 7 (3/1/3) | 3 |
| 2002 | 951 / 949 / 942 | 7 (2/1/4) | 2 | 2858 / 2855 / 2847 | 8 (3/1/4) | 3 |
| 2003 | 945 / 943 / 936 | 7 (2/1/4) | 2 | 2852 / 2850 / 2842 | 8 (3/1/4) | 2 |
| 2004 | 926 / 924 / 917 | 7 (2/1/4) | 2 | 2804 / 2800 / 2792 | 8 (3/1/4) | 4 |
| 2005 | 923 / 920 / 915 | 5 (2/0/3) | 3 | 2799 / 2794 / 2787 | 7 (3/1/3) | 5 |
| 2006 | 921 / 918 / 911 | 7 (2/1/4) | 3 | 2793 / 2788 / 2779 | 9 (3/2/4) | 5 |
| 2007 | 922 / 919 / 913 | 6 (2/0/4) | 3 | 2785 / 2781 / 2772 | 9 (3/2/4) | 4 |
| 2008 | 919 / 916 / 910 | 6 (2/0/4) | 3 | 2779 / 2775 / 2766 | 9 (3/2/4) | 4 |
| 2009 | 914 / 911 / 903 | 8 (3/1/4) | 3 | 2772 / 2767 / 2758 | 9 (3/2/4) | 5 |
| 2010 | 915 / 912 / 905 | 7 (2/1/4) | 3 | 2782 / 2778 / 2769 | 9 (3/2/4) | 4 |
| 2011 | 922 / 919 / 910 | 9 (3/2/4) | 3 | 2778 / 2775 / 2764 | 11 (4/3/4) | 3 |
| 2012 | 915 / 912 / 903 | 9 (3/2/4) | 3 | 2770 / 2766 / 2755 | 11 (4/3/4) | 4 |
| 2013 | 919 / 916 / 907 | 9 (3/2/4) | 3 | 2756 / 2752 / 2741 | 11 (4/3/4) | 4 |
| 2014 | 921 / 918 / 906 | 12 (5/3/4) | 3 | 2750 / 2745 / 2732 | 13 (6/3/4) | 5 |
| 2015 | 925 / 922 / 910 | 12 (5/3/4) | 3 | 2755 / 2747 / 2732 | 15 (8/3/4) | 8 |
| 2016 | 928 / 923 / 912 | 11 (5/2/4) | 5 | 2753 / 2742 / 2729 | 13 (6/3/4) | 11 |
| 2017 | 927 / 923 / 910 | 13 (6/3/4) | 4 | 2774 / 2766 / 2752 | 14 (7/3/4) | 8 |
| 2018 | 937 / 933 / 927 | 6 (0/2/4) | 4 | 2786 / 2778 / 2770 | 8 (1/3/4) | 8 |
| 2019 | 941 / 937 / 932 | 5 (0/2/3) | 4 | 2792 / 2784 / 2779 | 5 (0/2/3) | 8 |
| 2020 | 953 / 950 / 945 | 5 (0/2/3) | 3 | 2814 / 2804 / 2798 | 6 (1/2/3) | 10 |
| 2021 | 949 / 946 / 943 | 3 (1/1/1) | 3 | 2789 / 2781 / 2775 | 6 (3/2/1) | 8 |
| 2022 | 966 / 963 / 963 | 0 | 3 | 2863 / 2853 / 2853 | 0 | 10 |
| 2023 | 976 / 973 / 973 | 0 | 3 | 2892 / 2881 / 2881 | 0 | 11 |
| 2024 | 989 / 986 / 986 | 0 | 3 | 2919 / 2908 / 2908 | 0 | 11 |
| 2025 | 995 / 993 / 993 | 0 | 2 | 2953 / 2943 / 2943 | 0 | 10 |

- **Totals:** 390 list-drops (142 warrant, 80 unit, 168 non-USD) of 21 distinct names. Top-1000: 175. Top-3000: 215.
- **Share per vintage:** 0–15 names. The largest share is 1.41 % (top-1000-2017, 13 of 923); top-3000 peaks at 0.55 %
  (2015). Nothing drops in 2022–2025.
- **Control:** the dual-class collapse removes 243 names.
- **Report count vs off − on:** the "on" reports list 394 class drops. The extra four are BAC-WS-B in 2015 and STI-WS-B
  in 2015–17, which the off arm's dual-class collapse had already removed (D4).

**M2. Dropped names** (lists dropped from; rank and avg_dollar_volume in the committed lists):

| name | lists | rank | avg_dollar_volume |
|---|---:|---|---|
| CTRA_old | 44 | 1–330 | 7.1e7 – 3.94e10 |
| SBER | 44 | 2–862 | 1.46e7 – 2.07e10 |
| HSBA | 42 | 1–5 | 1.29e10 – 6.55e10 |
| WFC-WS | 40 | 10–158 | 1.09e8 – 3.55e9 |
| CMA-WS | 39 | 292–1,265 | 2.31e7 – 1.61e8 |
| CELSIA | 38 | 1–119 | 5.72e8 – 8.06e10 |
| RCF-UN | 36 | 146–2,828 | 1.6e5 – 5.28e8 |
| CND-UN | 23 | 166–2,637 | 7.37e5 – 1.1e8 |
| LHC-UN | 20 | 1–9 | 8.45e9 – 2.05e10 |
| VLY-WS | 18 | 880–2,011 | 2.61e6 – 2.84e7 |
| AIG-WS | 15 | 111–580 | 1.59e7 – 3.06e8 |
| COF-WS | 8 | 179–593 | 8.65e7 – 2.43e8 |
| GM-WS-B, STI-WS-A | 6 each | 160–363; 425–1,150 | |
| BAC-WS-A | 4 | 100–2,591 | |
| DNMR-WS | 2 | 921 | |
| ACIC-WS, BIOA-WS, C-WS-A, CVE-WS, SEDA-UN | 1 each | 2,353; 2,779; 1,846; 1,123; 1,298 | |

Specimens, by number of lists where each is excluded out of lists where it is a member:
- HSBA 42/42, CELSIA 38/38, SBER 44/44, CTRA_old 44/44, AIG-WS 15/15, C-WS-A 1/1, LHC-UN 20/20: every appearance is
  excluded.
- LDG is kept in all 21 of its lists, as expected (per-caller since #3280).

**M3.**
- rk-k0 s0 traded **none** of the 21 dropped names (`rk-k0-s0-trades.csv`).
- In W0's decision extract, they appear only as skipped alternatives with No_structural_stop, 10 times:
  - RCF-UN 2007-06-29
  - CND-UN 2010-06-11 and 2011-06-10
  - CELSIA 2013-09-06, 2014-04-25, 2014-05-16 and 2020-02-28
  - LHC-UN 2014-04-25
  - GM-WS-B 2017-09-22
  - BAC-WS-A 2018-08-10
- That skip happens before an id is drawn (`entry_audit_capture.ml` `make_entry_transition`). Adopting the policy filter
  could therefore move the record only through the candidate list itself, never through a dropped name's own trade.

**M4.** Ten names, spelled `-WT`, `-U`, `-R`, `-RI` or `-RT`, survive into the on-lists (46 list-memberships):

| name | lists | rank |
|---|---:|---|
| GIX-U | 12 | 179–2,203 |
| OIBR-R | 11 | 621–2,579 |
| GRP-U | 7 | 1,614–2,766 |
| NEE-P-R | 5 | 2,023–2,609 |
| GIG-U | 3 | |
| OXY-WT | 3 | |
| MOSC-U | 2 | |
| ACIC-U | 1 | |
| BMY-RI | 1 | |
| HYLN-WT | 1 | |

None ranks in the top 150. NEE-P-R reads as a preferred line, which the pattern counts as an `-R` spelling (D5).
Reported, not fixed.

**Estimand gap.** The policy filter drops names without refilling. A builder-level filter would admit the next-ranked
0–15 names per vintage.

**Outside M1–M4** (not pre-registered; for the next step): in the committed list order, names outside the curated set
still rank above US mega-caps after the filter.
- 2010: VNTR above AAPL.
- 2015: RICO and MEL above AAPL.
- 2020: VPI, LDG and DCM above AMZN.
- In the top 25: CMIG3 (2005) and BOUBYAN (2010).

Their currency and class are not established here.

With M1–M4 recorded, #3183's item is met.

### 2. Verdict

- **#3136.** The implementation check passes as pre-registered, and the pre-registered decision is recorded.
  - What this design can claim: on the record path (seed 0, 26y, broad top-3000 pit-v12), the true-dollar basis is
    live in both the entry gate and the hold exit. The first divergence is a gate decision on a divisor ≠ 1 symbol,
    and every gate-level change falls in one of the 10-19 classes.
  - What it cannot claim:
    - any return effect;
    - anything about a default flip;
    - a complete flip list for a full-history basis (D1). The list is complete for the basis the run actually read.
- **#3183.** A measurement; the item is met.
- **#3109.** Nothing was read.
- No ACCEPT or REJECT, as the README says.

### 3. Why

**The gate decides little on this path.**
- 7 of 683 / 679 placed entries (≈1 %) and 1 of 576 exits change over 26.5 years.
- That is far below the 10-19 note's 2.5 % of member-weeks. The gate binds only on screener candidates that also clear
  the cascade and the cash queue, and the v12 lists already rank on true dollars.
- The stored gate's blocks fall on small names that later reverse-split, near the $1M line: CVM, SVRA, HAFC, VHI, VHC
  and MAXN, with F from 1/7,500 to 1/8.

**The gate's own trades net to about zero.**
- Summed impact is −0.03 % of NAV: blocked → admitted −2.12 %, admitted → blocked +0.96 %, hold exit +1.13 %.
- Removing any one of CVM, VHC or PENN flips the sign, so no sign is claimed (n = 8).

**The level gap is displacement, and mostly one trade.**
- The 26 one-arm displacement rows sum to −4.77 % of NAV (median −0.18 %, range −4.01 % to +2.29 %).
- OPSW alone is −4.01 %. Without it, displacement sums to −0.76 % and all 34 differing rows to −0.78 %, against
  −4.79 % with it.
- The arms' year-end log gap moves only in years with differing decisions: 2000 −0.0037, 2005 +0.0102, 2006 −0.0204,
  2007 −0.0244, 2008 −0.0109, 2021 −0.0008, 2023 −0.0056.
- It is flat in 2009–2020 and 2024–26. From 2008-01 to 2021-02 both arms place the same decisions, sized in proportion
  to NAV.

**Five traces, end to end:**
1. **CVM** (the first gate flip, F).
   - On 2000-02-04, stored 20-bar ADV fails $1M and true passes (F = 1/7,500). W0's extract has no CVM row that week;
     Wtd places it.
   - The stop-limit ticket rests 10 weeks, fills 2000-04-14 at 3.97 and stops out 04-17 at 3.46.
   - The equity curves part on that fill date, and every later Wtd id moves up one more (SFAM 87 → 89).
2. **PENN** (the hold exit).
   - Both arms enter on 2000-04-17. With F = 4, the stored reading never fails the $500k hold floor in 17 Fridays.
   - The true reading fails it first on Friday 2000-08-18. Wtd's liquidity exit sells on 08-21 at 14.62; W0 holds to
     its 09-05 laggard rotation at 13.81 (+$10,185 to Wtd). This is the only liquidity_exit in either arm.
3. **AVD** (admitted → blocked).
   - On 2005-03-11 stored passes and true fails (F = 2.67). Wtd has no AVD row in 2005.
   - W0 buys 03-21 and stops out 04-22 (−10.48 %). Wtd's `splits.csv` lacks AVD's 2005-04-18 split because it never
     held AVD.
4. **SVRA → ALSK → BRC** (one admission re-routes cash).
   - SVRA, admitted on 2006-01-20, is 14 % of NAV from 01-24.
   - On 2006-03-21 Wtd has $15,069 against the $175,224 ALSK needs, so the fill is refused. W0's ALSK makes +$36,904.
   - The cash Wtd did not spend on ALSK fills BRC on 2006-05-30 (−$25,511), the same day W0 refuses BRC for DWSN1.
5. **OPSW → CLC** (the trade that carries the gap).
   - W0 places OPSW on 2007-06-22 (F = 1; the gate passes on both bases). Wtd places nothing that week, so the extract
     does not record why.
   - OPSW fills 06-29 at 9.98 and leaves 09-21 "delisted" at 14.24: +42.7 %, +$120,560, 4.0 % of NAV (the 2007 cash
     takeover).
   - Buying it leaves W0 $812.55 short for CLC's fill on 07-24. Wtd fills CLC and loses $24,114.

**Other mechanisms:**
- Timing, cost and turnover: trades are 576 vs 575; no effect.
- Long-resting tickets appear in the lists: CVM 10 weeks; HAFC, ADP and ENB 5–7 months. That is the record's known rest
  behaviour, not the lever.
- The data defect (D1) reaches one placed decision, ENB 2004-03-26, which both arms placed. It does not move this pair.

### 4. How it fits

- **`dev/notes/dollar-volume-gate-flips-v12-2026-10-19.md`: confirmed in direction and era, refined in scale.**
  - fail→pass, from names that later reverse-split, dominates and spans 2000–2023.
  - pass→fail, from forward splitters, is rare and early (AVD 2005).
  - The O2 answer holds on the realised flips.
  - Realised decision flips are about 1 % of placed decisions, against 2.5 % of member-weeks.
- **`project_26y_path_noise_floor` and `project_record_kseed_band`: confirmed.**
  - A cash change re-draws a few local steps that re-synchronise, and the level moves by how far the cascade reaches a
    tail trade (here OPSW, by 2008).
  - −0.055 log is 0.25 SD of the band.
  - `project_record_kseed_band` already carries the P0 trace; this reading is consistent with it.
- **`project_edge_is_the_fat_tail` and `feedback_perturb_before_believing_a_cohort_split`: confirmed.** One trade
  carries 84 % of the summed impact, and the gate's own-P&L sign does not survive a one-row perturbation.
- **The 10-09 ledger entry (`rebaseline-v12-record-baseline`)** lists "#3136 liquidity gates" among the unmodelled items
  around the record's thin CAGR margin. On one seed this pair puts it at −0.23 pp CAGR, inside path noise.
- **#3183 against the 10-07 note**, which said foreign-currency, unit and warrant lines head some lists: the filter
  removes every named specimen where it appears, but the four-name curated non-USD set leaves other top-ranked names.
  This refines the note's scope.
- **The pre-registration's M3 expectation ("CELSIA traded once per #3183") is stale.** rk-k0 never traded CELSIA; the
  trades that did are in other runs' files (`shorts-phase-b-2026-10-09` v12, `obvious-fixes-2026-09-25` v11).

### 5. What it implies next (options; the choice is the user's)

1. **#3136: stop.** The measurement the issue asked for is done; close the issue after merge.
2. **If a default flip is wanted** (a correctness case, not a returns case): fix the divisor's input first.
   - A flag-on run reads `data.csv` from `TRADING_DATA_DIR`. The record's standard run tree has `data.csv` only for the
     650 committed symbols, all starting 2009 or later. The flag would be silently inert for about 11,200 symbols and
     partial for 300. td-full fixed the first problem and kept the second (D1).
   - Options: stage the full store ahead of the committed bar files, or compute F from the warehouse.
   - Add a liveness line (symbols with F ≠ 1, symbols with no file), like the `split_dividend_guard` line.
   - Then O1 and the config-default goldens.
   - A K = 5 performance read is not worth about 22 h per arm on this evidence: roughly 1 % of decisions move, the
     gate's own P&L is about 0, and the level is path noise.
3. **#3183: the item is met.**
   - Adopting the filter with refill is a list rebuild that needs its own null comparison (the 10-07 decision). M3
     bounds the direct record effect at zero traded names.
   - Optional list-quality follow-ups: the M4 spellings, and the top-ranked names outside the curated set. The second
     needs a currency source, as `symbol_class.mli` notes.
4. **#3109.** Land the prerequisite PR. The rerun needs W0 again on the new SHA and a refreshed Wrc prediction
   (15 splits, including TGI).
5. **Chain hygiene.** Stop committed bar files from shadowing the store in td-full before any chain that reads
   `data.csv`: a true-dollar run, or a validator comparison of V7/V13 against the record.

### 6. Defects found

**D1. td-full's step 2 shadows the bar store's full-history `data.csv` with the 650 committed short files.**
- Specimens: `chain.sh` lines 95–96; `trading/test_data/A/K/ADSK/data.csv` starts 2009-01-02 (511 of the 650 files
  start that day).
- Effect on the divisor: Wtd's divisor misses splits before a short file's first bar or after its last, for 300 of the
  650 symbols (`read/tdfull_check.txt`; for example AAPL's F at 1999-01-04 is 28 here and 112 on the full history).
- Effect on decisions:
  - ENB 2004-03-26, placed in both arms (F 2 vs 4), would be blocked on the full history.
  - So would CLF 2001-06-08 and 06-15, which were skipped alternatives.
- Effect on the validator: its `-data-dir` reads the same short files.
  - W0's V13 is 39 against the record's 24, and V7 is 36 against 21. The record's validator read the full store
    (`record-kseed-2026-10-27/chain.sh` line 144).
  - All ten stored V13 specimens are committed short-file symbols reading "no bar on entry_date … (nearest earlier bar:
    none)": WRB 2000-08-28, WDC 2003-10-06, TYL 2007-09-11, TSCO 2005-03-28, TRMB 2003-11-24, STT 2000-04-10, SNA
    2004-03-08, ROL 2007-03-12, PKG 2004-03-17, and QCOM 2026-05-18 (nearest earlier bar 2026-04-10).
  - V7 lists WRB 2018-04-20 with 485 weekly bars.
- V6 is unaffected. This is not a simulator defect.

**D2. Warmup ids break the pre-registration's id-clock premise.**
- `suppress_warmup_trading` drops the 1999 warmup's entries, but `gen_position_id` (`entry_audit_capture.ml:55-57`) has
  already drawn the id.
- W0's first post-warmup id is 83; Wtd's is 84 (entries extracts; id-shift rows DIS, TWX1 and FR in `firstdiff.txt`).
- So the first changed decision is in the warmup, invisible to both `trades.csv` and the extracts, and ids are never a
  common clock.
- T3 is unchanged, because CVM is the smallest differing id on either side.

**D3. The README's divisor wording differs from the code.** The README uses close confirmation only; the code also
applies the volume check. Values differ on 6 rows (PENN 4 vs 17.69, VHI 1/12 vs 1/4, HMSY 1 vs 3, RNWK, NABZY, ABEV).
F and every class are the same.

**D4. M1's off − on leaves out four class drops.** BAC-WS-B (2015) and STI-WS-B (2015–17) were already removed by the
off arm's dual-class collapse: 394 class drops against 390.

**D5. M4's pattern counts NEE-P-R as an `-R` spelling.**

**D6. Pack: four "Concentrated gains at NAV peak … n/a for 1 position price/inventory input" cards** (peaks
2010-04-23, 2011-07-21, 2018-06-06 and 2021-04-12). Not traced.

**D7. Chain hygiene.**
- `chain.sh` collects `chain.log` before it writes "CHAIN W DONE", so the committed log has no DONE line.
- The run started twice, 16 s apart (08:22:02 and 08:22:18).

### Review-pack look

The pack embeds bar series, so it is not committed or linked (EODHD terms; in place of RV1's link). Rebuild with:

`sh dev/scripts/review_pack.sh --out .sweep-output/review-chain-w --title "chain-w W0 vs Wtd (2000-2026, pit-v12, td-full)" --run-kind arm --charts-run 0 --no-container --data-dir data W0=dev/experiments/chain-w-2026-11-10/results/cw-W0-s0- Wtd=dev/experiments/chain-w-2026-11-10/results/cw-Wtd-s0-`

then `sh dev/scripts/review_pack_render.sh --site .sweep-output/review-chain-w/site`.

**What the look showed.** `top.png` and parts 1–26 were opened.
- The KPI strip matches W0's `actual.sexp`. The window is 2000-01-03 → 2026-06-25, and nothing renders as NaN or blank.
- The Arms part agrees with the read: the yearly spread is non-zero only in 2000, 2005–08, 2021 and 2023; 559 trades
  are shared and 33 are one-arm; the first non-shared entry is CVM 2000-04-14, which is T3's F.
- Two things looked wrong: the V13 specimens (D1) and the four n/a cards (D6).

**Signal bullets (RV3):**
- The eras vs SPY, eroded-era, worst-stretch, gate-reopen, concentrated-open-gain, ten-trades and average-invested
  bullets describe the record path. They have the same shape in both arms; no claim is made.
- "Initial stop under 2 % below E": 18 trades in each arm (−$535k and −$508k). This is the 11-06 walk's D4, not the
  lever.
- The E-vs-close, trail-never-raised and fallback-stop bullets read n/a because the pack was built `--no-container`.
  That is the correct reading.
- Fill-week volume, filled-from-above and stops filled beyond the stop are record-path execution flags, with the same
  shape in both arms.
- "V13 39": refined. The count includes D1 artifacts.
- "Arms +1,473 % / +1,388 %": confirmed, and traced in §3.
