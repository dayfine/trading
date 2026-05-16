# IWV scrape blocker — Akamai 503 (2026-05-16)

**Status:** BLOCKED (cooldown ongoing). The P0a operational scrape per
`dev/notes/next-session-priorities-2026-05-17.md` §P0a cannot run from
this network/IP until Akamai unblocks.

## What I tried

```bash
docker exec -w /workspaces/trading-1/trading trading-1-dev bash -c \
  'eval $(opam env) && dune exec analysis/data/sources/ishares/bin/fetch_iwv_history.exe -- \
     -from 2006-09-29 -until 2026-05-16 -cadence auto \
     -cache-dir ../dev/data/ishares/iwv -sleep-ms 2000' \
  > dev/logs/iwv-fetch-2026-05-16.log 2>&1 &
```

Planned 3714 dates ≈ 2h 4min wall clock. Killed after ~5 minutes with
zero CSVs written and zero `.sentinel` markers.

## How it failed

- Process state: `S (sleeping)` at 0.5% CPU.
- `/proc/<pid>/net/tcp`: no remote connection. Socket fd 7 open but
  never reached established state for the ishares.com host.
- `dev/logs/iwv-fetch-2026-05-16.log`: only the dune workspace warning
  + `exit=143` after SIGTERM. The exe prints summary only at end (per
  `fetch_iwv_history.ml` — no progress line during the fetch loop).

## Root cause — Akamai IP block

Independent reproduction with curl, both inside the docker container
and from the host (macOS):

```bash
$ curl -sI --max-time 10 \
    "https://www.ishares.com/us/products/239714/ishares-russell-3000-etf/1467271812596.ajax?fileType=csv&fileName=IWV_holdings&dataType=fund&asOfDate=20240301"
HTTP/2 503
server: AkamaiGHost
x-reference-error: 102.c9e9c717.1778928012.b71c3635
```

Reproduces with:
- No headers.
- `-A "Mozilla/5.0"` UA only.
- Full Chrome UA + `Referer: https://www.ishares.com/...` + `Accept: text/csv,*/*`.

Even the bare landing page `https://www.ishares.com/us/products/239714/ishares-russell-3000-etf`
returns 503. Google returns 200 — internet itself is fine.

This is an IP-level block from Akamai's bot WAF. Almost certainly
triggered by the `Cohttp_async` default UA (`ocaml-cohttp/<version>`)
on the first contact attempts before any retry logic existed.

## What's been fixed

**PR #1131** (`fix(ishares): browser headers + 503/429 retry-with-backoff
for IWV fetcher`) **MERGED 2026-05-16 12:15Z**. Implements:

- Browser User-Agent (`Mozilla/5.0 ... Chrome/120.0.0.0 Safari/537.36`),
  Accept, Accept-Language, Referer headers on every GET via
  `Cohttp.Header.of_list`.
- Retry on 503/429/502/504 with exponential backoff (5s, 30s, 120s, 3
  attempts max).
- Injectable sleep fn so tests don't actually wait.
- 4 mock-fetcher retry tests pin the contract.

So the *code* is ready. The blocker is now purely the Akamai cooldown
on this egress IP.

## Cooldown probe timeline (2026-05-16)

| Probe | Local time | Wall time post-first-contact | Result |
|---|---|---|---|
| 0 | ~10:34Z | 0 (first contact) | 503 — initial run that flagged the IP |
| 1 | ~11:50Z | ~75 min | 503 |
| 2 | ~12:33Z | ~120 min | 503 |
| 3 | ~13:41Z (scheduled wakeup) | ~190 min | TBD |
| 4 | (conditional, ~17:30Z) | ~420 min | TBD |

Akamai blocks last 1–24h per their public docs.

## What needs to happen next

1. **Wait for Akamai cooldown.** Wakeups at 13:41Z (probe 3) and
   conditionally 17:30Z (probe 4) will retry. If still blocked at
   probe 4, give up the local path tonight.
2. **Once probe returns 200**, single-date probe via:
   ```bash
   docker exec -w /workspaces/trading-1/trading trading-1-dev bash -c \
     'eval $(opam env) && dune exec analysis/data/sources/ishares/bin/fetch_iwv_history.exe -- \
        -from 2024-03-01 -until 2024-03-01 -cadence daily \
        -cache-dir ../dev/data/ishares/iwv -sleep-ms 2000'
   ```
   If `dev/data/ishares/iwv/2024-03-01.csv` writes with valid holdings
   (~3000 rows), Akamai is unblocked AND #1131's headers work.
3. **Full backfill** (~3h wall clock):
   ```bash
   docker exec -w /workspaces/trading-1/trading trading-1-dev bash -c \
     'eval $(opam env) && dune exec analysis/data/sources/ishares/bin/fetch_iwv_history.exe -- \
        -from 2006-09-29 -until 2026-05-16 -cadence auto \
        -cache-dir ../dev/data/ishares/iwv -sleep-ms 2000' \
     > dev/logs/iwv-fetch-2026-05-16-pm.log 2>&1 &
   ```
4. **`build_iwv_universe.exe`** over the cache to emit
   `trading/test_data/goldens-russell-3000-historical/russell-3000-2006-2026.sexp`.
5. **Survivorship-correct re-pin** of `sp500-2010-2026.sexp` baseline
   on the IWV-derived cohort (Phase 1.3 / next-session-priorities §P0c).

## Alternative if local IP stays blocked

Run the scrape from a GHA runner — different egress IP, not previously
flagged. The exe is container-portable; needs a one-shot
`workflow_dispatch` workflow that:

1. Pulls `ghcr.io/dayfine/trading-ci:latest`.
2. Runs `fetch_iwv_history.exe` with `-sleep-ms 2000` for ~3h.
3. Uploads `dev/data/ishares/iwv/` as a workflow artifact.
4. (Optional) commits the resulting `russell-3000-2006-2026.sexp` via
   a follow-up PR.

`.github/workflows/iwv-scrape-once.yml` would be ~40 LOC.

## Open items for next session

- (a) Probe 3 + 4 results (will be appended by the scheduled wakeups).
- (b) Decision: local scrape (after Akamai cooldown elapses) vs.
  GHA-runner scrape (independent of local IP).
- (c) The `dev/notes/next-session-priorities-2026-05-17.md` §P0a TL;DR
  said "Next step is operational, not a feature PR" — that wasn't
  true; PR #1131 (browser headers + retry) was needed first, and is
  now merged. Update the priorities doc next-step text accordingly.
