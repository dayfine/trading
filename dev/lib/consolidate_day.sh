#!/bin/sh
# consolidate_day.sh — merge all per-run daily summaries for a date into a
# single ${DATE}-summary.md file under dev/daily/.
#
# Usage: sh dev/lib/consolidate_day.sh YYYY-MM-DD
#
# Inputs:  dev/daily/${DATE}.md (run-1) and dev/daily/${DATE}-run*.md
#          Excludes *-plan.md and the output target itself.
# Output:  dev/daily/${DATE}-summary.md (overwritten on re-run — idempotent)
# Exit 0 on success; exit 1 with FAIL: message on bad args or no inputs.
#
# Section extraction helpers warn to stderr and continue on malformed input.
# POSIX sh — no bash-isms.

set -eu

# ── arg check ────────────────────────────────────────────────────────────────
DATE="${1:-}"
if [ -z "$DATE" ]; then
  echo "FAIL: consolidate_day.sh — missing required argument DATE (YYYY-MM-DD)" >&2
  exit 1
fi
# POSIX-safe date format check (grep -E is widely available but use -E explicitly)
if ! echo "$DATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  echo "FAIL: consolidate_day.sh — malformed DATE argument (expected YYYY-MM-DD, got: $DATE)" >&2
  exit 1
fi

# ── locate daily dir ─────────────────────────────────────────────────────────
# If CONSOLIDATE_DAY_DIR is set (tests use this), use it directly.
# Otherwise walk up from the script's directory to find the .git root.
if [ -n "${CONSOLIDATE_DAY_DIR:-}" ]; then
  DAILY_DIR="$CONSOLIDATE_DAY_DIR"
else
  _dir="$(cd "$(dirname "$0")" && pwd)"
  while [ "$_dir" != "/" ] && [ ! -d "$_dir/.git" ]; do
    _dir="$(dirname "$_dir")"
  done
  if [ ! -d "$_dir/.git" ]; then
    echo "FAIL: consolidate_day.sh — could not locate .git root from $(dirname "$0")" >&2
    exit 1
  fi
  DAILY_DIR="$_dir/dev/daily"
fi

OUTPUT="${DAILY_DIR}/${DATE}-summary.md"
OUTPUT_BASENAME="$(basename "$OUTPUT")"

# ── enumerate input files in chronological order ─────────────────────────────
# run-1 = ${DATE}.md, then -run2, -run3, ... by numeric suffix.
# Enumerate into a newline-delimited temp file to avoid word-splitting issues.
TMP_INPUTS="$(mktemp)"
if [ -f "${DAILY_DIR}/${DATE}.md" ]; then
  echo "${DAILY_DIR}/${DATE}.md" >> "$TMP_INPUTS"
fi
# run-N files — sort -V sorts version-style (numeric suffix order).
# grep -v guards against -plan.md and the output file itself.
for f in "${DAILY_DIR}/${DATE}-run"*.md; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in
    *-plan.md)          continue ;;
    "$OUTPUT_BASENAME") continue ;;
  esac
  echo "$f"
done | sort -V >> "$TMP_INPUTS"

# Count inputs
INPUT_COUNT=0
while IFS= read -r _line; do
  INPUT_COUNT=$((INPUT_COUNT + 1))
done < "$TMP_INPUTS"

if [ "$INPUT_COUNT" -eq 0 ]; then
  rm -f "$TMP_INPUTS"
  echo "FAIL: consolidate_day.sh — no input files found for date $DATE in $DAILY_DIR" >&2
  exit 1
fi

# ── helper: extract_section FILE HEADING ─────────────────────────────────────
# Prints the body of a section from "## HEADING" to the next "## " (exclusive).
# Warns to stderr and prints nothing if section is absent.
extract_section() {
  _es_file="$1"
  _es_heading="$2"
  _es_result="$(awk -v h="$_es_heading" '
    /^## / { if (found) { exit } if ($0 == h) { found=1; next } }
    found  { print }
  ' "$_es_file")"
  if [ -z "$_es_result" ]; then
    echo "WARN: $_es_file: section '$_es_heading' not found or empty" >&2
  fi
  printf '%s\n' "$_es_result"
}

# ── helper: run_label FILEPATH → "run-N" ─────────────────────────────────────
run_label() {
  _rl_base="$(basename "$1" .md)"
  # If basename ends in -runN, extract N; otherwise this is run-1.
  case "$_rl_base" in
    *-run[0-9]*)
      _rl_n="${_rl_base##*-run}"
      echo "run-${_rl_n}"
      ;;
    *)
      echo "run-1"
      ;;
  esac
}

# ── build run inventory ───────────────────────────────────────────────────────
TMP_LABELS="$(mktemp)"
LAST_FILE=""
N=0
while IFS= read -r f; do
  lbl="$(run_label "$f")"
  echo "$lbl" >> "$TMP_LABELS"
  LAST_FILE="$f"
  N=$((N + 1))
done < "$TMP_INPUTS"

