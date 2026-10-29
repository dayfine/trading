#!/bin/sh
# review_pack.sh -- build a backtest review pack: a static site with the equity
# curve vs SPY, year/quarter tables, every trade with its chart, grade and
# execution/book flags, highlights, diagnostics and a cross-salt comparison.
#
# usage:
#   sh dev/scripts/review_pack.sh --out DIR [options] LABEL=PREFIX [LABEL=PREFIX ...]
#
#   LABEL=PREFIX  one run. PREFIX is the path prefix of the run's output files
#                 (PREFIXtrades.csv, PREFIXequity_curve.csv, PREFIXsummary.sexp,
#                 PREFIXparams.sexp, PREFIXmacro_trend.sexp, PREFIXvalidator.sexp.md,
#                 PREFIXtrade_audit.sexp, ...), e.g.
#                   s0=.sweep-output/pit-null/a0-pit-null-s0-v11-
#                 or a directory ending in "/" that holds the unprefixed files.
#   --out DIR          output root (must be inside the repo when container steps
#                      run, so trading-1-dev sees it); the site lands in DIR/site
#   --title T          page title        (default "Backtest Review")
#   --subtitle S       page subtitle     (default: window + universe from params)
#   --charts-run N     0-based run that gets per-trade charts + flags (default 0)
#   --snapshot-dir W   snapshot warehouse for trade_audit_report (container path,
#                      default /tmp/snap_top3000_pit_v11pit); missing -> audit skipped
#   --data-dir D       CSV bar store (default <repo>/data)
#   --run-kind K       salt | seed | arm | auto (default auto): salts are one config under
#                      different path seeds, seeds are one config under different screener
#                      tie-order seeds, arms are different configs; the page words its
#                      comparison accordingly. auto = seed when every label is k<N>, else
#                      salt when every label is <base>s<N> with one shared base (s0 s1,
#                      null-s0 null-s1), else arm
#   --no-container     skip the three docker steps (audit report, stage replay,
#                      their build): the site still builds, without conformance
#                      rows, audit fields or weekly stage overlays
#
# Steps, all re-runnable (each overwrites its own outputs; the stage replay
# skips trades already replayed):
#   1. stage   copy each run's files into DIR/runs/<label>/ without the prefix
#   2. docker  build + run trade_audit_report per run and stage_chart per trade
#              of the charts run (~1.3 s/trade)          [skipped: --no-container]
#   3. host    per-trade extraction over the CSV bar store, period tables,
#              join, then DIR/site/{index.html,data/*.json}
#
# Publish: point the Artifact tool at DIR/site/index.html with DIR/site/data/*
# as supporting files, or open it through any static file server (the page
# fetches data/ relative to itself, so file:// does not work).
set -eu

LIB="$(cd "$(dirname "$0")/../lib/review_pack" && pwd)"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CONTAINER="${CONTAINER:-trading-1-dev}"
MOUNT=/workspaces/trading-1   # where the container bind-mounts the host checkout; CROOT is set from it
. "$LIB/croot.sh"
. "$LIB/pack_sha.sh"
REGIME_WARMUP_ROWS=180   # SPY bars published before the window for the regime warm-up (#3194)

OUT=""; TITLE="Backtest Review"; SUBTITLE=""; CHARTS=0
SNAP=/tmp/snap_top3000_pit_v11pit; DATA="$REPO/data"; DOCKER=1; RUNS=""; RUN_KIND=auto
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT=$2; shift 2 ;;
    --title) TITLE=$2; shift 2 ;;
    --subtitle) SUBTITLE=$2; shift 2 ;;
    --charts-run) CHARTS=$2; shift 2 ;;
    --snapshot-dir) SNAP=$2; shift 2 ;;
    --data-dir) DATA=$2; shift 2 ;;
    --run-kind) RUN_KIND=$2; shift 2 ;;
    --no-container) DOCKER=0; shift ;;
    -h|--help) sed -n '2,43p' "$0"; exit 0 ;;
    *=*) RUNS="$RUNS $1"; shift ;;
    *) echo "review_pack: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$OUT" ] && [ -n "$RUNS" ] || { echo "usage: review_pack.sh --out DIR LABEL=PREFIX ..." >&2; exit 2; }
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
SPY_CSV="$DATA/S/Y/SPY/data.csv"
[ -f "$SPY_CSV" ] || { echo "review_pack: no SPY bars at $SPY_CSV" >&2; exit 2; }

