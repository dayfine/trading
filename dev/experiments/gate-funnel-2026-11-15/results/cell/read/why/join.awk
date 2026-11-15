# join fridays.tsv with macro, spy regime (prior week), positions held, gate-reopen age
FILENAME==ARGV[1] { MT[$1]=$2; MB[$1]=$3; ALLD[++nd]=$1; next }
FILENAME==ARGV[2] { SR[$1]=$2; next }
FILENAME==ARGV[3] { nh++; HE[nh]=$1; HX[nh]=$2; next }
FNR==1 { next }
{ F[$1]=$0 }
END {
  age=0
  for (i=1;i<=nd;i++) { d=ALLD[i]
    if (MT[d]=="Bearish") { age=0; continue }
    age++
    if (!(d in F)) { print "MISSING " d > "/dev/stderr"; continue }
    split(F[d], c, "\t")
    h=0; for (j=1;j<=nh;j++) if (HE[j]<=d && d<HX[j]) h++
    reg=SR[week_of(d)-1]; if (reg=="") reg="NA"
    print d "\t" substr(d,1,4) "\t" MT[d] "\t" MB[d] "\t" reg "\t" age "\t" h "\t" F[d]
  }
}
