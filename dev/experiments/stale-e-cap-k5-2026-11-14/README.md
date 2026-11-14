# Stale-E entry cap, K = 5 paired 26y (2026-11-14): pre-registration

**Status: pre-registered, no runs.** Written before any result of any 26-year arm. The only backtests behind it are
one-year local smokes (§Smoke). They are liveness checks, and they changed the design twice:

- They showed that the cap also admits names that S's stop gate rejects (§How the cap reaches a fill, item 5).
- That finding added a third arm, **G**: the cap with the stop gate read at the uncapped trigger (#3609), which keeps
  the screen's re-pricing and re-sizing and takes the admissions out. The user approved it on 2026-11-14, before any
  26-year cell ran (§Arm G).

The rule below is applied as written.

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
(§The admission channel). Arm G takes the admissions out by construction, so G vs S reads the screen's channels alone
(§Arm G).

## Design

### Arms and seeds

- **S** is the record config. `specs/sec-S-k<K>.sexp` equals `../record-kseed-2026-10-27/specs/rk-k<K>.sexp` below
  its header, so it also equals #3595's arm S, `../price-band-tiebreak-2026-11-13/specs/pb-S-k<K>.sexp`.
- **C** is S plus `((entry_cap_local_range_weeks 4))`, in `specs/sec-C-k<K>.sexp`.
- **G** is C plus `((entry_cap_stop_gate_on_uncapped true))` (#3609), in `specs/sec-G-k<K>.sexp` (§Arm G).
- **Seeds.** K = 0..4, on the Seeded tie default, `tiebreak_seed` = K in every arm. C-kK and G-kK pair with S-kK, and
  all three run in the same session.
- **Generation and checks.** `make_specs.sh` writes the fifteen specs. Before anything runs, `chain.sh` checks:
  - S equals rk-kK and pb-S-kK, normalised;
  - C equals S plus the one override;
  - G equals C plus the one flag;
  - S sets the three fill-model settings above, shorts off and `tiebreak_seed` K;
  - S sets none of `entry_anchor_local_range_weeks`, `enable_continuation_buys`, `freeze_entry_at_first_breakout`,
    `entry_cap_local_range_weeks` or `entry_cap_stop_gate_on_uncapped`, each of which would change what the cap acts on;
  - G sets neither `entry_anchor_local_range_weeks` nor `freeze_entry_at_first_breakout`. `Weinstein_strategy.make`
    refuses the gate flag with either, so this follows from the lines above; it is asserted on G's own text anyway,
    because a refusal would surface only when the cell starts.

### Window, universe, build, data

- **Window and universe.** 2000-01-01 → 2026-06-26, top-3000 PIT v12 yearly schedule with the deduped lists, as #3595.
  Broad universe only (`.claude/rules/universe-discipline.md`). `TRADING_PATH_SEED_SALT=0`.
- **Build.** All fifteen cells run at one `origin/main` SHA (`SC_SHA`) that contains #3604, #3609 and this
  pre-registration, in Claude cloud sessions. The five sessions must log the same `HEAD=`; a seed run at another SHA is
  re-run.
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
  HEAD 1034b458e and 9664e1705 (#3609), only #3604 and #3609 touch `trading/` outside `devtools/`.
- **params.sexp.** It lists the spec's overrides only, so S's differs from #3595's only in `code_version` and
  `data_dir`.

**Does #3609 change anything when its flag is off? No, by reading the code** (`entry_cap_stop_gate.ml`,
`entry_audit_capture.ml`, `entry_audit_helpers.ml`, `entry_stop_width_order.ml`, `entry_walk.ml`):

- **The gate entry.** `Entry_cap_stop_gate.gate_entry` returns `None` unless `entry_cap_stop_gate_on_uncapped` is true
  and `entry_cap_local_range_weeks > 0`. Arm S sets neither.
- **The entry walk with `None`.** `_initial_stops` takes the gate's floor kind and distance from the placed stop itself,
  and `initial_stop_and_kind` tests the re-anchor at `Option.value gate_entry ~default:effective_entry`: the same values
  the code computed before. The `Demote_over_max` order falls back to `effective_entry_of_close`, as before.
- **Pinned.** The unit tests "gate entry none unless the flag applies" and "flag on, cap off: no-op"
  (`trading/trading/weinstein/strategy/test/test_entry_cap_stop_gate.ml`), and "stop gate flag: default off, an axis"
  (`trading/trading/backtest/test/test_entry_cap_overlays.ml`).
- **`chain.sh` greps both off paths** before it builds, so a later change to either stops the session.

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
- **The waiver.** `TRIPWIRE_WAIVE="<diagnosis>"` continues past a mismatch and logs the reason. The arms stay
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
the outcome, for C vs S, then for G vs S and C vs G (§Arm G), then the combined outcome. `DATA_DIR` (the bar store) is
needed only to mark the open positions at the end; without it the outcome prints as PROVISIONAL.

This section is the C vs S rule, the flag as built and the promotion question. It is unchanged by arm G; §Arm G
applies the same machinery to G vs S and adds the combined table.

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
    not a cell. (Since #3609 that variant exists and runs here as arm G, so the G read answers this question in the
    same run; the clause stays as written, and §Arm G's combined table says what follows.)
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

## Arm G: the cap, with the stop gate read at the uncapped E (added 2026-11-14, before any result)

The user approved a third arm on 2026-11-14, after the smoke showed that 19 of C's 21 capped tickets were admissions.
No 26-year cell had run, so G is part of the pre-registration, not a reaction to a result.

### Why G

- **What the screen measured.** #3594 replayed only tickets the record took. It measured re-pricing and re-sizing
  (channels 1 and 2 of §How the cap reaches a fill), and never admission (channel 5).
- **What C carries.** C moves all five channels at once. C vs S alone cannot say whether a gain or a loss belongs to
  the screen's lever or to the admissions.
- **What G does.** It keeps channels 1–4 and takes channel 5 out:
  - **G vs S** isolates the screen's lever: the same names, cheaper and larger, in the real book.
  - **C vs G** isolates the admissions: the same lever on both sides, plus the names only C's gate lets in.
  - Per seed, Δk_CG = ln(1 + R_C) − ln(1 + R_G) = Δk_CS − Δk_GS exactly.

### The flag (#3609, merged as 9664e1705e)

`entry_cap_stop_gate_on_uncapped : bool`, default false. The contract is in
`trading/trading/weinstein/strategy/lib/entry_cap_stop_gate.mli` and the field's doc in `weinstein_strategy_config.mli`.

- **What it changes.** When the cap lowers a long ticket's trigger from E to E′, every stop-width decision in the entry
  walk reads the stop the ticket would install at E:
  - the §5.1 re-anchor test (`stop_anchor_at_entry_base`);
  - the `require_structural_stop` test;
  - the `max_stop_distance_pct` gate;
  - the `Demote_over_max` order.
- **What it keeps.** The trigger, the StopLimit limit, the installed stop and the size still follow E′. So G admits
  exactly the names S's gate admits, and places each one as C would.
- **Where it does nothing.** Without the cap, without the trigger entry (`sim_entry_trigger_at_suggested` and
  `enable_sim_entry_stoplimit`), on shorts, and on a ticket the cap did not lower.
- **What `make` refuses.** The flag with `entry_anchor_local_range_weeks > 0` or `freeze_entry_at_first_breakout`. The
  record config sets neither, and `chain.sh` checks every G spec (§Design).
- **Faithfulness.** §5.1 of `docs/design/weinstein-book-reference.md` measures the stop from the purchase price, which
  is E′ under the cap. So the flag is a control, not a more faithful gate; its doc says so. It changes only which E the
  15 % test reads (a dial, W2). No spine item moves (W1).

### What G cannot take out

- **Path.** G's positions are larger, so its cash on later Fridays differs from S's. G can still place a name S did not,
  or skip one S placed (classes PC and PS, as for C). Those are path effects, not gate admissions.
- **The Fridays without an S list.** On a Friday S placed nothing, S recorded no list, so a G ticket that Friday cannot
  be checked against S's gate. The G check below counts only recorded skips. G's "A no S list" count is reported beside
  C's.

### The G check: G must create no admissions

- **The count.** G's capped long tickets on a key (symbol, decision Friday) that an S cell skipped at the stop gate that
  Friday: `No_structural_stop` or `Stop_too_wide` in S's `entries.tsv`. The S record is pooled over the five S seeds,
  as for class A gate (recorded), because the gate's verdict does not depend on the portfolio.
- **The bar: 0, pooled over all seeds, with no tolerance.** Why no tolerance:
  - The gate is a function of the bars and the candidate alone. `make_entry_transition` (`entry_audit_capture.ml`)
    decides it before sizing and before any cash check.
  - With the flag, the gate reads the same E as S's for the same candidate.
  - So one G ticket on a recorded gate skip means the flag does not do what #3609 says.
- **The premise, reported beside it.** The count of S's own tickets on a pooled gate key, expected 0. If it is not 0,
  the gate is not portfolio-independent after all, so the pooled record cannot certify G. The count then falls back to
  each seed's own S record, with the same bar of 0.
- **Where it is checked.**
  - In each session's preflight, on G's first quarter against S's. Any G ticket on an S gate skip aborts the session
    before the cells run.
  - After each seed's cells, logged as `GCHECK kK`.
  - In the read, pooled: §0 of the S:G pair in `read/split.sh`.
- **If it fails: G INVALID.**
  - Every G seed leaves the read, and G vs S and C vs G are reported as information only.
  - No channel is named. C vs S stands alone, exactly as §Outcome.
  - The defect goes to `feat-weinstein` as a #3609 bug, and G does not run again until it is fixed.
- **G's other validity, per seed,** is C's with G in C's place:
  - V6 of G against S exits 0 (`sec-G-kK-s0.v6diff-S.log`);
  - the tripwire holds;
  - G's RESULT line reads `n_symbols_absent=1`.
  - With fewer than 4 valid G seeds, G is INVALID too.

### G vs S: the screen's lever

The rule of §Decision rule, applied as written with G in C's place: validity, L and F, Δk_GS against the same
δ = max(0.20, m_S), D, the drawdown and concentration bars, and the outcome table, first match wins.

- **L for G** is G's capped share. With the admissions gone, it should sit near the screen's base of 20 % (§Decision rule
  1), not near C's 62 %. The 10 % bar is unchanged.
- **F for G** rests on many more pairs than C's: almost every capped G ticket is a key S placed too. In the smoke year it
  was 3 of 3, against C's 2 of 2.
- **D_G is the screen's estimand in the real book.** The screen found +6.8 to +12.0 NAV-% per seed, with free funding
  and fixed exits.
- **What each G outcome means:**
  - **ESCALATE.** The candidate is the cap with the uncapped gate: both flags as one configuration, under
    `dev/rules/promotion-confirmation.md`, as §Outcome says for C. The gate flag's doc calls it a control arm; changing
    that is the user's decision when the program starts, not this run's.
  - **KEEP-AXIS.** The screen's per-ticket gain survives the book but sits below what K = 5 resolves. This is the
    predicted outcome.
  - **NO-BUILD.** The per-ticket gain does not survive cash, the exposure cap and rotation.
  - **NOT LIVE.** G does not bind or does not reach the fill. That makes G a different arm from the one designed, so it
    counts as G INVALID.
  - **INCONCLUSIVE.** As for C.

### C vs G: the admissions, reported

`read/split.sh` reads this pair with G as the base. It reports:

- Δk_CG per valid seed, its median against δ, and its signs;
- the admission classes of C against G: capped C tickets on keys G did not place, as A gate (recorded), A no G list and
  A other, each with its count and NAV-% sum, per seed and pooled;
- the displacement: G's tickets that C skipped for `Insufficient_cash`;
- the same-ticket tables. On this pair they mostly compare a ticket with itself, because both arms cap it the same way.

**It is reported, and it decides no build on its own.** Why:

- **It carries no new data.** Per seed, Δk_CG = Δk_CS − Δk_GS. A third pass or harm verdict on the same cells would add
  a second route to a promotion and no information.
- **Its noise is the same.** C and G re-draw the path from the first admission on. #3595's paired SD of Δ at 26 years
  was 0.167.
- **What it does decide is attribution.** It names the channel in the combined table:
  - **"admissions add"**: the median Δk_CG is at least δ, and Δk_CG > 0 in all but one valid seed;
  - **"admissions cost"**: the median is at most −δ, and Δk_CG < 0 in all but one valid seed;
  - **"unresolved"**: anything else, including fewer than 4 valid seeds.

### The combined outcome (the first row that matches)

C's outcome is the C vs S rule's, and G's is the G vs S rule's. This table changes neither. It says which reading and
which candidate follow from the two. "Passes" means ESCALATE.

| combined | when | reading and next step |
|---|---|---|
| **G INVALID** | the G check fails, fewer than 4 G seeds are valid, or G vs S is NOT LIVE | C vs S stands alone, exactly as §Outcome. G reads are information only, and no channel is named. |
| **BOTH PASS** | C and G both pass | The screen's lever alone clears δ, and the admissions do not take it back. The candidate is the cap as built (C): the flag the run tests, with the gate §5.1 describes. If C vs G reads "admissions cost", the candidate is G instead. |
| **LEVER, NOT ADMISSIONS** | G passes, C does not | The screen's lever survives the book, and the admissions cost it or bury it in noise. The candidate is the cap with the uncapped gate (G). C's own outcome stands for the flag as built. |
| **ADMISSIONS** | C passes, G does not | C's ESCALATE stands under its rule, but this run cannot say the screen's lever carries it. C vs G names the channel: "admissions add" or "unresolved". Either way the gain is read as a change to the stop gate, against the history below, before any promotion work starts. |
| **NEITHER PASSES** | neither passes | Each arm's own outcome applies to its configuration. G at KEEP-AXIS is the predicted case: the lever survives per ticket, below what K = 5 resolves. |

`read/lib/combine.awk` prints the row from the three pairs' `RULE` lines.

**The stop-width history that the ADMISSIONS row is read against.** An admitted name has a support floor more than 15 %
below E but within 15 % of E′. So the cap acts as a selective widening of the 15 % gate. The relevant history
(`dev/agent-memory/`):

- `project_max_stop_filters_structural_stops.md`: the 15 % gate filters only book-faithful `Support_floor` stops, and
  30 % of that population sits within one point of the gate, so a small move admits a whole block at once.
- `project_stop_gate_not_entry_anchor.md` and `project_faithful_ticket_structural_exclusion.md`: the gate, not the
  anchor, excludes the crash-recovery cohort (AXTI was rejected 21 times as `Stop_too_wide`).
- `project_stop_anchor_surface_is_dds.md`, `project_stop_width_regime_dependent.md` and
  `project_record_gap_is_concentration.md`: earlier gains from wider stops or a wider gate came down to one admission
  (DDS, MSTR, AXTI) or to concentration, and their sign turned with the regime.

So under ADMISSIONS the analyst also reports, per valid seed, the A total without its three largest keys. If that is
≤ 0 in at least three valid seeds, the gain rests on a few admissions, in the pattern above. That is flagged to the
user with the ESCALATE, before any promotion work starts.

### Power and expectations (written before any result)

- **G vs S.** The screen predicts +0.05 to +0.15 log, inside the band (δ = 0.20). With #3595's paired SD of 0.167, K = 5
  resolves only an effect larger than the screen predicts. The expected G outcome is KEEP-AXIS, so D_G carries G's
  read.
- **D_G is much better powered than C's D.** C's D rests on the few keys both arms placed with C capped (2 in the smoke
  year). G places S's own keys, so nearly every capped G ticket enters D_G (3 of 3 in the smoke year).
- **C vs G** resolves only a large admissions effect. The smoke year (A gate +6.00, A no list −5.41 NAV-%) says nothing
  about its sign.

### Where I was unsure

- **Pooling the gate record.** It rests on the gate being portfolio-independent. The premise count tests that, and the
  G check falls back to each seed's own record if it fails.
- **Fridays without an S list.** A G admission there would escape the check. It is reported, not barred.
- **G NOT LIVE as G INVALID.** A G that rarely binds is not the arm designed, so I read it as a failed control rather
  than as a result about the lever.
- **The candidate when both pass.** I chose C, the flag as built with the gate §5.1 describes, unless C vs G says the
  admissions cost. The other way is defensible too: G changes less of the record's admission set.
- **C vs G for attribution only.** A third verdict seemed to add a second route to promotion with no new data.
- **The three-largest-keys flag under ADMISSIONS** is a reporting rule, not a bar on C's ESCALATE. Making it a bar would
  change the C vs S rule, which stays as written.
- **`CELL_TIMEOUT` at twice the slowest cell, not three times** (§Cost). A cloud session slower than twice the 11-13
  ones would now lose a healthy cell; the relaunch would then re-run it once.

## Reported regardless of the verdict

From `read/split.sh`, per seed and pooled, for each of the three pairs (S:C, S:G and G:C, the first arm in the role
called S below and the second in the role called C), then the combined outcome:

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
- **The admissions and the displacement** (§The admission channel): count and NAV-% sum per class and seed, the A total
  without its three largest keys, and the PC and PS components by the other arm's record.
- **The three largest and three smallest keys per seed**, with their class.
- **The G check** (§Arm G): the pooled and own-seed counts, the premise count, and C's count beside them.
- **Validity.** The `HEAD=`, image and `STAGE OK` lines, `SPEC CHECKS OK`, the `PREFLIGHT_OK` lines (each logs the
  capped tickets of its first quarter, and C's and G's count on S's gate skips), the `TRIPWIRE` and `PARITY` lines, V6
  for C and for G, the `GCHECK` lines, and the cache lines.
- **The review pack**, built over the fifteen cells and looked at before any analysis
  (`dev/rules/backtest-result-review.md` RV1–RV3). It is not committed (EODHD terms).

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
- **G is a control, not a more faithful gate.** §5.1 measures the stop from the purchase price, E′ under the cap. A G
  that passes names a candidate configuration; it does not show that the book's gate should read E.
- **C vs G is an attribution, not a third test.** It is Δk_CS − Δk_GS, seed by seed.
- **The window's end.** Open positions are marked at the last raw close, without dividends.

## Cost (`dev/rules/sweep-hygiene.md`)

- **Per cell.** #3595's ten cells of this spec ran 7,161–8,058 s in the cloud, at 5.71–5.77 GB peak RSS (`maxrss`
  5.84–5.91 GB). Arm C adds one 4-bar scan per analysed symbol-week and some extra tickets to the same work; in the
  smoke it ran 3 % longer than S (1,111 s against 1,076 s). Arm G adds one more stop computation per capped candidate.
  So about the same is expected for all three. (G's own smoke ran 606 s at a 3.61 GB peak, alone in the container
  later the same day, so its wall is not comparable with the S/C run's.)
- **Guards.**
  - `CELL_TIMEOUT` = 16,200 s, twice the slowest cell (8,058 s). It was three times (24,200 s) with two cells per
    session; with three, one hung cell could take the whole session. Twice still clears the observed spread by far.
  - `MEM_MIN_GB` = 7, in whole GiB as `MemTotal` truncates: a cell peaks near 5.9 GB, and #3602's session logged
    `mem=15G`. The three arms run one at a time, so the session's peak is one cell's; G's smoke peaked lower than the
    S/C run (3.61 GB against 3.76 GB). This guard only stops a session on a machine too small to finish a cell.
  - At least 12 GB of free disk before an unfinished stage (#3598's measure), and 5 GB before each cell.
- **Per session.** Stage 10–13 min, build under 1 min, three 3-month preflights about 5 min each, three cells
  6.0–6.7 h, extracts and the in-session read about 5 min. That is about 7 h.
  - It must detach: `run_in_background` stops at 2 h (`docs/howtos/claude_cloud_sessions.md`).
  - **Resume, per arm.** On 11-14 cloud containers restarted once or twice per session (the dispatcher's report), and
    each restart re-ran the cell it lost. `chain.sh` resumes from its log, as the price-band chains do, one arm at a time:
    - each arm's preflight is skipped once its `PREFLIGHT_OK` line is logged, and all of them once any cell has run;
    - each cell is skipped once its `RESULT` line is logged;
    - the tripwire, once its `MATCH` or `WAIVED` line is;
    - each arm's extracts, once its `EXTRACT` line is and both files are non-empty.
  - So a restart during G re-runs only G. A cell that fails (a non-zero exit, or no `actual.sexp` or `trades.csv`)
    logs `CELL FAILED` instead of `RESULT` and aborts, so the relaunch re-runs it rather than skipping it.
- **In all.** Five sessions side by side, about 32 cell-hours. No local container time beyond the smokes.

## Files

- `make_specs.sh` writes `specs/`, the fifteen cells (`sec-{S,C,G}-k0..4`).
- `chain.sh` runs it all; its header describes each subcommand.
  - `run K` runs one seed's three arms in one cloud session: stage, build, spec checks, the preflight of the three arms
    over 2000-01-03 → 2000-03-31, S, the tripwire, C with V6 against S, G with V6 against S, each arm's extracts after
    its cell, the G check (logged), collect, and the in-session read (information only). It resumes per arm (§Cost).
  - The preflight aborts the session unless:
    - the params carry the cap at 4 in C and G and not in S, and the gate flag in G only;
    - every cache line reads `n_symbols=9200 n_symbols_absent=1`;
    - C and G each cap at least one ticket, and S none;
    - G caps no ticket on a key S's preflight skipped at the stop gate (the G check on the quarter).
  - The smoke's C capped 9 tickets in that quarter and G 2, from screens that do not depend on the portfolio.
  - `check K` runs only the spec checks; they pass for all five seeds and abort on each tamper tried (§Smoke).
  - `tickets AUDIT` and `entries AUDIT` print the two extracts of any `trade_audit.sexp`. The smoke used them.
  - `preflight K` is the local smoke path: spec checks and the three preflights against an existing warehouse, with
    `RUNNER=exec`.
- **The two extracts.** `trade_audit.sexp` (~0.3 GB) is never committed.
  - `<tag>-tickets.tsv` has one row per placed ticket: `position_id`, symbol, decision date, side, `entry_anchor`, the
    `local_range_top` flag, stop width (a ratio), `risk_pct`, the position value and risk at placement, cancel reason
    and age, fill age, the cash required and available at a refusal, and the fill against its trigger (a signed
    fraction).
  - It carries no price: the stop and trigger levels stay in the session.
  - `<tag>-entries.tsv` is #3588's placed-and-skipped list.
- `read/split.sh` (POSIX sh + awk, `read/lib/keys.awk`, `read/lib/summary.awk`, `read/lib/combine.awk`) is the whole
  read above. It reads the pairs S:C, S:G and G:C in turn (`PAIRS` picks others), then prints the combined outcome. It
  prints summaries only. `KEYS=FILE` also writes the per-key rows; with `DATA_DIR` those carry marked open positions,
  from which a raw close can be recovered, so that file is never committed.
- `results/smoke/` holds the smoke's per-arm artifacts, its read and its log (§Smoke).
- `results/k<K>/` holds each seed's `chain.sh collect` output, after the runs.

## Smoke (local, 2026-11-14): liveness only

### Arms S and C

Both arms of seed 0 ran over 2000-01-01 → 2000-12-29 on the record's top-3000 PIT v12 schedule, in the local
container. They used the container's v12wk warehouse (the source of R2 `v12wk-9236`) and the tree's committed
`test_data`, which has no corporate actions, so no dividends were credited.

**This is liveness and plumbing only.** One seed, one year, on a different data stage: none of its numbers is evidence
about the cap's effect on returns, and none enters the read.

- `results/smoke/smoke.txt` has the commands, the logs and the checks.
- `results/smoke/k0/` has the per-arm artifacts and both extracts.
- `results/smoke/split.txt` is `read/split.sh` run on them. It was regenerated with arm G (below); its S:C numbers
  are unchanged.

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

### Arm G (local, 2026-11-14, after #3609 merged): liveness only

Arm G of seed 0 ran over the same year, in the same container, on the same warehouse and `test_data`.

- **The build.** main 9664e1705e (#3609), in a clone of its own under `.claude/worktrees/`, so `params.sexp` reads
  `code_version 9664e1705e842fa0971f6f3f94e155ebefe29a3f`. (The S/C smoke's `code_version` reads b54e44ea9, the
  enclosing checkout's HEAD; the code that ran there was d521e5254's, as `results/smoke/smoke.txt` explains.)
- **The files.** `results/smoke/k0/sec-G-k0-s0-*`. The read of all three pairs is in `results/smoke/split.txt`, and
  the G commands and checks are in `results/smoke/smoke.txt`.
- **The same caveat.** One seed, one year, no corporate actions: none of its numbers is evidence about returns.

| arm | wall | placed tickets | capped | closed | open at the end |
|---|---:|---:|---:|---:|---:|
| G | 606 s | 19 | 3 (L = 15.8 %) | 13 | 5 |

Peak RSS was 3.61 GB (`maxrss` 3.69 GB). The cache line read `n_symbols=9200 n_symbols_absent=1`. G ran alone in
the container, later in the day than S and C, so its wall time is not comparable with theirs.

- **G places S's tickets.** Its 19 tickets are S's 19, symbol and Friday for symbol and Friday.
- **It caps only names S placed.** The three capped tickets are:
  - DIS 2000-01-14 and TRW1 2000-03-24, the two capped tickets C shares with S;
  - EOG 2000-04-14. S placed it uncapped, and C skipped it for `Insufficient_cash` that Friday (one of C's three
    displaced tickets).
- **It reaches the fill, lower, with more shares, on S's days.** F = 3 of 3:
  - DIS: 36.96 for 2,024 shares, against S's 37.23 for 1,949;
  - TRW1: 57.56 for 1,281, against S's 58.34 for 1,178;
  - EOG: 25.21 for 3,123, against S's 25.52 for 2,733, still open at the end.
- **No admissions.** G's capped tickets on a key S skipped at the stop gate: 0. The premise count (S's own tickets on a
  gate key) is 0. C has 10 on the same record.
- **The uncapped tickets do not move.** The 15 uncapped keys both arms filled have the same fill days and prices, and
  share counts within 0–48 of S's, because G's NAV runs slightly higher. M0 is +0.00 NAV-%.
- **The read runs on three arms.** The S:G and G:C passes and the combined table run end to end
  (`results/smoke/split.txt`). With one seed, every outcome is INCONCLUSIVE and the combined row is G INVALID (fewer
  than 4 valid G seeds), as the rule says.
- **The chain's own preflight path**, `chain.sh preflight 0` with `RUNNER=exec`, passed for the three arms:
  - S in 337 s, the cap at 0 and no gate flag, 0 of 8 tickets capped;
  - C in 334 s, the cap at 4, 9 of 15 capped (the full-year smoke's 9 on the same Fridays), 3 of them on S's gate
    skips (NTPIF, PLL_old, TBI1);
  - G in 303 s, the cap at 4 and the gate flag true, 2 of 8 capped (DIS, TRW1), none on S's gate skips. G's 8
    tickets are S's 8.
- **The run path, with stubs.** `cells` and `collect` ran against a stub runner and validator in the container: a
  failed C and then a failed G each aborted without a RESULT line, and each relaunch re-ran only the lost cell
  (`results/smoke/smoke.txt`). The first stub run caught a defect, fixed here: a variable that `disk_ok` overwrote.
- **The spec checks** pass for all five seeds with G, and abort on seven more tampers, each named in
  `results/smoke/smoke.txt`.
- **A fix to the ticket extract.** `tickets_extract` compared the trigger and the stop as strings. So a row whose two
  levels straddle a power of ten printed its width negative: one row per arm in the smoke, TCR 2000-03-31, −0.1156
  for 0.1156. It is fixed (a numeric compare) before G's extract. The S and C extracts are left as committed. The read
  never uses that column.

**Not run locally:** the guards, the R2 stage, the full cells, the validator, the V6 diff and the tripwire. Apart from
the tripwire, which is an md5 comparison, they are #3588's code, which ran in the cloud on 11-13 (#3595).

## Launching (one cloud session per seed, K = 0..4, side by side)

The dispatcher picks one SHA on `origin/main` that contains #3604, #3609 and this pre-registration, and puts it in all
five briefs as `<SC_SHA>`. `chain.sh` refuses to run at any other HEAD, and refuses to resume at a HEAD different from
the one its `chain.log` already records.

```
Repo checkout of dayfine/trading. Run: git fetch origin main && git checkout <SC_SHA>. Do not edit tracked files.
Launch the chain detached, exactly:
  mkdir -p .sweep-output/stale-e-cap-k5 && SC_SHA=<SC_SHA> setsid nohup sh dev/experiments/stale-e-cap-k5-2026-11-14/chain.sh run K >> .sweep-output/stale-e-cap-k5/run.out 2>&1 < /dev/null &
Do not start it as a harness background task (those are killed at 2 h); it runs three cells and takes about 7 h. Wait
with a Monitor until-loop on .sweep-output/stale-e-cap-k5/chain.log for "STALE-E-CAP kK DONE" or "ABORT", plus a
30-minute send_later heartbeat that re-checks the log and re-arms both. After any restart, or a "CELL FAILED" abort,
re-run the same launch command once: it resumes per arm and re-runs only the cell that was lost. If the same cell fails
twice, stop and push the log. Never docker kill every container: the session's own trading-1-dev container is not a
chain cell. Never print R2 or EODHD credentials. When "STALE-E-CAP kK DONE" appears, copy
.sweep-output/stale-e-cap-k5/results/kK into dev/experiments/stale-e-cap-k5-2026-11-14/results/kK on a new branch
experiment/stale-e-cap-k5-kK, commit and push that branch. Do not open a PR, merge, label or push to main. If the chain
logs any other ABORT (a TRIPWIRE MISMATCH or a failed G check included), push the log the same way and stop.
```

After the runs:

1. The dispatcher gathers the five branches into one results PR.
2. **The read, on the host,** with a local `data/`:
   `sh dev/experiments/stale-e-cap-k5-2026-11-14/read/split.sh dev/experiments/stale-e-cap-k5-2026-11-14/results data > dev/experiments/stale-e-cap-k5-2026-11-14/results/read/split.txt`.
   It prints the three pairs and the combined outcome.
3. One review pack covers the fifteen cells: `dev/scripts/review_pack.sh`, rendered with `review_pack_render.sh`, as
   #3595 did (RV1). It is looked at and not committed.
4. `results-analyst` reads the PR and the pack, applies the outcome and writes the why.
5. `qc-results` reviews the PR (`dev/rules/model-routing.md`).
