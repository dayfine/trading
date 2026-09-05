#!/bin/sh
# Inputs: sy.csv = year,symbol,sector,rs_start,rs_mid,ret_y,ret_h2,traded,trade_pnl
W=/tmp/yr-run; cd $W
# ranks within (year,sector): by rs_start desc -> rk_sig ; by ret_y desc -> rk_ret ; by rs_mid desc -> rk_sigm ; by ret_h2 desc -> rk_reth2
sort -t, -k1,1n -k3,3 -k4,4gr sy.csv | awk -F, 'BEGIN{OFS=","} { k=$1","$3; if(k!=pk){r=0; pk=k}; r++; print $0, r }' > s1.csv
sort -t, -k1,1n -k3,3 -k6,6gr s1.csv | awk -F, 'BEGIN{OFS=","} { k=$1","$3; if(k!=pk){r=0; pk=k}; r++; print $0, r }' > s2.csv
sort -t, -k1,1n -k3,3 -k5,5gr s2.csv | awk -F, 'BEGIN{OFS=","} { k=$1","$3; if(k!=pk){r=0; pk=k}; r++; print $0, r }' > s3.csv
sort -t, -k1,1n -k3,3 -k7,7gr s3.csv | awk -F, 'BEGIN{OFS=","} { k=$1","$3; if(k!=pk){r=0; pk=k}; r++; print $0, r }' > ranked.csv
# columns now: 1 y,2 sym,3 sec,4 rs0,5 rsm,6 ry,7 rh2,8 traded,9 tpnl,10 rk_sig,11 rk_ret,12 rk_sigm,13 rk_reth2
# per sector-year summary
awk -F, '
  { k=$1","$3; n[k]++; sr[k]+=$6; if($8==1){ nt[k]++; tp[k]+=$9 }
    if($10==1){ topsig[k]=$2; topsig_rr[k]=$11; topsig_ry[k]=$6; topsig_tr[k]=$8 }
    if($11==1){ topret[k]=$2; topret_sr[k]=$10; topret_ry[k]=$6; topret_tr[k]=$8 }
    if($10<=5 && $8==1) t5s[k]++
    if($11<=5 && $8==1) t5r[k]++
    if($11<=5) { top5ret_ry[k]+=$6 }
    d=$10-$11; sd2[k]+=d*d
    if($12==1){ topsigm[k]=$2; topsigm_rr[k]=$13; topsigm_tr[k]=$8 }
    ys[$1]=1; ry_all[$1]+=$6; n_all[$1]++
    vals[k]=vals[k]" "$6 }
  END {
    print "year,sector,n,mean_ret,spearman_start,spearman_mid_note,top_by_signal,its_ret_rank,its_ret,top_sig_traded,top_by_ret,its_sig_rank,its_ret,top_ret_traded,traded_n,traded_pnl,top5sig_traded,top5ret_traded" > "sector_year.csv"
    for (k in n) { split(k,a,","); nn=n[k]; rho=(nn>2)? 1-6*sd2[k]/(nn*(nn*nn-1)) : 0
      printf "%s,%s,%d,%.3f,%.3f,,%s,%d,%.3f,%d,%s,%d,%.3f,%d,%d,%.0f,%d,%d\n", a[1], a[2], nn, sr[k]/nn, rho, topsig[k], topsig_rr[k], topsig_ry[k], topsig_tr[k], topret[k], topret_sr[k], topret_ry[k], topret_tr[k], nt[k], tp[k], t5s[k], t5r[k] >> "sector_year.csv" }
  }' ranked.csv
# mid-year spearman (rs_mid vs ret_h2) per sector-year
awk -F, '{ k=$1","$3; n[k]++; d=$12-$13; sd2[k]+=d*d } END { for(k in n){ nn=n[k]; printf "%s,%.3f\n", k, (nn>2? 1-6*sd2[k]/(nn*(nn*nn-1)) : 0) } }' ranked.csv > spearman_mid.csv
wc -l sector_year.csv spearman_mid.csv
