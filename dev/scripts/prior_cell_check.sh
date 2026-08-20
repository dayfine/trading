#!/bin/sh
# prior_cell_check.sh — has this cell already been measured?
#
# Pre-flight for any experiment that is about to spend container time
# re-running a configuration, and post-flight for any writeup that is about to
# claim "no prior null exists for this metric".
#
# WHY THIS EXISTS. On 2026-08-20 the rt-freshness 26y writeup justified a
# six-cell design with "the 2026-08-14 run recorded return and trades and
# nothing else, so there is no null spread for MaxDD or Sharpe". A committed
# file — dev/experiments/nearfloor-26y-salts-2026-08-13/results.txt — already
# carried that exact cell at all three salts with win_rate, maxDD, sharpe and
# holding_days. The claim was wrong in a way that cost the record its strongest
# evidence: six metrics x three salts had reproduced digit-for-digit against an
# independent artefact, and the writeup claimed only three return draws.
# qc-behavioral found it by grepping. This makes that grep a command.
#
# Full-precision draws are effectively unique fingerprints, so an exact-string
# search over the archived results is both cheap and decisive.
#
# USAGE
#   sh dev/scripts/prior_cell_check.sh 281.707836178685        # by draw
#   sh dev/scripts/prior_cell_check.sh 00-core-w4              # by cell name
#   sh dev/scripts/prior_cell_check.sh --metrics 00-core-w4    # + which metrics
#
# EXIT CODES
#   0  no prior record found — the cell looks genuinely unmeasured
#   1  prior record(s) found — READ THEM BEFORE RUNNING OR CLAIMING ANYTHING
#   2  usage error
#
# Exit 1 is deliberately the "found" case: this is a pre-flight guard, so the
# non-zero exit is the one that should stop a chain script.
set -u

SHOW_METRICS=0
if [ "${1:-}" = "--metrics" ]; then
  SHOW_METRICS=1
  shift
fi

if [ $# -ne 1 ]; then
  echo "usage: $0 [--metrics] <full-precision-draw | cell-name>" >&2
  exit 2
fi

NEEDLE="$1"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Archived result tables live as results*.txt / *-results.txt under
# dev/experiments/, plus per-cell actual.sexp files committed with a writeup.
HITS=$(find "$ROOT/dev/experiments" "$ROOT/dev/notes" \
         -type f \( -name 'results*.txt' -o -name '*results*.md' \
                    -o -name 'actual.sexp' \) 2>/dev/null \
       | xargs grep -l -F -- "$NEEDLE" 2>/dev/null | sort)

if [ -z "$HITS" ]; then
  echo "no prior record of '$NEEDLE' under dev/experiments/ or dev/notes/"
  echo "(absence here is not proof — uncommitted .sweep-output/ is not searched)"
  exit 0
fi

echo "PRIOR RECORD FOUND for '$NEEDLE' — read these before running or claiming:"
echo
for f in $HITS; do
  rel=${f#"$ROOT"/}
  echo "  $rel"
  if [ "$SHOW_METRICS" = 1 ]; then
    grep -F -- "$NEEDLE" "$f" \
      | grep -oE '(total_return_pct|return|trades|total_trades|win_rate|maxDD|max_drawdown_pct|sharpe|sharpe_ratio|holding_days|avg_holding_days|ulcer_index|calmar_ratio|sortino_ratio_annualized) [0-9.eE+-]+' \
      | sed 's/^/      /'
  fi
done
echo
echo "If a prior file already carries the metric you were about to call"
echo "unmeasured, the honest statement is which metrics it DOES carry and which"
echo "it does not — and a digit-for-digit match against it is a stronger"
echo "determinism tripwire than a fresh run's self-consistency."
exit 1
