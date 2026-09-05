# Yearly trade review, 2000–2026 — every record trade graded, the strongest sector and stock each year, and whether the signal finds the money

Source: the canonical record on the fixed basis (`record-rebase-2026-09-03/results/rec26y-new-s0-trades.csv`,
723 trades, 2000-01-03 → 2026-06-26, top-3000 PIT-2000, record convention). Prices for the
post-trade paths and the market/sector tables are the CSV store (`data/`), read basis-free
(every ratio inside one series). Universe per year = that year's `top-3000-<year>.sexp`
composition (≈2,000–2,800 names with full-year prices). Sector = `data/sectors.csv`; delisted
old names without a tag are "(untagged)". Working files: `/tmp/yr-run/` (graded.csv, sy.csv,
sector_year.csv); scripts in the same directory (sh + awk).

## Takeaway

1. **The system is a 22%-hit-rate machine and the hits are everything.** 162 of 723 trades
   graded A made **+$9.05M**; the other 561 lost **−$6.4M** between them, and two delisting
   stub prints (STMP 2021, CLE 2014, issue #2672) took another **−$741k** that never happened.
   Net +$2.2M realised. Thirteen of 26 years lose money; four years (2004, 2013, 2017, 2021)
   carry the run, each on one or two names.
2. **Exit mechanics sort cleanly by grade.** Laggard-rotation exits: 130 A / 71 B / 26 C / 10 D
   — 55% A. Stop exits: 26 A / 136 B / 159 C / 131 D / 15 F — 31% whipsaws (stopped, then
   ≥ +15% within 13 weeks), 29% right (stock lower 13 weeks later), 34% noise. Holding the 141
   D-grade whipsaws 13 more weeks would have been worth ≈ **+$6.9M** at the later close
   instead of −$2.6M realised. That is the 4%-fallback-stop tax, and it is larger than the
   whole run's net.
3. **The relative-strength signal has no cross-sectional power at the yearly horizon.** Within
   each sector-year, Spearman(year-start RS vs calendar-year return) = **−0.007** (322
   groups, positive in 50%); mid-year RS vs H2 return +0.008. Signal deciles: median year
   return 5.9% for the strongest decile vs 9–11% for the middle; the strongest decile has the
   fattest right tail (winsorized mean +15–17% vs +13%), i.e. **RS at the top is a lottery
   ticket, not a ranking**. Of each sector-year's five biggest winners, only **11%** were
   top-5 by signal and 27% top-20.
4. **The strongest sector by signal is almost never the strongest sector that year.** Median
   sector return: the signal-best sector at year start matched the market-best sector in
   **1 of 27 years** (2024). Our own best-P&L sector matched the market-best in 3 of 27
   (2009, 2020, 2026). Weinstein's sector call works as a *filter* (we made money in energy
   in 2000/2006, tech in 2020/2023/2025), not as a *forecast*.
5. **We do not catch the money-makers, but we do pick above-median names.** Of 1,610 top-5-
   by-return sector-year names, the record traded **17 (1.1%)**; of our 658 traded name-years,
   3% were top-5 and 14% top-20 in their sector (base rate for top-20 ≈ 11%). Yet traded
   names returned **+32% for the year vs a +14% sector median, 69% above median** — partly
   real selection, partly look-ahead (we enter after the move that makes the year return).
6. **What this implies.** The edge is not in ranking and not in exits; it is in *being in* the
   4–8 names a year that run 50–140% and *staying in*. Two levers follow directly: (a) the
   stop that produces 141 whipsaws worth $9M of swing, and (b) the funnel that admits 1% of
   the eventual winners. Everything else measured this week — rotation, extension stop,
   stage-3 exit, the clock — moves the needle by tens of thousands.

## Grade rubric (mechanical, hindsight-informed, applied to all 723)

A: P&L ≥ +20%, or a winner sold within 10% of the following 13-week high · B: modest win, or a
stop that was right (stock ≤ −5% 13 weeks later) · C: small loss/gain, flat after · D: whipsaw —
stopped, then ≥ +15% within 13 weeks · F: stopped, then ≥ +50% · X: delisting stub print.

| grade | n | realised $ | avg |
|---|---:|---:|---:|
| A | 162 | +9051180 | +55871 |
| B | 209 | -560801 | -2683 |
| C | 187 | -2882713 | -15416 |
| D | 141 | -2611194 | -18519 |
| F | 15 | -304259 | -20284 |
| NODATA | 7 | +254051 | +36293 |
| X | 2 | -741039 | -370519 |

| exit trigger | A | B | C | D | F | X |
|---|---:|---:|---:|---:|---:|---:|
|  | 0 | 0 | 0 | 0 | 0 | 0 |
| extension_stop | 3 | 0 | 0 | 0 | 0 | 0 |
| laggard_rotation | 130 | 71 | 26 | 10 | 0 | 0 |
| liquidity_exit | 0 | 2 | 0 | 0 | 0 | 0 |
| stage3_force_exit | 3 | 0 | 2 | 0 | 0 | 0 |
| stop_loss | 26 | 136 | 159 | 131 | 15 | 2 |

## Year by year — trades, grades, strongest sector by market / by signal / by our P&L

"market-best" = highest median calendar-year return among sectors with ≥ 10 names that year;
"signal-best" = highest median year-start 26-week RS vs GSPC; "our P&L" = record trades entered
that year. Full per-year tables follow the summary.

| year | n | win% | realised | A/B/C/D/F | market-best sector (median) | signal-best sector (its median) | our best sector |
|---|---:|---:|---:|---|---|---|---|
| 2000 | 31 | 39% | +270k | 9/8/5/7/2 | Health Care            (+43%) | Information Technology (-28%) | Energy                  (+249k) |
| 2001 | 9 | 33% | -35k | 1/5/1/2/0 | Consumer Discretionary (+35%) | Utilities              (-3%) | Information Technology    (+0k) |
| 2002 | 9 | 44% | -23k | 3/4/1/0/0 | Real Estate            (+8%) | Consumer Staples       (+2%) | Financials                (+3k) |
| 2003 | 25 | 44% | +407k | 8/4/5/7/1 | Information Technology (+71%) | Communication Services (+41%) | Industrials             (+296k) |
| 2004 | 30 | 10% | +77k | 2/7/13/8/0 | Energy                 (+41%) | Information Technology (-0%) | Consumer Discretionary   (+27k) |
| 2005 | 28 | 36% | +71k | 3/9/8/7/1 | Energy                 (+39%) | Real Estate            (+13%) | Industrials             (+108k) |
| 2006 | 28 | 36% | +158k | 9/5/9/4/0 | Real Estate            (+37%) | Energy                 (+16%) | Energy                  (+170k) |
| 2007 | 15 | 47% | -29k | 6/3/3/3/0 | Energy                 (+25%) | Real Estate            (-17%) | Health Care              (+20k) |
| 2008 | 3 | 33% | +7k | 1/1/0/1/0 | Utilities              (-22%) | Materials              (-46%) | Industrials              (+35k) |
| 2009 | 23 | 9% | -217k | 1/3/11/7/1 | Information Technology (+64%) | Consumer Staples       (+24%) | Information Technology   (+10k) |
| 2010 | 29 | 31% | +36k | 7/10/8/3/1 | Consumer Discretionary (+38%) | Real Estate            (+27%) | Health Care              (+70k) |
| 2011 | 15 | 27% | -76k | 3/5/2/5/0 | Utilities              (+17%) | Materials              (-13%) | Health Care               (+5k) |
| 2012 | 29 | 48% | +320k | 12/4/5/8/0 | Real Estate            (+26%) | Utilities              (+4%) | Consumer Discretionary  (+135k) |
| 2013 | 26 | 65% | +702k | 13/5/7/1/0 | Communication Services (+48%) | Materials              (+21%) | Industrials             (+422k) |
| 2014 | 27 | 41% | +144k | 10/3/8/5/0 | Real Estate            (+29%) | Health Care            (+23%) | Consumer Staples        (+267k) |
| 2015 | 24 | 17% | -148k | 0/12/8/3/0 | Consumer Staples       (+14%) | Health Care            (+7%) | Materials                 (+0k) |
| 2016 | 26 | 38% | +413k | 8/4/7/7/0 | Materials              (+39%) | Utilities              (+19%) | Information Technology  (+254k) |
| 2017 | 24 | 50% | +440k | 6/7/8/2/1 | Information Technology (+31%) | Financials             (+16%) | Industrials             (+150k) |
| 2018 | 38 | 26% | -367k | 6/14/13/5/0 | Utilities              (+4%) | Consumer Discretionary (-9%) | Information Technology   (+16k) |
| 2019 | 35 | 37% | -183k | 6/16/7/6/0 | Information Technology (+39%) | Utilities              (+25%) | Industrials             (+125k) |
| 2020 | 48 | 42% | +1162k | 10/16/7/10/3 | Information Technology (+37%) | Materials              (+17%) | Information Technology  (+858k) |
| 2021 | 25 | 40% | -399k | 10/4/5/5/0 | Energy                 (+43%) | Consumer Discretionary (+24%) | Real Estate             (+156k) |
| 2022 | 43 | 30% | -211k | 5/20/9/9/0 | Energy                 (+56%) | Utilities              (+0%) | Consumer Staples         (+22k) |
| 2023 | 38 | 32% | +26k | 7/10/11/7/2 | Industrials            (+26%) | Energy                 (+9%) | Information Technology  (+152k) |
| 2024 | 43 | 30% | -255k | 6/14/14/9/0 | Financials             (+23%) | Financials             (+23%) | Industrials             (+111k) |
| 2025 | 35 | 31% | +251k | 8/8/9/6/3 | Materials              (+21%) | Financials             (+9%) | Information Technology  (+217k) |
| 2026 | 17 | 12% | -336k | 2/8/3/4/0 | Energy                 (+40%) | Health Care            (+13%) | Energy                   (+14k) |

