# Next-session priorities — 2026-10-11 (supersedes 2026-10-04)

The 10-05 plan (`dev/plans/total-return-and-shorts-phase-b-2026-10-05.md`) is done through shorts Phase B
round 1. Total-return accounting is the record basis (rb1, #3219). Phase B round 1 **failed**; single-name
shorts are stopped per decision 10. The results PR is merged; one user decision is parked.

## 0. Ground rules

Unchanged from 10-04 §0 (book file never leaves the machine; no Python; jj; QC before backtests; no
self-posted gate verdicts; sp500 is never evidence; clean only our own files, never TM snapshots;
results-analyst for direction-class reads; times PT; compact at ~250k). Also:

- **Quiet hours (user, 10-07):** no questions 23:00–11:00 PT; take the (Recommended) reversible option
  and park the rest under §3 (`.claude/rules/decision-quiet-hours.md`).

## 1. What this session settled

| item | result |
|---|---|
| #3221 (was #3218) | interest field names confirmed; merged |
| #3227 | AIG/AIG-WS twin (V6 = 1) fixed; Phase B relaunched at 10f725ffe |
| Phase B lane A (v0) + lane B (v1), 3 salts each | V6 = 0 every cell; v0/v1 `validator_diff -check V6` exit 0; lane B s0 replay byte-identical |
| #3237 (open) | results: A fails (26y R_ex ex-interest v0 −0.93 log, v1 −0.80); B 1/3 (only 2008–09 positive). Two independent reads agree. Ledger `2026-10-10-shorts-phase-b-round1.sexp` verdict Reject |
| #3240 | perf long-cell ledger: 7 Phase B cells; `check` ok; merged |
| issues | #3238 A-D breadth fixture gap 2000–2016 (affects the long record too); #3239 HRC 2005-12-19 splice |
| comments | #3206 late short-stop fills (DOX, ATAR_old, AMIEQ, STRA); #3183 (HSBA, CELSIA, SBER); #3214 pack defects 1–10 |

Why Phase B failed (memory `project_shorts_liveness_dead`): exposure timing −0.30 log, single-name
selection −0.49, costs −0.14; breakdowns keep rising after the fill; no book-rule cohort is positive.

## 2. Queue

1. **Done 00:50 PT:** #3237 merged after qc-results APPROVED (review 5482332809, 4 non-blocking notes); #3131 closed with
   its evidence; #3145 commented (stays pending). Open note from that review: once §3 is decided, record whether
   `enable_short_side` and the four short-fix flags stay as plumbing (index hedge) or retire under Rule 4.
2. **#3238 (A-D breadth gap)** — highest-value next fix: 26y runs have no breadth for 2000–2016. Fix,
   then a paired rb1 rerun (old vs fixed breadth) on the record preset.
3. Weekly perf/usage review (§Weekly review in `dev/status/backtest-perf.md`, §Usage review in
   `dev/status/cost-tracking.md`) if not done this week.

## 3. Decisions waiting (deferred to 11:00 PT)

**Open the index-hedge question?** Phase B decision 10 says: no book-supported fix found → stop
single-name shorts and move to the index-hedge question.

- Evidence for: in Phase B the index-level short exposure made about +0.30 log inside the three bears.
- Evidence against: the same exposure cost about −0.30 log over 26 years; the barbell was closed 06-27 and
  the idle-cash SPY sleeve was user-declined (`project_barbell_on_stocks`).
- Options: (a) **open it as a pre-registered screen** — index short only when the macro gate is Bearish
  and SPY is Stage 4, with the same A/B rule (Recommended: cheap, it answers whether the +0.30 bear-window
  gain survives costs without the 26y bleed); (b) close shorts entirely and record it; (c) defer behind
  #3238, since breadth feeds the macro gate the hedge would key on.

## 4. GHA watch

None.
