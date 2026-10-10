# Paired v1 - v0 read at one salt (README item 3), joined on symbol|entry_date (fill date; position_id is not a
# cross-arm key). Gate 3 (validator_diff -check V6 exit 0) is checked by the caller from chain-B.log.
# Each v0-only trade is tagged with what v1 did with the same ticket: the v1 audit record for the same symbol and
# decision date (cancel reason), else "no v1 ticket". Each v1-only trade is tagged likewise against v0.
# files: 1 v0 trades.csv  2 v1 trades.csv  3 v0 audit.tsv  4 v1 audit.tsv  5 v0 entries_tr.txt (macro at fill)
# out: per unmatched trade a line, then a summary line.  -v SALT=<s>
BEGIN{ FS="," }
FILENAME==ARGV[1]{ if (FNR==1) next; k=$1 "|" $3; A[k]=$9+0; ap[k]=$20; ax[k]=$4; ae[k]=$6; na++; ta+=$9; next }
FILENAME==ARGV[2]{ if (FNR==1) next; k=$1 "|" $3; B[k]=$9+0; bp[k]=$20; bx[k]=$4; be[k]=$6; nb++; tb+=$9; next }
FILENAME==ARGV[3]{ split($0, f, "\t"); if (f[1]=="T") { adec[f[2]]=f[4]; asym[f[2]]=f[3]; aage[f[2]]=f[12]
    if (f[16]=="-") acan[f[3] "|" f[4]]=f[14] "@" f[13] "wk"; else afill[f[3] "|" f[4]]=1 } next }
FILENAME==ARGV[4]{ split($0, f, "\t"); if (f[1]=="T") { bdec[f[2]]=f[4]; bage[f[2]]=f[12]
    if (f[16]=="-") bcan[f[3] "|" f[4]]=f[14] "@" f[13] "wk"; else bfill[f[3] "|" f[4]]=1 } next }
FILENAME==ARGV[5]{ split($0, f, " "); mfill[f[2] "|" f[1]]=f[9]; next }
END{
  for (k in B) if (k in A) { nm++; d=B[k]-A[k]; md+=d; if (ae[k]!=be[k] || ax[k]!=bx[k]) ndiff++ }
  for (k in A) if (!(k in B)) { split(k, s, "|"); dk=s[1] "|" adec[ap[k]]
    why=(dk in bcan) ? "v1 cancelled " bcan[dk] : ((dk in bfill) ? "v1 filled same ticket on another date" : "no v1 ticket (path)")
    printf "S%s v0-only %s pnl %.0f age %s wk, screen at v0 fill %s; %s\n", SALT, k, A[k], aage[ap[k]], mfill[k], why
    no++; so+=A[k]; if (why ~ /^v1 cancelled/) { nc++; sc+=A[k] } }
  for (k in B) if (!(k in A)) { split(k, s, "|"); dk=s[1] "|" bdec[bp[k]]
    why=(dk in acan) ? "v0 cancelled " acan[dk] : ((dk in afill) ? "v0 filled same ticket on another date" : "no v0 ticket (path)")
    printf "S%s v1-only %s pnl %.0f age %s wk; %s\n", SALT, k, B[k], bage[bp[k]], why; n1++; s1+=B[k] }
  printf "S%s SUMMARY v0 %d trades %.0f | v1 %d trades %.0f | delta %.0f = matched %d (%.0f; %d with a different fill or exit) + v1-only %d (%.0f) - v0-only %d (%.0f; of which v1 cancelled the ticket: %d, %.0f)\n",
    SALT, na, ta, nb, tb, tb-ta, nm, md, ndiff+0, n1, s1, no, so, nc+0, sc
}
