# stop-width-cadence-surface-2026-09-05 — fallback stop width {4, 8, 10, 12, 14}% × stop cadence {daily trail update, weekly trail update}, record convention, fixed basis

Motivated by `dev/notes/yearly-trade-review-2000-2026.md` (#2673): 389 of the record's 469
stop exits are the ~4% fallback ticket and carry −$5.8M of the −$6.7M stop total; 121 losers
exit within five days; the unselected width counterfactual over all stop exits puts 8–12%
initial width at roughly half the loss at 13 weeks. The 09-03 stop-width surface only moved
4% → 5.9% and ran on the survivor-tilted 2000-vintage warehouse. The book (§5.3 4–6% band
for the percentage fallback; Ch. 6's weekly re-evaluation of the trail — trigger continuous,
update weekly, per `stops_runner.mli`) is the authority for the cadence axis and a *trader-mode* licence for widths beyond the band
(`.claude/rules/weinstein-faithful-core.md` dials; `project_fallback_stop_half_book_band`).

## Design

- **Build `e4984c5fe`** (pinned worktree `sweep-stop0905`) — the same build as
  `record-rebase-2026-09-03`, so its 2000–04 null (`rec5y-2000-new-s0`) is reused.
- **Arms** — the record spec with the window swapped and TWO lines prepended,
  `((initial_stop_buffer b))` and `((stop_update_cadence c))`; fallback width = 1 − 0.96·b:

  | b | width | cadence |
  |---|---|---|
  | 1.0 | 4% (record) | Daily (record) / Weekly |
  | 0.9583 | 8% | Daily / Weekly |
  | 0.9375 | 10% | Daily / Weekly |
  | 0.9167 | 12% | Daily / Weekly |
  | 0.8958 | 14% | Daily / Weekly |

  14% is the top because `stops_config.max_stop_distance_pct` (0.15, book §5.1) rejects
  wider candidates; widening that cap would be a second knob.
- **Cells (salt 0, 19 arms)**: 2019–23 × top-3000-2019 on the **2019-vintage warehouse**
  (`/tmp/snap_top3000_2019`; a fresh w4-D null is part of the chain — the first record-convention
  cell on that warehouse) and 2000–04 × top-3000-2000 on the 2000-vintage warehouse. Two arms
  2-concurrent, ~22 min per pair. Salts 1–2 follow for the surviving widths only.
- Reads: `../exit-lever-surface-2026-09-04/dissect.sh` and `unreal.sh`; every delta ex-monster;
  loss dollars = Σ negative `pnl_dollars`; whipsaw = stop exit followed by ≥ +15% within 13
  weeks (needs the CSV store; `../yearly-trade-review-2026-09-04/grade.sh` logic).

## Pre-registered decision rule (before the first cell)

For each arm vs its window's null, per salt: (1) **loss dollars** (Σ negative pnl) ≥ 40% lower;
(2) **equity** (realised + engine unrealised) ≥ null; (3) **maxDD** not worse by > 5pp; all
ex-monster (join `symbol|entry_date`, remove any single one-arm trade > 50% of |Δ|).

- An arm that passes (1)–(3) at salt 0 on **both** windows → run salts 1–2; it becomes a
  promotion candidate only if it passes at ≥ 2 of 3 salts on both windows and the 26y
  confirmation arm (`sw26y-…`, salt 0) does not worsen maxDD.
- Passes on one window → regime dial; record which window and the named trades.
- Fails (1) everywhere → the counterfactual was the proxy's artefact (tied capital, later
  exits); record the loss-dollar and whipsaw counts per arm anyway — that is the mechanism read.
- The cadence axis is read separately: Weekly vs Daily at the same width, same three tests.
  Weekly mirrors the book's weekly trail update (the trigger stays intraday in BOTH arms);
  if it passes it is the more faithful default regardless of size.

Nothing here flips a default (`experiment-flag-discipline.md` R3;
`config-default-blast-radius.md`).

## Results

_(filled in as cells land — `chain.log`)_

### Interim — 2019–23 nulls on the 2019-vintage warehouse, salt 0 (00:35 PDT)

| arm | return % | trades | sharpe | maxDD % | realised $ | unrealised $ | loss $ (losers) | exits ≤ 5d | stops |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| w4-D (record, daily) | **16.79** | 179 | 0.261 | **22.04** | +11,565 | +171,175 | −1,054,114 (126) | 52 | 139 |
| w4-W (weekly update) | 3.50 | 189 | 0.133 | 27.36 | −52,096 | +102,381 | −1,121,473 (132) | 47 | 142 |

The daily 4% arm is the **first level-valid record-convention 2019 cell** (16.8% vs 3.0% for
the same spec on the 2000-vintage warehouse — different name set, not comparable, but this is
the base every 2019 arm below diffs against). Weekly-update cadence at the 4% width **fails all
three tests** at this salt: loss dollars +6%, equity −$132k, maxDD +5.3pp. Shared 145 trades
drift +$49k in the weekly arm's favour (the exits it does take are later and better), but it
takes 3 more stops and its unique cohort earns a third of the null's. Cadence alone does not
remove the ≤ 5-day exits (47 vs 52): a 4% stop is hit intraday in both arms; the only difference is that the Weekly arm's trail is
not raised mid-week. The cadence axis
is re-read at each wider width below.

### Interim — 2019–23 w8-D and 2000–04 w4-W, salt 0 (00:57 PDT)

| cell | null | arm | Δ realised | Δ unrealised | shared drift | loss $ (losers) | exits ≤ 5d | maxDD |
|---|---|---|---:|---:|---:|---|---:|---|
| 2019 w8-D vs w4-D | 16.79 / 179 / 22.04 | 5.18 / 156 / 27.26 | −$69k | −$54k | **+$192k (87 shared)** | −1.05M (126) → −1.07M (109) | 52 → **15** | **+5.2pp** |
| 2000 w4-W vs w4-D | 76.64 / 98 / 28.36 | 78.26 / 97 / 28.13 | +$15k | +$1k | +$12k (97 shared) | −597k (67) → −591k (66) | — | −0.2pp |

