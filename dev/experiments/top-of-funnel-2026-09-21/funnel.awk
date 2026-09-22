# Streams candidates.sexp; emits long-format rows: date,kind,key,count
# kind=outcome key=<outcome>; kind=gate key=<breakout_gate> ; kind=grade key=<outcome>/<grade>
function flush(   k) { for (k in c) { split(k, p, SUBSEP); print d "," p[1] "," p[2] "," c[k] } delete c }
{
  if (match($0, /\(date [0-9-]+\)/)) { if (d != "") flush(); d = substr($0, RSTART+6, RLENGTH-7); next }
  if (match($0, /\(outcome [A-Za-z_]+\)/)) { o = substr($0, RSTART+9, RLENGTH-10); c["outcome", o]++ }
  if (match($0, /\(breakout_gate [A-Za-z_]+\)/)) { g = substr($0, RSTART+15, RLENGTH-16); c["gate", g]++ }
  if (match($0, /\(grade [A-Za-z_]+\)/)) { gr = substr($0, RSTART+7, RLENGTH-8); c["grade", o "/" gr]++ }
}
END { if (d != "") flush() }
