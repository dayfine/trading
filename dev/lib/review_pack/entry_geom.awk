# Entry geometry from trade_audit.sexp (#3546 D1/D4/D5): one row per audited entry, for the pack's
# entry-geometry signals (index.html entryGeometry).
# usage: awk -f entry_geom.awk trade_audit.sexp > x_geo.tsv
#   out: pid<TAB>suggested_entry<TAB>close_at_decision<TAB>adjusted_close_at_decision
#   E is the screener's entry; the closes are the decision bar's raw and adjusted closes, so close / E is
#   raw on both sides and close / adjusted_close is the bar's basis factor in the warehouse's vintage.
#   A field absent from the record (an audit written before it existed) is left empty -> null in the JSON.
# Each key is taken from the first occurrence after a position_id: these keys appear only in the entry
# decision, never in alternatives, exits or stop decisions. Whitespace and line wrapping do not matter.
{
  s = $0
  while (match(s, /\((position_id|suggested_entry|close_at_decision|adjusted_close_at_decision) [^()]+\)/)) {
    tok = substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH)
    k = tok; sub(/ .*/, "", k); v = tok; sub(/^[^ ]+ +/, "", v); sub(/ +$/, "", v)
    if (k == "position_id") { pid = v; if (!(pid in seen)) { seen[pid] = 1; ord[++n] = pid }; continue }
    if (pid != "" && !((pid SUBSEP k) in val)) val[pid, k] = v
  }
}
END {
  for (i = 1; i <= n; i++) {
    p = ord[i]; if (!((p SUBSEP "suggested_entry") in val)) continue
    printf "%s\t%s\t%s\t%s\n", p, val[p, "suggested_entry"], val[p, "close_at_decision"], val[p, "adjusted_close_at_decision"]
  }
}
