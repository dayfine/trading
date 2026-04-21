#!/usr/bin/env bash
# budget_rollup.sh DATE_RANGE
#
# Reads dev/budget/*.json for the given date range and emits a markdown table
# broken down by: run_id, model, total_cost_usd, cache hit rate.
#
# Usage:
#   dev/lib/budget_rollup.sh 2026-04-01 2026-04-30   # range (inclusive)
#   dev/lib/budget_rollup.sh 2026-04-20               # single date
#   dev/lib/budget_rollup.sh                           # all records
#
# Exit codes:
#   0 — success (zero records is not an error; table is emitted empty)
#   1 — argument error

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BUDGET_DIR="${REPO_ROOT}/dev/budget"

# --- Argument parsing ---

START_DATE=""
END_DATE=""

if [ "$#" -eq 0 ]; then
  START_DATE="0000-00-00"
  END_DATE="9999-99-99"
elif [ "$#" -eq 1 ]; then
  START_DATE="$1"
  END_DATE="$1"
elif [ "$#" -eq 2 ]; then
  START_DATE="$1"
  END_DATE="$2"
else
  echo "Usage: $0 [START_DATE [END_DATE]]" >&2
  exit 1
fi

# Basic YYYY-MM-DD validation (not exhaustive)
_validate_date() {
  local d="$1"
  if [ "$d" = "0000-00-00" ] || [ "$d" = "9999-99-99" ]; then return 0; fi
  if ! printf '%s' "$d" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    echo "ERROR: invalid date '$d' — expected YYYY-MM-DD" >&2
    exit 1
  fi
}
_validate_date "$START_DATE"
_validate_date "$END_DATE"

# --- Collect matching files ---

if [ ! -d "$BUDGET_DIR" ]; then
  echo "No budget records found (${BUDGET_DIR} does not exist)."
  exit 0
fi

MATCHED_FILES=()
for f in "${BUDGET_DIR}"/*.json; do
  [ -f "$f" ] || continue
  BASENAME="$(basename "$f" .json)"
  # Filenames are <YYYY-MM-DD>-run<N>; extract the date portion
  FILE_DATE="${BASENAME%-run*}"
  if [[ "$FILE_DATE" < "$START_DATE" ]] || [[ "$FILE_DATE" > "$END_DATE" ]]; then
    continue
  fi
  MATCHED_FILES+=("$f")
done

if [ "${#MATCHED_FILES[@]}" -eq 0 ]; then
  echo "No budget records found for range ${START_DATE} to ${END_DATE}."
  exit 0
fi

# --- Parse and emit markdown table ---

python3 - "${MATCHED_FILES[@]}" <<'PYEOF'
import json
import sys
import os

files = sys.argv[1:]
rows = []

for f in sorted(files):
    try:
        with open(f) as fh:
            data = json.load(fh)
    except Exception as e:
        print(f"WARNING: skipping {f}: {e}", file=sys.stderr)
        continue

    run_id = data.get("run_id", os.path.basename(f).replace(".json", ""))
    timestamp = data.get("timestamp", "—")
    commit_sha = data.get("commit_sha", "—")[:8]
    totals = data.get("totals", {})
    total_cost = totals.get("total_cost_usd")
    cost_str = f"${total_cost:.4f}" if isinstance(total_cost, (int, float)) else "—"

    # Cache hit rate: cache_read / (input + cache_read) — only if token counts available
    inp = totals.get("input_tokens")
    cache_r = totals.get("cache_read_input_tokens")
    if isinstance(inp, (int, float)) and isinstance(cache_r, (int, float)) and (inp + cache_r) > 0:
        cache_hit_rate = f"{100.0 * cache_r / (inp + cache_r):.1f}%"
    else:
        cache_hit_rate = "—"

    subagents = data.get("subagents", [])
    models = list({s.get("model", "—") for s in subagents if s.get("model")})
    model_str = ", ".join(sorted(models)) if models else "—"

    rows.append((run_id, timestamp[:10], model_str, cost_str, cache_hit_rate, commit_sha))

if not rows:
    print("No valid budget records found.")
    sys.exit(0)

# Totals row
total_costs = []
for f in sorted(files):
    try:
        with open(f) as fh:
            data = json.load(fh)
        c = data.get("totals", {}).get("total_cost_usd")
        if isinstance(c, (int, float)):
            total_costs.append(c)
    except Exception:
        pass

total_str = f"${sum(total_costs):.4f}" if total_costs else "—"

print(f"## Budget rollup — {sys.argv[1].split('/')[-1].replace('.json','')} to {sys.argv[-1].split('/')[-1].replace('.json','')}")
print()
print(f"Runs: {len(rows)} | Period: {rows[0][1]} to {rows[-1][1]}")
print()
print("| Run ID | Date | Models | Total cost | Cache hit rate | Commit |")
print("|--------|------|--------|------------|---------------|--------|")
for run_id, date, model, cost, cache, sha in rows:
    print(f"| {run_id} | {date} | {model} | {cost} | {cache} | {sha} |")
print(f"| **TOTAL** | | | **{total_str}** | | |")
print()
print(f"> Prices from `dev/config/merge-policy.json` model_prices block.")
print(f"> Per-subagent breakdown not available (fallback 1b); totals are measured from")
print(f"> claude-code-action execution_file. See dev/status/cost-tracking.md.")
PYEOF
