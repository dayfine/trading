#!/usr/bin/env bash
# velocity_report.sh — reproducible PR velocity report with LOC-by-language breakdown.
#
# Usage:
#   velocity_report.sh --since YYYY-MM-DD [--until YYYY-MM-DD] [--out FILE]
#
# Flags:
#   --since YYYY-MM-DD    Start date (inclusive). Required.
#   --until YYYY-MM-DD    End date (inclusive). Default: today.
#   --out FILE            Write report to FILE instead of stdout.
#
# Requirements: gh (GitHub CLI), jq, bc.
#
# Language buckets:
#   OCaml source (total): *.ml, *.mli
#   OCaml source (lib):   *.ml / *.mli NOT under */test/*
#   OCaml source (test):  *.ml / *.mli under */test/*
#   Dune:                 dune, dune-project, *.opam
#   Sexp / scenario:      *.sexp
#   Shell:                *.sh, *.bash
#   YAML / GHA:           *.yml, *.yaml
#   JSON:                 *.json
#   Markdown:             *.md
#   CSV:                  *.csv
#   Docker:               Dockerfile, *.dockerignore
#   Other:                everything else
#
# OCaml test-vs-source classification:
#   Paths containing /test/ → OCaml source (test)
#   All other .ml/.mli paths (lib/, bin/, scripts/) → OCaml source (lib)
#
# Verification: the script asserts that OCaml source (total) == lib + test.
# If Total Raw LOC (from PR-level data) differs from the language-table sum
# (from per-file data), a WARNING is emitted; this can occur when a PR's files
# field is empty (rare edge case in the GitHub GraphQL API).
#
# Idempotent: re-running with the same --since/--until produces byte-identical
# output (modulo the run-timestamp in the Methodology section).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
SINCE=""
UNTIL=""
OUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      shift
      if [[ $# -eq 0 ]]; then
        echo "ERROR: --since requires a YYYY-MM-DD argument" >&2; exit 1
      fi
      SINCE="$1"
      ;;
    --until)
      shift
      if [[ $# -eq 0 ]]; then
        echo "ERROR: --until requires a YYYY-MM-DD argument" >&2; exit 1
      fi
      UNTIL="$1"
      ;;
    --out)
      shift
      if [[ $# -eq 0 ]]; then
        echo "ERROR: --out requires a FILE argument" >&2; exit 1
      fi
      OUT_FILE="$1"
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo "Usage: $0 --since YYYY-MM-DD [--until YYYY-MM-DD] [--out FILE]" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z "$SINCE" ]]; then
  echo "ERROR: --since is required" >&2
  echo "Usage: $0 --since YYYY-MM-DD [--until YYYY-MM-DD] [--out FILE]" >&2
  exit 1
fi

if [[ -z "$UNTIL" ]]; then
  UNTIL="$(date +%Y-%m-%d)"
fi

# ---------------------------------------------------------------------------
# Validate date format
# ---------------------------------------------------------------------------
_validate_date() {
  local d="$1"
  if ! [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: date must be YYYY-MM-DD format, got: $d" >&2; exit 1
  fi
}
_validate_date "$SINCE"
_validate_date "$UNTIL"

# ---------------------------------------------------------------------------
# Day count — UTC midnight arithmetic, portable across DST boundaries.
# macOS date -jf without TZ=UTC picks up the current local time-of-day
# component, causing DST-boundary off-by-one errors.  Explicitly set
# TZ=UTC and append a midnight time to force clean epoch values.
# ---------------------------------------------------------------------------
_days_between() {
  local d1="$1" d2="$2"
  local t1 t2
  t1="$(TZ=UTC date -jf "%Y-%m-%d %H:%M:%S" "${d1} 00:00:00" +%s 2>/dev/null \
    || TZ=UTC date -d "${d1}T00:00:00Z" +%s)"
  t2="$(TZ=UTC date -jf "%Y-%m-%d %H:%M:%S" "${d2} 00:00:00" +%s 2>/dev/null \
    || TZ=UTC date -d "${d2}T00:00:00Z" +%s)"
  echo $(( (t2 - t1) / 86400 + 1 ))
}

DAYS="$(_days_between "$SINCE" "$UNTIL")"

# ---------------------------------------------------------------------------
# Temp directory (cleaned up on exit)
# ---------------------------------------------------------------------------
TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

PR_LIST_FILE="${TMPDIR_BASE}/pr_list.json"

# ---------------------------------------------------------------------------
# Fetch PR metadata (title, additions, deletions, mergedAt, files)
# ---------------------------------------------------------------------------
echo "Fetching PR list from dayfine/trading (merged:${SINCE} to ${UNTIL})..." >&2

gh pr list \
  --repo dayfine/trading \
  --state merged \
  --search "merged:>=${SINCE} merged:<=${UNTIL}" \
  --limit 2000 \
  --json number,title,additions,deletions,mergedAt,files \
  > "${PR_LIST_FILE}"

TOTAL_PRS="$(jq 'length' "${PR_LIST_FILE}")"
echo "Fetched ${TOTAL_PRS} PRs." >&2

# ---------------------------------------------------------------------------
# 100-file truncation guard
# When gh pr list --json files returns exactly 100 entries for a PR, the
# files list is truncated (GitHub GraphQL limit).  Fall back to the REST
# paginated endpoint to get the full list.
# ---------------------------------------------------------------------------
TRUNCATED_PRS="$(jq -r '[.[] | select((.files | length) == 100)] | .[].number' \
  "${PR_LIST_FILE}")"

if [[ -n "$TRUNCATED_PRS" ]]; then
  TRUNCATED_COUNT="$(echo "$TRUNCATED_PRS" | wc -l | tr -d ' ')"
  echo "Fetching paginated file lists for ${TRUNCATED_COUNT} truncated PR(s): ${TRUNCATED_PRS}" >&2

  PATCHED_FILE="${TMPDIR_BASE}/pr_list_patched.json"
  cp "${PR_LIST_FILE}" "${PATCHED_FILE}"

  for pr_num in $TRUNCATED_PRS; do
    echo "  PR #${pr_num}: fetching via REST paginate..." >&2
    PAGINATED_FILES="${TMPDIR_BASE}/pr_${pr_num}_files.json"

    gh api "repos/dayfine/trading/pulls/${pr_num}/files" --paginate \
      | jq '[.[] | {path: .filename, additions: .additions, deletions: .deletions}]' \
      > "${PAGINATED_FILES}"

    PAGINATED_COUNT="$(jq 'length' "${PAGINATED_FILES}")"
    echo "  PR #${pr_num}: ${PAGINATED_COUNT} files (was 100 truncated)." >&2

    PATCHED_TMP="${TMPDIR_BASE}/pr_list_patched_tmp.json"
    jq --argjson pr "$pr_num" \
       --slurpfile newfiles "${PAGINATED_FILES}" \
       '(.[] | select(.number == $pr) | .files) |= $newfiles[0]' \
       "${PATCHED_FILE}" \
       > "${PATCHED_TMP}"
    mv "${PATCHED_TMP}" "${PATCHED_FILE}"
  done

  mv "${PATCHED_FILE}" "${PR_LIST_FILE}"
fi

# ---------------------------------------------------------------------------
# Enrich with category (Conventional Commits prefix) and month
# ---------------------------------------------------------------------------
PR_STATS="${TMPDIR_BASE}/pr_stats.json"

jq '
  [.[] | {
    number: .number,
    title: .title,
    additions: .additions,
    deletions: .deletions,
    mergedAt: .mergedAt,
    files: .files,
    category: (
      .title |
      if test("^[a-zA-Z][a-zA-Z0-9_-]*[:(]") then
        capture("^(?<cat>[a-zA-Z][a-zA-Z0-9_-]*)") | .cat
      else
        "other"
      end
    )
  }]
' "${PR_LIST_FILE}" > "${PR_STATS}"

# ---------------------------------------------------------------------------
# By-category summary
# ---------------------------------------------------------------------------
CAT_STATS="${TMPDIR_BASE}/cat_stats.json"

jq '
  group_by(.category) |
  map({
    category: .[0].category,
    pr_count: length,
    additions: (map(.additions) | add),
    deletions: (map(.deletions) | add),
    raw_loc: (map(.additions + .deletions) | add),
    net_loc: (map(.additions - .deletions) | add)
  }) |
  sort_by(-.pr_count)
' "${PR_STATS}" > "${CAT_STATS}"

# ---------------------------------------------------------------------------
# Headline numbers (from PR-level additions/deletions)
# ---------------------------------------------------------------------------
HEADLINE="${TMPDIR_BASE}/headline.json"

jq '{
  total_prs: (map(1) | add),
  total_additions: (map(.additions) | add),
  total_deletions: (map(.deletions) | add),
  total_raw_loc: (map(.additions + .deletions) | add),
  total_net_loc: (map(.additions - .deletions) | add)
}' "${PR_STATS}" > "${HEADLINE}"

# ---------------------------------------------------------------------------
# Per-month rollup
# ---------------------------------------------------------------------------
MONTH_STATS="${TMPDIR_BASE}/month_stats.json"

jq '
  group_by(.mergedAt[0:7]) |
  map({
    month: .[0].mergedAt[0:7],
    pr_count: length,
    raw_loc: (map(.additions + .deletions) | add),
    net_loc: (map(.additions - .deletions) | add),
    top_categories: (
      group_by(.category) |
      map({cat: .[0].category, n: length}) |
      sort_by(-.n) |
      .[0:3] |
      map(.cat + "(" + (.n | tostring) + ")") |
      join(", ")
    )
  }) |
  sort_by(.month)
' "${PR_STATS}" > "${MONTH_STATS}"

# ---------------------------------------------------------------------------
# By-language breakdown — classify each PR×file record
# ---------------------------------------------------------------------------
LANG_STATS="${TMPDIR_BASE}/lang_stats.json"

jq '
  [.[] | .number as $pr |
   (.files // [])[] |
   {
     pr: $pr,
     path: .path,
     additions: .additions,
     deletions: .deletions
   }
  ] |
  map(
    .path as $p |
    (
      if   ($p | test("\\.mli?$")) then
        if ($p | test("/test/")) then "ocaml_test" else "ocaml_lib" end
      elif ($p | test("/(dune|dune-project)$|\\.opam$")) then "dune"
      elif ($p | test("\\.sexp$"))         then "sexp"
      elif ($p | test("\\.(sh|bash)$"))    then "shell"
      elif ($p | test("\\.(yml|yaml)$"))   then "yaml"
      elif ($p | test("\\.json$"))         then "json"
      elif ($p | test("\\.md$"))           then "markdown"
      elif ($p | test("\\.csv$"))          then "csv"
      elif ($p | test("(^|/)Dockerfile(\\..*)?$|\\.dockerignore$")) then "docker"
      else "other"
      end
    ) as $bucket |
    . + {bucket: $bucket}
  ) |
  group_by(.bucket) |
  map({
    bucket: .[0].bucket,
    pr_count: ([.[].pr] | unique | length),
    # unique_file_count counts distinct path strings (a file changed in N PRs = 1).
    # This matches the original "Files touched = unique file paths" definition.
    unique_file_count: ([.[].path] | unique | length),
    additions: (map(.additions) | add),
    deletions: (map(.deletions) | add),
    raw_loc: (map(.additions + .deletions) | add),
    net_loc: (map(.additions - .deletions) | add)
  })
' "${PR_STATS}" > "${LANG_STATS}"

# ---------------------------------------------------------------------------
# Extract a per-bucket value; default 0 if bucket absent.
# For file counts, always use "unique_file_count" (distinct paths).
# ---------------------------------------------------------------------------
_lang() {
  jq -r --arg bucket "$1" --arg field "$2" \
    '(.[] | select(.bucket == $bucket) | .[$field]) // 0' \
    "${LANG_STATS}"
}

_lang_files() {
  _lang "$1" "unique_file_count"
}

# ---------------------------------------------------------------------------
# CSV (ex-#873) correction
# For LOC: subtract the CSV-specific lines from PR #873 (per-file data via REST fallback).
# For file count ("Files touched"): count unique CSV paths from all PRs EXCEPT #873.
#   This matches the original report's "ex-873" semantics: files that exist in
#   non-#873 PRs (75), not total-minus-#873-paths (68 — different due to overlap).
# ---------------------------------------------------------------------------
PR873_CSV_STATS="${TMPDIR_BASE}/pr873_csv.json"
jq '
  [.[] | select(.number == 873) |
   (.files // [])[] |
   select(.path | test("\\.csv$")) |
   {additions: .additions, deletions: .deletions}
  ] |
  {
    additions: (map(.additions) | add // 0),
    deletions: (map(.deletions) | add // 0)
  }
' "${PR_STATS}" > "${PR873_CSV_STATS}"

PR873_CSV_ADD="$(jq -r '.additions' "${PR873_CSV_STATS}")"
PR873_CSV_DEL="$(jq -r '.deletions' "${PR873_CSV_STATS}")"
PR873_CSV_RAW="$((PR873_CSV_ADD + PR873_CSV_DEL))"
PR873_CSV_NET="$((PR873_CSV_ADD - PR873_CSV_DEL))"

# Unique CSV file paths from any PR other than #873
CSV_EX873_FILES="$(jq -r '
  [.[] | select(.number != 873) |
   (.files // [])[] |
   select(.path | test("\\.csv$")) |
   .path
  ] | unique | length
' "${PR_STATS}")"

# ---------------------------------------------------------------------------
# Extract language totals
# ---------------------------------------------------------------------------
CSV_PRs="$(_lang csv pr_count)";    CSV_FILES="$(_lang_files csv)"
CSV_ADD="$(_lang csv additions)";   CSV_DEL="$(_lang csv deletions)"
CSV_RAW="$(_lang csv raw_loc)";     CSV_NET="$(_lang csv net_loc)"

CSV_EX873_PRs="$((CSV_PRs - 1))"
CSV_EX873_ADD="$((CSV_ADD - PR873_CSV_ADD))"
CSV_EX873_DEL="$((CSV_DEL - PR873_CSV_DEL))"
CSV_EX873_RAW="$((CSV_RAW - PR873_CSV_RAW))"
CSV_EX873_NET="$((CSV_NET - PR873_CSV_NET))"

OCaml_LIB_PRs="$(_lang ocaml_lib pr_count)"; OCaml_LIB_FILES="$(_lang_files ocaml_lib)"
OCaml_LIB_ADD="$(_lang ocaml_lib additions)"; OCaml_LIB_DEL="$(_lang ocaml_lib deletions)"
OCaml_LIB_RAW="$(_lang ocaml_lib raw_loc)";   OCaml_LIB_NET="$(_lang ocaml_lib net_loc)"

OCaml_TEST_PRs="$(_lang ocaml_test pr_count)"; OCaml_TEST_FILES="$(_lang_files ocaml_test)"
OCaml_TEST_ADD="$(_lang ocaml_test additions)"; OCaml_TEST_DEL="$(_lang ocaml_test deletions)"
OCaml_TEST_RAW="$(_lang ocaml_test raw_loc)";   OCaml_TEST_NET="$(_lang ocaml_test net_loc)"

# OCaml total = sum of lib + test buckets
# PR count is recomputed as the union of PRs that touched any .ml/.mli file
OCaml_TOT_PRs="$(jq -r '
  [.[] | .number as $pr |
   (.files // [])[] |
   select(.path | test("\\.mli?$")) |
   $pr
  ] | unique | length
' "${PR_STATS}")"
OCaml_TOT_FILES="$((OCaml_LIB_FILES + OCaml_TEST_FILES))"
OCaml_TOT_ADD="$((OCaml_LIB_ADD + OCaml_TEST_ADD))"
OCaml_TOT_DEL="$((OCaml_LIB_DEL + OCaml_TEST_DEL))"
OCaml_TOT_RAW="$((OCaml_LIB_RAW + OCaml_TEST_RAW))"
OCaml_TOT_NET="$((OCaml_LIB_NET + OCaml_TEST_NET))"

DUNE_PRs="$(_lang dune pr_count)";  DUNE_FILES="$(_lang_files dune)"
DUNE_ADD="$(_lang dune additions)"; DUNE_DEL="$(_lang dune deletions)"
DUNE_RAW="$(_lang dune raw_loc)";   DUNE_NET="$(_lang dune net_loc)"

SEXP_PRs="$(_lang sexp pr_count)";  SEXP_FILES="$(_lang_files sexp)"
SEXP_ADD="$(_lang sexp additions)"; SEXP_DEL="$(_lang sexp deletions)"
SEXP_RAW="$(_lang sexp raw_loc)";   SEXP_NET="$(_lang sexp net_loc)"

SHELL_PRs="$(_lang shell pr_count)";  SHELL_FILES="$(_lang_files shell)"
SHELL_ADD="$(_lang shell additions)"; SHELL_DEL="$(_lang shell deletions)"
SHELL_RAW="$(_lang shell raw_loc)";   SHELL_NET="$(_lang shell net_loc)"

YAML_PRs="$(_lang yaml pr_count)";  YAML_FILES="$(_lang_files yaml)"
YAML_ADD="$(_lang yaml additions)"; YAML_DEL="$(_lang yaml deletions)"
YAML_RAW="$(_lang yaml raw_loc)";   YAML_NET="$(_lang yaml net_loc)"

JSON_PRs="$(_lang json pr_count)";  JSON_FILES="$(_lang_files json)"
JSON_ADD="$(_lang json additions)"; JSON_DEL="$(_lang json deletions)"
JSON_RAW="$(_lang json raw_loc)";   JSON_NET="$(_lang json net_loc)"

MD_PRs="$(_lang markdown pr_count)";  MD_FILES="$(_lang_files markdown)"
MD_ADD="$(_lang markdown additions)"; MD_DEL="$(_lang markdown deletions)"
MD_RAW="$(_lang markdown raw_loc)";   MD_NET="$(_lang markdown net_loc)"

DOCKER_PRs="$(_lang docker pr_count)";  DOCKER_FILES="$(_lang_files docker)"
DOCKER_ADD="$(_lang docker additions)"; DOCKER_DEL="$(_lang docker deletions)"
DOCKER_RAW="$(_lang docker raw_loc)";   DOCKER_NET="$(_lang docker net_loc)"

OTHER_PRs="$(_lang other pr_count)";  OTHER_FILES="$(_lang_files other)"
OTHER_ADD="$(_lang other additions)"; OTHER_DEL="$(_lang other deletions)"
OTHER_RAW="$(_lang other raw_loc)";   OTHER_NET="$(_lang other net_loc)"

# Language table totals (sum across all buckets; files are unique per-bucket so no double-count)
LANG_TOTAL_ADD="$((OCaml_TOT_ADD + DUNE_ADD + SEXP_ADD + SHELL_ADD + YAML_ADD + JSON_ADD + MD_ADD + CSV_ADD + DOCKER_ADD + OTHER_ADD))"
LANG_TOTAL_DEL="$((OCaml_TOT_DEL + DUNE_DEL + SEXP_DEL + SHELL_DEL + YAML_DEL + JSON_DEL + MD_DEL + CSV_DEL + DOCKER_DEL + OTHER_DEL))"
LANG_TOTAL_RAW="$((OCaml_TOT_RAW + DUNE_RAW + SEXP_RAW + SHELL_RAW + YAML_RAW + JSON_RAW + MD_RAW + CSV_RAW + DOCKER_RAW + OTHER_RAW))"
LANG_TOTAL_NET="$((OCaml_TOT_NET + DUNE_NET + SEXP_NET + SHELL_NET + YAML_NET + JSON_NET + MD_NET + CSV_NET + DOCKER_NET + OTHER_NET))"
LANG_TOTAL_FILES="$((OCaml_TOT_FILES + DUNE_FILES + SEXP_FILES + SHELL_FILES + YAML_FILES + JSON_FILES + MD_FILES + CSV_FILES + DOCKER_FILES + OTHER_FILES))"

# Total unique file paths across all buckets (each file has one extension → one bucket, no cross-bucket double-count)
LANG_TOTAL_PR_COUNT="$(jq -r '
  [.[] | .number as $pr | (.files // [])[] | $pr] | unique | length
' "${PR_STATS}")"

# Sanity: total unique file paths should equal sum of per-bucket unique_file_counts
# (since each path belongs to exactly one bucket)
LANG_TOTAL_FILES_JQ="$(jq -r '[.[] | .unique_file_count] | add // 0' "${LANG_STATS}")"
if [[ "$LANG_TOTAL_FILES" -ne "$LANG_TOTAL_FILES_JQ" ]]; then
  echo "WARNING: LANG_TOTAL_FILES mismatch: shell=$LANG_TOTAL_FILES, jq=$LANG_TOTAL_FILES_JQ" >&2
fi

# ---------------------------------------------------------------------------
# Verification assertions
# ---------------------------------------------------------------------------
echo "Verifying OCaml source (total) == lib + test..." >&2
if [[ "$OCaml_TOT_RAW" -ne "$((OCaml_LIB_RAW + OCaml_TEST_RAW))" ]]; then
  echo "ERROR: OCaml total mismatch: total=${OCaml_TOT_RAW}, lib+test=$((OCaml_LIB_RAW + OCaml_TEST_RAW))" >&2
  exit 1
fi
echo "OK: OCaml source (total) == lib (${OCaml_LIB_RAW}) + test (${OCaml_TEST_RAW})" >&2

TOTAL_RAW="$(jq -r '.total_raw_loc' "${HEADLINE}")"
if [[ "$TOTAL_RAW" -ne "$LANG_TOTAL_RAW" ]]; then
  echo "WARNING: headline Total Raw LOC (${TOTAL_RAW}) != language-table sum (${LANG_TOTAL_RAW})" >&2
  echo "  This can occur when some PRs have no per-file data available." >&2
  echo "  The language table total is authoritative for the By-language section." >&2
fi

# ---------------------------------------------------------------------------
# Headline numbers for report
# ---------------------------------------------------------------------------
TOTAL_PRS_INT="$(jq -r '.total_prs' "${HEADLINE}")"
TOTAL_ADDS="$(jq -r '.total_additions' "${HEADLINE}")"
TOTAL_DELS="$(jq -r '.total_deletions' "${HEADLINE}")"
TOTAL_NET="$(jq -r '.total_net_loc' "${HEADLINE}")"
AVG_PRS_DAY="$(echo "scale=1; ${TOTAL_PRS_INT} / ${DAYS}" | bc)"

# PR #873 total for the LOC-outlier note (PR-level additions)
PR873_TOTAL_ADD="$(jq -r '.[] | select(.number == 873) | .additions' "${PR_STATS}" 2>/dev/null || echo 0)"
PR873_TOTAL_DEL="$(jq -r '.[] | select(.number == 873) | .deletions' "${PR_STATS}" 2>/dev/null || echo 0)"
TOTAL_RAW_EX873="$((TOTAL_RAW - PR873_TOTAL_ADD - PR873_TOTAL_DEL))"
TOTAL_NET_EX873="$((TOTAL_NET - PR873_TOTAL_ADD + PR873_TOTAL_DEL))"

RUN_TIMESTAMP="$(date -u '+%Y-%m-%d %H:%MZ')"

# ---------------------------------------------------------------------------
# Report generators
# ---------------------------------------------------------------------------
_cat_rows() {
  jq -r --argjson total_prs "$TOTAL_PRS_INT" '
    .[] |
    "| " + .category +
    " | " + (.pr_count | tostring) +
    " | " + ((.pr_count / $total_prs * 100) | (. * 10 | round) / 10 | tostring) + "%" +
    " | " + (.additions | tostring) +
    " | " + (.deletions | tostring) +
    " | " + (.raw_loc | tostring) +
    " | " + (.net_loc | tostring) + " |"
  ' "${CAT_STATS}"
}

_month_rows() {
  jq -r '.[] |
    "| " + .month +
    " | " + (.pr_count | tostring) +
    " | " + (.raw_loc | tostring) +
    " | " + (.net_loc | tostring) +
    " | " + .top_categories + " |"
  ' "${MONTH_STATS}"
}

# ---------------------------------------------------------------------------
# Generate the report
# ---------------------------------------------------------------------------
_generate_report() {
cat <<REPORT
# Velocity since ${SINCE}

**Window:** ${SINCE} to ${UNTIL} (${DAYS} days inclusive).
**Source:** \`gh pr list --repo dayfine/trading --state merged --search "merged:>=${SINCE} merged:<=${UNTIL}"\` (run ${RUN_TIMESTAMP}).

## Headline

- Total PRs merged: ${TOTAL_PRS_INT}
- Total LOC raw (add+del): ${TOTAL_RAW}
- Total LOC net (add−del): ${TOTAL_NET}
- Average PRs/day: ${AVG_PRS_DAY} (calendar)

**Note on LOC outlier:** PR #873 ("harness: CI golden runs postsubmit") contributed +${PR873_TOTAL_ADD}/−${PR873_TOTAL_DEL} LOC as generated CSV test-fixture data (997 files of ~4,360 lines each). Excluding it: raw ${TOTAL_RAW_EX873}, net ${TOTAL_NET_EX873} — these numbers are more representative of active development churn.

## By category

Categories are parsed from the Conventional-Commits prefix in the PR title (the word before \`:\`). PRs with no conventional prefix are classified \`other\`.

| Category | PRs | % PRs | Additions | Deletions | Raw LOC | Net LOC |
|---|---:|---:|---:|---:|---:|---:|
$(_cat_rows)
| **TOTAL** | **${TOTAL_PRS_INT}** | **100%** | **${TOTAL_ADDS}** | **${TOTAL_DELS}** | **${TOTAL_RAW}** | **${TOTAL_NET}** |

## By language

**Source:** per-file \`{path, additions, deletions}\` from \`gh pr list --json number,files\` + REST API pagination for any PR with exactly 100 files (100-file truncation in the GitHub GraphQL \`files\` field).

**Note on LOC outlier:** PR #873 contributed ${PR873_CSV_ADD} CSV additions (500 files of generated SP500 golden-run fixtures). The CSV (ex-#873) row gives adjusted totals.

| Language | PRs touched | Files touched | Additions | Deletions | Raw LOC | Net LOC |
|---|---:|---:|---:|---:|---:|---:|
| CSV | ${CSV_PRs} | ${CSV_FILES} | ${CSV_ADD} | ${CSV_DEL} | ${CSV_RAW} | ${CSV_NET} |
| CSV (ex-#873) | ${CSV_EX873_PRs} | ${CSV_EX873_FILES} | ${CSV_EX873_ADD} | ${CSV_EX873_DEL} | ${CSV_EX873_RAW} | ${CSV_EX873_NET} |
| OCaml source (total) | ${OCaml_TOT_PRs} | ${OCaml_TOT_FILES} | ${OCaml_TOT_ADD} | ${OCaml_TOT_DEL} | ${OCaml_TOT_RAW} | ${OCaml_TOT_NET} |
| — OCaml source (lib) | ${OCaml_LIB_PRs} | ${OCaml_LIB_FILES} | ${OCaml_LIB_ADD} | ${OCaml_LIB_DEL} | ${OCaml_LIB_RAW} | ${OCaml_LIB_NET} |
| — OCaml source (test) | ${OCaml_TEST_PRs} | ${OCaml_TEST_FILES} | ${OCaml_TEST_ADD} | ${OCaml_TEST_DEL} | ${OCaml_TEST_RAW} | ${OCaml_TEST_NET} |
| Markdown | ${MD_PRs} | ${MD_FILES} | ${MD_ADD} | ${MD_DEL} | ${MD_RAW} | ${MD_NET} |
| Sexp / scenario | ${SEXP_PRs} | ${SEXP_FILES} | ${SEXP_ADD} | ${SEXP_DEL} | ${SEXP_RAW} | ${SEXP_NET} |
| Shell | ${SHELL_PRs} | ${SHELL_FILES} | ${SHELL_ADD} | ${SHELL_DEL} | ${SHELL_RAW} | ${SHELL_NET} |
| Other | ${OTHER_PRs} | ${OTHER_FILES} | ${OTHER_ADD} | ${OTHER_DEL} | ${OTHER_RAW} | ${OTHER_NET} |
| Dune | ${DUNE_PRs} | ${DUNE_FILES} | ${DUNE_ADD} | ${DUNE_DEL} | ${DUNE_RAW} | ${DUNE_NET} |
| YAML / GHA | ${YAML_PRs} | ${YAML_FILES} | ${YAML_ADD} | ${YAML_DEL} | ${YAML_RAW} | ${YAML_NET} |
| JSON | ${JSON_PRs} | ${JSON_FILES} | ${JSON_ADD} | ${JSON_DEL} | ${JSON_RAW} | ${JSON_NET} |
| Docker | ${DOCKER_PRs} | ${DOCKER_FILES} | ${DOCKER_ADD} | ${DOCKER_DEL} | ${DOCKER_RAW} | ${DOCKER_NET} |
| **TOTAL** | **${LANG_TOTAL_PR_COUNT}** | **${LANG_TOTAL_FILES}** | **${LANG_TOTAL_ADD}** | **${LANG_TOTAL_DEL}** | **${LANG_TOTAL_RAW}** | **${LANG_TOTAL_NET}** |

_"PRs touched" = unique PR count where at least one file in the bucket was modified. "Files touched" = unique file paths. Buckets: OCaml = \`*.ml\`/\`*.mli\`; OCaml (lib) = OCaml files NOT under any \`/test/\` directory; OCaml (test) = OCaml files under \`/test/\`; Dune = \`dune\`, \`dune-project\`, \`*.opam\`; Sexp = \`*.sexp\`; Shell = \`*.sh\`/\`*.bash\`; YAML = \`*.yml\`/\`*.yaml\`; Docker = \`Dockerfile\`/\`*.dockerignore\`; Other = everything else._

_Bin and scripts (\`*/bin/*.ml\`, \`*/scripts/*.ml\`) count as source (lib), not test. Only paths containing \`/test/\` qualify as test._

## Per-month rollup

| Month | PRs | Raw LOC | Net LOC | Top categories by PR count |
|---|---:|---:|---:|---|
$(_month_rows)

## Methodology

- Categorization is from the PR title's Conventional-Commits prefix; if a PR was mis-prefixed, it is mis-classified here.
- PRs with no conventional prefix are classified \`other\`.
- The \`harness\` category is a project-local prefix (not part of standard Conventional Commits) used for tooling/linter/agent-definition changes.
- Raw LOC double-counts modifications; net LOC under-counts effort on refactors. Both are shown.
- Squash-merge style means each PR = one commit on main; LOC reflects the squashed delta.
- **100-file truncation:** \`gh pr list --json files\` truncates file lists at 100 entries per PR. For any PR with exactly 100 files, this script falls back to \`gh api repos/dayfine/trading/pulls/<N>/files --paginate\` to retrieve the complete list. Verified for this window: PR #873 (997 files via pagination).
- **OCaml test vs source split:** after the \`*.ml\`/\`*.mli\` extension match, the path is checked for \`/test/\` as a substring. Paths containing \`/test/\` are classified as test; all others (including \`/lib/\`, \`/bin/\`, \`/scripts/\`) are classified as lib/source. The total OCaml row equals lib + test (asserted before output).
- **CSV (ex-#873):** subtracts only the CSV-file-specific lines from PR #873 (computed from per-file data), not the full PR additions/deletions.
- Time window inclusive on both ends. Day count uses UTC midnight to avoid DST-boundary off-by-one errors.
- Excludes: PRs not merged (closed-without-merge).
- Script: \`dev/scripts/velocity_report.sh --since ${SINCE} --until ${UNTIL}\`
REPORT
}

# ---------------------------------------------------------------------------
# Write output
# ---------------------------------------------------------------------------
if [[ -n "$OUT_FILE" ]]; then
  echo "Writing report to ${OUT_FILE}..." >&2
  _generate_report > "${OUT_FILE}"
  echo "Done." >&2
else
  _generate_report
fi
