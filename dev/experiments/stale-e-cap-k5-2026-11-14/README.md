# Stale-E entry cap, K = 5 paired 26y (2026-11-14): pre-registration

**Status: pre-registered, no runs.** Written before any result of either 26-year arm. The only backtest behind it is a
one-year local smoke (§Smoke). That is a liveness check, and it changed the design in one way: it showed that the cap
also admits names that S's stop gate rejects (§How the cap reaches a fill, item 5). The rule below is applied as
written.

## Why

The 2026-11-12 entry-timing screen (`../entry-timing-screen-2026-11-12/`, #3594; ledger slugs `entry-timing-screen`,
`stale-e-cap-screen`) replayed every closed trade of the record run under four entry rules. Only one survived, H2′: cap
a stale entry trigger at E′ = min(E, 4-week high × 1.005).

- **The gain.** Per seed k0..k4: +11.6, +7.3, +6.8, +12.0 and +9.7 NAV-% (the screen's `results/extra.txt`), with
  78–90 trades better and 4–9 worse per seed. The k0 90 % bootstrap interval is [+2.2, +22.1].
- **The two channels** (the screen's `results/sizing.txt`):
  - **Price.** The lower fill, at the old share count: +3.9, +4.4, +2.7, +6.5 and +6.1.
  - **Size.** Sizing at 1 % NAV risk off a lower trigger buys more shares (median +10.3 %, p90 +28.0 %): +7.7, +3.0,
    +4.1, +5.5 and +3.6. That is 37–66 % of the gain.
- **What the replay could not see.** It funded every larger position freely, held exits fixed, and could not see
  cash, the 70 % exposure cap, the 30 % cash floor or rotation. A cash-limited book can eat the size half.
- **Scale.** The gain is 2–5 % of realised P&L. Scaled to the run's 26-year log return of about 2.8, that is roughly
  +0.05 to +0.15 log. This is a proportional estimate, not a measured return.

PR #3604 (merged at d521e5254) built the flag. This experiment is the K = 5 paired 26-year test the screen asked for,
and it must report the price/size split and the fills per arm.

## Mechanism under test

`entry_cap_local_range_weeks : int`, default 0 (off). Arm C sets it to 4.

- **The rule.** T is the split-safe maximum high over the 4 most recent weekly bars, the current one included. A long
  ticket's anchor becomes min(A, T) when A is above T, where A is the screener's anchor (the graded breakout top).
  The screener then adds its own `entry_buffer_pct` (0.5 %), so the capped ticket is round(T × 1.005).
  An anchor at or below T is left alone. The cap only lowers a trigger; it never raises one.
- **Not capped.** The MA fallback (a basis mix, #2973), the continuation arm and shorts.
- **Unchanged.** The screener's admission, resistance grading, cascade scoring, the F1 freshness clock (it reads the
  uncapped anchor) and stage classification. The strategy's own entry walk is not unchanged: its stop gate reads the
  ticket's E (item 5 below).
- **The audit.** A capped ticket records `entry_anchor Local_range_top` in `ticket_lifecycle`, and carries a
  `local_range_top` field. With the replace anchor off, as in the record config, both appear exactly when the cap
  bound.
- **Faithfulness.** `docs/design/weinstein-book-reference.md` §4.7 puts the buy-stop at the top of the *current*
  trading range, and §4.1 requires the breakout. This is an entry-level dial (W2). No spine item moves (W1).

### How the cap reaches a fill, and what else it moves

The record config (checked by `chain.sh` in every S spec) sets `enable_sim_entry_stoplimit true`,
`sim_entry_trigger_at_suggested true` and `entry_extension_max_pct 2.0`. So the simulator's entry is
StopLimit(E, E × 1.02) resting at the ticket's own E, and arm C's ticket is StopLimit(E′, E′ × 1.02).
Without `sim_entry_trigger_at_suggested` the trigger would be the decision close, and the cap would never reach a
fill (the #3604 QC note).

With the trigger at E′, the cap moves five things per capped ticket. The first two are the screen's channels; the
other three are what this run adds.

1. **The price paid.** E′ < E, so C triggers no later than S, and lower.
2. **The size.** The stop is the support floor under the base (`stop_anchor_at_entry_base`), not a function of E.
   So the risk per share falls, and the 1 % NAV risk budget buys more shares, up to the 14 % position cap.
3. **The limit.** The do-not-chase limit falls with the trigger, to E′ × 1.02. A session that opens above it is a
   no-fill, and the ticket rests to the next bar. A ticket can therefore fill later than S's, or never.
4. **Cash.** A larger fill can be refused for cash where S's smaller one was not (`entry_fill_rejected_by_portfolio`;
   the record config has no retry or resize). Larger positions also leave less cash for later tickets.
5. **Admission at the stop gate.** The initial stop is measured from the ticket's E (`entry_audit_helpers.ml`
   `initial_stop_and_kind`).
   - **In S.** A candidate whose support-floor stop sits more than `max_stop_distance_pct` (15 %) below its E is
     re-anchored to a buffer stop (`_maybe_reanchor_to_entry_base`). `require_structural_stop` then skips it as
     `No_structural_stop`.
   - **In C.** Measured from the lower E′, the same floor can sit within 15 %, so C places the ticket.
   - **The effect.** The cap changes *which* names are bought. The screen replayed only the trades the code took, so
     it could not see this channel.
   - **It works one way only.** A lower E′ can only shorten the stop distance and enlarge the share count, so the cap
     cannot make the gate reject a name S places.

**In the smoke, channel 5 is the largest by count** (§Smoke). Over 2000, seed 0, C placed 34 tickets and S 19. Of
C's 21 capped tickets, only 2 were tickets S also placed (DIS and TRW1: same fill day, lower price, more shares, same
exit). The other 19 were admissions:

