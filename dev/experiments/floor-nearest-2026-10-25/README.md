# floor-nearest-2026-10-25: Nearest support floor under `require_structural_stop`, pre-registered

Status: **SN RUN 2026-10-25, NOT LIVE as screened (§Results, #3423); SM RUN 2026-10-26, INCONCLUSIVE (§Results, arm SM).** Pre-registered in #3418 (97b6daa99, plus the §Log
06:57 PT amendment) before any SN cell ran; the null is path-stability arm S (#3419). All 6 SN cells ran clean (V6 exit 0).

## Why this arm

The record N arm skips about 20,000 decisions over 26 y as `No_structural_stop` (every year, 87–97 % of top-N
decisions). On the path-stability S p0 cell it is 5,078 skipped decisions against 190 placed tickets. A host-only screen of the
26y record skips (2026-10-25, memory `project_floor_and_refresh_screens`) found:

- 67 % of skips have no 8 % pullback after the 90-bar high, because the high is at or near the end of the window: the
  stock is making new highs, which is the shape the strategy wants to buy.
- With `support_floor_anchor_scope Nearest` (an existing default-off dial: the nearest correction that meets
  `min_correction_pct`, not the one after the window extreme), about 8× more tickets get a structural stop within
  `max_stop_distance_pct`, at a similar per-trade mean in a crude 26-week proxy (+5.0 % vs +7.1 % placed; > +50 %
  tail 6.3 % vs 5.1 %).

The proxy has no ranking, capital or trailing stops, so it cannot say whether the extra tickets beat the current picks
for a slot. That is what this backtest measures. The stop stays structural (book Ch. 6: no automatic percentage stops);
only which correction anchors it changes.

Prior record: the 08-16 Nearest grid (`dev/experiments/nearfloor-confirmation-grid-2026-08-16/`, memory
`project_nearfloor_is_risk_not_return`) did not promote Nearest: 0 of 3 cells cleared their null on return, with a real
loss on top-3000 × 2010–2026. That grid predates `require_structural_stop`. With the gate off, Nearest only tightens
stops on tickets that would be placed anyway. With the gate on, it also turns skips into entries, which is a different
mechanism. The 08-16 finding (a crash-depth dial whose effect depends on deep prior lows in the window) is a standing
prior against it.

## Design

- **Arm SN** = path-stability arm S (`../path-stability-2026-10-23/specs/ps-S-p0.sexp`: the record N body, Seeded tie
  order, 2019-01-01 → 2024-12-31, top-3000 pit-v12 schedule) plus one override:
  `((stops_config ((support_floor_anchor_scope Nearest))))`. The spec differs from ps-S-p0 by that line, the name, the
  description and the header comment.
- **Null** = path-stability S, already run: 6 cells, same build (`3db869d32`), same warehouse, same lists (md5
  `51fba79e…`), same five deleted names (SHEN, ODFL, SLAB, DECK, DIOD), same seeds (pk sets `tiebreak_seed k`).
- **K = 6** SN cells: p0 unperturbed, and p1–p5 delete the null's k-th name with `tiebreak_seed k`. Names are copied from
  the null, never re-chosen.
- **Validity.** SN p0 is gated on `validator_diff -check V6` against the null's A-p0, and each SN pk against SN p0, as in
  the null's chain. An excluded cell is dropped and named.
- **Cost.** 6 cells; the null's S cells took 2,360–2,863 s and its SC cells 3,013–3,606 s, so about 4–6 h, alone in the container.

## Metrics and decision rule (written before any SN run)

Per arm over its included cells: spread = sample SD of ln(1 + R); median ln(1 + R), Sharpe, max DD and Calmar.
Null values (path-stability `summary.txt`, 2026-10-24): spread(S) = **0.2108**, median ln(1 + R) = **1.0313**, median
max DD 23.29 %, median Calmar 0.674.

1. **Liveness first.** From SN p0's trade audit, counting top-N decision outcomes only (`(outcome ...)` in
   `cascade_summaries`, not the re-listings in each placed entry's `alternatives_considered`): skipped
   `No_structural_stop` ≤ 0.75 × 5,078 = 3,808 **and** `Placed` > 190 (S p0's counts). If SN p0 is excluded or failed,
   liveness is n/a and nothing is read. If either condition fails, the mechanism did not do what the screen predicted. The run is recorded as "not live as
   screened", with no return read, and the next step is to find out why.
2. **Return.** Δ = median ln(1 + R)(SN) − median ln(1 + R)(S), with the bar b = spread(S) = 0.2108.
   - Δ ≥ +b → **PROMISING**: escalate to a new pre-registration covering 26 y plus a pre-2009 cell
     (`promotion-confirmation.md`; the 08-16 lesson makes the pre-2009 / crash-depth cell mandatory). Not a promotion.
   - Δ ≤ −b → **NO-BUILD decision** for this lever at this window. The dial stays default-off as an axis.
   - otherwise → **INCONCLUSIVE**: no escalation on return.
3. **Do-no-harm on PROMISING.** If median max DD(SN) − median max DD(S) > 100 × b pp, the result reads "PROMISING
   with a DD cost": a user decision, not an automatic escalation. Calmar is reported beside it. At this window the
   DD bar is loose (21 pp), so the median max DD and Calmar are also reported on their own.
4. **Reported, not decision-bearing:** spread(SN)/spread(S); how many of the 36 SN × S cross pairs SN wins; the
   divergence onset of each SN pk; the review-pack signals of SN p0; the tail (trades above +100 % total return per
   cell and the top trade's share of P&L), read from the committed `trades.csv`. Also a cohort read of SN p0 vs S p0
   joined on `symbol|entry_date`: trades in both, SN only (the converted skips) and S only, with count and P&L each.
5. **Cell floor:** `summary` applies the rule only with ≥ 4 included cells in each arm; otherwise it reports n/a.

**Power, said up front.** With n = 6 per arm and spread 0.21, the standard error of a difference in medians is about
0.15, so the bar b = 0.21 is about 1.4 SE. Only a large effect can register. An INCONCLUSIVE result does not show that
Nearest has no effect. The cells cannot be paired: every SN pk diverges from its null partner within weeks (the null's
divergence onsets are all in Feb–May 2019), so the comparison is between unpaired distributions.

**Window caveat.** 2019–2024 reuses the null and contains the 2020 V and the 2022–23 round trip, but not 2025 (the
year that motivated this) and nothing before 2009. Escalation exists to cover both.

## How to run

```sh
PREREG=<this commit> sh dev/experiments/floor-nearest-2026-10-25/chain.sh launch   # reuses .claude/worktrees/sweep-ps @ 3db869d32
tail -f /tmp/fn-run/chain.log
sh dev/experiments/floor-nearest-2026-10-25/chain.sh summary /tmp/fn-run/results   # S rows from NULL_DIR (default /tmp/ps-run/results)
sh dev/scripts/perf_long_cells.sh update /tmp/fn-run/chain.log
```

`chain.sh` is `../path-stability-2026-10-23/chain.sh` cut down to one arm. Its header lists the changes: the null's
build, names and lists are asserted at launch, there are separate stage, work, fixtures and output dirs, and the
summary reads S from `NULL_DIR` and applies the rule above. It was checked with `sh -n`, `dash -n` and
`posix_sh_check.sh`. `summary` was also run on the null's own SC cells relabelled as SN, which exercises the arithmetic
only: it read "NO-BUILD", as SC's numbers imply.

## Arm SM (second stage, blocked): a monthly universe refresh

The yearly May 31 list freezes the universe for 12 months. Live trading screens whatever is liquid now. In the same
screen, a monthly top-3000 (same 60-day dollar-volume rule) had 13 % of members outside the yearly list in force. These
entrants have a lower median 12-month forward return (−0.5 % vs +6.1 %) but hold 29 % of all > +300 % 12-month moves
(AXTI enters at 2025-09; the yearly lists never admit it). Pre-registered here so that the rule predates any SM run:

- **Arm SM** = S with `universe_schedule` holding a dated top-3000 list at every month end (1999-05-31 → 2025-12-31),
  built by the same builder and post-processing as pit-v12 (the dollar-volume rank, the equity filter, the #3391
  twin-drops). Everything else is S's.
- **Prerequisites (each a PR, before any SM run):**
  1. A dates option on the list builder (`build_composition_universes_runner` anchors at May 31 today, though
     `Build_from_individuals.build ~date` takes any date).
  2. A reproduction check: the builder's May 31 output must equal the committed pit-v12 yearly lists byte for byte, so
     the monthly lists differ from the yearly ones only by date.
  3. A warehouse whose manifest covers the union of the monthly lists, with the chain's set-equality check.
- **Perturbations:** the same five names, cut from every monthly list; same seeds.
- **Rule:** the same as SN's (liveness, then Δ against spread(S), do-no-harm, the same caveats). Liveness for SM: at
  least one SM p0 trade in a symbol outside the yearly list in force on its entry date.
- **Amendment 2026-10-25 (after the SN read, before any SM list, warehouse or run exists):**
  - **Displacement read.** SN showed this book is cash-bound: every admitted ticket displaces one. For each SM cell vs
    its paired S cell, report (a) *entrants*: SM placements in symbols outside the yearly list in force; (b)
    *displaced*: S placements absent from the SM cell, counted at the decision (S Placed where SM reads Insufficient_cash, as for SN) and,
    separately, by the symbol + entry-date join, which mixes in path effects; (c) the realised ln(1+R) of each set, as n, mean, median,
    p10/p90 and the share above +100 %. This is descriptive. It explains the Δ and does not change the rule above.
  - **Twin drops on monthly lists.** Year Y's pit-v12 twin drops apply to every monthly list dated in
    [Y-05-31, Y+1-05-31). Symbols that appear only in monthly lists also go through the twin detector, and its drops
    are committed with their evidence (prerequisite 3). *Revised 2026-10-25 by the dispatcher, before any SM list
    exists:* both legs of a confirmed pit-v12 pair can co-occur in a monthly list whose yearly list in force holds
    only one leg (CMN and CMD in `top-3000-2009-04-30`, the 2008 window). The dropped leg therefore leaves **every**
    monthly list that holds both legs of a confirmed pair, whatever the window; cells where the yearly list in force
    also holds both legs are pit-v12's own state and stay, so each May 31 list still equals its yearly list.
    `twin-cooccur-unhandled.txt` must come out empty.
  - **Lists not committed.** The 320 monthly lists (~130 MB) are not committed. `composition.md5`,
    `composition-raw.md5` and `twin-drops-monthly.txt` are, and `dev/scripts/build_monthly_universe_warehouse.sh`
    rebuilds the lists and the schedule from the committed inputs, aborting unless they match the md5 files byte
    for byte.

### How to run SM

```sh
PREREG=<commit holding chain-sm.sh> sh dev/experiments/floor-nearest-2026-10-25/chain-sm.sh stage-lists  # optional host-only dry run
PREREG=<commit holding chain-sm.sh> sh dev/experiments/floor-nearest-2026-10-25/chain-sm.sh launch       # reuses .claude/worktrees/sweep-ps @ 3db869d32
tail -f /tmp/fsm-run/chain.log
sh dev/experiments/floor-nearest-2026-10-25/chain-sm.sh summary /tmp/fsm-run/results   # S rows from NULL_DIR (default /tmp/ps-run/results)
sh dev/scripts/perf_long_cells.sh update /tmp/fsm-run/chain.log
```

## Results


**NOT LIVE as screened** (rule step 1, read as pre-registered at 97b6daa99 with the 06:57 PT amendment). SN p0 skipped
4,822 top-N decisions as `No_structural_stop`, 0.950 × S p0's 5,078; the bar was ≤ 0.75 × (3,808). Placed rose to 238
(> 190), so the second condition passed. Step 2 is not applied: no return verdict is read from these cells.

The bar was set about four times stricter than the screen's own per-decision conversion. Nearest converted 5.0 % of the
skips; the screen's own output predicted 6.7 %. The arm still sits below S, and the reason is cash, not the stop gate.
In each pair, 217–235 of S's skips become stop-bearing decisions in SN. About half of these hit `Insufficient_cash`,
and the 87–100 that place take cash from S's own tickets: 39–58 S placements per cell are refused for cash in SN.
Those include the window's tail names: APPS, MMYT and GLNG at the decision, and ADMA and MSTR at the fill.

Paths. `results/` is this directory's results, the SN cells collected by the amended `chain.sh` (source `/tmp/fn-res2`).
`null/` is `../path-stability-2026-10-23/results/`, the S cells. These are byte-identical to `/tmp/ps-run/results`: 42 of
42 per-cell files were compared. `read/` is `results/read/`, written by `read/fn-analysis.sh`. That script regenerates
every derived table below except `read/screen-floor-breakdown.txt` (a static extract of the screen session's uncommitted output) from `results/` and `null/`, plus the raw trade audits, which are not committed
(`.sweep-output/{floor-nearest,path-stability}/ps-*-trade_audit.sexp`). `read/decisions/*.csv` holds the per-cell
top-N decisions reduced from those audits; `read/tickets/*.txt` holds each placed ticket with its outcome and P&L.

### The rule, as written

**Validity.** All six cells are on the null's build `3db869d32`, its lists (md5 `51fba79e…`) and its warehouse (9,236
symbols, `n_symbols_absent=1`, MEL) (`results/chain.log`, lines 1 and 6, and every RESULT line). `validator_diff -check
V6` exits 0 for SN p0 against the null's A-p0 (`results/ps-SN-p0-s0.v6diff-A0.log`). It also exits 0 for each SN pk
against SN p0 (`results/ps-SN-p{1..5}-s0.v6diff-SN0.log`). The chain log reads 6 RESULT, 0 EXCLUDED and 0
failed/void.

**Step 1, liveness (decision-bearing).** These counts are top-N decision outcomes only, never the
`alternatives_considered` re-listings. The sources are `results/ps-SN-p0-s0-audit_outcomes.csv` and `read/liveness.txt`.

| cell | `No_structural_stop` | × S p0 | Placed | Insufficient_cash | Sized_to_zero |
|---|---:|---:|---:|---:|---:|
| S p0 (README) | 5,078 | 1.000 | 190 | 131 | 59 |
| **SN p0** | **4,822** | **0.950** | **238** | 316 | 76 |
| S p1–p5 | 5,073–5,101 | | 169–180 | 128–156 | 54–60 |
| SN p1–p5 | 4,837–4,866 | 0.953–0.958 | 236–249 | 265–304 | 74–77 |

NSS ≤ 3,808 fails, and Placed > 190 passes. The result is **NOT LIVE as screened**. Each of the six cells would also
fail.

**Step 2, return: not applied.** The figures below are from `results/summary.txt` and are reported as description. They
carry no verdict. The summary's mechanical line, "NO-BUILD decision for this lever at this window", applies only if
step 1 reads LIVE, so it is not the result.

| arm | n | spread SD ln(1+R) | median ln(1+R) | median Sharpe | median max DD | median Calmar |
|---|---:|---:|---:|---:|---:|---:|
| S | 6 | 0.2108 | 1.0313 | 0.8377 | 23.29 % | 0.6744 |
| SN | 6 | 0.1435 | 0.6240 | 0.5325 | 28.51 % | 0.4089 |

- Δ median ln(1+R) = −0.4073, 1.9 × the bar b = 0.2108. Scaled per year, that is 18.8 %/yr for S and 11.0 %/yr for SN on
  the median cell. SPY total return over the same dates is +158.4 %, about 17.1 %/yr (`read/regime-split.txt`).
- Paired by seed, which is not the pre-registered read, SN minus S is −0.047, −0.287, −0.178, −0.339, −0.496 and −0.644.
  The mean is −0.332 and the SD 0.215 (`read/paired.txt`).
- Max DD by pair is mixed: SN is higher in p0, p1 and p3 and lower in p2, p4 and p5. The values are 17.1/32.3,
  20.3/32.9, 32.3/29.3, 22.9/25.4, 23.7/22.3 and 38.0/27.7 (S/SN; `read/paired.txt`).

**Step 3, do-no-harm:** n/a. It applies only on PROMISING. **Step 5, cell floor:** 6 included cells in each arm.

**Step 4, reported and not decision-bearing.**
- **Spread.** spread(SN)/spread(S) = 0.68. With K = 6 per arm, this cannot be told apart from 1.
- **Cross pairs.** SN beats S in 3 of the 36 cross pairs (`results/summary.txt`).
- **Divergence onsets.** SN pk diverges from SN p0 on 2019-02-26, 05-09, 02-28, 02-26 and 02-28 (`results/summary.txt`).
  These are the null's own onsets, set by the seed and the deletion (`null/summary.txt`). SN pk diverges from S pk (same
  seed, same deletion) on 2019-06-03 in five pairs and on 2019-04-15 in p4 (`read/paired.txt`). The first decisions
  that differ are S `No_structural_stop` → SN Placed: CHDN 2019-05-17 in p0 (filled 2019-06-03, closed +25.3 %) and
  MSTR 2019-03-15 in p4 (`read/transitions.txt`). Pairing by seed therefore holds the path only for the first three to
  five months.
- **The tail** (`read/paired.txt`, from `trades.csv` and `actual.sexp`). Trades with `pnl_percent` > 100 number
  2/4/4/3/4/5 per S cell and 2/4/3/2/3/3 per SN cell. The top trade's share of realised total-return P&L is 43–62 % in S
  and 52–184 % in SN; the 184 % is SN p0, whose realised total is only $81k. The return rests on open positions in both
  arms: end unrealised is $532k for S p0 and $734k for SN p0.
- **Cohort read, SN p0 vs S p0, joined on `symbol|entry_date`** (`read/paired.txt`):

  | cohort | trades | P&L in S | P&L in SN |
  |---|---:|---:|---:|
  | in both | 95 | +$258k | +$267k |
  | SN only | 93 | | −$186k |
  | S only | 55 | +$96k | |

  The other pairs have the same sign. SN-only is −$32k to −$322k in every pair, and S-only is +$37k to +$611k in every
  pair. This join leaves out open positions and mixes converted skips with path effects. The decision-level classes in
  §Why separate them.
- **Review-pack signals:** see §Review-pack look.

### Was the liveness bar consistent with the screen?

**No. It was mis-set relative to the screen's own prediction.** The pre-registered verdict stands as written: NOT LIVE as
screened.

- **What the screen measured.** It ran per decision over the 26-year record N s0 audit: 20,165 `No_structural_stop`
  skips with ≥ 160 bars of history (`read/screen-floor-breakdown.txt`, from the session's `floor_out.txt`).
  - The W90 replica admits 1,415 of them (7.0 %).
  - N90 admits 2,771 (13.7 %).
  - N90 admits and W90 does not in 1,356 (6.7 %). That is the Nearest increment.
  - The memory's figure, 1,148 / 20,177 = 5.7 %, is the same quantity after the screen's fill-within-5-bars filter
    and its one-per-182-days dedupe.
- **What the bar required.** NSS ≤ 0.75 × S means at least 25 % of the skips must convert. That is 3.7 to 4.4 times
  the screen's conversion. Even the 13.7 % upper bound is about half the bar. The upper bound assumes every skip the
  replica falsely admits would also convert.
- **Where a 0.75 bar does fit.** It fits the README's "about 8× more tickets get a structural stop" if that is read as a
  per-decision multiplier. Under that reading, 8 × S p0's 382 stop-bearing decisions would cut NSS to about 0.47 ×.
- **What the 8× actually is.** It compares two cohorts after the filters: 1,148 filled Nearest admissions of skips
  against 138 filled W90 admissions of placed tickets. It is new tickets relative to placed tickets, not a share of
  skips. And about 517 of the 1,148 are skips the W90 replica already admits.
- **What was observed.** NSS fell 5.0 % on SN p0. On the same decision (same Friday, same symbol), 4.3–4.7 % of S's skips
  became stop-bearing in every pair (`read/transitions.txt`). That is the screen's prediction, slightly under it.

### The verdict, calibrated

- **What this run establishes.** At 2019–2024 on top-3000 pit-v12, `support_floor_anchor_scope Nearest` under
  `require_structural_stop` converts about 5 % of structural-stop skips. That is what its own screen predicted, and it is
  below the pre-registered bar. Per the rule, the run is recorded as not live as screened, with no return read.
- **What it cannot claim.**
  - It does not reject Nearest, and it is not a NO-BUILD decision by rule.
  - It says nothing about 26 years, about pre-2009 crash depth (the 08-16 grid's axis), or about 2025, the year that
    motivated it.
  - It says nothing about a book with slack cash.
- **The dial's classification is unchanged.** It stays default-off as an axis: REJECT-as-default-but-legitimate-axis
  since 08-16, not do-not-revive (`memory/project_nearfloor_is_risk_not_return`).
- **The descriptive return gap is consistent in sign.** SN is below S in 6 of 6 seed pairs and in 33 of 36 cross pairs.
  The decomposition below makes it a traced result rather than an untraced delta. Most of its size, though, is a few
  tail names.

### Why

**1. Why `No_structural_stop` barely moved: Nearest turns "no floor" into "floor too far."** On the screen's 20,165
skips, the share with no qualifying correction falls from 67.1 % (W90) to 4.9 % (N90). The share whose floor sits more
than 15 % below the entry rises from 25.9 % to 81.3 % (`read/screen-floor-breakdown.txt`). For a name at a fresh high,
the nearest ≥ 8 % correction usually lies under the whole advance. After Nearest, the §5.1 15 % gate ("prefer other
candidates") is the binding reason for a skip.

The few names that do convert sit at the gate's edge. Of the converted trades, 33 % have a decision stop ≥ 14 % from E,
against 18 % of the trades both arms took. Their mean size at fill is 8.6 % of NAV, against 9.8 %
(`read/cohorts.txt`). This edge is also where V12 comes from (§Defects).

**2. What the extra tickets were, and where the cash went.** These figures compare the two arms on the same decision
(`read/transitions.txt`).

- **The net +48 on p0 is two flows.**
  - SN placed 115 tickets that S did not: 91 converted skips, 17 that were `Insufficient_cash` in S, and 7 names absent
    from S's list that week.
  - SN did not place 67 that S placed. 58 of them hit `Insufficient_cash`, 5 were not in SN's list that week, and 4 had
    another outcome.
- **Across the six pairs.** About 217–235 converted decisions per cell divide into 87–100 placed (39–46 %), 99–127
  `Insufficient_cash` (46–54 %) and 15–16 `Sized_to_zero`. 39–58 of S's placements per cell, 24–32 % of those SN also
  decided, become `Insufficient_cash` in SN.
- **When the displacement happens.**
  - 10–18 per cell come after a converted SN placement earlier in the same week's list.
  - 20–47 are carry-over: the cash is already in positions SN opened in earlier weeks.
  - Fill-time cash refusals are 15–31 per SN cell against 9–14 per S cell (`results/ps-SN-p*-s0-cash_rejections.txt`,
    `null/ps-S-p*-s0-cash_rejections.txt`).
- **The top-20 cut is not what moved.** The stop is checked after the cut, and the weekly lists differ only where the
  holdings differ: 74 of S p0's 5,460 decisions are absent from SN p0's lists.
- **The book is cash-bound before Nearest adds anything.** S already logs 128–156 `Insufficient_cash` decisions per cell
  (`read/liveness.txt`). Average invested is 63.1 % on SN p0 against 59.2 % on S p0; §5 gives the regime split.

**3. Why the descriptive return is lower.** Per pair, the NAV gap splits by what the other arm did on the same decision.
The residual is ≤ $4k (`read/decomposition.txt`; $k). The two displaced/S-only columns show minus S's P&L on those
tickets.

| pair | ΔNAV | shared tickets, SN − S | converted skips (SN) | S cash → SN placed | other SN-only | displaced (−S P&L) | other S-only (−S P&L) | Δ interest |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| p0 | −91 | −48 | +159 | −59 | +165 | −284 | −3 | −20 |
| p1 | −809 | −300 | +149 | 0 | −57 | −612 | +45 | −31 |
| p2 | −419 | −571 | −180 | +25 | +271 | +48 | +14 | −30 |
| p3 | −663 | −24 | −136 | +54 | −2 | −513 | −8 | −34 |
| p4 | −1,196 | −263 | −157 | −12 | −7 | −748 | +27 | −35 |
| p5 | −1,581 | −736 | −152 | +75 | +101 | −900 | +79 | −46 |
| sum | −4,759 | −1,942 | −317 | +83 | +471 | −3,009 | +154 | −196 |

Three mechanisms, in order of size:

- **Displacement, the cash re-draw: −$3.0M pooled.** It is positive for S in 5 of 6 pairs. It is mostly three tail
  names that S funded and SN could not:
  - APPS 2020-06-12 in p3, p4 and p5 (+$387–395k each, +526 %);
  - MMYT 2023-10-06 in p1, p4 and p5 (+$501–536k open at the end, +203 %);
  - GLNG 2022-02-04 in p0 (+$134k).

  Without MMYT and APPS, the displaced cohort's mean drops from +10.4 % to +0.4 %, and its P&L from +$3.01M to +$0.27M
  (`read/cohorts.txt`). This channel is a lottery over which tail name finds cash.
- **Shared tickets: −$1.9M pooled.** Of this, −$1.09M is mostly the same trades held smaller. SN's NAV is lower when
  they open, and sizing is a fixed share of NAV. APPS sits at 7.0–7.1 % of NAV in both arms, ADMA at 9.9–10.4 % and MMYT
  at 14.4–15.0 % (`read/tickets/`). The total P&L ratio SN/S on trades both arms filled is 0.70–0.99. The other
  −$0.92M is tickets both arms placed that only S could fund at the fill: ADMA in p2 (−$518k) and MSTR in p5 (−$427k)
  (`read/decomposition.txt`).
- **Converted skips: −$0.32M pooled, −$0.94M without IONQ.** Without IONQ the cohort is negative in every cell, at
  −$110k to −$206k per cell. IONQ 2024-10-25 is the one converted monster: +178 % and open, +$269k in p0 and +$355k in
  p1. In p2–p5 it was itself refused for cash. Pooled over the six cells (`read/cohorts.txt`):

  | cohort | n | mean | median | p10 | p90 | > +50 % |
  |---|---:|---:|---:|---:|---:|---:|
  | converted skips | 447 | −1.4 % | −4.3 % | −13.9 % | +10.4 % | 1.6 % |
  | converted, ex IONQ | 445 | −2.3 % | −4.3 % | −13.9 % | +9.6 % | 1.1 % |
  | shared, S side | 605 | +8.3 % | −5.1 % | −12.7 % | +28.8 % | 6.8 % |
  | shared, ex ADMA and APPS | 599 | +4.6 % | −5.2 % | −12.7 % | +24.7 % | 5.8 % |
  | displaced, ex MMYT and APPS | 212 | +0.4 % | −3.3 % | −12.1 % | +19.7 % | 1.9 % |

  The medians agree. The gap is in the upper half. Stop exits cost about the same: −9.8 % for converted against −8.7 %
  for shared. The laggard-rotation exits average +5.0 % against +24.4 %. Converted trades are held 51 days on average,
  against 77. By decision year, the converted cohort lost $723k in 2021, $292k in 2022 and $286k in 2023, and made
  $1,031k in 2024, IONQ included. The cohort is regime-sensitive, not uniformly bad.
- **Perturbation.**
  - The cells overlap: 28 of the 165 converted decisions occur in all six cells, and 66 in only one.
  - So the six cells are partly six draws of path noise around one set of converted names in one window. They are not
    six windows.
  - The cohort split survives dropping the top name from each side: converted ex IONQ −2.3 %, against shared ex ADMA
    and APPS +4.6 %. Its dollar size does not.

**4. Events traced end to end** (`read/tail-traces.txt`; audit fields from the raw trade audits; positions from
`trades.csv` and `open_positions.csv`).

- **MMYT, p1/p4/p5.**
  - Nearest admitted KD on 2023-09-01, with S `No_structural_stop`: E 17.30, stop 14.71 (15.0 %), $90k. It filled
    09-11 at 17.32.
  - It admitted ANET on 09-08, also S NSS: stop 5.0 % below E, a 14 %-cap position of $186k. It filled 09-18.
  - On 2023-10-06 SN held 7 names including both, and MMYT was `Insufficient_cash`.
  - S placed MMYT at E 36.89 with a 4.1 % stop. It was $258k in p1, filled 10-26 at 37.64 and was +203 % open at the
    window end.
  - KD stopped out 10-13 at −15.3 % and ANET 10-26 at −6.9 %. The cash came back one to three weeks after the only week
    MMYT carried a structural stop.
- **APPS, p3.**
  - Converted NVDA (04-03), CABO (05-01) and ASND (05-22), with LACO (entered 05-27), filled SN's book to 10 names; ATRC's 05-08 ticket was refused at the fill (`entry_fill_rejected_by_portfolio`).
  - On 2020-06-12 APPS was `Insufficient_cash`; S, holding 7 names, placed it.
  - On 06-19 Nearest admitted APPS again. Where S decided APPS that week (p0), it was `No_structural_stop`: a fresh
    high.
  - That ticket's trigger was E = 9.17, against a 10.38 close. The stock's lowest low over the next year was 10.17
    (`data/` bars), so the ticket expired unfilled after 53 weeks (`entry_ticket_ttl_expired`).
  - The same sequence holds in p0, p4 and p5. In p0, S also lacked cash.
- **GLNG, p0.** On 2022-02-04 SN p0 held three conversions: WTRG (15.0 % stop), TRNO (14.4 %) and CWK (13.9 %), $285k of
  entry notional. GLNG was `Insufficient_cash`. S p0 placed it: +70 %, +$134k, exited 2022-11-28. The three
  conversions closed at −10.6 %, −3.0 % and −3.0 %. In 2022 the NAV gap grew by $245k. Over the same year, S realised
  +$169k on three tickets SN could not fund, GLNG among them, and SN realised −$91k on 13 conversions
  (`read/paired.txt`). The year returns are −5.1 % for S and −23.0 % for SN.
- **ADMA, p2.** Both arms placed ADMA on 2023-08-18. After 17 weeks of rest, SN p2 could not fund it at the fill: $166,731
  required against $149,362 available (`results/ps-SN-p2-s0-cash_rejections.csv`; see the #3420 caveat on
  `available`). S p2 made +$518k (+300 %).
- **IONQ, p0/p1, the converse.** S skipped IONQ on 2024-10-25 (fresh high, no floor after it). Nearest found a floor 10.1 %
  under E = 15.57, and SN placed a $147k ticket. It filled 10-29 at 15.89 and was +178 % open at the end. This is the
  shape the screen hoped for: a converted fresh-high monster. It reached cash in 2 of 6 cells.

**5. Exposure is read against market condition** (p0 pair; review-pack NAV with invested %, SPY regime on the 30-week MA
with its slope, lagged one week; `read/regime-split.txt`).

| period | regime | days | invested S / SN | return S / SN | SPY |
|---|---|---:|---:|---:|---:|
| 2019–2021 | UP | 603 | 66.2 % / 75.2 % | +49.3 % / +35.6 % | +49.4 % |
| 2019–2021 | DOWN | 79 | 43.6 % / 48.1 % | +10.9 % / +14.4 % | +47.5 % |
| 2019–2021 | all | 756 | 61.4 % / 69.5 % | +48.2 % / +39.8 % | +99.7 % |
| 2022 | DOWN | 150 | 36.3 % / 24.6 % | +2.8 % / −9.0 % | +7.2 % |
| 2022 | all | 251 | 45.0 % / 37.2 % | −5.1 % / −23.0 % | −18.2 % |
| 2024 | UP | 251 | 84.5 % / 86.6 % | +23.1 % / +54.4 % | +25.3 % |
| 2019–2024 | all | 1,508 | 59.2 % / 63.1 % | +96.0 % / +87.0 % | +158.4 % |

SN's gap opens while it is *more* invested: 2019–21 UP days, 75.2 % against 66.2 %. It widens in 2022 on *less*
exposure, 24.6 % against 36.3 % on DOWN days. Neither is a cash effect; the holdings differ (`read/cohorts.txt`, p0 by
decision year).
- **Decided 2019–21.** S made +$104k on tickets SN could not fund. SN's conversions made −$51k and its cash swaps −$78k.
- **Decided 2022.** S had GLNG (+$134k); its five other displaced 2022 tickets never filled. SN's conversions made
  −$70k.
- **Decided 2024.** The rebuild leans on SN's conversions, +$320k, of which IONQ is +$269k.

Only the p0 packs exist, so the pk cells have no exposure series.

**6. Why the screen's per-trade parity did not carry over (check 1, the estimand gap).** Cut to 2019–2024, the screen's
own cohorts *favoured* the converts: N90-only skips +6.0 % over 26 weeks with 8.4 % above +50 %, n=285. W90 placed
tickets made +1.9 % (6.1 %), n=33 (`read/screen-floor-breakdown.txt`). Realised in the arm, the converts made −1.4 %
against +7.7 % for shared trades.

The screen's estimand was a 26-week hold with a fixed stop at floor × 0.96. It had no cash, no rank order, no trailing
stop and no laggard rotation. The arm's converts rest as stop-limit tickets, compete for cash, and are rotated out as
laggards after a mean 51 days. The README warned the proxy could not say whether the extra tickets beat the current
picks for a slot. On this window they mostly do not, and they take the slot.

**7. Two smaller observations.**

- **The 08-16 tightening channel is nearly absent with the gate on.** On trades both arms took, 83–90 of 89–97 per pair
  have the same initial stop. Nearest tightens 4–6 per pair, and loosens 2 in p1 (`read/paired.txt`). The arm's
  signature is the opposite of 08-16's "fewer trades, longer holds, lower DD":
  - 1.25–1.43 × as many trades (`actual.sexp`: 180–194 against 132–150);
  - shorter holds (64–70 days against 71–81);
  - the same win rate (29–34 %);
  - drawdown mixed across pairs.

  This confirms the README's premise: with the gate on, Nearest acts through admission and is a different mechanism.
- **Nearest is not a superset of `Window_extreme`.** 4–5 decisions per cell flip the other way, S stop-bearing → SN
  `No_structural_stop`, with the same names in every cell: GOGO 2020-09-11, IZEA 2021-01-22, CVM 2021-02-12, OLN
  2021-04-09, SDA 2023-06-16 and OKLO 2024-11-08 (`read/decisions/`).
  - In each, E sits well under the price, and Nearest anchors on a drop of a few days that ends at the price. OKLO's
    floor is 24.28 from a one-day 10.4 % drop, against a close of 24.47 and E ≈ 18.89 (recomputed from `data/` bars and
    the NSS record's fallback level).
  - So the floor sits above E and no valid stop exists.
  - A one-bar "correction" is a weak anchor in book terms. Here it happens to veto stale-E tickets: SDA lost $17.6–24.5k
    in every S cell (`null/ps-S-p*-s0-trades.csv`).

### How it fits what we know

- **`project_floor_and_refresh_screens`: contradicted on two points, refined on one.**
  - Contradicted: "8× more tickets" does not hold. The decision-level conversion is 5–7 %.
  - Contradicted: per-trade parity reverses in the backtest. Converts −1.4 % against shared +7.7 %; > +50 %: 1.6 %
    against 6.6 %.
  - Refined: the binding reason after Nearest is the 15 % gate (81 % of floors are beyond it).
  - The memory's "worth a real 26y test" should carry this result.
- **`project_nearfloor_is_risk_not_return` (08-16): refined.** Its risk signature came from tightening stops on tickets
  placed anyway, with the gate off. With the gate on, that channel touches about 5 % of shared trades, and Nearest acts
  through admission. The crash-depth "why" is untested here: there is no pre-2009 data.
- **`project_record_gap_is_concentration`: confirmed.** "Wider admission funds more candidates, which dilutes every
  position." The average trade is 10.7–13.3 % of NAV against 13.1–17.3 % (`summary.sexp` `avgtradesizepct`). p0 holds
  6.2 positions against 5.3 (pack). The same monsters are held at the same weight on a smaller NAV, or not at all.
- **`project_top_n_capacity_verdict` (ledger `2026-09-22-top-of-funnel-capacity.sexp`): confirmed shape, refined sign.**
  Widening the funnel on a capital-bound book re-draws the slots. The top-N arm's sign flipped with salt. Here it is
  negative in 6 of 6 seeds. One difference is that Nearest's extra names are also weaker on the body: −2.3 % against
  +4.6 % mean, without the top names.
- **`project_monster_funnel_top_of_funnel`, `project_path_stability_seeded_noise`: confirmed.** Past gate 1
  (`No_structural_stop`), gate 2 (cash) binds. The window's return is the few tail trades the path-stability read named
  (ADMA, APPS, GLNG, open MMYT). SN loses exactly these to cash in 5 of 6 pairs.
- **`project_edge_is_the_fat_tail`: confirmed from a new side, and refined.** A lever that touches no winner can still tax
  the tail, through cash. The tail names must find cash in their decision week, and more tickets chasing the same cash
  fund them less often and smaller. "Entry quantity" is tail-preserving only when capital is slack.
- **`project_recovery_reentry_gap` (10-18, "NSS is mostly no floor"): confirmed and extended.** With a floor supplied,
  the skip becomes "floor > 15 %". Far anchors exist in every year, for floors as for tops.
- **`project_max_stop_filters_structural_stops`: confirmed.** Support floors cluster at the gate (33 % of conversions are
  ≥ 14 %).
- **`project_concentration_deploy_probe_reject`: its forward guidance is refined.** It said "the next entry-side screens
  widen the funnel". Two funnel-widening reads (top-N, and Nearest under the gate) now behave as cash re-draws.
- **Applied: `feedback_perturb_before_believing_a_cohort_split`.** Without its top two names, the displaced cohort's
  edge vanishes. The converted cohort stays negative.

### What it implies next

These are options. The choice is the user's.

1. **Stop here for SN (the honest default).** Record NOT LIVE as screened plus the why.
   - Do not escalate to the 26y + pre-2009 pre-registration. Nothing PROMISING was read, and the why does not point
     there.
   - Nearest stays default-off as an axis. Its 08-16 classification is unchanged, and retirement (R4) is not supported.
2. **The question behind SN is still open, but not through the stop anchor:** how to catch fresh-high names like IONQ
   and AXTI.
   - After Nearest, the gates are the §5.1 15 % rule, which is faithful and where the book says "prefer other
     candidates", and cash.
   - The only remaining freedom is which admitted ticket gets the cash: slot-fill ordering
     (`project_top_n_capacity_verdict`).
   - The record says ranking has no skill (`project_entry_selection_closed_powered`), so the prior is low.
3. **Arm SM (monthly refresh, pre-registered, blocked on three prerequisite PRs) is the same class of lever.** It adds
   candidates to a capital-bound book.
   - If it is built, read it with the displacement cohort (null placed → arm `Insufficient_cash`) and a tail-name
     ledger, as here.
   - Its liveness rule (≥ 1 trade outside the yearly list) is easy to pass, and cannot be changed now.
   - Its one possible advantage is a fatter entrant tail: the screen puts 29 % of > +300 % rows among entrants. Whether
     those names reach cash is the open question.
4. **Process, for the next pre-registration.**
   - Derive a liveness bar from the screen's per-decision output (here about 0.93 × NSS), not from a cohort ratio.
   - For any funnel-widening arm, pre-register the displacement count beside the conversion count.

### Defects found

Each defect is listed with its specimens; none of them changes the SN − S comparison.

- **V12 edge drift is a basis mismatch, not a Nearest bug.** The dispatcher's reading is confirmed and refined.
  - The 15 % gate is measured from E (`sim_entry_trigger_at_suggested`). V12 compares the installed stop with the fill,
    and stop-limit fills land up to 2 % above E.
  - SN V12 counts are 32/27/25/29/23/30. Of the edge cases, 17–26 per cell are converted skips; the rest are tickets S
    also takes (`read/v12.txt`). S counts are 8/4/5/4/3/5.
  - Specimens (decision distance → fill distance, from `trades.csv`):
    - KD 2023-09-11: E 17.30, stop 14.707, 14.99 % → 15.08 %, fill 17.32.
    - XEL 2020-01-27: 14.32 % → 15.29 %.
    - TXNM 2020-02-03: 14.84 % → 16.51 %.
  - Proposal: V12 should measure from E, as the gate does, or allow the stop-limit band. Candidate for #3420.
- **#3420 item 1, both directions.**
  - False FAILs: SNX 2020-11-09 (0.7628) in SN p1 and S p1, and NEE 2020-10-21 (2.4577) in SN p3/p5. There are none in
    SN p0.
  - A false PASS, a new specimen: AAON-wein-508 (SN p0) and AAON-wein-307 (S p0). Decided 2023-03-17, filled
    2024-02-15 at 83.43 after 47 weeks. The live stop is 55.48, 33.5 % under the fill. `stop_initial_distance_pct` 0.0025,
    `stop_fill_distance_pct` 0.0026 and the audit's `installed_stop` 83.21 all read the pre-split decision level, so V12
    misses it. The pack's check 11 counts it (33 against V12's 32).
  - The rested trigger itself is the #3075 class. Its fix, `cancel_resting_entry_on_split` (#3108), is off in this
    spec.
- **A phantom force-liquidation record.** `force_liquidations.sexp` logs a `Per_position` event for SIRI-wein-526 on
  2023-07-25 at `current_price` 5.13, the close, with `entry_price` 6.88. On the same bar, `trades.csv` closes that
  position at 5.96, the open: `stop_loss`, `gap_down`, stop 6.31, fill 6.94.
  - `actual.sexp` counts the event (`force_liquidations_count 1`). P&L follows the trade row.
  - The same appears in every SN cell (SIRI), and in every S cell (SIRI, plus SDA 2023-07-13: event at 8.18, trade exit
    10.44).
  - Likely cause, to check: the breaker evaluates at the close a position the trigger-bar stop already closed.
- **A buy filled from above, in the null.**
  - S p0 SDA-wein-319 was decided 2023-06-16 with E = 11.56 (`suggested_entry`) against a close of 21.97. That is the
    pre-pump SPAC range, under `entry_extension_max_pct 2.0`.
  - It filled 2023-07-12 at 11.79, on a bar with open 14.15 and low 11.55: a stop-limit buy executed on the way down of
    a −17 % day. It exited next day for −$17.6k. It is present in all six S cells.
  - The pack's "Filled from above" detector reads n/a, so it cannot see this.
- **V13 rounding and V7.**
  - V13 flags cent-rounded fills: KD 2023-09-11 at 17.32 against a bar high of 17.319, and AXIA 2021-05-24 at 9.96
    against a low of 9.9638. This is beside #3420's delisting rows (MIME, BMCH); the V13 fix should carry a tolerance.
  - V7 rises from 1 (S p0) to 7 (SN p0). Five of the seven are converted skips: PCOR, NVEE, KD, ELF and BLD. This is the
    known short-history `Virgin_territory` class (`project_false_virgins_load_bearing`), surfaced more often because
    Nearest admits more fresh-high names.

### Review-pack look

Published pack (SN p0): https://claude.ai/artifact/WfWi4Za7HENMKE4nKuKmSs. The S p0 null pack is https://claude.ai/artifact/Vm8SLjNXLGQ8y2nqMVdSZX (#3419).

The pack read here is `.sweep-output/review-ps-SN-p0/render/top.png` and `part-1..15.png`. For the paired comparison,
`review-ps-S-p0/render/top.png` and `part-1.png` were also read. What was checked:

- **Window.** 2019-01-02 → 2024-12-30, and every chart spans it.
- **KPIs against `results/ps-SN-p0-s0-actual.sexp`.** All match: +87.0 %, CAGR 11.0 %, max DD −32.3 % (2021-05-07 →
  2023-10-27), Sharpe 0.54, Calmar 0.34, 188 trades, win 29.3 %, average hold 67 d, 7 open.
- **Yearly table against `equity_curve.csv`.** It matches: +2.2 / +27.9 / +7.0 / −23.0 / +12.5 / +54.4 %. Average
  invested, 63 %, matches the regime split's 63.1 %.
- **Config-implied zeros.**
  - Fallback stops: 0 of 188, as `require_structural_stop` implies.
  - Stops breached before the exit day: 0. All 60 unraised stop exits fill the same day, as
    `sim_stop_exit_fill_on_trigger_bar` implies.
  - "Initial stop wider than 15 %": 0, measured from E.
  - Placements in a Bearish week: 0. The audit shows 26 Bearish weeks with no decisions.
  - The three fills after a Bearish screen (V23: SLB, ISEE, CIB) are resting tickets, which
    `entry_ticket_macro_suspend` off allows.
- **Text.** No mojibake, `NaN` or empty panels. Wide tables are cut at the panel edge in the render: the missed-winner
  reasons, the career-scorecard citations and the per-trade "All checks" column. `part-15` overlaps `part-14` because the
  last slice is clamped to the page end. Both are cosmetic.
- **Odd rows, traced.**
  - V12 = 32 and the pack's check 11 = 33: see §Defects (edge drift, plus AAON).
  - V7 = 7: converted skips.
  - SIRI's one-day −14.1 % loser: the phantom force-liquidation record.
  - V13's KD and AXIA: cent rounding.
- **What the pack's signals said** (RV3):
  - *Eras vs SPY:* eroded 2019–23 to 0.59 ×, built 2024 to 0.72 ×. Confirmed and refined. Against S p0, which was
    eroded 2019–21 to 0.74 × and held 2022–24, SN's extra erosion is mostly 2022 (GLNG, conversions). The 2024 rebuild
    leans on 2024 conversions, +$320k, of which IONQ is +$269k.
  - *"Mostly in cash through rebounds":* rejected as SN's cause relative to S. SN was more invested in 2019–21 and less
    invested but losing in 2022 (§5).
  - *Return rests on open positions:* $734k unrealised against $16k closed. Confirmed. MMYT +$296k and IONQ +$269k, a
    conversion, are 77 % of it.
  - *Entries cancelled at the fill for cash:* 26, against 9 in S p0. Confirmed, and central to the why.
  - *51 D/F losers that later moved ≥ 15 % the trade's way (−$504k):* S p0 has 39 (−$427k). The rate is about the same,
    27 % against 26 %. Not a Nearest effect.
  - *0 fallback stops, 0 late stop fills, 3 gate reopens with none flagged, and the fill-week volume caveat (180/188):*
    confirmed. They are the same as in S p0 and not Nearest effects.
  - *Worst three-year stretch, 2019–21, +39.8 % against SPY +99.7 %:* confirmed. S p0 made +48.2 %.

No pack defect needs a fix in `dev/lib/review_pack/`. A detector for "filled from above", the SDA case, is the one gap
the pack cannot see today.

### Ledger (one line)

2026-10-25 floor-nearest — NOT LIVE as screened (no return read; ledger entry `_ledger/2026-10-25-floor-nearest.sexp`, #3428): SN (Nearest under `require_structural_stop`, top-3000 pit-v12 2019–24, K=6) cut NSS to 0.950 × S against a ≤ 0.75 × bar mis-set versus the screen's own 6.7 % conversion (Placed 238 > 190); why: Nearest turns "no floor" into "floor > 15 %", and its ~5 % conversions re-draw cash in a cash-bound book (39–58 S tickets displaced per cell, incl. APPS/MMYT/GLNG, ADMA/MSTR at the fill; converts −2.3 % ex IONQ against shared +4.6 %); descriptive Δ median ln(1+R) −0.41, 6/6 seeds negative; the dial stays a default-off keep-axis and is not escalated.

`Verifies: none`. The #3420 [after-merge] item concerns the path-stability cells, not this run.

## Results, arm SM (monthly universe refresh)

**INCONCLUSIVE.** This is the rule as pre-registered at d97f94937: SN's rule, SM's own liveness test and the 2026-10-25 displacement amendment.
- **Liveness passes.** 19 of 150 SM p0 closed trades are in names outside the yearly list in force, and all 19 are outside it at the decision too.
- **Return.** Δ median ln(1+R) is −0.193 against a bar of ±0.211, so there is no escalation on return.
- **The lean.** It is negative and traced, but it does not reach the bar.

**Paths.**
- `sm/` is `results/sm/`: the six SM cells as `chain-sm.sh collect` wrote them, from `/tmp/fsm-run/results`. 120 files were compared. All are identical except `chain.log`, whose committed copy adds the final DONE line.
- `null/` is `../path-stability-2026-10-23/results/`. It is byte-identical to the `/tmp/ps-run/results` the chain read (42 of 42 S files compared).
- `read/decisions/` holds the S top-N decisions from the SN read.
- `sm/read/` holds the extracts below, written by `sm/read/sm-analysis.sh`. Its inputs are:
  - the directories above;
  - the committed yearly lists;
  - the 320 staged monthly lists. They are not committed, and each matches `trading/test_data/backtest_scenarios/pit-v12-monthly/composition.md5`;
  - `data/`, for the 2024-12-30 marks and month-end closes;
  - the two p0 review packs.
- The per-decision annotation `annot.txt` (4.1 MB) is not committed; `sm-analysis.sh` regenerates it. The raw trade audits are not committed either (`.sweep-output/floor-refresh-sm/`).

**`sm/summary.txt` is a re-run.**
- The chain's default `S_DEC_DIR` (`chain-sm.sh` line 91) resolves to the parent working copy. That copy sat on a base older than the SN read and had no `results/read/decisions/`. So the chain's own summary could not compute "displaced at the decision".
- The summary was re-run with `S_DEC_DIR` pinned to this tree. The committed `sm/summary.txt` is that re-run.
- `chain-sm.sh summary results/sm`, run with `NULL_DIR`, `S_DEC_DIR` and `YEARLY_DIR` on committed paths, reproduces it line for line. Only the three paths in its header change.

### The rule, as written (arm SM)

**Validity.**
- All six cells ran on the null's build `3db869d32` (`sm/chain.log`, line 1). They used the 320 monthly lists at md5 `d0c7f724…` and the null's five deletion names (`sm/perturb-names.txt` and the PERTURB lines).
- `validator_diff -check V6` exits 0 for SM p0 against the null's A-p0 (`sm/ps-SM-p0-s0.v6diff-A0.log`). It also exits 0 for each SM pk against SM p0 (`sm/ps-SM-p{1..5}-s0.v6diff-SM0.log`).
- The chain log reads 6 RESULT, 0 EXCLUDED and 0 failed/void.

**Step 1, liveness (decision-bearing): LIVE.** The test is "at least one SM p0 trade in a symbol outside the yearly list in force on its entry date" (`sm/summary.txt`).

| cell | closed trades outside the yearly list, by fill date | of those, also by decision date |
|---|---:|---:|
| S p0, p2, p3, p5 | 0 | 0 |
| S p1, p4 | 1 (TRTX, decided 2021-05-28, filled 2021-08-17) | 0 |
| **SM p0** | **19 of 150** | **19** |

- **Both dates.** The 10-26 Log entry asked for both. The fill-date test is the pre-registered one. Re-testing at the decision removes the null's roll-only TRTX passes and keeps all 19 SM passes.
- **Closed trades only.** Open positions change nothing. None of SM p0's 7 open positions is outside the yearly list, and no entrant is open at the end in any cell (`sm/summary.txt`: "open at the end 0" in all six pairs; `sm/read/tickets.txt`).
- **Fill date against decision date.** Classified at the decision, SM p0 placed 26 entrant tickets, and 21 filled. Two of them fell inside the next yearly list by their fill date, which is why the fill-date count is 19:
  - GSHD, decided 2019-05-24 and filled 06-06;
  - USAC, decided 2023-10-13 and filled 2024-08-02.

**Step 2, return: INCONCLUSIVE** (`sm/summary.txt`).

| arm | n | spread SD ln(1+R) | median ln(1+R) | median Sharpe | median max DD | median Calmar |
|---|---:|---:|---:|---:|---:|---:|
| S | 6 | 0.2108 | 1.0313 | 0.8377 | 23.29 % | 0.6744 |
| SM | 6 | 0.1489 | 0.8384 | 0.6851 | 28.79 % | 0.4464 |

- **Δ = −0.1929.** The bar is b = 0.2108, so −b < Δ < +b. The result is INCONCLUSIVE, with no escalation on return.
- **Per year.** The median cell compounds at 18.8 %/yr in S and 15.0 %/yr in SM. SPY total return over the window is +158.4 %, about 17.1 %/yr (`sm/read/regime-split.txt`).
- **Per cell.** ln(1+R) for p0–p5 is 0.878 / 0.799 / 0.539 / 0.735 / 0.937 / 0.918 in SM and 0.673 / 1.177 / 0.945 / 0.837 / 1.118 / 1.203 in S.

**Step 3, do-no-harm: n/a.** It applies only on PROMISING. Reported on their own, as the rule asks: median max DD is +5.50 pp higher in SM (the DD bar is 21.08 pp), and median Calmar is 0.446 against 0.674.

**Step 5, cell floor:** 6 included cells in each arm.

**Step 4, reported and not decision-bearing.**
- **Spread.** spread(SM)/spread(S) = 0.71. With K = 6 per arm, this cannot be told from 1.
- **Cross pairs.** SM beats S in 8 of 36.
- **Divergence onsets.**
  - SM pk leaves SM p0 on 2019-02-26, 04-15, 05-09, 02-26 and 04-15 (`sm/summary.txt`).
  - SM pk leaves S pk (same seed, same deletion) on 2019-02-28 in p0 and p2, and on 2019-06-06 in the other four (`sm/read/same-data.txt`).
  - The first placements that differ are:
    - SPSC 2019-02-15 in p0 and p2. S placed it, and two entrants pushed it out of SM's top-20 (§Why 6 below).
    - 2019-05-24 in the other four pairs. SM placed the entrant GSHD in all four; S placed the leaver JBSS in p1 and p3 (`sm/read/transitions.txt`).
  - Pairing by seed therefore holds only for the first two to five months.
- **Paired by seed (not the pre-registered read).** SM − S is +0.204, −0.377, −0.406, −0.102, −0.181 and −0.286. The mean is −0.191 and the SD 0.225 (`sm/read/step4.txt`).
- **The tail** (`trades.csv`, `pnl_percent` > 100).
  - Trades above +100 %: 3/3/2/3/4/4 per SM cell, against 2/4/4/3/4/5 per S cell.
  - The top trade's share of realised total-return P&L is 51–81 % in SM and 43–62 % in S.
  - End unrealised P&L is $586k on SM p0 and $532k on S p0 (`actual.sexp`).
- **Cohort read, SM p0 against S p0, joined on `symbol|entry_date`** (`sm/read/step4.txt`):

  | cohort | trades | P&L in S | P&L in SM |
  |---|---:|---:|---:|
  | in both | 113 | +$487k | +$472k |
  | SM only | 37 | | +$266k |
  | S only | 37 | −$134k | |

  p0 is the one pair SM wins. In p1, p3, p4 and p5 the SM-only cohort is −$94k to −$216k (+$44k in p2). In p1–p5 the S-only cohort is +$49k to +$898k.

**Displacement read (the amendment; descriptive).** Closed trades, ln(1+R) with R = (pnl + dividends) / (entry price × quantity), pooled over the six pairs (`sm/summary.txt`):

| set | n | mean | median | p10 | p90 | > +100 % |
|---|---:|---:|---:|---:|---:|---:|
| (a) entrants | 114 | −0.039 | −0.078 | −0.136 | +0.139 | 0.0 % |
| (b) displaced at the decision (S Placed, SM `Insufficient_cash`) | 73 | +0.041 | −0.055 | −0.111 | +0.193 | 2.7 % |
| (b) S-only by the symbol + entry-date join | 184 | +0.031 | −0.038 | −0.117 | +0.195 | 2.2 % |
| SM-only by the same join (reference) | 258 | −0.016 | −0.050 | −0.136 | +0.115 | 0.4 % |

Per pair (`sm/summary.txt`):

| pair | entrant placements / SM placed | entrant closed trades | displaced at the decision (their closed S trades) | S-only by join |
|---|---:|---:|---:|---:|
| p0 | 26 / 191 | 19 | 24 (14) | 37 |
| p1 | 22 / 191 | 17 | 8 (6) | 27 |
| p2 | 26 / 196 | 21 | 21 (17) | 34 |
| p3 | 25 / 190 | 21 | 27 (17) | 39 |
| p4 | 25 / 187 | 19 | 23 (14) | 32 |
| p5 | 23 / 193 | 17 | 11 (5) | 15 |

The summary leaves five parts to the analyst (`sm/read/tickets.txt`, `sm/read/cohorts.txt`):
- **Open marks.** No entrant is open at the end. Nine displaced S tickets are, CVNA, BBW, TCOM and VCYT among them. With their 2024-12-30 marks, the displaced set is n = 82, median −0.039, p90 +0.289.
- **Displaced tickets that never filled.** 32 of the 114 displaced decisions never filled in S either: 14 were still resting at the end, 10 expired and 8 were refused at the fill. Their displacement cost nothing.
- **Entrants refused for cash.** 40 entrant decisions read `Insufficient_cash` (5–10 per cell), and 13 entrant tickets were refused at the fill.
- **The displaced tail.** The two > +100 % displaced trades are one name, APPS 2020-06-12, in p2 and p5.
- **Path effects.** The decision-class decomposition (§Why 2 below) separates path effects from the join.

### Same data, different warehouse

SM ran on `/tmp/snap_top3000_pit_v12monthly`: 10,125 symbols, with `n_symbols_absent=1` (MEL). S ran on `/tmp/snap_top3000_pit_v12wk`, with 9,236. Below is what the change could move, and what it did (`sm/read/same-data.txt` unless noted).

- **Shared names read the same bars.** On 637 trades both arms hold with the same symbol, entry date and exit date (100–117 per pair), these all agree exactly:
  - entry price and exit price;
  - `pnl_percent` and `entry_stop`;
  - dividends per share.
- **Shared decisions read the same stops.** Both arms made 29,696 decisions on the same Friday and symbol. On these, the stop gate and the sizer never disagree. The only flips are (`sm/read/transitions.txt`):
  - cash: 140 `Insufficient_cash` → `Placed` and 114 the other way;
  - share class: 5.
- **The NAVs agree to the cent** on every common date until 2019-02-28 (p0, p2) or 2019-06-06 (p1, p3–p5).
- **The macro inputs are identical.** `macro_trend.sexp` is byte-identical in all six pairs. `params.sexp` differs only in `universe_size`: 9,222 against 10,111.
- **The calendar gains two empty steps.**
  - Every SM equity curve has rows for 2019-01-01 and 2020-01-01 that S lacks: 1,563 rows against 1,561, and `n_steps` 1,563 against 1,561.
  - They come from USAS, a name in no yearly list. Its `data/` file has $0.0001, volume-0 rows on those holidays.
  - The 2019-01-01 row reads $1,000,063.89, which is one day of cash interest. S books the same two days at its first step: the 2019-01-02 NAV is $1,000,126.95 in both arms.
  - So the rows move no dollars. They can touch only daily-return statistics (Sharpe, volatility), through two extra near-zero returns among 1,562.
  - USAS was never decided or traded. The rows are a calendar effect of the warehouse, not a mechanism effect. They did break the first pack render (§Review-pack look, arm SM).
- **One guarded event on an SM-only name.** `split_dividend_guard rejected=1` appears in every SM cell and in no S cell (chain log, GUARDS lines). The split detector misread a dividend on a name S never reads, and the guard rejected it, which is the protective path (#3173). The log does not name the symbol (§Defects found, arm SM).

The warehouse change adds two empty steps and one guarded event on an SM-only name. Nothing on a shared name moved. The SM − S difference is the universe, and the cash paths it sets off.

### Was the SM liveness test consistent with the screen?

Yes, and it is a weak test by design: the SN read noted that "≥ 1 trade outside the yearly list" is easy to pass.
- The arm places 22–26 entrant tickets per cell, against the null's base rate of 0–1 roll-only passes.
- Entrants are 7.2 % of SM's top-20 decisions (379–398 per cell).
- They are 8.8 % of member-months in this window (`sm/read/entrant-funnel.txt`). The screen's 13 % is a 26-year figure.
- So entrants reach the top-20 at slightly below their share of the list. The arm did what the screen predicted at the decision level.

### The SM verdict, calibrated

- **What this run establishes.** At 2019–2024 on top-3000 PIT, a monthly list refresh is live. It does not raise the median return.
  - The descriptive lean is negative: Δ = −0.193, with S above SM in 28 of 36 cross pairs and 5 of 6 seed pairs.
  - Δ is 0.92 b and about −1.3 SE, at the pre-registered SE of 0.15. By rule it is INCONCLUSIVE.
- **What it cannot claim.**
  - It is not a NO-BUILD decision, and it does not show that the refresh hurts: Δ did not reach −b.
  - About 70 % of the pooled NAV gap is seven tail names: where each found cash, and at what size (§Why 2 below). That is the path noise of `project_26y_path_noise_floor`, even though every dollar of it is traced.
  - It says nothing about 2025 or AXTI, whose entrant month (2025-09) is outside the window. It says nothing before 2009, and nothing about a book with slack cash.
- **What the why supports.** The entrants the refresh adds realise worse than what they displace, and the refresh adds no tail trade to the book. Together these make a positive effect at this window unlikely. But they rest on about 30 distinct entrant tickets, and on a funnel trace rather than on P&L.

### Why (arm SM)

**1. What the refresh changes in the decision flow** (per cell; `sm/read/transitions.txt`).
- **Entrants come in.** About 7 % of SM's top-20 decisions are entrants: names in the month-end list but not in the yearly list in force.
- **Leavers go out.** About 4.5 % of S's decisions (241–250 per cell) are leavers: names the yearly list still holds but the current month-end list has dropped.
- **The top-20 cut re-draws.** The Seeded tie order hashes each name separately (`screener_ranking.mli`). So an entrant inserts into the order and pushes the bottom names out, and a leaver frees a slot.
  - 245–278 S decisions per cell are cut from SM's top-20.
  - 128–147 SM decisions are on names that S's top-20 did not reach.
- **Placements.**
  - S's 169–190 placements per cell go, in SM, to: 128–155 the same, 8–27 `Insufficient_cash`, 6–9 leavers, 3–16 cut and 0–2 held.
  - SM's 187–196 placements come from: the same 128–155, 22–26 entrants, 14–32 tickets S could not fund, and 1–6 cut gains.
- **Entrants convert more often.** 6.6 % of entrant decisions place (26 of 395 on p0), against 3.5 % of all decisions (191 of 5,486). They are also `Sized_to_zero` more often: 18–20 per cell, out of SM's 62–71.
- **Cash at the fill is tighter.** SM refuses 11–17 tickets per cell for cash at the fill, against 9–14 in S; pooled, 89 against 72 (`cash_rejections.txt`).

**2. Where the NAV gap comes from** (`sm/read/decomposition.txt`; $k; the residual is within $8k per pair).

| pair | ΔNAV | seven tail names, SM − S | entrants (SM) | other tickets, SM − S | Δ interest | ln(NAV_SM/NAV_S) |
|---|---:|---:|---:|---:|---:|---:|
| p0 | +444 | +454 | +15 | −31 | +10 | +0.204 |
| p1 | −1,019 | −596 | −109 | −286 | −27 | −0.377 |
| p2 | −858 | −903 | +6 | +67 | −26 | −0.406 |
| p3 | −224 | −72 | −140 | +3 | −7 | −0.102 |
| p4 | −507 | −191 | −116 | −185 | −13 | −0.181 |
| p5 | −827 | −792 | −90 | +83 | −27 | −0.286 |
| sum | −2,991 | −2,100 | −434 | −349 | −90 | |

The seven tail names are every trade above +100 % in either arm (APPS, ADMA, BBWI, MMYT, DXCM, MSTR), plus GLNG (+70 %). The gap splits into three parts, in order of size.

- **The tail lottery: −$2.10M pooled, 70 %.** It turns on which arm's cash catches each tail name (`sm/read/tail-ledger.txt`, `sm/read/step4.txt`).
  - APPS 2020-06-12 (+526 %): S funded it in 5 cells and SM in 4. SM gained it in p0 and lost it in p2 and p5, worth $378–387k each time.
  - ADMA 2023-08-18 (+300 %): S had it in 4 cells and SM in 3. SM p2 was refused at the fill after 17 weeks of rest: $131,637 required against $91,928 available (`sm/ps-SM-p2-s0-cash_rejections.csv`). S p2 made +$518k.
  - BBWI 2020-07-31 (+138 %): S had it in 6 cells and SM in 5. SM p1 was refused at the fill for $146: $114,950 required against $114,804 available (`sm/ps-SM-p1-s0-cash_rejections.csv`). `available` is gross cash, per #3420. S p1 made +$162k.
  - MMYT and DXCM reach both arms in all six cells. GLNG reaches SM in all six and S in five (S p2 lacks it).
  - The rest of this term is size. The same tail trades are a fixed share of NAV in both arms: ADMA 10.0 %, MMYT 14.4–14.7 %. So they are smaller in dollars wherever SM's NAV is already lower. That is −$0.62M pooled on tickets both arms filled.
  - In p3 and p4, both arms caught the same tail names, and SM still trails by 0.10 and 0.18. That residue is the entrants' own losses plus the size effect. In the other four pairs, one or two tail names decide the sign.
- **The entrants' own trades: −$434k pooled, 15 %.** They lose $90k–$140k in four cells. They are about zero in p0 and p2, where BMA found cash (+$127k and +$92k).
  - Scaled, that is about −$12k a year per cell, about −0.8 % a year of SM's $1.45M average NAV.
- **Everything else: −$349k, plus −$90k of interest.** These classes are small:
  - leavers made +$8k for S over 45 placements;
  - cut names made +$29k for S and +$49k for SM.
- **Displacement is mostly carry-over.** 0–5 of the 8–27 cash-displaced S tickets per pair came after an entrant placement in the same week's list. Most came after earlier weeks' positions had already taken the cash (`sm/read/step4.txt`).

**3. Entrants are worse than what they displace** (`sm/read/cohorts.txt`; filled or open tickets, ln(1+R), pooled).

| set | n | mean | median | p10 | p90 | > +50 % | > +100 % |
|---|---:|---:|---:|---:|---:|---:|---:|
| entrants | 123 | −0.032 | −0.072 | −0.136 | +0.115 | 1.6 % | 0.0 % |
| entrants ex BMA | 121 | −0.044 | −0.072 | −0.136 | +0.115 | 0.0 % | 0.0 % |
| displaced at the decision (S side, incl. 9 open) | 82 | +0.052 | −0.039 | −0.111 | +0.289 | 3.7 % | 2.4 % |
| displaced ex APPS | 80 | +0.008 | −0.043 | −0.111 | +0.201 | 1.2 % | 0.0 % |
| shared, S side, ex ADMA, APPS, MMYT | 670 | +0.010 | −0.049 | −0.132 | +0.223 | 5.5 % | 1.9 % |

- **Median and p90.** The median gap is 2–3 pp of trade return, inside overlapping interquartile ranges. The p90 gap is larger: +0.115 for entrants, against +0.20 to +0.29 for what they displaced and +0.22 for the body of the book.
- **Perturbed.** The sign survives each of these:
  - dropping the top name on each side (BMA; APPS);
  - testing entrants by fill date instead of decision date (median −0.078, `sm/summary.txt`);
  - dropping the open marks (displaced median −0.055).

  The dollar size does not survive: without APPS, the displaced cohort's P&L falls from +$963k to +$189k.
- **The cohort is small.** The six cells place only 35 distinct entrant tickets. 18 are placed in all six cells, and 30 filled somewhere. At the book's tail rate, 30 tickets would hold well under one trade above +100 % even if entrants matched the book. So "no entrant tail trade" proves nothing by itself, and §5 answers the tail question instead.

**4. Why entrants realise worse: they are volume spikes.** A name enters a monthly dollar-volume list because its recent dollar volume jumped. The breakout screen rewards the same spike.
- **Breakout volume.** `entry_volume_ratio` (`trades.csv`) for entrants has a median of 4.6×, p75 12.0× and p90 33.9×. For SM's other trades it is 2.5×, 3.1× and 4.3× (`sm/read/cohorts.txt`).
- **Exits.**
  - Entrants exit at the stop more often: 65 % of trades, against 56 % for shared trades.
  - They are held 45 days against 75.
  - Their laggard-rotation exits make +12.8 %, against +25.5 %.
  - Size at fill is the same: 10.5 % of NAV against 9.9 %.
- **Forward returns.** Entrants' 12-month forward returns are wider on both sides (`sm/read/entrant-funnel.txt`):
  - median −11.2 % against +4.4 % for members;
  - p10 −74 % against −45 %;
  - p90 +81 % against +68 %.

  The stop takes the left side. §5 shows how rarely the right side arrives.

**5. Why the entrant tail does not reach the book** (`sm/read/entrant-funnel.txt`). The screen's premise holds in this window: entrants are 8.8 % of member-months but 18.3 % of > +300 % 12-month rows (14.9 % without a ≥ 50 % one-day move). The funnel stops them.
- **The population.** 60 distinct names had a > +300 % 12-month move starting in a month when they were entrants, with no ≥ 50 % day.
- **Most never reach a top-20.** 45 never reached any SM cell's top-20 in the following 12 months. 21 of the 60 had under a year of trading history at the time. Examples are 2019 listings such as ZM (first bar 2019-04-18), NET, CRWD and PTON.
- **Those that do are skipped.** 15 reached a top-20 in at least one cell:
  - 11 read only `No_structural_stop`: FSLY, JMIA, NET, PRPL, GNMK, FLGT, SI_old1, AEHR, VERA, FNMA and KC;
  - CLDX read `No_structural_stop` or `Insufficient_cash`;
  - CAVA and HSAI read `Sized_to_zero`;
  - BMA was placed (§6).
- **Members meet the same funnel.** 67 of 227 member names with such a move reached S p0's top-20 (30 %), and 3 were placed. For entrants on SM p0 the figures are 12 of 60 (20 %) and 1 placed.
- **The gates.** The refresh widens the list. What reaches cash is decided by the top-20 cut and the structural-stop gate.

**6. Events traced end to end** (positions from `trades.csv`, decisions from the regenerated `annot.txt`, bars from `data/`).
- **The first divergence: SPSC, p0 and p2.**
  - On 2019-02-15, GFF and ICAGY sit 3rd and 10th in SM's top-20. Both are in the 2019-01-31 monthly list and not in the 2018 yearly list.
  - S's last two names that day, FNOX and SPSC, are not in SM's list. S placed SPSC, which filled on 2019-02-28.
  - 2019-02-28 is the first date the paired NAVs differ. The SPSC trade itself made −$1.5k, but it moved the cash path.
- **APPS 2020-06-12: p0 gains it, p2 and p5 lose it.**
  - On SM p0, MOH (decided 2020-04-24) had been refused at the fill. SM p0 held 8 names, S p0 held 10 (MOH $152k and ASND among them), and only SM p0 could fund DECK and APPS that Friday. SM p0 made +$378k.
  - On SM p2 and p5, the cash sat in LACO and AKAM. These are ordinary names that S had refused for cash or at the fill. S funded APPS, for +$387k in each cell.
  - None of the names that held the cash was an entrant. A candidate-set change re-draws whose cash is free.
- **TRT, the entrant round trip, in all six cells.**
  - TRT was decided 2021-12-03. It is in the 2021-11-30 monthly list and in no yearly list for 2020–21. Its breakout volume was 247.9×.
  - It filled 2021-12-06 at 7.62 with a stop at 6.88, 8.8 % below. It closed 2021-12-31 at 13.43, +76 %.
  - The stop was never raised: there was no correction to trail.
  - It stopped out 2022-01-19 at 6.87, −9.9 %, for −$15k to −$20k per cell.
  - It added +$117k to +$153k to SM's 2021 year-end mark and took back −$132k to −$173k in January 2022 (`sm/read/years.txt`, `sm/read/y2022-positions.txt`).
  - This is most of SM's 2022 shortfall. In five pairs SM's 2022 is 8–12 pp worse than S's (−15 % to −19 % against −5 % to −8 %). The entrants' 2022 marks, −$183k to −$233k per cell, cover the whole gap, and TRT is most of those marks. Over its life the trade lost only $15k–$20k.
- **BMA, the one entrant monster that reached cash.**
  - BMA was in the monthly lists from 2023-09-30 and not in the 2023 yearly list. It was decided 2023-12-15.
  - It filled in p0 and p2 on 12-18 at 28.21 and had 5 stop raises. It was rotated out as a laggard on 2024-07-15 at 54.00: +91.4 % on price, +$127k total return on p0.
  - BMA closed 2024 at 96.76, +243 % over the fill.
  - It was refused for cash in p5. It was not in the top-20 in p1, p3 or p4.

**7. Exposure is read against market condition** (p0 pair; pack NAV with invested %, SPY regime on the 30-week MA and its slope, lagged one week; `sm/read/regime-split.txt`).

| period | regime | days | invested S / SM | return S / SM | SPY |
|---|---|---:|---:|---:|---:|
| 2019 | DOWN | 31 | 0.0 % / 0.0 % | +0.3 % / +0.3 % | +10.9 % |
| 2019 | all | 251 | 44.0 % / 39.4 % | +9.8 % / +6.8 % | +31.1 % |
| 2020 | UP | 175 | 74.5 % / 75.9 % | +20.5 % / +49.7 % | +5.9 % |
| 2020 | all | 253 | 72.5 % / 72.0 % | +18.3 % / +51.0 % | +18.3 % |
| 2021 | UP (all days) | 252 | 67.4 % / 76.8 % | +14.1 % / +20.3 % | +28.7 % |
| 2022 | UP | 14 | 88.2 % / 76.0 % | −7.9 % / −15.9 % | −7.8 % |
| 2022 | all | 251 | 45.0 % / 46.0 % | −5.1 % / −15.2 % | −18.2 % |
| 2023 | all | 250 | 41.7 % / 43.6 % | +13.3 % / +9.8 % | +26.2 % |
| 2024 | UP (all days) | 251 | 84.5 % / 86.1 % | +23.1 % / +33.1 % | +25.3 % |
| 2019–2021 | all | 756 | 61.4 % / 62.8 % | +48.2 % / +93.9 % | +99.7 % |
| 2022–2024 | all | 752 | 57.1 % / 58.6 % | +32.3 % / +24.0 % | +29.4 % |
| 2019–2024 | all | 1,508 | 59.2 % / 60.7 % | +96.0 % / +140.5 % | +158.4 % |

- **Exposure is never the difference.** It is within 1.5 pp over each three-year period. By year it is within 5 pp, except 2021 (76.8 % against 67.4 %).
- **Where SM p0 gains and loses.** Its lead is 2020's UP days (APPS) and 2024. It loses the first 14 trading days of 2022, which are UP days: TRT's collapse.
- **Coverage.** This is the pair SM wins. Only the p0 packs exist, so the pk cells have no exposure series.

### How SM fits what we know

- **`project_floor_and_refresh_screens`: confirmed in direction, refined in size and consequence.**
  - In this window, entrants are 8.8 % of member-months, not 13 %, and hold 18.3 % of > +300 % rows, not 29 %. Their median forward return is worse and their tail is fatter, as the screen said.
  - The memory said that if SM was built, a displacement count should be pre-registered. That was done, and it reads as a cash re-draw.
  - The new part: the entrant tail exists in the list but not in the book. 45 of 60 never reach a top-20, and 1 is placed.
- **floor-nearest SN (ledger `2026-10-25-floor-nearest.sexp`): the same shape at half the size.**
  - Entrants do not beat what they displace: median −0.072 against −0.039, and ex top name −0.044 against +0.008. SN's converts showed the same pattern (−2.3 % against +4.6 %).
  - SM adds 22–26 placements per cell, against SN's 87–100. Its cash-displaced count is 8–27, against 39–58. Its Δ is −0.19, against −0.41.
- **`project_26y_path_noise_floor` and `project_path_stability_seeded_noise`: confirmed.**
  - A candidate-set change moved the end NAV by 0.10–0.41 log per pair.
  - A $146 shortfall cost BBWI (+$162k), like FDX's $68.58 in the memory.
  - Cell level tracks tail capture: ADMA, APPS, BBWI, GLNG, MMYT, DXCM, MSTR.
- **`project_top_n_capacity_verdict` (ledger `2026-09-22-top-of-funnel-capacity.sexp`): confirmed again.** Widening the funnel of a capital-bound book re-draws the slots. Three funnel-widening reads now behave the same way: top-N 40, Nearest, and the monthly refresh.
- **`project_monster_funnel_top_of_funnel`: confirmed from the entrant side.** 80 % of entrant monsters die at the top-20, and those that pass mostly die at `No_structural_stop`.
- **`project_edge_is_the_fat_tail`: refined.** That memory lists "universe breadth (more shots at a monster)" as tail-preserving. That holds only if the shots reach a slot. List breadth adds volume-spike names that the top-20 cut and the stop gate filter out before cash.
- **`project_record_gap_is_concentration`: confirmed.** The same tail trades, at the same weight on a smaller NAV, cost −$0.62M pooled.
- **`project_2025_anatomy`: consistent.** Supply is not what limits the tail; the funnel is. 2025 itself is untested here.
- **`project_entry_selection_closed_powered`: consistent.** The top-20 cut lands inside a tie group, so which names make it is a seeded draw, and entrants enter that draw by hash.
- **`project_pit_universe_migration`, decision D1 (the May-31 anchor):** the anchor is not shown to bias the record at this window.
- **Applied: `feedback_perturb_before_believing_a_cohort_split`** (§Why 3 above).
- **No contradiction.** The SN read guessed that SM's "one possible advantage is a fatter entrant tail". There is a fatter tail in the list and none in the book.

### What SM implies next

These are options. The choice is the user's.

1. **Stop here for SM (the honest default).**
   - Record INCONCLUSIVE, with no escalation on return, by rule.
   - The yearly May-31 lists stay the record's universe.
   - Nothing in strategy code needs to be retired. The monthly lists and warehouse stay an available input.
   - The why gives no route to a positive effect at this window.
2. **A realism by-product.** Monthly lists move the median by −0.19 log, inside one null SD, and no tail name is lost to list membership itself. So the backtest's May-31 freeze is not shown to flatter or penalise the record at this window. That is one window.
3. **The tail question behind SN and SM is not a universe question.** It is how to catch fresh names like IONQ and AXTI.
   - The binding gates are the top-20 cut (a score tie group, in seeded order) and the §5.1 structural-stop gate, which is faithful.
   - The record says ranking has no skill.
   - The prior for a fourth funnel-widening lever is low.
4. **If 2025 matters.** AXTI's entrant month (2025-09) is outside this window. A 2025–26 SM cell would trace one name; it would not give a verdict. Low priority.
5. **Process, for the next universe or funnel arm.**
   - Pre-register the leaver and cut classes beside "displaced at the decision". The cash class held only 8–27 of the 20–49 S placements per cell that SM did not make.
   - Chain summaries should default to committed input paths and print the paths they read.

### Defects found (arm SM)

None of these changes the SM − S comparison.

- **Data: zero-volume sub-cent bars that become simulator steps.**
  - `data/U/S/USAS/data.csv` has rows at $0.0001 with volume 0 on US holidays. 2019-01-01 and 2020-01-01 are two of them.
  - USAS is in five monthly lists (2020-08-31, 2020-09-30 and 2025-10-31 to 12-31) and in no yearly list. Its rows add the two extra steps to every SM equity curve.
  - The class is wider: 163 of the 10,125 warehouse symbols have volume-0 bars at ≤ $0.001 in 2018–2024. None was traded in either arm.
  - Proposal: drop such rows at warehouse build, or keep zero-volume bars out of the simulator calendar.
- **Pack: SPY anchored on a holiday first row (fixed, #3445).** The first render (`.sweep-output/review-ps-SM-p0`, pack 3db869d32) had three errors:
  - SPY 2019 read 0.00 % (`p0_years.json`);
  - the eras read "built 2019–2020 (1.00→1.36×) … ends at 1.22×";
  - years beating SPY read 4/6.

  These contradict the KPI strip: +141 % against SPY's +158 % is 0.93×. The cause is the 2019-01-01 NAV row, which falls before SPY's first bar. It is fixed in #3445 and pinned in `review_pack_test.sh`.
- **Pack: the commit label is wrong in jj workspaces.**
  - The re-render's `manifest.json` says `"pack_sha": "6436d9a6f"`. That is the parent repository's HEAD, not the workspace (`.claude/worktrees/fix-rp`) that carries #3445.
  - `dev/lib/review_pack/pack_sha.sh` runs `git -C REPO rev-parse HEAD`, which resolves to the parent repository from a jj workspace. Its dirty check reads the parent's paths too.
  - So #3262's guard cannot flag a pack built from a jj workspace.
- **Chain: the summary defaults point outside the commit.**
  - `chain-sm.sh` line 91 defaults `S_DEC_DIR` to `$REPO/$EXP/results/read/decisions`, in the parent working copy, which here lacked the directory.
  - `NULL_DIR` defaults to `/tmp/ps-run/results`. The committed summary header names the `/tmp` paths.
  - The summary failed safely: the chain's own summary could not compute that column instead of guessing. But the defaults should be committed paths.
- **Guard log names no specimen.** `Panel_runner: split_dividend_guard rejected=1` (every `sm/ps-SM-p*-s0.log`) names no symbol or date, so the rejected event cannot be identified from the artifacts. Proposal: print the symbol, date and factor of each rejection.
- **Known classes, with entrant specimens.**
  - **CGEN, filled from above** (SM p2 `CGEN-wein-354`, SM p3 `CGEN-wein-359`).
    - Decided 2024-01-26 at a close of 2.21, with `suggested_entry` 1.50 (32 % under the close) and stop 1.488.
    - Filled 2024-07-05 at 1.53 after 23 weeks, on a falling bar: open 1.61, low 1.50.
    - Exited three days later as a `liquidity_exit`. This is the SN read's SDA class.
  - **USAC, a rested ticket.** Decided 2023-10-13, filled 2024-08-02 after 42 weeks (#3075 class).
- **Unchanged from the SN read, present here too.**
  - Phantom force-liquidation records: SDA 2023-07-13 and SIRI 2023-07-25 (`force_liquidations_count 2` in `sm/ps-SM-p0-s0-actual.sexp`).
  - SDA filled from above.
  - V13 delisting rows: MIME and LACO.
  - V12 edge drift: SM 9/5/8/6/9/7, against S 8/4/5/4/3/5.

### Review-pack look, arm SM

Published pack (SM p0): https://claude.ai/artifact/WgGuP4vAuYAEC5WBE3XNtT. The S p0 null pack is https://claude.ai/artifact/Vm8SLjNXLGQ8y2nqMVdSZX (#3419).

The pack read here is the #3445 re-render (`render/top.png` and `part-1..14.png`). The first render's `top.png` and S p0's `top.png` were also read. What was checked:

- **Window.** 2019-01-01 → 2024-12-30, and every chart spans it.
- **KPIs against `sm/ps-SM-p0-s0-actual.sexp` and `summary.sexp`.** All match:
  - +141 %, CAGR 15.8 %, max DD −24.3 % (2021-04-13 → 2023-10-27);
  - Sharpe 0.72, Calmar 0.65;
  - 150 trades, win rate 32.7 %, average hold 73 d, 7 open, profit factor 1.57.
- **Yearly table against `equity_curve.csv`.** It matches:
  - SM: +6.8 / +51.0 / +20.3 / −15.2 / +9.8 / +33.1 %;
  - SPY: +31.1 / +18.3 / +28.7 / −18.2 / +26.2 / +25.3 %;
  - average invested 61 % against the regime split's 60.7 %.
- **Config-implied zeros.**
  - Fallback stops: 0 of 150, as `require_structural_stop` implies.
  - Stop exits sold at a later open: 0, as `sim_stop_exit_fill_on_trigger_bar` implies.
  - "Stop breached before the exit day", "Initial stop wider than 15 %", "Fill outside the day's high–low" and "Fill on a non-trading day": all clear.
  - Placements in a Bearish week: 0. The 26 Bearish weeks have no decisions in any SM cell (`macro_trend.sexp`, the regenerated `annot.txt`).
  - The one fill after a Bearish screen, ISEE 2022-09-30 (V23), is a resting ticket, which `entry_ticket_macro_suspend` off allows.
- **Text.** No mojibake, `NaN` or empty panels. Wide tables are cut at the panel edge, and `part-14` overlaps `part-13`. Both are cosmetic, as in SN.
- **Found on the first render:** the SPY 2019 and eras defect (§Defects found, arm SM), now fixed. The re-render reads 0.93× and 3 of 6 years.
- **Odd rows, traced.**
  - TRT's give-back, +73 % peak open gain to −9.9 % (§Why 6 above).
  - CGEN, a fill from above.
  - SIRI −$28k, the phantom force-liquidation record.
  - V13: MIME and LACO, delisting exits.

**What the pack's signals said (RV3).**
- **Eras vs SPY: eroded 2019 to 0.81×, built 2020 to 1.04×, eroded 2021–24 to 0.93×.** Confirmed. S p0 eroded 2019–21 to 0.74× and held 0.76× through 2022–24. SM p0's whole lead is 2020: APPS. The year-end SM/S ratio goes 0.973 → 1.241 in 2020 (`sm/read/years.txt`).
- **"Eroded 2019: mostly in cash through rebounds" (DOWN days +0.3 % against SPY +10.9 % at 0 % invested).** Confirmed, and not an SM effect. S p0 reads the same, and the macro gate held both books out.
- **"Eroded 2021–2024: holdings lagged in UP days" (+40.5 % against +63.8 % at 72 % invested).** Confirmed and refined. Exposure matches S within 1.5 pp per period. The extra lag is 2022: TRT's give-back and five 2022 entrant stop-outs.
- **"Concentrated open gain before a drawdown":** APPS held $617,808 of open gain at the 2021-04-13 peak (30.9 % of peak NAV), and the NAV then fell 24.3 % to 2023-10-27. Confirmed. In 11 of the 12 cells across both arms, the max drawdown ends on 2023-10-27 (`sm/read/step4.txt`). The drawdown is the window's shape, and APPS sizes it on SM p0.
- **"Concentrated gains at NAV peak: n/a for 1 position."** That position is BBWI, on the 2021 spin-off basis (#3215 class). It is the same in S.
- **"Fill-week volume: 143 of 150 under 2×".** S p0 reads 144 of 150, so it is not an SM effect. It measures the fill week; the entrants' outlier is their breakout-week volume (§Why 4 above).
- **Gate reopens: 3, none flagged.** The macro series is byte-identical to S's.
- **"Entries cancelled at the fill for cash": 16, against 9 on S p0.** Confirmed, and central to the why (BBWI p1, ADMA p2); pooled, 89 against 72.
- **"Worst three-year stretch 2021–2023, +12.1 % against SPY +32.9 %".** Confirmed. 2022 carries TRT's give-back.
- **"Ten trades made $1.27M of the $679k realised total".** Confirmed. BMA (+$116k price P&L) is the only entrant among them.
- **0 fallback stops; 20 of 81 stop exits more than 0.5 % beyond the stop; 0 at a later open; 40 D/F losers moved the trade's way (−$509k).** Confirmed. The rate is S p0's: 39 trades for −$427k, per the SN read's §Review-pack look.
- **Average invested 61 %, 0 fills on a day with no bar, V13 = 2.** Confirmed.
- **A pattern the pack did not flag.** One position's year-end open gain carried a year boundary: TRT added about +9 pp to SM p0's 2021 and took about −9 pp from 2022. The year table cannot show this.
  - Proposed detector: flag a year whose return moves by at least 5 pp on one position's year-end open gain that the next year gives back.

### Ledger, arm SM (one line)

2026-10-26 floor-nearest arm SM: INCONCLUSIVE (rule applied, LIVE; ledger entry `_ledger/2026-10-26-floor-refresh-sm.sexp`). Design: monthly top-3000 universe refresh against path-stability S (top-3000 PIT, 2019–24, K=6, build 3db869d32). Result: Δ median ln(1+R) −0.193 against a bar of 0.211; SM wins 8 of 36 cross pairs; median max DD +5.5 pp; Calmar 0.45 against 0.67. Liveness: 19 of 150 SM p0 trades are outside the yearly list, against a null base rate of 0–1 (roll-only). Why: 70 % of the NAV gap is which arm's cash caught APPS, ADMA or BBWI (BBWI refused for $146). 15 % is the entrants' own trades (−$434k pooled): volume-spike names (median breakout volume 4.6× against 2.5×) that realise worse than what they displace (median −0.072 against −0.039), with 0 of 123 above +100 %. The entrant tail stops at the funnel: 45 of 60 > +300 % entrant names never reach a top-20, and 1 (BMA) is placed. No escalation; the yearly May-31 lists stay.

`Verifies: none`. No issue item is satisfied by this run.

## Log

- 2026-10-25 06:57 PT, before any SN artifact was read (the chain was in the SN-p0 preflight): qc-results (#3418)
  found that liveness counted every `No_structural_stop` token in the audit (8,302 on S p0). That figure includes the
  week's skips re-listed in each placed entry's `alternatives_considered`, which grow with Placed and pull against
  the second condition. Amended to decision outcomes only (S p0: 5,078 / 190). The bar ratio 0.75 is unchanged. The
  running chain was staged from 97b6daa99, so its own `summary.txt` uses the old count: `collect` and `summary` are
  re-run from this commit's `chain.sh` after the chain ends, and that output is the one read.
- 2026-10-26, before any SM list was staged by a chain or any SM cell ran: `chain-sm.sh` and `specs/ps-SM-p0.sexp`
  written (ps-S-p0 with its 27 yearly entries replaced by the 320 month-end lists; `universe_path` points at the first
  monthly list, which `scenario_runner` ignores under a schedule). The rule text above is unchanged. One property of
  the liveness test, recorded before the run: it reads `trades.csv` `entry_date`, the fill, so a ticket decided before
  a May 31 roll and filled after it in a name the new yearly list drops passes it. On the null's own S cells this
  happens once each in p1 and p4 (TRTX, decided 2021-05-28, filled 2021-08-17) and never in p0. `summary` prints this
  base rate beside SM p0's count, and re-tests each passing trade at its decision date, as description.
- 2026-10-26, after the SM chain ended (16:48 PT): `chain-sm.sh summary` re-run with `S_DEC_DIR` pinned to the committed
  `results/read/decisions` (the chain's default resolved to a parent working copy without it). The rule text is unchanged;
  the read is §Results, arm SM, written by a results-analyst pass from the committed artifacts. The first SM pack render
  carried a pack defect (SPY 2019 = 0 % on a holiday first NAV row), fixed in #3445 before the pack was read.
