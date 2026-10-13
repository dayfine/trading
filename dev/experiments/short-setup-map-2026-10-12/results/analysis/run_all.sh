#!/bin/sh
# Analyst re-derivations behind the README's "Why", "Traced events" and rigor sections (results-analyst, 2026-10-12).
# Read-only: host bars (data/), the stage replays (.sweep-output/short-setup-map/stages/), the committed event table.
# Host only, no container; 10-40 minutes, mostly the cluster bootstrap (B = 1,000), depending on host load. Run from the repo root:
#   sh dev/experiments/short-setup-map-2026-10-12/results/analysis/run_all.sh
# Writes analysis.txt and traces.txt next to this script; scratch files go to .sweep-output/short-setup-map/analysis/.
set -e
E=dev/experiments/short-setup-map-2026-10-12
A=${A:-$E/results/analysis}; export A
W=${W:-.sweep-output/short-setup-map/analysis}
mkdir -p "$W/ev2"

# Steps 1-3 (about 5 minutes) can be skipped on a rerun with SKIP_EXTRACT=1 once $W holds their outputs.
if [ -z "$SKIP_EXTRACT" ] || [ ! -s "$W/evx.csv" ] || [ ! -s "$W/lastdate.csv" ]; then
# 1. The committed event table (one header) and its symbols.
cat $E/results/events/*.csv | awk 'NR==1 || !/^sym,/' > $W/ev.csv
cut -d, -f1 $W/ev.csv | tail -n +2 | sort -u > $W/syms.txt

# 2. Extra per-event diagnostics, same event selection as events.awk; joined back on (sym, date).
xargs -P 3 -I{} sh $A/ev2_one.sh {} $W < $W/syms.txt
cat $W/ev2/*.csv > $W/ev2.csv
awk -F, -f $A/join.awk $W/ev2.csv $W/ev.csv > $W/evx.csv

# 3. Last bar date per symbol (delisted vs live).
while read s; do a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1)
  printf '%s,%s\n' "$s" "$(tail -1 data/$a/$b/$s/data.csv | cut -d, -f1)"; done < $W/syms.txt > $W/lastdate.csv
fi

# 4. The tables.
{
  echo "events: $(($(wc -l < $W/ev.csv) - 1)) committed, $(($(wc -l < $W/evx.csv) - 1)) joined"
  for d in support surface checklist lateness topwidth dividends years robust paired phase tail scale; do
    echo; echo "== $d"; awk -F, -f $A/lib.awk -f $A/$d.awk $W/evx.csv; done
  echo; echo "== survivor"; awk -F, -f $A/lib.awk -f $A/survivor.awk $W/lastdate.csv $W/evx.csv
  for f in 5 17; do echo; echo "== criteria floor $f"; awk -F, -v floor=$f -f $A/lib.awk -f $A/criteria.awk $W/evx.csv; done
  echo; echo "== bootstrap"
  for clu in week quarter; do
    for col in e1_o2_exc e1_o1_60 e1_o1_120; do awk -F, -v cell=P1 -v col=$col -v clu=$clu -v B=1000 -f $A/lib.awk -f $A/boot.awk $W/evx.csv; done
    for col in e2_o2_exc e2_o1_60; do awk -F, -v cell=P2 -v col=$col -v clu=$clu -v B=1000 -f $A/lib.awk -f $A/boot.awk $W/evx.csv; done
  done
} > $A/analysis.txt

# 5. The twenty traced events: P1 and P2 at fixed quantiles of O2 excess (5/20/35/50/65 % losers, 75/82/89/95/99 % winners).
for x in BCE,2000-06-02 AIR,2007-09-14 AVA,2004-05-21 OSPN,2007-11-16 PLUS,2016-02-26 KRNT,2018-12-28 WM,2020-03-27 \
         ING,2011-07-29 CSL,2020-03-20 LFST,2025-04-04 PLXS,2022-02-11 DOO,2022-09-23 LGND,2016-02-12 ETR,2007-08-10 \
         TRGP,2025-04-17 GEN,2025-04-04 KR,2018-12-31 SEIC,2008-01-25 EQIX,2025-03-14 FHN,2023-03-24 CSCO,2000-09-22; do
  sh $A/trace.sh "${x%,*}" "${x#*,}"; echo; done > $A/traces.txt

# 6. Every traced field against its committed row.
{ echo; echo "== trace check"; awk -f $A/check_traces.awk $A/traces.txt; } >> $A/analysis.txt
echo DONE
