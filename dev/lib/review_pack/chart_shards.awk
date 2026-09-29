# Per-trade chart data, sharded by entry year: OUT/<year>.json =
#   {"<pid>": {"w": [[week_date, close, ma, stage], ...],   (stage_chart replay CSV)
#              "d": [[date, o, h, l, c], ...]}, ...}        (adjusted daily bars)
# usage: awk -v STAGE_DIR=<dir> -v OUT=<dir> -f chart_shards.awk x_daily.tsv trades.csv
# A trade with no replay CSV gets "w": [] (the page then draws daily bars only).
FNR == 1 { fi++ }
fi == 1 { FS = "\t"; split($0, a, "\t")
          dy[a[1]] = dy[a[1]] (dy[a[1]] == "" ? "" : ",") sprintf("[\"%s\",%s,%s,%s,%s]", a[2], a[3] + 0, a[4] + 0, a[5] + 0, a[6] + 0); next }
fi == 2 && FNR > 1 {
  split($0, c, ","); pid = c[20]; yr = substr(c[3], 1, 4); f = OUT "/" yr ".json"; w = ""
  file = STAGE_DIR "/" pid ".png.csv"; n = 0
  while ((getline line < file) > 0) { n++; if (n == 1) continue; split(line, b, ",")
    w = w (w == "" ? "" : ",") sprintf("[\"%s\",%s,%s,\"%s\"]", b[2], b[3] + 0, b[4] + 0, b[5]) }
  close(file)
  if (!(yr in opened)) { opened[yr] = 1; printf "{" > f } else printf "," > f
  printf "\"%s\":{\"w\":[%s],\"d\":[%s]}", pid, w, dy[pid] > f
}
END { for (y in opened) printf "}\n" > (OUT "/" y ".json") }
