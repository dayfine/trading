# Positions still open at the window end -> <run>_open.json on stdout (#3125):
#   {"rows":[{"sym","side","ed","ep","qty","mE"}], "check":{"date","pack","actual"}}
# usage: awk -v last=D -v actual=V -f open_json.awk x_open.tsv x_macro.tsv x_expo.tsv
#   x_open.tsv : sym<TAB>entry_date<TAB>entry_price<TAB>qty<TAB>side   (open_positions.csv rows)
#   last       : the window's last equity date
#   actual     : actual.sexp open_positions_value, "" when the run has no actual.sexp
# check.pack is the marked value of everything held on the last day (closed trades
# stop counting the day before their exit), so it should equal check.actual.
function q(s) { gsub(/"/, "", s); return "\"" s "\"" }
# files told apart by ARGV: x_open.tsv / x_macro.tsv may be empty, which an FNR==1 counter skips
FILENAME == ARGV[1] { split($0, a, "\t"); no++; os[no] = a[1]; oe[no] = a[2]; op[no] = a[3]; oq[no] = a[4]; osd[no] = a[5]; next }
FILENAME == ARGV[2] { split($0, a, "\t"); nm++; md[nm] = a[1]; mtr[nm] = a[2]; next }
FILENAME == ARGV[3] { split($0, a, "\t"); if (a[1] == last) pack += a[2]; next }
function macro_at(d,   i, r) { r = 0; for (i = 1; i <= nm && md[i] <= d; i++) r = i; return r }
END {
  printf "{\"rows\":["
  for (i = 1; i <= no; i++) { m = macro_at(oe[i])
    printf "%s{\"sym\":%s,\"side\":%s,\"ed\":%s,\"ep\":%s,\"qty\":%s,\"mE\":%s}", (i > 1 ? "," : ""), q(os[i]), q(osd[i]), q(oe[i]), op[i] + 0, oq[i] + 0, q(m ? mtr[m] : "") }
  printf "],\"check\":{\"date\":%s,\"pack\":%.2f,\"actual\":%s}}\n", q(last), pack, (actual == "" ? "null" : sprintf("%.2f", actual))
}
