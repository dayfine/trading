#!/bin/sh
# vsb-1 supply-path count (#3671 QC R1): per arm, how many entry decisions in a trade_audit.sexp were
# graded by the continuous supply path, which is the path `virgin_supply_basis` reaches.
#
#   sh vsb-1-supply-count.sh S=<path>/trade_audit.sexp vsb-1=<path>/trade_audit.sexp
#
# The screener writes "Overhead supply (continuous)" into an entry's cascade_rationale exactly when
# the analysis carries a supply score (`screener_scoring.ml` _resistance_signal: w_overhead_supply = Some
# and supply = Some); with supply = None it falls back to the binary v1 grade. Under One_basis a
# missing breakout or raw close gives supply = None, so a collapsed arm shows ~0 here.
# resistance_quality is the v1 grade the audit records (not the knob's path); it is listed for reference.
# Reads the pretty-printed layout the runner writes: one `(entry` line opens each audit record, and
# `(cascade_summaries` ends the audit_records section. Prints counts only: no prices, dates or symbols.
set -eu
printf 'arm\taudit_records\tsupply_continuous\trq_Clean\trq_Moderate_resistance\trq_Virgin_territory\trq_Heavy_resistance\trq_none\n'
for spec in "$@"; do
  label=${spec%%=*}; file=${spec#*=}
  awk -v label="$label" '
    /^ *\(cascade_summaries/ { done = 1 }
    done { next }
    /^ *\(\(+entry$/ { nrec++; got_q = 0 }
    nrec && index($0, "\"Overhead supply (continuous)\"") && !sup[nrec]++ { nsup++ }
    nrec && !got_q && match($0, /\(resistance_quality +\(?[A-Za-z_]*/) {
      q = substr($0, RSTART, RLENGTH); sub(/^\(resistance_quality +\(?/, "", q)
      rq[q == "" ? "none" : q]++; got_q = 1
    }
    END {
      printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n", label, nrec, nsup, rq["Clean"], rq["Moderate_resistance"],
        rq["Virgin_territory"], rq["Heavy_resistance"], rq["none"] + nrec - (rq["Clean"] + rq["Moderate_resistance"] \
        + rq["Virgin_territory"] + rq["Heavy_resistance"] + rq["none"])
    }' "$file"
done