- 10 names S's own list skipped at the stop gate that Friday;
- 9 on Fridays when S placed nothing, so S recorded no list.

All 21 capped tickets had stops 12.3–14.9 % below E′, just inside the 15 % gate. So this run tests more than the
screen's price and size channels. It tests the cap as built, admissions included, and the read keeps the two apart
(§The admission channel).

## Design

### Arms and seeds

- **S** is the record config. `specs/sec-S-k<K>.sexp` equals `../record-kseed-2026-10-27/specs/rk-k<K>.sexp` below
  its header, so it also equals #3595's arm S, `../price-band-tiebreak-2026-11-13/specs/pb-S-k<K>.sexp`.
- **C** is S plus `((entry_cap_local_range_weeks 4))`, in `specs/sec-C-k<K>.sexp`.
- **Seeds.** K = 0..4, on the Seeded tie default, `tiebreak_seed` = K in both arms. C-kK pairs with S-kK, and both run
  in the same session.
- **Generation and checks.** `make_specs.sh` writes the ten specs. Before anything runs, `chain.sh` checks:
  - S equals rk-kK and pb-S-kK, normalised;
  - C equals S plus the one override;
  - S sets the three fill-model settings above, shorts off and `tiebreak_seed` K;
  - S sets none of `entry_anchor_local_range_weeks`, `enable_continuation_buys`, `freeze_entry_at_first_breakout` or
    `entry_cap_local_range_weeks`, each of which would change what the cap acts on.

### Window, universe, build, data

- **Window and universe.** 2000-01-01 → 2026-06-26, top-3000 PIT v12 yearly schedule with the deduped lists, as #3595.
  Broad universe only (`.claude/rules/universe-discipline.md`). `TRADING_PATH_SEED_SALT=0`.
- **Build.** All ten cells run at one `origin/main` SHA (`SC_SHA`) that contains #3604 and this pre-registration, in
  Claude cloud sessions. The five sessions must log the same `HEAD=`; a seed run at another SHA is re-run.
- **Data.** #3595's: the R2 warehouse `v12wk-9236`, corporate actions `corpact-2026-10-27`, and the validator's data
  dir built as in `../chain-w-2026-11-10/README.md` §Data.

### Tripwire: arm S must reproduce #3595's arm S

**Does #3604 change anything when the flag is off? No, by reading the code:**

- **The old path.** `Stock_analysis._local_range_top` returned `None` for `entry_anchor_local_range_weeks <= 0`, and
  otherwise the split-safe max-high scan over that many bars.
- **The new path.** `Stale_entry_cap.anchors` computes the same `range_top` with the same scan, and returns `None` for
  0 weeks: `scan_max_high`'s `base_end_offset >= base_lookback` guard.
- **The cap off.** `cap_weeks = 0` scans nothing, and `ticket_anchor ~cap_top:None` returns `range_top` unchanged.
  The F1 clock reads `range_top`, as it read the old value.
- **Pinned.** The unit tests "off passes the replace anchor through" and "anchors off scans nothing"
  (`trading/analysis/weinstein/stock_analysis/test/test_stale_entry_cap.ml`).
- **Nothing else moved.** The other #3604 diffs are documentation, the weekly-report path and tests. Between #3595's
  HEAD 1034b458e and d521e5254, no other commit touches `trading/` outside `devtools/`.
- **params.sexp.** It lists the spec's overrides only, so S's differs from #3595's only in `code_version` and
  `data_dir`.

**So the tripwire is a hard gate.** After each S cell, `chain.sh` compares `sec-S-kK-s0-trades.csv` with #3595's
`pb-S-kK-s0-trades.csv` by md5:

