# Compare each trace in traces.txt with its committed row (the "committed:" line trace.sh prints). awk -f check_traces.awk traces.txt
function val(s, key,   i, n, a) { n = split(s, a, " "); for (i = 1; i <= n; i++) if (index(a[i], key "=") == 1) return substr(a[i], length(key) + 2); return "" }
function chk(name, x, y, tol) { if (x == "" && y == "") return; if (x == "" || y == "" || (x - y > tol || y - x > tol)) { bad++; printf "  MISMATCH %s %s: committed %s vs trace %s\n", ev, name, x, y } else ok++ }
/^=== / { ev = $2 " " $5; leg = ""; n_ev++; next }
/^committed:/ { c = $0; next }
/^Stage-3 run/ { match($0, /stop = [0-9.]+/); chk("stop", val(c, "stop"), substr($0, RSTART + 7, RLENGTH - 7), 0.0002)
  match($0, /\([0-9]+ wk\)/); chk("top_width", val(c, "top_width"), substr($0, RSTART + 1, RLENGTH - 5), 0); next }
/^E[12] entry/ { leg = ($1 == "E1") ? "e1" : "e2"; split($0, g, " "); chk(leg "_date", 0, (g[3] == val(c, leg "_date") ? 0 : 1), 0)
  chk(leg "_px", val(c, leg "_px"), g[6], 0.0002); match($0, /room to stop [-0-9.]+%/); chk(leg "_room", val(c, leg "_room"), substr($0, RSTART + 13, RLENGTH - 14) / 100, 0.0001); k = 0; next }
/^   O1\+/ { k++; nm = (k == 1 ? "_o1_20" : (k == 2 ? "_o1_60" : "_o1_120")); match($0, /excess\(short-short\) [-+0-9.]+%/); chk(leg nm, val(c, leg nm), substr($0, RSTART + 20, RLENGTH - 21) / 100, 0.0001); next }
/O2 exit/ { match($0, /bar \+[0-9]+/); chk(leg "_o2_bars", val(c, leg "_o2_bars"), substr($0, RSTART + 5, RLENGTH - 5), 0); chk(leg "_o2_stopped", val(c, leg "_o2_stopped"), ($0 ~ /STOPPED/) ? 1 : 0, 0); next }
/O2 short ret/ { match($0, /short ret [-+0-9.]+%/); chk(leg "_o2_ret", val(c, leg "_o2_ret"), substr($0, RSTART + 10, RLENGTH - 11) / 100, 0.0001)
  match($0, /excess vs SPY short [-+0-9.]+%/); chk(leg "_o2_exc", val(c, leg "_o2_exc"), substr($0, RSTART + 20, RLENGTH - 21) / 100, 0.0001); next }
/^E2: pullback in week/ { match($0, /week \+[0-9]+/); chk("e2_weeks", val(c, "e2_weeks"), substr($0, RSTART + 6, RLENGTH - 6), 0); next }
END { printf "traced events %d; committed fields compared %d; mismatched %d\n", n_ev, ok + bad, bad + 0 }
