# Short-semantics late-stop check (Phase A short_late.sh, ported to one awk pass). For each stop_loss exit: was the
# live buy-stop breached (bar HIGH >= stop) on a bar strictly after the entry day and strictly before the exit day?
# Live stop = trades.csv entry_stop, then each stop_decisions stop_after, applied from the bar AFTER its decision date.
# The run has sim_stop_exit_fill_on_trigger_bar on, so a breach before the exit day should not happen.
# files: 1 bars.csv (sym,date,o,h,l,c,adj; sorted)  2 <cell>.audit.tsv  3 force_liquidations.sexp  4 trades.csv (hdr)
# out (tab): cell pid sym entry exit first_breach live_stop bar_open bar_high exit_price pnl forced(fl date) lag_bars
# -v CELL=<label>
BEGIN{ OFS="\t" }
FILENAME==ARGV[1]{ split($0, f, ","); k[f[1]]++; bd[f[1], k[f[1]]]=f[2]; bo[f[1], k[f[1]]]=f[3]+0; bh[f[1], k[f[1]]]=f[4]+0; next }
FILENAME==ARGV[2]{ split($0, f, "\t"); if (f[1]=="S") { n[f[2]]++; sdd[f[2], n[f[2]]]=f[3]; ssa[f[2], n[f[2]]]=f[7]+0 } next }
FILENAME==ARGV[3]{ if (match($0, /\(position_id [^)]*\)/)) { p=substr($0, RSTART+13, RLENGTH-14); match($0, /\(date [0-9-]+\)/); fl[p]=substr($0, RSTART+6, 10) } next }
FILENAME==ARGV[4]{ if (FNR==1) next; split($0, t, ","); if (t[13]!="stop_loss") next
  pid=t[20]; s=t[1]; ed=t[3]; xd=t[4]; first=""; lag=0
  for (i=1; i<=k[s]; i++) { d=bd[s, i]; if (d<=ed) continue; if (d>=xd) break
    st=t[11]+0; for (j=1; j<=n[pid]; j++) if (sdd[pid, j]<d) st=ssa[pid, j]
    if (first=="" && bh[s, i]>=st-1e-9) { first=d; fs=st; fo=bo[s, i]; fh=bh[s, i] }
    if (first!="") lag++ }
  nl++; if (first!="") { nb++; pb+=t[9]; if (pid in fl) nf++
    print CELL, pid, s, ed, xd, first, sprintf("%.4f", fs), fo, fh, t[7], t[9], (pid in fl ? "forced " fl[pid] : "-"), lag }
}
END{ printf "%s\tSUMMARY\tstop_loss exits %d, breached before the exit day %d (P&L %.0f), of which force-liquidated %d\n", CELL, nl, nb+0, pb, nf+0 }
