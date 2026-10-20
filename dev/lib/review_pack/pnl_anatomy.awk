# NAV CSV, trades CSV, extraction TSV -> per-year + whole-run anatomy JSON.
# Monetary P&L and return % in trades.csv are already side-signed.
BEGIN { FS="," }
function numeric(s) { return s ~ /^[-+]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][-+]?[0-9]+)?$/ }
function json(v) { return v=="" ? "null" : sprintf("%.12g",v) }
function nav_at(d,   lo,hi,m,r) {
  lo=1; hi=nn; r=0
  while(lo<=hi) { m=int((lo+hi)/2); if(navdate[m]<=d) { r=m; lo=m+1 } else hi=m-1 }
  return r ? nav[r] : ""
}
function descending(a,n,   i,j,v) {
  for(i=2;i<=n;i++) { v=a[i]; j=i-1; while(j>=1 && a[j]<v) { a[j+1]=a[j]; j-- } a[j+1]=v }
}
function alpha(a,n,   k,i,s) {
  k=int(n/10); if(k<1 || n<=k) return ""
  s=0; for(i=1;i<=k;i++) s+=log(a[i]/a[k+1])
  return s>0 ? k/s : ""
}
function top_share(k,n,net,   i,s) {
  if(net==0) return ""
  s=0; for(i=1;i<=n && i<=k;i++) s+=ranked[i]
  return 100*s/net
}
FILENAME==ARGV[1] {
  if(FNR==1) next
  nn++; navdate[nn]=$1; nav[nn]=numeric($2) && $2+0>0 ? $2+0 : ""; next
}
FILENAME==ARGV[2] {
  if(FNR==1) {
    for(i=1;i<=NF;i++) { sub(/\r$/,"",$i); col[$i]=i }
    valid=col["entry_date"] && col["entry_price"] && col["quantity"] && col["pnl_dollars"] && col["pnl_percent"] && col["position_id"] && col["exit_trigger"]
    next
  }
  if(!NF) next
  nt++; ed[nt]=$(col["entry_date"]); ep[nt]=$(col["entry_price"]); qty[nt]=$(col["quantity"])
  pnl[nt]=$(col["pnl_dollars"]); pct[nt]=$(col["pnl_percent"]); pid[nt]=$(col["position_id"]); trig[nt]=$(col["exit_trigger"])
  year[nt]=ed[nt] ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ ? substr(ed[nt],1,4) : "n/a"
  if(!(year[nt] in years)) { years[year[nt]]=1; labels[++ny]=year[nt] }
  next
}
FILENAME==ARGV[3] {
  split($0,x,"\t"); post[x[1]]=x[17]; peak[x[1]]=x[6]; after[x[1]]=x[8]
}
function row(label,   i,n,nw,nl,net,wp,lp,weights,rel,v,profit_ok,pct_ok,nav_ok,whip,good,regret,wm,gm,rm,complete,k) {
  for(i in positive) delete positive[i]
  for(i in negative) delete negative[i]
  for(i in ranked) delete ranked[i]
  n=nw=nl=net=wp=lp=weights=rel=whip=good=regret=wm=gm=rm=complete=0
  profit_ok=pct_ok=nav_ok=1
  for(i=1;i<=nt;i++) {
    if(label!="All" && year[i]!=label) continue
    n++; v=nav_at(ed[i])
    if(v!="" && numeric(ep[i]) && numeric(qty[i]) && ep[i]+0>0 && qty[i]+0>0 && year[i]!="n/a") {
      weights+=100*ep[i]*qty[i]/v
      if(numeric(pnl[i])) rel+=100*pnl[i]/v; else nav_ok=0
    } else nav_ok=0
    if(!numeric(pct[i])) pct_ok=0
    if(!numeric(pnl[i])) { profit_ok=0; wm=gm=rm=1; continue }
    ranked[n]=pnl[i]+0; net+=pnl[i]
    if(pnl[i]+0>0) { positive[++nw]=pnl[i]+0; wp+=pct[i] }
    if(pnl[i]+0<0) { negative[++nl]=-pnl[i]; lp-=pct[i] }
    k=pid[i]; v=numeric(post[k]) && post[k]+0>=65
    complete+=v
    if(pnl[i]+0<0) {
      if(v && numeric(peak[k])) whip+=peak[k]+0>=15; else wm=1
      if(trig[i]=="stop_loss") { if(v && numeric(after[k])) good+=after[k]+0<=-5; else gm=1 }
    }
    if(trig[i]=="laggard_rotation") { if(v && numeric(peak[k])) regret+=peak[k]+0>=15; else rm=1 }
    if(trig[i]=="") { gm=1; rm=1 }
  }
  descending(positive,nw); descending(negative,nl); descending(ranked,n)
  printf "{\"year\":\"%s\",\"n\":%d,\"pnl\":%s,\"weight\":%s,\"win_rate\":%s",label,n,json(profit_ok?net:""),json(n && nav_ok?weights/n:""),json(n && profit_ok?100*nw/n:"")
  printf ",\"avg_win\":%s,\"avg_loss\":%s,\"payoff\":%s,\"expectancy\":%s,\"nav_pct\":%s",json(profit_ok && pct_ok && nw?wp/nw:""),json(profit_ok && pct_ok && nl?lp/nl:""),json(profit_ok && pct_ok && nw && nl && lp>0?(wp/nw)/(lp/nl):""),json(n && profit_ok && pct_ok?(wp-lp)/n:""),json(nav_ok?rel:"")
  printf ",\"top5\":%s,\"top10\":%s,\"top20\":%s",json(profit_ok?top_share(5,n,net):""),json(profit_ok?top_share(10,n,net):""),json(profit_ok?top_share(20,n,net):"")
  printf ",\"alphaW\":%s,\"alphaL\":%s",json(profit_ok?alpha(positive,nw):""),json(profit_ok?alpha(negative,nl):"")
  printf ",\"whipsaw\":%s,\"good_stop\":%s,\"rotation_regret\":%s,\"continuations\":%d}",json(wm?"":whip),json(gm?"":good),json(rm?"":regret),complete
}
END {
  if(!valid) { print "{\"available\":false,\"rows\":null}"; exit }
  for(i=1;i<=ny;i++) for(j=i+1;j<=ny;j++) if(labels[i]>labels[j]) { v=labels[i]; labels[i]=labels[j]; labels[j]=v }
  printf "{\"available\":true,\"rows\":["
  for(y=1;y<=ny;y++) { if(y>1) printf ","; row(labels[y]) }
  if(ny) printf ","
  row("All"); print "]}"
}