| seed | #3595 md5 | lines |
|---|---|---:|
| k0 | 0928cfe40333560429f5a6e57c9c18de | 577 |
| k1 | 9441578a81c6cfe4be68a7ca5aecbb8f | 569 |
| k2 | 2034e05dd8dd00f10c16d93be4ce2ce2 | 563 |
| k3 | 0f33cdad0d6e28e1829f53f7e3fd3d92 | 563 |
| k4 | 995be28e6ef1c1829f7db0c8ecd79a41 | 549 |

- **On a mismatch** the chain stops before arm C. Something moved: the build, the CI image (#3595 ran
  `sha256:3865e48e8a61`) or the data stage. The dispatcher diagnoses it before any C cell runs.
- **The waiver.** `TRIPWIRE_WAIVE="<diagnosis>"` continues past a mismatch and logs the reason. The pair stays
  same-SHA and same-stage, so it can still be read, and the read reports the waiver. A waiver needs the written
  diagnosis in the results PR.
- **Information only.** `actual.sexp` and `equity_curve.csv` are also compared with #3595's and the result logged
  (`PARITY` lines).

A match also makes #3595's committed S cells a second witness for every S figure here.

The cloud has already reproduced this file once across sessions. #3602's binding cell (pb-S-k0 with
`--emit-candidates`, 11-14, HEAD 645065bb2, image `sha256:3865e48e8a61`, `mem=15G`) matched md5 0928cfe4…
(`../price-band-binding-2026-11-13/results/cell/chain.log`). It ran before #3604 merged, so it shows cross-session
determinism, not the flag's inertness; the code reading above carries that.

## Decision rule (applied as written)

`read/split.sh RESULTS_DIR DATA_DIR` computes every quantity below from the committed per-arm artifacts and prints
the outcome. `DATA_DIR` (the bar store) is needed only to mark the open positions at the end; without it the outcome
prints as PROVISIONAL.

### 0. Validity

A seed enters the read only when all four hold:

- **V6.** `validator_diff -check V6` of C-kK against S-kK exits 0 (`sec-C-kK-s0.v6diff-S.log`).
- **Tripwire.** `TRIPWIRE MATCH`, or `TRIPWIRE WAIVED` with its diagnosis (reported).
- **Absent symbols.** Both arms' RESULT lines read `n_symbols_absent=1`, the MEL baseline.
- **S is the control.** No S ticket is anchored at `local_range_top`.

A seed that fails is left out and reported. With fewer than 4 valid seeds the outcome is INCONCLUSIVE. Below, "all
but one" means 4 of 5, or 3 of 4.

### 1. Liveness, read per decision

- **L, the binding rate.** The share of C's placed long tickets whose audit `entry_anchor` is `Local_range_top`,
  pooled over the valid seeds. **Bar: L ≥ 10 %.**
- **F, the fill check.** Take the capped keys where both arms filled (a key is a symbol and its decision Friday). F is
  the share where C's entry price, in the decision-date basis, is below S's. **Bar: F ≥ 50 %**, over at least 30
  such pairs pooled; with fewer, liveness is unreadable and the outcome is INCONCLUSIVE.
- **Either bar fails: NOT LIVE.** No return read is made.

Why these bars:

