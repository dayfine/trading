# Next-session priorities — 2026-10-12 (supersedes 2026-10-11)

The #3238 breadth fix is merged (#3252), and its paired 26y record rerun is merged (#3261). **The record is now N**
(rb1 on the full NYSE A-D fixture). The index-short overlay screen plan is confirmed and merged (#3251) and is the next
direction-class work.

## 0. Ground rules

Unchanged from 10-11 §0: the book file never leaves the machine; no Python; jj; QC before backtests; no self-posted
gate verdicts; sp500 is never evidence; clean only our own files, never TM snapshots; results-analyst for
direction-class reads; times PT; compact at ~250k; quiet hours 23:00–11:00 PT.

**Cloud sessions:**
- A rebase brief must say "do not post any review". The 10-12 #3253 rebase session posted its own approvals anyway.
  The merge rested on a separate QC session's reviews.
- Send dune output to log files, or `/tmp` fills (ENOSPC).

## 1. What this session settled

| item | result |
|---|---|
| #3252 | full NYSE A-D fixture plus interior-gap fill and gap warning; merged |
| #3261 | paired rerun, O (old fixture) vs N (full), 3 salts, V6 = 0 every cell. N replaces rb1: +849 / +836 / +878 %, CAGR 8.87–8.99 % vs SPY TR 8.20 %, max DD 22.2–22.5 % vs 55.2 %. N − O mean +0.030 log (noise). Bearish weeks 398 → 233, all 2000–16. qc-results APPROVED after one rework |
| #3251 | index-short overlay screen pre-registration; confirmed by the user, hold lifted 10-12 11:35 PT, merged |
| #3253, #3254 | cloud PRs (review-pack flag cards; holiday-Friday screening, default-off) merged on green gates |
| issues | #3262 review-pack defects (Friday-fill macro join, against-macro wording, reused-ticker exit, pack SHA stamp); #3263 A-D fixture holiday rows |
| perf ledger | 6 breadth-fix cells added (`dev/status/perf-long-cells.csv`); `check` ok except a pre-existing 0.24y msusp cell (+26 %) |

**Why the record barely moved** (memory `project_breadth_fix_ad_frozen`):
- The book is capital-bound. The unlocked weeks bought ordinary trades, and the fat tail swapped 3-for-3
  (PEGA/GPN/JNS in, CHDN/GTIV/INVX out).
- Real breadth re-enters V-rebounds earlier (2010–16 +0.10 log) but buys into the 2001, 2007 and 2008 tops (−0.10).

## 2. Queue

1. **Index-short overlay screen** (`dev/plans/index-hedge-screen-2026-10-11.md`). An offline script plus a writeup,
   then results-analyst, then qc-results.
   - Base = N's equity curves (`dev/experiments/breadth-fix-rb1-2026-10-11/results/N-*`).
   - G2 and G3 read N's `macro_trend.sexp`.
   - The analyst's note: criterion 2 (max DD ≥ 3 pp better) looks hard, because the base's max DD is the 2024-11 →
     2026-06 picks drawdown in a rising market. Look at G1's 2025 episode first. The rule stands as written.
2. **Weekly perf/usage review.** Not done this week (`perf-review-weekly.md`).
3. **A-D default-flip provenance.** The 06-23 grid record says `test_data` held the full Unicorn archive, but the
   committed fixture never did before #3252. This is a docs read first; see #3261 §How it fits.
4. #3262 and #3263 are good cloud/Codex candidates (harness and fixture checks, no backtest).

## 3. Decisions waiting

None.

## 4. GHA watch

None.