## Does the signal find the money? (all names, all years)

| within-year RS decile at Jan 1 (1 = strongest) | median year return | winsorized mean | n |
|---|---:|---:|---:|
| 1 | +5.9% | +15.0% | 5825 |
| 2 | +8.6% | +13.2% | 5815 |
| 3 | +9.2% | +12.7% | 5818 |
| 4 | +9.8% | +13.2% | 5813 |
| 5 | +11.2% | +14.0% | 5811 |
| 6 | +10.6% | +13.5% | 5818 |
| 7 | +10.9% | +14.2% | 5816 |
| 8 | +9.8% | +14.1% | 5815 |
| 9 | +9.7% | +15.8% | 5818 |
| 10 | +3.8% | +16.8% | 5801 |

Within sector-year (322 groups, n ≥ 10): Spearman(year-start RS, year return) mean **−0.007**,
positive in 50%, > +0.2 in 12%, < −0.2 in 14%; Spearman(mid-year RS, H2 return) mean +0.008,
positive in 57%. Top-5-by-signal names: winsorized mean +21% vs +14% for the rest — a fatter
tail, a lower median. Of the top-5-by-return names per sector-year, 11% were top-5 by signal
and 27% top-20.

Catch rates: the record traded 17 of 1,610 top-5-by-return sector-year names (1.1%) and 18 of
1,610 top-5-by-signal (1.1%). Of the 658 name-years it traded, 3% were top-5 and 14% top-20 by
return in their sector (≈ 11% base rate), 3% / 11% by signal. Traded names' year return
averaged +32% vs their sector-year median +14% (69% above median) — with the look-ahead caveat
above.

Caveats: the signal here is a proxy (26-week RS vs GSPC at two snapshots), not the screener's
weekly cascade score; calendar-year return is a coarse outcome for a system that holds 2–12
months; 0.6% of symbol-years (mis-adjusted splits, stub prints) were excluded and returns
winsorized to [−95%, +300%] for the rank statistics; sector tags are current, not point-in-time.

---
# Per-year detail

## 2000 — 31 trades, 39% winners, realised +270k · grades A 9 / B 8 / C 5 / D 7 / F 2

Market: market-best Health Care            med  +43% (n= 90) | signal-best Information Technology (its med ret  -28%)       | our-P&L-best Energy                  +249k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Energy | 3 | 3 | +249k | NOV EOG CNX |
| (untagged) | 16 | 9 | +139k | TWX1 TBI1 SFAM PHCC FLMIQ CRE_old CRCL_old1 CLTR2 BSC_old BKI_old BEC BEAS BDLN APWR AKZOY AGN_old |
| Utilities | 1 | 0 | -7k | ES |
| Financials | 2 | 0 | -10k | CFFN AJG |
| Materials | 1 | 0 | -11k | BHP |
| Consumer Discretionary | 1 | 0 | -13k | BRSL |
| Industrials | 4 | 0 | -30k | MLKN DE CRS AIT |
| Health Care | 3 | 0 | -46k | XRAY RGEN NEOG |

Best: CNX +142k (Energy, 2000-06-14→2001-03-20, stop_loss, grade A); APWR +89k ((untagged), 2000-01-24→2000-04-10, extension_stop, grade A); EOG +59k (Energy, 2000-05-01→2001-02-27, stop_loss, grade A); 

Worst: NEOG -22k (Health Care, 2000-03-25→2000-04-04, stop_loss, grade B); RGEN -19k (Health Care, 2000-02-05→2000-02-08, stop_loss, grade F); TBI1 -17k ((untagged), 2000-04-28→2000-07-25, stop_loss, grade F); 

Whipsaws (D/F): XRAY (stopped -3.5%, +13wk max +15%); TWX1 (stopped -5.0%, +13wk max +29%); TBI1 (stopped -9.5%, +13wk max +53%); RGEN (stopped -13.6%, +13wk max +262%); PHCC (stopped -3.2%, +13wk max +47%); MLKN (stopped -11.5%, +13wk max +16%); CRS (stopped -2.5%, +13wk max +40%); CFFN (stopped -2.9%, +13wk max +44%); BRSL (stopped -9.4%, +13wk max +28%); 

## 2001 — 9 trades, 33% winners, realised -35k · grades A 1 / B 5 / C 1 / D 2 / F 0

Market: market-best Consumer Discretionary med  +35% (n=110) | signal-best Utilities              (its med ret   -3%)       | our-P&L-best Information Technology    +0k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Health Care | 3 | 2 | -0k | NBIX MDT ICLR |
| Consumer Discretionary | 1 | 0 | -3k | CHH |
| Industrials | 1 | 0 | -3k | SWK |
| Materials | 1 | 0 | -6k | PKG |
| Financials | 2 | 1 | -10k | BBAR AON |
| (untagged) | 1 | 0 | -13k | MATK |

Best: MDT +1k (Health Care, 2001-04-03→2001-04-05, stop_loss, grade B); ICLR +0k (Health Care, 2001-06-18→2001-06-27, stop_loss, grade B); BBAR +0k (Financials, 2001-01-18→2001-03-20, stop_loss, grade A); 

Worst: MATK -13k ((untagged), 2001-06-13→2001-07-18, stop_loss, grade B); AON -11k (Financials, 2001-10-03→2001-10-22, stop_loss, grade B); PKG -6k (Materials, 2001-07-02→2001-07-06, stop_loss, grade D); 

Whipsaws (D/F): PKG (stopped -3.6%, +13wk max +27%); CHH (stopped -1.8%, +13wk max +34%); 

## 2002 — 9 trades, 44% winners, realised -23k · grades A 3 / B 4 / C 1 / D 0 / F 0

