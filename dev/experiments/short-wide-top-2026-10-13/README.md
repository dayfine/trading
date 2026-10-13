# Short wide-top screen (2026-10-13)

Option (b) of the shorts-track decision. Pre-registration: `dev/plans/short-wide-top-screen-2026-10-13.md`, committed
in `6a0177107` before any number here was computed. Host-only; no container, no strategy code.

## Rule output (price floor $5)

```
Step 1 O1+60: n=24790 beat=51.3% (>=55% FAIL) median=+0.50% (>0 ok) => CLOSE (no-build)
Step 2 O2 (not reached; shown for the record): n=24790 (>=100 ok) mean=-2.12% (>=+2% FAIL) median=+1.10% (>0 ok) beat=52.0% (>=55% FAIL) halves -6.56/+2.13% (FAIL) O1+60 mean -2.19% (ok) => no edge
VERDICT: CLOSE (no-build)
```

$17 floor (robustness): n 18,308; O1 +60 beat 50.8 %, median +0.26 % → CLOSE; O2 mean −0.29 %, median +0.69 %,
beat 51.3 %, halves −2.79 / +1.79 %.

## Numbers (from `results/summary-floor5.txt`)

| outcome | n | mean | median | p10 | p25 | p75 | p90 | beat |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| O1 +20 | 24,790 | +0.13 % | +0.09 % | −12.6 | −5.6 | +5.9 | +13.4 | 50.4 % |
| O1 +60 | 24,790 | −2.19 % | +0.50 % | −21.0 | −9.5 | +10.8 | +22.7 | 51.3 % |
| O1 +120 | 24,790 | −1.47 % | +1.85 % | −29.3 | −12.4 | +16.3 | +32.4 | 53.4 % |
| O2 | 24,790 | −2.12 % | +1.10 % | −28.4 | −13.6 | +16.1 | +32.3 | 52.0 % |
| O2 2000–12 | 12,118 | −6.56 % | −1.18 % | −30.5 | −15.8 | +14.1 | +30.4 | 47.7 % |
| O2 2013–25 | 12,672 | +2.13 % | +3.48 % | −25.8 | −11.5 | +17.7 | +33.6 | 56.0 % |
| O2 clipped ±100 % | 24,790 | +1.13 % | +1.10 % | | | | | 52.0 % |

- O2 stopped: 4,580 (18.5 %). The stop sits above the whole right shoulder, so room is wide: 16,396 events (66 %) have
  room > 30 %, 980 have ≤ 15 %.
