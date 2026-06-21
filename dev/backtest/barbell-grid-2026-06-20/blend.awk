# blend.awk — barbell NAV blend + risk metrics.
# Usage: awk -v w=<floor_weight> -f blend.awk floor_equity.csv engine_equity.csv
#   floor_weight in [0,1]; blended daily return = w*floor_ret + (1-w)*engine_ret.
# Inputs: equity_curve.csv files (header "date,portfolio_value", date-ordered).
# Output (tab-separated, one line): w total_return% sharpe maxdd% calmar ulcer% n
#   sharpe = mean(ret)/popstd(ret)*sqrt(252); calmar = annret/maxdd;
#   ulcer = sqrt(mean(drawdown%^2)) over the blended NAV path.
BEGIN { FS=","; ann=252.0 }
FNR==1 { next }                       # skip header in both files
NR==FNR { f[$1]=$2+0; next }          # first file: floor[date]=value
{                                     # second file (engine), date-ordered
  d=$1; if (d in f) { date[++n]=d; fv[n]=f[d]; ev[n]=($2+0) }
}
END {
  if (n<3) { printf "%.2f\tNA\tNA\tNA\tNA\tNA\t%d\n", w, n; exit }
  nav=1.0; peak=1.0; maxdd=0.0; sum=0.0; sumsq=0.0; m=0; usum=0.0
  for (i=2;i<=n;i++) {
    fr=(fv[i]-fv[i-1])/fv[i-1]
    er=(ev[i]-ev[i-1])/ev[i-1]
    r=w*fr+(1-w)*er
    nav*=(1+r)
    sum+=r; sumsq+=r*r; m++
    if (nav>peak) peak=nav
    dd=(peak-nav)/peak                # fractional drawdown >=0
    if (dd>maxdd) maxdd=dd
    usum+=(dd*100)*(dd*100)
  }
  mean=sum/m
  var=sumsq/m-mean*mean; if (var<0) var=0
  sd=sqrt(var)
  sharpe=(sd>0)? mean/sd*sqrt(ann) : 0
  totret=(nav-1)*100
  annret=(nav>0)? (exp(log(nav)*(ann/m))-1) : -1   # nav^(252/m)-1
  calmar=(maxdd>0)? annret/maxdd : 0
  ulcer=sqrt(usum/m)
  printf "%.2f\t%.1f\t%.3f\t%.1f\t%.3f\t%.2f\t%d\n", w, totret, sharpe, maxdd*100, calmar, ulcer, n
}
