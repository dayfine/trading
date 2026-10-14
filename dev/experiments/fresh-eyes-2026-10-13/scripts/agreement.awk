# agreement.awk: driving reader vs shadow reader on the same first-attempt messages (pilot 2).
# Usage: awk -f agreement.awk <run dir>/raw/<cut>-1.txt files ... (driving) then -v shadowdir=<run dir>/shadow-raw
# Simpler entry point: agreement.sh. Input here: lines "D|<cut>|<json>" and "S|<cut>|<json>" on stdin.
# Output: action agreement overall and on "active" driving decisions (anything but none), and level agreement
# (|shadow - driving| / driving) on trigger and stop where both gave the same order action.
function field(j, k,   v) {
  if (match(j, "\"" k "\"[ \t]*:[ \t]*\"[^\"]*\"")) { v = substr(j, RSTART, RLENGTH); sub(/^[^:]*:[ \t]*"/, "", v); sub(/"$/, "", v); return v }
  if (match(j, "\"" k "\"[ \t]*:[ \t]*[-+0-9.eE]+")) { v = substr(j, RSTART, RLENGTH); sub(/^[^:]*:[ \t]*/, "", v); return v }
  return ""
}
BEGIN { FS = "|" }
{ j = $0; sub(/^[^|]*\|[^|]*\|/, "", j); if ($1 == "D") D[$2] = j; else Sh[$2] = j }
END {
  for (c in D) {
    if (!(c in Sh)) { nos++; continue }
    a = field(D[c], "action"); b = field(Sh[c], "action"); if (a == "") a = "none"; if (b == "") b = "none"
    n++; if (a == b) same++
    sa = field(D[c], "stage"); sb = field(Sh[c], "stage"); if (sa != "" && sb != "") { ns++; if (sa == sb) ss++ }
    pair[a " -> " b]++
    if (a != "none") { na++; if (a == b) sa2++; act[c] = a " / " b }
    if (b != "none" && a == "none") shadow_only++
    if ((a == "buy_stop" || a == "short_stop" || a == "set_stop") && a == b) {
      for (q = 1; q <= 2; q++) { k = (q == 1) ? "trigger" : "stop"; x = field(D[c], k); y = field(Sh[c], k)
        if (x + 0 > 0 && y + 0 > 0) { nl[k]++; d = (y - x) / x; if (d < 0) d = -d; L[k, nl[k]] = d; sl[k] += d } }
    }
  }
  printf "paired decisions %d (driving without a shadow answer: %d)\n", n, nos
  printf "action agreement %d / %d = %.1f %%\n", same, n, n ? 100 * same / n : 0
  printf "stage agreement %d / %d = %.1f %%\n", ss, ns, ns ? 100 * ss / ns : 0
  printf "active driving decisions (not none) %d; shadow gave the same action on %d\n", na, sa2
  printf "shadow active where driving said none: %d\n", shadow_only
  for (p in pair) printf "  %-26s %d\n", p, pair[p]
  for (c in act) printf "  active %s: %s\n", c, act[c]
  for (q = 1; q <= 2; q++) { k = (q == 1) ? "trigger" : "stop"
    if (nl[k]) { m = nl[k]; for (i = 1; i <= m; i++) for (j2 = i + 1; j2 <= m; j2++) if (L[k, j2] < L[k, i]) { t = L[k, i]; L[k, i] = L[k, j2]; L[k, j2] = t }
      printf "level %s: n %d, mean |diff| %.2f %%, median %.2f %%, max %.2f %%\n", k, m, 100 * sl[k] / m, 100 * L[k, int((m + 1) / 2)], 100 * L[k, m] }
    else printf "level %s: no same-action pairs\n", k }
}
