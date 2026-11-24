# Next-session priorities — 2026-11-24 (covers 11-23 16:00 PT → 11-24 07:35 PT; supersedes 2026-11-23-eod)

The v13 warehouse landed and the universe-depth run is live: five cloud sessions, one per seed. Main CI is green at
84f62393. Local Docker is idle; nothing local is running.

## 1. Merged (11-24)

| PR | what |
|---|---|
| #3707 | universe-depth pre-registration (`dev/experiments/universe-depth-2026-11-23/PREREG.md`) |
| #3712 | pit-v13 lists aliased with the twin map; `twin-drops.txt` (15,592 drops); `composition.md5`. Warehouse `v13pit-12710` in R2 |
| #3714 | universe-depth run kit: `make_specs.sh`, `chain.sh`, 20 specs (S3/U4/N3/UN4 × k0..4), README |
| #3715 | cloud howto: dockerd is not running at session start; add `trading-results` with `add_repo` |

The 461-name gap between the lists (13,171) and the manifest (12,710) is 473 names seen only in the 1998 lists
(before the window) plus 4 quarantined names (DNGFF, HLAN, MDFI, SYNI). Every preflight shows only those 4 absent.

## 2. In flight: universe-depth K=5 (cloud, SC_SHA ca42b914)

| seed | trigger | session |
|---|---|---|
| k0 | trig_01UN6m3VP6Fbuf9MjPJu1eVD | cse_013VUubfAYqtFtRoPYT5co9M |
| k1 | trig_01XWnBM62sMYEeJkedfXsbA6 | cse_013VUubhcoU9xz8MTw76uj58 |
| k2 | trig_0138yboRKSBzTyBXqjNiRgAr | cse_013VUubhyMF4J8Xhui8t2mxY |
| k3 | trig_012m5scHcBbRAnUxCMjQXB5Y | cse_013VUubf7waW938gA6NHsbzL |
| k4 | trig_01Wimqdw5NiqoECxp6L5YfGM | cse_013VUubf9GwozG6ZzP71hV4E |

- k0, k1 and k3 first stopped at setup because dockerd was not running. They were relaunched about an hour later
  (the "-r2" routines); their original triggers are dead.
- **k2's tripwire MATCHED** at 14:44Z: md5 `f7746eb838618c9eac4aed7f969e63af`, 563 lines, log NAV 2.5739,
  max DD 39.55 %, 7,061 s. So the #3701 fixture removal changed nothing. All four k2 preflights passed, and
  the S3 cell started at 15:16Z.
- Each cell takes about 2 h, so each seed should finish about 8–10 h after its tripwire. Expect k2 and k4 around
  00:00–02:00Z on 11-25, and k0, k1 and k3 about an hour later.
- On DONE, each session runs `chain.sh publish K`, which writes the private artifacts to `trading-results`. It then
  pushes the public results to branch `results/universe-depth-kK`, without opening a PR.

## 3. Next, in order

1. When all five branches exist: merge them into one results PR under `dev/experiments/universe-depth-2026-11-23/`,
   then dispatch `results-analyst` (PREREG rule; report N3's `Buffer_fallback` share both placed and filled), then
   `qc-results`, then merge. The PR is results-only.
2. **#3713:** v13 twin-check dune rule (ready-for-agent).
3. **#3710** (weekly-start BAH SPY sweep): needs a SPY bar refresh, or close it as stale.
4. Carried from 11-23 EOD:
   - **#3693:** recommend won't-build (user's call).
   - **#3676:** run `fetch_test_bars.sh` after pulling main.
   - The first launchd picks run Sat 11-28 09:00 PT.
   - `weekly_snapshot_generator` does not thread `virgin_supply_basis`.
   - Triage the foreign/vendor-splice names at the top of the lists.

## 4. Decisions waiting (deferred to 11:00 PT)

- None new. #3693 won't-build and #3710 close-vs-refresh are still the user's calls.

## 5. Lessons

- **Cloud sessions do not start with dockerd running.** A brief that says "stop if `docker info` fails" stops the
  session. Give the start command, as the howto now does (#3715).
- **Routines attach the user's connectors by default.** Send `clear_mcp_connections: true` for backtest routines.
- **Two qc-results verdicts at one SHA read as "unclear".** Only a tip-moving commit clears it (#3714 needed an
  empty commit).
