# files: mem_v11 mem_v12 tradesA(v12 arm) tradesB(v11 arm). prints unmatched trades with membership status at entry
function ly(d,  y){ y=substr(d,1,4)+0; if(substr(d,6,5)<"05-31") y--; if(y<1999) y=1999; if(y>2025) y=2025; return y }
BEGIN{FS=","}
FILENAME==ARGV[1]{ m11[$1","$2]=1; any11[$2]=1; next }
FILENAME==ARGV[2]{ m12[$1","$2]=1; any12[$2]=1; next }
FILENAME==ARGV[3]{ if(FNR==1) next; k=$1"|"$3; A[k]=$9; Asym[k]=$1; Aed[k]=$3; Axd[k]=$4; next }
FILENAME==ARGV[4]{ if(FNR==1) next; k=$1"|"$3; B[k]=$9; Bsym[k]=$1; Bed[k]=$3; Bxd[k]=$4; next }
END{ for(k in A) if(!(k in B)){ s=Asym[k]; y=ly(Aed[k]); printf "v12-only,%s,%s,%s,%.0f,in_v11=%d,in_v12=%d,v11_ever=%d\n", s, Aed[k], Axd[k], A[k], (y","s in m11)+0, (y","s in m12)+0, (s in any11) }
     for(k in B) if(!(k in A)){ s=Bsym[k]; y=ly(Bed[k]); printf "v11-only,%s,%s,%s,%.0f,in_v11=%d,in_v12=%d,v12_ever=%d\n", s, Bed[k], Bxd[k], B[k], (y","s in m11)+0, (y","s in m12)+0, (s in any12) }
     for(k in A) if(k in B) nm++; printf "matched=%d\n", nm > "/dev/stderr" }
