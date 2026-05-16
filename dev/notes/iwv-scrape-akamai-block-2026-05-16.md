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

| Probe | Local time | curl result | OCaml fetcher result |
|---|---|---|---|
| 0 | ~10:34Z | 503 | n/a (initial run that flagged the IP) |
| 1 | ~11:50Z | 503 | not attempted |
| 2 | ~12:33Z | 503 | not attempted |
| 3 | ~21:43Z | **200 + text/csv** | **HTML body → parse error** |

Akamai cooldown elapsed ~3.5h post-first-contact (within their 1-24h
public-doc window). At probe 3 the WAF stopped IP-blocking outright,
but the response content differs by HTTP client — see §"2026-05-16
~21:43Z update" below.

## 2026-05-16 ~21:43Z update — Akamai unblocked, but Cohttp_async still gets HTML

Direct curl (host + docker) returns HTTP/2 200 + `text/csv;charset=UTF-8`.
**But the OCaml fetcher in `fetch_iwv_history.exe` (with the PR #1131
browser headers) gets HTML in the body, status 200:**

```
ERROR 2024-03-01 — parse error: { Status.code = Status.Invalid_argument;
  message =
  "Cannot read 'Fund Holdings as of' cell from line: \"<html xmlns=\\\"http://www.w3.org/1999/xhtml\\\" prefix=\\\"og: http://ogp.me/ns#\\\" lang=\\\"en-US\\\" xml:lang=\\\"en-US\\\">\""
  }
```

Status WAS 200 (otherwise PR #1131's retry classifier would have caught
it as `Retryable_error` or `Fatal_error`), but body is the Akamai
bot-check interstitial HTML, not CSV.

### Root-cause hypothesis (untested)

Akamai's WAF likely fingerprints clients via one or more of:
1. **HTTP version.** curl uses HTTP/2; `Cohttp_async` is HTTP/1.1. Many
   CDNs serve automation-friendly content over HTTP/2 and bot-check HTML
   over HTTP/1.1 when UA claims to be a modern Chrome.
2. **TLS JA3 fingerprint.** curl on macOS emits one JA3; OCaml's
   `cohttp-async-tls` emits a different, distinctively non-browser JA3.
3. **Missing browser-only headers.** Real Chrome sends `Sec-Fetch-Site`,
   `Sec-Fetch-Dest`, `Sec-Fetch-Mode`, `sec-ch-ua`, `sec-ch-ua-mobile`,
   `sec-ch-ua-platform`. PR #1131 only added UA / Accept / Referer.

Most likely culprit is #1 (UA-version vs HTTP-version mismatch).

### What needs to happen next

| Option | Effort | P(fix) |
|---|---|---|
| (a) Add full Chrome `Sec-Fetch-*` + `sec-ch-ua-*` headers. ~10 LOC. | XS | low-medium |
| (b) Switch HTTP client to HTTP/2-capable lib (e.g. `piaf`, `h2`). Multi-file refactor. | M | medium-high |
| (c) Shell out to `curl` via `Core_unix.create_process`. ~30 LOC. | S | high |

**Recommendation:** try (a) first as a cheap probe in one PR. If still
HTML, jump to (c) — `curl` is a known-good. Don't invest in (b) until
(a)/(c) prove insufficient.

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

## GHA-runner workflow

**Rationale:** GHA runner has a different egress IP than the local dev
machine. Even if local IP is in Akamai cooldown, a GHA run will come
from a GitHub-owned IP range (not previously flagged by iShares WAF).

**Workflow file:** `.github/workflows/iwv-scrape-once.yml`

This `workflow_dispatch` workflow:
1. Pulls `ghcr.io/dayfine/trading-ci:latest` (same image as CI).
2. Builds `fetch_iwv_history.exe` inside the container via dune.
3. Runs the fetcher with the input parameters, writing to
   `$GITHUB_WORKSPACE/dev/data/ishares/iwv/`.
4. Uploads `dev/data/ishares/iwv/` as artifact `iwv-cache-<run_id>`
   (30-day retention).
5. Uploads `iwv-fetch-<run_id>.log` as artifact `iwv-log-<run_id>`.
6. Does NOT commit the cache (gitignored; download artifact manually).

**Dispatch command** (paste after PR merges):
```bash
gh workflow run iwv-scrape-once.yml \
  -f from_date=2006-09-29 \
  -f until_date=2026-05-16 \
  -f cadence=auto \
  -f sleep_ms=2000
```

**After the run completes (~3h):**
1. Download the artifact:
   ```bash
   gh run download <run_id> --name iwv-cache-<run_id> --dir dev/data/ishares/iwv/
   ```
2. Run `build_iwv_universe.exe` offline against the cache:
   ```bash
   docker exec -w /workspaces/trading-1/trading trading-1-dev bash -c \
     'eval $(opam env) && dune exec analysis/data/sources/ishares/bin/build_iwv_universe.exe -- \
        --cache-root ../dev/data/ishares/iwv \
        --output ../dev/data/ishares/russell-3000-2006-2026.sexp'
   ```
3. Commit the resulting sexp as a follow-up PR (the CSV cache stays
   gitignored; only the derived universe sexp is checked in).

**Important constraint:** concurrency is set to `cancel-in-progress: false`
— a second dispatch will queue rather than cancel a partial scrape.
The job timeout is 360 min (6h), well above the ~3h expected wall clock
at `-sleep-ms 2000` for ~3700 dates.