# comma-separated run list for header line
RUNS_DISPLAY="$(tr '\n' ',' < "$TMP_LABELS" | sed 's/,$//' | sed 's/,/, /g')"
rm -f "$TMP_LABELS"

GENERATED="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u)"

# ── section 1: Pending work — from last run ───────────────────────────────────
PENDING="$(extract_section "$LAST_FILE" "## Pending work")"

# ── section 2: Dispatched — deduped union ────────────────────────────────────
# Strategy: tag every dispatch row with its run label, then use awk to dedup
# on (Track, Agent, Outcome). When (Track, Agent) appears with conflicting
# Outcomes in different runs, emit both rows with (run-N) appended to Notes.

TMP_DISPATCHED="$(mktemp)"
while IFS= read -r f; do
  lbl="$(run_label "$f")"
  awk -v h="## Dispatched this run" -v lbl="$lbl" '
    /^## / { if (found) { exit } if ($0 == h) { found=1; next } }
    found && /^\|/ && !/^\|[[:space:]]*Track[[:space:]]*\|/ && !/^\|[-|]+\|/ {
      print lbl"\t"$0
    }
  ' "$f"
done < "$TMP_INPUTS" > "$TMP_DISPATCHED"

DISPATCHED_ROWS="$(awk -F'\t' '
{
  run = $1
  row = $2
  # Parse pipe-delimited row: | Track | Agent | Outcome | Notes |
  n = split(row, fields, "|")
  if (n < 5) next
  track   = fields[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", track)
  agent   = fields[3]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", agent)
  outcome = fields[4]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", outcome)
  notes   = fields[5]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", notes)

  key_full = track "|" agent "|" outcome
  key_ta   = track "|" agent

  if (key_full in seen) next   # identical row — skip
  seen[key_full] = 1

  if (key_ta in ta_seen) {
    # Same (Track, Agent) appeared before with a different outcome.
    # Suffix this row Notes with its run label.
    if (notes == "") { notes = "(" run ")" } else { notes = notes " (" run ")" }
    needs_suffix[key_ta] = 1
    ta_run[key_ta] = ta_run[key_ta] "," run
  } else {
    ta_seen[key_ta]  = outcome
    ta_run[key_ta]   = run
  }

  order[++count] = key_full
  row_track[key_full]   = track
  row_agent[key_full]   = agent
  row_outcome[key_full] = outcome
  row_notes[key_full]   = notes
  row_run[key_full]     = run
  row_ta[key_full]      = key_ta
}
END {
  for (i = 1; i <= count; i++) {
    k     = order[i]
    ta    = row_ta[k]
    notes = row_notes[k]
    # Also suffix the first occurrence if its sibling got a suffix
    if (ta in needs_suffix) {
      if (notes !~ /[(]run-/) {
        if (notes == "") { notes = "(" row_run[k] ")" } else { notes = notes " (" row_run[k] ")" }
      }
    }
    printf "| %s | %s | %s | %s |\n",
      row_track[k], row_agent[k], row_outcome[k], notes
  }
}
' "$TMP_DISPATCHED")"
rm -f "$TMP_DISPATCHED"

# ── section 3: QC Status — latest per track ─────────────────────────────────
TMP_QC="$(mktemp)"
while IFS= read -r f; do
  awk -v h="## QC Status" '
    /^## / { if (found) { exit } if ($0 == h) { found=1; next } }
    found && /^-/ { print }
  ' "$f"
done < "$TMP_INPUTS" > "$TMP_QC"

QC_ROWS="$(awk '
{
  # Key = text before the first colon on the line (POSIX awk compatible)
  line = $0
  key = line
  sub(/^- /, "", key)
  # Everything before the first colon
  if (index(key, ":") > 0) {
    key = substr(key, 1, index(key, ":") - 1)
  }
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
  if (key == "") { key = $0 }
  if (!(key in seen)) { seen[key] = 1; order[++count] = key }
  rows[key] = $0
}
END {
  for (i = 1; i <= count; i++) {
    print rows[order[i]]
  }
}
' "$TMP_QC")"
rm -f "$TMP_QC"

# ── section 4: Budget — sum across runs ──────────────────────────────────────
TOTAL_SUBAGENTS=0
TOTAL_COST_NOTES=""
KILLED_EVENTS=""

while IFS= read -r f; do
  lbl="$(run_label "$f")"
  # extract_section may warn to stderr — that's fine, we handle empty gracefully
  BUDGET_SECTION="$(extract_section "$f" "## Budget" 2>/dev/null)" || true
  if [ -z "$BUDGET_SECTION" ]; then
    TOTAL_COST_NOTES="${TOTAL_COST_NOTES}
- Budget not parseable from $lbl (section missing)"
    continue
  fi
  spawned="$(printf '%s\n' "$BUDGET_SECTION" \
    | grep -i 'subagents spawned' | grep -oE '[0-9]+' | head -1)" || true
  if [ -n "$spawned" ]; then
    TOTAL_SUBAGENTS=$((TOTAL_SUBAGENTS + spawned))
  fi
  util="$(printf '%s\n' "$BUDGET_SECTION" \
    | grep -i 'Budget utilization:' | head -1)" || true
  if [ -n "$util" ]; then
    TOTAL_COST_NOTES="${TOTAL_COST_NOTES}
- $lbl: $util"
  fi
  killed="$(printf '%s\n' "$BUDGET_SECTION" \
    | grep -i 'killed mid-flight' | head -1)" || true
  if printf '%s\n' "$killed" | grep -qi 'yes'; then
    KILLED_EVENTS="${KILLED_EVENTS}
- $lbl: $killed"
  fi
done < "$TMP_INPUTS"

# Strip leading newlines from accumulated strings
TOTAL_COST_NOTES="$(printf '%s' "$TOTAL_COST_NOTES" | sed '1{/^$/d}')"
KILLED_EVENTS="$(printf '%s' "$KILLED_EVENTS" | sed '1{/^$/d}')"
[ -z "$KILLED_EVENTS" ] && KILLED_EVENTS="None reported across all runs."

# ── section 5: Escalations — deduped union ───────────────────────────────────
TMP_ESC="$(mktemp)"
while IFS= read -r f; do
  lbl="$(run_label "$f")"
  awk -v h="## Escalations" -v lbl="$lbl" '
    /^## / { if (found) { exit } if ($0 == h) { found=1; next } }
    found && /^[0-9]+\. |^- / { print lbl"\t"$0 }
  ' "$f"
done < "$TMP_INPUTS" > "$TMP_ESC"

ESC_ITEMS="$(awk -F'\t' '
{
  run  = $1
  line = $2
  # Strip leading markers and severity tags for the dedup key
  key = line
  sub(/^[0-9]+\. /,    "", key)
  sub(/^- /,           "", key)
  sub(/^\*\*\[.*\]\*\* /, "", key)
  sub(/^\[.*\] /,      "", key)
  short_key = substr(key, 1, 60)

  if (short_key in seen) {
    seen_runs[short_key] = seen_runs[short_key] "," run
  } else {
    seen[short_key]      = run
    seen_runs[short_key] = run
    order[++count]       = short_key
    full_line[short_key] = line
  }
}
END {
  for (i = 1; i <= count; i++) {
    k    = order[i]
    line = full_line[k]
    runs = seen_runs[k]
    n    = split(runs, r, ",")
    if (n > 1) {
      sub(/\.$/, "", line)
      line = line " (seen in: " runs ")"
    }
    print line
  }
}
' "$TMP_ESC")"
rm -f "$TMP_ESC"

# ── section 6: Integration Queue — from last run ─────────────────────────────
INT_QUEUE="$(extract_section "$LAST_FILE" "## Integration Queue")"

# ── section 7: Per-run links ─────────────────────────────────────────────────
TMP_LINKS="$(mktemp)"
while IFS= read -r f; do
  lbl="$(run_label "$f")"
  fname="$(basename "$f")"
  echo "- $lbl -> \`$fname\`"
done < "$TMP_INPUTS" > "$TMP_LINKS"

# ── write output ─────────────────────────────────────────────────────────────
{
  echo "# Consolidated Summary — ${DATE}"
  echo "Runs included: ${RUNS_DISPLAY} (${N} total)"
  echo "Generated: ${GENERATED}"
  echo ""
  echo "## Pending work (from last run)"
  if [ -n "$PENDING" ]; then
    printf '%s\n' "$PENDING"
  else
    echo "(section not found in last run)"
  fi
  echo ""
  echo "## Dispatched across all runs (deduped)"
  echo "| Track | Agent | Outcome | Notes |"
  echo "|-------|-------|---------|-------|"
  if [ -n "$DISPATCHED_ROWS" ]; then
    printf '%s\n' "$DISPATCHED_ROWS"
  else
    echo "| — | — | — | No dispatched rows found |"
  fi
  echo ""
  echo "## QC across all runs"
  if [ -n "$QC_ROWS" ]; then
    printf '%s\n' "$QC_ROWS"
  else
    echo "(no QC entries found)"
  fi
  echo ""
  echo "## Budget (summed across runs)"
  echo "- Total subagents spawned: ${TOTAL_SUBAGENTS}"
  if [ -n "$TOTAL_COST_NOTES" ]; then
    printf '%s\n' "$TOTAL_COST_NOTES"
  fi
  echo "- Killed mid-flight: ${KILLED_EVENTS}"
  echo ""
  echo "## Escalations (merged)"
  if [ -n "$ESC_ITEMS" ]; then
    printf '%s\n' "$ESC_ITEMS"
  else
    echo "(no escalation items found)"
  fi
  echo ""
  echo "## Integration Queue (last run's view)"
  if [ -n "$INT_QUEUE" ]; then
    printf '%s\n' "$INT_QUEUE"
  else
    echo "(no Integration Queue section in last run)"
  fi
  echo ""
  echo "## Per-run links"
  cat "$TMP_LINKS"
} > "$OUTPUT"

rm -f "$TMP_INPUTS" "$TMP_LINKS"
echo "OK: consolidated summary written to $OUTPUT (${N} runs)"