Market: market-best Real Estate            med   +8% (n= 59) | signal-best Consumer Staples       (its med ret   +2%)       | our-P&L-best Financials                +3k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| (untagged) | 3 | 2 | +6k | WLL1 VLCY NHYDY |
| Financials | 2 | 2 | +3k | MCY FULT |
| Industrials | 1 | 0 | -7k | TKR |
| Materials | 1 | 0 | -10k | CLF |
| Health Care | 2 | 0 | -15k | UTHR DHR |

Best: WLL1 +6k ((untagged), 2002-01-22→2002-03-19, , grade NODATA); NHYDY +4k ((untagged), 2002-03-14→2002-06-27, stop_loss, grade A); MCY +2k (Financials, 2002-03-26→2002-06-26, stop_loss, grade A); 

Worst: UTHR -11k (Health Care, 2002-11-21→2002-11-25, stop_loss, grade B); CLF -10k (Materials, 2002-04-22→2002-06-10, stop_loss, grade C); TKR -7k (Industrials, 2002-03-21→2002-05-31, stop_loss, grade B); 

## 2003 — 25 trades, 44% winners, realised +407k · grades A 8 / B 4 / C 5 / D 7 / F 1

Market: market-best Information Technology med  +71% (n=131) | signal-best Communication Services (its med ret  +41%)       | our-P&L-best Industrials             +296k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Industrials | 6 | 3 | +279k | WNC RYAAY MMM HEI EXPO AZZ |
| Health Care | 3 | 1 | +82k | HSIC DVA CRVL |
| Communication Services | 1 | 1 | +44k | TIMB |
| (untagged) | 4 | 3 | +28k | WLP1 DRYR CWLZ CEB |
| Financials | 3 | 1 | +2k | ORI AMG ACGL |
| Information Technology | 3 | 1 | +0k | WDC TRMB AAPL |
| Consumer Discretionary | 5 | 1 | -27k | SCI PENN COLM BWA BKNG |

Best: WNC +271k (Industrials, 2003-05-09→2004-03-01, laggard_rotation, grade A); DVA +92k (Health Care, 2003-06-21→2004-02-09, laggard_rotation, grade A); TIMB +44k (Communication Services, 2003-09-13→2004-02-09, laggard_rotation, grade A); 

Worst: AZZ -18k (Industrials, 2003-08-30→2003-09-26, stop_loss, grade D); BKNG -18k (Consumer Discretionary, 2003-06-12→2003-06-17, stop_loss, grade F); BWA -10k (Consumer Discretionary, 2003-07-21→2003-07-23, stop_loss, grade D); 

Whipsaws (D/F): SCI (stopped -3.0%, +13wk max +19%); RYAAY (stopped -2.7%, +13wk max +22%); PENN (stopped -5.0%, +13wk max +22%); HSIC (stopped -3.0%, +13wk max +22%); CEB (stopped -4.0%, +13wk max +18%); BWA (stopped -5.9%, +13wk max +19%); BKNG (stopped -10.3%, +13wk max +64%); AZZ (stopped -11.5%, +13wk max +22%); 

## 2004 — 30 trades, 10% winners, realised +77k · grades A 2 / B 7 / C 13 / D 8 / F 0

Market: market-best Energy                 med  +41% (n= 66) | signal-best Information Technology (its med ret   -0%)       | our-P&L-best Consumer Discretionary   +27k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| (untagged) | 8 | 1 | +176k | TLB IUSA_old IPIXQ ECLP COGN BRW_old ARTI_old ABNK_old |
| Consumer Discretionary | 8 | 1 | +27k | PLCE ORLY MAR M JACK HMC ANF ANF |
| Consumer Staples | 1 | 0 | -6k | TGT |
| Real Estate | 1 | 0 | -8k | LAMR |
| Utilities | 1 | 0 | -17k | EVRG |
| Information Technology | 3 | 0 | -26k | MSTR MEI DXC |
| Materials | 3 | 0 | -34k | OLN B ALB |
| Industrials | 5 | 1 | -36k | KFRC GWW FWRD ARCB AGCO |

Best: IPIXQ +256k ((untagged), 2004-04-03→2004-04-19, extension_stop, grade A); ANF +85k (Consumer Discretionary, 2004-10-30→2005-08-31, stop_loss, grade A); ARCB +27k (Industrials, 2004-07-21→2005-01-24, laggard_rotation, grade B); 

Worst: ARTI_old -24k ((untagged), 2004-05-19→2004-05-21, stop_loss, grade C); B -20k (Materials, 2004-03-31→2004-04-14, stop_loss, grade C); KFRC -19k (Industrials, 2004-11-05→2005-01-13, stop_loss, grade B); 

Whipsaws (D/F): PLCE (stopped -2.6%, +13wk max +17%); OLN (stopped -7.7%, +13wk max +18%); MSTR (stopped -11.9%, +13wk max +26%); FWRD (stopped -4.7%, +13wk max +18%); ANF (stopped -5.1%, +13wk max +20%); ALB (stopped -0.0%, +13wk max +18%); AGCO (stopped -14.1%, +13wk max +16%); ABNK_old (stopped -3.2%, +13wk max +21%); 

## 2005 — 28 trades, 36% winners, realised +71k · grades A 3 / B 9 / C 8 / D 7 / F 1

Market: market-best Energy                 med  +39% (n= 71) | signal-best Real Estate            (its med ret  +13%)       | our-P&L-best Industrials             +108k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Industrials | 4 | 1 | +85k | RHI NDSN FORR EME |
| Information Technology | 2 | 2 | +53k | MSTR CXT |
| Health Care | 1 | 1 | +26k | BHC |
| Financials | 2 | 1 | -7k | TFC RY |
| Consumer Discretionary | 2 | 0 | -17k | HRB AMZN |
| Energy | 2 | 0 | -17k | OII INVX |
| (untagged) | 15 | 5 | -51k | TIN SVM1 SRCL SIAL SHAW RDA1 PLFE LAUR1 KOSP IMDC1 GIFI CVD BCSI ARG ACV_old |

Best: EME +129k (Industrials, 2005-02-25→2006-02-27, laggard_rotation, grade A); CXT +33k (Information Technology, 2005-12-01→2006-07-24, laggard_rotation, grade B); BHC +26k (Health Care, 2005-09-09→2006-02-06, laggard_rotation, grade B); 

Worst: FORR -23k (Industrials, 2005-07-28→2005-10-12, stop_loss, grade C); SVM1 -22k ((untagged), 2005-10-10→2005-10-12, stop_loss, grade C); SHAW -16k ((untagged), 2005-09-24→2005-10-07, stop_loss, grade D); 

Whipsaws (D/F): TIN (stopped -3.2%, +13wk max +17%); SRCL (stopped -3.4%, +13wk max +15%); SHAW (stopped -6.9%, +13wk max +43%); OII (stopped -4.4%, +13wk max +37%); NDSN (stopped -4.2%, +13wk max +19%); INVX (stopped -3.8%, +13wk max +48%); HRB (stopped -1.2%, +13wk max +18%); BCSI (stopped -3.7%, +13wk max +56%); 

## 2006 — 28 trades, 36% winners, realised +158k · grades A 9 / B 5 / C 9 / D 4 / F 0

Market: market-best Real Estate            med  +37% (n= 64) | signal-best Energy                 (its med ret  +16%)       | our-P&L-best Energy                  +170k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Energy | 1 | 1 | +170k | UGP |
| Materials | 3 | 1 | +56k | SHW GEF AVY |
| Financials | 4 | 2 | +2k | MTB EWBC BSAC BRK-A |
| Health Care | 2 | 1 | +2k | IDXX ALXN |
| Communication Services | 1 | 0 | -5k | IAC |
| (untagged) | 6 | 2 | -6k | RBAK LDG HSII GIFI FLSH ECLP |
| Consumer Discretionary | 3 | 1 | -7k | WWW DRI ANF |
| Industrials | 4 | 2 | -11k | GD ESE AME ADP |
| Consumer Staples | 1 | 0 | -19k | MZTI |
| Information Technology | 3 | 0 | -25k | BB ADBE ACIW |

