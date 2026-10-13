function dn(s,   y, m, d) { y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0; if (m <= 2) { y--; m += 12 }; return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + d }
function friday(s,   x) { x = dn(s); return x + (FRI - x % 7 + 7) % 7 }
BEGIN{ FRI = dn("2000-01-07") % 7 }
NR>1 && $5+0>0 { nd++; dd[nd]=$1; raw6[nd]=$6 }
END{ nw=0; prev=-1
  for(j=1;j<=nd;j++){ fr=friday(dd[j]); if(fr!=prev){nw++; prev=fr}; wl[nw]=j; wcs[nw]=raw6[j] }
  for(w=1;w<=nw;w++) if(dd[wl[w]]==T) i=w
  # exact: adjusted closes as written in the file, scaled to integers of 1e-5
  a=0; b=0; for(q=i-29;q<=i;q++) a+=sprintf("%.0f", wcs[q]*100000); for(q=i-33;q<=i-4;q++) b+=sprintf("%.0f", wcs[q]*100000)
  printf "%s: sum30(i)=%d  sum30(i-4)=%d  (units 1e-5; equal => MA(i) <= MA(i-4) holds exactly)\n", T, a, b
  for(q=i-33;q<=i;q++) printf "%s ", wcs[q]; print ""
}
