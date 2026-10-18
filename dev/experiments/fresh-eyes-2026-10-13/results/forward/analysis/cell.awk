function med(a, n,   i, j, t) { for (i = 2; i <= n; i++) { t = a[i]; j = i - 1; while (j >= 1 && a[j] > t) { a[j+1] = a[j]; j-- }; a[j+1] = t }; if (n == 0) return "na"; return (n % 2) ? a[(n+1)/2] : (a[n/2] + a[n/2+1]) / 2 }
NR == 1 { next }
$5 == "NA" { next }
{ k = $3 "/" $5; if (want != "" && index(" " want " ", " " k " ") == 0) next
  n[k]++
  if ($12 != "") { nw[k]++; ws[k, nw[k]] = $12 + 0; if ($12 > 0.005) wr[k]++; else if ($12 < -0.005) wd[k]++; else wf[k]++ }
  if ($15 != "") { ns[k]++; ss[k, ns[k]] = $15 + 0; if ($15 > 0.01) sr[k]++; else if ($15 < -0.01) sd[k]++; else sf[k]++ }
  if ($22 < 0) belowhi52[k]++; if ($21 < 0) belowhi26[k]++
  if ($23 > 0) abovelo26[k]++; if ($24 > 0) abovelo52[k]++
  wk[k, n[k]] = $6 + 0; if ($6 + 0 <= 4) le4[k]++
  if ($9 + 0 > 0) { if ($8 > $9) abovesma[k]++ }
  if ($29 > 0) bh[k]++; if ($30 > 0) bl[k]++
  if ($27 != "") { nf[k]++; f26[k, nf[k]] = $28 + 0 }
}
END {
  printf "%-8s %5s | %-26s | %-28s | %7s %7s %7s %7s | %6s %5s | %6s %6s\n", "cell", "n", "WMA4: med  rise/flat/decl %", "SMA5: med  rise/flat/decl %", "<hi52", "<hi26", ">lo26", ">abSMA", "wks", "<=4", "brkHi", "brkLo"
  for (k in n) {
    for (i = 1; i <= nw[k]; i++) t1[i] = ws[k, i]; m1 = med(t1, nw[k])
    for (i = 1; i <= ns[k]; i++) t2[i] = ss[k, i]; m2 = med(t2, ns[k])
    for (i = 1; i <= n[k]; i++) t3[i] = wk[k, i]; m3 = med(t3, n[k])
    printf "%-8s %5d | %+6.2f%% %4.0f/%4.0f/%4.0f      | %+6.2f%% %4.0f/%4.0f/%4.0f        | %6.0f%% %6.0f%% %6.0f%% %6.0f%% | %6.1f %4.0f%% | %5.0f%% %5.0f%%\n", k, n[k], 100*m1, 100*wr[k]/nw[k], 100*wf[k]/nw[k], 100*wd[k]/nw[k], 100*m2, 100*sr[k]/ns[k], 100*sf[k]/ns[k], 100*sd[k]/ns[k], 100*belowhi52[k]/n[k], 100*belowhi26[k]/n[k], 100*abovelo26[k]/n[k], 100*abovesma[k]/n[k], m3, 100*le4[k]/n[k], 100*bh[k]/n[k], 100*bl[k]/n[k]
  }
}
