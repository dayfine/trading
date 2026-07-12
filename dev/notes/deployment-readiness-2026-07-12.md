# Deployment-readiness assessment — Weinstein strategy (2026-07-12)

Written for the user's deployment-confidence question (2026-07-11 PM session):
what do we trust, what are the known weak spots, and what must be checked
before real money. Companion artifacts: the fresh-picks sanity report (same
session, task 2) and the trade-review agenda (task 3).

## 1. What the record supports (confidence basis)

**Basis of record**: honest-tradeable deep run, top-3000 PIT 2000-2026 (end
2026-06-26), realism dials armed; realized-basis ≈ **$17.7M / +1670% /
~11.5%/yr vs SPY TR +700% / 8.17%/yr** — realized beats the index over 26y
including two bear markets. MaxDD 41.3 (AXTI-peak-relative; capital-relative
lower), Ulcer 15. The armed/un-armed advantage is gradual and sign-stable
across every sub-period (quality-filter shape, not one lucky trade).

Robustness that has survived scrutiny:
- **Bear-regime defense is the strategy's strongest, most repeated result**:
  wins EVERY SPY-down year (2001/2002/2008/2011/2018/2022); 2008 −11.7% vs
  −36.8%. Rolling-start matrices: left tail chopped (worst −4.9 vs −28pp).
- **Verdict discipline**: every mechanism default was earned through
  WF-CV/grid gates or an explicit user-mandated faithfulness basis change
  (ledger-tracked); the fold-horizon LAW now guards tail-dependent verdicts.
