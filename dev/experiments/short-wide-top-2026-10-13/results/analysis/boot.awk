# week-cluster bootstrap of a share. input: cluster,x (x in {0,1}); B resamples; prints point, 2.5/97.5 pct
function qs(A,lo,hi,  i,last,t,p){ if(lo>=hi) return; p=int((lo+hi)/2); t=A[lo];A[lo]=A[p];A[p]=t; last=lo; for(i=lo+1;i<=hi;i++) if(A[i]<A[lo]){last++;t=A[last];A[last]=A[i];A[i]=t}; t=A[lo];A[lo]=A[last];A[last]=t; qs(A,lo,last-1); qs(A,last+1,hi) }
{ if (!($1 in id)) { nc++; id[$1] = nc }; c = id[$1]; n[c]++; s[c] += $2; N++; T += $2 }
END { srand(SEED); for (b = 1; b <= B; b++) { nn = 0; ss = 0; for (k = 1; k <= nc; k++) { c = int(rand() * nc) + 1; nn += n[c]; ss += s[c] }; R[b] = ss / nn }
  qs(R, 1, B); printf "%s: point %.1f%%  95%% CI [%.1f, %.1f]%%  (clusters %d, n %d)\n", LBL, 100*T/N, 100*R[int(0.025*B)+1], 100*R[int(0.975*B)], nc, N }
