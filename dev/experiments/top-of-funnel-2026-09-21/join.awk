# targets: sym entry lo tag ; candidates.sexp streamed; emit sym,entry,tag,friday,outcome,grade for fridays in [lo, entry)
NR==FNR { k=$1; n[k]++; e[k,n[k]]=$2; l[k,n[k]]=$3; t[k,n[k]]=$4; next }
{
  if (match($0, /\(date [0-9-]+\)/)) { d = substr($0, RSTART+6, RLENGTH-7); next }
  if (match($0, /\(symbol [A-Z0-9.-]+\)/)) { s = substr($0, RSTART+8, RLENGTH-9); o=""; if (match($0, /\(outcome [A-Za-z_]+\)/)) o = substr($0, RSTART+9, RLENGTH-10); live = (s in n) }
  if (live && match($0, /\(grade [A-Za-z_]+\)/)) { g = substr($0, RSTART+7, RLENGTH-8);
    for (i=1;i<=n[s];i++) if (d >= l[s,i] && d < e[s,i]) print s","e[s,i]","t[s,i]","d","o","g; live=0 }
}
