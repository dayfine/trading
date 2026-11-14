# Price-band tiebreak confirmation (2026-11-13): pre-registration

**Status: run 2026-11-14.** NO-BUILD: C1 INCONCLUSIVE (return short, drawdown +3.83 pp, concentration 1 of 5), C2
FAIL (median Δ ln(1+R) −0.280, 1 of 5 seeds positive). `Price_band_seeded` stays a default-off axis, and no further
confirmation cells run on it without a new mechanism argument (§Results). The rule below was applied as written to the
20 cloud cells this directory launched.
The user approved this experiment on 2026-11-13.

## Why

The 26-year K = 5 paired run of `candidate_ranking Price_band_seeded` (#3588 pre-registration, #3595 results;
`../price-band-tiebreak-2026-11-13/README.md`) read **NOT LIVE as written**. Its liveness proxy, the ≤ $14 share of
entries at 1.3× S's, was mis-specified: it watched the smallest, most downstream footprint of the order. The
description beside that verdict is what this experiment tests:

- **Return.** P beat S in 5 of 5 seeds. The median Δ ln(1+R) was +0.348, about 2.2–2.4 SD under a shared-draw bound.
- **Drawdown.** P's median max drawdown was 5.64 pp deeper (arm medians; the paired median was +1.28 pp).
- **Bands.** The ≤ $14 band carried about 82 % of the one-arm net gain. By band, in points of entry NAV: < $8 +154,
  $8–14 +16, $14–33 +65, ≥ $33 −28 (before the split-restatement correction in §Reported regardless).
- **Era.** About 70 % of the gap came from positions entered in 2010–12 (MERC, ATML, WAL, DINO, REGN), plus ADMA in
  2023. The 2018–23 era ran against P in all five seeds.

The #3595 §What it implies next section names two confirmation cells: a period cell without the 2010–12 recovery and a
top-1000 breadth cell. It asks for a fresh pre-registration with four parts: a liveness bar from the per-decision
binding rate, a fixed drawdown reading, a name-concentration check, and the cells themselves. This README is that
pre-registration.

#3597 (`../price-band-binding-2026-11-13/`) pre-registers a separate diagnostic: one S-k0 cell with
`--emit-candidates`, re-ranked offline. It runs beside this one. This read does not wait for it and uses none of its
numbers; its own liveness is measured inside its own cells. How the two verdicts combine is fixed below (§How this
read combines with #3597).

## Mechanism under test

The mechanism is unchanged from #3588. `candidate_ranking = Price_band_seeded` (#3587) is default-off. The cascade
score stays primary. Among equal scores, the cheaper band of the raw ticket price `suggested_entry` goes first, with
`ranking_price_band_edges` = [8; 14; 33], the field default. Inside a band the order is exactly `Seeded`
(`screener_ranking.ml` `_price_band_seeded_cmp`).

So at the same seed, P and S order a tie differently only when the tie spans bands. P can then only move a cheaper name
ahead of a dearer one. The liveness signature below rests on that. Faithfulness is as #3588 states it: W1 holds (no spine
item moves) and W2 holds (`weinstein-book-reference.md` §4.5).

## Design

### Arms and seeds

- **S** is the record config. `specs/pbc<C>-S-k<K>.sexp` equals `../record-kseed-2026-10-27/specs/rk-k<K>.sexp` except
  for its name, description and the one cell change below.
- **P** is S plus `((screening_config ((candidate_ranking Price_band_seeded))))`, in `specs/pbc<C>-P-k<K>.sexp`.
- **Seeds.** K = 0..4. `tiebreak_seed` = K in both arms. Arm P seed K pairs with arm S seed K, and both run in the same
  session.
- **Generation and checks.** `make_specs.sh` writes all 20 specs. `chain.sh` re-checks every relation before it runs
  anything, and the check fails on a tampered spec (tested: an extra override, a stray top-3000 list, a moved end
  date, a changed seed).

### C1, the period cell: 2013-01-01 → 2026-06-26, top-3000 PIT v12 schedule

- **The change.** Only `start_date` moves, from 2000-01-01 to 2013-01-01.
- **Schedule.** The full 1999–2025 yearly schedule is kept, so each year's list is in force on its own dates (U4).
  This is the same construction as the path-stability 2019–24 cells (`../path-stability-2026-10-23/`), which kept the
  record body and full schedule and changed only the window.
- **No 2010–12 entries.** `suppress_warmup_trading` defaults to true (`weinstein_strategy_config.mli`), and the record
  config does not override it. So no entry is placed before 2013-01-01, and the cell opens all-cash. A 2012 entry such
  as WAL 2012-05-01 cannot carry into C1.
- **The warm-up.** The runner prepends 364 days (`runner.ml` `_weekly_strategy_warmup_days`), so the simulator starts on
  2012-01-03 and every indicator is warm before the first decision:
  - the 30-week stage MA, of stocks and of the index;
  - the 52-week RS line. `Rs.analyze` needs `rs_ma_period` = 52 aligned weekly bars, which is why the warm-up is 364
    days (`dev/notes/rs-warmup-gap-2026-07-07.md`);
  - the macro gate. Its index MA reads the same panel. Its A-D breadth series is loaded whole from the data dir
    (`Ad_bars.load`, not clipped to the window), so the 200-bar momentum MA is full from the first day. NH-NL looks
    back 13 weeks and breadth direction 4.
- **Checked, not assumed.** The preflight runs C1's first quarter and requires the macro trend and breadth state on
  every one of its Fridays to equal the 26y cell's (`pb-S-k0`, #3595) on the same date (§Chain).
- **Residual.** The weekly view is `lookback_bars` = 56. For the first 3 Fridays the panel holds 53–55 weekly bars,
  the same truncation every window has at its start, including the 26y window's 2000 start. At the record config,
  resistance reads that same view (`resistance_lookback_bars` = 0), so nothing deeper is lost after those weeks.

### C2, the breadth cell: 2000-01-01 → 2026-06-26, top-1000 PIT v12 schedule

- **The change.** Every `top-3000-YYYY` list becomes `top-1000-YYYY`, and `universe_size` 3000 becomes 1000. The
  window is the record's.
- **The lists are on main.** They live in `trading/test_data/backtest_scenarios/pit-v12/composition/top-1000-{1998..2025}.sexp`
  and are md5-pinned in `composition.md5`. They were built and twin-deduped with the top-3000 lists: `twin-drops.txt`
  has top-1000 rows.
- **Why this cell.** It is the axis `dev/rules/promotion-confirmation.md` names for universe diversity: "a top-1000
  schedule vs the top-3000 schedule, built from the same yearly lists with the same D1/D2 dating". Broad against
  broad, never sp500 (`.claude/rules/universe-discipline.md`).
- **Same warehouse.** The 1999–2025 top-1000 union is 3,477 names. All of them are in the top-3000 union, and all
  except MEL are in the v12wk warehouse. MEL is also the one absent name in every record cell (`n_symbols_absent=1`),
  so the same warehouse serves both cells.
- **Expected cache line.** C2: `n_symbols=3492` (3,477 + 15 index and ETF symbols). C1: `n_symbols=9200`, as
  `pb-S-k0`'s log reads.

### Same build, same data

- **Build.** All 20 cells run at one `origin/main` SHA (`PB_SHA`) that contains #3587 and this pre-registration, in
  Claude cloud sessions.
- **Data.** The data are #3588's: the R2 warehouse `v12wk-9236`, corporate actions `corpact-2026-10-27`, and the
  validator's data dir built as in `../chain-w-2026-11-10/README.md` §Data. `TRADING_PATH_SEED_SALT=0`.
- **Sessions.** The five sessions must log the same `HEAD=`. A seed run at a different SHA is re-run.

## Decision rule (applied as written, to each cell separately)

`read/decide.sh RESULTS TAG LIST_BANDS POSITIONS` computes every quantity below and prints the cell outcome. Pointed at
the #3595 artifacts (TAG `pb`), it reproduces that read's figures exactly (`read/repro-3595.txt`): B 66.8 %, G 80.1 pp,
median Δ +0.348, m_S 0.149, the drawdown difference +5.64 pp and the trim-3 nets. Under this rule the 26y read comes
out **INCONCLUSIVE** (drawdown). That is the outcome #3595 said its own rule would have given had liveness passed.

### 0. Validity

- **V6.** `validator_diff -check V6` of P-kK against S-kK must exit 0 (`pbcC-P-kK-s0.v6diff-S.log`). A mismatched pair
  is left out and reported.
- **Absent symbols.** Both arms' snapshot-cache lines must read `n_symbols_absent=1`, the MEL baseline. Otherwise the
  pair is VOID.
- **Seed count.** With fewer than 5 valid seeds, "4 of 5" below becomes "all but one". With fewer than 4, the cell is
  INCONCLUSIVE whatever the medians.

### 1. Liveness first: what the order does to the post-cut list

`entries.tsv` holds, for every Friday on which an arm placed a ticket, the whole post-cut list its entry walk saw. A
**Friday-pair** is a decision date on which both arms recorded one. Bands come from the raw close on the decision date
(`read/list_bands.sh`), a proxy for `suggested_entry` that agreed with the fill band on 96–97 % of #3595's trades.

- **B, the binding rate.** The share of Friday-pairs whose two lists differ. **Bar: ≥ 33 %.**
- **G, the band signature.** Take the names in S's list and not in P's, and the share of them priced ≥ $33. Subtract
  the same share for the names in P's list and not in S's. **Bar: ≥ 40 pp.**
- **Pooled.** Both are pooled over the valid seeds. Fewer than 100 Friday-pairs makes liveness unreadable, and the cell
  is INCONCLUSIVE.
- **LIVE** when both bars hold. Otherwise the cell is **NOT LIVE**, and no return read is made for it.

Why these bars:

- **Measured base.** On #3595's 2,011 Friday-pairs, B was 66.8 % pooled (65.2–69.6 % by seed). G was 80.1 pp
  (S-not-P names 85.7 % at ≥ $33, P-not-S names 5.6 %; 77.9–81.6 pp by seed).
- **The margin is half the measured value, for a stated reason.** The order binds only where a score tie straddles the
  top-20 cut and spans bands. A narrower universe passes fewer names through the cascade, so C2 is expected to bind
  less by construction. The bar must not fail an order that still binds routinely, and one Friday in three is routine.