**8% daily on 2019–23 does exactly what the proxy said on the trades both arms hold** — the
wider stop rides out the shakeouts (+$192k on 87 shared trades) and the ≤ 5-day exit count
falls from 52 to 15 — **and loses anyway**, because holding longer means fewer free slots:
only 87 trades are shared, the null's 92 unique entries include BBWI +$142k, PODD +$93k and
AN +$89k, the arm's 69 unique include BBBY +$108k and GME +$64k but net −$136k. Loss dollars
are flat (fewer losers, each bigger: 109 × −$9.8k vs 126 × −$8.4k), equity −$122k, maxDD
+5.2pp. The proxy's "capital not reused" caveat is the whole story at this width on this
tape: the tax the wide stop removes is paid back in slot reshuffle. The 2000–04 weekly-4%
arm is a no-op (97 of 98 trades shared, +$15k). Wider widths and the 2000–04 tape follow.

### Interim — 2019–23 w10-D and 2000–04 w8-D, salt 0 (01:19 PDT): wider stops do not cut loss dollars; they cut loser COUNT and, in the bear tape, drawdown

| cell | null | arm | Δ equity | shared drift | loss $ (losers) | exits ≤ 5d | maxDD | monsters |
|---|---|---|---:|---:|---|---:|---|---|
| 2019 w10-D vs w4-D | 16.79 / 179 / 22.04 | 18.93 / 184 / 30.94 | +$18k | +$0.5k (92) | −1.05M (126) → **−1.19M (129)** | 52 → 18 | **+8.9pp** | TWST +$242k arm-only vs BBWI +$142k null-only |
| 2000 w8-D vs w4-D | 76.64 / 98 / 28.36 | 79.86 / 90 / 18.22 | +$30k (≈ +$286k ex-IPIXQ) | **+$160k (60)** | −597k (67) → **−728k (57)** | 19 → 9 | **−10.1pp** | IPIXQ +$256k null-only; RT +$163k arm-only |

Test (1) of the pre-registered rule (loss dollars ≥ 40% lower) has failed in every arm so far
and it is now clear why: the losers that would have been stopped at 4% and *recovered* are a
minority; most go on to lose 8–10% instead of 4%. The counterfactual in the yearly review
credited them with the 13-week close, which is what the D-grade subset does and the rest
does not. What widening actually buys is (a) fewer whipsaw exits (≤ 5-day exits −65–70%),
(b) positive shared-trade drift (+$160k on 2000–04, +$192k at 8% on 2019–23), and (c) in the
2000–04 tape a **10pp drawdown improvement** at 8% with equity ahead ex-monster. On 2019–23
the drawdown goes the other way (+5 to +9pp) and the equity gain is a monster swap. Same
regime split as the 5.9% surface of 09-03, now with a mechanism: in a bust/recovery the
survivors are the recovery; in a melt-up the survivors are the laggards.

### Interim — 2019–23 w12-D and 2000–04 w10-D, salt 0 (01:41 PDT)

| cell | null | arm | Δ equity | shared drift | loss $ (losers) | exits ≤ 5d | maxDD | monsters |
|---|---|---|---:|---:|---|---:|---|---|
| 2019 w12-D vs w4-D | 16.79 / 179 / 22.04 | 20.48 / 176 / 32.26 | +$32k | +$118k (97) | −1.05M (126) → −1.18M (111) | 52 → 12 | **+10.2pp** | MGNI +$150k arm-only vs BBWI +$142k null-only |
| 2000 w10-D vs w4-D | 76.64 / 98 / 28.36 | 79.63 / 99 / 17.53 | +$25k (≈ +$281k ex-IPIXQ) | −$15k (64) | −597k (67) → **−577k (57)** | 19 → 11 | **−10.8pp** | IPIXQ +$256k null-only; SNDK +$150k arm-only |

On 2000–04 the 8% and 10% daily arms both hold drawdown near 17–18% (vs 28.4%) with equity
at or above the null ex-monster, win rate 32 → 37–42% and Sharpe 0.66 → 0.79–0.86; 10% is
the first arm anywhere to lower loss dollars (−3%). On 2019–23 every wider width so far
costs 5–10pp of drawdown for a monster-swap equity read. The cadence arms and 14% follow.

### Interim — 2019–23 w14-D and 2000–04 w12-D, salt 0 (02:05 PDT): at 14% the melt-up tape flips

| cell | null | arm | Δ equity | shared drift | loss $ (losers) | exits ≤ 5d | maxDD | exit mix stops / rotations |
|---|---|---|---:|---:|---|---:|---|---|
| 2019 w14-D vs w4-D | 16.79 / 179 / 22.04 | **32.48 / 196 / 21.33** (win 40%, Sharpe 0.41) | **+$150k** | **+$115k (100)** | −1.05M (126) → **−0.99M (118)** | 52 → **10** | **−0.7pp** | 139 / 40 → **99 / 96** |
| 2000 w12-D vs w4-D | 76.64 / 98 / 28.36 | 72.47 / 116 / 20.20 | −$46k (≈ +$210k ex-IPIXQ) | −$143k (61) | −597k (67) → −646k (68) | 19 → 7 | −8.2pp | 74 / 19 → ? |