Best: UGP +170k (Energy, 2006-10-20→2007-12-21, stop_loss, grade A); GEF +101k (Materials, 2006-09-05→2007-03-26, laggard_rotation, grade A); HSII +53k ((untagged), 2006-10-12→2007-05-29, laggard_rotation, grade A); 

Worst: GIFI -35k ((untagged), 2006-11-01→2007-03-05, stop_loss, grade D); SHW -34k (Materials, 2006-01-21→2006-02-23, stop_loss, grade D); MZTI -19k (Consumer Staples, 2006-09-15→2006-10-31, stop_loss, grade C); 

Whipsaws (D/F): SHW (stopped -14.0%, +13wk max +26%); LDG (stopped -11.5%, +13wk max +16%); GIFI (stopped -14.1%, +13wk max +30%); BB (stopped -4.3%, +13wk max +39%); 

## 2007 — 15 trades, 47% winners, realised -29k · grades A 6 / B 3 / C 3 / D 3 / F 0

Market: market-best Energy                 med  +25% (n= 74) | signal-best Real Estate            (its med ret  -17%)       | our-P&L-best Health Care              +20k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Health Care | 1 | 1 | +20k | BMY |
| (untagged) | 5 | 3 | +2k | STR_old IIJIY GAS1 AXE ARTC_old |
| Financials | 1 | 0 | -7k | AON |
| Industrials | 5 | 2 | -15k | TTC PKE HEI ETN AAON |
| Information Technology | 3 | 1 | -27k | SCSC PEGA MSFT |

Best: BMY +20k (Health Care, 2007-01-04→2007-08-13, laggard_rotation, grade A); STR_old +17k ((untagged), 2007-04-03→2007-08-06, stop_loss, grade B); ETN +17k (Industrials, 2007-02-21→2007-10-22, laggard_rotation, grade A); 

Worst: IIJIY -29k ((untagged), 2007-11-14→2007-11-20, stop_loss, grade B); SCSC -22k (Information Technology, 2007-11-03→2007-11-21, stop_loss, grade C); PKE -22k (Industrials, 2007-08-10→2007-08-14, stop_loss, grade D); 

Whipsaws (D/F): TTC (stopped -3.0%, +13wk max +19%); PKE (stopped -7.8%, +13wk max +21%); HEI (stopped -4.3%, +13wk max +33%); 

## 2008 — 3 trades, 33% winners, realised +7k · grades A 1 / B 1 / C 0 / D 1 / F 0

Market: market-best Utilities              med  -22% (n= 56) | signal-best Materials              (its med ret  -46%)       | our-P&L-best Industrials              +35k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Industrials | 1 | 1 | +35k | CPRT |
| (untagged) | 2 | 0 | -28k | SIVB NTTYY |

Best: CPRT +35k (Industrials, 2008-10-08→2008-10-13, stop_loss, grade A); NTTYY -11k ((untagged), 2008-07-02→2008-07-14, stop_loss, grade B); SIVB -17k ((untagged), 2008-07-23→2008-07-25, stop_loss, grade D); 

Worst: SIVB -17k ((untagged), 2008-07-23→2008-07-25, stop_loss, grade D); NTTYY -11k ((untagged), 2008-07-02→2008-07-14, stop_loss, grade B); CPRT +35k (Industrials, 2008-10-08→2008-10-13, stop_loss, grade A); 

Whipsaws (D/F): SIVB (stopped -6.5%, +13wk max +19%); 

## 2009 — 23 trades, 9% winners, realised -217k · grades A 1 / B 3 / C 11 / D 7 / F 1

Market: market-best Information Technology med  +64% (n=147) | signal-best Consumer Staples       (its med ret  +24%)       | our-P&L-best Information Technology   +10k MATCH

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Information Technology | 6 | 1 | +10k | MSTR INFY HPQ GEN COHR CHKP |
| Industrials | 2 | 1 | +7k | LII GWW |
| Real Estate | 1 | 0 | -12k | SVC |
| Consumer Discretionary | 1 | 0 | -14k | CATO |
| Consumer Staples | 2 | 0 | -22k | JJSF CASY |
| Health Care | 2 | 0 | -34k | NEOG ALXN |
| Financials | 2 | 0 | -48k | RDN IBN |
| (untagged) | 3 | 0 | -50k | SHFL PSSI HOTT |
| Materials | 4 | 0 | -55k | MTX ECL B B |

Best: CHKP +66k (Information Technology, 2009-08-07→2010-03-29, laggard_rotation, grade A); GWW +10k (Industrials, 2009-10-31→2010-06-08, stop_loss, grade B); LII -2k (Industrials, 2009-11-14→2009-12-07, laggard_rotation, grade D); 

Worst: RDN -32k (Financials, 2009-08-06→2009-08-10, stop_loss, grade F); B -30k (Materials, 2009-09-08→2009-09-10, stop_loss, grade D); HOTT -23k ((untagged), 2009-03-31→2009-04-08, stop_loss, grade B); 

Whipsaws (D/F): SVC (stopped -4.7%, +13wk max +28%); SHFL (stopped -7.0%, +13wk max +16%); RDN (stopped -12.2%, +13wk max +69%); MTX (stopped -8.6%, +13wk max +24%); LII (stopped -1.0%, +13wk max +20%); INFY (stopped -5.9%, +13wk max +28%); COHR (stopped -4.8%, +13wk max +41%); B (stopped -11.8%, +13wk max +27%); 

## 2010 — 29 trades, 31% winners, realised +36k · grades A 7 / B 10 / C 8 / D 3 / F 1

Market: market-best Consumer Discretionary med  +38% (n=162) | signal-best Real Estate            (its med ret  +27%)       | our-P&L-best Health Care              +70k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Health Care | 2 | 2 | +70k | FMS EW |
| Consumer Staples | 5 | 2 | +52k | INGR HSY EL COKE CCU |
| Materials | 1 | 1 | +18k | SHW |
| Industrials | 7 | 1 | +13k | SSD SPXC HUBG HTLD DE CAT CAR |
| Utilities | 2 | 2 | +7k | NJR EVRG |
| Financials | 3 | 1 | -15k | FDS AIG ACGL |
| Consumer Discretionary | 2 | 0 | -21k | GPC COLM |
| (untagged) | 3 | 0 | -40k | SHFL PFCB JDAS |
| Information Technology | 4 | 0 | -47k | PTC MKSI MANH AEIS |

Best: INGR +76k (Consumer Staples, 2010-09-16→2011-02-28, laggard_rotation, grade A); CAT +70k (Industrials, 2010-09-21→2011-06-13, laggard_rotation, grade A); EW +65k (Health Care, 2010-09-23→2011-05-23, laggard_rotation, grade A); 

Worst: SHFL -26k ((untagged), 2010-05-14→2010-05-20, stop_loss, grade C); AEIS -18k (Information Technology, 2010-04-01→2010-04-06, stop_loss, grade B); HUBG -14k (Industrials, 2010-03-20→2010-03-29, stop_loss, grade D); 

Whipsaws (D/F): HUBG (stopped -5.8%, +13wk max +20%); DE (stopped -4.9%, +13wk max +23%); CCU (stopped -2.8%, +13wk max +33%); AIG (stopped -4.4%, +13wk max +99%); 

## 2011 — 15 trades, 27% winners, realised -76k · grades A 3 / B 5 / C 2 / D 5 / F 0

Market: market-best Utilities              med  +17% (n= 58) | signal-best Materials              (its med ret  -13%)       | our-P&L-best Health Care               +5k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Health Care | 1 | 1 | +5k | EHC |
| Information Technology | 2 | 1 | +5k | FICO CRUS |
| (untagged) | 3 | 1 | -0k | MRX_old ITMN FDO |
| Consumer Discretionary | 1 | 0 | -3k | NKE |
| Financials | 1 | 0 | -6k | WBS |
| Consumer Staples | 3 | 1 | -19k | MO BF-B BF-A |
| Industrials | 3 | 0 | -21k | CTAS CPRT CAR |
| Communication Services | 1 | 0 | -36k | VOD |

