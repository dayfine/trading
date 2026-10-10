#!/bin/sh
# Reproduce every number in ../results-2026-10-10.md. POSIX sh + awk, read-only on the repo; run from the repo root:
#   sh dev/experiments/shorts-phase-b-2026-10-09/results/analysis/run_all.sh > /tmp/spb-analysis.out
# Inputs (defaults in common.sh; override by environment): the committed per-cell artifacts in results/, the
# lane-A / lane-B trade audits under .sweep-output/shorts-phase-b{,-v1}/ (not committed, ~3 MB each), the host bar
# store data/, the staged dividends (the run tree, else data/), DTB3 at trading/test_data/macro/tbill_3m_dtb3.csv and
# full SPY history at data/S/Y/SPY/data.csv. WORK (default ${TMPDIR:-/tmp}/spb-analysis) holds the flattened inputs.
# Sections, in the writeup's order:
#   gates.sh      validity gates 1-5 and 7, validator counts
#   decision8.sh  gate 6 (interest reconstruction), decision 8 (A, B, bear periods, give-back, years), arm decisions
#   liveness.sh   item 2 and the #3131 after-merge item
#   anatomy.sh    item 3 (paired v1 - v0, RV2 regime split), items 4-6, #3145 / #3148 evidence, selection read
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
sh "$HERE/prep.sh"
echo; sh "$HERE/gates.sh"
echo; sh "$HERE/decision8.sh"
echo; sh "$HERE/liveness.sh"
echo; sh "$HERE/anatomy.sh"
