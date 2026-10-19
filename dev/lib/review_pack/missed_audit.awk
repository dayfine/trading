# Stream the cascade_summaries subtree only; accept pretty or compact sexps.
# TSV: W date placed has_decisions; D date symbol outcome. Never infer missing
# pre-#3139 decisions from the presence of an audit file.
function atom(s) {
  if(key[depth]=="") { key[depth]=s; if(s=="cascade_summaries") base=depth; if(base && s=="decisions") { dec=depth; hasdec=1 } }
  else val[depth]=val[depth] (val[depth]!=""?" ":"") s
}
function close_list(   k,v) {
  k=key[depth]; v=val[depth]
  if(base) {
    if(k=="date" && depth==base+3) date=v
    if(dec && depth==dec+3 && k=="symbol") sym=v
    if(dec && depth==dec+3 && k=="side") side=v
    if(dec && depth==dec+3 && k=="outcome") outcome=v
    if(dec && depth==dec+2 && side=="Long") { printf "D\t%s\t%s\t%s\n",date,sym,outcome; if(outcome=="Placed") placed++; sym=side=outcome="" }
    if(depth==dec) dec=0
    if(depth==base+2) { printf "W\t%s\t%d\t%d\n",date,placed,hasdec; date=""; placed=hasdec=0 }
    if(depth==base) base=0
  }
  delete key[depth]; delete val[depth]; depth--
  if(depth && k!="" && key[depth]=="") key[depth]=k
  else if(depth && k!="" && key[depth]=="outcome") val[depth]=k (v!=""?" " v:"")
}
{
  for(pos=1;pos<=length($0);pos++) {
    ch=substr($0,pos,1)
    if(quoted) {
      if(escaped) { token=token ch; escaped=0 }
      else if(ch=="\\") escaped=1
      else if(ch=="\"") { quoted=0; atom(token); token="" }
      else token=token ch
    } else if(ch=="\"") quoted=1
    else if(ch=="(" || ch==")" || ch ~ /[ \t\r]/) {
      if(token!="") { atom(token); token="" }
      if(ch=="(") depth++
      else if(ch==")") close_list()
    } else token=token ch
  }
  if(!quoted && token!="") { atom(token); token="" }
}