Best: ITMN +15k ((untagged), 2011-08-08→2011-08-10, stop_loss, grade B); FICO +12k (Information Technology, 2011-03-05→2011-06-27, laggard_rotation, grade A); EHC +5k (Health Care, 2011-01-10→2011-08-02, stop_loss, grade A); 

Worst: VOD -36k (Communication Services, 2011-01-05→2011-01-07, stop_loss, grade C); BF-A -13k (Consumer Staples, 2011-07-01→2011-08-10, stop_loss, grade D); CTAS -11k (Industrials, 2011-07-01→2011-07-13, stop_loss, grade B); 

Whipsaws (D/F): MRX_old (stopped -2.8%, +13wk max +28%); MO (stopped -5.9%, +13wk max +16%); FDO (stopped -5.7%, +13wk max +23%); CPRT (stopped -0.4%, +13wk max +18%); BF-A (stopped -10.7%, +13wk max +24%); 

## 2012 — 29 trades, 48% winners, realised +320k · grades A 12 / B 4 / C 5 / D 8 / F 0

Market: market-best Real Estate            med  +26% (n= 88) | signal-best Utilities              (its med ret   +4%)       | our-P&L-best Consumer Discretionary  +135k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Industrials | 5 | 4 | +163k | FSS FELE CNH ALK AIT |
| Consumer Discretionary | 9 | 4 | +135k | WWW TOL MOV JACK ETD EBAY CHDN BC AMZN |
| Health Care | 5 | 3 | +20k | REGN GERN CNMD AMGN AGN |
| Financials | 1 | 1 | +17k | SPGI |
| Information Technology | 5 | 1 | +15k | WDC VRSN MANH HCKT APH |
| Consumer Staples | 1 | 0 | -8k | JJSF |
| (untagged) | 2 | 1 | -8k | SKX LSI1 |
| Real Estate | 1 | 0 | -13k | DOC |

Best: EBAY +119k (Consumer Discretionary, 2012-02-23→2013-03-04, laggard_rotation, grade A); ALK +111k (Industrials, 2012-11-01→2013-06-17, laggard_rotation, grade A); REGN +101k (Health Care, 2012-01-28→2012-07-16, laggard_rotation, grade A); 

Worst: GERN -76k (Health Care, 2012-09-01→2012-09-11, stop_loss, grade D); HCKT -24k (Information Technology, 2012-03-26→2012-06-06, stop_loss, grade D); CNH -20k (Industrials, 2012-11-23→2012-12-19, stop_loss, grade D); 

Whipsaws (D/F): TOL (stopped -3.0%, +13wk max +21%); SKX (stopped -3.9%, +13wk max +22%); MOV (stopped -3.0%, +13wk max +18%); HCKT (stopped -10.3%, +13wk max +19%); GERN (stopped -54.1%, +13wk max +39%); CNH (stopped -17.2%, +13wk max +19%); CHDN (stopped -3.1%, +13wk max +17%); AMZN (stopped -6.8%, +13wk max +21%); 

## 2013 — 26 trades, 65% winners, realised +702k · grades A 13 / B 5 / C 7 / D 1 / F 0

Market: market-best Communication Services med  +48% (n= 66) | signal-best Materials              (its med ret  +21%)       | our-P&L-best Industrials             +422k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Industrials | 8 | 5 | +422k | WNC UFPI TRN FWRD CSGS CMI ABM AAON |
| Financials | 4 | 3 | +119k | WFC WAFD FITB BRK-A |
| Consumer Discretionary | 4 | 3 | +94k | M KBH CAL AMZN |
| Information Technology | 4 | 2 | +62k | TXN ROG BDC AEIS |
| Health Care | 3 | 2 | +18k | UNH MRK GSK |
| Consumer Staples | 1 | 1 | +8k | TGT |
| (untagged) | 1 | 1 | +0k | ISCA |
| Energy | 1 | 0 | -21k | SGU |

Best: TRN +212k (Industrials, 2013-10-31→2014-06-30, laggard_rotation, grade A); AAON +172k (Industrials, 2013-01-14→2013-07-15, laggard_rotation, grade A); WAFD +71k (Financials, 2013-06-29→2013-10-28, laggard_rotation, grade A); 

Worst: SGU -21k (Energy, 2013-02-09→2013-03-07, stop_loss, grade C); MRK -14k (Health Care, 2013-04-23→2013-05-02, stop_loss, grade C); AEIS -13k (Information Technology, 2013-11-05→2013-11-20, stop_loss, grade D); 

Whipsaws (D/F): AEIS (stopped -4.0%, +13wk max +25%); 

## 2014 — 27 trades, 41% winners, realised +144k · grades A 10 / B 3 / C 8 / D 5 / F 0 / stub-print X 1

Market: market-best Real Estate            med  +29% (n= 88) | signal-best Health Care            (its med ret  +23%)       | our-P&L-best Consumer Staples        +267k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Consumer Staples | 2 | 2 | +267k | KR CLX |
| Information Technology | 7 | 4 | +84k | NICE LRCX KLIC DXC BDC AWRE ADI |
| Energy | 1 | 1 | +43k | TK |
| Industrials | 1 | 0 | -10k | TXT |
| Materials | 2 | 0 | -14k | SON CX |
| Financials | 5 | 2 | -26k | SEIC RF FHI BRK-A BRK-A |
| Health Care | 2 | 0 | -36k | VRTX BCRX |
| Consumer Discretionary | 4 | 1 | -41k | PII MOD MATW KSS |
| (untagged) | 3 | 1 | -124k | X CLE CBKCQ |

Best: KR +222k (Consumer Staples, 2014-03-15→2015-05-11, laggard_rotation, grade A); NICE +123k (Information Technology, 2014-11-12→2015-08-25, stop_loss, grade A); LRCX +62k (Information Technology, 2014-05-03→2015-02-09, laggard_rotation, grade A); 

Worst: CLE -147k ((untagged), 2014-11-18→2014-11-19, stop_loss, grade X); AWRE -98k (Information Technology, 2014-07-12→2014-07-28, stop_loss, grade B); VRTX -29k (Health Care, 2014-06-28→2014-08-08, stop_loss, grade D); 

Whipsaws (D/F): VRTX (stopped -7.6%, +13wk max +36%); SEIC (stopped -4.7%, +13wk max +20%); MOD (stopped -6.4%, +13wk max +19%); CBKCQ (stopped -4.5%, +13wk max +23%); ADI (stopped -5.3%, +13wk max +21%); 

## 2015 — 24 trades, 17% winners, realised -148k · grades A 0 / B 12 / C 8 / D 3 / F 0

Market: market-best Consumer Staples       med  +14% (n= 80) | signal-best Health Care            (its med ret   +7%)       | our-P&L-best Materials                 +0k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Health Care | 5 | 2 | +131k | PCYC DHR CRVL BCRX ALKS |
| Utilities | 1 | 0 | -10k | KEP |
| Communication Services | 1 | 0 | -16k | TTWO |
| Industrials | 1 | 0 | -16k | AAON |
| (untagged) | 5 | 2 | -26k | NUAN MEL CASC BMS ASMIY |
| Consumer Staples | 1 | 0 | -29k | CCU |
| Financials | 4 | 0 | -65k | LNC CBSH BOH BGC |
| Information Technology | 6 | 0 | -118k | VYX TER PEGA OTEX OSPN ASML |

Best: PCYC +245k (Health Care, 2015-01-21→2015-05-27, , grade NODATA); CRVL +10k (Health Care, 2015-12-05→2016-04-04, laggard_rotation, grade B); ASMIY +1k ((untagged), 2015-02-24→2015-03-02, liquidity_exit, grade B); 

