FNR==1{fi++; next} fi==1{v0[$1]=$2; next} $5!="-" && $2>="2000-01-07"{k=civil(friday(days($2))); if(k in v0){n++; if(v0[k]==substr($5,6,1)) a++}} END{printf "%d %d\n", a, n}
