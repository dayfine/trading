# Next-session priorities — 2026-11-15 (supersedes 2026-11-14 EOD)

The gate funnel (observatory P1) is read: **Rule 1 PARK, Rule 2 NO RANKING LEVER** (#3631). The spare cash and buyable
names it found are an empty-book state after a gate block, not a wasted cap, and the one binding gate behind both the
bear brake and the recovery gap is the structural-stop check at 15 %. So P3 starts with `max_stop_distance_pct`. The
observatory's pair reader is on main (#3634); the lane chain that feeds it is being built (P2b). Ground rules
unchanged: backtests in the cloud, local container for QC and smokes, feat agents build + fmt locally and CI runs tests.

## 1. Merged this session (11-15 PT, overnight)

| PR | what |
|---|---|
| #3630 | `screener.ml` 498 → 345 lines: per-candidate evaluation moved verbatim into `screener_candidate_eval.{ml,mli}` |
| #3631 | gate-funnel 26y cell read: **Rule 1 PARK, Rule 2 NO RANKING LEVER**; cell = #3602 S-k0 byte for byte (the candidate-log fields change no trade over 26y); price files in `dayfine/trading-results` a3a2dadc2 (first cloud push there) |
| #3632 | `float_equal` and `gt`/`ge`/`lt`/`le`/`is_between` fail on NaN (`?nan_equal` opt-in); full suite green, so no test was riding a hidden NaN. Closes #3627 |
| #3633 | rules: chains split `collect`/`publish` (sweep-hygiene), docker preflight in cloud; four transferable read rules (gate-distance levers, replay exits from the moved fill, leave-one-year-out on pooled clauses, path-aware binding counts) in the rigor rule and screen-rigor skill |
| #3634 | observatory P2a: `dev/experiments/observatory/obs_read.sh` (paired D(t) per seed → private; one mark-free row → `surface.tsv`; §3 flag rule; refusals append nothing), 11-arm boundary fixture |

## 2. The funnel result in one paragraph

X net·f 1,200 against the CLOSE bar 25 (the prior said CLOSE). 52 % of X falls on 74 zero-position Fridays and 90 %
within 26 open Fridays of a Bearish read; there the top 20 is 96 % A+ fresh highs and 94 % `No_structural_stop`,
while buyable names sit at ranks 21–200+. In the invested state (744 of 1,099 open Fridays) cash binds, as the 09-22
read said. C\*'s ride tie with the funded names is 2003 alone (leave-one-year-out fails 7/21), and the bear share is
0.26 against 0.15, so PARK. `Stop_too_wide` never fires: under `require_structural_stop` the width gate and the
structural-stop gate are one gate. Memory: `project_axis_observatory_gate_funnel`.

## 3. In flight

- **P2b lane chain** (`harness/observatory-lane`, feat-backtest agent): `dev/experiments/observatory/lane.sh` +
  `queue.tsv` seeded with `msd-12` / `msd-18` (`max_stop_distance_pct` 0.12 / 0.18 vs 0.15); S k0–k4 once per HEAD,
  arm k0–k4, tripwire + V6 + liveness, `obs_read.sh`, `collect` → branch `observatory/lane-results`, `publish` →
  trading-results; baseline-drift mode; SPY years file from the bar store; `--dry-run` + check. Also folds the #3634
  review's non-blocking notes. Then CI → qc-structural (sonnet) → qc-behavioral.

## 4. Queue

1. **P2b review and merge**, then **launch the first lane** in one Claude cloud session (a routine like
   `trig_01EGdsscqsgyTNNLHwbG7h5T`, both repos as sources, `setsid nohup`, Monitor + 30-min heartbeat). Measure its
   tokens and record them before adding a second lane (plan §4).
2. **P3 order** (from the funnel): `max_stop_distance_pct` 12/15/18 first, read as D(t) around the reopen episodes
   (2002, 2003, 2008, 2009, 2016, 2022–23) by regime, with positions held and crowded-out S tickets; `max_buy_candidates`
   40 low (ranks 21–40 hold 16 % of C\*); ranking dials low; gate-before-cap stays PARK, unqueued.
3. **P2c curves page**: the plan's private artifact page of all arms' D(t) (data from trading-results only).
4. Carried: pack render blank-slice check; #3613 split resting orders; stop traded days before the exit fill
   (TRW-wein-742, #3075 class); entry-timing-screen README estimand note; orchestrator CI pre-flight fallback; D1
   td-full shadowing fix; #3587; SPY refresh (forward weeks need it); 38 near-tightening stops; dangling-doc linter;
   #3578; `pr_gate_status` 3000-file sentinel; the #3610 README / 11-14 handoff "sub-top-1000" wording.

## 5. Decisions waiting (deferred to 11:00 PT)

- **Frozen pre-registration text on main quotes a few smoke-year fill prices** (carried from 11-14 EOD;
  `dev/experiments/stale-e-cap-k5-2026-11-14/README.md`, from #3608). (A, recommended) leave it, as history before
  11-14 is not scrubbed; (B) redact in place with a note. Your call under the data-terms decision.
- **Track pacer #3635: eight ESCALATE_TO_MAINTAINER rows**, most repeated for weeks: close `rename-twin-dedup` (done);
  `support-floor-stops` (set a next step or close; stalls next week); `tuning` (#1327 M2 enable, 17th ask);
  `sweep-perf` (manual ghcr flambda rebuild, 16th); `resistance-v2` (#3527 open, 14th); `arc-readiness`;
  `weekly-snapshot`; `short-side-strategy` (paired surface + close-out). Recommended: one batch call that closes the
  finished or abandoned tracks and names one next step for each that stays, so the pacer stops re-asking.

## 6. Lessons

- **Cloud containers can start without dockerd.** The funnel's first launch aborted at BUILD in the same second; the
  session started `dockerd` and relaunched (stage reused). Now in sweep-hygiene (#3633).
- **Analyst why-tables need their scripts committed.** qc-results traced every number only because the scratch joins
  went in as `read/why/`; three tables stayed ad hoc and had to be flagged. Brief analysts to keep joins as files.
- **Mutation probes find unpinned thresholds.** #3634's first check pinned one flag clause of three; near-miss fixture
  arms (one clause off by a hair, each direction) fixed it. Use that shape for any rule with several bars.
- **Agents' scratch dirs can collide with old jj workspaces** in the shared scratchpad (the analyst wrote into a stale
  `gf/` workspace). Remove workspaces when their PR merges.