2019–23 at 14%: no dominating monster (null-only BBWI +$142k vs arm-only POWL +$122k roughly
cancel; the unique cohorts are −$105k and −$58k), so the +$150k is shared-trade drift plus a
smaller whipsaw bill. The exit mix is the mechanism: with a 14% initial stop the position
lives long enough for the laggard rotation to be the exit (96 rotations vs 40) — and rotation
exits are the A-grade channel (55% A in the yearly review) while 4% stops are the whipsaw
channel. Passes tests (2) and (3); test (1) passes in direction (−6%) but not the 40% bar.
2000–04 at 12% overshoots: the bear tape's survivors from an 8–10% stop were the recovery,
its survivors from a 12% stop include the next leg down (shared drift −$143k; WNC-class
trades sized smaller). Width that suits the tape: 2019–23 wants ≥ 14%, 2000–04 wants 8–10%.
Remaining: 2000–04 at 14%, and the weekly-update cadence at 8–14% on both windows.

### Interim — 2000–04 w14-D and 2019–23 w8-W, salt 0 (02:28 PDT)

| cell | null | arm | Δ realised | Δ unrealised | shared drift | loss $ (losers) | exits ≤ 5d | maxDD | stops / rotations |
|---|---|---|---:|---:|---:|---|---:|---|---|
| 2000 w14-D vs w4-D | 76.64 / 98 / 28.36 | **145.29 / 123 / 20.06** (win 46%, Sharpe 1.17) | +$142k | **+$540k** | −$29k (62) | −597k (67) → −584k (66) | 19 → 7 | **−8.3pp** | 74 / 19 → 71 / 41 |
| 2019 w8-W vs w8-D | 5.18 / 156 / 27.26 | 1.08 / 139 / 24.75 | −$13k | −$25k | +$60k (84) | −1.07M (109) → −1.05M (91) | 15 → 14 | −2.5pp | 102 / 52 → 85 / 53 |

The 2000–04 14% arm's +$540k of extra unrealised is its open book at 2004-12-31: **ADSK
2003-09-08 +$382k** (held 16 months because a 14% stop never fired) and AEO +$137k. Ex-ADSK
the arm is still ≈ +$290k ahead on equity with 8pp less drawdown and IPIXQ (+$256k) sitting
in the null only — so this cell passes (2) and (3) ex-monster on both sides of the join, and
(1) in direction (−2%). Rotations double (19 → 41): same mechanism as 2019–23 at 14%.

Weekly cadence at 8% on 2019–23 is again a mild negative on equity (−$38k) with a mild
drawdown gain (−2.5pp); the cadence axis has not passed anywhere yet.

**Artifact sighting (#2672):** the 2019–23 14% arm's open book carries DTV (entered
2020-03-28) at a final price of **0.00** — −$66k of phantom unrealised loss; that cell's
equity is understated by that amount. Every wide-stop arm is more exposed to this defect
because it holds delisted names longer.

### Interim — cadence axis at 8–10%, salt 0 (02:50 PDT): weekly-update does not pass

| cell (weekly vs daily, same width) | daily | weekly | Δ realised | Δ unrealised | shared drift | loss $ (losers) | maxDD | stops / rotations |
|---|---|---|---:|---:|---:|---|---|---|
| 2019 w10 | 18.93 / 184 / 30.94 | 18.64 / 179 / 27.63 | +$61k | −$63k | +$18k (132) | −1.19M (129) → −1.17M (123) | **−3.3pp** | 118 / 64 → 98 / 76 |
| 2000 w8 | 79.86 / 90 / 18.22 | 64.32 / 89 / 18.22 | −$102k | −$55k | −$41k (86) | −728k (57) → −682k (55) | 0.0 | 62 / 24 → 59 / 24 |

With 4 arms read (4%, 8%, 10% on 2019–23; 4%, 8% on 2000–04), the weekly-update cadence is
equity-neutral to negative at every width and buys at most 3pp of drawdown on the melt-up
tape. The weekly update leaves the trail lower mid-week; at these widths that lower level changes
almost nothing. The cadence axis is not a promotion candidate; it remains a
faithfulness dial. Remaining: 2000–04 w10-W / w12-W / w14-W, 2019–23 w12-W / w14-W.

### Interim — 2019–23 w12-W and 2000–04 w10-W, salt 0 (03:11 PDT): at wide widths the weekly update starts to pay

| cell | vs | Δ realised | Δ unrealised | shared drift | unique cohorts (null / arm) | loss $ (losers) | exits ≤ 5d | maxDD | stops / rot |
|---|---|---:|---:|---:|---|---|---:|---|---|
| 2019 w12-W (56.08 / 181 / 24.98, win 40%, Sharpe 0.59) | w4-D null | **+$396k** | −$6k | +$44k (90) | −$59k (89: BBWI +142k, AN +89k) / **+$292k** (91: POWL +173k, APPS +154k, NVDA +80k) | −1.05M → −1.14M (108) | 52 → **6** | +2.9pp | 139/40 → 94/85 |
| 2019 w12-W | w12-D | +$360k | −$2k | **+$130k (131)** | +$77k (45) / +$306k (50) | −1.18M → −1.14M | 12 → 6 | **−7.3pp** | 98/77 → 94/85 |
| 2000 w10-W (88.81 / 98 / 17.53, win 45%, Sharpe 0.91) | w10-D | +$91k | +$1k | −$7k (93) | −$49k (6) / +$49k (5) | −577k → −594k (54) | 11 → 11 | 0.0 | 59/33 → 56/35 |

No single trade exceeds half the 2019 delta (POWL is 44%, APPS 39%), and the open book is
clean (FCNCA +$56k top). Against the daily twin at the same width the weekly update is worth
+$130k on the trades both hold and 7pp of drawdown — the opposite of its reads at 4–10%,
where it only delayed a stop that was already through. The interpretation to test with
salts: at 12%+ the once-a-week trail update leaves the stop far enough below the shakeout lows that
the (intraday) trigger is not hit where the daily-raised trail is; the cadence matters only
once the width makes that gap large. Fragility: two of the three arm-only monsters are 2020 names; salts 1–2 decide.

