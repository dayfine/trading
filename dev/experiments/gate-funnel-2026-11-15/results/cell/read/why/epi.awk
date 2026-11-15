$28>0 { t=days($1); if (last=="" || t-last>21) { e++; S[e]=$1 } E[e]=$1; X[e]+=$28; N[e]++; Z[e]+=($7==0); last=t; T+=$28 }
END { for (i=1;i<=e;i++) printf "%s\t%s\t%d\t%d\t%.4f\t%d\n", S[i], E[i], N[i], X[i], X[i]/T, Z[i] }
