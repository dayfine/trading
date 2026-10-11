# Decision-8 returns ex cash interest (README §Stopping rule), per window, from one cell's recon.awk DAY file.
#   x_t scaled by CIT / reconstructed interest (the gate is checked by the caller);
#   R_ex(log) = ln(V_end / V_start) - sum_{t in (start, end]} ln(V_t / (V_t - x_t));
#   R_ex($)   = (V_end - V_start - sum x_t) / V_start.
# V at a bound = the last equity row on or before the bound date; the full window starts from V_0 = $1,000,000
# on 2000-01-01, before the first row. SPY total return = adjusted close at the same bound dates (last SPY bar on
# or before). Also: mean short exposure (short MV at close / V over the window's rows), fills (trades.csv entries
# dated in the window), dividends paid by shorts, interest stripped (scaled), realised P&L of covers in the window.
# Decomposition columns (diagnostic, not part of the rule):
#   L_cost = sum ln((V_t + c_t) / V_t), c_t = dividends paid + borrow (estimate) + commissions (estimate);
#   H      = an SPY short at the same exposure path: sum ln(1 - e_{t-1} * SPY_t / SPY_{t-1} + e_{t-1}),
#            e_{t-1} = short MV / V at the prior row (0 on rows without an SPY bar);
#   names  = R_ex(log) + L_cost - H: what the single names did beyond an index short at the same exposure.
# files: 1 DAY csv (no hdr: date,V,x_int,div,borrow,comm,short_mv,base,nav_recon,n_open)  2 spy.csv (date,close,adj)
#        3 trades.csv (hdr)   4 windows file (no hdr: label,start,end)
# -v CIT=<cashinteresttotal> -v CELL=<label>
BEGIN{ FS="," }
FILENAME==ARGV[1]{ n++; dt[n]=$1; V[n]=$2+0; x[n]=$3+0; dv[n]=$4+0; co[n]=$4+$5+$6; mv[n]=$7+0; tx+=$3; next }
FILENAME==ARGV[2]{ ns++; sd[ns]=$1; sa[ns]=$3+0; sp[$1]=$3+0; next }
FILENAME==ARGV[3]{ if (FNR==1) next; ne++; ed[ne]=$3; xd[ne]=$4; pn[ne]=$9+0; next }
FILENAME==ARGV[4]{ nw++; wl[nw]=$1; ws[nw]=$2; we[nw]=$3; next }
function rowon(d,   i, r){ r=0; for (i=1; i<=n; i++) { if (dt[i]<=d) r=i; else break } return r }
function spyon(d,   i, r){ r=0; for (i=1; i<=ns; i++) { if (sd[i]<=d) r=i; else break } return r }
END{
  s=CIT/tx
  # per-row index-short log return at the prior row's exposure
  pv=1000000; pm=0; ps=sa[spyon("2000-01-01")]
  for (t=1; t<=n; t++) { h[t]=0
    if (dt[t] in sp) { h[t]=log(1-(pm/pv)*(sp[dt[t]]/ps-1)); ps=sp[dt[t]] }
    pv=V[t]; pm=mv[t] }
  for (w=1; w<=nw; w++) {
    a=rowon(ws[w]); b=rowon(we[w])
    va=(a==0 ? 1000000 : V[a]); da=(a==0 ? "2000-01-01" : dt[a])
    L=0; X=0; D=0; E=0; m=0; LC=0; H=0
    for (t=a+1; t<=b; t++) { xs=s*x[t]; L+=log(V[t]/(V[t]-xs)); X+=xs; D+=dv[t]; E+=mv[t]/V[t]; m++; LC+=log((V[t]+co[t])/V[t]); H+=h[t] }
    rl=log(V[b]/va)-L; rd=(V[b]-va-X)/va
    sa0=spyon(da); sb=spyon(dt[b]); spy=sa[sb]/sa[sa0]-1
    nf=0; rp=0; for (k=1; k<=ne; k++) { if (ed[k]>da && ed[k]<=dt[b]) nf++; if (xd[k]>da && xd[k]<=dt[b]) rp+=pn[k] }
    printf "%s\t%s\t%s\t%s\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.1f\t%d\t%.0f\t%.0f\t%.0f\t%.0f\t%.0f\t%s\t%.4f\t%.4f\t%.4f\n", CELL, wl[w], da, dt[b],
      rl, rd, log(V[b]/va), L, spy, (m>0 ? 100*E/m : 0), nf, D, X, rp, va, V[b], ((rl>0 && rd>0) ? "PASS" : "fail"), LC, H, rl+LC-H
  }
}
