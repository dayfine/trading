# upper tail P(X >= x) for hypergeometric(N, K, n)
function lchoose(a, b,   i, s) { if (b < 0 || b > a) return -1e300; s = 0; for (i = 1; i <= b; i++) s += log(a - b + i) - log(i); return s }
function ptail(N, K, n, x,   k, p, t) { p = 0; for (k = x; k <= n && k <= K; k++) { t = lchoose(K, k) + lchoose(N - K, n - k) - lchoose(N, n); p += exp(t) }; return p }
NR>1 && $1 !~ /-r/ && $2=="long" && $7>0 {
  e = $7*$4/$3; es = $5*$4/$3
  printf "%-12s pool %d ours %d (%.1f%%)  shortlist %d/%d (exp %.2f)  orders %d/%d (exp %.2f) P(X>=x)=%.3f\n", $1, $3, $4, 100*$4/$3, $6, $5, es, $8, $7, e, ptail($3,$4,$7,$8)
  O+=$8; E+=e; n+=$7; SO+=$6; SE+=es; SN+=$5; nd++; if ($8>0) pos++
  share[nd] = $8/$7
}
NR>1 && $1 !~ /-r/ && $2=="long" && $7==0 && $5>0 { SO2+=$6; SE2+=$5*$4/$3; SN2+=$5; nz++ }
END {
  printf "TOTAL long r0 dates with orders %d: orders in our list %d of %d (%.1f%%), expected at the pool base rate %.2f (%.1f%%); shortlist %d of %d (%.1f%%) expected %.2f; dates with >=1 overlap %d\n", nd, O, n, 100*O/n, E, 100*E/n, SO, SN, 100*SO/SN, SE, pos
  printf "long r0 dates with a shortlist but no orders %d: shortlist ours %d of %d, expected %.2f\n", nz, SO2, SN2, SE2
  # per-date share distribution
  for (i=2;i<=nd;i++){t=share[i];for(j=i-1;j>=1&&share[j]>t;j--)share[j+1]=share[j];share[j+1]=t}
  printf "per-date share of orders in our list: min %.2f p25 %.2f median %.2f p75 %.2f max %.2f\n", share[1], share[int(nd*.25)+1], (nd%2? share[(nd+1)/2] : (share[nd/2]+share[nd/2+1])/2), share[int(nd*.75)+1], share[nd]
}