### Interim — 2019–23 w14-W and 2000–04 w12-W, salt 0 (03:33 PDT): the cadence effect flips sign across the grid

| cell (weekly vs daily, same width) | daily | weekly | Δ realised | Δ unrealised | shared drift | unique (daily / weekly) | maxDD |
|---|---|---|---:|---:|---:|---|---|
| 2019 w14 | 32.48 / 196 / 21.33 | 18.57 / 200 / 25.20 | −$88k | −$51k | +$38k (167) | +$116k (29: AN +94k) / −$11k (33) | **+3.9pp** |
| 2000 w12 | 72.47 / 116 / 20.20 | 96.40 / 117 / 20.28 | +$76k | +$163k | +$69k (112) | −$31k (4) / −$24k (5) | +0.1pp |

Cadence, weekly vs daily at the same width, salt 0: 4% −$132k / +$15k (2019 / 2000); 8%
−$38k / −$156k; 10% −$2k / +$92k; 12% **+$358k / +$239k**; 14% −$139k / (pending). The sign
flips with width and window, and the two big weekly wins at 12% are a handful of names per
window (POWL, APPS, NVDA; the 2000 open book). That is the salt-lottery signature, not a
mechanism; the cadence axis goes to salts 1–2 only at 12%, alongside the width survivors.

## Salt-0 verdict (19 arms, 03:55 PDT)

Equity = realised + engine unrealised; Δ vs the window's w4-D null. Loss $ = Σ negative
`pnl_dollars`. 2019–23 null: 16.8% / 179 / maxDD 22.0 / loss −$1.054M / 52 exits ≤ 5d /
139 stops, 40 rotations. 2000–04 null: 76.6% / 98 / 28.4 / −$597k / 19 / 74, 19.

| window | width | cad | return | maxDD | Δ equity | loss $ (Δ%) | losers | ≤ 5d | stops / rot | tests passed |
|---|---|---|---:|---:|---:|---:|---:|---:|---|---|
| 2019 | 4 | W | 3.5 | 27.4 | −$132k | −1.121M (+6%) | 132 | 47 | 142 / 44 | — |
| 2019 | 8 | D | 5.2 | 27.3 | −$122k | −1.067M (+1%) | 109 | 15 | 102 / 52 | — |
| 2019 | 8 | W | 1.1 | 24.8 | −$160k | −1.045M (−1%) | 91 | 14 | 85 / 53 | — |
| 2019 | 10 | D | 18.9 | 30.9 | +$18k | −1.192M (+13%) | 129 | 18 | 118 / 64 | (2) |
| 2019 | 10 | W | 18.6 | 27.6 | +$16k | −1.172M (+11%) | 123 | 13 | 98 / 76 | (2) |
| 2019 | 12 | D | 20.5 | 32.3 | +$32k | −1.179M (+12%) | 111 | 12 | 98 / 77 | (2) |
| 2019 | **12** | **W** | **56.1** | 25.0 | **+$389k** | −1.144M (+9%) | 108 | 6 | 94 / 85 | **(2)(3)** |
| 2019 | **14** | **D** | **32.5** | **21.3** | **+$150k** | **−0.992M (−6%)** | 118 | 10 | 99 / 96 | **(2)(3)** |
| 2019 | 14 | W | 18.6 | 25.2 | +$12k | −1.003M (−5%) | 126 | 8 | 95 / 101 | (2)(3) |
| 2000 | 4 | W | 78.3 | 28.1 | +$16k | −591k (−1%) | 66 | 17 | 71 / 20 | (2)(3) no-op |
| 2000 | **8** | **D** | 79.9 | **18.2** | +$30k (≈ +$286k ex-IPIXQ) | −728k (+22%) | 57 | 9 | 62 / 24 | **(2)(3)** |
| 2000 | 8 | W | 64.3 | 18.2 | −$126k | −682k (+14%) | 55 | 8 | 59 / 24 | (3) |
| 2000 | **10** | **D** | 79.6 | **17.5** | +$25k (≈ +$281k ex-IPIXQ) | −577k (−3%) | 57 | 11 | 59 / 33 | **(2)(3)** |
| 2000 | **10** | **W** | 88.8 | **17.5** | +$118k | −594k (−1%) | 54 | 11 | 56 / 35 | **(2)(3)** |
| 2000 | 12 | D | 72.5 | 20.2 | −$46k (≈ +$210k ex-IPIXQ) | −646k (+8%) | 68 | 7 | 69 / 38 | (3) |
| 2000 | **12** | **W** | 96.4 | 20.3 | **+$193k** | −654k (+9%) | 68 | 7 | 62 / 44 | **(2)(3)** |
| 2000 | **14** | **D** | **145.3** | 20.1 | **+$682k** (≈ +$300k ex-ADSK) | −584k (−2%) | 66 | 7 | 71 / 41 | **(2)(3)** |
| 2000 | 14 | W | 122.5 | 18.5 | +$455k | −641k (+7%) | 70 | 7 | 68 / 49 | (2)(3) |

**Test (1) — loss dollars ≥ 40% lower — fails in every arm** (best: −6%). Recorded as a
miscalibrated pre-registration: the yearly review's counterfactual credited every survivor
with the 13-week close, and the surface shows the survivors of a 4% stop mostly go on to
lose 8–14% instead. Widening does not cut the loss bill; it converts many small whipsaws into
fewer, larger losses (loser count −6% to −28%, ≤ 5-day exits −65% to −87%), lifts the win
rate (30 → 37–46%), and moves the exit mix from stops to rotations. Whether that pays is the
tape: on 2000–04 every width ≥ 8% takes 8–11pp off the drawdown and 8–14% adds equity ex-monster;
on 2019–23 only 14% daily and 12% weekly clear both (2) and (3), and the 12%-weekly win is
three names.

