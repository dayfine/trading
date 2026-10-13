# Clustered bootstrap of a primary cell: -v cell=P1|P2 -v col=<outcome column> -v clu=week|quarter -v B=1000
NR==1 { hdr(); next }
{ if (!isP()) next; x = $(c[col]); if (x == "") next
  w = (clu == "quarter") ? substr($2,1,4) "Q" int((substr($2,6,2) + 2) / 3) : $2
  if (!(w in wi)) { nw++; wi[w] = nw; wn[nw] = 0 } j = wi[w]; wn[j]++; val[j, wn[j]] = x + 0; N++ }
END { srand(20261012)
  for (b = 1; b <= B; b++) { n = 0; s = 0; p = 0
    for (k = 1; k <= nw; k++) { j = int(rand() * nw) + 1; for (t = 1; t <= wn[j]; t++) { n++; Z[n] = val[j, t]; s += Z[n]; if (Z[n] > 0) p++ } }
    qs(Z, 1, n); bm[b] = q(Z, n, .5); bb[b] = p / n; bs[b] = s / n }
  qs(bm, 1, B); qs(bb, 1, B); qs(bs, 1, B)
  printf "%s %-10s %-7s events=%d clusters=%d | beat 95%% CI [%.1f, %.1f]%% | median [%+.2f, %+.2f]%% | mean [%+.2f, %+.2f]%%\n", cell, col, clu, N, nw, 100*bb[int(.025*B)+1], 100*bb[int(.975*B)], 100*bm[int(.025*B)+1], 100*bm[int(.975*B)], 100*bs[int(.025*B)+1], 100*bs[int(.975*B)] }
