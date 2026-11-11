# chain-w-2026-11-10: cloud verification chain for #3136, #3109 (with #3104) and #3183

**Pre-registration.** Nothing has run. Every read below is fixed before the first cell launches. The chain runs in a
Claude cloud session (`docs/howtos/claude_cloud_sessions.md`), not in the local container.

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
  F **fails** T3: something other than the gate moved first. No `trade_audit.sexp` extract is needed (the audit is
  not collected). Every differing entry is listed with its symbol, date, id, side (blocked → admitted, the 10-19
  measurement's dominant 1.9 % class, or admitted → blocked, the 0.6 % class) and divisor.
- **T4 level (reported, no verdict):** total return, end-NAV log ratio, MaxDD, trades, Sharpe, Calmar. A level delta
  below 0.45 log that T3 does not trace to gate decisions is path noise.
- **The decision this pair can record** (the `[after-merge]` item): the pit-v12 lists already rank on true dollars
  (#3164, lists #3182, rebuild decided 10-07, record rebaselined 10-08); the remaining stored-basis reading is the
  liquidity gate, computed at read time from bars. If T1 and T3 pass, Wtd ran on the unchanged `v12wk-9236`
  warehouse and its divergence is wholly the gate's, so **no list or warehouse rebuild is needed for the gate basis**;
  that is recorded on #3136 and the issue's last item is met. If T1 or T3 fails, no decision is recorded and the
  failing specimen becomes the next step. **If the pair is identical** (T3 has no first divergence), **no decision is
  recorded**: the run has no liveness counter for the divisor, so an insensitive path cannot be told from an inert
  knob. The next step is to trace first: take a W0 candidate-week from the 10-19 flip list, check its divisor and gate
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
   `.sweep-output/chain-w/results`). `trade_audit.sexp` is left out (large; not needed by these reads).
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