Worst: BCRX -92k (Health Care, 2015-06-19→2015-08-10, stop_loss, grade B); VYX -32k (Information Technology, 2015-06-16→2015-06-18, stop_loss, grade B); CCU -29k (Consumer Staples, 2015-10-22→2015-12-01, stop_loss, grade B); 

Whipsaws (D/F): PEGA (stopped -4.8%, +13wk max +20%); DHR (stopped -2.8%, +13wk max +17%); CASC (stopped -10.6%, +13wk max +17%); 

## 2016 — 26 trades, 38% winners, realised +413k · grades A 8 / B 4 / C 7 / D 7 / F 0

Market: market-best Materials              med  +39% (n=115) | signal-best Utilities              (its med ret  +19%)       | our-P&L-best Information Technology  +254k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Information Technology | 8 | 3 | +232k | TSM SLAB PTC ONTO MKSI LRCX IT FFIV |
| (untagged) | 4 | 1 | +115k | SCLN HRC GRA CMA-WS |
| Industrials | 3 | 2 | +104k | ROL HEI-A FDX |
| Financials | 2 | 2 | +44k | BGC AON |
| Real Estate | 1 | 1 | +7k | AKR |
| Communication Services | 1 | 0 | -5k | SIRI |
| Consumer Staples | 1 | 0 | -8k | DLTR |
| Consumer Discretionary | 1 | 0 | -11k | THO |
| Health Care | 2 | 1 | -25k | BMY AORT |
| Materials | 3 | 0 | -40k | GGB CCK APD |

Best: MKSI +280k (Information Technology, 2016-05-26→2017-07-10, laggard_rotation, grade A); CMA-WS +222k ((untagged), 2016-11-09→2017-04-03, laggard_rotation, grade A); ROL +106k (Industrials, 2016-10-26→2017-11-06, laggard_rotation, grade A); 

Worst: GRA -49k ((untagged), 2016-01-22→2016-02-05, stop_loss, grade D); BMY -42k (Health Care, 2016-04-28→2016-08-08, stop_loss, grade B); SCLN -40k ((untagged), 2016-04-04→2016-07-20, stop_loss, grade B); 

Whipsaws (D/F): THO (stopped -3.0%, +13wk max +26%); SLAB (stopped -2.6%, +13wk max +20%); PTC (stopped -3.4%, +13wk max +18%); ONTO (stopped -6.2%, +13wk max +27%); LRCX (stopped -5.7%, +13wk max +18%); HEI-A (stopped -3.1%, +13wk max +15%); GRA (stopped -21.9%, +13wk max +18%); 

## 2017 — 24 trades, 50% winners, realised +440k · grades A 6 / B 7 / C 8 / D 2 / F 1

Market: market-best Information Technology med  +31% (n=204) | signal-best Financials             (its med ret  +16%)       | our-P&L-best Industrials             +150k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Industrials | 6 | 3 | +150k | TREX RTX EXPO EMR DY ADP |
| Information Technology | 6 | 3 | +138k | WDC TDY LOGI INFY COHU ASML |
| Consumer Discretionary | 4 | 2 | +76k | PLCE MOD CVSA BBY |
| Communication Services | 1 | 1 | +71k | NYT |
| Health Care | 2 | 1 | +12k | NEOG A |
| Financials | 1 | 1 | +7k | BRK-A |
| (untagged) | 3 | 1 | +6k | USG_old UN FOE |
| Materials | 1 | 0 | -22k | OLN |

Best: TREX +137k (Industrials, 2017-09-07→2018-02-26, laggard_rotation, grade A); ASML +75k (Information Technology, 2017-07-12→2017-12-18, laggard_rotation, grade A); NYT +71k (Communication Services, 2017-02-07→2017-11-06, laggard_rotation, grade B); 

Worst: DY -29k (Industrials, 2017-04-18→2017-05-26, stop_loss, grade C); USG_old -23k ((untagged), 2017-11-28→2018-02-06, stop_loss, grade D); OLN -22k (Materials, 2017-02-16→2017-05-05, stop_loss, grade C); 

Whipsaws (D/F): USG_old (stopped -8.8%, +13wk max +20%); MOD (stopped -4.5%, +13wk max +51%); A (stopped -4.7%, +13wk max +16%); 

## 2018 — 38 trades, 26% winners, realised -367k · grades A 6 / B 14 / C 13 / D 5 / F 0

Market: market-best Utilities              med   +4% (n= 65) | signal-best Consumer Discretionary (its med ret   -9%)       | our-P&L-best Information Technology   +16k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Information Technology | 9 | 2 | +16k | SMTC PEGA LOGI IMMR CHKP AVT APH AMD ACIW |
| (untagged) | 2 | 1 | +3k | VVUS ELP |
| Energy | 2 | 1 | -5k | RIG IMO |
| Consumer Staples | 1 | 0 | -13k | JJSF |
| Communication Services | 1 | 0 | -18k | DIS |
| Materials | 1 | 0 | -23k | GGB |
| Real Estate | 1 | 0 | -31k | LAMR |
| Utilities | 3 | 1 | -43k | EVRG DTE AEP |
| Health Care | 3 | 0 | -54k | UHS LH BIIB |
| Industrials | 4 | 1 | -70k | GD FSS FAST CSX |
| Consumer Discretionary | 11 | 4 | -129k | SCVL SCHL SBUX KMX KMX DRI CBRL CAL CAL BKNG BKE |

Best: AMD +116k (Information Technology, 2018-06-11→2018-12-03, laggard_rotation, grade A); SMTC +37k (Information Technology, 2018-04-10→2018-10-22, laggard_rotation, grade A); VVUS +25k ((untagged), 2018-11-27→2018-11-29, stop_loss, grade B); 

Worst: BIIB -41k (Health Care, 2018-07-24→2018-07-27, stop_loss, grade B); SCHL -37k (Consumer Discretionary, 2018-07-06→2018-07-20, stop_loss, grade C); CAL -36k (Consumer Discretionary, 2018-04-07→2018-04-23, stop_loss, grade C); 

Whipsaws (D/F): SBUX (stopped -3.0%, +13wk max +18%); LOGI (stopped -11.5%, +13wk max +27%); ELP (stopped -5.0%, +13wk max +26%); DTE (stopped -7.2%, +13wk max +16%); ACIW (stopped -3.9%, +13wk max +18%); 

## 2019 — 35 trades, 37% winners, realised -183k · grades A 6 / B 16 / C 7 / D 6 / F 0

Market: market-best Information Technology med  +39% (n=242) | signal-best Utilities              (its med ret  +25%)       | our-P&L-best Industrials             +125k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Industrials | 4 | 4 | +125k | MTZ LMT ITT CPRT |
| Consumer Discretionary | 5 | 2 | +84k | PRDO POOL LOW CHDN BBY |
| (untagged) | 5 | 3 | -1k | PDLI NTTYY CRAY CBDBY ARQL |
| Real Estate | 1 | 0 | -18k | ARE |
| Consumer Staples | 1 | 0 | -19k | TR |
| Financials | 3 | 0 | -56k | MCY JKHY IBN |
| Utilities | 3 | 0 | -63k | SWX DUK AEE |
| Health Care | 3 | 2 | -68k | SYK QGEN DHR |
| Information Technology | 10 | 2 | -166k | VYX RAMP PRGS PLXS PEGA MSTR IT DIOD ADSK ACIW |

Best: MTZ +89k (Industrials, 2019-08-02→2019-12-02, laggard_rotation, grade A); CHDN +85k (Consumer Discretionary, 2019-06-03→2019-11-18, laggard_rotation, grade A); POOL +74k (Consumer Discretionary, 2019-04-18→2019-11-18, laggard_rotation, grade B); 

Worst: QGEN -89k (Health Care, 2019-12-07→2019-12-27, stop_loss, grade D); IT -62k (Information Technology, 2019-06-20→2019-07-31, stop_loss, grade C); BBY -44k (Consumer Discretionary, 2019-12-12→2020-02-28, stop_loss, grade D); 

