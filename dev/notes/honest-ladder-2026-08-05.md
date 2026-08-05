# Honest E-anchored ladder — the designed rule, executed honestly (2026-08-05)

First measurement of the book-faithful entry rule after the 2026-08-05 user
decision (Step 0 = (b), `dev/plans/gtc-breakout-orders-2026-08-05.md`):
entries as StopLimit orders genuinely RESTING at the screener's breakout
level E (`sim_entry_trigger_at_suggested`, #2209), with the execution-
faithfulness audit (#2210/#2212) live for the first time.

Run: 3 sequential 26y arms, record-convention config, top-3000 PIT-2000,
split-safe warehouse `/tmp/snap_top3000_dedup_v5thin_adj`, pinned worktree
@`3b8dc10d` (= main incl. #2209+#2210 + the committed twins), cache 1024.

## Results

| Arm | Terminal | Sharpe | Sortino | MaxDD | Win% | Trades |
|---|---:|---:|---:|---:|---:|---:|
| control — market fill (record basis) | +8,367% | 0.90 | 1.49 | 37.1% | 37.7% | 1,122 |
| estop15 — rest @ E, band 15pp (live ticket today) | +244% | 0.41 | 0.55 | 37.7% | 31.3% | 993 |
| estop2 — rest @ E, band 2pp (the book's ticket) | **+965%** | 0.30 | **1.08** | **29.5%** | 31.3% | 1,102 |

Control reproduces the verified record for the third time — basis clean.
Single-window decomposition evidence (path divergence applies), NOT a WF
verdict.

## Findings

1. **The designed rule, honestly executed at the graded E, earns ~+965%** —
   still beats SPY-TR (~+687% same window) with the lowest MaxDD of any arm
   (29.5%), but ~9× less terminal wealth than the record's market-fill curve.
   The record is, relative to the rule AS TICKETED, substantially a
   fill-model artifact.
2. **Band importance flips under E-anchoring**: tight 2pp ≫ wide 15pp
   (+965% vs +244%). Wide bands chase breakout overshoots that lose; the
   tight band takes only clean fills near E and (with persistent orders)
   catches pullbacks-into-band. Matches the book's 12⅛/12⅜ ticket. If live
   stays E-anchored, the data says shrink the live band toward ~2pp.
3. **Execution-faithfulness maiden run**: control 1121/1121 faithful
   (Market-by-definition, the convention made visible); stop arms ~98%
   faithful (5 + 13 violations to inspect). GAP: only ~30% of stop-arm
   trades carry execution records — the audit↔trade join uses the 7-day
   decision→fill window, but resting orders fill weeks later. Follow-up:
   join by position_id without the date window.
4. **The E-basis itself is now the highest-value open lever.** E here is the
   conservative 520-week graded top (false-virgins protection). The book
   anchors the buy-stop at the top of the CURRENT trading range — a nearer,
   earlier-triggering level (BKE: local top ~20.5 vs graded 28.66).

## Direction (user decision 2026-08-05, option (b))

**Invest in the resistance-anchoring lever first — local-range-top E —
and re-measure before judging any record re-basing.** Guardrail: the lever
must change the TICKET LEVEL only (suggested_entry derivation), NOT the
admission/grading basis — shortening the grading lookback would re-open the
false-virgins class ([[project_false_virgins_load_bearing]]). Default-off
knob; then re-run this ladder with local-top-E arms; then WF-CV.

Artifacts: `dev/experiments/stoplimit-entry-wfcv-2026-08-04/honest-ladder/`
(3× actual.sexp + 3× trades.csv). Twins committed under
`staging-record-convention/` (estop15/estop2, branch feat/honest-ladder-arms
→ this PR).