- **L is a per-decision rate.** It is read on the decision the mechanism makes: a ticket's anchor. It is not an
  entry share × a multiplier (#3595 §Defects 1).
- **L's base is the screen's.** E sat above the 4-week high on 500 of the record's 2,695 basis-valid filled trades
  (18.6 %; `../entry-timing-screen-2026-11-12/results/replay-k*.csv`), and on 150 of its 548 never-filled tickets
  (27.4 %; the screen's `results/unfilled.txt`). That is 650 of 3,243 of S's own tickets, 20.0 %.
- **The bar is half that base, for a stated reason.** C's ticket set drifts from S's, and the screen's weeks were
  Monday-based calendar weeks rather than the simulator's weekly bars. Half still fails a flag that binds only in
  edge cases or not at all.
- **C's L will sit well above 20 %, and that is not a reason to move the bar.** Every admission (channel 5) is a
  capped ticket by construction, so C's capped share counts admissions on top of the screen's stale tickets. The smoke
  read 61.8 % in its one year. The bar stays a wiring check: it asks whether the cap binds routinely, not how much it
  admits. The admission share is reported (§The admission channel).
- **F checks the wiring to the fill.** In the replay the capped fill was below the null fill on 490 of 500 stale
  trades and never above it. A cap that does not reach the fill makes C fill exactly where S does, so F = 0.

### 2. Return, the primary metric

Per valid seed, Δk = ln(1 + R_C,k) − ln(1 + R_S,k), where R = `total_return_pct` / 100 from `actual.sexp`. The quantity
m_S is the median, over the pairs of valid S seeds, of |ln(1 + R_S,i) − ln(1 + R_S,j)|. **δ = max(0.20, m_S).**

- **Pass:** the median Δk is at least δ, and Δk > 0 in all but one seed.
- **Harm:** the median Δk is at most −δ, and Δk < 0 in all but one seed.
- **Inside the band:** −δ < median Δk < δ.

Why:

- **The 0.20 floor accounts for the record band.** The 26-year K = 5 record band has a median of ln 2.78 and an SD of
  0.225 (`dev/agent-memory/project_record_kseed_band.md`), and an untraced 26-year difference under about 0.2 log is
  one draw (`project_26y_path_noise_floor.md`).
- **m_S is the cell's own reshuffle null.** By the tripwire, the S cells are #3595's, whose m_S was 0.149. So δ will be
  0.20.
- **The expectation, written now.** The screen's proportional estimate is +0.05 to +0.15 log, below δ.
  - In #3595 the paired SD of Δ at 26 years was 0.167, and pairing by seed removed almost no variance (correlation
    +0.26). Any change to the fills re-draws later cash states, as a tie-order change does.
  - So K = 5 can detect only an effect larger than the screen predicts. The expected portfolio read is "inside the
    band".
  - That is why the mechanism read below, which holds the ticket fixed, carries the build decision when the return is
    inside the band.

### 3. The same-ticket effect D, the mechanism read

D_k is the effect of the cap on the tickets both arms placed and the cap touched, in NAV-% (§The price/size split):

**D_k = M_k + RC_k − RS_k**, over the keys of seed k that both arms placed and where C's ticket is capped, where:

- **M_k**, both arms filled: the sum of c_C − c_S. It splits exactly into price + size + exit.
- **RC_k**, only C filled: the sum of c_C. These are tickets S never reached (the stale E), or that S lost to cash.
- **RS_k**, only S filled: the sum of c_S. These are tickets C lost: refused for cash, or never filled under its lower
  limit.

**Bar: D_k > 0 in all but one valid seed.**

Why:

- **D is the screen's estimand, moved into the real book.** The screen found +6.8 to +12.0 per seed, with free
  funding and fixed exits. D keeps the ticket fixed and lets the book act: refused larger fills count against the
  cap, and tickets that only the lower trigger reached count for it.
- **It holds the ticket fixed, so it does not carry the path's re-draw.** The path re-draw is in the one-arm keys (PC,
  PS), which D leaves out.
- **The same-ticket path null, M0** (uncapped keys both arms filled), is reported beside D. It is the noise a shared
  ticket picks up from the path alone: a different exit day after a rotation, for example.
- **The admissions (channel 5) are reported, not in D.** An admitted ticket uses cash that would otherwise fund
  another ticket or sit in T-bills, so its contribution is only half of its effect. The other half, the tickets it
  displaces, sits among the path keys and cannot be tied to it ticket by ticket. Adding the admissions to D without
  their displacement would bias D upward by construction. Δk is the one quantity that nets the two, so the
  admissions enter the verdict through Δk, and they are reported in full (§The admission channel).

### 4. Drawdown and concentration (ESCALATE only)

- **Drawdown.** Arm medians: median_k(maxDD_C,k) − median_k(maxDD_S,k) ≤ **3.0 pp**, with `max_drawdown_pct` from
  `actual.sexp`. This is #3598's fixed reading. 3 pp is about one seed SD of 26-year max drawdown (3.06 pp across
  #3595's S cells).
- **Concentration.** Per seed, take the total over all keys of c_C − c_S, and drop the 3 largest and 3 smallest keys.
  **Bar: the trimmed total is > 0 in all but one seed.** #3595's gap lived in about five names.

### Outcome (the first row that matches)

| outcome | when |
|---|---|
| **INCONCLUSIVE** | fewer than 4 valid seeds |
| **NOT LIVE** | L < 10 % |
| **INCONCLUSIVE** | fewer than 30 capped pairs both arms filled (F unreadable) |
| **NOT LIVE** | F < 50 % |
| **NO-BUILD** | D_k > 0 in at most one seed while the median Δk < δ; or the harm bar holds |
| **ESCALATE** | the pass bar, the drawdown bar and the concentration bar all hold |
| **KEEP-AXIS** | the D bar holds, and the median Δk is inside the band |
| **INCONCLUSIVE** | anything else: for example a pass with the drawdown or concentration bar failing, or D positive in 2–3 seeds |

ESCALATE does not ask for the D bar. The flag under test is the cap as built, admissions included, and a portfolio
gain that clears δ in all but one seed, within the drawdown limit and without resting on six keys per seed, is a gain
of that flag whichever channel carried it. The read still reports which channel did.

