# Next-session priorities — 2026-11-23 EOD (covers 11-23 01:45 → 16:00 PT; supersedes 2026-11-23)

The NAV-scale run is read and merged. The user then opened a new line: widen the universe and test the structural stop
at live size. The store was expanded and new PIT lists built; the warehouse is building in a cloud session and the
experiment is pre-registered. Main CI is green. Local Docker is OFF (Docker Desktop quit); nothing local is running.

## 1. Merged (11-23)

| PR | what |
|---|---|
| #3701 | bar fixtures fetched from private trading-results in CI and orchestrator (#3676) |
| #3702 | 11-23 handoff addendum (launchd picks, $100k, Docker) |
| #3704 | NAV-scale K=5 results. P-100k INCONCLUSIVE (+0.002, 3/5), P-1M INCONCLUSIVE (−0.024, 2/5), P-10M −0.62..−0.98 (capacity). Cap stays default-off. #3681 closed. #3693 verify met with a caveat: P-100k is live-sized (median $9–13k positions) only 2000–08 |
| #3706 | pit-v13 lists (top-3000/4000, 1998–2026, true-dollar ranking, 16,203-symbol store) + version-parameterised warehouse build (`CHUNKS`, `CONTAINER=none`, v13 wrapper, cloud recipe) |

Filed: #3705 (finding: CMRE 5.1× / BFH 4.0× store-vs-warehouse bar disagreement, not a reverse-split artifact).

## 2. In flight

- **Cloud warehouse build** — routine `pit-v13-warehouse` (trig_01PFZXkURuQtCZu5VKs8H4kV), fired 23:57Z 11-23,
  6–9 h. It pulls `bars/data-20261123` from R2, builds in its own `trading-1-dev` container, uploads
  `warehouse/v13pit-<N>`, applies the twin alias map and opens a PR from `data/pit-v13-aliased` (lists/md5/twin-drops
  only). Check `RemoteTrigger list_runs`. Gate that PR as a data PR (CI + QC pair; it is not results-only).
- **#3707** — universe-depth pre-registration (`dev/experiments/universe-depth-2026-11-23/PREREG.md`), docs-only:
  merge on green CI.
- R2 now also holds `warehouse/corpact-2026-11-23` (32,238 files, 16,119 dividends.csv), which the new names need.

## 3. Next, in order

1. When the warehouse PR lands: write the universe-depth specs + chain (4 arms × K=5 + the k0 tripwire, per PREREG),
   one cloud session per seed, `setsid nohup` launch. Specs need `universe_size` 3000/4000 and the v13 list schedule.
2. Read with `results-analyst`, review with `qc-results`.
3. **#3693:** remaining item (position-scaled hold floor) is unsupported by the NAV-scale run (fired ~once/seed at
   $500k, never at $50k). Recommend won't-build; user's call.
4. **#3676 after-merge:** run `sh dev/scripts/fetch_test_bars.sh` in each local checkout after pulling main; SPY refresh.
5. First launchd picks run Sat 11-28 09:00 PT — check `~/Library/Logs/trading-weekly-picks.log`.
6. Carried: `weekly_snapshot_generator.ml` does not thread `virgin_supply_basis`.
7. Data hygiene (both v12 and v13): foreign / vendor-splice names with absurd ADV at the top of the lists (HSBA,
   SBER, VPI, LDG, GEG_, HVN). They take list slots from real names; not yet triaged.

## 4. Universe facts (11-23 audit)

- Store eligible pool is only ~4.8–5.7k names/yr; rank 5000 ≈ $0.1–0.4M ADV and the 4001–5000 band is 33 % defective,
  so top-4000 ≈ "everything the $1M floor admits".
- The old top-3000 lists had holes (99–262 names/yr missing from the store). EODHD tags each name with today's
  exchange, so failed ex-NASDAQ names (now OTC/PINK) were never fetched: survivorship. v13 adds 156–717 names/yr
  vs v12; 30–65 % are OTC/PINK today.
- v13 also ranks by true dollar volume (v12 did not), so v12 → v13 moves two things at once. The PREREG compares arms
  within v13 only; S3 vs NAV-scale P-100k is descriptive.
- At $100k the liquidity floor does not block cheap names; the `No_structural_stop` gate does (238/249 sub-$1M rows
  on k0). `require_structural_stop false` is spine item 5 — testable, not promotable.

## 5. Lessons

- **Quitting Docker Desktop killed a live data agent's `docker exec`.** Quit only after `container_idle_stop.sh`
  says the container stopped; "kept: a host docker exec targets it" means a job is live.
- **A position cap is not a position size.** The "$14k" claim in the NAV-scale read was the cap; measured medians
  were $9–94k by era. Measure sizes from trades.csv before claiming live-size coverage.
- **qc-behavioral caught a recipe that could not run** (exe on a cloud host without libta-lib). Doc recipes that
  name a toolchain need the same scrutiny as code.
