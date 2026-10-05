#!/bin/sh
# Short-semantics late-stop check: for each stop_loss exit of a SHORT, was the live stop
# (installed stop, then each stop_decisions stop_after, applied from the next bar) breached
# (bar HIGH >= stop) on a day strictly after the entry day and strictly before the exit day?
# usage: short_late.sh <trades.csv> <stopdec.tsv> <bars-root>
TR=$1; SD=$2; DATA=$3
tail -n +2 "$TR" | while IFS=, read -r sym side ed xd days ep xp qty pnl pct es xs trig rest; do
  [ "$trig" = stop_loss ] || continue
  pid=$(echo "$rest" | awk -F, '{print $7}')
  nraise=$(echo "$rest" | awk -F, '{print $10}')
  f="$DATA/$(printf %s "$sym" | cut -c1)/$(printf %s "$sym" | rev | cut -c1)/$sym/data.csv"
  [ -f "$f" ] || { echo "$pid NOFILE"; continue; }
  awk -F'\t' -v pid="$pid" 'NR==FNR { if ($1 == pid) { n++; dd[n] = $2; ss[n] = $3 }; next }
    FNR == 1 { next }
    {
      split($0, b, ","); d = b[1]; hi = b[3] + 0; lo = b[4] + 0
      if (d <= ed || d >= xd) next
      st = es + 0; for (i = 1; i <= n; i++) if (dd[i] < d) st = ss[i]
      if (hi >= st - 1e-9 && first == "") { first = d; fst = st; fhi = hi }
      if (lo <= st + 1e-9) longb++
    }
    END { printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", pid, ed, xd, nraise, es, (first == "" ? "-" : first), (first == "" ? "-" : fst), (first == "" ? "-" : fhi), longb + 0 }' \
    ed="$ed" xd="$xd" es="$es" nraise="$nraise" "$SD" "$f"
done