log() { printf '[review_pack %s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
labels() { for r in $RUNS; do printf '%s\n' "${r%%=*}"; done; }
run_kind() { # salt | seed | arm: auto = seed when every label is k<N>; salt when every label is <base>s<N> with one shared base (#3149)
  case "$RUN_KIND" in salt|seed|arm) echo "$RUN_KIND"; return ;; esac
  [ "$(labels | grep -cvE '^k[0-9]+$')" = 0 ] && { echo seed; return; }
  [ "$(labels | grep -cvE '(^|[^A-Za-z0-9])s[0-9]+$')" = 0 ] && [ "$(labels | sed -E 's/s[0-9]+$//' | sort -u | wc -l | tr -d ' ')" = 1 ] && echo salt || echo arm
}
charts_label() { labels | sed -n "$((CHARTS + 1))p"; }

# ---- 1. stage ---------------------------------------------------------------
stage_run() { # $1 label, $2 prefix
  d="$OUT/runs/$1"; mkdir -p "$d"
  case "$2" in
    */) for f in "$2"*; do [ -f "$f" ] && cp "$f" "$d/"; done ;;
    *) for f in "$2"*; do [ -f "$f" ] && cp "$f" "$d/${f#"$2"}"; done ;;
  esac
  [ -s "$d/trades.csv" ] || { echo "review_pack: $1: no trades.csv under prefix $2" >&2; exit 2; }
}

spy_covers_runs() { # SPY bars must start by every run's first equity date (#3262, from #3214): nav_json keeps a
  # NAV row only on a SPY bar day, so a short SPY series silently cut a 2000-2026 run to 2009 on the charts
  sf=$(sed -n 2p "$SPY_CSV" | cut -d, -f1)
  for l in $(labels); do
    rf=$(sed -n 2p "$OUT/runs/$l/equity_curve.csv" | cut -d, -f1)
    [ -z "$rf" ] || ! awk -v a="$sf" -v b="$rf" 'BEGIN { exit !(a > b) }' || { echo "review_pack: SPY bars at $SPY_CSV start $sf, after run $l's first equity date $rf; the NAV chart and every SPY comparison would start at $sf. Pass a --data-dir whose SPY covers the window." >&2; exit 2; }
  done
}

