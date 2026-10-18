FNR==1 { fi++; next }
fi==1 { k = civil(friday(days($2))); st[k] = substr($5,6,1); next }
fi==2 { n++; w[n]=$1; c[n]=$5+0; h[n]=$3+0; l[n]=$4+0 }
END { for (i = 53; i <= n; i++) { if (w[i] < "2000-01-07") continue
        if (st[w[i]] == 4 && st[w[i-1]] == 3) {
          hi = 0; lo = 1e18; lo10 = 1e18
          for (j = 1; j <= 52; j++) { if (c[i-j] > hi) hi = c[i-j] }
          for (j = 1; j <= 26; j++) { if (c[i-j] < lo) lo = c[i-j] }
          for (j = 1; j <= 10; j++) { if (c[i-j] < lo10) lo10 = c[i-j] }
          printf "%s,%s,%.4f,%.4f,%.4f\n", sym, w[i], c[i]/hi-1, c[i]/lo-1, c[i]/lo10-1 } } }
