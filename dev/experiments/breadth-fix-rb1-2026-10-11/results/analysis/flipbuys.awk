# N placements decided in weeks where O read Bearish and N did not (unlocked weeks), by period; P&L of those that filled
FILENAME ~ /macro_ON/ { if($2=="Bearish" && $5!="Bearish") unl[$1]=$5; if($5=="Bearish" && $2!="Bearish") lock[$1]=1; next }
FILENAME ~ /aud_/ { pid=$1; dec=$3; if(dec in unl){ y=substr(dec,1,4); p=(y<=2002?"2000-02":(y<=2007?"2003-07":(y<=2009?"2008-09":"2010-16"))); np[p]++; st[pid]=p; if($10=="filled") nf[p]++; else nc[p" "$10]++ } next }
FNR==1{next}
{ split($0,a,","); pid=a[20]; if(pid in st){ p=st[pid]; pn[p]+=a[9]; nt[p]++; if(a[9]>0) w[p]++ } }
END{ for(p in np) printf "  %s: placed %d, filled %d (closed trades %d, win %d, pnl %.0f); cancelled: %s %s %s\n", p, np[p], nf[p], nt[p], w[p], pn[p], (nc[p" entry_fill_rejected_by_portfolio"]+0)" cash", (nc[p" entry_ticket_ttl_expired"]+0)" ttl", (nc[p" delisted"]+0)" delisted" }