- **Realism floor**: entry gate $1M ADV + stale-exit 5d are DEFAULTS
  (#1926); fake fills/ghost positions cannot inflate the number of record.
  Liquidity study: 91% of realized trades <0.1 days-ADV; winners are liquid.

## 2. Known weak spots (each documented, none hidden)

| # | Weak spot | Severity | Live-relevant? | Mitigation state |
|---|---|---|---|---|
| W1 | **Melt-up lag** — trails SPY badly in narrow mega-cap tapes (2024 −21.8pp, 2019 −21.6, 2023 −20.9) | HIGH (opportunity cost, psychology) | YES — structural | Documented law (melt-up-lag-anatomy note). Answer = P1b SPY-sleeve barbell (in progress), NOT screener changes. Deployment must set expectations: this strategy WILL trail in melt-ups. |
| W2 | **Constant whipsaw premium** — ~30-39 short stop-outs/yr, −6 to −16% NAV/yr, every year | MEDIUM (baked into record) | YES | Structural insurance cost (stop-tuning closed after repeated WF-CV rejects). Live: expect ~60% of trades to lose small. Psychology risk > math risk. |
| W3 | **Return is episodic** — a year's sign vs SPY = whether a fat-tail monster pays that year; top-5 trades ≈ 85% of PnL | HIGH (variance of patience) | YES | Cannot diversify away without taxing the edge (9 confirmations). Deployment needs multi-year commitment framing; single-year evaluation will mislead. |
| W4 | **Mega-cap non-participation** — 9 Mag7 trades in 26y, all scratches; cash-at-signal blocks the rest | MEDIUM | YES | Faithful behavior (volume/freshness criteria). P2b (decision_audit Phase-2) will quantify the cost of cash-rejection ordering. |
| W5 | **Parabola give-back** — trailing stop sits far below a parabolic peak (AXTI $122→$70 held) | MEDIUM | YES | Extension-stop INSURANCE dial built default-off (#1934). Deployment decision needed: arm trigger 2.0/trail 0.25 or accept give-back. Screen says tight trails are worse than the disease. |
| W6 | **MTM-vs-realized gap** — deep-run toplines are MTM-top-heavy (AXTI $45M unrealized of $62M OPV) | LOW for live (live sizes are smaller) | PARTIAL | Realized-basis is the number of record. Live at $1-10M NAV: single-position concentration cap 0.30 still allows big terminal weights — position-size review in pre-deploy checklist. |
| W7 | **Static $1M ADV gate** calibrated for $1-10M capital | LOW now | YES at scale | Documented follow-up: position-vs-ADV scaling above ~$10M NAV. |
| W8 | **Universe staleness (backtest)** — static PIT membership can't see later IPOs (GME-class) | — | **NO — backtest-only** | Live trading screens the CURRENT universe weekly; this weakness UNDERSTATES live capture vs backtest. P4 fixes the backtest side. |
| W9 | **Floor/peak pathology** — monotonic MTM peak + floor sterilized a run (GME squeeze) | — | Mitigated | Portfolio_floor default-off (#1910 + ablation); P1b windowed-peak redesign pending. Do NOT re-arm the floor live until P1b lands. |
| W10 | **Live-pipeline defects found & fixed this cycle** — prior_stage bug (#1821 fix), missing sectors manifest (all-70 alphabetical picks), macro gate on broken breadth data (false Bearish seed) | — | YES — pipeline risk | All three fixed/documented, but they were found by INSPECTION, not by tests failing. Pre-deploy checklist requires a fresh-picks sanity pass every week until a validation harness exists. |
| W11 | **Screener tie-break skew** — score ties resolve alphabetically at the cap-20 boundary | LOW-MED | YES | Known (#1782): live-UX fix planned; sector-spread restoration (fetch_finviz_sectors) reduces tie mass. Check tie composition in each week's picks. |
| W12 | **Deep-crash V-bounce entries look alarming and lose big** (8 of the 12 biggest losses) — but two same-night screens proved they are the strategy's STANDARD ticket, feature-identical to the monsters (FARM ≡ TFX class); both gate hypotheses NO-BUILD (net-negative, 22-94% block rates) | — (accepted cost, reframed) | YES — psychology | NOT fixable by entry gating; stops already cap each at −5..−15%. Real fixes that survived: resistance-LABEL data-starvation fix (COO/CWST false "Virgin territory"), declining-MA gate arming for broad (catches the AIR subclass, own WF-CV support). See `dev/notes/visual-trade-audit-2026-07-12.md`. |
| W13 | **Rename-twin double-count** — ~$2.14M of the record run's $18.0M realized PnL (11.9%) is clone legs (10 confirmed groups, NLS/BFX class); historical PIT snapshots retain stale-leg twins | HIGH (number-of-record accuracy) | Backtest-only (live universe scanned clean) | Haircut the realized headline ~12% (≈$15.6M, ~11.0%/yr — still > SPY TR 8.17%/yr) until twin-dedup lands in the snapshot builders + the run re-pins. Validator V6 detects mechanically (#1937). |
| W14 | **Non-equity universe leak** — ~55 clear CEFs/trusts (incl. FTHY, a top-7 pick 2026-07-10) + ~27 SPAC shells; EODHD exchange-symbol-list mislabels them "Common Stock" | MEDIUM | YES | Fix at universe build: fundamentals `General::Type` enrichment or curated blocklist + SPAC vol/age gate. Weekly human pass caught it in week 1. |

## 3. Confidence statement

- **The EDGE (bear defense + fat-tail capture on breadth) is real and
  multiply-derived** — highest confidence. It survived realism arming,
  fold-horizon sensitivity, rolling starts, and PIT survivorship correction.
- **The COST structure (whipsaw premium, melt-up lag, episodic payoff) is
  equally real and structural** — deploying means accepting years like 2019
  (+9.6 vs +31.2) without losing conviction. The strategy is a different
  asset class than SPY, strongest as a sleeve beside an index leg (P1b).
- **The live PIPELINE is the least-proven layer** (W10): generation works
  and the 26-week refreshed series is coherent (72% 6-week confirmation),
  but defects to date were caught by hand. Weekly sanity discipline is
  load-bearing until automated validation exists — the post-run validation
  harness (#1937, report-only v1) is the fix path; its first live-week run
  (2026-07-10 picks) caught a universe-hygiene leak (W14) and a label bug
  (W12) by hand in the same pass.
- **The number of record carries a known ~12% overstatement** (W13 twin
  double-count) pending snapshot de-twinning + re-pin; the de-twinned
  estimate still beats SPY TR by ~2.8pp/yr.

## 4. Pre-deployment checklist (proposed)

1. [ ] Fresh-picks generation for the current week + per-pick sanity
   (stage chained, volume ratio, ADV gate, freshness, sector spread,
   tie-break composition) — this session produces the first instance.
2. [ ] Macro-gate inputs verified non-degenerate (breadth files present,
   GSPC stage sane) before trusting the week's long/short posture.
3. [ ] Decide the insurance dials + quality gates for live config and RECORD
   the decision: extension_stop (arm 2.0/0.25?), catastrophic_stop (armed in
   record basis), portfolio floor stays OFF until P1b, declining-MA gate
   (ARM — validated for broad, and live = broad). NO overhead/base-quality
   gates (screened + killed 2026-07-12, see W12).
4. [ ] Position-sizing sanity at intended capital (concentration 0.30,
   min_cash 0.30, gate $1M vs intended NAV).
5. [ ] Paper-trade N weeks with the weekly workflow (generate → review →
   would-have-ordered), comparing against the backtest's same-week behavior.
6. [ ] Weekly ops runbook: fetch STALE set → verify data_end ≥ as-of →
   generate → render report → sanity pass (the caveats playbook).
7. [ ] Sleeve decision (P1b): deploy strategy-only, or strategy+SPY sleeve
   from day one. The melt-up-lag law argues for the sleeve.

## 5. Open items feeding this assessment

- Fresh-picks sanity report (this session) — validates the pipeline NOW.
- Trade-review agenda (this session) — the interactive audit's entry point.
- P1b sleeve lens (queued) — the melt-up answer.
- P2b decision_audit Phase-2 (queued) — the cash-at-signal cost.
