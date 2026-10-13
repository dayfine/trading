# Fresh-eyes stepper: normalise one agent decision to key=value lines (plan §4 layer (ii)).
# Usage: awk -f decision.awk <decision file>
# Accepts either a flat JSON object ({"action":"buy_stop","trigger":12.5,...}) or key=value lines. Keys kept:
# stage, action, trigger, limit, stop, reason. Output always carries an action line (default none), so the
# simulator never reads an empty decision file.
{ buf = buf " " $0 }
END {
  n = split("stage action trigger limit stop reason", K, " ")
  s = buf
  if (s ~ /[{]/) {
    for (i = 1; i <= n; i++) {
      v = ""
      if (match(s, "\"" K[i] "\"[ \t]*:[ \t]*\"[^\"]*\"")) {
        v = substr(s, RSTART, RLENGTH); sub(/^[^:]*:[ \t]*"/, "", v); sub(/"$/, "", v)
      } else if (match(s, "\"" K[i] "\"[ \t]*:[ \t]*[-+0-9.eE]+")) {
        v = substr(s, RSTART, RLENGTH); sub(/^[^:]*:[ \t]*/, "", v)
      }
      val[K[i]] = v
    }
  } else {
    m = split(buf, L, " ")
    # key=value lines: re-read from the raw text so a reason may contain spaces.
    t = buf; gsub(/[ \t]+([a-z]+)=/, "\n&", t); m = split(t, L, "\n")
    for (j = 1; j <= m; j++) {
      x = L[j]; sub(/^[ \t]+/, "", x); sub(/[ \t]+$/, "", x)
      p = index(x, "="); if (p == 0) continue
      key = substr(x, 1, p - 1); v = substr(x, p + 1)
      for (i = 1; i <= n; i++) if (K[i] == key) val[key] = v
    }
  }
  if (val["action"] == "") val["action"] = "none"
  gsub(/[\n\r,]/, ";", val["reason"])
  for (i = 1; i <= n; i++) print K[i] "=" val[K[i]]
}