**Deviation from the rule, recorded:** the rule sends only (1)–(3) passers to salts. Since
(1) is unattainable as written, the salts run for the (2)+(3) passers instead — 2019–23
w14-D and w12-W; 2000–04 w8-D, w10-D, w10-W, w12-W, w14-D — plus fresh 2019 nulls per salt
(`chain-v2.sh`, 16 cells). The salts decide whether any of these is a promotion candidate;
the pre-registered promotion bar (≥ 2 of 3 salts on BOTH windows, 26y maxDD not worse)
stands unchanged, with (2) and (3) as the tests.

## Salts 1–2 (survivors; `chain-v2.sh`)

2019–23 nulls per salt on the 2019-vintage warehouse; 2000–04 nulls at salts 1–2 are
`stop-width-surface-2026-09-03/results/sw5y-2000-b1.0-s{1,2}` (same build).

| cell | salt | null (ret / maxDD / loss $ / ≤5d) | arm (ret / maxDD / loss $ / ≤5d) | Δ equity | shared drift (n) | unique null / arm | stops/rot null → arm | (2) | (3) |
|---|---|---|---|---:|---:|---|---|---|---|
| 2019 w14-D | 0 | 16.8 / 22.0 / −1.054M / 52 | 32.5 / 21.3 / −0.992M / 10 | +$150k | +$115k (100) | BBWI +142k / POWL +122k | 139/40 → 99/96 | ✓ | ✓ |
| 2019 w14-D | 1 | 9.0 / 25.6 / −1.108M / 51 | 16.5 / 22.1 / −1.057M / 10 | +$69k | **+$166k (101)** | BBWI +141k / POWL +116k | 139/40 → 102/101 | ✓ | ✓ |
| 2019 w12-W | 0 | 16.8 / 22.0 / −1.054M / 52 | 56.1 / 25.0 / −1.144M / 6 | +$389k | +$44k (90) | BBWI +142k, AN +89k / POWL +173k, APPS +154k | 139/40 → 94/85 | ✓ | ✓ |
| 2019 w12-W | 1 | 9.0 / 25.6 / −1.108M / 51 | 40.8 / 27.1 / −1.187M / 7 | +$315k | **+$176k (88)** | BBWI +141k, AN +88k / APPS +153k, NVDA +80k, HVT +78k | 139/40 → 88/92 | ✓ | ✓ (+1.5pp) |
| 2000 w8-D | 0 | 76.6 / 28.4 / −597k / 19 | 79.9 / 18.2 / −728k / 9 | +$30k (≈ +$286k ex-IPIXQ) | +$160k (60) | IPIXQ +256k, DVA +92k / RT +163k | 74/19 → 62/24 | ✓ | ✓ |
| 2000 w8-D | 1 | 55.5 / 19.6 / −534k / 18 | 80.4 / 18.2 / −720k / 9 | **+$248k** | **+$157k (59)** | DVA +92k, TIMB +43k / RT +163k, LD1 +57k | 71/19 → 61/24 | ✓ | ✓ |
| 2000 w10-D | 0 | 76.6 / 28.4 / −597k / 19 | 79.6 / 17.5 / −577k / 11 | +$25k (≈ +$281k ex-IPIXQ) | −$15k (64) | IPIXQ +256k / SNDK +150k | 74/19 → 59/33 | ✓ | ✓ |
| 2000 w10-D | 1 | 55.5 / 19.6 / −534k / 18 | 78.7 / 17.5 / −577k / 11 | +$228k (≈ +$78k ex-SNDK) | −$39k (63) | DVA +92k / SNDK +150k | 71/19 → 59/33 | ✓ | ✓ |
| 2000 w10-W | 0 | 76.6 / 28.4 / −597k / 19 | 88.8 / 17.5 / −594k / 11 | +$118k | −$7k (93 vs w10-D) | — | 74/19 → 56/35 | ✓ | ✓ |
| 2000 w10-W | 1 | 55.5 / 19.6 / −534k / 18 | 88.0 / 17.5 / −594k / 11 | +$322k (≈ +$164k ex-SNDK) | −$13k (60) | DVA +92k / SNDK +158k, BDY +85k | 71/19 → 56/35 | ✓ | ✓ |

The 2000–04 10% arms are salt-invariant to the first decimal (daily 79.6 → 78.7, weekly
88.8 → 88.0, maxDD 17.5 both times) while the null moved 76.6 → 55.5: the wider stop removes
the path-dependence of the 4% book (which stop fires on which shakeout) and the drawdown
floor of ~17.5% is a property of the arm, not the draw.
| 2000 w12-W | 0 | 76.6 / 28.4 / −597k / 19 | 96.4 / 20.3 / −654k / 7 | +$193k | +$69k (112 vs w12-D) | — / AEO +147k open | 74/19 → 62/44 | ✓ | ✓ |
| 2000 w12-W | 1 | 55.5 / 19.6 / −534k / 18 | 95.4 / 20.3 / −656k / 7 | **+$396k** | −$140k (59) | DVA +92k, EOG +58k / SNDK +117k, BRSL +93k (58 unique) | 71/19 → 62/44 | ✓ | ✓ (+0.7pp) |
| 2000 w14-D | 0 | 76.6 / 28.4 / −597k / 19 | 145.3 / 20.1 / −584k / 7 | +$682k (≈ +$300k ex-ADSK held +382k) | −$29k (62) | IPIXQ +256k / SNDK +110k, BRSL +87k | 74/19 → 71/41 | ✓ | ✓ |
| 2000 w14-D | 1 | 55.5 / 19.6 / −534k / 18 | 93.5 / 20.0 / −685k / 7 | **+$377k** (open book ordinary, +$159k) | −$61k (62) | EOG +58k, TIMB +43k / SNDK +109k, BRSL +86k (67 unique) | 71/19 → 75/43 | ✓ | ✓ (+0.5pp) |

