#!/bin/sh
# Check 8: Trends — followup-item count delta + CC distribution delta (T3-G).
#
# Usage: sh check_08_trends.sh <report_file> [findings_file]
#
# Two sub-sections:
#   8a. Followup count per status file — now vs second-most-recent deep scan.
#   8b. CC (cyclomatic complexity) distribution — now vs previous cc-*.json.
#       Buckets: 1-5 / 6-10 / >10. Plus top-5 highest-CC functions today.
#
# Dependency on Check 5: reads FOLLOWUP_PER_FILE data from the sidecar file
# at <findings_file>.followup (orchestrated mode) or <report_file>.followup
# (standalone mode). Check 5 must run before Check 8.
#
# Degrades gracefully when no baseline exists ("no baseline").
# CC JSON generation requires the cc_linter binary to be built; if not
# found, the CC sub-section reports "cc_linter binary not available".

set -e

REPORT_FILE="${1:?Usage: check_08_trends.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 8: Trends
# ────────────────────────────────────────────────────────────────

TRENDS_CONTENT=""

# Read FOLLOWUP_PER_FILE from the sidecar written by Check 5.
FOLLOWUP_SIDECAR="${FINDINGS_FILE:-"$REPORT_FILE"}.followup"
FOLLOWUP_PER_FILE=""
if [ -f "$FOLLOWUP_SIDECAR" ]; then
  FOLLOWUP_PER_FILE="$(cat "$FOLLOWUP_SIDECAR")"
fi

# ── 8a: Followup count delta ──────────────────────────────────────