Whipsaws (D/F): QGEN (stopped -20.6%, +13wk max +24%); PRDO (stopped -4.0%, +13wk max +19%); JKHY (stopped -4.3%, +13wk max +19%); DUK (stopped -4.9%, +13wk max +18%); CRAY (stopped -2.8%, +13wk max +27%); BBY (stopped -10.3%, +13wk max +16%); 

## 2020 — 48 trades, 42% winners, realised +1162k · grades A 10 / B 16 / C 7 / D 10 / F 3

Market: market-best Information Technology med  +37% (n=249) | signal-best Materials              (its med ret  +17%)       | our-P&L-best Information Technology  +858k MATCH

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Information Technology | 12 | 5 | +825k | QRVO ORCL OLED NVDA NVDA NVDA MSI LSCC LOGI GILT CDNS AUDC |
| Consumer Discretionary | 5 | 1 | +287k | VFC TJX BKE BBWI AMZN |
| Health Care | 1 | 1 | +187k | UTHR |
| Industrials | 2 | 2 | +92k | MATX LECO |
| Materials | 1 | 1 | +26k | CCK |
| (untagged) | 7 | 3 | -3k | LUB LGTY GC FUJIY EGOV CY CY |
| Consumer Staples | 12 | 7 | -5k | TGT KR KR GIS FLO FLO FLO CPB CPB CLX CHD CAG |
| Real Estate | 3 | 0 | -63k | CSGP CCI CCI |
| Communication Services | 3 | 0 | -70k | PHI IAC DIS |
| Utilities | 2 | 0 | -112k | TXNM CIG |

Best: LOGI +424k (Information Technology, 2020-05-06→2021-05-10, laggard_rotation, grade A); BBWI +414k (Consumer Discretionary, 2020-08-08→2021-08-16, laggard_rotation, grade A); NVDA +338k (Information Technology, 2020-04-06→2020-11-30, laggard_rotation, grade A); 

Worst: CIG -70k (Utilities, 2020-03-09→2020-03-12, stop_loss, grade D); VFC -56k (Consumer Discretionary, 2020-01-06→2020-01-24, stop_loss, grade B); TXNM -42k (Utilities, 2020-02-01→2020-02-28, stop_loss, grade B); 

Whipsaws (D/F): TGT (stopped -0.1%, +13wk max +34%); QRVO (stopped -6.0%, +13wk max +40%); PHI (stopped -6.9%, +13wk max +16%); OLED (stopped -4.3%, +13wk max +17%); NVDA (stopped -4.2%, +13wk max +51%); NVDA (stopped -6.4%, +13wk max +54%); LGTY (stopped -6.8%, +13wk max +33%); CSGP (stopped -15.7%, +13wk max +26%); CPB (stopped -6.7%, +13wk max +16%); CIG (stopped -15.8%, +13wk max +33%); CCI (stopped -7.7%, +13wk max +19%); BKE (stopped -8.5%, +13wk max +60%); AMZN (stopped -4.9%, +13wk max +26%); 

## 2021 — 25 trades, 40% winners, realised -399k · grades A 10 / B 4 / C 5 / D 5 / F 0 / stub-print X 1

Market: market-best Energy                 med  +43% (n= 97) | signal-best Consumer Discretionary (its med ret  +24%)       | our-P&L-best Real Estate             +156k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Real Estate | 2 | 2 | +156k | KRC CPT |
| Industrials | 4 | 2 | +132k | VICR ITW IEX AOS |
| Financials | 1 | 1 | +44k | FDS |
| Health Care | 1 | 1 | +17k | MMSI |
| Energy | 1 | 1 | +6k | SGU |
| Consumer Staples | 1 | 0 | -1k | FLO |
| Materials | 1 | 0 | -2k | ASH |
| Consumer Discretionary | 3 | 0 | -46k | LEN HRB GCO |
| Information Technology | 9 | 3 | -84k | RDWR POWI PLXS NVDA NOVT HPQ CSCO AKAM ADBE |
| (untagged) | 2 | 0 | -621k | STMP HSII |

Best: CPT +156k (Real Estate, 2021-04-20→2022-03-28, laggard_rotation, grade A); VICR +101k (Industrials, 2021-07-03→2021-12-07, stop_loss, grade A); AOS +61k (Industrials, 2021-02-27→2021-06-21, laggard_rotation, grade A); 

Worst: STMP -594k ((untagged), 2021-07-30→2021-10-06, stop_loss, grade X); POWI -42k (Information Technology, 2021-08-21→2021-12-06, laggard_rotation, grade C); HPQ -29k (Information Technology, 2021-12-08→2022-01-25, stop_loss, grade D); 

Whipsaws (D/F): RDWR (stopped -2.0%, +13wk max +31%); NVDA (stopped -4.8%, +13wk max +43%); HSII (stopped -12.9%, +13wk max +22%); HPQ (stopped -5.3%, +13wk max +15%); GCO (stopped -6.9%, +13wk max +36%); 

## 2022 — 43 trades, 30% winners, realised -211k · grades A 5 / B 20 / C 9 / D 9 / F 0

Market: market-best Energy                 med  +56% (n=139) | signal-best Utilities              (its med ret   +0%)       | our-P&L-best Consumer Staples         +22k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| (untagged) | 3 | 1 | +237k | TEF K BPT |
| Consumer Staples | 2 | 1 | +22k | MZTI BTI |
| Consumer Discretionary | 2 | 1 | -25k | HOG AMZN |
| Health Care | 8 | 4 | -31k | RMD QDEL NVO GILD GERN CI BMY BCRX |
| Materials | 2 | 0 | -31k | GFI ALB |
| Real Estate | 4 | 1 | -36k | KRC JOE BDN ARE |
| Industrials | 4 | 1 | -56k | MLI FSS CSL AIT |
| Financials | 4 | 0 | -61k | THG IBN BCS AXP |
| Energy | 6 | 2 | -66k | WFRD SGU EPD EOG CCJ APA |
| Information Technology | 8 | 2 | -164k | SANM OSIS HLIT CTS BDC AKAM ADTN ADTN |

Best: BPT +281k ((untagged), 2022-01-22→2022-05-03, stop_loss, grade A); AIT +48k (Industrials, 2022-10-05→2023-05-08, laggard_rotation, grade B); CI +43k (Health Care, 2022-09-17→2023-01-17, laggard_rotation, grade A); 

Worst: CSL -77k (Industrials, 2022-09-22→2022-10-31, stop_loss, grade C); ADTN -56k (Information Technology, 2022-08-15→2022-09-07, stop_loss, grade B); ADTN -45k (Information Technology, 2022-08-01→2022-08-05, stop_loss, grade B); 

Whipsaws (D/F): SGU (stopped -5.3%, +13wk max +29%); RMD (stopped -3.7%, +13wk max +21%); HLIT (stopped -3.1%, +13wk max +20%); FSS (stopped -1.1%, +13wk max +18%); EPD (stopped -7.1%, +13wk max +20%); EOG (stopped -9.0%, +13wk max +22%); BDC (stopped -5.0%, +13wk max +25%); AMZN (stopped -7.7%, +13wk max +34%); ALB (stopped -2.2%, +13wk max +19%); 

## 2023 — 38 trades, 32% winners, realised +26k · grades A 7 / B 10 / C 11 / D 7 / F 2

Market: market-best Industrials            med  +26% (n=334) | signal-best Energy                 (its med ret   +9%)       | our-P&L-best Information Technology  +152k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Information Technology | 13 | 6 | +132k | MSTR MSFT LYTS LYTS LSCC JBL IT HLIT FLEX CNXN CLS CDNS ADI |
| Consumer Discretionary | 2 | 1 | +52k | WSM ROST |
| (untagged) | 4 | 2 | +47k | X PDCO NATI CHS |
| Consumer Staples | 2 | 1 | +30k | TAP CCEP |
| Health Care | 1 | 0 | -15k | HOLX |
| Materials | 1 | 0 | -21k | GFI |
| Financials | 2 | 0 | -21k | SIGI EG |
| Communication Services | 2 | 0 | -39k | TDS OMC |
| Industrials | 7 | 2 | -61k | UFPI RBA R MOG-A FLS CNH AAON |
| Energy | 4 | 0 | -78k | XOM HLX EPD CCJ |

