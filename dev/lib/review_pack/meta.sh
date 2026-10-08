#!/bin/sh
# meta.json for one salt dir: summary metrics, params overrides, validator checks, audit conformance,
# and the short leg when params enable it.
D=$1
# Return basis (#3177): cash yield credited and dividend_crediting true. Both -> "tr" (compare with SPY
# total return), neither -> "price" (SPY price only), one -> "mixed" (the page shows both SPY lines). The
# Sharpe is excess over the net T-bill rate when cash yield is credited, raw otherwise.
# cash_yield is read from the overrides when present (any value but No_yield credits). Absent, it takes the
# default of the code that ran: No_yield before #3184 (99f0b321, default-on), the T-bill series from it on.
# When git cannot place the run's code_version (an unknown or shallow-cloned SHA) the current default (on)
# is assumed and the page says so: cash_yield_src = explicit | default | assumed.
CASH_YIELD_DEFAULT_ON=99f0b3218787c8abde82400eeccecfb2fe241d2c
REPO_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
basis() {
  dv=false; grep -q '(dividend_crediting true)' "$D/params.sexp" 2>/dev/null && dv=true
  if grep -q '(cash_yield No_yield)' "$D/params.sexp" 2>/dev/null; then cy=false; src=explicit
  elif grep -qE '\(cash_yield \(' "$D/params.sexp" 2>/dev/null; then cy=true; src=explicit
  else
    cv=$(grep -oE 'code_version [0-9a-f]+' "$D/params.sexp" 2>/dev/null | cut -d' ' -f2)
    if [ -n "$cv" ] && git -C "$REPO_DIR" cat-file -e "$cv^{commit}" 2>/dev/null && git -C "$REPO_DIR" cat-file -e "$CASH_YIELD_DEFAULT_ON^{commit}" 2>/dev/null; then
      src=default; cy=false; git -C "$REPO_DIR" merge-base --is-ancestor "$CASH_YIELD_DEFAULT_ON" "$cv" 2>/dev/null && cy=true
    else cy=true; src=assumed; fi
  fi
  case "$cy$dv" in truetrue) b=tr ;; falsefalse) b=price ;; *) b=mixed ;; esac
  printf '{"spy":"%s","cash_yield":%s,"dividends":%s,"cash_yield_src":"%s"}' "$b" "$cy" "$dv" "$src"
}
esc() { sed 's/\\/\\\\/g; s/"/\\"/g'; }
# Short leg (#3111): null unless params.sexp has (enable_short_side true). Fills and realised P&L come
# from trades.csv (side SHORT); tickets placed (audited entry decisions with side Short), Bearish
# screening weeks and those with short_top_n_admitted > 0 (cascade_summaries) come from
# trade_audit.sexp and are null, never 0, when it is missing.
short_leg() {
  grep -q '(enable_short_side true)' "$D/params.sexp" 2>/dev/null || { printf 'null'; return; }
  awk -F, 'NR>1 && $2=="SHORT" { n++; p += $9 } END { printf "{\"fills\":%d,\"pnl\":%.2f", n, p }' "$D/trades.csv"
  if [ -s "$D/trade_audit.sexp" ]; then
    printf ',"tickets":%s' "$(grep -o '(side Short) (suggested_entry' "$D/trade_audit.sexp" | wc -l | tr -d ' ')"
    awk '/^ \(cascade_summaries/ { on = 1 } !on { next }
      /\(macro_trend [A-Za-z]+\)/ { b = /\(macro_trend Bearish\)/; bw += b }
      match($0, /\(short_top_n_admitted [0-9]+\)/) { n = substr($0, RSTART + 22, RLENGTH - 23) + 0; if (b && n > 0) ba++; b = 0 }
      END { printf ",\"bearish_weeks\":%d,\"bearish_admitted\":%d}", bw, ba }' "$D/trade_audit.sexp"
  else
    printf ',"tickets":null,"bearish_weeks":null,"bearish_admitted":null}'
  fi
}
# At-fill cash rejections (#3138): entry tickets cancelled because the book could not fund the fill,
# from each ticket_lifecycle (cash_rejection ((required R) (available A))) in trade_audit.sexp. count, and
# how many were at least 90 % funded (A / R >= 0.9). null, never 0, when the trade audit is missing.
cash_rejections() {
  [ -s "$D/trade_audit.sexp" ] || { printf 'null'; return; }
  tr -s '\n\t ' '   ' < "$D/trade_audit.sexp" | grep -oE '\(cash_rejection \(\(required [-0-9.e+]+\) \(available [-0-9.e+]+\)\)\)' |
    awk '{ r = $3; a = $5; gsub(/[()]/, "", r); gsub(/[()]/, "", a); n++; if (r > 0 && a / r >= 0.9) k++ }
      END { printf "{\"count\":%d,\"near\":%d}", n, k }'
}
esc() { sed 's/\\/\\\\/g; s/"/\\"/g'; }
{
printf '{"metrics":{'
grep -oE 'metric_type\.t\.[a-z]+ [-0-9.e]+' "$D/summary.sexp" | sed 's/metric_type\.t\.//' | awk '{printf "%s\"%s\":%s", (NR>1?",":""), $1, $2+0}'
printf '},"n_round_trips":%s,"final_value":%s' "$(grep -oE 'n_round_trips [0-9]+' "$D/summary.sexp" | cut -d' ' -f2)" "$(grep -oE 'final_portfolio_value [0-9.]+' "$D/summary.sexp" | cut -d' ' -f2)"
printf ',"code_version":"%s"' "$(grep -oE 'code_version [0-9a-f]+' "$D/params.sexp" | cut -d' ' -f2)"
printf ',"overrides":"%s"' "$(sed -n '/overrides/,$p' "$D/params.sexp" | tr -s ' \n' ' ' | esc)"
printf ',"validator":['
awk 'function flush() { if (id != "") { printf "%s{\"id\":\"%s\",\"sev\":\"%s\",\"status\":\"%s\",\"specimens\":[%s]}", (n++?",":""), id, sev, st, sp } }
  /^V[0-9]+ / { flush(); id=$1; sev=$2; $1=""; $2=""; st=substr($0,3); sp=""; ns=0; next }
  /^    / && id != "" { s=$0; sub(/^ +/,"",s); gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); sp = sp (ns++?",":"") "\"" s "\""; next }
  END { flush() }' "$D/validator.sexp.md"
printf '],"conformance":['
[ -s "$D/trade_audit_report.md" ] && sed -n '/## Weinstein conformance/,/^## Decision/p' "$D/trade_audit_report.md" | awk -F'|' '/^\| R[0-9]/ { for(i=2;i<=7;i++){gsub(/^ +| +$/,"",$i); gsub(/"/,"\\\"",$i)}; printf "%s{\"rule\":\"%s\",\"desc\":\"%s\",\"passed\":\"%s\",\"rate\":\"%s\",\"fails\":\"%s\"}", (n++?",":""), $2,$3,$4,$5,$6 }'
printf '],"short_leg":%s,"basis":%s,"cash_rejections":%s}\n' "$(short_leg)" "$(basis)" "$(cash_rejections)"
}