**Salt 1 complete (05:23 PDT): 7 of 7 survivors pass (2)+(3) at both salts run so far.** The
2000–04 wide arms win through their unique cohort (58–67 extra entries the 4% book never had
capacity for, +$477–489k), not through shared drift (−$60k to −$140k: the trades both hold do
slightly worse held wider); the 2019–23 arms win through shared drift (+$115–176k) with the
unique cohorts roughly cancelling. Two mechanisms, one direction.

### Salt 2

| cell | salt | null (ret / maxDD / loss $ / ≤5d) | arm (ret / maxDD / loss $ / ≤5d) | Δ equity | shared drift (n) | unique null / arm | stops/rot null → arm | (2) | (3) |
|---|---|---|---|---:|---:|---|---|---|---|
| 2019 w14-D | 2 | 15.5 / 22.0 / −1.057M / 52 | 19.3 / 21.3 / −1.023M / 12 | +$31k | **+$124k (108)** | BBWI +142k / POWL +116k (cohorts −119k / −163k) | 139/40 → 104/100 | ✓ (thin) | ✓ |
| 2019 w12-W | 2 | 15.5 / 22.0 / −1.057M / 52 | 36.3 / 27.4 / −1.206M / 7 | +$204k | **+$147k (92)** | BBWI +142k, AN +88k, BAND +75k / APPS +153k, NVDA +80k, HVT +78k | 139/40 → 87/94 | ✓ | ✗ (+5.4pp) |
| 2000 w8-D | 2 | 75.7 / 28.4 / −600k / 19 | 81.0 / 18.2 / −716k / 9 | +$50k (≈ +$305k ex-IPIXQ) | **+$162k (60)** | IPIXQ +255k, DVA +91k / RT +163k, LD1 +57k | 74/19 → 61/24 | ✓ | ✓ |
| 2000 w10-D | 2 | 75.7 / 28.4 / −600k / 19 | 74.7 / 17.5 / −575k / 11 | −$15k (≈ +$240k ex-IPIXQ) | −$13k (64) | IPIXQ +255k, DVA +91k / SNDK +150k, NDSN +46k | 74/19 → 59/33 | ✓ (ex-monster) | ✓ |
| 2000 w10-W | 2 | 75.7 / 28.4 / −600k / 19 | 88.2 / 17.5 / −592k / 11 | +$120k (≈ +$375k ex-IPIXQ) | +$19k (63) | IPIXQ +255k, DVA +91k / SNDK +158k, BDY +85k | 74/19 → 56/35 | ✓ | ✓ |
| 2000 w12-W | 2 | 75.7 / 28.4 / −600k / 19 | 95.7 / 20.3 / −654k / 7 | +$195k (AEO +147k held, as at s0/s1) | −$131k (60) | IPIXQ +255k, DVA +91k / SNDK +117k, BRSL +93k (57 unique) | 74/19 → 62/44 | ✓ | ✓ |
| 2000 w14-D | 2 | 75.7 / 28.4 / −600k / 19 | 88.8 / 20.1 / −639k / 6 | +$127k (≈ +$382k ex-IPIXQ) | −$23k (65) | IPIXQ +255k, EOG +58k / SNDK +110k, BRSL +86k (63 unique) | 74/19 → 75/43 | ✓ | ✓ |

## Verdict after salts 0–2 (06:50 PDT)

| arm | (2) equity ≥ null | (3) maxDD ≤ null + 5pp | maxDD Δ by salt | shared drift by salt | read |
|---|---|---|---|---|---|
| 2019 w14-D | **3/3** (+150k / +69k / +31k) | **3/3** | −0.7 / −3.5 / −0.8 | +115k / +166k / +124k | structural: the trades both books hold do better held wider; unique cohorts cancel |
| 2019 w12-W | **3/3** (+389k / +315k / +204k) | 2/3 | +2.9 / +1.5 / **+5.4** | +44k / +176k / +147k | same shared-drift signature plus a salt-stable APPS/NVDA/HVT cohort; costs 1.5–5.4pp of drawdown |
| 2000 w8-D | 3/3 ex-IPIXQ | 3/3 | −10.1 / −1.3 / −10.1 | +160k / +157k / +162k | shared drift salt-invariant; loss bill +20% |
| 2000 w10-D | 3/3 ex-IPIXQ | 3/3 | −10.8 / −2.0 / −10.8 | −15k / −39k / −13k | wins through the unique cohort (SNDK); arm salt-invariant (79.6 / 78.7 / 74.7, maxDD 17.5 ×3) |
| 2000 w10-W | 3/3 | 3/3 | −10.8 / −2.0 / −10.8 | −7k / −13k / +19k | as w10-D, +$90–120k more realised each salt |
| 2000 w12-W | 3/3 | 3/3 | −8.1 / +0.7 / −8.1 | −140k (vs null) / — / −131k | wins through 57–58 extra entries and a held AEO every salt |
| 2000 w14-D | 3/3 | 3/3 | −8.3 / +0.5 / −8.2 | −29k / −61k / −23k | wins through 61–67 extra entries; s0's ADSK hold was path-specific, the win was not |

**Two widths clear both windows at ≥ 2 of 3 salts: 14% daily and 12% weekly-update.** Their
26y confirmation arms (`sw26y-w14-D`, `sw26y-w12-W`, salt 0, vs `rec26y-new-s0` = 302.65% /
maxDD 36.26) decide promotion-candidacy per the pre-registered bar (26y maxDD not worse).
Nothing is flipped here.

### Mechanism (why), decomposed

