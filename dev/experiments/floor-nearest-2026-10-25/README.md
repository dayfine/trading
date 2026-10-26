# floor-nearest-2026-10-25: Nearest support floor under `require_structural_stop`, pre-registered

Status: **RUN 2026-10-25; NOT LIVE as screened (§Results, #3423).** Pre-registered in #3418 (97b6daa99, plus the §Log
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
    *displaced*: S placements absent from the SM cell; (c) the realised ln(1+R) of each set, as n, mean, median,
    p10/p90 and the share above +100 %. This is descriptive. It explains the Δ and does not change the rule above.
  - **Twin drops on monthly lists.** Year Y's pit-v12 twin drops apply to every monthly list dated in
    [Y-05-31, Y+1-05-31). Symbols that appear only in monthly lists also go through the twin detector, and its drops
    are committed with their evidence (prerequisite 3).

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

2026-10-25 floor-nearest — NOT LIVE as screened (no return read; ledger entry to follow in a docs PR): SN (Nearest under `require_structural_stop`, top-3000 pit-v12 2019–24, K=6) cut NSS to 0.950 × S against a ≤ 0.75 × bar mis-set versus the screen's own 6.7 % conversion (Placed 238 > 190); why: Nearest turns "no floor" into "floor > 15 %", and its ~5 % conversions re-draw cash in a cash-bound book (39–58 S tickets displaced per cell, incl. APPS/MMYT/GLNG, ADMA/MSTR at the fill; converts −2.3 % ex IONQ against shared +4.6 %); descriptive Δ median ln(1+R) −0.41, 6/6 seeds negative; the dial stays a default-off keep-axis and is not escalated.

`Verifies: none`. The #3420 [after-merge] item concerns the path-stability cells, not this run.

## Log

- 2026-10-25 06:57 PT, before any SN artifact was read (the chain was in the SN-p0 preflight): qc-results (#3418)
  found that liveness counted every `No_structural_stop` token in the audit (8,302 on S p0). That figure includes the
  week's skips re-listed in each placed entry's `alternatives_considered`, which grow with Placed and pull against
  the second condition. Amended to decision outcomes only (S p0: 5,078 / 190). The bar ratio 0.75 is unchanged. The
  running chain was staged from 97b6daa99, so its own `summary.txt` uses the old count: `collect` and `summary` are
  re-run from this commit's `chain.sh` after the chain ends, and that output is the one read.
