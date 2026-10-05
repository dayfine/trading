# FILE1 = null trades, FILE2 = arm trades; key = symbol|entry_date
BEGIN{FS=","}
FNR==1{next}
FNR==NR{ k=$1"|"$3; N[k]=$9; NP[k]=$10; NX[k]=$4; next }
{ k=$1"|"$3; if (k in N) { sh++; dsh+=$9-N[k]; if ($9!=N[k]) chg[k]=$9-N[k]; seen[k]=1 } else { ao++; aop+=$9; print "  ARM_ONLY " $1 " " $3 "->" $4 " pnl=" $9 " (" $10 "%)" } }
END{ for (k in N) if (!(k in seen)) { no++; nop+=N[k]; split(k,z,"|"); print "  NULL_ONLY " z[1] " " z[2] "->" NX[k] " pnl=" N[k] " (" NP[k] "%)" }
     for (k in chg) print "  SHARED_CHG " k " d=" chg[k]
     printf "  shared=%d shared_dpnl=%.0f arm_only=%d pnl=%.0f null_only=%d pnl=%.0f\n", sh, dsh, ao, aop, no, nop }
