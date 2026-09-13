#!/bin/sh
# Per-salt paired read: null = committed a0-breadth-on-null-s<salt>-v10 (stop-width-by-state-2026-09-08/results),
# arm = $ARM-s<salt>-v10 (ARM defaults to a3-deteriorating-gate; results/ here, or the artifact dir given as $2).
# Prints level / realised / unrealised / maxDD / trades / exit mix, then the symbol|entry_date join
# (shared, null-only, arm-only) with top movers. Usage: sh read.sh <salt> [arm-artifact-dir]
set -eu
salt=$1; ARMDIR=${2:-dev/experiments/deteriorating-gate-2026-09-13/results}; ARM=${ARM:-a3-deteriorating-gate}
N=${NULL:-dev/experiments/stop-width-by-state-2026-09-08/results/a0-breadth-on-null-s$salt-v10}
A=$ARMDIR/$ARM-s$salt-v10
k() { grep -oE "\($2 [0-9.eE+-]+" "$1-actual.sexp" | awk '{print $2}'; }
hdr() { printf '%-6s %10s %8s %12s %12s %8s\n' arm level trades realised unrealised maxDD; }
row() { printf '%-6s %10.2f %8d %12.0f %12.0f %8.2f\n' "$1" "$(k $2 total_return_pct)" "$(k $2 total_trades)" \
  "$(awk -F, 'NR>1{s+=$9} END{print s}' $2-trades.csv)" "$(k $2 unrealized_pnl)" "$(k $2 max_drawdown_pct)"; }
echo "== salt $salt =="; hdr; row null $N; row gate $A
echo "-- exit mix (null | gate)"
for t in stop_loss laggard_rotation stage3_force_exit extension_stop delisted liquidity_exit stale_exit force_liquidation; do
  printf '  %-20s %4d | %4d\n' $t "$(awk -F, -v t=$t 'NR>1&&$13==t{c++} END{print c+0}' $N-trades.csv)" "$(awk -F, -v t=$t 'NR>1&&$13==t{c++} END{print c+0}' $A-trades.csv)"; done
echo "-- open names (null | gate)"; echo "  $(awk -F, 'NR>1{printf "%s ",$1}' $N-open_positions.csv) | $(awk -F, 'NR>1{printf "%s ",$1}' $A-open_positions.csv)"
echo "-- join on symbol|entry_date"
J=$(mktemp); awk -F, 'FNR==1{f++; next} {key=$1"|"$3} f==1{n[key]=$9; next} {a[key]=$9}
  END{ for(k in n) if(k in a) print "SHARED", k, n[k], a[k], a[k]-n[k]; else print "NULLONLY", k, n[k]
       for(k in a) if(!(k in n)) print "GATEONLY", k, a[k] }' $N-trades.csv $A-trades.csv > "$J"
awk '$1=="SHARED"{sh++; sn+=$3; sa+=$4} $1=="NULLONLY"{no++; snull+=$3} $1=="GATEONLY"{ao++; sarm+=$3}
  END{printf "  shared %d: null %.0f -> gate %.0f (drift %.0f)\n  null-only %d: %.0f\n  gate-only %d: %.0f\n", sh, sn, sa, sa-sn, no, snull, ao, sarm}' "$J"
top() { echo "  $3"; grep "^$1 " "$J" | sort -k$2,$2 -g -r | head -8 | awk -v c=$2 '{printf "    %-22s %10.0f\n", $2, $c}'; echo "    ...worst:"; grep "^$1 " "$J" | sort -k$2,$2 -g | head -4 | awk -v c=$2 '{printf "    %-22s %10.0f\n", $2, $c}'; }
top NULLONLY 3 "top null-only (entries the gate removed or displaced):"
top GATEONLY 3 "top gate-only (what the freed cash bought):"
echo "  largest shared drifts (gate - null):"; grep '^SHARED ' "$J" | awk '$5!=0' | sort -k5,5 -g -r | head -5 | awk '{printf "    %-22s %10.0f\n", $2, $5}'
rm -f "$J"
