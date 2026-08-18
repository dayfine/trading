# TTL re-test — results (2026-08-18)

Chain: `/tmp/ttl-retest-chain.log`, 4 arms, pinned worktree `@59b26c3bf`,
2026-08-17 21:45 → 2026-08-18 04:09 PDT.

## Top line

| arm | rescreen | clock | salt | return % | trades | maxDD % | rejected_fills | wall |
|---|---|---|---|---:|---:|---:|---:|---:|
| `00-null` | off | 0 | 0 | **281.708** | 1,147 | 39.03 | 262 | 7,174s |
| `01-rescreen-only` | **on** | 0 | 0 | 176.358 | 1,115 | 42.23 | 123 | 5,401s |
| `01-rescreen-only` | on | 0 | 1 | 174.829 | 1,114 | 42.85 | 125 | 5,281s |
| `01-rescreen-only` | on | 0 | 2 | 182.281 | 1,113 | 42.88 | 124 | 5,202s |

**Tripwire passed.** Arm 00 returned `281.707836178685`, reproducing the
2026-08-14 seeded salt-0 draw exactly, so the binary did not move and the
borrowed null is valid.

## Verdict — REJECT, on complete distributional separation

| | draws | min | max | spread |
|---|---|---:|---:|---:|
| null (measured 08-14) | 265.44 / 281.71 / 397.95 | 265.44 | 397.95 | 132.5pp |
| re-screen (measured here) | 176.36 / 174.83 / 182.28 | 174.83 | 182.28 | **7.45pp** |

The **best** re-screen draw is **83pp below the null's worst**. The
distributions do not overlap, which is why a single window is enough to reject
(it would not be enough to *promote* — that needs the confirmation grid).
Drawdown is also worse (42.2–42.9 vs 39.0), so this is not a return-for-risk
trade.

## Why — dissected, not inferred

Rest-time buckets, `position_id`-keyed
(`../ticket-funding-cohort-2026-08-18/rest_time_pnl.sh`), null vs re-screen s0:

| bucket | null n | null P&L | rescreen n | rescreen P&L |
|---|---:|---:|---:|---:|
| ≤1wk | 698 | +1,710,291 | 873 | +1,601,081 |
| 2–4wk | 166 | −149,906 | 181 | −271,094 |
| **5–13wk** | 136 | **+1,021,434** | 58 | **−131,738** |
| 14–26wk | 58 | +82,266 | 3 | +73,019 |
| 27–52wk | 29 | −148,226 | **0** | 0 |
| 1–3yr | 35 | +16,612 | **0** | 0 |
| >3yr | 25 | −217,518 | **0** | 0 |
| **TOTAL** | 1,147 | **+2,314,952** | 1,115 | **+1,271,267** |

**1. The re-screen is a de-facto ~22-week cap.** Max fill age collapses from
**865 weeks to 22**; three whole buckets go to exactly zero fills.

**2. It destroys the profit band.** The 5–13wk band — the best per-trade bucket
in the null (+7,511/trade) — becomes **−2,271/trade** on 57% fewer fills. Total
realized falls **−45%**.

**3. Condition-based cancellation is the opposite of time-based cancellation.**
On this same null arm, every clock bound `{13, 26, 52, 156}` cuts a
**net-losing** cohort. A clock removes tickets that rested long *without their
setup changing* — stale, never resumed. The re-screen removes tickets whose
stage / sector / macro **flipped while resting** — but a stock that pulls back
out of Stage 2 and then re-breaks out **is the base-building pattern**
(`weinstein-book-reference.md` §Stage 1→2). Cancelling on the wobble discards
precisely the pullback-then-resume winners.

The two rules select **opposite populations**, and the pre-#2349 composite knob
armed both at once — which is why the axis read as uninformative before the
split.

**4. The variance collapse is itself the evidence.** 132.5pp → 7.45pp. The
null's dispersion *is* the long-rest lottery: which tickets survive and get
funded. Capping rest at 22 weeks removes the lottery and its positive expected
value together — removing variance and return in one stroke is what taxing a
fat tail looks like. 12th confirmation of `project_edge_is_the_fat_tail`, and
the cleanest.

**5. The mechanism worked as specified.** `rejected_fills` halves (262 → ~124),
so it genuinely cancels tickets before they trigger into a cash-short book.
This is not a no-op that failed; it is a working mechanism whose **selection
rule** is wrong.

## Forward guidance

- **Stop proposing condition-based cancellation of resting tickets** in any
  form — re-qualify, re-score, re-grade at trigger. The population it removes
  is the tail.
- **Time-based bounds stay open**, and are the next arm: `03-ttl26` first. On
  the null arm a 26-week bound cuts 89 fills worth **−349,132**, the largest
  net-losing cohort of the four bounds tested.
- `enable_entry_ticket_rescreen` stays **default-off** as an axis
  (`experiment-flag-discipline.md` R1/R2). It is a REJECT-as-default, **not**
  a do-not-revive REJECT — it is a coherent book-supported rule that loses on
  this base, so Rule 4 retirement does not apply.

Ledger: `dev/experiments/_ledger/2026-08-18-entry-ticket-rescreen.sexp`.
