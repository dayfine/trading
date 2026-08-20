# Next-session priorities — 2026-08-20 morning

Supersedes `next-session-priorities-2026-08-19-evening.md`.

## P0 — one decision is waiting on a human, and it is the only hard block

**PR #2433 carries a `do-not-merge` label.** It reached rework iteration 3
(cap is 2), and the remaining question is a judgement call, not more agent
cycles:

> The record concluded that the "fewer trades / longer holds / higher win rate /
> lower drawdown / return unmoved" signature is **a generic consequence of
> reduced turnover** on the 26y base. That is now known to be **wrong on the
> drawdown leg** — `nearfloor ÷ rt` is 3.8× / 10.2× / 4.0× on trades / holds /
> win rate but only **1.2×** on MaxDD, and rt buys **81.6%** of nearfloor's
> drawdown improvement for **26.4%** of its turnover cut. The file now says the
> scoped version. **Decide whether to keep the scoped claim or defend the
> stronger one.** Everything else in the PR is verified and reproduces.

The verdict is unaffected either way — the mechanism fails on the 5y cell's
independent reversal, not on this argument. Remove the label only on an explicit
decision (`.claude/rules/pr-merge-gates.md` Rule 0).

## What shipped

| PR | state | what |
|---|---|---|
| **#2430** | merged | `sexp_default_drift_linter` — catches the class that produced #2384 (−40.91pp) and #2388, both of which compiled green |
| **#2434** | merged (by cron) | daily orchestrator record |
| **#2435** | merged | re-lands corrections to #2434 that the cron's merge stranded |
| **#2433** | **HELD** | 26y rt-freshness A/B, reworked 3× |
| **#2436** | open, CI green | the 5y null measurement |
| **#2437** | open | `prior_cell_check` tooling |
| **#2438** | open | contention test — the mechanism, confirmed |

## The strategy findings, in order of how much they should change future work

### 1. ⭐ "X is a risk lever, not a return lever" may be an instrument artefact

On the 26y base, **return carries ~10× worse signal-to-noise than any risk
metric**. Null ratios (26y ÷ 5y): win rate 1.2×, Sharpe 11.6×, MaxDD 13.2×,
ulcer 18.0×, **return 134.4×**.

So the program's recurring conclusion — return in-null while a risk metric
clears — is partly *low power*, not evidence of no return effect. Honest
phrasing is **"risk moved; return is not measurable here at this effect size."**

**Worth a pass over ledger ACCEPT/REJECT entries that turn on a return-in-null
reading.** Not started.

### 2. ⭐ The noise floor is ADMISSION CONTENTION, not tail exposure — tested

Measured from committed `trades.csv`, joined on `(symbol, entry_date)`:

| | s0 vs s1 | s0 vs s2 | of N |
|---|---:|---:|---:|
| **5y core** | **0 (0.0%)** | **0 (0.0%)** | 240 |
| 26y core | 710 (61.9%) | 459 (40.0%) | 1147 |

At 5y the trade set is **bit-identical** across path seeds — only fill prices
move. At 26y the seed re-rolls **40–62% of which trades happen**.
`force_liquidations_count` is 4/3/4 at 26y and **0/0/0** at 5y: the capital
constraint binds at one scale and not the other, and per
`project_ticket_dies_on_cash_shortfall` an unfundable triggered ticket is
destroyed with selection at trigger being arrival order.

**TESTED AND CONFIRMED — PR #2438.** The 5y spec with `max_position_pct_long`
0.14 → 0.33 (one knob, period and universe fixed):

| arm | s0 vs s1 | s0 vs s2 | of N |
|---|---:|---:|---:|
| control (0.14) | **0 (0.0%)** | **0 (0.0%)** | 240 |
| tightened (0.33) | **23 (13.1%)** | **63 (36.0%)** | 175 |

Relative return noise moved **31×** (0.9% → 28%) from that one knob. Prediction
was registered in commit 1 before the run.

**It also sharpened:** `force_liquidations_count` stayed 0/0/0, so the channel
is not cash exhaustion — at 0.33 against 0.70 max exposure only ~2 positions
fit, so a **slot** constraint binds. Restated:

> Any binding admission constraint — cash *or* slots — makes ticket selection
> depend on arrival order, and arrival order is path-dependent. Force-liquidation
> count is a symptom of one constraint binding, not a proxy for contention.

Sufficiency is shown at fixed period/universe; **exclusivity at 26y is not** —
that cell varies period, universe, breadth and constraint at once. The
confirming direction is a relaxed-26y run (~2h), still unrun.

### 3. Range-top freshness is NOT promotable

26y: ulcer −26.5%, win rate +1.73pp, MaxDD −21%, all past their own nulls.
5y: **loses on all five metrics at 13–73× that cell's null**, ulcer flipping
from −26.5% better to +51.8% worse. 1-of-2 grid cells with the second reversing
everything. The 26y measurement is sound and reproduces; it is 26y-scoped.

### 4. Never import a null across scales

1.2× to 134× apart *by metric*, ordering not guessable in advance. 1/√n predicts
the 26y null should be **0.46×** the 5y one (more trades ⇒ quieter); every
metric is noisier instead, return by 292× the prediction. A tight null means low
contention, not a better instrument.

## Process — what actually changed, mechanically

- **`prior_cell_check.sh`** (#2437) — "has this cell already been measured?" is
  now a command with 8 mutation-verified tests, wired into `dune runtest`. Built
  because a writeup claimed a null was unmeasured while a committed file carried
  it at all three salts.
- **`pr_gate_status.sh` false-green closed** (#2419/#2421 merged 08-19) — the
  merge loop's own state reader had a hole.
- **The `do-not-merge` label works and the gate script reads it** — verified
  live on #2433, which prints `HOLD -- do-not-merge label` instead of `MERGE`.

### The failure pattern, named because it recurred four times in one PR

Every rework fixed the instances found and **not the rule that generated them**.
v1 skipped the metrics that moved; v2 skipped the ones that failed Rule 4; v3
skipped the one leg that did not fit "every". Stated as a rule:

> **When a claim quantifies several legs, score every leg before choosing the
> summary adjective.**

Each instance was caught by qc-behavioral, never by me. The measurements held up
throughout; the interpretive layer did not.

## Suggested order next session

1. **Decide #2433** (P0 above) — one judgement call, then merge or rework.
2. **Merge #2438** (contention) — it confirms, not falsifies, so #2436 needs no correction on that point.
3. **Merge #2436 / #2437** through the normal gates.
4. **The ledger audit** from finding 1 — the highest-value unexplored item, and
   it re-reads existing records rather than spending container time.
5. Only then new mechanism work.
