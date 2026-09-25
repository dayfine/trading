#!/bin/sh
# meta.json for one salt dir: summary metrics, params overrides, validator checks, audit conformance.
D=$1
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
sed -n '/## Weinstein conformance/,/^## Decision/p' "$D/trade_audit_report.md" | awk -F'|' '/^\| R[0-9]/ { for(i=2;i<=7;i++){gsub(/^ +| +$/,"",$i); gsub(/"/,"\\\"",$i)}; printf "%s{\"rule\":\"%s\",\"desc\":\"%s\",\"passed\":\"%s\",\"rate\":\"%s\",\"fails\":\"%s\"}", (n++?",":""), $2,$3,$4,$5,$6 }'
printf ']}\n'
}
