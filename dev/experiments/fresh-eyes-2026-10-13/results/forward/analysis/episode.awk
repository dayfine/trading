FNR==1 { fi++; next }
fi==1 { k = civil(friday(days($2))); os[k] = substr($5,6,1) "/" $6; om[k] = $4; next }
fi==2 { if ($1 == s) { rd[$2] = $3 "/" $4 }; next }
fi==3 { n++; w[n]=$1; h[n]=$3; l[n]=$4; c[n]=$5; m[n]=$7; r[n]=$8; v[n]=$6 }
END { for (i = 1; i <= n; i++) { if (w[i] < a || w[i] > b) continue
        ss = (m[i-5] > 0) ? sprintf("%+.2f%%", 100*(m[i]-m[i-5])/m[i-5]) : ""
        ws = (om[w[i-4]] > 0 && om[w[i]] > 0) ? sprintf("%+.2f%%", 100*(om[w[i]]-om[w[i-4]])/om[w[i-4]]) : ""
        av4 = (i > 4) ? (v[i-1]+v[i-2]+v[i-3]+v[i-4])/4 : 0
        vr = (av4 > 0) ? sprintf("%.1fx", v[i]/av4) : ""
        printf "%s H%8.3f L%8.3f C%8.3f sma%8.3f wma%7s ours%6s sma5%8s wma4%8s rs%7s vol%6s %s\n", w[i], h[i], l[i], c[i], m[i], om[w[i]], os[w[i]], ss, ws, r[i], vr, (w[i] in rd) ? "<< rd " rd[w[i]] : "" } }
