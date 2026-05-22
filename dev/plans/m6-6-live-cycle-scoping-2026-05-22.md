# M6.6 Live Cycle — Scoping Plan (2026-05-22)

Plan-only doc. Per `dev/notes/next-session-priorities-2026-05-22.md` §P2,
user green-lit M6.6 scoping ("we could start setting it up with param and
code version pinned"). This doc enumerates the components, dependencies,
and sequencing for the full live cycle so a future session can dispatch
the implementation against a clear scope.

## 0. What "M6.6 live cycle" means (from `weinstein-trading-system-v2.md` §7)

> **M6.6** True live cycle (later) — Wire `live` DATA_SOURCE + cron +
> alerts. Out of scope for now; previously the entire M6.

Operational definition: the system runs **without human intervention
between Friday-close screening sessions**. The maintainer reviews the
weekly report Saturday morning, decides whether to execute the suggested
orders, and acknowledges alerts during the week.

The Saturday review per `weinstein-trading-system-v2.md` §3 requires:
1. Friday-close screen → ranked candidates with entries/stops
2. Held-position update → trailing stops adjusted, exits flagged
3. Weekly report written to disk + emailed (or push-notified)
4. Mid-week alerts fire if a stop triggers or position needs review

## 1. State of the world (2026-05-22)

| Component                                  | State       | Path                                                                |
|--------------------------------------------|-------------|---------------------------------------------------------------------|
| `live` DATA_SOURCE                         | **EXISTS**  | `trading/analysis/weinstein/data_source/lib/live_source.{ml,mli}`   |
| EODHD client                               | EXISTS      | `trading/analysis/data/sources/eodhd/lib/eodhd.{ml,mli}`            |
| Weekly snapshot generator (M6.1)           | EXISTS      | `trading/trading/weinstein/snapshot/lib/weekly_snapshot.{ml,mli}`   |
| Forward-trace renderer (M6.2)              | EXISTS      | `trading/trading/weinstein/snapshot/lib/forward_trace.{ml,mli}`     |
| Cross-version pick diff (M6.3)             | EXISTS      | `trading/trading/weinstein/snapshot/lib/pick_diff.{ml,mli}`         |
| Split/dividend verification (M6.4)         | EXISTS      | `trading/trading/data/types/split_*`                                |
| Weekly report renderer (M6.5)              | EXISTS      | `trading/trading/weinstein/snapshot/lib/report_renderer.{ml,mli}`   |
| **Cron / scheduler**                       | MISSING     | new — `.github/workflows/weekly-live-cycle.yml`                     |
| **Alert dispatch (email / push)**          | MISSING     | new — `trading/trading/weinstein/notify/`                           |
| **Trading-state durability**               | PARTIAL     | snapshots ARE durable; **portfolio state across runs not yet**     |
| **Parameter pin via `live/current.sexp`** | EXISTS      | `dayfine/trading-parameters` repo (#1234 + #1240 + #1241 + #1243)   |

**Implication:** M6.6 is **not** a from-scratch milestone — it's a
wiring milestone. ~70% of the moving parts exist. The missing pieces are
the cron entry, the alert side-channel, and the cross-run portfolio
state.

The user prompt ("set it up with param and code version pinned") matches
the parameter-pin component, which is already done via `promote_config.sh`.
That means M6.6 can launch against `dayfine/trading-parameters` live
config at any time without further infra work on the parameter side.

## 2. Component scope (the work to do)

### 2.1 Live-cycle entrypoint binary [new, ~300 LOC]

`trading/trading/weinstein/live/bin/weekly_cycle.ml` (new). One-shot
process invoked by cron each Friday at 16:30 ET (post-close + EODHD
end-of-day publish ~16:00 ET). Reads:

- Config: `$TRADING_PARAMS_DIR/live/current.sexp` (promote_config.sh-managed)
- Trading state: `$TRADING_STATE_DIR/portfolio.sexp` (per §2.4 below)
- DATA_SOURCE: `Live_source` with cache under `$TRADING_DATA_DIR`

Pipeline (mirrors the simulator pipeline):
1. `Live_source.refresh` to pull this week's bars (incremental, ~5-10
   min per `eng-design-1-data-layer.md` §Performance).
2. Run the Weinstein strategy's `on_market_close` on the latest bars.
3. Compute trailing stops on held positions.
4. Emit `Weekly_snapshot.t` to `dev/weekly-picks/<system-version>/<date>.sexp`.
5. Render `Weekly_report.t` (markdown).
6. Diff against last week's snapshot (M6.3 `pick_diff`).
7. Update trading state: persist updated stops + held-position metadata.
8. Dispatch report + diff to operator (per §2.3 below).

The entrypoint is **the only new code that orchestrates**; everything
else is a library call to existing modules. Estimate ~300 LOC including
arg parsing, error handling, and structured logging.

### 2.2 Cron / scheduler integration [new, ~50 LOC YAML + Dockerfile]

`.github/workflows/weekly-live-cycle.yml` (new). Same pattern as
`.github/workflows/orchestrator.yml` (the daily-summary cron):

- `schedule: - cron: "30 21 * * 5"` (Friday 21:30 UTC = 16:30 ET = 13:30 PT)
- `runs-on: ubuntu-latest`, `timeout-minutes: 60`
- Container: `ghcr.io/dayfine/trading-devcontainer:latest` (same as
  orchestrator)
- Env: `EODHD_API_KEY`, `TRADING_PARAMS_DIR` (clone `dayfine/trading-parameters`
  at workflow start), `TRADING_STATE_DIR` (clone `dayfine/trading-state`
  per §2.4 below)
- Steps:
  1. Checkout `dayfine/trading`
  2. Clone `dayfine/trading-parameters` + read `live/current.sexp`
  3. Clone `dayfine/trading-state` + read `portfolio.sexp`
  4. Build `weekly_cycle.exe` (dune)
  5. Run `weekly_cycle.exe` — emits snapshot + report
  6. Commit + push snapshot to `dayfine/trading`
  7. Commit + push updated state to `dayfine/trading-state`
  8. Dispatch alert (per §2.3)

**Why GHA cron, not a self-hosted process:**
- Already paid for via existing CI minutes budget.
- No infra to babysit (no VM, no `systemd`).
- Run logs are durably stored in GHA UI.
- Same auth + secret model as the daily orchestrator.

**Tradeoff:** GHA cron has ~5-10 min jitter; not suitable for
sub-second-precision tasks. For weekly close timing, that's fine.

### 2.3 Alert dispatch [new, ~150 LOC]

`trading/trading/weinstein/notify/{notify.ml,notify.mli}` (new). Three
adapters behind a single interface:

```ocaml
module type NOTIFIER = sig
  val send : subject:string -> body:string -> unit Status.status_or
end
```

Adapters (one is enough for v1):
| Adapter | Mechanism | Cost | Latency |
|---|---|---|---|
| **Email (SMTP)** | RECOMMENDED. SendGrid / SES / Mailgun free tier | $0 | <1 min |
| Push (Pushover) | Pushover API; mobile push | $5 one-time | <1 min |
| Slack webhook | Existing Slack workspace incoming webhook | $0 | <1 min |

**Recommendation v1: SendGrid email** — single recipient, structured
HTML body, attaches the weekly report markdown. Pushover is a v1.5
add-on if the operator wants mobile alerts on stop triggers.

Alert types:
- `WeeklyReportReady` (Friday close) — body = weekly report markdown
- `StopTriggered` (mid-week, when daily monitor fires) — body =
  symbol + price + stop + suggested action
- `MacroRegimeChange` (rare, when bullish↔bearish flips) — body =
  before/after macro snapshot

The daily monitor for `StopTriggered` requires a separate daily cron
that runs on Mon-Thu (Friday is covered by the weekly cycle). Same
GHA pattern, smaller scope.

### 2.4 Trading-state durability [new repo + ~200 LOC]

Currently the simulator holds portfolio state in `Portfolio.t` (an
in-memory record). For live trading the state must survive cron-run
restarts. Two design options:

**Option A — `dayfine/trading-state` private repo (RECOMMENDED).**
- Single `portfolio.sexp` file with the current `Portfolio.t` snapshot.
- Each weekly-cycle run commits the updated state.
- Git history is the audit log of every state change.
- Cron clones at start, commits + pushes at end.
- Pattern matches `dayfine/trading-parameters` exactly.

**Option B — DynamoDB / SQLite remote.**
- More machinery; same durability guarantee.
- No human-readable history without explicit tooling.
- More moving parts in the cron path (auth + network).

**Pick A.** Reuse the parameter-repo pattern; minimal infra; auditable.

Schema:
```
trading-state/
├── README.md
├── portfolio.sexp           — current Portfolio.t snapshot
├── _archive/                — pre-cycle snapshots (rotation cap N=52)
│   ├── 2026-05-23.sexp
│   └── ...
└── _metadata/
    └── audit.sexp           — append-only event log
```

`portfolio.sexp` round-trip requires `[@@deriving sexp]` on
`Portfolio.t` (verify in `trading/trading/portfolio/lib/portfolio.mli`
— if missing, ~50 LOC of derivers + a round-trip test). The state
schema is **version-tagged** so a future `Portfolio.t` evolution can
migrate cleanly.

### 2.5 Parameter pin (already done)

`promote_config.sh` (#1234 + #1240 + #1241 + #1243) writes
`dayfine/trading-parameters/live/current.sexp`. The weekly-cycle
entrypoint (§2.1) reads that file at run start. Config is therefore
pinned at promote time, not at run time.

**No new work** needed for the parameter side.

### 2.6 Code-version pin

The weekly-cycle workflow YAML pins a specific `dayfine/trading@<sha>`
at `actions/checkout` step. Bumping the live system to a new code
version is a one-line YAML diff. The pinned sha + the
`trading-parameters/live/current.sexp` together constitute the full
reproducibility envelope.

## 3. Sequencing

Estimated wall: **3-5 sessions** (per the weekly-snapshot.md
"~5 sessions" line, but with parameter-pin already done).

| Session | Scope | Output |
|---|---|---|
| **S1** | `weekly_cycle.exe` entrypoint (§2.1) — read config + state, run pipeline, write snapshot + report locally; no cron, no alert | One-shot binary; end-to-end test on the most recent Friday |
| **S2** | Alert dispatch (§2.3) — SendGrid email + interface; wire into `weekly_cycle.exe` | Email arrives in operator inbox during local test |
| **S3** | Trading-state repo + persistence (§2.4) — create `dayfine/trading-state`, derive sexp on Portfolio.t if missing, write/read cycle | `portfolio.sexp` round-trips cleanly |
| **S4** | Cron / GHA workflow (§2.2) — write `.github/workflows/weekly-live-cycle.yml`, register all secrets, dry-run via `workflow_dispatch` | First successful end-to-end cron run, paper-only |
| **S5** | Daily-monitor cron (Mon-Thu) for `StopTriggered` alerts | Second weekly workflow file |

**S1 is the highest-leverage first step** — once the entrypoint runs
end-to-end locally, S2-S5 are wiring against a working pipeline.

## 4. Open decisions (require user input before S1)

1. **Email service.** SendGrid vs SES vs Mailgun — all $0 at our
   volume. Recommend SendGrid for simplest API. **NEEDS USER PICK.**
2. **Trading-state private repo name.** `dayfine/trading-state` proposed
   above. **NEEDS USER CONFIRM.**
3. **Cron timing.** Friday 13:30 PT proposed (post-close + EODHD
   end-of-day publish ~13:00 PT). **NEEDS USER CONFIRM** (or operator
   preference re. when to be paged for review).
4. **Whether to gate on the V3 winner config or wait for the 11-knob
   sweep / cross-scenario validation result.** V3 winner is currently
   promoted to `live/current.sexp` post P0 E2E; an alternative is to
   wait for 11-knob result before going live. **NEEDS USER PICK.**

## 5. Risks

| Risk | Mitigation |
|---|---|
| EODHD rate limit during cycle | live_source already throttles to 20 concurrent; weekly incremental is ~5-10 min wall |
| Stale config drift between local promote + cron run | Both read from `trading-parameters/live/current.sexp` via env var; cron clones at run start |
| Portfolio.t schema break | Version-tagged sexp + schema-aware reader (mirrors `weekly_snapshot` pattern) |
| Alert spam from advisory linter noise | Alerts only on hard signals (stop fired, regime change); weekly report is informational, not alerting |
| Trading-state push race (cron vs local manual update) | Single writer (cron); operator never manually edits state. Document this in trading-state README |

## 6. Out of scope for M6.6

- **Automated order execution.** M6.6 is signal generation + alerting
  only; operator places orders manually. Automated execution is M7+ and
  requires broker integration.
- **Intraday data / decisions.** Weekly + daily-monitor only; no
  hour-by-hour processing.
- **Multi-account / multi-strategy.** Single portfolio, single Weinstein
  strategy variant pinned by `live/current.sexp`.
- **Margin / shorts.** Long-only v1 (matches the strategy's current
  capability per `dev/status/short-side-strategy.md`).

## 7. Reference

- `docs/design/weinstein-trading-system-v2.md` §3 + §7 — system-level
  weekly-cycle workflow + M6.6 milestone definition
- `docs/design/eng-design-1-data-layer.md` §DATA_SOURCE — Live_source
  contract
- `dev/status/weekly-snapshot.md` — M6.1-M6.5 scope (precursor)
- `dev/notes/next-session-priorities-2026-05-22.md` §P2 — user
  green-light + this plan's source
- `trading/trading/weinstein/snapshot/lib/*.{ml,mli}` — existing
  M6.1-M6.5 implementation
- `trading/analysis/weinstein/data_source/lib/live_source.{ml,mli}` —
  existing `live` DATA_SOURCE
