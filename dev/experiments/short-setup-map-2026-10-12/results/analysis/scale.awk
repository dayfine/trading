# Economic scale: hold length (bars) and hold-time-weighted excess (sum excess / sum bars x 252).
NR==1 { hdr(); next }
{ P = isP(); for (en = 1; en <= 2; en++) { e = "e" en; x = $(c[e "_o2_exc"]); if (x == "") continue; hb = $(c[e "_o2_bars"]) + 0; r = $(c[e "_o2_ret"]); xc = (x < -1) ? -1 : (x > 1 ? 1 : x)
    split((P ? "P" en : "-") " ALL" en, KK, " "); for (z = 1; z <= 2; z++) { k = KK[z]; if (k == "-") continue; add(k " hold", hb); SX[k] += x; SXc[k] += xc; SB[k] += hb; SR[k] += r; N[k]++ } } }
function holds(key,   n, k, A) { n = cnt[key]; for (k = 1; k <= n; k++) A[k] = v[key, k]; qs(A, 1, n); return sprintf("hold bars mean %.1f, p25 %d, median %d, p75 %d", sm[key]/n, q(A,n,.25), q(A,n,.5), q(A,n,.75)) }
END { split("P1 P2 ALL1 ALL2", L, " "); for (i = 1; i <= 4; i++) { k = L[i]
    printf "%-5s n=%5d %s | excess %+.1f%%/yr (clipped %+.1f%%/yr) | absolute short %+.1f%%/yr\n", k, N[k], holds(k " hold"), 100*252*SX[k]/SB[k], 100*252*SXc[k]/SB[k], 100*252*SR[k]/SB[k] } }