- The mean and the ±100 %-clipped mean differ in sign (−2.12 % vs +1.13 %): the negative mean is carried by a short
  tail: 136 events lose more than 100 % and 21 gain more than 100 % (some are vendor splices, as in the setup map, #3239). The median and beat do not move.
- Room split (O2 beat): ≤ 15 % 45.5 %, 15–30 % 49.5 %, > 30 % 53.5 %.
- SPY phase split (O2 beat): s4_early 47.2 %, s4_late 46.7 %, s3 50.3 %, s12 55.3 %.
- Bear years (O2 beat): 2000–02 48.0 %, 2007–09 55.1 %, 2022 48.9 %.

## Notes on the implementation

- Weekly bars built from the daily bars (weeks end Friday) and the 30-week MA computed here; our stage classifier is
  not used. The SPY weekly stage CSV only labels the phase split.
- Entry at the next daily bar's adjusted open; the SPY leg starts at SPY's adjusted open on the same day. (The setup
  map's `events.awk` entered at that day's adjusted close.)
- Membership and the $5 floor are read at the breakdown week's last daily bar.

## Files

- `scripts/run.sh` regenerates everything (`DATA=<bar store>`, default `data/`): `run_events.sh` → `event_one.sh` →
  `events.awk` per symbol, then `summarize.sh` (`analyze.awk`).
- `results/events/<year>.csv` (one header each; columns in `scripts/header.txt`), `results/summary-floor5.txt`,
  `results/summary-floor17.txt`.

# Reading (results-analyst)

Pre-registration `dev/plans/short-wide-top-screen-2026-10-13.md` (commit `6a0177107`, pushed 17:42:59Z before the
results commit at 17:48:05Z; merged separately as #3299, byte-identical). Universe PIT top-3000 v12 (broad, U1). No
review pack: this is an event screen, not a backtest. V6 not applicable: no simulator arms; every paired read is
within event on the same bars.

Analyst artifacts are in `results/analysis/` (host only). `run_all.sh` regenerates `analysis.txt` (cited as §N) and
`traces.txt` in about 10 minutes from the repo root (`DATA=<repo>/data` from a worktree). `ra_events.awk` re-derives the
event table from the plan's text, sharing no code with `scripts/events.awk`, and draws a random-member null in the same
pass: every top-3000 member over $5 on every 4th Friday (864,415 draws), shorted at the next open with the same outcome
formula. Bootstraps are seeded; two runs gave identical output.

## In brief

- **CLOSE (no-build), by the pre-registered rule.** O1 +60 beat 51.3 % against a 55 % bar (week-clustered 95 % CI
  [50.3, 52.4] %), median +0.50 %. $17 floor: 50.8 %. Step 2 not reached.
- **It reproduces the setup map's no-stop coin flip.** The stop sits a median 38 % above entry, so only 18.5 % of shorts
  are stopped; on the rest O2 equals O1 +120 exactly. No-stop numbers are within half a point of the setup map's
  population (O1 +60 +0.50 % / 51.3 % here, +0.49 % / 51.4 % there).
- **The coin flip is the universe, not the breakdown.** Against random top-3000 members on the same dates, 49.1 % of
  events do better for the short at +60 bars (CI [48.1, 50.0] %). The setup map's 45,599 breakdowns also read 49.1 %.
- **The 2013–25 beat of 56 % is the benchmark.** Random members beat an SPY short 57.0 % of the time in that half; the
  base rate runs 43 % to 66 % by year (cap-weighted SPY vs an equal-weighted, mostly small/mid-cap universe).
- **The one event-specific effect is adverse.** In early SPY Stage 4, the book's timing window, 45.4 % of events beat
  the date's random member (CI [43.2, 47.4] %): broken names rebound harder when the index turns.
- **Forward.** Price-shape short screens are exhausted. Short interest is the one book lever left, and it is
  data-gated. Any future screen pre-registers against a calendar-matched null, not only an SPY short.

## 1. The rule, as written

| floor | n | O1 +60 beat (bar ≥ 55 %) | median (bar > 0) | step 1 |
|---|---:|---:|---:|---|
| $5, primary | 24,790 | 51.3 % ✗ | +0.50 % ✓ | **CLOSE (no-build)** |
| $17, robustness | 18,308 | 50.8 % ✗ | +0.26 % ✓ | CLOSE |

Step 2 (record only): $5 O2 mean −2.12 % ✗, median +1.10 %, beat 52.0 % ✗, halves −6.56 / +2.13 % ✗; $17 −0.29 % /
+0.69 % / 51.3 %, halves −2.79 / +1.79 %.

- The sample resolves the bar: week-clustered CI [50.3, 52.4] % over 1,327 weeks; month clusters [49.8, 52.8] % (§13).
- The $5 summary reproduces to the digit from `results/events/*.csv` with independent code (§2). `ra_events.awk` finds
  24,791 events; 24,789 match the committed rows on all 17 columns (§1); the two differences are exact 30-week MA ties
  (defect 1) and move no reported number.
- Choices the plan left open, each measured, none moving a reported number: filters before the 182-day dedupe ($17 line
  filters the $5-deduped set, as the setup map did); the entry bar's own high is not checked against the stop (1 event
  changes, §10); the 400-bar guard drops 1 event (SRAC 2021-07-16, interactive check); SPY phase read at the week's last
  bar vs its Friday changes 2 labels (§15); next-open entry vs the setup map's close: a median 0.11 pp better for the
  short, and with a close entry O1 +60 reads 51.1 % / +0.40 % (§10). Same verdict.

## 2. The verdict, calibrated

**No-build decision for the price-defined wide-top short.** Over 24,790 price-defined wide tops (a late-Stage-2
52-week high, then a close below the pre-top base under a falling 30-week MA) in the PIT top-3000, 2000–25, the short
shows no edge over an SPY short at +20, +60 or +120 bars, or with the stop held to 120 bars. On the forward return
relative to SPY these events are indistinguishable from random members on the same dates: 49.1 % / 50.3 % above the
date's random-member median at +60 / +120 bars (§5); 49.6 % against members equally far below their 52-week highs
(§11). The setup map's breakdowns read 49.1 % / 49.5 % (§8).

It cannot claim that shorts cannot work (a proxy screen: no capital, sizing, borrow, uptick rule, slippage or trail,
each of which would cut the result further); anything about the book's head-and-shoulders top with a stop above the
right shoulder (in 84 % of events the stop sits above the head, §3.2); or anything about short interest.

Rigor (`mechanism-validation-rigor.md`): (1) estimand — a short-stock / long-SPY pair with no costs; an SPY short is not
a neutral benchmark for this universe (base rate by year, §3.4); the calendar-matched null is the cleaner control and the
verdict holds against both. (2) Distributions with n, mean, median, p10–p90 and beat throughout; clipped and trimmed
lines in §2. (3) Scale §3.7. (4) Every attribute is known at the breakdown week; PIT lists include later delistings;
ticker-reuse gaps are defect 2. (5) Surface: horizon, floor, entry convention, room, depth, top width, shoulder/head
ratio — no region clears the bar once matched to the null. (6) Paired: O2 vs O1 +120 within event, open vs close entry,
date- and date × distance-matched null, five events traced (§3.8). (7) Week-clustered bootstraps (§13). (8) V6 n/a.

## 3. Why

### 3.1 The far stop turns O2 into the no-stop hold

The stop sits a median 38.4 % above entry (p25 25.9 %, p75 60.9 %; §2) vs the setup map's 10.2 %. Only 18.5 % of shorts
are stopped (setup map 68.9 %). On the other 20,210 events O2 equals O1 +120 exactly; the stop changes the sign of 418
events (391 beats become losses, 27 the reverse), the whole gap between O2's 52.0 % and O1 +120's 53.4 %.

| | O1 +20 median / beat | O1 +60 | O1 +120 |
|---|---|---|---|
| wide top (this screen, open entry) | +0.09 % / 50.4 % | +0.50 % / 51.3 % | +1.85 % / 53.4 % |
| setup map, all events, close entry | +0.19 % / 51.0 % | +0.49 % / 51.4 % | +1.47 % / 53.0 % |
| random top-3000 member, every 4th Friday (§4) | — | +0.60 % / 51.8 % | +1.41 % / 52.9 % |

It lands where the setup map's stop-width surface put it (its §5.3: 51.8 % at entry + 50 %, 52.8 % at + 100 %). It
tests that map's conclusion from the other side: remove the stop cost and the coin flip is what remains.

### 3.2 What the event actually is

H is the first week of a topping episode, not the head: in 84.2 % of events the stock made a higher high before the
break (§12), so the [H+1, i−1] "right shoulder" range contains the head and the stop goes 1 % above the episode's peak —
the plan's text, not the book's "above prior rally peak" (`weinstein-book-reference.md` §6.3). The entry is late: a
median 21.0 % below H's high (p25 −29.9 %, p10 −41.4 %; §15a). 83.4 % of events follow a classifier Stage 3 → 4
breakdown on the same symbol within 52 weeks, 52.5 % within 8 (§9): mostly the setup map's declines, seen later.

### 3.3 Picks: beyond the calendar, the event carries no information

| | O1 +60 beat event / null | O1 +120 beat event / null | above the date's null median +60 / +120 |
|---|---|---|---|
| all | 51.3 % / 52.3 % | 53.4 % / 53.4 % | 49.1 % / 50.3 % |
| 2000–12 | 49.1 / 50.2 | 48.9 / 49.6 | 48.8 / 49.5 |
| 2013–25 | 53.5 / 54.3 | 57.8 / 57.0 | 49.3 / 51.2 |

### 3.4 The halves and the phase split are the benchmark, not the setup

The 2013–25 beat of 56 % survives clipping (56.0 %, mean +3.05 %) and trimming (55.8 %) (§2), but random members on the
same dates beat the SPY short 57.0 % of the time over 120 bars (§5), inside the event's CI [54.5, 57.6] % (§13). For any
cutoff year 2004–2020 the late half's O2 beat sits 0.7–2.2 pp below its matched null (§7); the raw late-half beat
climbs with the cut (52.6 % → 57.4 %) only because the base rate does. Year by year (§6) the matched null's O1 +120 beat
runs from 43.0 % (2003) to 66.1 % (2019) and the event tracks it (2015 60.1 % vs 60.2 %, 2019 65.4 % vs 66.1 %, 2005
43.6 % vs 44.8 %); event minus null averages +0.7 pp (SD 6.3), positive in 14 of 26 years, −0.3 pp without 2009's 175
events (§15a). The base rate fits a cap-weight / size pattern (high in 2019–21 and 2023–25 when large caps led, low in
2000–01 and 2003–05); no equal-weight index was computed to test it. Wins are relative: in 2020 the median O2 excess is
+8.5 % while the median short lost 24.6 % absolute (§3); only 41.6 % of all shorts make money. The bull tape (s12) is
the best phase at 55.3 %, but its matched null is also 55.3 % (§5). Early SPY Stage 4 is adverse: 45.4 % above the null
median (CI [43.2, 47.4] %; §13) — the setup map's early-Stage-4 finding and the index-hedge rebound bleed, now against
a matched control.

### 3.5 Room, depth and top width: the universe's momentum gradient, not the top

Room: O2 beat 45.5 / 49.5 / 53.5 % for ≤ 15 / 15–30 / > 30 % room comes from the stop (stopped share 46.2 / 27.5 /
12.7 %, §15a); O1 +60 is flat (50.4 / 50.3 / 51.8 %). Depth: O2 beat rises from 49.4 % within 20 % of the high to
62.2 % beyond 50 % below it (n 1,326; §11), but random members show the same gradient by distance from their own
52-week high (O1 +120 51.7 % → 55.6 %); matched on date × distance, events land at 48.5–51.0 % above the cell null
median, 49.6 % overall, 49.8 % against members also below a falling MA (§11). That is the universe's 52-week-high
(momentum-loser) factor. "The bigger the top, the bigger the drop" (Ch. 7): room looks informative against the calendar
null (46.0 % → 58.5 % at +120), but room and depth are nearly one variable here; matched on date × distance, room is
flat (48.5 / 49.1 / 49.7 / 49.7 / 51.3 %). Top width: O1 +60 beat 52.4 / 53.1 / 50.7 / 50.0 / 52.1 % from 8–12 to
41–52 weeks; 48.4–50.3 % against the matched null (§15a), as the setup map's blind read expected.

### 3.6 The one residual slice: a lower right shoulder (post-hoc, not a lead)

3,926 events whose right shoulder stays below H's high read better: O1 +60 beat 54.4 % (CI [52.6, 56.3] %), 52.4 % /
54.2 % above the date's null median at +60 / +120 (§12). By shoulder-to-head ratio it is a U, not a dose-response:
≤ 0.90 (288) 69.1 %; 0.90–0.95 (527) 56.0 %; 0.95–1.00 (3,107) 52.5 %; 1.00–1.25 (18,125) 48.7–49.3 %; > 1.25 (2,726)
54.4 %. The ≤ 0.90 cell is not a head-and-shoulders top: its "heads" are intraday spikes (VMC, HOPE, PB in the 2008-09-19
short-ban squeeze week) and reverse-split microcaps (HTBX 2015-03-13, IMNN 2020-06-19). One of dozens of cells cut; it
cannot propose a build. A true H&S definition (lower right shoulder, declining volume) would need its own
pre-registration against the matched null.

### 3.7 Tail, data and scale

The negative raw mean is two data splices: BELM 2005-10-21 (−46,743 %) and CGE 2001-07-06 (−13,857 %) carry −2.45 pp,
more than the whole −2.12 % mean; the ten worst carry −3.05 pp (§2), mostly vendor splices or ticker reuse (defects 2,
3). Halves raw −6.56 / +2.13 %, clipped −0.88 / +3.05 %. Medians and beats do not move. Scale (§14): mean O2 hold 110.7
bars; O2 earns +2.6 %/yr per unit of capital-time clipped (+2.0 % trimmed) before borrow; the absolute short return is
−10.3 %/yr; the random member's clipped O1 +120 is +0.8 %/yr (−3.0 % in 2000–12, +4.5 % in 2013–25).

### 3.8 Traced events (`results/analysis/traces.txt`, independent tracer)

| event | H high → shoulder peak | entry (vs H high) | stop (room) | outcome | shows |
|---|---|---|---|---|---|
| BDY 2007-07-27 (q10) | 22.67 → 25.00 | 16.52 (−27 %) | 25.25 (+53 %) | held: short −19.8 %, SPY −8.6 %, excess −28.4 % | rallied 24 % in 20 bars in a falling market |
| EXPR 2012-07-27 (q50) | 480.4 → 525.4 | 329.6 (−31 %) | 530.65 (+61 %) | +120: short −8.1 %, SPY +9.2 %, excess +1.1 % | the median "win" lost money; the horizon set its sign |
| EXR 2008-10-17 (q90) | 8.96 → 9.16 | 5.93 (−34 %) | 9.26 (+56 %) | held: short +42.5 %, excess +32.3 % | a REIT breaking down in the 2008 crash |
| COKE 2009-10-30 (stopped) | 4.80 → 4.90 | 3.84 (−20 %) | 4.95 (+29 %) | stopped bar 84: excess −18.8 % | a defensive dip in a rising market |
| CSCO 2000-10-27 (archetype) | 44.56 → 52.58 | 31.54 (−29 %) | 53.10 (+68 %) | held: short +66.9 %, excess +55.3 % | the book's picture, one of 24,790 |

### 3.9 Decomposition

| mechanism | effect | where |
|---|---|---|
| stop and timing | removed by construction: 18.5 % stopped, 418 sign flips | §2 |
| picks | none: 49.1 % / 50.3 % vs the date's random member; 49.6 % vs members equally far below their highs | §5, §11 |
| benchmark (cap-weight / size base rate) | moves every split: 43–66 % by year | §6, §7 |
| the book's market timing | adverse: early SPY Stage 4 at 45.4 % vs the null | §13 |
| fat tail and data | sets the mean's sign (two splices, −2.45 pp), not the median | §2 |
| entry price (open vs close) | +0.11 pp median; same verdict | §10 |
| costs | absent; each would cut further | — |

## 4. How it fits what we know

- Confirms the setup map (ledger `2026-10-13-short-setup-map`): its blind read predicted this failure (no top-width
  gradient, market-phase headwind); both hold. It gives the setup map's "coin flip" a cause: both event sets sit at the
  universe's base rate (51.8 %) and at 49 % against members on the same dates. Two independent definitions of a broken
  top — a 1–2-week classifier sliver and a price-defined wide top entered after a true base break — carry no
  information about the next 1–6 months' return relative to SPY in this universe.
- Confirms Phase B round 1 (its skipped candidate pool was a coin flip vs SPY; so is a random member) and the index-hedge
  rebound bleed, now against a matched control.
- Refines `project_edge_is_the_fat_tail` for shorts: the squeeze tax is modest here and the negative raw mean is mostly
  data; the problem is the centre of the distribution, and the centre is the universe.
- An instance of the factor-lens gap in `project_index_beating_structural_bar`: excess-vs-SPY carries a 43–66 %-by-year
  cap-weight / size base rate.
- **A cross-check for the long book, not a conclusion:** the years random members most often lagged SPY include the long
  book's worst lag years (2019 66.1 %, 2023 61.3 %, 2024 58.8 %; §6). Part of "holdings lagged in UP regimes" in the
  review packs may be the broad universe lagging cap-weighted SPY. Untested.
- Contradicts nothing in the ledger or memory.

## 5. What it implies next (options; the user decides; the track stays open but idle)

Ruled out for the shorts track: more price-shape short screens (the two screens bracket the space — tight classifier
top vs wide price top, early vs late entry, 10 % vs 38 % stop — and both return the base rate); the book's market timing
as an edge (adverse inside its window); building on the 2013–25 or bull-tape "beat" (base rate).

Left open:
1. **Short interest**, the book's "sucker short" filter: the one book lever with a non-trivial prior; data-gated, so the
   first step is a coverage check, not a run.
2. **A reopen standard:** any future short idea pre-registers against the calendar-matched random-member null (share of
   events above the date's null median, or excess over an equal-weighted universe), not an SPY short alone — a random
   member's 2013–25 O1 +120 beat vs an SPY short is 57.0 %, above this plan's 55 % bar.
3. **A measurement change regardless of shorts:** carry an equal-weight-universe benchmark beside SPY in long-side
   screens and in the review pack's "Eras vs SPY" signal, so eras when the broad universe lags cap-weighted SPY are not
   read as selection failures. Its own design question.
4. Nothing: stop here.

Not recommended: a momentum-loser short (stocks > 50 % below their 52-week high lag SPY slightly more often, 55.6 %; a
universe factor, not the book's setup, and its crash risk is exactly the early-Stage-4 rebound measured here).

## 6. Defects found

1. **Float ties on the 30-week MA** (`scripts/events.awk` running sum line 48, `ma[i] <= ma[i - 4]` line 56):
   two-decimal prices tie exactly and the comparison resolves by rounding. WGRD 2004-07-23 is missing (exact
   sum30(i) = sum30(i−4)); MOD 2018-05-04 is the same tie resolved correctly. 1 event; no number moves. Fix: integer
   cents or an epsilon.
2. **Ticker reuse and long bar gaps inside the 120-bar window:** 17 events span > 250 calendar days, 10 across a gap of
   more than a year (§15). ECLP 2010-07-02 (Eclipsys ends 2010-08-24, resumes 2023-03-08; excess +507 %); CCBL
   2007-08-31 (C-COR ends 2007-12-14, resumes 2014-06-09 at $234.71; excess −1,942 % — the setup map filed it as a
   splice under #3239, it is ticker reuse); NBIS 2021-12-27 (Yandex suspended 2022-02 → 2024-10); also KFX, LMS, APL,
   ATH, LRI, PNB, NDN. Fix: treat a gap > N days as a delisting at the last bar before it.
3. **Splices and corrupt highs in the tail** (#3239 class): BELM, CGE; NLCS 2014-09-26 (room 5,587 %), CAA 2005-07-29
   (room 2,481 %), MGDDY 2010-01-22 (stop 562,636), PLBC 2002-12-13 (stop 742,561).
4. **Non-common listings** (#3183; filter default-off since #3280): 117 events (0.5 %) — 66 warrants (WFC-WS ×11,
   BAC-WS-A), 11 units, 40 on non-USD listings (HSBA, SBER, CTRA_old, NVTK, BOUBYAN). They lean toward short "wins" from
   warrant decay. BOUBYAN has Monday–Thursday bars only, so its weeks end on Thursday.
5. **README nits above:** "21 gain more than 100 %" — the table has 20 on O2 excess, 23 on O1 +120; "the stop sits
   above the whole right shoulder" — true by definition, but in 84 % of events that range includes the head; "the
   negative mean is carried by a short tail" — two splices carry more than all of it.
6. Timing evidence is commit and push order only (the run's output directory is not on disk).
