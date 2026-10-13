# per-group medians and beats; input "group,x1,x2,..." ; prints n, then for each column median and share>0
function qs(A,lo,hi,  i,last,t,p){ if(lo>=hi) return; p=int((lo+hi)/2); t=A[lo];A[lo]=A[p];A[p]=t; last=lo; for(i=lo+1;i<=hi;i++) if(A[i]<A[lo]){last++;t=A[last];A[last]=A[i];A[i]=t}; t=A[lo];A[lo]=A[last];A[last]=t; qs(A,lo,last-1); qs(A,last+1,hi) }
{ g=$1; n[g]++; for(c=2;c<=NF;c++){ v[g,c,n[g]]=$c+0; if($c+0>0) pos[g,c]++ }; nc=NF }
END{ for(g in n) { line=sprintf("%-10s n=%5d", g, n[g]); for(c=2;c<=nc;c++){ delete A; for(k=1;k<=n[g];k++) A[k]=v[g,c,k]; qs(A,1,n[g]); line=line sprintf(" | c%d med %+6.2f%% >0 %5.1f%%", c, 100*A[int(0.5*(n[g]-1))+1], 100*pos[g,c]/n[g]) } print line } }
