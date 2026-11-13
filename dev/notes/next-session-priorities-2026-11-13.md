# Next-session priorities — 2026-11-13 (supersedes 2026-11-11)

Sessions 11-12 → 11-13: a trade-by-trade walk of the record → entry-timing screens → the trait-Y population
screen → the price-band tiebreak, built (#3587) and pre-registered (#3588). **Five cloud runs are in flight.**
Main CI green at `1034b458e`. Open issues: 9. Ground rules from 2026-11-10 §0 still hold: backtests run in the
cloud; the local container is for QC only.

## 1. Merged since the 11-11 handoff

| PR | what |
|---|---|
| #3571 | chain-w pre-registration (#3136, #3109, #3183), merged 11-11 21:26 UTC, which closed the 11-11 §4 T3 decision |
| #3581 | orchestrator `total_cost_usd` is API dollars from 2026-11-11 (11-11 queue item 1 done) |
| #3582, #3583 | rules: QC authority files and situational rules load on demand from `dev/rules/` |
| #3587 | `candidate_ranking = Price_band_seeded`, default-off: among equal scores, the cheaper band of `suggested_entry` (edges 8 / 14 / 33) goes first, then the seeded draw |
| #3588 | price-band pre-registration: `dev/experiments/price-band-tiebreak-2026-11-13/` (README, specs, `chain.sh`, `screen/`) |

**Why the tiebreak (`memory/project_trait_y_low_price`):** across 20,195 PIT top-3000 book breakouts (2000–25),
low share price is the only decision-time trait that raises the double-in-a-year rate in both halves without
lowering the win rate: $5–8 at 21.1 % / 19.5 % against 4.9–5.6 % above $33, win rate flat at ~39 %. The record
under-buys it: 11 % of its trades are ≤ $14, against 16 % of breakouts.

## 2. In flight: price-band K=5 paired 26y runs (cloud)

One cloud session per seed, all at `PB_SHA=1034b458e`, on warehouse `v12wk-9236` + `corpact-2026-10-27`. Each
runs arm S (record) and then arm P (S + `Price_band_seeded`).

| seed | session | chain pid | S cell started (UTC) |
|---|---|---|---|
| k0 | `session_013VUubibjW7Tcc3KQUD79rv` | 25796 (setsid) | 13:53 |
| k1 | `session_013VUubhXVjdpHAPPEMhAKfQ` | 24653 (setsid) | 13:53 |
| k2 | `session_013VUube5n5U5H3SFjpCoSNf` | 981 (nohup) | 13:50 |
| k3 | `session_013VUubgqNyxCzpFdLs7xY2F` | 983 (nohup) | 13:51 |
| k4 | `session_013VUubfjaT7izrn9RN6khXK` | 884 (nohup) | 13:51 |

- At 15:35 UTC all five were alive, every preflight passed and P's params contained `Price_band_seeded`.
- A 26y cell takes ~1.9 h (chain-w W0: 6,880 s), so the P cells end around **17:45–18:30 UTC**.
- On `PRICE-BAND kK DONE` each session pushes `experiment/price-band-kK` with `results/kK`. On ABORT it pushes
  `chain.log` and `run.out` instead.
- **Launch lesson** (`memory/feedback_cloud_brief_detach_long_chains`): k0 and k1 started under the harness
  background task, which caps at 2 h, and were relaunched detached. Future briefs must spell out
  `setsid nohup … &`.
- Check on a session: `RemoteTrigger get_run_log <session>`. Each session re-arms a Monitor and a 30-minute
  `send_later` heartbeat.

## 3. Queue

1. **Price-band results** (README §"After the runs"):
   - gather the five branches into one results-only PR;
   - build the review pack (`dev/scripts/review_pack.sh` + `review_pack_render.sh`);
   - `results-analyst` applies the pre-registered rule: V6 → liveness (P's ≤ $14 entry share ≥ 1.3× S's) →
     Δk / max DD → anchors, capacity, cash displacement;
   - spot-check the numbers, then `qc-results`;
   - write the ledger row and update `memory/project_trait_y_low_price`.

   In the same PR, close the #3588 qc-results non-blocking notes:
   - the `ath_gap` overlap with price is unmeasured;
   - "price is monotone" holds for the doubling rate only;
   - the `ath_gap` cut is ≥ 63.5 % below the all-time high;
   - clean up the r2_bars `tmp/` and `.partial` leftovers.
2. **#3584 chain-w results: artifacts only, no reading yet.**
   - W0 ≠ rk-k0: +1472.8 % vs +1312.8 %, 576 vs 566 trades; the equity curves first differ on 2004-07-22.
     **Traced 11-13 (PR comments):** two known main changes, and td-full adds at most ~0.0001 log.
     - **#3475 rename-twin dedupe** (10-29): universe 9,222 → 9,185. First change: W0 places PRMB on 2004-05-28
       and every later id shifts by one.
     - **#3483 same-day fill order** (11-01): DWSN1 and BRC compete for cash on 2006-05-30, and the winner flips.
     - #3483's own paired 26y k0 cell on the record's data dir read +1472.62 % / 576 trades / Sharpe 0.634. W0 on
       td-full reads +1472.76 % / 576 / 0.634. So W0 is the current record path.
     - The README's P0 data.csv hypothesis is not supported.
     - The price-band S arms run at current main too, so S ≠ rk-kK is expected; the pairs stay valid.
     - Free check: pb-S-k0 should match cw-W0-s0 byte for byte, which also shows #3587 is inert while off.
   - Then do README §"After the chain" steps 2–4: review pack, `perf_long_cells.sh update`, T1–T3.
   - #3109 shows `PREREQ_MISSING`, as expected.
3. **Docs:** add the detached-launch requirement to `docs/howtos/claude_cloud_sessions.md` and to the
   experiment README launch-brief template.
4. **#3587 follow-up wording:** the `.mli`'s "invest much more heavily" refers to the book's A+ pattern. Reuse
   the wording from `weinstein-book-reference.md` §4.5.
5. **Carried from 11-11, not re-verified unless marked:**
   - Refresh `trading/test_data/S/Y/SPY`. Verified still ending 2026-09-28; due before the next Monday
     weekly-start run.
   - Screen the 38 near-tightening stop exits (#3573 trigger).
   - Dangling-doc-link linter candidate (#3574).
   - #3578 QC-gap wording PR.

## 4. Local state not on main

- **Workspace `entry-screen`, commit `usxwqwrz`:** the entry-timing screen and follow-ups
  (`dev/experiments/entry-timing-screen-2026-11-12/`, 50 files). Committed as finding notes; **not pushed**.
  Summary: `memory/project_entry_timing_screen_1112`. Only the stale-E cap survives, at +7 to +12 NAV-% in
  5/5 seeds.
- **Default workspace `@` = `kkrwwqyn`:** budget records `local-2026-11-03.json` and `local-2026-11-04.json`,
  unpushed. Its description also names a priorities doc that the commit does not contain.

## 5. Decisions waiting (deferred to 11:00 PT)

**Push the entry-timing screen (`usxwqwrz`) as a results-only PR?**
- **A (recommended):** push it and open the PR. It records why skip / anchor / pullback are NO-BUILD and why the
  stale-E cap survives; one `qc-results` gate, and reversible.
- **B:** keep it local until the price-band read lands, then decide whether the stale-E cap gets its own
  pre-registered run.
