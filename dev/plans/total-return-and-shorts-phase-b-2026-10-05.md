# Total-return basis, dollar-volume fix, shorts Phase B — plan (2026-10-05)

Decisions from a grilling session with the user, 2026-10-05. Covers issues #3137 (cash interest +
dividends), #3136 (dollar-volume look-ahead), and the shorts programme (#3131, #3145, #3146).

## Decisions

| # | question | decision |
|---|---|---|
| 1 | Sequencing | Measure #3136 first (read-only, ~1 h). Build #3137 in parallel. **One** combined baseline re-run picks up both, so the record is re-baselined once. |
| 2 | Dividend source | **Fetch EODHD dividend files** (ex-date + cash amount, all ~9.4k warehouse symbols incl. delisted). Not inferred from the adjusted/raw close ratio, which is the signal #3109 already confuses. Shorts **pay** dividends in the same change. |
| 3 | Total return as the record basis | **Yes — default-on after the combined re-run.** Lands default-off (`experiment-flag-discipline.md` R1); the flip is an accounting-realism change (precedent #1926), justified by an implementation check that the re-run matches the #3137 estimate (≈ +0.24 log interest, ≈ +0.13 log dividends on the 26y investor run), not by a strategy ACCEPT. Goldens re-pinned once; writeups note the basis change. Sharpe becomes excess over the T-bill rate. |
| 3a | Cash rate | Daily 3-month T-bill series (floating) **minus a 0.10 %/yr fee** (SGOV/BIL-class), floored at 0. The fee is a config knob (0.35 % = money-market-fund class). |
| 3b | Why it matters beyond level | Price-only scoring is biased toward full investment: drawdown credits cash for avoiding pain, but return charged cash at 0 %. Cash-heavy verdicts were judged on that bias. |
| 4 | Re-checking past verdicts | **No pre-set cutoff.** Each verdict whose arms held different cash (macro-suspend, cash reserve, index-stage veto, deteriorating gate, concentration grids, others the analyst finds) gets a results-analyst diagnostic — cash path over time by regime and by T-bill level, the gap split into interest vs path, and whether the verdict's stated *why* depended on cash costing nothing. Re-runs are decided per verdict from that read, qualitative and quantitative. |
| 5 | Dollar-volume basis (#3136) | **Split-only-adjusted close × split-adjusted volume** (= raw × raw, true dollars traded at the time). Split events from EODHD, fetched with the dividends (one bulk fetch), so splits and dividends come from separate sources; the existing split detector is cross-checked against them. Implausible dollar-volume bars (COMP_old 4.2e12, VEXPQ, OCHTQ) rejected and listed. The fix moves both PIT list construction (`build_from_individuals.ml`) and the strategy liquidity gates (`liquidity_metric.ml`); both are measured before any rebuild. |
| 6 | Shorts: continue? | **Continue**, under a written stopping rule (row 8) and a round cap (row 10). |
| 7 | Phase B contents | One paired 26y run on one build, V6-gated. **v0** = bug fixes only (#3131 ticket at breakdown + $17 gate on that price; #3145 short stop ratchets down; #3146 share-class gate for shorts) = the short-only baseline. **v1** = v0 + cancel resting short tickets when the macro screen leaves Bearish + a shorter short ticket TTL. Cover-on-Bullish-macro is **not** proposed unless the book supports it (Weinstein covers on a buy-stop). results-analyst reads it; the writeup must give the why of each delta and the next lever it implies. |
| 8 | Stopping rule | **A and B must both hold** (on v0 or v1), cash interest excluded from the short book's return: A = positive total return over 26y; B = positive in ≥ 2 of 3 bear periods (2000–02, 2008–09, 2022). **C** (per-position anatomy: win rate × win size vs loss size, with spread, by entry / stop / squeeze / hold) is diagnostic only — it names the lever, it is not a threshold. |
| 9 | Queue | Container, one long run at a time: (1) #3136 measurement → (2) combined long baseline re-run, 3 salts → (3) 26y shorts pair → (4) cash-sensitive verdict diagnostics. Code PRs (fetch, #3137, #3136 fix, short fixes) run in parallel, ≤ 3 agents, never beside a backtest. |
| 10 | Shorts round cap | **≤ 2 rounds.** Round 2 only if round 1's anatomy names a specific cause with a book-supported fix. If the stopping rule still fails after round 2: stop single-name shorts; record the why (memory + ledger); bear protection goes to the index-hedge decision as its own question. |

## Known gaps, constraints, open areas (to be extended as work proceeds)

User direction: unknown-unknowns are expected; every gap, issue, constraint and remaining work
area is documented here and in each results writeup, not left implicit.

- **Short window evidence so far is 2007–12 only** (Phase A, "5d"). 2000–02 and 2022 are unseen.
- **Short dividend charge** depends on the dividend fetch; until it lands, short P&L is overstated by
  roughly 0.4–0.5 pp/yr at ~25 % short exposure.
- **Squeezes** (Phase A's largest losers ran through stops on bear-market-rally days) have no mechanism
  in v0/v1. If round 1 points there, round 2 needs a book-supported answer (stop placement).
- **Margin realism for shorts** still has open defects: #3147 (margin-call labels), #3148 (FINRA tier step).
  The sub-$17 forced-cover churn (Phase A bucket A, +$96k/+$73k) must be gone in v0; verify it is.
- **Pack reads shorts long-side** (#3149): fix before the shorts pair, or the review look is unreliable.
- **#3109**: 5 dividend-type adjustments pass the split rule; the EODHD split/dividend files are the
  cross-check, but the stop-raise tightness test on the adjusted series is still owed.
- **Dividend data quality**: specials, ADR dividends net of withholding, delisted-symbol coverage gaps —
  measure coverage before trusting the crediting.
- **T-bill series source** (FRED DTB3 vs EODHD 13-week bill index) and its pre-2001 coverage: confirm the
  full 26y window is covered with no fallback-to-zero.
- **Re-baseline ripple**: goldens, record band, ledger entries and memories quoting price-only figures —
  list and annotate, not silently mix bases.
- **#3136 rebuild** cost (warehouse + PIT lists, hours) is decided only after the measurement.
- **Long–short integration** criteria come after short-only passes; not in scope here.