# Find the second-most-recent *-deep.md (today's is already written to OUTPUT_FILE
# but hasn't been flushed yet — safe to glob all existing ones).
PREV_DEEP=""
# List all deep scan files sorted by name (date-based names sort chronologically),
# exclude today's (which may or may not exist yet).
for f in $(ls -1 "${OUTPUT_DIR}"/*-deep.md 2>/dev/null | sort); do
  case "$(basename "$f")" in
    "${TODAY}-deep.md") continue ;;
  esac
  PREV_DEEP="$f"
done
# PREV_DEEP is now the most-recent file that is NOT today's.

TRENDS_CONTENT="${TRENDS_CONTENT}### Followup items — now vs previous deep scan\n\n"

if [ -z "$PREV_DEEP" ]; then
  TRENDS_CONTENT="${TRENDS_CONTENT}No baseline (first deep scan). Current counts:\n\n"
  if [ -n "$FOLLOWUP_PER_FILE" ]; then
    TABLE=""
    while IFS=: read -r fname cnt; do
      [ -z "$fname" ] && continue
      TABLE="${TABLE}| \`${fname}\` | ${cnt} |\n"
    done << PFEOF
$(printf '%s' "$FOLLOWUP_PER_FILE")
PFEOF
    TRENDS_CONTENT="${TRENDS_CONTENT}| File | Count |\n|---|---|\n${TABLE}\n"
  else
    TRENDS_CONTENT="${TRENDS_CONTENT}No open followup items found.\n\n"
  fi
else
  prev_date="$(basename "$PREV_DEEP" -deep.md)"
  TRENDS_CONTENT="${TRENDS_CONTENT}Baseline: \`$(basename "$PREV_DEEP")\`\n\n"

  # Build today's per-file map from FOLLOWUP_PER_FILE
  # Extract per-file counts from the previous deep scan's
  # "## Followup Count Detail" section (written by Check 8 itself on that run).
  # Format in that section: "| \`*.md\` | prev_count | ..."
  # We parse lines matching "| \`*.md\` | <number>"

  TABLE=""
  while IFS=: read -r fname today_cnt; do
    [ -z "$fname" ] && continue
    # Look for this file in the previous report's Followup Count Detail table
    prev_cnt=""
    if grep -q "| \`${fname}\`" "$PREV_DEEP" 2>/dev/null; then
      prev_cnt="$(grep "| \`${fname}\`" "$PREV_DEEP" 2>/dev/null | head -1 \
        | awk -F'|' '{gsub(/ /,"",$3); print $3}' 2>/dev/null || true)"
    fi
    if [ -z "$prev_cnt" ]; then
      delta="(new)"
      delta_sign=""
    else
      # Compute delta
      delta=$((today_cnt - prev_cnt))
      if [ "$delta" -gt 0 ]; then
        delta_sign="+${delta}"
      elif [ "$delta" -lt 0 ]; then
        delta_sign="${delta}"
      else
        delta_sign="0"
      fi
      delta="$delta_sign"
    fi
    TABLE="${TABLE}| \`${fname}\` | ${today_cnt} | ${prev_cnt:-—} | ${delta} |\n"
  done << PFEOF
$(printf '%s' "$FOLLOWUP_PER_FILE")
PFEOF

  # Also surface files that appeared in prev but not today (all cleared)
  if [ -f "$PREV_DEEP" ] && grep -q "| \`.*\.md\`" "$PREV_DEEP" 2>/dev/null; then
    while IFS= read -r prev_line; do
      fname_raw="$(echo "$prev_line" | grep -o '\`[^|]*\.md\`' | tr -d '\`' | head -1)"
      [ -z "$fname_raw" ] && continue
      # Skip if we already processed it
      if printf '%s' "$FOLLOWUP_PER_FILE" | grep -q "^${fname_raw}:"; then
        continue
      fi
      prev_cnt="$(echo "$prev_line" | awk -F'|' '{gsub(/ /,"",$3); print $3}' 2>/dev/null || true)"
      if [ -n "$prev_cnt" ] && [ "$prev_cnt" -gt 0 ] 2>/dev/null; then
        delta="-${prev_cnt}"
        TABLE="${TABLE}| \`${fname_raw}\` | 0 | ${prev_cnt} | ${delta} |\n"
      fi
    done << PTEOF
$(grep "| \`.*\.md\`" "$PREV_DEEP" 2>/dev/null || true)
PTEOF
  fi

  if [ -n "$TABLE" ]; then
    TRENDS_CONTENT="${TRENDS_CONTENT}| File | Today | Prev (${prev_date}) | Delta |\n|---|---|---|---|\n${TABLE}\n"
  else
    TRENDS_CONTENT="${TRENDS_CONTENT}No open followup items in either scan.\n\n"
  fi
fi

# ── 8b: CC distribution delta ────────────────────────────────────

TRENDS_CONTENT="${TRENDS_CONTENT}### CC distribution — now vs previous snapshot\n\n"

METRICS_DIR="${REPO_ROOT}/dev/metrics"
mkdir -p "$METRICS_DIR"

# Find cc_linter binary (built by dune under trading/_build)
CC_LINTER_BIN=""
for candidate in \
    "${TRADING_DIR}/_build/default/devtools/cc_linter/cc_linter.exe" \
    "${TRADING_DIR}/_build/install/default/bin/cc_linter"; do
  if [ -f "$candidate" ] && [ -x "$candidate" ]; then
    CC_LINTER_BIN="$candidate"
    break
  fi
done

if [ -z "$CC_LINTER_BIN" ]; then
  TRENDS_CONTENT="${TRENDS_CONTENT}cc_linter binary not available — run \`dune build\` first.\n\n"
else
  # Single rolling snapshot cc-latest.json (version-controlled; overwritten
  # each run). Previous state comes from git HEAD so we don't accumulate
  # one JSON per run in-tree.
  TODAY_CC_JSON="${METRICS_DIR}/cc-latest.json"
  PREV_CC_JSON="$(mktemp -t cc-prev-XXXXXX.json)"
  trap 'rm -f "$PREV_CC_JSON"' EXIT
  if ! git -C "$REPO_ROOT" show "HEAD:dev/metrics/cc-latest.json" >"$PREV_CC_JSON" 2>/dev/null; then
    PREV_CC_JSON=""
  fi
  "$CC_LINTER_BIN" "$TRADING_DIR" "$TODAY_CC_JSON" >/dev/null 2>&1 || true

  if [ ! -f "$TODAY_CC_JSON" ]; then
    TRENDS_CONTENT="${TRENDS_CONTENT}cc_linter failed to write JSON output.\n\n"
  else

    # Compute bucket distribution from a JSON file using python3.
    # Outputs three numbers on one line: "low mid high" where
    #   low  = CC 1-5, mid = CC 6-10, high = CC >10
    _cc_buckets() {
      json_file="$1"
      python3 - "$json_file" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
fns = data.get("functions", [])
low = sum(1 for x in fns if 1 <= x["cc"] <= 5)
mid = sum(1 for x in fns if 6 <= x["cc"] <= 10)
high = sum(1 for x in fns if x["cc"] > 10)
print(low, mid, high)
PYEOF
    }

    # Top-5 highest-CC functions from today's JSON
    _cc_top5() {
      json_file="$1"
      python3 - "$json_file" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
fns = sorted(data.get("functions", []), key=lambda x: -x["cc"])[:5]
for fn in fns:
    print(fn["cc"], fn["file"] + ":" + str(fn["line"]), fn["name"])
PYEOF
    }

    today_buckets="$(_cc_buckets "$TODAY_CC_JSON" 2>/dev/null || echo "? ? ?")"
    today_low="$(echo "$today_buckets" | awk '{print $1}')"
    today_mid="$(echo "$today_buckets" | awk '{print $2}')"
    today_high="$(echo "$today_buckets" | awk '{print $3}')"

    if [ -n "$PREV_CC_JSON" ]; then
      prev_date_cc="$(git -C "$REPO_ROOT" log -1 --format='%h' -- dev/metrics/cc-latest.json 2>/dev/null || echo 'HEAD')"
      prev_buckets="$(_cc_buckets "$PREV_CC_JSON" 2>/dev/null || echo "? ? ?")"
      prev_low="$(echo "$prev_buckets" | awk '{print $1}')"
      prev_mid="$(echo "$prev_buckets" | awk '{print $2}')"
      prev_high="$(echo "$prev_buckets" | awk '{print $3}')"

      # Compute deltas (skip if values are "?")
      _delta() {
        a="$1"; b="$2"
        if [ "$a" = "?" ] || [ "$b" = "?" ]; then echo "?"; return; fi
        d=$((a - b))
        if [ "$d" -gt 0 ]; then echo "+${d}"
        elif [ "$d" -lt 0 ]; then echo "${d}"
        else echo "0"; fi
      }

      d_low="$(_delta "$today_low" "$prev_low")"
      d_mid="$(_delta "$today_mid" "$prev_mid")"
      d_high="$(_delta "$today_high" "$prev_high")"

      TRENDS_CONTENT="${TRENDS_CONTENT}| CC range | Today | Prev (${prev_date_cc}) | Delta |\n|---|---|---|---|\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| 1–5 (low) | ${today_low} | ${prev_low} | ${d_low} |\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| 6–10 (medium) | ${today_mid} | ${prev_mid} | ${d_mid} |\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| >10 (high) | ${today_high} | ${prev_high} | ${d_high} |\n\n"
    else
      TRENDS_CONTENT="${TRENDS_CONTENT}No baseline CC snapshot (first run). Current distribution:\n\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| CC range | Count |\n|---|---|\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| 1–5 (low) | ${today_low} |\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| 6–10 (medium) | ${today_mid} |\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| >10 (high) | ${today_high} |\n\n"
    fi

    # Top-5 highest-CC functions
    top5="$(_cc_top5 "$TODAY_CC_JSON" 2>/dev/null || true)"
    if [ -n "$top5" ]; then
      TRENDS_CONTENT="${TRENDS_CONTENT}**Top-5 highest-CC functions today:**\n\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| CC | Location | Function |\n|---|---|---|\n"
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        cc_val="$(echo "$line" | awk '{print $1}')"
        loc="$(echo "$line" | awk '{print $2}')"
        fname_fn="$(echo "$line" | awk '{$1=$2=""; print substr($0,3)}')"
        TRENDS_CONTENT="${TRENDS_CONTENT}| ${cc_val} | \`${loc}\` | \`${fname_fn}\` |\n"
      done << TOP5EOF
${top5}
TOP5EOF
      TRENDS_CONTENT="${TRENDS_CONTENT}\n"
    fi

    TRENDS_CONTENT="${TRENDS_CONTENT}CC JSON written to: \`$(basename "$TODAY_CC_JSON")\`\n"
  fi
fi

flush_findings

# Always emit the Trends section.
printf "\n## Trends\n\n" >> "$REPORT_FILE"
printf '%b' "$TRENDS_CONTENT" >> "$REPORT_FILE"

# Emit per-file followup count detail for future scans to diff against.
# The table rows use format "| `file.md` | count |" so Check 8's grep
# can extract them from the previous deep scan report.
if [ -n "$FOLLOWUP_PER_FILE" ]; then
  {
    printf "\n## Followup Count Detail\n\n"
    printf "| File | Count |\n|---|---|\n"
    while IFS=: read -r fname cnt; do
      [ -z "$fname" ] && continue
      printf "| \`%s\` | %s |\n" "$fname" "$cnt"
    done << DETEOF
$(printf '%s' "$FOLLOWUP_PER_FILE")
DETEOF
  } >> "$REPORT_FILE"
fi
