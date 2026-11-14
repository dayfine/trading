# Price-band tiebreak confirmation (2026-11-13): pre-registration

**Status: pre-registered, no runs.** Written before any result of either cell. The rule below is applied as written.
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
