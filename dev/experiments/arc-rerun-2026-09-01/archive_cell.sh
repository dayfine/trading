#!/bin/sh
# archive_cell.sh <cell-tag> [...] — copy a finished cell's per-arm artifacts from the
# container's /tmp/sweeps/arc0901/<tag>/ into results/<tag>/ and extract the audit CSV.
# The 22MB trade_audit.sexp itself is NOT copied (kept out of git); its extract is.
set -u
C=trading-1-dev
R="$(dirname "$0")/results"
for tag in "$@"; do
  mkdir -p "$R/$tag"
  for f in actual.sexp params.sexp trades.csv summary.sexp open_positions.csv wall_seconds.txt; do
    docker cp "$C:/tmp/sweeps/arc0901/$tag/$f" "$R/$tag/$f" 2>/dev/null
  done
  docker exec "$C" cat "/tmp/sweeps/arc0901/$tag/trade_audit.sexp" 2>/dev/null \
    | perl "$(dirname "$0")/audit_extract.pl" > "$R/$tag/audit_extract.csv"
  printf '%s: ' "$tag"; grep -oE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|win_rate [0-9.]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.]+' "$R/$tag/actual.sexp" | tr '\n' ' '; echo
  awk -F, 'NR>1{n[$13]++; p[$13]+=$9} END{printf "  exits:"; for(k in n) printf " %s=%d(%.0f)",k,n[k],p[k]; printf "\n"}' "$R/$tag/trades.csv"
done
# --- phantom check (issue #2646): trades whose [entry, exit] window contains an
# adjusted-close splice date from results/splice-scan.csv; prints ex-phantom realised.
for tag in "$@"; do
  T="$R/$tag/trades.csv"; SC="$R/splice-scan.csv"; [ -f "$SC" ] || continue
  awk -F, -v run="$tag" 'NR==FNR{sp[$1]=sp[$1]" "$2; next}
    FNR>1{tot+=$9; n=split(sp[$1],d," "); for(i=1;i<=n;i++) if(d[i]>=$3 && d[i]<=$4){ph+=$9; printf "  PHANTOM %s %s->%s pnl=%.0f %s (splice %s)\n",$1,$3,$4,$9,$13,d[i]; break}}
    END{printf "  realised=%.0f phantom=%.0f ex_phantom=%.0f\n",tot,ph,tot-ph}' "$SC" "$T"
done