- **Widening does not cut the loss bill.** Test (1) failed in all 19 salt-0 arms and every
  salt: survivors of a 4% stop mostly lose 8–14% instead. The yearly review's counterfactual
  was wrong about that and right about everything else.
- **What it buys is time.** ≤ 5-day exits fall 65–87%; stop exits fall from 139 to ~100 and
  rotation exits rise from 40 to ~95–100 (2019–23), from 19 to 33–49 (2000–04). The laggard
  rotation is the A-grade exit; the 4% stop is the whipsaw exit. A wide initial stop moves
  the exit decision from the stop to the rotation.
- **Two ways it pays, one per tape.** On 2019–23 the gain is shared-trade drift
  (+$115–176k every salt at 14% daily): the same entries, held through the shakeout. On
  2000–04 the gain is capacity: 55–67 extra entries the 4% book never funded (the 4% book
  churned its slots into whipsaws), plus a drawdown floor of 17.5–20% vs 28% because the
  book is not stopped out en masse into the 2001–02 legs down.
- **Cadence is width-dependent, not a mechanism of its own.** Weekly-update loses at 4–8%,
  is neutral at 10%, wins at 12% on both windows every salt, loses again at 14% on 2019–23.
  The 12%-weekly cohort (APPS, NVDA, HVT on 2019; AEO, SNDK, BRSL on 2000) is salt-stable,
  so it is not a lottery — but there is no monotone story to promote.
- **Book-faithfulness.** §5.3's 4–6% band is the *investor* fallback; 12–14% is a trader-mode
  adaptation with the book's own §5.1 15% ceiling as its limit (`max_stop_distance_pct`).
  The weekly trail update is the book's Ch. 6 cadence (trigger intraday in both arms — see
  the correction below); this surface says it only matters once the width is wide enough that
  a lower-resting trail is not hit.

### Caveats

- 2019–23 levels are the first on the 2019-vintage warehouse (2,208 names, ~76% of the
  composition); the delisting stub-print defect (#2672: DTV at 0.00 in the 14%-daily arm,
  −$66k) understates every wide arm. Fix #2672 before any promotion PR and re-run the 26y
  pair.
- The 2000–04 8–10% arms' equity wins are ex-IPIXQ at two of three salts (a null-only
  +$255k blow-off that the wide book had no slot for); their drawdown wins are not.
- No cell is on sp500; no level is compared across warehouses; nothing in this record flips
  a default (`experiment-flag-discipline.md` R3, `config-default-blast-radius.md`).

## 26y confirmation — `sw26y-w14-D` (10:12 PDT)

| arm | return % | trades | win % | Sharpe | maxDD % | realised $ | unrealised $ | loss $ (losers) | ≤ 5d | stops / rotations |
|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---|
| `rec26y-new-s0` (record) | 302.65 | 723 | 34 | 0.40 | 36.26 | +2,205,226 | +982,040 | −9.02M (475) | 131 | 469 / 237 |
| `sw26y-w14-D-s0` | **513.02** | 1,009 | 42 | 0.51 | **40.37** | +3,909,304 | +1,383,305 | −14.50M (581) | 52 | 407 / 573 |

Shared 393 trades drift **+$1.14M**; null-only 330 trades +$747k (BBWI +414k, NVDA +338k,
IPIXQ +256k, PCYC +245k); arm-only 616 trades +$1.31M (BFX +702k, NOVT +681k, SWKS +478k,
KTOS +383k — BFX alone is 41% of the realised delta and 33% of the equity delta). Open book at 2026-06: VIAV +$1.01M of the
+$1.38M unrealised. Realised by exit year: the arm is ahead in 17 of 27 years; behind in 2004
(IPIXQ), 2008 (−$239k vs +$2k), 2016, 2017, 2020 (**−$670k vs −$145k**), 2022 (−$589k vs
−$137k), 2026 H1.

**maxDD 40.4% vs 36.3%: the pre-registered 26y bar ("does not worsen maxDD") is NOT met**
(+4.1pp). The arm's drawdown runs from the 2018-01-26 peak to the **2020-05-01** trough. In
2020 the arm has 48 losers for −$1.80M vs the record's 30 for −$727k; the Feb 15 – Mar 31
crash-window entries alone lose −$623k vs −$313k (CNMD −$114k in two days, AGR, AEE, MSI
−$64–68k each — every one a 14% stop where the record paid 4%). The mechanism that pays in
2003–05, 2013–15 and 2021 (hold through the shakeout, exit by rotation) costs a full extra
leg in the two fastest bear tapes (2008, 2020); the 5y 2000–04 window never saw one.

**Read:** 14% daily is a large, robust return lever (+210pp, shared drift +$1.14M across
393 trades, win rate 34 → 42%, rotations 237 → 573) that buys its return with ~4pp of extra
drawdown concentrated in crash years. Not a promotion candidate under the bar as written.
The natural follow-up is a paired axis, not a flip: wide initial stop **plus** a crash-tape
gate (the yearly review's index-state read — entries after a > +10% index run lose — or the
macro gate itself), tested as its own surface.

## 26y confirmation — `sw26y-w12-W` (15:40 PDT): clears the bar

| arm | return % | trades | win % | Sharpe | maxDD % | realised $ | unrealised $ | loss $ (losers) | ≤ 5d | stops / rotations |
|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---|
| `rec26y-new-s0` (record) | 302.65 | 723 | 34 | 0.40 | 36.26 | +2,205,226 | +982,040 | −9.02M (475) | 131 | 469 / 237 |
| `sw26y-w12-W-s0` | **761.20** | 862 | 44 | 0.58 | **29.73** | +6,489,892 | +1,316,706 | −15.10M (483) | 42 | 328 / 496 |

