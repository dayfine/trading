# For each reader transition A->B between consecutive cuts (A=from, B=to given as -v fr, to), find our stage at the
# reader's B cut; if ours is also B, report how many weeks earlier our current B run began.
FNR == 1 { fi++; next }
fi == 1 { k = $1; n[k]++; dd[k, n[k]] = days($2); ss[k, n[k]] = substr($5, 6, 1); next }
fi == 2 { if ($1 == ps && pr == fr && $3 == to) {
            d = days($2); cur = ""; start = ""
            for (i = 1; i <= n[$1]; i++) { if (dd[$1, i] > d + 6) break; if (ss[$1, i] != cur) { cur = ss[$1, i]; start = dd[$1, i] } }
            tot++
            if (cur == to) { m++; lag[m] = (d - start) / 7 } else other[cur]++ }
          ps = $1; pr = $3 }
END { for (i = 2; i <= m; i++) { t = lag[i]; j = i - 1; while (j >= 1 && lag[j] > t) { lag[j+1] = lag[j]; j-- }; lag[j+1] = t }
      printf "reader %s->%s transitions: %d; ours already in %s: %d; our run began a median %.0f weeks earlier (p25 %.0f, p75 %.0f, p90 %.0f)", fr, to, tot, to, m, lag[int((m+1)/2)], lag[int((m+3)/4)], lag[int((3*m+1)/4)], lag[int(0.9*m)]
      printf "; ours elsewhere:"; for (k in other) printf " %s=%d", k, other[k]; printf "\n" }
