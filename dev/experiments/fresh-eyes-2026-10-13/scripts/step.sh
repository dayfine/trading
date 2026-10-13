#!/bin/sh
# step.sh <SYM> <run dir> init <start Friday | auto>
# step.sh <SYM> <run dir> apply <decision file>
# step.sh <SYM> <run dir> pending
#
# The forward-pass loop of plan §4 layer (ii), one symbol per run dir:
#   init     writes the first state at the start cut, renders its pages, writes pending.txt.
#   apply    applies the agent's decision (JSON or key=value; see decision.awk) at the current cut, simulates daily
#            bars to the next checkpoint (sim.awk), renders the new cut's pages and rewrites pending.txt. A
#            rejected decision leaves the state unchanged and puts the message in pending.txt (exit 3).
#   pending  re-renders any missing page for the current cut and rewrites pending.txt (resume after a failed
#            render).
# Run dir layout: state (key=value), trades.csv, log.csv, decisions/<cut>.txt (each applied decision, as given),
# pending.txt. Pages: <PAGES>/<SYM display>-<cut>-{full,5y}.png + .json; MARKET pages are shared across symbols
# in <PAGES>/market (default PAGES = <run dir>/../pages). Run from the repo root; DATA = the daily store;
# END = last cut (default 2026-06-26). Exit 0 on success, 3 on a rejected decision, 4 when the run is finished.
set -e
s=$1; R=$2; cmd=$3; arg=$4
E=dev/experiments/fresh-eyes-2026-10-13; S=$E/scripts; DATA=${DATA:-data}; END=${END:-2026-06-26}
WEEKLY=${WEEKLY:-.sweep-output/fresh-eyes/weekly}; export WEEKLY DATA
PAGES=${PAGES:-$R/../pages}; mkdir -p "$R" "$PAGES/market" "$WEEKLY"
w=$WEEKLY/$s.csv
[ -s "$w" ] || sh $S/weekly.sh "$s" > "$w"
disp=$(printf %s "$s" | sed -E 's/_old[0-9]*$//; s/[0-9]+$//')
a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1); daily=$DATA/$a/$b/$s/data.csv

cut_of() { sed -n 's/^cut=//p' "$R/state"; }
status_of() { sed -n 's/^status=//p' "$R/state"; }

# Render the cut's pages unless both PNGs already exist (stock and market).
pages() {
  c=$1
  [ -s "$PAGES/$disp-$c-full.png" ] && [ -s "$PAGES/$disp-$c-5y.png" ] && [ -s "$PAGES/$disp-$c.json" ] \
    || sh $S/render.sh "$s" "$c" "$PAGES"
  [ -s "$PAGES/market/MARKET-$c-full.png" ] && [ -s "$PAGES/market/MARKET-$c-5y.png" ] \
    || sh $S/render.sh MARKET "$c" "$PAGES/market"
}

write_pending() {
  c=$(cut_of)
  {
    if [ "$(status_of)" = done ]; then echo "RUN FINISHED"; else echo "DECISION NEEDED at cut $c"; fi
    echo "stock pages: $PAGES/$disp-$c-full.png $PAGES/$disp-$c-5y.png"
    echo "last bar: $PAGES/$disp-$c.json"
    echo "market pages: $PAGES/market/MARKET-$c-full.png $PAGES/market/MARKET-$c-5y.png"
    [ -n "$1" ] && echo "REJECTED: $1 (state unchanged; decide again at the same cut)"
    awk -F, -f $S/status.awk "$R/state" "$w" "$R/trades.csv"
  } > "$R/pending.txt"
}

case $cmd in
init)
  c=$arg; [ "$c" = auto ] && c=$(awk -F, -f $S/days.awk -f $S/start.awk "$w")
  [ "$c" != none ] || { echo "step.sh: $s has no 30-week MA after 2000-01-07" >&2; exit 2; }
  printf 'sym=%s\ncut=%s\npos=none\nedate=\nepx=\nstop=\nord=none\ntrig=\nlim=\nostop=\nplaced=\ndue=0\nxpend=0\nstatus=open\nmsg=\n' "$s" "$c" > "$R/state"
  echo "sym,side,entry_date,entry_px,exit_date,exit_px,how,ret,spy_ret,excess" > "$R/trades.csv"
  echo "cut,action,trigger,stop,next_cut,events" > "$R/log.csv"
  mkdir -p "$R/decisions"
  pages "$c"; write_pending ;;
apply)
  [ "$(status_of)" != done ] || { write_pending; exit 4; }
  c=$(cut_of); T=${TMPDIR:-/tmp}/fe-step-$$; mkdir -p "$T"
  sh $S/decision.sh "$arg" > "$T/dec"
  awk -F, -v end="$END" -f $S/days.awk -f $S/sim.awk "$R/state" "$T/dec" "$w" "$DATA/S/Y/SPY/data.csv" "$daily" > "$T/out"
  if grep -q '^REJECT,' "$T/out"; then
    m=$(sed -n 's/^REJECT,//p' "$T/out"); rm -rf "$T"; write_pending "$m"; exit 3
  fi
  cp "$arg" "$R/decisions/$c.txt"
  grep '^TRADE,' "$T/out" | sed 's/^TRADE,//' >> "$R/trades.csv" || true
  grep '^LOG,' "$T/out" | sed 's/^LOG,//' >> "$R/log.csv"
  grep -v -e '^TRADE,' -e '^LOG,' "$T/out" > "$R/state"; rm -rf "$T"
  if [ "$(status_of)" = done ]; then write_pending; exit 4; fi
  pages "$(cut_of)"; write_pending ;;
pending)
  [ "$(status_of)" = done ] || pages "$(cut_of)"; write_pending ;;
*) echo "usage: step.sh <SYM> <run dir> init <start|auto> | apply <decision> | pending" >&2; exit 2 ;;
esac
