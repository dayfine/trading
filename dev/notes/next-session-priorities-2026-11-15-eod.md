# Next-session priorities — 2026-11-15 EOD (supersedes 2026-11-15)

The observatory is running. The lane runner merged (#3637, #3639), the first arm (msd-12, `max_stop_distance_pct`
0.12 vs the record's 0.15) finished on a cloud session with every validity gate passing and **no flag**, and the
second arm (msd-18) is running at the same commit, reusing S. The 11:00 decisions are resolved. Ground rules
unchanged: backtests in the cloud, local container for QC and smokes, feat agents build + fmt locally and CI runs tests.

## 1. Merged since the 11-15 handoff (#3636)

| PR | what |
|---|---|
| #3635 | weekly track pacer 2026-11-15 |
| #3637 | observatory P2b: `lane.sh`, `queue.tsv` (msd-12, msd-18), S once per HEAD, tripwire + V6 + liveness, drift mode, collect → `observatory/lane-results`, publish → trading-results |
| #3639 | lane follow-ups: overrides replace a record field by full path (`OVERRIDE` log), `tiebreak_seed` and multi-field forms refused, drift-read-failed event, `lane.out` under `.sweep-output/` |
| #3641 | status cleanup from the pacer (your batch-cleanup call) |
| #3643 | lane check starts from an empty lane state: it had copied the live `surface.tsv`, so #3642's first row failed six assertions in CI |
| #3642 | msd-12 lane results, qc-results APPROVED (see §2) |

Decisions taken at 11:00: #3608's README fill prices stay (history before 11-14 is not scrubbed); stale tracks went
in one batch (#3641).

## 2. msd-12 in one paragraph

Validity: S k0 `trades.csv` matched the record md5 0928cfe4; V6 agreed on 5/5 seeds; msd-12 differed from S on 5/5
(live); no drift point yet. Surface row: median D_end −0.272 (seeds −0.27, −0.40, −0.23, −0.21, −0.75), but the
yearly signs split 50/50 (no seed is 60 % negative), so the HARM clause fails and the flag is none; no analyst read,
per the plan. Orientation only: bear-year steps +0.12 and bear-macro +0.05, max drawdown 1.7 pp lower, 5.5 fewer
entries a year (medians: drawdown was lower on 3 seeds and higher on 2, and the Ulcer index rose 0.28), and the k0
seed's largest steps are 2020–21 weeks when S held APPS. S shows 32–39 V7 violations per seed, as the record does;
msd-12 passes V7 on all five, which a later stop-gate read should note. A tighter gate looks like more
bear brake for less tail, which is what #3621 predicts; one arm does not make that a finding. Price-bearing cells and
reads: trading-results 5ddca9182.

## 3. In flight

- **msd-18 lane**: cloud session `cse_013VUubgvrtZ7KtUP5iT9fV7` (routine `trig_01EGdsscqsgyTNNLHwbG7h5T`), LANE_SHA
  3c367cca7, launched 03:31Z 11-16; dry run picked msd-18 and reuses S k0–k4 from trading-results, so 5 cells in three
  batches, expected to publish ~09:30–10:00Z. Then the same mechanical read and a results PR (qc-results).
- **The branch after #3642 merges.** The repo deletes head branches on merge, so msd-18's publish recreates
  `observatory/lane-results` from 32ff86c00. Run `gh pr update-branch` on its PR before review so the diff is msd-18
  alone (surface/events/drift merge as a union, and queue.tsv merges cleanly).
- **Weekly picks backfill, 13 Fridays 2026-08-21 → 11-13** (pacer #3635: 93 days stale). Step 1, ops-data: refresh
  the local bar store (it ended 08-17/18) through 11-13, stale set included. Step 2: generate, validate and render each
  Friday on the record config (rk-k0 overrides; the 07-14 `live-config-overrides.sexp` predates the record), at main.
  Full reports print closes and entry/stop prices, so they go to private trading-results; the public repo gets rank,
  symbol, grade, score and sector only. Then keep the cadence weekly.

## 4. Queue

1. **msd-18 read**, plus the price-band slice promised on 11-15: of the admissions msd-18 adds over S, what share is
   ≤ $14, whether the D(t) gain or harm comes from them, and how 2008 behaves (counts only; mark-free). This is where
   the low-price trait goes next: the price-order axis is closed (#3602, #3610), and the cheap monsters are lost at
   this gate (`project_trait_y_low_price`).
2. **Next arms need a new HEAD**, which re-runs S (the drift point by design). Batch the queue additions in one PR:
   P3 order from the funnel is `max_buy_candidates` 40 low, then the ranking dials low; gate-before-cap stays PARK.
   Decide after msd-18 whether a price-conditioned width (the 15 % gate for cheap names only) is worth a W2 argument.
3. **P2c curves page**: private artifact of all arms' D(t), data from trading-results only.
4. **Lane tokens (plan §4)**: msd-12's session woke ~4 times an hour (a 30-min Monitor plus a 30-min `send_later`),
   ~40 wakes of ~4 model calls each over 9.8 h, plus a 9-call launch and an 8-call finish. msd-18's brief uses one
   background wait (≤ 110 min) and one 120-min fallback, ~1 wake per 2 h. Read the quota delta over the msd-18 run
   before running two lanes at once.
5. Carried: pack render blank-slice check; #3613 split resting orders; stop traded days before the exit fill
   (TRW-wein-742, #3075 class); entry-timing-screen README estimand note; orchestrator CI pre-flight fallback; D1
   td-full shadowing fix; #3587; SPY refresh; 38 near-tightening stops; dangling-doc linter; #3578;
   `pr_gate_status` 3000-file sentinel; the #3610 README / 11-14 handoff "sub-top-1000" wording.

## 5. Decisions waiting (raise at 11:00 PT)

- **Weekly live picks: decided by the user 11-15 22:10 PT — "we should still backfill all the weekly picks".** In
  progress, see §3.
- **Host headroom (optional).** Swap was 15.5 / 16 GB at 19:30 PT (load from Arduino builds and tests); disk 33 GiB
  free. Offered: delete `.sweep-output` entries older than 30 days (~4 GB, results already committed or published)
  and quit Docker Desktop while nothing local needs the container (frees its 4 GB VM).

## 6. Lessons

- **A check that copies a data directory must reset the data.** The lane check copied the whole observatory dir, so
  the first merged row broke it; any results PR would have. Test fixtures copy code, not state.
- **Cloud wait cadence sets the lane's token cost.** A 30-min Monitor plus a 30-min heartbeat is ~4 wakes an hour; a
  background wait capped under the 2 h limit plus one fallback is one wake per ~2 h for the same safety.
- **Poll, then sleep, then poll once more.** My branch watch slept after its last poll and reported "not landed" 17
  minutes after the branch landed.