Shared 380 trades drift **+$1.67M**; null-only 343 trades +$2.23M (LOGI +424k, BBWI +414k,
NVDA +338k, IPIXQ +256k); arm-only 482 trades +$4.84M (BFX +1.05M, MSTR 2023 +827k, KLIC
+381k, LUV +319k — the largest is 24% of the realised delta). Open book: KLAC 2025-06
+$1.08M of the +$1.32M unrealised (the record's open book is +$982k with its own holds).
The STMP stub print (#2672) is in both arms (−$624k here, −$594k in the record). Drawdown
window 2018-01-26 → **2020-03-25**, 29.7% — 6.5pp *better* than the record's 36.3%: with
the trail raised only weekly the stops rest lower going into crash week, fewer positions are
stopped (the trigger is still intraday), and the book that survives March rides the April
recovery (2020 realised +$359k vs −$145k). Behind the
record in 2010 (−$213k), 2016, 2022 (−$644k vs −$137k), 2025 (−$602k vs −$201k).

**Pre-registered promotion bar: met.** 5y: (2) 3/3 and (3) 2/3 on 2019–23, 3/3 + 3/3 on
2000–04; 26y: maxDD not worse (−6.5pp). `initial_stop_buffer 0.9167` +
`stop_update_cadence Weekly` is a **promotion candidate**, subject to the standing rules
before any flip: #2672 fixed and the pair re-run on the fix; a ledger entry; the
confirmation-grid check (this surface's three cells: 2019–23 on the 2019-vintage
warehouse, 2000–04 and 26y on the 2000-vintage — two vintages, one macro-diverse deep
cell); `config-default-blast-radius.md` paired goldens for both knobs. It is a two-knob
change; the salt-0 grid says neither knob alone clears both windows at 26y (14% daily
fails maxDD; 12% daily was +$32k / +10pp on 2019–23).

## Breadth state across 27 years (the macro-gate question)

Weekly breadth over the per-year PIT universes (`/tmp/yr-run/breadth_all_daily.csv`,
5,788 histories): percent above the 150-day MA, new 52-week highs/lows, advance–decline.
A "crash" state defined on *level* alone (e.g. < 40% above MA or > 8% new lows) is **net
positive** in both books (record +$449k over 105 entries; 14% arm +$845k over 127), because
it lumps the collapse with the recovery — April 2020, 2003 and 2009 entries are among the
best in the run. The losing state is **breadth deteriorating**: below 45% above MA *and*
falling ≥ 5 points over 20 days (or new lows > 8% and rising):

| state at entry | record n / win / P&L / A | 14% arm n / win / P&L / A |
|---|---|---|
| ok (≥ 55% above MA) | 495 / 35% / +$1.58M / 40 | 715 / 45% / +$3.58M / 84 |
| mid (45–55%) | 93 / 35% / +$249k / 7 | 135 / 37% / −$522k / 14 |
| weak, flat | 19 / 37% / +$351k / 2 | 16 / 25% / −$293k / 0 |
| **deteriorating** | **80 / 29% / −$604k / 1** | **94 / 35% / −$668k / 2** |
| recovering | 36 / 39% / +$627k / 4 | 49 / 45% / **+$1.81M** / 9 |

Deteriorating-state entries by year (record / arm): 2020 −$217k / −$412k, 2023 −$190k /
+$193k, 2018 −$91k / −$174k, 2025 −$123k / −$74k, 2007 −$52k / −$60k; false positives 2022
+$77k / +$67k, 2014 +$45k / +$50k. Under the macro gate's own labels those entries were
Neutral 31 / Bearish 22 / Bullish 27 in the record — the gate's Neutral band is where the
damage sits. **Design implication (keep concerns separate):** the macro gate should emit
the breadth *direction* as a state (Bullish / Neutral / Deteriorating / Recovering /
Bearish) from indicators it already computes (A-D, NH-NL, percent-above-MA), and the stop
width and entry admission read that state — width 12–14% when Bullish/Recovering, the
4–6% band or no entries when Deteriorating. That is the paired surface, with the state
machine in `Macro` and the width map in the stops config, each an axis.

## Correction (qc-behavioral rework 1, 16:10 PDT): what the cadence knob actually does

Earlier sections described the `stop_update_cadence Weekly` arms as evaluating the stop on
the weekly close. That is wrong. `stops_runner.mli` (lines 15–25) is explicit: the trigger is
**continuous (intraday) in both cadences**; `Weekly` only advances the trail state machine
on the week's final trading day, so mid-week ticks still fire a stop when the bar's low
crosses it but do **not** raise it. The PR's own artifacts confirm it — weekday of stop
exits, Mon..Fri: `sw5y-2019-w12-W-s0` 24 / 24 / 14 / 14 / 18 vs its daily twin 25 / 23 /
13 / 15 / 22; `sw26y-w12-W-s0` 66 / 77 / 59 / 52 / 74. Friday-only triggering would put
nearly every exit on Monday.

So the mechanism of the "W" arms is a **level effect**: between Fridays the trail rests
where it was last raised, i.e. lower than the daily-raised trail, and fewer shakeout lows
reach it. That is why the cadence only matters at wide widths (at 4–8% the resting level is
hit either way) and why the 26y `w12-W` arm's drawdown improvement comes from fewer
crash-week stop-outs, not from skipping intraday lows. The book-faithfulness reading is
unchanged in substance: Ch. 6 has the protective stop as a resting order executed when its
level is hit, with the trail moved on the weekly correction cycle — the `Weekly` arm mirrors
that contract, the `Daily` arm does not. The `.claude/rules/qc-behavioral-authority.md` L3
row ("stop triggers on weekly close, not intraday") is not supported by the reference doc
§5.1 and needs its own docs write-back (filed separately). Nothing numeric above changes;
every "weekly-close" phrase now reads "weekly-update" and the three mechanism sentences in
§Interim 03:11, §Mechanism and §26y `w12-W` were rewritten.