What each outcome does next:

- **ESCALATE.** `entry_cap_local_range_weeks` becomes a promotion candidate under `dev/rules/promotion-confirmation.md`,
  and nothing more. That rule still needs:
  - a walk-forward surface on the axis, values {0, 4} with the neighbours {2, 8};
  - the confirmation grid: at least three broad-vs-broad contexts, one of them a disjoint period in another macro regime
    and one the top-1000 tier;
  - only a ledger ACCEPT then opens a default change (`dev/rules/experiment-flag-discipline.md` R3), on the user's
    decision.
- **KEEP-AXIS.** The per-ticket gain survives the book, but the portfolio effect sits below what a 26-year K = 5 run
  resolves.
  - The flag stays a default-off axis. No further single-lever cells run on it.
  - It may ride in a Weinstein preset bundle that is tested as a whole (`.claude/rules/weinstein-faithful-core.md` W3),
    with D measured again there.
  - If the admissions (all three A classes, pooled over the valid seeds) sum below zero (§The admission channel), the
    analyst names the split variant as the next design question: cap the trigger, but keep the stop gate measured
    from the uncapped E. That is the screen's price-and-size lever alone. It is a code change for `feat-weinstein`,
    not a cell.
- **NO-BUILD.** The per-ticket gain does not survive the book, or the book is clearly worse.
  - Classification: REJECT-as-default, keep-as-axis. One window cannot earn do-not-revive.
  - It is not bundled into a preset without a new mechanism argument.
- **NOT LIVE.** The flag does not bind, or does not reach the fill, on this config. Trace the wiring with the
  per-ticket extract before anything else runs.
- **INCONCLUSIVE.** Name the bar that failed and by how much, and trace the per-seed gap key by key. No new cells run
  without a fresh rationale. No default changes.

## The price/size split (defined before any result)

**Keys.** A key is a symbol and its decision Friday: the ticket the strategy placed that Friday. Each arm's tickets come
from `<tag>-tickets.tsv`, extracted from `trade_audit.sexp` in the session (§Files). Each ticket's outcome is:

- **closed**: a `trades.csv` row with that `position_id`;
- **open**: an `open_positions.csv` row, joined by symbol to the arm's latest uncancelled ticket on or before its
  entry date (the file has no `position_id`);
- **otherwise its cancel reason**: refused for cash at the fill (`entry_fill_rejected_by_portfolio`), TTL expired,
  requalification failed, delisted, or still resting at the end.

**Contribution.** For a filled ticket in arm a, c_a = 100 × (`pnl_dollars` + `dividends_received`) / N_a, in NAV-%.
N_a is arm a's NAV on the last equity-curve date on or before the decision date: the NAV the ticket was sized
against. An open position contributes quantity × (mark − `entry_price`), marked at the last raw close on or before
the arm's last equity-curve date, without dividends.

