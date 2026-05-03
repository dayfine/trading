# Local automation recipes — snapshot corpus refresh (2026-05-03)

User-facing setup for periodically refreshing the broad-universe
daily-snapshot corpus on the operator's host. Final PR (4/4) of
`dev/plans/data-pipeline-automation-2026-05-03.md`.

This is a per-host configuration doc — nothing in this repo wires
itself into your scheduler. Use one of the recipes below to register
`dev/scripts/build_broad_snapshot_incremental.sh` (PR 1, #819) with
`launchd` (macOS) or `cron` (Linux) and let it chip away at the corpus
every night.

## 1. Why local-only

The snapshot corpus lives under `dev/data/snapshots/...`, which is
gitignored and never reaches CI / GHA runners — see
`dev/notes/tier4-release-gate-checklist-2026-04-28.md`. Cron / launchd
on the operator's workstation is the only place periodic rebuilds can
run; the building blocks ship with the repo, but the schedule is
per-host.

The wrapper is bounded by `--max-wall`, takes a flock on
`<output-dir>/.build.lock` (concurrent invocations exit 75 /
`EX_TEMPFAIL`), and resumes from the per-symbol manifest — so a partial
run safely picks up where the previous left off.

## 2. macOS launchd recipe

`launchd` is Apple's `init`-equivalent. A `LaunchAgent` plist registered
under `~/Library/LaunchAgents/` runs as your user. Save to
`~/Library/LaunchAgents/com.dayfine.trading.snapshot-refresh.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.dayfine.trading.snapshot-refresh</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/difan/Projects/trading-1/dev/scripts/build_broad_snapshot_incremental.sh</string>
    <string>--universe</string>
    <string>/Users/difan/Projects/trading-1/dev/data/universes/broad-2014-2023.sexp</string>
    <string>--output-dir</string>
    <string>/Users/difan/Projects/trading-1/dev/data/snapshots/broad-2014-2023</string>
    <string>--csv-data-dir</string>
    <string>/Users/difan/Projects/trading-1/data</string>
    <string>--max-wall</string>
    <string>30m</string>
    <string>--progress-every</string>
    <string>50</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>3</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/Users/difan/.local/share/trading/logs/snapshot-refresh.out.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/difan/.local/share/trading/logs/snapshot-refresh.err.log</string>
  <key>WorkingDirectory</key>
  <string>/Users/difan/Projects/trading-1</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
```

Adjust the absolute paths for your checkout. The wrapper itself appends
to `dev/logs/snapshot-build-YYYY-MM-DD.log`; the launchd
`StandardOutPath` / `StandardErrorPath` capture anything outside that
logger (e.g. early `bash`-level errors).

**Why 3am.** EODHD bulk daily fetches typically land by ~02:30 PT, so
3am consumes the freshest CSVs without racing the fetch; lowest I/O
contention with interactive `dune build`; fits the 2–6am low-power
window. Change `Hour` / `Minute` to taste; for multi-window-per-day,
replace with an array of `StartCalendarInterval` dicts.

**launchctl cheatsheet:**

```bash
# Verify XML is well-formed
plutil -lint ~/Library/LaunchAgents/com.dayfine.trading.snapshot-refresh.plist

# Load (registers + arms)
launchctl load ~/Library/LaunchAgents/com.dayfine.trading.snapshot-refresh.plist

# Inspect status
launchctl list | grep com.dayfine.trading.snapshot-refresh
launchctl print gui/$(id -u)/com.dayfine.trading.snapshot-refresh | head -40

# One-shot run now (ignore schedule)
launchctl kickstart -k gui/$(id -u)/com.dayfine.trading.snapshot-refresh

# Unload (deregister)
launchctl unload ~/Library/LaunchAgents/com.dayfine.trading.snapshot-refresh.plist
```

After editing the plist file, you must `unload` then `load` —
`launchctl` caches plist content at load time.

## 3. Linux crontab recipe

Add to your user crontab via `crontab -e`:

```
# m h dom mon dow  command
0 3 * * * /bin/bash /home/difan/projects/trading-1/dev/scripts/build_broad_snapshot_incremental.sh --universe /home/difan/projects/trading-1/dev/data/universes/broad-2014-2023.sexp --output-dir /home/difan/projects/trading-1/dev/data/snapshots/broad-2014-2023 --csv-data-dir /home/difan/projects/trading-1/data --max-wall 30m --progress-every 50 >> /home/difan/.local/share/trading/logs/snapshot-refresh.cron.log 2>&1
```

Five-field cron format (`minute hour dom month dow command`); above runs
at 03:00 daily. Verify with `crontab -l`. For `systemd` distros, the
equivalent is a `OnCalendar=*-*-* 03:00:00` entry in a `*.timer` unit
pointing at a `*.service` unit running the wrapper — left as an
exercise; cron is the lowest-friction path for a single workstation.

## 4. Freshness pre-flight

Both recipes above blindly invoke the wrapper, which is correct but
slightly wasteful: when the corpus is already fresh, the wrapper still
acquires the lock and walks the manifest. Gate on
`check_snapshot_freshness.sh` (PR 1, #819) to skip on already-fresh
nights:

```bash
#!/usr/bin/env bash
set -euo pipefail
REPO=/Users/difan/Projects/trading-1
OUTPUT_DIR=$REPO/dev/data/snapshots/broad-2014-2023

if "$REPO/dev/scripts/check_snapshot_freshness.sh" \
     --output-dir "$OUTPUT_DIR" --csv-data-dir "$REPO/data" \
     --threshold-pct 5 --quiet; then
  echo "[snapshot-refresh] corpus is fresh; skipping rebuild"
  exit 0
fi

exec "$REPO/dev/scripts/build_broad_snapshot_incremental.sh" \
  --universe "$REPO/dev/data/universes/broad-2014-2023.sexp" \
  --output-dir "$OUTPUT_DIR" --csv-data-dir "$REPO/data" \
  --max-wall 30m --progress-every 50
```

Save as `~/bin/snapshot-refresh-gated.sh`, chmod 755, and point your
launchd plist or crontab at it instead of the raw wrapper. The probe
exits 1 when stale% > threshold (which the `if` inverts → wrapper
runs); the probe is read-only, takes seconds, and doesn't grab the
build lock — safe to run during interactive `dune build`.

## 5. Audit / monitoring

`dev/notes/snapshot-corpus-status.md` (PR 3, #821) is the canonical
at-a-glance ledger. Inspect manually:

```bash
head -10 /Users/difan/Projects/trading-1/dev/notes/snapshot-corpus-status.md
```

For an active alert when refresh has lagged, a second cron entry can
post to a Slack webhook or `mail(1)` if `Last updated:` is more than
7 days behind today:

```bash
#!/usr/bin/env bash
set -euo pipefail
LEDGER=/Users/difan/Projects/trading-1/dev/notes/snapshot-corpus-status.md
last_updated=$(awk '/^Last updated:/ { print $3; exit }' "$LEDGER")
last_epoch=$(date -j -f "%Y-%m-%d" "$last_updated" "+%s" 2>/dev/null \
           || date -d "$last_updated" "+%s")  # BSD / GNU
days=$(( ($(date +%s) - last_epoch) / 86400 ))
if [ "$days" -gt 7 ]; then
  echo "ALERT: snapshot corpus has not refreshed in $days days (last: $last_updated)"
  # curl -X POST -H 'Content-type: application/json' \
  #      --data "{\"text\":\"Snapshot corpus stale ${days}d\"}" "$SLACK_WEBHOOK_URL"
fi
```

The webhook URL belongs in your shell rc, not in this repo (secrets
must not land under `dev/`).

**Alert recommendation.** Don't wire Slack by default. The ledger is
human-readable and the wrapper logs are date-stamped; weekly inspection
is enough for a single-operator workstation. Add the alert only after
periodic refresh has been running long enough that you've stopped
checking the ledger.

## 6. Disabling / rebuilding from scratch

**Disable launchd:**

```bash
launchctl unload ~/Library/LaunchAgents/com.dayfine.trading.snapshot-refresh.plist
rm ~/Library/LaunchAgents/com.dayfine.trading.snapshot-refresh.plist
```

**Disable cron:** `crontab -e`, delete the line, save.

**Full rebuild** (rare — schema hash changed or manifest corrupt; see
`dev/notes/snapshot-corpus-runbook-2026-05-03.md` §"When to fall back"
for criteria):

```bash
# 1. Stop scheduled runs
launchctl unload ~/Library/LaunchAgents/com.dayfine.trading.snapshot-refresh.plist
# 2. Wipe warehouse + manifest + lock
rm -rf /Users/difan/Projects/trading-1/dev/data/snapshots/broad-2014-2023
# 3. Run wrapper foreground with a generous --max-wall
bash /Users/difan/Projects/trading-1/dev/scripts/build_broad_snapshot_incremental.sh \
  --universe /Users/difan/Projects/trading-1/dev/data/universes/broad-2014-2023.sexp \
  --output-dir /Users/difan/Projects/trading-1/dev/data/snapshots/broad-2014-2023 \
  --csv-data-dir /Users/difan/Projects/trading-1/data \
  --max-wall 4h --progress-every 50
# 4. Re-arm the schedule
launchctl load ~/Library/LaunchAgents/com.dayfine.trading.snapshot-refresh.plist
```

Cold-cache rebuild is ~2h wall under the post-#792 writer.

## See also

- `dev/plans/data-pipeline-automation-2026-05-03.md` — track plan.
- `dev/notes/snapshot-corpus-runbook-2026-05-03.md` — manual-dispatch
  runbook (PR 3, #821).
- `dev/notes/snapshot-corpus-status.md` — ledger updated by every
  refresh dispatch (PR 3, #821).
- `.claude/agents/ops-data.md` §"Snapshot corpus refresh" — agent
  dispatch shape (PR 3, #821).
- `dev/scripts/build_broad_snapshot_incremental.sh` — wrapper this doc
  schedules (PR 1, #819).
- `dev/scripts/check_snapshot_freshness.sh` — probe used in §4 (PR 1,
  #819).
- `dev/notes/tier4-release-gate-checklist-2026-04-28.md` — explains why
  this is local-only.