Best: X +84k ((untagged), 2023-09-19→2024-03-25, laggard_rotation, grade A); ROST +83k (Consumer Discretionary, 2023-11-14→2024-03-18, laggard_rotation, grade A); CDNS +83k (Information Technology, 2023-04-25→2023-08-28, laggard_rotation, grade B); 

Worst: LYTS -50k (Information Technology, 2023-09-30→2023-11-03, stop_loss, grade C); CNH -49k (Industrials, 2023-03-04→2023-03-16, stop_loss, grade C); FLS -36k (Industrials, 2023-08-04→2023-08-18, stop_loss, grade C); 

Whipsaws (D/F): WSM (stopped -6.9%, +13wk max +45%); TDS (stopped -6.1%, +13wk max +27%); MSTR (stopped -4.5%, +13wk max +52%); MOG-A (stopped -2.5%, +13wk max +23%); LSCC (stopped -3.1%, +13wk max +16%); HLX (stopped -1.8%, +13wk max +17%); HLIT (stopped -4.0%, +13wk max +25%); CLS (stopped -1.8%, +13wk max +71%); CCJ (stopped -5.5%, +13wk max +28%); 

## 2024 — 43 trades, 30% winners, realised -255k · grades A 6 / B 14 / C 14 / D 9 / F 0

Market: market-best Financials             med  +23% (n=387) | signal-best Financials             (its med ret  +23%) MATCH | our-P&L-best Industrials             +111k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Industrials | 3 | 2 | +111k | FLS FLR ATI |
| Consumer Staples | 2 | 2 | +21k | CHD CCEP |
| Consumer Discretionary | 2 | 2 | +19k | LZB BBY |
| Financials | 8 | 3 | +17k | WSFS SLF MUFG JEF EWBC CNA AXP AMG |
| Real Estate | 1 | 0 | -14k | FR |
| Communication Services | 2 | 1 | -16k | IMAX AD |
| (untagged) | 2 | 0 | -33k | TEF AVNW |
| Materials | 2 | 0 | -36k | GFI CMC |
| Energy | 6 | 1 | -40k | TTE NPKI HLX GEL EOG COP |
| Health Care | 3 | 0 | -41k | UHS GERN CAH |
| Information Technology | 12 | 2 | -244k | PEGA ORCL OLED LOGI HPQ DSGX CTS CIEN BDC AVT AMKR AAPL |

Best: ATI +100k (Industrials, 2024-03-11→2024-09-09, laggard_rotation, grade B); NPKI +92k (Energy, 2024-02-22→2024-03-04, laggard_rotation, grade B); AAPL +63k (Information Technology, 2024-08-05→2024-10-14, laggard_rotation, grade B); 

Worst: AMKR -74k (Information Technology, 2024-06-22→2024-07-31, stop_loss, grade B); CIEN -69k (Information Technology, 2024-03-04→2024-03-08, stop_loss, grade B); TTE -38k (Energy, 2024-05-02→2024-06-14, stop_loss, grade C); 

Whipsaws (D/F): UHS (stopped -2.9%, +13wk max +19%); PEGA (stopped -7.1%, +13wk max +32%); ORCL (stopped -5.4%, +13wk max +19%); JEF (stopped -3.1%, +13wk max +17%); IMAX (stopped -4.9%, +13wk max +26%); HPQ (stopped -5.5%, +13wk max +16%); HLX (stopped -7.3%, +13wk max +18%); GERN (stopped -4.6%, +13wk max +34%); BDC (stopped -5.1%, +13wk max +27%); 

## 2025 — 35 trades, 31% winners, realised +251k · grades A 8 / B 8 / C 9 / D 6 / F 3

Market: market-best Materials              med  +21% (n=159) | signal-best Financials             (its med ret   +9%)       | our-P&L-best Information Technology  +217k 

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Industrials | 3 | 2 | +226k | PKE CHRW CAR |
| Utilities | 2 | 1 | +126k | WTRG KEP |
| Information Technology | 9 | 3 | +107k | PTC ORCL KOPN KLAC INFY IBM GILT CSCO CHKP |
| (untagged) | 2 | 1 | +91k | AZPN ANZGY |
| Consumer Staples | 2 | 2 | +44k | INGR BTI |
| Consumer Discretionary | 2 | 0 | -37k | URBN AN |
| Financials | 6 | 2 | -45k | TRV SPGI JPM IBN HSBC AIG |
| Health Care | 3 | 0 | -63k | STE STE MDT |
| Communication Services | 4 | 0 | -93k | VZ VOD TKO SSP |
| Energy | 2 | 0 | -105k | GEL CTRA |

Best: CHRW +195k (Industrials, 2025-08-14→2026-02-13, stop_loss, grade A); GILT +157k (Information Technology, 2025-07-18→2026-02-12, stop_loss, grade A); KEP +141k (Utilities, 2025-05-07→2025-10-06, laggard_rotation, grade A); 

Worst: INFY -96k (Information Technology, 2025-12-20→2025-12-23, stop_loss, grade B); GEL -81k (Energy, 2025-03-20→2025-04-07, stop_loss, grade D); SSP -39k (Communication Services, 2025-11-18→2025-11-20, stop_loss, grade F); 

Whipsaws (D/F): VOD (stopped -6.2%, +13wk max +23%); TKO (stopped -2.5%, +13wk max +16%); SSP (stopped -9.4%, +13wk max +65%); KOPN (stopped -6.5%, +13wk max +92%); KLAC (stopped -5.3%, +13wk max +25%); JPM (stopped -6.5%, +13wk max +19%); GEL (stopped -18.5%, +13wk max +38%); CSCO (stopped -1.6%, +13wk max +21%); CAR (stopped -6.1%, +13wk max +79%); 

## 2026 — 17 trades, 12% winners, realised -336k · grades A 2 / B 8 / C 3 / D 4 / F 0

Market: market-best Energy                 med  +40% (n=136) | signal-best Health Care            (its med ret  +13%)       | our-P&L-best Energy                   +14k MATCH

| sector | n | wins | P&L | names |
|---|---:|---:|---:|---|
| Energy | 2 | 1 | +10k | EQT BP |
| Communication Services | 2 | 1 | +8k | TEO SSP |
| Financials | 1 | 0 | -14k | BGC |
| Materials | 1 | 0 | -16k | GEF |
| Utilities | 1 | 0 | -17k | ATO |
| Consumer Discretionary | 1 | 0 | -18k | CCL |
| Health Care | 2 | 0 | -49k | VTRS LLY |
| Industrials | 4 | 0 | -111k | MSM HEI-A HEI CAR |
| Consumer Staples | 3 | 0 | -128k | SYY COST ADM |

Best: SSP +26k (Communication Services, 2026-05-20→2026-06-01, stage3_force_exit, grade A); EQT +14k (Energy, 2026-03-03→2026-03-18, stop_loss, grade A); BP -4k (Energy, 2026-03-31→2026-04-02, stop_loss, grade B); 

Worst: SYY -92k (Consumer Staples, 2026-02-07→2026-03-31, stop_loss, grade D); CAR -56k (Industrials, 2026-04-25→2026-04-28, stop_loss, grade B); HEI -29k (Industrials, 2026-01-05→2026-02-05, stop_loss, grade B); 

Whipsaws (D/F): SYY (stopped -18.2%, +13wk max +21%); MSM (stopped -1.8%, +13wk max +29%); LLY (stopped -4.8%, +13wk max +28%); ADM (stopped -4.3%, +13wk max +26%); 