**Decision-date basis.** `trades.csv` restates `entry_price` and `quantity` for splits during the hold (#3595 §Defects
2, #3384). The read undoes this with each arm's `splits.csv`. With F the product of the split factors of that symbol
dated after the entry and on or before the exit: p0 = `entry_price` × F, q0 = `quantity` / F, and u0 = (`pnl_dollars` +
`dividends_received`) / q0.

**A key both arms filled** (M on capped keys, M0 on uncapped ones):

- **price** = 100 × (q0_S / N_S) × (p0_S − p0_C): S's shares, per unit of S's NAV, bought at C's price.
- **size** = 100 × (q0_C / N_C − q0_S / N_S) × u0_C: the extra shares per unit of NAV, at C's own per-share outcome.
- **exit** = (c_C − c_S) − price − size: everything else, chiefly a different exit day or price, and dividends.
- **price + size + exit = c_C − c_S, exactly.**
- **Comparison with the screen.** The screen held exits fixed, so its "price" channel is this price + exit, and its
  "size" channel is this size (`../entry-timing-screen-2026-11-12/lib/sizing.awk`).
- **Shares per unit of NAV.** Normalising shares by each arm's own NAV keeps a size gap from being a gap in NAV.
  After a few years the arms' NAVs differ, and raw share counts would carry that difference.

**The other classes:**

| class | key | enters the totals as |
|---|---|---|
| RC | both placed, only C filled | +c_C (in D when capped) |
| RS | both placed, only S filled | −c_S (in D when capped) |
| RN | both placed, neither filled | 0, counted |
| PC | only C placed | +c_C, labelled by what S did with that symbol that Friday |
| PS | only S placed | −c_S, labelled by what C did |

- **Totals.** Over all keys, the sum is Σ c_C − Σ c_S, the arms' NAV-% difference. It approximates Δ ln(1 + R) and
  does not equal it.
- **What the other arm did,** for PC and PS, comes from its `entries.tsv` that Friday: skipped with a reason
  (`Insufficient_cash`, `No_structural_stop`, `Sized_to_zero` and so on), not in its post-cut list, or no list
  recorded.

**How cash-refused fills enter it.**

- **On a capped key S filled and C did not, because C's fill was refused for cash.** This is RS, so −c_S counts in
  D. The read splits it in two:
  - **"S's size fits".** C's cash at the refusal (`cash_rejection.available`) was at least S's position cost scaled to
    C's NAV. The larger size was what failed: the size channel eaten at the fill.
  - **"short of S's size".** C could not have funded S's size either. That is the path's cash state.
- **A refusal on an uncapped key** is RS0, a path effect, outside D.
- **A ticket never placed for cash** (an `Insufficient_cash` skip at placement in one arm) is PC or PS, labelled
  `skip:Insufficient_cash`. That is the cash-displacement channel, outside D.
- **The resting-ticket channel.** A capped ticket that gapped past its lower limit and expired shows in RS as `ttl`.
  One that rested and filled later than S's shows in M, with a later fill in the fill-age table.

## The admission channel (defined before any result)

An admission is a capped C ticket on a key S did not place (class PC with C capped). The read sorts them by what S's
records show for that symbol on that Friday:

- **A gate (recorded).** An S `entries.tsv` lists the symbol as skipped at the stop gate (`No_structural_stop` or
  `Stop_too_wide`) that Friday. The gate's verdict does not depend on the portfolio, so a record from any S seed
  counts (`gate-other-seed`). These are admissions the cap caused.
- **A no S list.** This seed's S placed nothing that Friday, so its post-cut list was not recorded, and no S seed
  recorded the symbol at the gate. Most are expected to be gate skips too, but the artifacts cannot prove it. S may
  instead have lacked cash or been cut differently.
- **A other.** S recorded a list without the symbol (held, or cut), or skipped it for cash or another reason. These
  are path effects that happen to be capped.

Against them stands the **displacement**: S's tickets on keys C did not place, where C's `entries.tsv` lists the symbol
as skipped for `Insufficient_cash` that Friday (class PS, `skip:Insufficient_cash`). C's larger positions and extra
admissions draw on the same cash.

What the read reports, per seed: the count and NAV-% sum of each A class and of the displacement; the components of PC
and PS by the other arm's record; and the resolution of C's capped tickets against their S twins. What it does not
do is net A against the displacement ticket by ticket. The two are tied through cash on later Fridays, not on the same
key; Δk is where they net.

## Reported regardless of the verdict

From `read/split.sh`, per seed and pooled:

- **Per seed and arm.** R, ln(1 + R), Δk, max drawdown, Sharpe, Ulcer index, closed trades, open positions, and trades
  at ≥ +100 %.
- **Liveness.** L and F by seed; S's capped count (must be 0); and the count of tickets whose `local_range_top` field
  and `entry_anchor` disagree (expected 0).
- **Fills per arm.** Placed long tickets by outcome: closed, open, refused for cash at the fill, TTL, requalification,
  delisted, still resting.
  - The same for C's capped tickets, and for S's twins of them.
  - Fill age from placement (p50, p90, share within one week), all tickets and capped ones.
- **The split.**
  - Per seed: n, price, size, exit and M; RC and RS on capped keys, by outcome; D; M0 with its mean |c_C − c_S|; PC
    and PS by what the other arm did; the total; the trimmed total.
  - Beside the screen's per-seed price and size channels: the size share of M, and the p50 and p90 of C's position
    weight over S's on capped pairs (the screen: +10.3 % and +28.0 % more shares).
- **The admissions and the displacement** (§The admission channel): count and NAV-% sum per class and seed, and the
  PC and PS components by the other arm's record.
- **The three largest and three smallest keys per seed**, with their class.
- **Validity.** The `HEAD=`, image and `STAGE OK` lines, `SPEC CHECKS OK`, the `PREFLIGHT_OK` lines (each logs the
  capped tickets of its first quarter), the `TRIPWIRE` and `PARITY` lines, V6, and the cache lines.
- **The review pack**, built over the ten cells and looked at before any analysis (`dev/rules/backtest-result-review.md`
  RV1–RV3). It is not committed (EODHD terms).

## Not claimed

- **Nothing here changes a default.** Even ESCALATE only opens the walk-forward and grid program.
- **One window, one universe.** 2000–2026 on the top-3000 schedule. The screen that chose the lever replayed this same
  history, so the run is not out of sample.
- **The seeds re-draw tie order, not the market.** A ticket's E′ depends on its symbol and Friday, not on the seed.
  Wherever two C seeds place the same ticket, they make the same change to it, so the five C cells largely replicate
  one set of per-ticket changes. D's sign across seeds shows that those changes pay in this history, not that they
  pay in expectation.
- **D is not the portfolio effect.** It leaves out the admissions and the path re-draw (PC, PS), which the cap causes
  too: an admission or a larger position changes later cash. Δk is the portfolio effect, and at K = 5 it resolves only
  a large one.
- **The admission classes are an attribution, not a measurement.** "A no S list" rests on an inference about Fridays
  whose S lists were never recorded (#3595 §Defects 3).
- **The window's end.** Open positions are marked at the last raw close, without dividends.

## Cost (`dev/rules/sweep-hygiene.md`)

- **Per cell.** #3595's ten cells of this spec ran 7,161–8,058 s in the cloud, at 5.71–5.77 GB peak RSS (`maxrss`
  5.84–5.91 GB). Arm C adds one 4-bar scan per analysed symbol-week and some extra tickets to the same work; in the
  smoke it ran 3 % longer than S (1,111 s against 1,076 s). So about the same is expected.
- **Guards.**
  - `CELL_TIMEOUT` = 24,200 s, three times the slowest cell (8,058 s), so a slow session does not kill a healthy cell.
  - `MEM_MIN_GB` = 7, in whole GiB as `MemTotal` truncates: a cell peaks near 5.9 GB, and #3602's session logged
    `mem=15G`. #3595 ran this spec without a guard; this one only stops a session on a machine too small to finish
    a cell.
  - At least 12 GB of free disk before an unfinished stage (#3598's measure), and 5 GB before each cell.
- **Per session.** Stage 10–13 min, build under 1 min, two 3-month preflights about 5 min each, two cells 4.0–4.5 h,
  extracts and the in-session read about 3 min. That is about 4.6 h.
  - It must detach: `run_in_background` stops at 2 h (`docs/howtos/claude_cloud_sessions.md`).
  - A restart costs at most the cell in flight: `chain.sh` resumes past every cell whose RESULT line is logged.
- **In all.** Five sessions side by side, about 21 cell-hours. No local container time beyond the smoke.

## Files

- `make_specs.sh` writes `specs/`, the ten cells (`sec-{S,C}-k0..4`).
- `chain.sh` runs it all; its header describes each subcommand.
  - `run K` runs one seed's pair in one cloud session: stage, build, spec checks, the preflight of both arms over
    2000-01-03 → 2000-03-31, S, the tripwire, C with V6 against S, the extracts, collect, and the in-session read
    (information only).
  - The preflight aborts the session unless C's params carry the cap at 4 and S's do not, both cache lines read
    `n_symbols=9200 n_symbols_absent=1`, C caps at least one ticket and S none. The smoke's C capped 9 tickets in that
    quarter, from screens that do not depend on the portfolio.
  - `check K` runs only the spec checks; they pass for all five seeds and abort on each tamper tried (§Smoke).
  - `tickets AUDIT` and `entries AUDIT` print the two extracts of any `trade_audit.sexp`. The smoke used them.
  - `preflight K` is the local smoke path: spec checks and both preflights against an existing warehouse, with
    `RUNNER=exec`.
- **The two extracts.** `trade_audit.sexp` (~0.3 GB) is never committed.
  - `<tag>-tickets.tsv` has one row per placed ticket: `position_id`, symbol, decision date, side, `entry_anchor`, the
    `local_range_top` flag, stop width (a ratio), `risk_pct`, the position value and risk at placement, cancel reason
    and age, fill age, the cash required and available at a refusal, and the fill against its trigger (a signed
    fraction).
  - It carries no price: the stop and trigger levels stay in the session.
  - `<tag>-entries.tsv` is #3588's placed-and-skipped list.
- `read/split.sh` (POSIX sh + awk, `read/lib/keys.awk`, `read/lib/summary.awk`) is the whole read above. It prints
  summaries only. `KEYS=FILE` also writes the per-key rows; with `DATA_DIR` those carry marked open positions, from
  which a raw close can be recovered, so that file is never committed.
- `results/smoke/` holds the smoke's per-arm artifacts, its read and its log (§Smoke).
- `results/k<K>/` holds each seed's `chain.sh collect` output, after the runs.

## Smoke (local, 2026-11-14): liveness only

Both arms of seed 0 ran over 2000-01-01 → 2000-12-29 on the record's top-3000 PIT v12 schedule, in the local
container. They used the container's v12wk warehouse (the source of R2 `v12wk-9236`) and the tree's committed
`test_data`, which has no corporate actions, so no dividends were credited.

**This is liveness and plumbing only.** One seed, one year, on a different data stage: none of its numbers is evidence
about the cap's effect on returns, and none enters the read.

- `results/smoke/smoke.txt` has the commands, the logs and the checks.
- `results/smoke/k0/` has the per-arm artifacts and both extracts.
- `results/smoke/split.txt` is `read/split.sh` run on them.

| arm | wall | placed tickets | capped | closed | open at the end |
|---|---:|---:|---:|---:|---:|
| S | 1,076 s | 19 | 0 | 13 | 5 |
| C | 1,111 s | 34 | 21 (L = 61.8 %) | 24 | 5 |

Peak RSS was 3.76 GB. Both cache lines read `n_symbols=9200 n_symbols_absent=1`.

- **The cap fires.** 21 of C's 34 tickets are anchored at `local_range_top`, and the `local_range_top` field is present
  on exactly those 21. S has none.
- **It reaches the fill.** Two capped tickets were placed by both arms, and C filled lower on both (F = 2 of 2). DIS
  2000-01-14, the screen's traced case, fills on 2000-01-25 in both arms: S at 37.23 for 1,949 shares, C at 36.96 for
  2,024. Both stop out on 2000-02-25, as the screen said DIS would.
- **Arm S reproduces #3595's arm S decisions.** Its 19 tickets are pb-S-k0's 2000 tickets, symbol and Friday for
  symbol and Friday. The closed trades differ only by 3–13 shares on four rows (no dividends here, so a slightly
  smaller NAV), and in the five rows the window end leaves open.
- **Admissions dominate the capped tickets** (§How the cap reaches a fill): 19 of 21.
- **The tooling runs end to end.** The two extracts, the read, the spec checks for all five seeds, and six tampers
  that each abort the checks.
- **The chain's own preflight path**, `chain.sh preflight 0` with `RUNNER=exec`, passed for both arms: S in 630 s
  with the cap at 0 and 0 of 8 tickets capped, C in 769 s with the cap at 4 and 9 of 15 capped. Those 9 are the
  full-year smoke's 9 on the same Fridays. The capped-ticket abort was added after this run and checked by hand on
  its two ticket files.

**Not run locally:** the guards, the R2 stage, the full cells, the validator, the V6 diff and the tripwire. Apart from
the tripwire, which is an md5 comparison, they are #3588's code, which ran in the cloud on 11-13 (#3595).

## Launching (one cloud session per seed, K = 0..4, side by side)

The dispatcher picks one SHA on `origin/main` that contains #3604 and this pre-registration, and puts it in all five
briefs as `<SC_SHA>`. `chain.sh` refuses to run at any other HEAD, and refuses to resume at a HEAD different from the
one its `chain.log` already records.

```
Repo checkout of dayfine/trading. Run: git fetch origin main && git checkout <SC_SHA>. Do not edit tracked files.
Launch the chain detached, exactly:
  mkdir -p .sweep-output/stale-e-cap-k5 && SC_SHA=<SC_SHA> setsid nohup sh dev/experiments/stale-e-cap-k5-2026-11-14/chain.sh run K >> .sweep-output/stale-e-cap-k5/run.out 2>&1 < /dev/null &
Do not start it as a harness background task (those are killed at 2 h); it takes about 4.6 h. Wait with a Monitor
until-loop on .sweep-output/stale-e-cap-k5/chain.log for "STALE-E-CAP kK DONE" or "ABORT", plus a 30-minute
send_later heartbeat that re-checks the log and re-arms both. After any restart, re-run the same launch command (it
resumes). Never docker kill every container: the session's own trading-1-dev container is not a chain cell. Never
print R2 or EODHD credentials. When "STALE-E-CAP kK DONE" appears, copy .sweep-output/stale-e-cap-k5/results/kK into
dev/experiments/stale-e-cap-k5-2026-11-14/results/kK on a new branch experiment/stale-e-cap-k5-kK, commit and push that
branch. Do not open a PR, merge, label or push to main. If the chain logs ABORT (a TRIPWIRE MISMATCH included), push
the log the same way and stop.
```

After the runs:

1. The dispatcher gathers the five branches into one results PR.
2. **The read, on the host,** with a local `data/`:
   `sh dev/experiments/stale-e-cap-k5-2026-11-14/read/split.sh dev/experiments/stale-e-cap-k5-2026-11-14/results data > dev/experiments/stale-e-cap-k5-2026-11-14/results/read/split.txt`.
3. One review pack covers the ten cells: `dev/scripts/review_pack.sh`, rendered with `review_pack_render.sh`, as #3595
   did (RV1). It is looked at and not committed.
4. `results-analyst` reads the PR and the pack, applies the outcome and writes the why.
5. `qc-results` reviews the PR (`dev/rules/model-routing.md`).
