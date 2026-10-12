# usage: awk -F, -f join.awk O-trades.csv N-trades.csv ; key = symbol|entry_date ; col 9 = pnl_dollars
FNR==1{f++; next}
f==1{k=$1"|"$3; o[k]=$9; oy[k]=substr($3,1,4); next}
f==2{k=$1"|"$3; n[k]=$9; ny[k]=substr($3,1,4)}
END{for(k in o){ if(k in n){c++; cpo+=o[k]; cpn+=n[k]} else {l++; lp+=o[k]; ly[oy[k]]++; lyp[oy[k]]+=o[k]} }
 for(k in n) if(!(k in o)){g++; gp+=n[k]; gy[ny[k]]++; gyp[ny[k]]+=n[k]}
 printf "common %d (O pnl %.0f, N pnl %.0f) | lost(O only) %d pnl %.0f | gained(N only) %d pnl %.0f\n", c, cpo, cpn, l, lp, g, gp;
 for(y=2000;y<=2026;y++) if(ly[y]+gy[y]>0) printf "  %d lost %d (%.0f) gained %d (%.0f)\n", y, ly[y], lyp[y], gy[y], gyp[y]}