# ---- 2. docker ----------------------------------------------------------------
container_path() { # host path -> container path (must sit under the repo)
  case "$1" in "$REPO"/*) printf '%s%s' "$CROOT" "${1#"$REPO"}" ;; *) return 1 ;; esac
}
docker_steps() {
  # this checkout's container path, not the mount root: a worktree builds and runs its own tree (#3262)
  src=$(mount_source "$CONTAINER" "$MOUNT"); [ -n "$src" ] || { src=$REPO; log "docker: no mount at $MOUNT found by docker inspect; assuming it is $REPO"; }
  CROOT=$(croot_for "$src" "$REPO" "$MOUNT") || { echo "review_pack: $REPO is not under $src, the directory $CONTAINER mounts at $MOUNT" >&2; exit 2; }
  cdata=$(croot_for "$src" "$DATA" "$MOUNT") || { cdata=$MOUNT/data; log "docker: --data-dir $DATA is outside the mount; the stage replay reads $cdata"; }
  cout=$(container_path "$OUT") || { echo "review_pack: --out must be inside $REPO for container steps (or pass --no-container)" >&2; exit 2; }
  log "docker: building trade_audit_report_bin + stage_chart"
  docker exec "$CONTAINER" bash -c "cd $CROOT/trading && eval \$(opam env) && dune build trading/backtest/bin/trade_audit_report_bin.exe analysis/scripts/stage_chart/bin/stage_chart.exe" >&2
  for l in $(labels); do
    log "docker: trade audit report $l"
    docker exec "$CONTAINER" bash -c "[ -d $SNAP ] || exit 3; $CROOT/trading/_build/default/trading/backtest/bin/trade_audit_report_bin.exe --scenario-dir $cout/runs/$l --snapshot-dir $SNAP --out $cout/runs/$l/trade_audit_report.md --html $cout/runs/$l/trade_audit_report.html --benchmark-symbol SPY" > "$OUT/runs/$l/audit.log" 2>&1 \
      || log "audit $l failed or no snapshot dir (see runs/$l/audit.log); continuing without it"
    [ -s "$OUT/runs/$l/trade_audit_report.md" ] || log "WARNING: $l: trade_audit_report.md is missing or empty, so the conformance panel and the audit cards read n/a (runs/$l/audit.log)"
  done
  cl=$(charts_label); log "docker: stage replay for $cl ($(($(wc -l < "$OUT/runs/$cl/trades.csv") - 1)) trades)"
  docker exec "$CONTAINER" sh "$CROOT/dev/lib/review_pack/stages.sh" "$CROOT" "${cout#"$CROOT"/}/runs/$cl" "$cdata"
}

# ---- 3. host ------------------------------------------------------------------
extract_run() { # $1 run dir, $2 1 = also write daily chart bars
  d=$1; : > "$d/x_trades.tsv"; : > "$d/x_expo.tsv"; : > "$d/x_daily.tsv"
  dy=""; [ "$2" = 1 ] && dy="$d/x_daily.tsv"
  tail -n +2 "$d/trades.csv" | while IFS=, read -r sym side ed xd _days ep xp qty _pnl _pct es _xs _trig _stg _vr sid rest; do
    pid=$(echo "$rest" | cut -d, -f4)
    f=$(sym_csv "$sym")
    if [ ! -f "$f" ]; then printf '%s\tNOFILE\n' "$pid" >> "$d/x_trades.tsv"; continue; fi
    awk -v pid="$pid" -v side="$side" -v ed="$ed" -v xd="$xd" -v ep="$ep" -v xp="$xp" -v qty="$qty" -v sid="${sid:-0}" -v es="${es:-0}" \
        -v out_tr="$d/x_trades.tsv" -v out_ex="$d/x_expo.tsv" -v out_dy="$dy" -f "$LIB/trade_extract.awk" "$f"
  done
  extract_open "$d"
}
sym_csv() { printf '%s/%s/%s/%s/data.csv' "$DATA" "$(printf %s "$1" | cut -c1)" "$(printf %s "$1" | rev | cut -c1)" "$1"; }
extract_open() { # $1 run dir: positions still held at the window end join the exposure series (#3125)
  d=$1; : > "$d/x_open.tsv"; [ -s "$d/open_positions.csv" ] || return 0
  last=$(tail -1 "$d/equity_curve.csv" | cut -d, -f1)
  tail -n +2 "$d/open_positions.csv" | while IFS=, read -r sym side ed ep qty _rest; do
    printf '%s\t%s\t%s\t%s\t%s\n' "$sym" "$ed" "$ep" "$qty" "$side" >> "$d/x_open.tsv"
    f=$(sym_csv "$sym"); [ -f "$f" ] || continue
    awk -v pid="open:$sym:$ed" -v ed="$ed" -v last="$last" -v qty="$qty" -v out_ex="$d/x_expo.tsv" -f "$LIB/open_extract.awk" "$f"
  done
}
open_json() { # $1 run dir -> <run>_open.json: open rows + the last-day exposure check vs actual.sexp
  d=$1; last=$(tail -1 "$d/equity_curve.csv" | cut -d, -f1); act=""
  [ -f "$d/actual.sexp" ] && act=$(grep -oE 'open_positions_value [-0-9.e]+' "$d/actual.sexp" | cut -d' ' -f2)
  awk -v last="$last" -v actual="$act" -f "$LIB/open_json.awk" "$d/x_open.tsv" "$d/x_macro.tsv" "$d/x_expo.tsv"
}
audit_rows() { # per-trade table of the audit report -> sym entry rs macro grade score fill_vs_trig faithful
  [ -s "$1/trade_audit_report.md" ] || return 0
  sed -n '/## Per-trade table/,/^## Split/p' "$1/trade_audit_report.md" \
    | awk -F'|' 'NR>4 && NF>15 { for (i=2;i<=18;i++) gsub(/^ +| +$/,"",$i); printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",$2,$3,$13,$14,$15,$16,$17,$18 }' | sed 's/%//'
}
stop_floor_kinds() { # trade_audit.sexp -> pid<TAB>stop_floor_kind (Support_floor | Buffer_fallback) per entry (#3149)
  [ -s "$1/trade_audit.sexp" ] || return 0
  awk 'match($0, /\(position_id [^)]+\)/) { pid = substr($0, RSTART + 13, RLENGTH - 14) }
    match($0, /\(stop_floor_kind [A-Za-z_]+\)/) { if (pid != "") printf "%s\t%s\n", pid, substr($0, RSTART + 17, RLENGTH - 18); pid = "" }' "$1/trade_audit.sexp"
}
nav_json() { # daily [date, nav, invested % of nav, open positions]
  # A weekday with no SPY bar (inside SPY's range) is a market holiday: the NAV is carried
  # forward and no position has a bar, so the row would read 0 % invested. Dropped (#3125).
  # files told apart by ARGV, not an FNR==1 counter: an empty x_expo.tsv must not shift them
  awk 'FILENAME==ARGV[1]{if(FNR>1){split($0,a,","); spy[a[1]]=1; if(a[1]>sl) sl=a[1]} next}
       FILENAME==ARGV[2]{split($0,a,"\t"); ex[a[1]]+=a[2]; np[a[1]]++; next}
       FNR>1{split($0,a,","); if(!(a[1] in spy) && a[1]<=sl) next; v=a[2]+0; printf "%s[\"%s\",%.0f,%.1f,%d]", (n++?",":"["), a[1], v, (v>0?100*ex[a[1]]/v:0), np[a[1]]}
       END{if(!n) printf "["; print "]"}' "$SPY_CSV" "$1/x_expo.tsv" "$1/equity_curve.csv"
}
host_run() { # $1 label, $2 index
  d="$OUT/runs/$1"; s="$OUT/site/data"; is_ch=0; [ "$2" = "$CHARTS" ] && is_ch=1
  log "host: $1 extract ($(($(wc -l < "$d/trades.csv") - 1)) trades)"
  extract_run "$d" "$is_ch"
  sed -nE 's/.*\(date ([0-9-]+)\) \(trend ([A-Za-z]+)\) \(breadth_state ([A-Za-z_]+)\).*/\1	\2	\3/p' "$d/macro_trend.sexp" > "$d/x_macro.tsv"
  # the year/quarter SPY column on the run's own basis (#3177): price-only runs read close, else adjusted_close
  sh "$LIB/meta.sh" "$d" > "$s/$1_meta.json"
  spycol=6; grep -q '"spy":"price"' "$s/$1_meta.json" && spycol=5
  for g in Y Q; do awk -v gran=$g -v spycol=$spycol -f "$LIB/periods.awk" "$SPY_CSV" "$d/equity_curve.csv" "$d/x_expo.tsv" "$d/trades.csv" "$d/x_macro.tsv" > "$d/x_p$g.json"; done
  audit_rows "$d" > "$d/x_audit.tsv"
  if [ -d "$d/stage" ]; then sh "$LIB/stage_sum.sh" "$d" > "$d/x_stage.tsv"; else : > "$d/x_stage.tsv"; fi
  stop_floor_kinds "$d" > "$d/x_sfk.tsv"
  awk -f "$LIB/assemble.awk" "$d/trades.csv" "$d/x_trades.tsv" "$d/x_audit.tsv" "$d/x_macro.tsv" "$d/x_stage.tsv" "$d/x_sfk.tsv" > "$s/$1_trades.json"
  cp "$d/x_pY.json" "$s/$1_years.json"; cp "$d/x_pQ.json" "$s/$1_quarters.json"
  nav_json "$d" > "$s/$1_nav.json"
  sh "$LIB/peak_gains.sh" "$DATA" "$d" > "$s/$1_peaks.json"
  open_json "$d" > "$s/$1_open.json"
  sh "$LIB/missed_winners.sh" "$DATA" "$d" > "$s/$1_missed.json"
  sh "$LIB/pnl_anatomy.sh" "$d" > "$s/$1_anatomy.json"
  sh "$LIB/faithfulness.sh" "$s/$1_trades.json" "$FAITH_DROP" > "$s/$1_faithfulness.json"
  # the detector: more than $1 and 1 % apart -> a warning line, and the page's findings say so
  jq -r 'def abs: if . < 0 then -. else . end;
    .check | select(.actual != null) | ((.pack - .actual) | abs) as $e
    | select($e > 1 and $e > 0.01 * ([.pack, .actual] | map(abs) | max))
    | "WARN open positions on \(.date): pack marks \(.pack + 0), actual.sexp open_positions_value \(.actual + 0)"' "$s/$1_open.json" |
    while IFS= read -r w; do log "$1: $w"; done
}
site_common() {
  s="$OUT/site/data"; cl=$(charts_label); d="$OUT/runs/$cl"
  first=$(sed -n 2p "$d/equity_curve.csv" | cut -d, -f1); last=$(tail -1 "$d/equity_curve.csv" | cut -d, -f1)
  # %.4f: the store writes values like "741." which strict JSON rejects
  # spy.json total return (adjusted_close), spy_price.json price only (close): the page picks by basis (#3177)
  for c in 6:spy 5:spy_price; do
    awk -F, -v a="$first" -v b="$last" -v col="${c%%:*}" 'NR>1 && $1>=a && $1<=b && $col+0>0 {printf "%s[\"%s\",%.4f]", (n++?",":"["), $1, $col+0} END{print "]"}' "$SPY_CSV" > "$s/${c#*:}.json"
  done
  # the regime's warm-up (#3194): the REGIME_WARMUP_ROWS SPY bars before the window, [date, adjusted_close,
  # close], read by the page for the regime only. 180 bars span at least 35 weeks (at most 5 a week), so the
  # 30-week MA and its 4-week slope (34 weekly closes) exist on the window's first day.
  awk -F, -v a="$first" -v k="$REGIME_WARMUP_ROWS" 'NR>1 && $1<a && $6+0>0 && $5+0>0 { r[n++ % k] = sprintf("[\"%s\",%.4f,%.4f]", $1, $6+0, $5+0) }
    END { m = n < k ? n : k; printf "["; for (i = n - m; i < n; i++) printf "%s%s", (i > n - m ? "," : ""), r[i % k]; print "]" }' "$SPY_CSV" > "$s/spy_warmup.json"
  awk -F'\t' '{printf "%s[\"%s\",\"%s\",\"%s\"]", (n++?",":"["), $1,$2,$3} END{print "]"}' "$d/x_macro.tsv" > "$s/macro.json"
  rm -rf "$s/charts"; mkdir -p "$s/charts"
  awk -v STAGE_DIR="$d/stage" -v OUT="$s/charts" -f "$LIB/chart_shards.awk" "$d/x_daily.tsv" "$d/trades.csv"
  [ -n "$SUBTITLE" ] || SUBTITLE="$first → $last, $(grep -oE 'universe_size [0-9]+' "$d/params.sexp" | cut -d' ' -f2) symbols, \$$(grep -oE 'initial_cash [0-9]+' "$d/params.sexp" | cut -d' ' -f2) start"
  # jq --arg does the JSON escaping: a title/subtitle/label with " or \ must not break the manifest
  # the page header stamps the pack code and the snapshot dir the audit read (#3262): a stale tree is visible
  snap_used=""; [ "$DOCKER" = 1 ] && snap_used=$SNAP
  runs_json=$(labels | jq -R -s -c 'split("\n") | map(select(length > 0) | {id: ., label: .})')
  jq -n --arg title "$TITLE" --arg subtitle "$SUBTITLE" --argjson charts "$CHARTS" --argjson runs "$runs_json" --arg kind "$(run_kind)" \
    --arg pack_sha "$(pack_sha "$REPO")" --arg snap "$snap_used" \
    '{title: $title, subtitle: $subtitle, charts_run: $charts, runs: $runs, run_kind: $kind, pack_sha: $pack_sha, snapshot_dir: $snap}' > "$s/manifest.json"
  # the page <title> carries --title (HTML-escaped); the template default is a placeholder
  TITLE="$TITLE" awk -v career="$LIB/career_scorecard.js" 'BEGIN { t = ENVIRON["TITLE"]; gsub(/&/, "\\&amp;", t); gsub(/</, "\\&lt;", t); gsub(/>/, "\\&gt;", t) }
    /^\/\* career-scorecard helper \*\/$/ { while ((getline line < career) > 0) print line; close(career); next }
    /^<title>.*<\/title>$/ { print "<title>" t "</title>"; next } { print }' "$LIB/index.html" > "$OUT/site/index.html"
}
check_json() {
  command -v jq >/dev/null 2>&1 || { log "jq not found; skipped the JSON check"; return 0; }
  bad=0; for f in "$OUT"/site/data/*.json "$OUT"/site/data/charts/*.json; do
    [ -e "$f" ] || continue; jq -e 'true' "$f" >/dev/null 2>&1 || { echo "review_pack: invalid JSON: $f" >&2; bad=1; }
  done; return $bad
}

for r in $RUNS; do stage_run "${r%%=*}" "${r#*=}"; done
spy_covers_runs
[ "$DOCKER" = 1 ] && docker_steps
mkdir -p "$OUT/site/data"
# The stage replay (~1.3 s per trade) runs for the charts run only, so checks 1 and 13 are measured for that
# run alone. When some runs have a replay and others do not, every run is graded without them, so the grades
# compare the same evidence; the faithfulness tab says which checks were dropped.
FAITH_DROP=""; with_stage=0; for l in $(labels); do [ -d "$OUT/runs/$l/stage" ] && with_stage=$((with_stage + 1)); done
[ "$with_stage" -gt 0 ] && [ "$with_stage" -lt "$(labels | wc -l | tr -d ' ')" ] && FAITH_DROP="1,13"
[ -z "$FAITH_DROP" ] || log "faithfulness: only $with_stage of $(labels | wc -l | tr -d ' ') runs have a stage replay; grading every run without checks 1 and 13"
i=0; for l in $(labels); do host_run "$l" "$i"; i=$((i + 1)); done
site_common
check_json
log "done: $OUT/site/index.html ($(du -sh "$OUT/site" | cut -f1))"
