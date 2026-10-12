# N-O log-return decomposition by period. Inputs: expo_O_sS.csv expo_N_sS.csv (date,nav,inv,pos)
FNR==1{f++}
{ d=$1; if(f==1){o[d]=$2} else {nv[d]=$2; dates[++n]=d} }
END{ split("2000-01-01 2003-01-01 2008-01-01 2010-01-01 2017-01-01 2019-01-01 2026-12-31",cut," "); split("2000-02 2003-07 2008-09 2010-16 2017-18 2019-26",lab," ");
  po=1e6; pn=1e6; k=1; tot=0;
  for(i=1;i<=n;i++){ d=dates[i]; while(d>=cut[k+1]){ printf "%s dlog %+.4f (O %+.4f N %+.4f) | ", lab[k], lnN-lnO, lnO, lnN; tot+=lnN-lnO; lnO=0; lnN=0; k++ }
    lnO+=log(o[d]/po); lnN+=log(nv[d]/pn); po=o[d]; pn=nv[d] }
  printf "%s dlog %+.4f (O %+.4f N %+.4f) | total %+.4f\n", lab[k], lnN-lnO, lnO, lnN, tot+lnN-lnO }
