# Short-book cash reconstruction: the interest base, interest, dividends paid, borrow and commissions per day,
# summed onto equity-curve rows. Method = ../../../total-return-26y-2026-10-06/results/analysis/tr_reconstruct.awk,
# moved to a short-only book (README §Stopping rule):
#   base_d = V0 + realised P&L of positions covered by d - commissions - borrow - dividends paid + interest so far
#   (for a short-only book this is cash minus open short proceeds, the simulator's interest base, cash_yield.mli);
#   interest_d = max(0, base_{d-1}) * max(0, DTB3_d - 0.10) / 100 / 360, every calendar day, DTB3 forward-filled.
# Commission max($1, $0.01/share) per side (params.sexp). Borrow per bar day held (entry day included, cover day
# excluded, as Phase A derive.sh): q * close * tier / 252, tier 1.00 under $5, 0.25 under $17, else 0.005
# (margin_config.mli default). Dividends: a short held at the prior close pays q * unadjusted_amount on the ex-date
# (entry < ex <= cover). No splits were applied in any cell (every <cell>-splits.csv is header-only).
# files: 1 DTB3 (hdr)  2 divs.csv sym,ex,unadj,adj  3 bars.csv sym,date,o,h,l,c,adj  4 trades.csv (hdr)
#        5 equity_curve.csv (hdr)
# -v DAY=<file>  per row: date,V,x_int,div,borrow,comm,short_mv,base,nav_recon,n_open
# -v POS=<file>  per position: pid,sym,entry,exit,div_paid,borrow,comm
# -v START=2000-01-01
function jdn(s,   y,m,d,a,yy,mm){ y=substr(s,1,4)+0; m=substr(s,6,2)+0; d=substr(s,9,2)+0;
  a=int((14-m)/12); yy=y+4800-a; mm=m+12*a-3;
  return d+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045 }
function comm(q,  c){ c=0.01*q; return (c<1?1:c) }
function tier(p){ return p<5 ? 1.00 : (p<17 ? 0.25 : 0.005) }
BEGIN{ FS=","; if (START=="") START="2000-01-01" }
FNR==1{ f++; if (f==1 || f==4 || f==5) next }
f==1{ if ($2!="" && $2!=".") rate[jdn($1)]=$2+0; next }
f==2{ nd[$1]++; dd[$1,nd[$1]]=jdn($2); da[$1,nd[$1]]=$3+0; next }
f==3{ j=jdn($2); cl[$1,j]=$6+0; if (!($1 in fb) || j<fb[$1]) fb[$1]=j; next }
f==4{ np++; ps[np]=$1; pe[np]=jdn($3); px[np]=jdn($4); pq[np]=$8+0; pep[np]=$6+0; pid[np]=$20; ped[np]=$3; pxd[np]=$4
      ce=comm($8+0); cx=ce; flow[pe[np]]-=ce; flow[px[np]]+=($9+0)-cx; cm[pe[np]]+=ce; cm[px[np]]+=cx; pcm[np]=ce+cx; next }
f==5{ n++; rd[n]=jdn($1); rs[n]=$1; rv[n]=$2+0; next }
END{
  # dividends paid and borrow, per day and per position
  for (p=1; p<=np; p++) { s=ps[p]
    for (j=1; j<=nd[s]; j++) { d=dd[s,j]; if (d>pe[p] && d<=px[p] && d<=rd[n]) { a=pq[p]*da[s,j]; dv[d]+=a; pdv[p]+=a } }
    last=0
    for (d=pe[p]; d<px[p] && d<=rd[n]; d++) { if ((s,d) in cl) { c=cl[s,d]; b=pq[p]*c*tier(c)/252; bo[d]+=b; pbo[p]+=b } }
  }
  d0=jdn(START); base=1000000; r=0
  for (k=d0-30; k<d0; k++) if (k in rate) r=rate[k]
  i=1; ai=0; adv=0; abo=0; acm=0; ti=0; tdv=0; tbo=0; tcm=0
  for (d=d0; d<=rd[n]; d++) {
    if (d in rate) r=rate[d]
    net=r-0.10; if (net<0) net=0
    it=(base>0?base:0)*net/100/360
    di=(d in dv)?dv[d]:0; bi=(d in bo)?bo[d]:0; ci=(d in cm)?cm[d]:0
    ti+=it; tdv+=di; tbo+=bi; tcm+=ci; ai+=it; adv+=di; abo+=bi; acm+=ci
    base+=it-di-bi
    if (d in flow) base+=flow[d]
    if (i<=n && rd[i]==d) {
      mv=0; un=0; no=0
      for (p=1; p<=np; p++) if (pe[p]<=d && d<px[p]) { s=ps[p]; c=""
          for (k=d; k>=d-10; k--) if ((s,k) in cl) { c=cl[s,k]; break }
          if (c=="") c=pep[p]
          mv+=pq[p]*c; un+=pq[p]*(pep[p]-c); no++ }
      if (DAY!="") printf "%s,%.2f,%.4f,%.4f,%.4f,%.4f,%.2f,%.2f,%.2f,%d\n", rs[i], rv[i], ai, adv, abo, acm, mv, base, base+un, no > DAY
      ai=0; adv=0; abo=0; acm=0; i++
    }
  }
  if (POS!="") for (p=1; p<=np; p++) printf "%s,%s,%s,%s,%.2f,%.2f,%.2f\n", pid[p], ps[p], ped[p], pxd[p], pdv[p], pbo[p], pcm[p] > POS
  printf "interest_recon=%.2f dividends_paid=%.2f borrow_est=%.2f commission_est=%.2f terminal_base=%.2f final_nav=%.2f\n", ti, tdv, tbo, tcm, base, rv[n]
}
