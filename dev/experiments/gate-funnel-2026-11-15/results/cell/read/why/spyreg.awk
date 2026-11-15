# input: SPY data.csv (date,open,high,low,close,adjusted_close,...). Output: week_key regime (known at that week's last close)
BEGIN{FS=","}
NR>1 { wk=week_of($1); if (wk!=lastwk && lastwk!="") { n++; C[n]=lc; K[n]=lastwk } lastwk=wk; lc=$6+0 }
END { n++; C[n]=lc; K[n]=lastwk
  for (i=1;i<=n;i++) { r="";
    if (i>=34) { m=0; for(j=i-29;j<=i;j++) m+=C[j]; m/=30; m4=0; for(j=i-33;j<=i-4;j++) m4+=C[j]; m4/=30; c=C[i]
      r = (c>m && m>m4) ? "UP" : (c<m && m<m4) ? "DOWN" : "MIXED" }
    print K[i]"\t"r }
}
