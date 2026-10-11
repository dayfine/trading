# One row per closed short (trades.csv) with every anatomy-C attribute (README §Pre-registered reading item 4).
# files: 1 <cell>.audit.tsv (audit_flat.awk)  2 <cell>.pos.csv (recon.awk POS: pid,sym,entry,exit,div,borrow,comm)
#        3 force_liquidations.sexp  4 macro.txt (date trend)  5 spy.csv (date,close,adj)  6 trades.csv (hdr)
# out (tab): cell pid sym entry exit days ret_px ret_tr pnl tr_pnl div borrow comm year macro_fill age agebkt band
#            stopexit planned realised squeeze forced holdbkt mfe mfebkt idx_ret pick_minus_idx exit_trigger
#            idx_stage stage_tag weeks_decl conf_ex_mom trigger_kind entry_price exit_price entry_stop exit_stop qty
#   ret_px  = trades.csv pnl / (qty * entry) in %, side-signed (+ = the short made money), price only
#   ret_tr  = (pnl - dividends paid - borrow estimate - commissions) / (qty * entry), the position's total return
#   stopexit: initial (stop never lowered) / trailed (lowered at least once, never Tightened) / tightened (the
#             stop-hit decision was in state Tightened) / other (margin_call, liquidity_exit, stale_force_exit)
#   planned = entry_stop / entry - 1; realised = exit / entry - 1 (adverse when > 0); squeeze = a losing exit with
#             realised > 1.5 * planned; forced = the position is in force_liquidations.sexp (Per_position)
#   idx_ret = an SPY short over the same dates (adjusted close, entry-date close to exit-date close), side-signed %
# -v CELL=<label>
function hb(d){ return d<=5 ? "a 0-5d" : d<=20 ? "b 6-20d" : d<=60 ? "c 21-60d" : d<=120 ? "d 61-120d" : "e >120d" }
function spyon(d,   lo, hi, mid){ lo=1; hi=ns; if (sd[1]>d) return 0
  while (lo<hi) { mid=int((lo+hi+1)/2); if (sd[mid]<=d) lo=mid; else hi=mid-1 } return lo }
BEGIN{ OFS="\t" }
FILENAME==ARGV[1]{ split($0, f, "\t")
  if (f[1]=="T") { age[f[2]]=f[12]; mfe[f[2]]=f[21]; ist[f[2]]=f[27]; tag[f[2]]=f[36]; wdc[f[2]]=f[29]; cxm[f[2]]=f[25] }
  if (f[1]=="S") { if (f[7]+0 < f[6]-1e-9) low[f[2]]=1; if (f[8]=="Stop_hit") lastst[f[2]]=f[4] }
  next }
FILENAME==ARGV[2]{ split($0, f, ","); dv[f[1]]=f[5]; bo[f[1]]=f[6]; cm[f[1]]=f[7]; next }
FILENAME==ARGV[3]{ if (match($0, /\(position_id [^)]*\)/)) fl[substr($0, RSTART+13, RLENGTH-14)]=1; next }
FILENAME==ARGV[4]{ split($0, f, " "); nm++; md[nm]=f[1]; mt[nm]=f[2]; next }
FILENAME==ARGV[5]{ split($0, f, ","); ns++; sd[ns]=f[1]; sa[ns]=f[3]+0; next }
FILENAME==ARGV[6]{ if (FNR==1) next; split($0, t, ",")
  pid=t[20]; q=t[8]+0; e=t[6]+0; x=t[7]+0; pnl=t[9]+0; notl=q*e
  rpx=100*pnl/notl; tr=pnl-dv[pid]-bo[pid]-cm[pid]; rtr=100*tr/notl
  m="NONE"; for (i=1; i<=nm; i++) { if (md[i]<=t[3]) m=mt[i]; else break }
  a=(pid in age) ? age[pid]+0 : -1; ab=(a<0 ? "?" : a>=4 ? "stale>=4wk" : "fresh<4wk")
  band=(e>=17 ? "fill>=17" : "fill<17")
  if (t[13]!="stop_loss") se="other"; else if (lastst[pid]=="Tightened") se="tightened"; else if ((pid in low) || t[12]+0 < t[11]-0.005) se="trailed"; else se="initial"
  pl=t[11]/e-1; re=x/e-1; sq=(pnl<0 && re>1.5*pl) ? "squeeze" : "no"
  fo=(pid in fl) ? "forced" : "no"
  mf=(pid in mfe && mfe[pid]!="-") ? 100*mfe[pid] : 0; mb=(mf>=20 ? "mfe>=20" : "mfe<20")
  i0=spyon(t[3]); i1=spyon(t[4]); ir=(i0>0 && i1>0) ? -100*(sa[i1]/sa[i0]-1) : 0
  print CELL, pid, t[1], t[3], t[4], t[5], sprintf("%.3f", rpx), sprintf("%.3f", rtr), sprintf("%.2f", pnl), sprintf("%.2f", tr),
    dv[pid], bo[pid], cm[pid], substr(t[3],1,4), m, a, ab, band, se, sprintf("%.4f", pl), sprintf("%.4f", re), sq, fo, hb(t[5]+0),
    sprintf("%.2f", mf), mb, sprintf("%.3f", ir), sprintf("%.3f", rpx-ir), t[13], ist[pid], tag[pid], wdc[pid], cxm[pid], t[17],
    e, x, t[11], t[12], q
}