- **B is out of reach of path effects alone.** In #3595, names held or pending in the other arm were 2.2–6.2 % of the
  names missing from a list (`../price-band-tiebreak-2026-11-13/results/read/held_confound.txt`). That is at most
  about 0.09 per list on each side, so they could change at most about a fifth of the lists. The mirror holds: an
  order that "rarely binds" cannot reach a third.
- **G is the order's fingerprint.** Inside a band P's order is S's, so the order itself only ever swaps a dearer name
  out for a cheaper one. Path-only differences are band-symmetric, with an expected gap of 0. Half of 80 pp keeps the
  bar far from path noise and still allows the top-1000's heavier ≥ $33 mix.
- **Not repeated.** No entry-share × multiplier (#3595 §Defects 1). Both measures are read on the decision the
  mechanism makes, the post-cut list, rather than downstream of the cash and stop gates.

### 2. Return

Per valid seed, Δk = ln(1 + R_P,k) − ln(1 + R_S,k), where R = `total_return_pct` / 100 from `actual.sexp`. The
quantity m_S is the median, over the pairs of valid S seeds (10 at 5 seeds), of |ln(1 + R_S,i) − ln(1 + R_S,j)|.
**δ = max(0.20, m_S).**

- **Return passes** when the median Δk is at least δ **and** Δk > 0 in at least 4 of 5 seeds.
- **Return fails** when the median Δk is ≤ 0, **or** Δk > 0 in 2 seeds or fewer.
- Anything between the two is **short**.

Why:

- **The 0.20 floor is #3588's.** The 26y record band has SD 0.225 (`dev/agent-memory/project_record_kseed_band.md`),
  and an untraced difference under 0.2 log is one draw (`project_26y_path_noise_floor.md`).
- **C1 keeps the floor although it is half as long.** A shorter window does not shrink tie-order noise. The 6-year
  seeded spread (path-stability arm S, 2019–24) was SD 0.211, against 0.127 for #3595's 26.5-year S. Each of those
  six-year cells also deleted one minor name from the lists.
- **m_S is the cell's own reshuffle null** (#3595 §Why 5). Two seeded tie draws of the same config differed by a median
  0.149 at 26y, so a paired gap no larger than a seed change is "just another tie order". It raises δ only where it
  exceeds 0.20; it did not at 26y.
- **The bar is a cross-seed spread, not a paired SD.** Pairing by seed removes almost no variance: P_k and S_k
  correlated +0.26 (#3595 §Why 5).
- **4 of 5, and the fail bars, are #3588's.** On its own, 4 of 5 is weak (6/32 under a symmetric null). It rules out a
  median carried by three seeds while two reverse.
- **Expectation, written now.** In the 26y run, the year-end gap grew from end-2012 to the end in 3 of 5 seeds, by a
  median +0.151, and two of the three positives were ADMA (`read/report.sh` §C on #3595). A C1 pass therefore needs
  more than the 26y run itself showed outside 2010–12. A shortfall in C1 is the expected outcome unless the order's
  edge is broader than that run shows.

### 3. Drawdown: one fixed reading

**Reading: the arm medians.** median_k(maxDD_P,k) − median_k(maxDD_S,k) ≤ **3.0 pp**, with `max_drawdown_pct` from
`actual.sexp`. The median of the paired differences is printed and not read.

Why arm medians:

- It is how #3588's clause was read, by its qc-results review (R1) and by #3595.
- On #3595's data it is the stricter reading: +5.64 pp against +1.28 pp paired. Choosing it cannot favour P.
- Pairing removes almost no variance (correlation +0.26), so the paired reading has no statistical advantage.

Why 3 pp: it is about one seed SD of max drawdown at 26y. That SD is 3.06 pp across #3595's five S cells and 3.31 pp
across the record band rk-k0..k4. A deepening larger than one seed's spread is not reshuffle noise. This is #3588's
number, now with its basis and its reading fixed. On #3595 the clause fails (+5.64).

### 4. Name concentration

Per seed, take the one-arm net: the sum of P-only positions' contribution ÷ the arm's NAV at entry, minus the same sum
for S-only positions (`read/positions.sh`, the #3595 `onearm_split` method). Drop the three largest P-only and the
three largest S-only positions. **Bar: the trimmed net is > 0 in at least 4 of 5 seeds.**

Why:

- **#3595's gap lived in about five names.** Dropping MERC, WAL, DINO, HOS and REGN left the P ≥ S + 3 group at net
  0.0.
- **The trim still held at 26y.** The trim-3 net stayed positive in 5 of 5 seeds there (+12.0 to +39.9).
- **The bar.** A cell whose gap does not survive losing its three best names on each side is a few draws, not a
  mechanism.
- **Why the net is a fair measure.** It is roughly additive in ln(1+R) and ranks the seeds as Δk does (#3595 §Why 3).

### Cell outcome

| outcome | when |
|---|---|
| **NOT LIVE** | liveness fails (§1) |
| **FAIL** | LIVE, and the return fails (§2) |
| **PASS** | LIVE, the return passes, the drawdown is within 3 pp, and the concentration bar holds |
| **INCONCLUSIVE** | anything else, including a short return, a drawdown or concentration miss, fewer than 4 valid seeds, or fewer than 100 Friday-pairs |

### The combined decision

| C1 | C2 | verdict |
|---|---|---|
| PASS | PASS | **ESCALATE** (confirmed) |
| either cell FAIL | | **NO-BUILD** |
| NOT LIVE | NOT LIVE | **NOT LIVE** |
| any other pair | | **INCONCLUSIVE** |

FAIL outranks everything: a FAIL in either cell is NO-BUILD, even if the other cell passes.

- **ESCALATE (confirmed).** Price_band_seeded becomes a promotion candidate under `dev/rules/promotion-confirmation.md`,
  and nothing more. That rule still requires:
  - **A walk-forward surface.** The axis `candidate_ranking` ∈ {Seeded, Price_band_seeded}, with neighbouring
    `ranking_price_band_edges`, through walk-forward CV with Deflated Sharpe. Only a ledger ACCEPT from it opens a
    default change (`dev/rules/experiment-flag-discipline.md` R3).
  - **The grid.** That surface is re-run in at least 3 contexts: the full window, a disjoint sub-window in a different
    macro regime, and the other breadth tier. C1 and C2 here are K = 5 seed reads, not walk-forward surfaces, and do
    not count as grid cells.
  - **A promotion PR**, on the user's decision.
- **NO-BUILD.** The order binds and still loses, or splits evenly, outside the context that produced the 26y gap. The
  gap is then attributed to what the failing cell removed: the 2010–12 cluster (C1) or top-3000 breadth (C2).
  `Price_band_seeded` stays a default-off axis, and no further confirmation cells run on it without a new mechanism
  argument.
- **NOT LIVE (both cells).** The order does not bind routinely outside the 26y top-3000 window, so the 26y gap cannot be
  a general property of it. It stays a default-off axis.
- **INCONCLUSIVE.** For each cell, name the bar that failed and by how much, and trace the gap per seed: which trades
  differ, and what they carried. No new cells run on this lever until the #3597 binding read is in and there is a
  fresh rationale. No default changes.

### How this read combines with #3597

The user approved running the two side by side (2026-11-13). Neither rule reads the other's numbers. #3597's L1 and L2
are its own quantities: the binding rate on one re-ranked path and the expected tail in +100 % trades. They are not this
README's B and G.

- **This read's verdict is final on its own rule**, with one exception. If this read returns ESCALATE while #3597's Rule
  1 returns CLOSE-AXIS or PARK, nothing escalates automatically. The two reads then disagree on whether the order buys
  a tail, and #3597's PARK and CLOSE-AXIS branches spend no further cells. The dispatcher puts the disagreement to the
  user with both reads: it is a direction call.
- **Every other combination cannot conflict.** Each non-ESCALATE verdict here, and every #3597 outcome, keeps
  `Price_band_seeded` default-off.
- **#3597's fresh-pre-registration liveness is not this rule's.** #3597's FRESH branch sets the liveness bar of a
  pre-registration written after its result, from an `--emit-candidates` P cell. This one was written before that result,
  so its bars come from #3595's measured list rates. If #3597 returns FRESH, the analyst reports its L1 beside this
  read's B. It changes no bar here.
- **If #3597's rule is not applied** (its band proxy agrees with the ticket band on fewer than 90 % of tickets), this
  verdict stands alone.

## Reported regardless of the verdict

Per cell, from `read/report.sh`, `read/capacity.sh`, `read/cash.sh` and `read/decide.sh`:

- **Per seed and arm:**
  - R, ln(1 + R), max drawdown, Sharpe, Ulcer index, closed trades, open positions, and entries at ≥ +100 %;
  - the band composition of entries, in four bands (< $8, $8–14, $14–33, ≥ $33);
  - the one-arm net by band, per seed and pooled, and by entry era.
- **Liveness, by seed.** B, G, and the share of P's tickets that S did not place on the same Friday (21.5 % at 26y).
- **The 2013–2026 increment on its own.** This is the year-end ln(NAV_P / NAV_S) and its change from end-2012 to the
  last date. For C1 it is the whole cell; for C2 it is reported beside the full-window gap.
- **The five largest one-arm contributors** per seed and side, with entry date, `entry_price`, band, P&L and share of
  entry NAV.
  - **The split-restatement trap.** `trades.csv` `entry_price` is restated for splits during the hold (#3595 §Defects
    2, #3384).
  - **The correction.** `read/positions.sh` takes the band from the raw close on the entry date whenever `entry_price`
    ÷ that close lies outside 0.80–1.25 (#3595 `basis_check`'s test), and the table marks such rows
    "split-restated".
  - **On #3595, this matters.** It moves DECK, EME, ENB and AVD to ≥ $33 and DUK and ADSK to $14–33, the six
    positions #3595 §Defects 2 listed. The corrected pooled one-arm net by band is < $8 +154.3, $8–14 +16.1,
    $14–33 +106.5 and ≥ $33 −69.5. The ≤ $14 share is unchanged at 82 % of +207.5.
- **Capacity** for entries priced at or below $14: position value at the fill ÷ the 20-day mean dollar volume.
  - Report p50, p90, the maximum and the count at ≥ 0.25.
  - Report the same again for entries from 2023-07-01, at the late-run NAV that #3595 §Why 6 asked about.
  - On #3595's artifacts this script reads P at p50 0.038, p90 0.194 and max 0.949, with 18 entries at ≥ 0.25. #3595's
    own table read p90 0.190 over 389 entries; ADSK's restated price, now corrected, accounts for the five-entry
    difference.
- **Cash displacement, both ways.** S's tickets that P skipped for `Insufficient_cash`, with their S result, and P's
  tickets that S skipped, with their P result, and the net. On #3595's artifacts the net is +7.8, +2.4, +26.1, −2.0 and
  −15.0 points by seed.
- **Validity.** The `HEAD=`, image and `STAGE OK` lines, `SPEC CHECKS OK`, the `PREFLIGHT_OK` lines, V6, and the
  cache lines.

The reading publishes summaries only. `positions-*.tsv` and `list_bands-*.tsv` are regenerated from a local `data/` and
are never committed: with `entry_price`, `px_ratio` would give a raw close. No output prints a bar.

## Not claimed

- **Nothing here changes a default.** Even ESCALATE only opens the walk-forward and grid program.
- **C1 is not disjoint from the 26y window.** It re-runs 2013–26 from cash and removes only the 2010–12 entries.
  2013–26 is also one macro era (post-GFC, with the 2020 crash and the 2022 bear market). The grid needs a
  bear-dominated regime (`promotion-confirmation.md` §Macro-regime diversity), and C2's full window carries 2000–02 and
  2008.
- **Neither cell is out of sample.** The screen chose the trait on 2000–2025, and both windows lie inside it.
- **The seeds re-draw tie order, not the market.** P's cross-band order is the same in every seed, so its five cells
  replicate one set of systematic swaps (#3595 §Why 5). A pass shows the swaps pay in this history and this breadth,
  not that they pay in expectation.
- **No pre-2000 cell.** #3595 suggested one if the deep-history lists support it. It is not part of this
  pre-registration.

## Files

- `make_specs.sh` writes `specs/`, the 20 cells (`pbc1-{S,P}-k0..4`, `pbc2-{S,P}-k0..4`).
- `chain.sh run K` runs one seed's four cells in one cloud session. It stages the data, builds, checks the specs,
  preflights the four specs over each cell's first quarter, then runs C1 S, C1 P (V6 against C1 S), C2 S and C2 P (V6
  against C2 S). Last, it writes each pair's keyed trade diff and `entries.tsv` extracts.
- `chain.sh preflight K [NAME...]` is the local smoke path only (§Smoke). It runs the spec checks and preflight against
  an existing warehouse and data dir, without the guards or the stage.
- `read/` holds the decision and report scripts, adapted from #3595's `results/read/` with the cell tag as a parameter:
  - `list_bands.sh`, `positions.sh`: per-row inputs read from the bar store; their outputs are never committed;
  - `decide.sh`: the rule above;
  - `report.sh`, `capacity.sh`, `cash.sh`: §Reported regardless;
  - `repro-3595.txt`: their output on the #3595 artifacts, the reproduction this README cites.
- `smoke.txt` is the local smoke record (§Smoke).
- `results/k<K>/` holds each seed's `chain.sh collect` output, after the runs. `trade_audit.sexp` and any
  `candidates.sexp` are left out.

## Chain

- **Cell guard.** `CELL_TIMEOUT` = 14,400 s.
  - The slowest #3595 cloud cell, pb-S-k0 (26.5 y of top-3000 plus the 1-y warm-up), ran 8,058 s. The ten cells ran
    7,161–8,058 s (`chain-kK.log` RESULT lines).
  - C1 simulates 14.5 of those 27.5 years, so it projects at about 0.53× (3,770–4,250 s).
  - C2: a top-1000 26y cell ran 8,250–8,780 s, about 55 % of a top-3000 26y cell (`../top-n-grid-2026-09-22/README.md`,
    lane C3, 2026-09-24). So C2 projects at 3,940–4,430 s.
  - 14,400 s is 3.2× the larger projection and 1.8× a full top-3000 26y cell, so a mis-projection does not kill a
    healthy cell.
- **Disk.**
  - Before an unfinished stage, at least 12 GB must be free: on 11-13 the stage took the five sessions from 20–22 GB
    free to 14–16 GB.
  - Before each cell, at least 5 GB: a 26y cell's outputs stayed under 1 GB (14 GB free both before and after pb-S-k0
    on 11-13).
- **Spec checks.** For each seed:
  - `pbc1-S` equals rk with only the start date moved;
  - `pbc2-S` equals rk with only top-3000 → top-1000 and `universe_size` changed, naming 28 top-1000 lists and no
    top-3000 one;
  - each P equals its S plus the one override;
  - all 27 top-1000 lists of the schedule exist.
- **Preflight.** Each of the four specs runs its first three months: C1 to 2013-03-29, C2 to 2000-03-31. It then
  checks:
  - the override is in P's `params.sexp` and absent from S's;
  - the cache line reads the expected `n_symbols` with `n_symbols_absent=1`;
  - the macro trend and breadth state on every preflight Friday equal the 26y cell's (`pb-S-k0`) on that date.

  This is the C1 warm-up check: a fresh 2012 warm-up must reach the macro state of a run with 13 more years of history.
- **The rest is #3588's:** the flock, the `PB_SHA` pin and resume, the stage, the build, the V6 diff, `collect`, and the
  leftover cleanup under the lock.

## Smoke (local, 2026-11-13)

The smoke ran the chain's own preflight path, `chain.sh preflight 0 <spec>` with `RUNNER=exec`, in the local
`trading-1-dev` container. It used the container's v12wk warehouse (`/tmp/snap_top3000_pit_v12wk`, the source of R2
`v12wk-9236`) and the tree's committed `test_data`. That data dir has no corporate actions, so no dividends are
credited, which does not matter for a preflight. `smoke.txt` has the log, the cache lines and the checks.

| spec | window | local wall | override in params | n_symbols / absent | macro = 26y |
|---|---|---:|---|---|---|
| pbc1-S-k0 | 2013-01-01 → 03-29 | 1,147 s | no | 9,200 / 1 | 12 of 12 Fridays |
| pbc1-P-k0 | 2013-01-01 → 03-29 | 877 s | yes | 9,200 / 1 | 12 of 12 |
| pbc2-S-k0 | 2000-01-01 → 03-31 | 416 s | no | 3,492 / 1 | 12 of 12 |
| pbc2-P-k0 | 2000-01-01 → 03-31 | 196 s | yes | 3,492 / 1 | 12 of 12 |

- **C1's warm-up holds.**
  - From the first Friday, 2013-01-04, the macro trend and breadth state equal the 26y cell's on all 12 Fridays of the
    quarter (Good Friday 2013-03-29 is a holiday).
  - No entry falls before 2013-01-01: the first is 2013-02-22, in both arms.
  - All 150 `rs_value` fields in each C1 arm's `trade_audit.sexp` are set (0 None).
- **C2 resolves the top-1000 schedule.** `n_symbols` is 3,492 with `n_symbols_absent=1` (MEL), as projected. The
  override is in P's `params.sexp` only.
- **The checks catch what they should.**
  - The spec checks pass for all five seeds and abort on each of four tampers.
  - The macro comparison catches a single altered row.
  - `collect` leaves out `trade_audit.sexp` and `candidates.sexp`.
- **The local walls are not a cloud estimate.** The first run shared the container with another agent's
  `dune runtest` for about 16 of its 19 minutes. The cloud figure is #3595's 291–315 s.
- **Not run locally:** the guards, the R2 stage, the full cells, the validator, the V6 diff and the per-pair reads.
  They are #3588's code, which ran on 11-13. The only changes around them are the four-cell loop and the path
  helpers the exec mode needed (`cpath`, `hpath`, the fixtures root), which the preflight exercised.

## Launching (one cloud session per seed, K = 0..4, side by side)

**Layout: five sessions, one per seed.** Each runs C1 S, C1 P, C2 S and C2 P in sequence. Ten sessions, one per
(cell, seed), were the alternative. Five were chosen because:

- **It is #3588's layout.** On 11-13 five sessions ran side by side at one HEAD and one image, so the concurrency and
  quota profile is known.
- **Ten sessions double the overhead.** That means ten R2 pulls of the 3.6 GB warehouse plus the bar archive instead
  of five, and twice the per-session setup: staging, build, preflight, the brief's turns and the heartbeats.
- **One stage per seed.** A seed's four cells share one data stage and one build.
- **The extra wall is acceptable.** About 5–5.5 h against about 3 h. Nothing waits on the result tonight, and #3597's
  diagnostic runs alongside.
- **A restart costs at most the cell in flight**, about 1.2 h: `chain.sh` resumes past every cell whose `RESULT` line
  is logged.

**Expected wall per session**, from #3595's cloud logs:

- stage 10–13 min;
- build under 1 min;
- preflight about 5 min per spec on #3595's 3-month windows (291–315 s), so about 20 min for four;
- cells 2 × 3,770–4,250 s (C1) plus 2 × 3,940–4,430 s (C2), 4.3–4.8 h.

That is **about 5–5.5 h** in all. The chain must therefore detach: `run_in_background` caps at 2 h
(`docs/howtos/claude_cloud_sessions.md` §Briefs that work).

The dispatcher picks one SHA on `origin/main` that contains #3587 and this pre-registration, and puts it in all five
briefs as `<PB_SHA>`. `chain.sh` refuses to run at any other HEAD, and refuses to resume at a HEAD different from the
one its `chain.log` already records.

```
Repo checkout of dayfine/trading. Run: git fetch origin main && git checkout <PB_SHA>. Do not edit tracked files.
Launch the chain detached, exactly:
  mkdir -p .sweep-output/price-band-confirm && PB_SHA=<PB_SHA> setsid nohup sh dev/experiments/price-band-confirm-2026-11-13/chain.sh run K >> .sweep-output/price-band-confirm/run.out 2>&1 < /dev/null &
Do not start it as a harness background task (those are killed at 2 h); it takes about 5.5 h. Wait with a Monitor
until-loop on .sweep-output/price-band-confirm/chain.log for "PRICE-BAND-CONFIRM kK DONE" or "ABORT", plus a 30-minute
send_later heartbeat that re-checks the log and re-arms both. After any restart, re-run the same launch command (it
resumes). Never docker kill every container: the session's own trading-1-dev container is not a chain cell. Never
print R2 or EODHD credentials. When "PRICE-BAND-CONFIRM kK DONE" appears, copy .sweep-output/price-band-confirm/results/kK
into dev/experiments/price-band-confirm-2026-11-13/results/kK on a new branch experiment/price-band-confirm-kK, commit
and push that branch. Do not open a PR, merge, label or push to main. If the chain logs ABORT, push the log the same way
and stop.
```

After the runs:

1. The dispatcher gathers the five branches into one results PR.
2. **The reads, on the host,** from a local `data/`, per cell C in 1 and 2 (`R=dev/experiments/price-band-confirm-2026-11-13`):

   ```
   mkdir -p $R/results/read
   sh $R/read/list_bands.sh $R/results pbcC data > /tmp/lb-C.tsv
   sh $R/read/positions.sh $R/results pbcC data > /tmp/pos-C.tsv
   sh $R/read/decide.sh $R/results pbcC /tmp/lb-C.tsv /tmp/pos-C.tsv > $R/results/read/decide-C.txt
   sh $R/read/report.sh $R/results pbcC /tmp/pos-C.tsv > $R/results/read/report-C.txt
   sh $R/read/capacity.sh /tmp/pos-C.tsv data > $R/results/read/capacity-C.txt
   sh $R/read/cash.sh $R/results pbcC /tmp/pos-C.tsv > $R/results/read/cash-C.txt
   ```

3. One review pack covers the 20 cells: `dev/scripts/review_pack.sh` rendered with `review_pack_render.sh`, as #3595 did
   (RV1). It is looked at and not committed (EODHD terms).
4. `results-analyst` reads the PR and the pack, applies the combined decision, and writes the why.
5. `qc-results` reviews the PR (`dev/rules/model-routing.md`).

## Results

**NO-BUILD.** C1 reads **INCONCLUSIVE** and C2 reads **FAIL**. By §The combined decision, a FAIL in either cell is
NO-BUILD. `Price_band_seeded` stays a default-off axis and no default changes. No further confirmation cells run on
it without a new mechanism argument.

- **The order binds in both cells.** It changes the post-cut list on 62.3 % (C1) and 58.3 % (C2) of Friday-pairs. The
  ≥ $33 signature is 82.2 and 74.5 pp. Liveness is not why the cells fall short.
- **C2 fails its return bar.** On the top-1000 schedule over the full window, P ends below S in 4 of 5 seeds. The
  median Δ ln(1+R) is −0.280.
- **C1 misses every bar after liveness.**
  - Return: the median Δ on 2013–2026 top-3000 is +0.139, against δ = 0.20, with 3 of 5 seeds positive.
  - Drawdown: the arm-median drawdown is 3.83 pp deeper.
  - Concentration: the gap survives the trim in 1 seed of 5.
- **Attribution, as the rule fixes it.** The 26-year gap belongs to what C2 removed: top-3000 breadth. §Why shows
  what that means in trades:
  - the gap lived in a few cheap names below the top 1,000 by dollar volume, most of them entered in 2010–12;
  - C1 is #3595's own 2013–2026 half, replayed.

**Paths.**
- **Per-arm artifacts.** `results/k{0..4}/pbc{1,2}-{S,P}-kK-s0-*`, and each seed's chain log `results/kK/chain-kK.log`.
- **The reads.** `results/read/{decide,report,capacity,cash}-{1,2}.txt`, from `read/*.sh`, run on the host as step 2
  prescribes. A fresh regeneration of the list-band and position tables reproduces all eight files byte for byte.
- **Figures marked †.** They come from `results/read/analyst_checks.sh`, whose output is
  `results/read/analyst_checks.txt`; section letters are in brackets.
  - It reads the committed artifacts of this directory and of #3595, and the committed pit-v12 lists.
  - It reads the local bar store through `read/positions.sh` and `read/list_bands.sh`.
  - It prints counts, NAV shares, bands, ranks, dates and relative moves, never a close.

### Validity and provenance (§0)

- **One build, one image, one data stage.**
  - All five chain logs carry `HEAD=04ca2ff0b` and image `sha256:3865e48e8a61`. The sessions launched at 03:41–03:42Z
    on 2026-11-14.
  - Each pulled warehouse `v12wk-9236`, corporate actions `corpact-2026-10-27` and bars `data-20261102`, and removed no
    corporate-action file.
  - Each logged `STAGE OK: warehouse 9236 entries, TD 11880 dividends.csv, 11888 data.csv`.
- **Specs and preflight.** All five sessions logged `SPEC CHECKS OK`. All 20 specs logged `PREFLIGHT_OK`:
  - the override is in P's `params.sexp` only;
  - `n_symbols=9200` (C1) or `3492` (C2), with `absent=1`;
  - the macro trend and breadth state equal `pb-S-k0`'s on 12 of 12 Fridays.
- **Restarts.** Two containers restarted. Each restart re-ran the launch command and logged the same `HEAD=` and
  image. It re-staged and rebuilt, passed the spec checks, and skipped the preflight and every cell with a `RESULT`
  line. It then re-ran the one cell it had lost.
  - **k1 restarted once,** at 06:59:31Z, while pbc2-P-k1 ran; C1 and pbc2-S-k1 had finished. pbc2-P-k1 re-ran from
    07:02:31 to 08:05:45Z.
  - **k4 restarted twice.** At 04:57:21Z it lost pbc1-S-k4, which re-ran 04:59:55–06:07:04Z. At 06:56:53Z it lost
    pbc1-P-k4, which re-ran 07:00:14–08:09:14Z.
  - Each of the 20 cell logs holds one result and one snapshot-cache line.
- **Cells.**
  - Walls were 2,904–4,104 s (C1) and 2,930–4,264 s (C2). The guard was 14,400 s; the projections were 3,770–4,250 s
    and 3,940–4,430 s.
  - Peak RSS was about 5.3 GB (C1) and 2.8 GB (C2).
- **V6.** `validator_diff -check V6` of P-kK against S-kK exits 0 ("agree") for all ten pairs
  (`pbcC-P-kK-s0.v6diff-S.log`). Every cache line reads `n_symbols_absent=1`. All five seeds of both cells enter the
  read.
- **The rest of the validator.**
  - The audit join is 100 % in all 20 cells, and V12, V19 and V20 pass.
  - V7, V13 and V17 read the validator's data dir, whose committed short bar files shadow the store (§Defects 2).
  - V16 flags one fallback exit in both arms of C2 k0, k1, k2 and k4: MAY 2005-03-02, `stale_force_exit`.
  - None of these differs between the arms of a pair.

### The rule, as written

`decide.sh` was not taken on trust:
- Δk, the medians, m_S and the drawdown medians were re-derived from `actual.sexp`.
- B was re-derived from `entries.tsv` alone.
- G and both trims were re-derived from freshly regenerated tables, with separate code.

All agree to the printed digit.

| clause | bar | C1: 2013–2026, top-3000 | C2: 2000–2026, top-1000 |
|---|---|---|---|
| valid seeds | ≥ 4 | 5 | 5 |
| Friday-pairs | ≥ 100 | 1,250 | 2,279 |
| B, lists changed | ≥ 33 % | 62.3 % (58.5–64.5 by seed) | 58.3 % (55.8–59.9) |
| G, ≥ $33 gap | ≥ 40 pp | 82.2 pp (87.9 − 5.6 %) | 74.5 pp (92.6 − 18.1 %) |
| **liveness** | | **LIVE** | **LIVE** |
| Δk, k0..k4 | | +0.171, −0.044, +0.208, +0.139, −0.166 | −0.424, +0.199, −0.049, −0.280, −0.293 |
| median Δk against δ = max(0.20, m_S) | ≥ δ | +0.139 against 0.200 (m_S 0.170) | −0.280 against 0.324 (m_S 0.324) |
| seeds with Δk > 0 | ≥ 4 | 3 | 1 |
| **return** | | **short** | **FAIL** |
| max DD, arm medians | ≤ +3.0 pp | P 29.77 − S 25.94 = **+3.83** | P 28.17 − S 26.66 = +1.51 |
| trim-3 net > 0, by seed | ≥ 4 | **1** (−7.0, −5.8, +23.0, −5.2, −16.6) | **2** (−15.6, +19.2, +4.8, −33.3, −34.6) |
| **cell outcome** | | **INCONCLUSIVE** | **FAIL** |

Source: `results/read/decide-{1,2}.txt`. The paired drawdown medians, +1.28 pp (C1) and +2.62 pp (C2), are printed
and not read.

- **C1: which bars failed, and by how much.**
  - **Return is short, not a fail.** The median Δk, +0.139, is 0.061 under δ; m_S, 0.170, is under the 0.20 floor.
    Three seeds are positive, one short of 4. A fail needs a median ≤ 0, or 2 seeds or fewer.
  - **Drawdown is 0.83 pp over.** The arm medians differ by +3.83 pp, against the 3.0 pp bar.
  - **Concentration is three seeds short.** The trimmed net is positive in 1 seed of 5, against the 4 required.
- **C2: the return fails on both counts.** The median Δk is −0.280 (≤ 0), and only 1 seed is positive (≤ 2). Its δ is
  the cell's own m_S, 0.324. The drawdown is inside the bar (+1.51 pp). The concentration also misses (2 of 5). FAIL
  decides.
- **Combined.** C2 FAIL gives **NO-BUILD**, whatever C1 reads.
- **#3597.** Its Rule 1 returned CLOSE-AXIS (#3602). This read is not ESCALATE, so the clash clause of §How this read
  combines with #3597 does not fire. Both reads keep the axis default-off.

### Reported regardless of the verdict

**Per seed and arm.** Source: `results/read/report-{1,2}.txt` §A. "Closed" counts positions; C2 S-k0 has 652 trade
rows because CERN-wein-739 is booked twice (§Defects 1). "≥ +100 %" counts closed positions.

| cell | seed | arm | R | ln(1+R) | Δk | max DD | Sharpe | Ulcer | closed | open | ≥ +100 % |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| C1 | k0 | S | +278.6 % | 1.3313 | | 25.94 | 0.585 | 10.60 | 340 | 5 | 5 |
| C1 | k0 | P | +349.4 % | 1.5027 | +0.171 | 29.77 | 0.635 | 12.64 | 334 | 5 | 6 |
| C1 | k1 | S | +337.0 % | 1.4747 | | 26.30 | 0.640 | 11.62 | 331 | 5 | 6 |
| C1 | k1 | P | +318.0 % | 1.4303 | −0.044 | 25.19 | 0.612 | 11.65 | 330 | 5 | 6 |
| C1 | k2 | S | +258.8 % | 1.2775 | | 32.07 | 0.560 | 13.56 | 340 | 6 | 6 |
| C1 | k2 | P | +341.7 % | 1.4854 | +0.208 | 31.48 | 0.647 | 13.98 | 325 | 5 | 6 |
| C1 | k3 | S | +258.6 % | 1.2771 | | 25.68 | 0.566 | 11.12 | 330 | 5 | 5 |
| C1 | k3 | P | +312.0 % | 1.4160 | +0.139 | 31.20 | 0.600 | 13.89 | 333 | 5 | 6 |
| C1 | k4 | S | +362.0 % | 1.5304 | | 25.10 | 0.657 | 11.12 | 328 | 5 | 6 |
| C1 | k4 | P | +291.2 % | 1.3640 | −0.166 | 26.39 | 0.580 | 12.29 | 341 | 4 | 6 |
| C2 | k0 | S | +1,544.2 % | 2.7999 | | 25.41 | 0.659 | 11.01 | 651 | 7 | 11 |
| C2 | k0 | P | +975.6 % | 2.3755 | −0.424 | 28.17 | 0.562 | 11.86 | 644 | 7 | 8 |
| C2 | k1 | S | +759.3 % | 2.1510 | | 30.50 | 0.514 | 12.47 | 664 | 7 | 8 |
| C2 | k1 | P | +948.3 % | 2.3498 | +0.199 | 33.12 | 0.558 | 12.62 | 649 | 6 | 8 |
| C2 | k2 | S | +1,448.0 % | 2.7395 | | 26.66 | 0.654 | 10.81 | 648 | 6 | 10 |
| C2 | k2 | P | +1,373.5 % | 2.6902 | −0.049 | 27.85 | 0.627 | 10.74 | 644 | 7 | 9 |
| C2 | k3 | S | +978.6 % | 2.3782 | | 30.54 | 0.586 | 11.54 | 640 | 6 | 8 |
| C2 | k3 | P | +714.9 % | 2.0979 | −0.280 | 25.78 | 0.500 | 10.61 | 652 | 5 | 7 |
| C2 | k4 | S | +1,087.4 % | 2.4744 | | 25.79 | 0.604 | 10.71 | 636 | 5 | 9 |
| C2 | k4 | P | +785.6 % | 2.1811 | −0.293 | 33.97 | 0.513 | 13.37 | 655 | 6 | 10 |

- **Scale.** The paired median is +0.139 log over 13.5 years in C1, about +1.0 % a year. In C2 it is −0.280 over
  26.5 years, about −1.1 % a year. #3595's was +0.348 over 26.5 years, about +1.3 % a year.
- **Spread† [A].**
  - In C1, S's seed SD of ln(1+R) is 0.117 and P's is 0.056. P is above S in 17 of the 25 cross-seed pairs.
  - In C2, S's SD is 0.267 and P's 0.228. P is above S in 6 of 25.
  - In #3595, P was above S in 25 of 25.
- **Risk-adjusted.**
  - In C1, P's Sharpe is higher in 3 of 5 seeds and its Ulcer index higher in 5 of 5. P's max drawdown is deeper in
    3 of 5.
  - In C2, P's Sharpe is higher in 1 of 5 seeds and its Ulcer index higher in 3 of 5. P's max drawdown is deeper in
    4 of 5.

**Entries by band, pooled over seeds.** Source: `report-{1,2}.txt` §A, split-restatement corrected.

| cell | arm | entries | < $8 | $8–14 | $14–33 | ≥ $33 | closed ≥ +100 % |
|---|---|---:|---:|---:|---:|---:|---:|
| C1 | S | 1,695 | 4.3 % | 7.7 % | 20.3 % | 67.7 % | 28 |
| C1 | P | 1,687 | 4.7 % | 8.8 % | 25.5 % | 60.9 % | 30 |
| C2 | S | 3,270 | 1.0 % | 3.0 % | 13.0 % | 83.0 % | 46 |
| C2 | P | 3,275 | 1.2 % | 3.5 % | 18.3 % | 77.0 % | 42 |

**One-arm net by band.** It is P-only minus S-only, in points of entry NAV, pooled; counts are P-only / S-only
positions. Source: §B. #3595's corrected column is from this README's §Reported regardless.

| band | C1 | C2 | #3595 (26 y, top-3000) |
|---|---:|---:|---:|
| < $8 | +64.8 (19 / 12) | −10.1 (13 / 5) | +154.3 |
| $8–14 | −14.1 (39 / 21) | −27.2 (32 / 16) | +16.1 |
| $14–33 | +28.6 (135 / 48) | +105.6 (242 / 69) | +106.5 |
| ≥ $33 | −43.9 (124 / 244) | −177.6 (369 / 561) | −69.5 |
| total | +35.4 | −109.4 | +207.5 |

C1's < $8 row is ADMA: +28.6 in each of k0 and k3.

**One-arm net by entry era.** Source: §B, and `read/repro-3595.txt` for #3595.

| era | C1 | C2 | #3595 |
|---|---:|---:|---:|
| 2000–09 | | −81.1 | +18.5 |
| 2010–12 | | +28.5 | +147.0 |
| 2013–17 | +11.7 | −93.1 | +34.3 |
| 2018–23 | +32.7, of which ADMA +57.2 | +26.5 | +16.7 |
| 2024–26 | −9.0 | +9.9 | −9.0 |

C1's 2024–26 row is #3595's to the digit (P-only 71 / −2.0, S-only 87 / +7.0); §Why 2 explains why.

**Liveness by seed.** Source: `decide-{1,2}.txt`.
- **C1.** B is 58.5–64.5 % and G 78.4–85.0 pp. P's tickets that S did not place that Friday are 13.9–20.6 % (pooled
  18.5 %).
- **C2.** B is 55.8–59.9 %, G 72.6–78.1 pp, and the re-drawn share 17.2–22.7 % (pooled 20.0 %).
- **#3595.** The re-drawn share was 21.5 %.

**The 2013–2026 increment.** Source: `report-{1,2}.txt` §C.
- **For C1 it is the whole cell:** +0.171, −0.044, +0.208, +0.139, −0.166.
- **For C2 it is −0.337, +0.010, +0.008, −0.029 and −0.041** (median −0.029). The full-window Δk beside it is −0.424,
  +0.199, −0.049, −0.280 and −0.293. By end-2012, C2's gap already stood at −0.088, +0.189, −0.057, −0.252 and −0.253.

**The largest one-arm contributors.** The five largest per seed and side, with split-restated prices marked, are in
`report-{1,2}.txt` §D. The three largest, as % of entry NAV:

| cell | seed | Δk | net → trim 3 | P-only | S-only |
|---|---|---:|---:|---|---|
| C1 | k0 | +0.171 | +22.5 → −7.0 | ADMA 2023-12-19 $4.35 +300 % 28.6; SAGE 2017-12-04 8.0; ADNT 2020-11-09 6.6 | CVNA 2024-07-08 7.7; MIME 2021-06-25 3.1; ATI 2024-04-23 2.9 |
| C1 | k1 | −0.044 | −6.2 → −5.8 | IPHI 2015-01-06 6.4; SGEN 2019-10-14 5.6; CDNS 2020-05-06 5.5 | WSM 2020-09-28 6.9; SKX 2014-03-10 5.7; CHDN 2017-03-28 5.4 |
| C1 | k2 | +0.208 | +19.3 → +23.0 | AMED 2014-10-02 5.4; HPQ 2020-11-24 2.8; LPG 2023-09-15 2.8 | WSM 6.9; FCNCA 2020-11-16 4.7; WDFC 2013-07-22 3.0 |
| C1 | k3 | +0.139 | +18.1 → −5.2 | ADMA 28.6; SAGE 8.0; IPHI 6.4 | GLNG 2022-02-07 9.7; AMED 5.3; FCNCA 4.8 |
| C1 | k4 | −0.166 | −18.3 → −16.6 | SGEN 5.6; GTIV 2014-06-09 4.4; LPG 2.7 | IPHI 6.4; FCNCA 4.8; TWLO 2026-04-30 3.2 |
| C2 | k0 | −0.424 | −55.9 → −15.6 | NIO 2020-09-24 $16.85 +119 % 13.1; BWA 2010-02-03 6.9; HRB 2012-10-22 6.6 | TSLA 2013-04-09 $41.00 +230 % 32.7; SWKS 2014-05-20 17.8; ANET 2016-11-14 16.3 |
| C2 | k1 | +0.199 | +17.5 → +19.2 | NIO 13.1; X 2005-12-19 4.8; HLF 2010-08-30 3.8 | AVGO 2013-09-10 $39.39 +200 % 15.3; ESLRQ 2005-10-19 4.8; ORCL 2024-08-05 3.3 |
| C2 | k2 | −0.049 | −3.0 → +4.8 | NIO 13.1; HRB 6.5; EOG 2000-05-01 4.4 | AVGO 15.9; SK 2010-06-01 8.3; SBUX 2011-08-08 7.8 |
| C2 | k3 | −0.280 | −37.3 → −33.3 | BWA 6.9; MAA 2021-03-15 5.9; SQM 2022-04-25 4.8 | TIBX 2010-07-12 $12.74 +112 % 10.2; HRB 6.6; ESLRQ 4.8 |
| C2 | k4 | −0.293 | −30.7 → −34.6 | IREN 2025-07-15 $16.32 +175 % 17.5; NIO 13.1; SK 8.3 | AVGO 15.8; TIBX 10.1; NVO 2010-01-26 9.1 |

**Capacity.** Source: `capacity-{1,2}.txt`. For entries at or below $14: position value ÷ the 20-day mean dollar
volume.

| cell | arm | n | p50 | p90 | max | ≥ 0.25 | from 2023-07-01: n / p50 / p90 / max |
|---|---|---:|---:|---:|---|---:|---|
| C1 | P | 229 | 0.007 | 0.041 | 0.181 (TRTX 2021-08-17 k4) | 0 | 70 / 0.019 / 0.052 / 0.084 |
| C1 | S | 204 | 0.006 | 0.043 | 0.197 (TRTX 2021-08-17 k4) | 0 | 65 / 0.017 / 0.056 / 0.087 |
| C2 | P | 155 | 0.006 | 0.019 | 0.068 (ELGX 2011-06-23 k4) | 0 | 30 / 0.009 / 0.047 / 0.064 |
| C2 | S | 131 | 0.007 | 0.026 | 0.088 (SIRI 2023-07-24 k0) | 0 | 31 / 0.009 / 0.059 / 0.088 |

- The late subset's ≥ 0.25 count is not printed by `capacity.sh`. It is 0, because every late maximum is under 0.25.
- These ratios are far below #3595's (P: p50 0.038, p90 0.194, maximum 0.949, 18 entries at ≥ 0.25).
- Neither cell tests capacity at #3595's late-run NAV:
  - C1 starts at $1M in 2013. On 2023-07-03 its P book is 4.5–6.2× smaller than #3595's at the same seed† [K].
  - C2's cheap names are top-1000 names, and so more liquid.

**Cash displacement, both ways.** Source: `cash-{1,2}.txt`. The net is P's tickets that S skipped for cash, minus S's
tickets that P skipped for cash, in points of entry NAV, by seed:
- C1: −14.0, +9.7, +4.6, −3.4, +2.6.
- C2: −24.1, +11.2, −19.7, −11.3, +4.9.

This counts skips at the decision only. A fill the portfolio rejects for cash is not in it, and such rejections are
routine in both arms: 15–30 per C1 cell and 60–79 per C2 cell† [J]. AVGO 2013 in C2 is one (§Why 6).

### The verdict, calibrated

- **What this run establishes.**
  - The band order binds outside the 26-year top-3000 cell, at about the same rate and with the same fingerprint:
    both in the post-2012 window and on the top-1000 tier.
  - On the top-1000 tier over 2000–2026 it does not reproduce #3595's gap. The paired median is −0.280, and S ends above
    P in 19 of the 25 cross-seed pairs† [A].
  - On top-3000 without the 2010–12 entries, it reproduces only #3595's own 2013–2026 increment (§Why 2).
  - So the 26-year gap is not a general property of the order. By the rule this is NO-BUILD: the axis stays
    default-off, and no further confirmation cells run on it without a new mechanism argument.
- **What it does not establish.**
  - **That the order hurts on the top-1000 tier.** C2's median gap lies inside its own reshuffle null (m_S 0.324).
    The mean paired gap, −0.170, is about 0.6 of S's seed SD (0.267)† [A]. The FAIL says the confirmation did not
    happen, not that the order loses in expectation.
  - **That C1 is fresh evidence on 2013–2026.** Same-seed C1 paths re-synchronise with #3595's (§Why 2). Eight of the
    ten arm-seeds hold #3595's positions from 2019 on, and all ten from 2023. C1's own information is mostly its
    2013–2018 re-path.
  - **That the mechanism does not work** (`dev/rules/mechanism-validation-rigor.md` §Verdict calibration).
    - These are two K = 5 seed reads, not a walk-forward surface.
    - The order's expected effect is below what either cell can resolve. #3597 measured it at about one doubler per
      26 years at top-3000.
    - The read rejects prioritising the axis further, not the mechanism.
  - **Anything out of sample.** Both windows lie inside the history on which the screen chose the trait (§Not
    claimed).
- **How strong the NO-BUILD is.** The deciding cell is one breadth tier on one history. That is enough for NO-BUILD,
  because the rule asks the gap to transfer and it does not. It is not enough to call the order harmful.

### Why

#### 1. The order binds everywhere; what it binds on changes with breadth

- **Liveness held, with margin.** B is 62.3 % and 58.3 %, against the 33 % bar and near #3595's 66.8 %. G is 82.2 and
  74.5 pp, against 40. The README expected the narrower universe to bind less by construction; it binds almost as
  often. B includes path effects; #3597's path-free L1 was 0.690, on S-k0 at 26 years.
- **The band proxy holds.** The decision-date band equals the fill band on 97.9 % (C1) and 98.1 % (C2) of filled
  tickets† [G].
- **On the top-1000 tier the cheap end thins out** [G]†. The table shows the band mix of all slots in S's lists, and
  of the names P lists that S does not:

  | band | C1 S lists | C2 S lists | C1 names P adds | C2 names P adds |
  |---|---:|---:|---:|---:|
  | < $8 | 5.5 % | 1.2 % | 15.4 % | 3.5 % |
  | $8–14 | 7.4 % | 2.8 % | 26.9 % | 10.7 % |
  | $14–33 | 25.4 % | 15.7 % | 52.1 % | 67.7 % |
  | ≥ $33 | 61.7 % | 80.3 % | 5.6 % | 18.1 % |

  - The names P adds are under $14 42 % of the time in C1, and 40 % in #3595 (§Why 1 there). In C2 they are under $14
    14 % of the time. On the top-1000 tier the order mostly swaps $14–33 names for ≥ $33 ones.
  - **The off-signature swaps are path.** Of the 470 names priced ≥ $33 that P lists in C2 and S does not, S held 146
    that Friday† [G]. A held name leaves its own arm's pool. In a universe that is 80 % ≥ $33, swaps driven by the path
    are mostly ≥ $33 names, so 18 % of P's additions are ≥ $33 here, against 6 % in C1.
- **Why the mix matters.** #3597's funded re-draw put +1.10 of its 0.953 expected doublers in the bands under $14. The
  exchange of $14–33 names for ≥ $33 ones netted −0.14, because at the strategy's rates those bands convert alike. A
  tier on which a seventh of the promoted names are cheap leaves the order little expected tail to buy.

#### 2. C1 is #3595's 2013–2026 half, replayed

- **The same paths.** C1 starts all-cash on 2013-01-01, but its paths lock onto the 26-year cells' at the same seed and
  arm† [C1].
  - Its positions (symbol and entry date, open ones included) equal #3595's from 2015 (P-k1); from 2016 (P-k3, S-k4,
    P-k4); from 2019 (S-k0, P-k0, S-k2, S-k3); from 2022 (P-k2); and from 2023 (S-k1).
  - The year-on-year change in ln(NAV_P / NAV_S) is the same to three decimals in every seed from 2023, and in four
    seeds from 2022† [C2].
- **Why they lock.**
  - The lists, the bars, the cascade score and P's cross-band order are functions of the date. So is S's seeded draw,
    which hashes `seed|date|ticker` (`screener_ranking.ml` `_seed_key`, `_seeded_cmp`).
  - Sizes are fractions of NAV.
  - Once the positions each run carried in have closed and the cash fractions match, the two runs make the same
    decisions.
- **So C1 measured #3595's own increment.**
  - C1's Δk per seed is +0.171, −0.044, +0.208, +0.139, −0.166. #3595's 2013–2026 increment is +0.290, −0.061, +0.190,
    +0.151, −0.155 (`read/repro-3595.txt` §C). The signs agree in 5 of 5 seeds, and the medians are +0.139 against
    +0.151.
  - §Decision rule 2 ("Expectation, written now") predicted this outcome.
- **What carries C1's lean.**
  - **ADMA, a tie-cut lottery, in k0 and k3.** It is the only one-arm doubler in C1 (+300 %, 28.6 % of entry NAV each)†
    [D], in the same two seeds as in #3595. P holds it in five seeds and S in three† [N]. Without it, C1's pooled
    one-arm net falls from +35.4 to about −21.8, about −4.4 a seed.
  - **SAGE, a cash lottery, in the same two seeds.** It entered 2017-12-04, is priced ≥ $33, and made +55.8 % (8.0 %
    of entry NAV).
    - P-k0 and P-k3 placed it on 2017-12-01. S skipped it for `Insufficient_cash` in k1–k4, and P did in k1, k2 and
      k4. S-k0 recorded no list that Friday† [L].
    - A ≥ $33 name in both arms, so not a band swap.
  - **k2 is the only seed whose gap survives the trim (+23.0).** It is built of many small differences in the
    re-pathed years: its year-end gap rose +0.134 in 2014 and +0.063 in 2017 (`report-1.txt` §C).
    - The largest piece is AMED, P-only here but S-only in k1 and k3.
    - #3595's k2 gained about as much over 2013–2017 on a different path: +0.234 against C1's +0.239† [C2].
- **The drawdown miss is #3595's episode.**
  - P-k0 and P-k3 peak on 2018-01-26 and trough on 2020-03-25. Their S arms peak in mid-June 2018† [B].
  - #3595's P-k0 and P-k3 have the same dates, and P-k3 the same depth, 31.20 %.
  - Into that peak, P held SAGE and NOAH (2017-07-05, +57.7 %), the only one-arm positions it carried across it† [M].
  - The miss is k0's +3.83 pp; k3's gap is +5.52 pp.

#### 3. C2: the cut swaps net to about zero, and the draw went to S

- **By channel.** This splits the gap by what the other arm did with each placed ticket, using `cash.sh`'s classes:
  P's tickets minus S's tickets, in points of entry NAV† [H].

  | the other arm … | C1 | C2 |
  |---|---:|---:|
  | listed the name not at all (the cut, or held) | +46.4 | +1.0 |
  | skipped it for cash at the decision | −0.4 | −39.0 |
  | placed it too (the fills can still differ) | +11.7 | −37.5 |
  | recorded no list that Friday | −23.3 | −32.0 |
  | found no structural stop | −1.8 | |
  | total, P minus S over all positions | +32.6 | −107.6 |

  - In C1, the cut channel is ADMA: +27.8 in k0 and +30.3 in k3.
  - In C2, where the other arm's list is visible, the order's own swaps net +1.0. The loss sits in the cash channels
    (−76.5) and the unresolved one (−32.0).
- **The systematic swaps are P's; the large one-off draws are S's** [E]†. Position keys are grouped by how many P seeds
  hold them minus how many S seeds:
  - **P in at least 3 more seeds:** 62 keys, net +98.6. NIO 2020-09-24 leads (+52.5; $14–33; P in 4 seeds, S in
    none), then BWA 2010-02-03 (+20.7) and BBWI 2010-02-16 (+13.1).
  - **S in at least 3 more seeds:** 29 keys, net −74.4. AVGO 2013-09-10 leads (−48.1).
  - **One or two seeds apart:** 600 keys, net −135.8. This is where S's ≥ $33 monsters sit: TSLA 2013-04-09 (−32.7),
    NVO 2010-01-26 (−18.2), CVH 2003-05-05 (−18.1), SWKS 2014-05-20 (−17.9), ANET 2016-11-14 (−16.3) and RH 2020-10-30
    (−14.2). TIBX 2010-07-12 (−20.3) is a cheap name S caught on its own path.
- **Tail access.** Closed one-arm positions at ≥ +100 %, P minus S, by seed† [D]:

  | | k0 | k1 | k2 | k3 | k4 |
  |---|---:|---:|---:|---:|---:|
  | #3595 (26 y, top-3000) | +2 | +3 | +2 | +2 | +2 |
  | C1 (2013–26, top-3000) | +1 | 0 | 0 | +1 | 0 |
  | C2 (26 y, top-1000) | −3 | 0 | −1 | −1 | +1 |

  - In C2, P's one-arm doublers are NIO (four seeds), and IREN and SK (k4).
  - S's are TSLA, SWKS, ANET and CERN (k0), AVGO (k1, k2, k4), SK (k2) and TIBX (k3, k4).
  - CERN's +138 % is a phantom (§Defects 1). Without it, k0 reads −2.
- **The distributions.** One-arm positions' P&L %, with open positions marked† [I]:

  | | n | mean | p10 | median | p90 | win | ≥ +50 % | ≥ +100 % |
  |---|---:|---:|---:|---:|---:|---:|---:|---:|
  | C1 P-only | 317 | +2.9 | −13.1 | −3.8 | +23.7 | 38.8 % | 2.8 % | 0.6 % |
  | C1 S-only | 325 | +1.8 | −12.8 | −2.8 | +19.7 | 41.5 % | 2.5 % | 0.0 % |
  | C2 P-only | 656 | +1.9 | −11.8 | −2.6 | +18.6 | 39.8 % | 2.0 % | 0.9 % |
  | C2 S-only | 651 | +4.0 | −11.3 | −2.3 | +18.7 | 39.9 % | 3.5 % | 1.5 % |
  | #3595 P-only | 618 | +6.1 | −12.9 | −3.8 | +33.1 | 39.6 % | 6.5 % | 2.3 % |
  | #3595 S-only | 704 | +2.5 | −12.2 | −2.7 | +19.7 | 43.0 % | 2.7 % | 0.4 % |

  P's one-arm book never wins more often than S's. Only on 26-year top-3000 did it buy the fatter right tail that
  pays for that. In C2 the right tail is S's.
- **Per seed, C2.**
  - k0: three ≥ $33 monsters in S. The CERN phantom also flatters S here.
  - k1: NIO, against AVGO lost to cash at the fill.
  - k2: NIO, against AVGO lost to cash at the decision.
  - k3: a broad loss built in 2004–06 and 2011 (`report-2.txt` §C).
  - k4: AVGO lost to cash at the fill.

#### 4. Where #3595's gap lived: below the top 1,000

- **By dollar-volume rank.** Each of #3595's positions is ranked in the top-3000 list in force at its entry† [F].
  - Names ranked below 1,000 carry +197.3 of its +204.5 pooled points (P minus S over all positions). Names in the top
    1,000 net +7.2.
  - By seed, outside the top 1,000: +65.5, +19.2, +47.1, +29.8 and +35.7. Inside: +4.2, +6.2, −1.8, +13.3 and −14.7.
- **Perturbed** (`feedback_perturb_before_believing_a_cohort_split`).
  - At every cut from 500 to 2,000 the part outside is positive in all five seeds; at 1,500, k1's is barely so,
    +0.2.
  - The part inside stays between −35.4 and +73.8, pooled.
  - Within the lower 2,000 the profile is not smooth. Ranks 1,501–2,000 net −50.6, and ranks 2,001–2,500 net +142.0.
    That is a few names, not a gradient.
- **The deciding names** [F2, N]†.
  - On their decision dates, MERC, WAL, DINO, REGN and ADMA were in the top-3000 list in force and not in the
    top-1000 list. None of them is held in any C2 cell.
  - ATML was in both lists. C2 holds it in both arms of all five seeds.

#### 5. Breadth, the 2010–12 cluster, or a shared draw?

All three, because they describe the same few events.

- **Breadth.** The names that made the gap sat below the top 1,000. C2 removed them, and on what was left the order
  lost (median −0.280).
- **The 2010–12 cluster.** Five of them entered in 2010–12. C1 removed those entries and kept the breadth. It returned
  #3595's own 2013–2026 increment (+0.139 against +0.151).
- **A shared draw.**
  - Each seed replicates the same swaps. P's cross-band order is the same at every seed.
  - S's draw at a given date is the same in every window.
  - That is why C1 caught ADMA and SAGE in exactly #3595's seeds.
- **Against #3597's expectation.**
  - #3597 found that the order re-draws about 84 funded tickets in 26 years. That is worth about one net doubler
    (E_net 0.953, about 0.10–0.18 log).
  - #3595's seeds realised +2 to +3 doublers each (§3).
  - C1's 13.5 years hold about half of that expectation, since the re-draws split about evenly between the halves
    (#3597 §What it implies next). C1 realised +0.4 a seed, all of it ADMA.
  - C2's promoted names are cheap a third as often, so its expectation is smaller still. It realised −0.8 a seed
    (−0.6 without CERN).
  - In no cell is the expected effect within reach of a K = 5 read (δ is 0.20 and 0.32).
  - What #3595's five seeds saw was one draw of a few cheap names, replicated five times.

#### 6. Four decisions, end to end

- **ADMA, 2023-08-18 (C1; the cut)** [L]†.
  - S-k0's and S-k3's 20-name lists hold PKG and R placed; ADMA is not in them.
  - P's lists in k0 and k3 hold ADMA placed. To make room, they drop SUN (k0) and DINO (k3), both ≥ $33.
  - In k1, S's own seeded draw admits ADMA.
  - The ticket filled 2023-12-19 at $4.35 and exited 2024-12-23 at +300 %, 28.6 % of entry NAV.
  - The year-end gap rose +0.204 (k0) and +0.181 (k3) in 2024, in C1 exactly as in #3595† [C2].
- **NIO, 2020-09-18 (C2; the cut)** [L]†.
  - S-k0's list has KKR placed and no NIO. P-k0's list has NIO placed.
  - P drops KKR, DKNG, DOW and PENN (all ≥ $33) and VICI ($14–33).
  - P adds NIO and AMH ($14–33), HBAN and PBR-A ($8–14), and PINS (≥ $33).
  - NIO filled 2020-09-24 at $16.85 and exited 2021-03-08 at +119.4 %, 13.1 % of entry NAV.
  - P held it in k0, k1, k2 and k4; S held it in no seed† [N]. This is the order working as designed.
- **AVGO, 2013-08-30 (C2; cash at the fill)** [L]†.
  - Both arms placed AVGO in k1 and k4, and the buy stop triggered in both on 2013-09-10.
  - S filled: 6,211 shares in k1 and 9,083 in k4.
  - P's fill was rejected. In k1, $288,394 was required and $37,735 available, after P had filled NVS that day and a
    larger HLF on 09-03 (9,085 shares against S's 7,647). In k4, $289,497 was required and $213,713 available, after
    P filled HLF on 09-03 (`pbc2-P-kK-s0.log`; `trades.csv`).
  - AVGO made +199.8 %, about 15–16 % of entry NAV.
  - In #3595 the same ticket fell the other way: P held it in k1 and k2, where S had skipped it for cash. The name is
    ≥ $33 in both arms; the cash path decides.
- **TSLA, 2013-04-05 (C2; unresolved)** [L]†.
  - S-k0 placed it from a 20-name list with 17 names at ≥ $33. It filled 2013-04-09 at $41.00 and exited 2013-11-18
    at +229.9 %, 32.7 % of entry NAV. That is the largest one-arm position in either cell.
  - P-k0 recorded no list that Friday, so the artifacts cannot say whether its order cut TSLA or its cash was short.
  - On the same Friday at k2, P's order did cut two ≥ $33 names, GIS and TM, for CNP and POM_old ($14–33). It kept
    TSLA, which both k2 arms then held.
  - Tickets placed a week later, on 2013-04-12, in seven C2 cells never filled. The committed artifacts do not say
    why (no `trade_audit.sexp`).

### How it fits what we know

- **Confirms #3597** (`project_trait_y_low_price`; ledger `2026-11-14-price-band-binding`). The order binds routinely
  and buys about one doubler per 26 years in expectation, so a traced gap is still a draw. The confirmation cells show
  that the draw does not recur outside its breadth and era.
- **Confirms #3595's era decomposition.** About 70 % of the gap came from 2010–12 entries. Without them, what is left
  is the 2013–2026 increment #3595 already reported.
- **Confirms the gate-1 / gate-2 law** (`project_record_kseed_band`, `project_path_stability_seeded_noise`). ADMA (the
  tie cut), and SAGE and AVGO (cash), decide which tails a seed catches.
- **Refines `project_26y_path_noise_floor`.** That memory records a universe change re-drawing the path "as a few
  local steps that re-synchronise" (#3489). A start-date change does the same: a nested window on the parent's seeds
  converges on the parent's path within 2–6 years. A nested cell is a re-measurement, not a replicate.
- **Settles the contradiction #3595 flagged** with the tiebreak ledger rows (`2026-06-29-candidate-ranking-tiebreak-
  grid`, `2026-06-30-tiebreak-noise-floor`).
  - The noise-floor row found that the best arbitrary tiebreak flips by breadth cell: Symbol_length was best on
    top-500 and collapsed on top-1000.
  - The informative price order now does the same. It was above every S seed on 26-year top-3000, and is below S in
    4 of 5 seeds on top-1000.
- **Rhymes with the top-N grid** (`project_top_n_grid_lane_2026_09_22`). Cap 40 tightened on two top-3000 cells and
  was dominated on the top-1000 cell. Two slot-level levers have now looked good on top-3000 and failed on top-1000.
- **Consistent with `project_cell_e_2020_stall_regime`** ("broad universe is the lever"). What the order harvested
  lived in the broad tail.
- **Contradicts nothing on record.** One expectation in this README missed: C2 binds about as often as C1 (58.3 %
  against 62.3 %), not markedly less.

### What it implies next

These are options; the choice is the user's.

- **Stop on this axis (the rule's outcome).** Both reads now agree: #3597 is CLOSE-AXIS and this read is NO-BUILD.
  The NO-BUILD clause rules out further confirmation cells without a new mechanism argument, and the why supplies none:
  the order's expected tail is about one doubler per 26 years on top-3000, and less on top-1000.
- **The low-price trait.**
  - #3597 placed its leak at `Stage_setup` (breadth, with no lift), the top-N slot and post-cut fundability. This read
    closes the slot route on both tiers tested.
  - The remaining link is why cheap top-20 names fail the structural-stop walk. That is a read-only count on a
    `trade_audit.sexp`, and it points at a risk dial already studied.
  - "Nothing further" is the honest default.
- **A design rule for period cells.**
  - A sub-window cell on its parent's seeds is independent of the parent only until it re-synchronises, here 2–6
    years.
  - `dev/rules/promotion-confirmation.md` already asks for disjoint windows; this run shows why a nested window cannot
    substitute for one.
  - It bears on the open stale-E cap escalation and on any grid built from the K = 5 record seeds. It is worth a
    line in that rule if the user wants one.
- **Levers that act at the top-N cut.** For them a top-1000 cell is the hard test, since their top-3000 gains sit in
  the lower 2,000 names. Run that cell early.
- **Defects to file** (§Defects 1): a CERN-shaped specimen for #3109, and a test for an exit order filled on a
  split's effective date.
- **Ruled out by this read:**
  - a sweep of the band edges;
  - more seeds on these windows;
  - a pre-2000 cell on this lever without a new argument;
  - promoting `Price_band_seeded` on #3595's evidence.

### Defects found

1. **A phantom split doubles a held position: C2 S-k0, CERN 2013-07-01. This is a #3109 specimen.**
   - **The specimen** [O]†.
     - CERN-wein-739 entered 2013-01-30. It appears in `pbc2-S-k0-s0-trades.csv` as two closed rows of 5,843 shares at
       $21.15.
     - One row exits 2013-07-01 at $48.50 (+$159,821, +129.3 %). The other exits 2013-07-22 at $50.42 (+$171,039,
       +138.4 %).
     - `pbc2-S-k0-s0-splits.csv` applies a CERN factor of 2.0 on 2013-07-01.
   - **The cause.**
     - In the bar store, CERN's `close` is already on the post-split basis before 2013-07-01. It moves +1.5 % that day,
       a gap share of −0.01, while `adjusted_close` steps ×2.
     - `Split_detector.detect_split` reads the step as a 2:1 split, and `Split_handler` doubles the held quantity
       (`split_handler.ml`). The price does not halve.
     - This is #3109's class: "held positions rescaled on non-split days". The #3105 `raw_confirm_min_share` check,
       which is default-off, would reject the event.
   - **The effect.**
     - S-k0's NAV rose +$415,497 (+9.88 %) on 2013-07-01. P-k0's rose +0.68 % and S-k1's +0.42% [O].
     - The phantom is about $283k: the extra 5,843 shares at the row's $48.50 exit price. It overstates S-k0's
       ln(1+R) by about 0.06.
     - Corrected, C2's Δk for k0 is about −0.36 rather than −0.42, and δ about 0.29 rather than 0.32. The outcome does
       not move: the median stays −0.280, with 1 seed of 5 positive.
     - CERN's +138 % is not a real doubler (§Why 3).
   - **Scope.** Of the 192 splits applied to held positions in this run's 20 cells, this is the only one without a
     raw gap. #3595's cells carry one small case, IHG 2012-10-09 (factor 0.933), in both arms of k0 and k2 and in P-k3
     [O]†.
   - **A simulator-side question.**
     - The 2013-07-01 exit sold 5,843 shares, the pre-split count, and left the rescaled remainder open until 07-22.
       That is why one position became two rows.
     - Had the split been real, an exit queued before it would have left half the position open.
     - One specimen cannot show whether this is general. `split_handler.ml` rescales the `Exiting` state's
       `target_quantity`, so the pending order is the place to look. A unit test pinning an exit filled on a split's
       effective date would settle it.
   - **The read side.** `read/positions.sh` keys positions on symbol and entry date, so it keeps only the second CERN
     row (+$171,039 of the +$330,860 the two rows book).
2. **The validator's data dir shadows the store (chain-w D1, carried over).**
   - V17's specimens are committed short bar files read in place of the full store [O2]†:
     - PBR 2026-02-09 and NVS 2025-12-03, in all ten C2 cells (their `trading/test_data` files end 2025-05-16);
     - QCOM 2026-05-18, in all ten C1 cells and C2 S-k2 (its file ends 2026-04-10);
     - SNA 2026-04-23, in C2 S-k3.
   - The store runs to 2026-08-17 for all four names.
   - The same files drive most of C2's V13 (99–109 per cell, mostly "no bar on entry_date … nearest earlier bar:
     none") and its V7 (60–68).
   - This is not a simulator defect. V6 is unaffected, and the counts match within each pair. The fix is chain-w
     §5 item 5.
3. **Design: a nested window re-synchronises with its parent.**
   - §Not claimed says C1 "re-runs 2013–26 from cash and removes only the 2010–12 entries". In fact it reproduces
     #3595's positions from 2015–2023, depending on arm and seed (§Why 2), so most of its 13.5 years re-measure
     #3595's paths.
   - The rule could still be applied as written; the cell simply carried less independent evidence than the design
     assumed.
4. **The two-sided cash read misses the fill-time gate.**
   - `read/cash.sh` classifies a ticket by the other arm's decision-time skip. A fill rejected for cash leaves both
     arms in `both-placed`.
   - So AVGO 2013 in C2 k1 and k4 (−15.3 and −15.8 points; §D) shows no cash effect.
   - Rejections at the fill are routine [J]†. A future cash read should join the rejected fills in the cell logs.
5. **Carried over, unchanged (#3384).**
   - `entries.tsv` records no list on a Friday without a placement. C2's unresolved channel is −32.0, and TSLA (k0) is
     its largest item.
   - `trades.csv` restates `entry_price` across in-hold splits: `report-2.txt` §D marks TRN, CNC, PH, CLF, DVN, CVH and
     AVGO 2023. `read/positions.sh` corrects the bands.
6. **Checked, no defect.**
   - `decide.sh` is re-derived above.
   - Trimming the three largest contributions by absolute size instead of by value gives the same trimmed nets in all
     ten seeds† [P].

### Review-pack look

Two packs, one per cell, each over its ten arms with charts on P-k0. They were built with `review_pack.sh --run-kind arm
--charts-run 0 --no-container` (pack b54e44ea9, run 04ca2ff0b) and rendered with `review_pack_render.sh` (C1 21 slices,
C2 31). The dispatcher looked at them (RV1–RV3). They are not committed (per-trade charts from the bar store). One pack per
cell rather than one over all 20, because the two cells differ in window and universe and one overlay would mix them.

- **KPI strips (P-k0) match the per-arm table.**
  - C1: +349 %, maximum drawdown −29.8 %, Sharpe 0.63, 334 trades.
  - C2: +976 %, −28.2 %, 0.56, 644 trades.
  - Both arms lists match `decide-{1,2}.txt` arm by arm: C1 +349 / +279 / +318 / +337 / +342 / +259 / +312 / +259 / +291 /
    +362 %, and C2 +976 / +1,544 / +948 / +759 / +1,373 / +1,448 / +715 / +979 / +786 / +1,087 %.
- **Windows.** C1 runs 2013-01-02 → 2026-06-25 over 9,185 symbols, and C2 2000-01-03 → 2026-06-25 over 3,477.
- **C1 re-synchronisation (§Why 2), confirmed.**
  - P-k0's concentration signals are #3595's P-k0 figures. The 2021-04-13 peak falls 25.7 % to 2023-10-27, with APPS at
    30.4 % of peak NAV. The 2024-11-28 peak falls 23.8 %, with MMYT at 15.0 % and ADMA at 23.3 %.
  - The 2018-01-26 peak reads n/a for one position's open gain.
  - The arms table puts ADMA 2023-12-19 first: impact 28.6 %, held by P-k0..4 and S-k1, S-k2, S-k4, not by S-k0 or S-k3.
    SAGE 2017-12-04 is third (8.0 %, P-k0 and P-k3 only). Both match §Why 2 and [N].
- **C2 signals, confirmed or refined.**
  - The 2021-02-16 peak falls 28.2 % to 2023-10-26, with NIO at 16.5 % of peak NAV. NIO is the order's swap (§Why 6).
  - The 2025-11-05 peak falls 20.3 %, with IREN at 28.0 %. That is not a swap: both arms of k0–k3 hold IREN, and only k4
    holds it in P alone, as §Why 3 has it.
- **Not flagged: C2 S-k0's 2013-07-01 step (§Defects 1).** The pack charts P-k0 only. S-k0's NAV series shows the +9.9 %
  day (4,205,296 → 4,620,793), and no signal names it. This is a detector candidate for the pack (RV3): a one-day NAV
  move that the held positions' price moves do not explain.
- **Era bullets.**
  - C1 ends at 0.71× SPY over 2013–2026 (SPY +533 %). It eroded in 2018–19, 2021 and 2025–26, with holdings lagging while
    the market rose, not an exposure effect.
  - C2 ends at 1.33× SPY. It built 2000–08 and 2010–15 and eroded 2016–19 and 2021–26.
  - Neither cell's eras turn on a price-band swap. The eroding legs are the record config's own.
- **Execution flags (P-k0's summary) carry no band signal.**
  - The initial-stop-under-2 % list repeats the same handful of tickets across arms and seeds: GME, APPF and AAON in C1,
    and CRM, SBUX and DECK in C2.
  - On P-k0, 59 (C1) and 106 (C2) long fills were filled from above. 44 of 175 (C1) and 60 of 271 (C2) stop exits filled
    more than 0.5 % past the stop.
  - None of these is a band swap. The entry-geometry diagnostics (D1, D4, D5) were not compared across arms here.
