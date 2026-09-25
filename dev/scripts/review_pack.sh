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
CROOT=/workspaces/trading-1

OUT=""; TITLE="Backtest Review"; SUBTITLE=""; CHARTS=0
SNAP=/tmp/snap_top3000_pit_v11pit; DATA="$REPO/data"; DOCKER=1; RUNS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT=$2; shift 2 ;;
    --title) TITLE=$2; shift 2 ;;
    --subtitle) SUBTITLE=$2; shift 2 ;;
    --charts-run) CHARTS=$2; shift 2 ;;
    --snapshot-dir) SNAP=$2; shift 2 ;;
    --data-dir) DATA=$2; shift 2 ;;
    --no-container) DOCKER=0; shift ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
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

# ---- 2. docker ----------------------------------------------------------------
container_path() { # host path -> container path (must sit under the repo)
  case "$1" in "$REPO"/*) printf '%s%s' "$CROOT" "${1#"$REPO"}" ;; *) return 1 ;; esac
}
docker_steps() {
  cout=$(container_path "$OUT") || { echo "review_pack: --out must be inside $REPO for container steps (or pass --no-container)" >&2; exit 2; }
  log "docker: building trade_audit_report_bin + stage_chart"
  docker exec "$CONTAINER" bash -c "cd $CROOT/trading && eval \$(opam env) && dune build trading/backtest/bin/trade_audit_report_bin.exe analysis/scripts/stage_chart/bin/stage_chart.exe" >&2
  for l in $(labels); do
    log "docker: trade audit report $l"
    docker exec "$CONTAINER" bash -c "[ -d $SNAP ] || exit 3; $CROOT/trading/_build/default/trading/backtest/bin/trade_audit_report_bin.exe --scenario-dir $cout/runs/$l --snapshot-dir $SNAP --out $cout/runs/$l/trade_audit_report.md --html $cout/runs/$l/trade_audit_report.html --benchmark-symbol SPY" > "$OUT/runs/$l/audit.log" 2>&1 \
      || log "audit $l failed or no snapshot dir (see runs/$l/audit.log); continuing without it"
  done
  cl=$(charts_label); log "docker: stage replay for $cl ($(($(wc -l < "$OUT/runs/$cl/trades.csv") - 1)) trades)"
  docker exec "$CONTAINER" sh "$CROOT/dev/lib/review_pack/stages.sh" "$CROOT" "${cout#"$CROOT"/}/runs/$cl"
}

# ---- 3. host ------------------------------------------------------------------
extract_run() { # $1 run dir, $2 1 = also write daily chart bars
  d=$1; : > "$d/x_trades.tsv"; : > "$d/x_expo.tsv"; : > "$d/x_daily.tsv"
  dy=""; [ "$2" = 1 ] && dy="$d/x_daily.tsv"
  tail -n +2 "$d/trades.csv" | while IFS=, read -r sym _side ed xd _days ep xp qty _pnl _pct _es _xs _trig _stg _vr sid rest; do
    pid=$(echo "$rest" | cut -d, -f4)
    f="$DATA/$(printf %s "$sym" | cut -c1)/$(printf %s "$sym" | rev | cut -c1)/$sym/data.csv"
    if [ ! -f "$f" ]; then printf '%s\tNOFILE\n' "$pid" >> "$d/x_trades.tsv"; continue; fi
    awk -v pid="$pid" -v ed="$ed" -v xd="$xd" -v ep="$ep" -v xp="$xp" -v qty="$qty" -v sid="${sid:-0}" \
        -v out_tr="$d/x_trades.tsv" -v out_ex="$d/x_expo.tsv" -v out_dy="$dy" -f "$LIB/trade_extract.awk" "$f"
  done
}
audit_rows() { # per-trade table of the audit report -> sym entry rs macro grade score fill_vs_trig faithful
  [ -s "$1/trade_audit_report.md" ] || return 0
  sed -n '/## Per-trade table/,/^## Split/p' "$1/trade_audit_report.md" \
    | awk -F'|' 'NR>4 && NF>15 { for (i=2;i<=18;i++) gsub(/^ +| +$/,"",$i); printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",$2,$3,$13,$14,$15,$16,$17,$18 }' | sed 's/%//'
}
nav_json() { # daily [date, nav, invested % of nav, open positions]
  awk 'FNR==1{fi++} fi==1{split($0,a,"\t"); ex[a[1]]+=a[2]; np[a[1]]++; next}
       fi==2&&FNR>1{split($0,a,","); v=a[2]+0; printf "%s[\"%s\",%.0f,%.1f,%d]", (n++?",":"["), a[1], v, (v>0?100*ex[a[1]]/v:0), np[a[1]]}
       END{print "]"}' "$1/x_expo.tsv" "$1/equity_curve.csv"
}
host_run() { # $1 label, $2 index
  d="$OUT/runs/$1"; s="$OUT/site/data"; is_ch=0; [ "$2" = "$CHARTS" ] && is_ch=1
  log "host: $1 extract ($(($(wc -l < "$d/trades.csv") - 1)) trades)"
  extract_run "$d" "$is_ch"
  sed -nE 's/.*\(date ([0-9-]+)\) \(trend ([A-Za-z]+)\) \(breadth_state ([A-Za-z_]+)\).*/\1	\2	\3/p' "$d/macro_trend.sexp" > "$d/x_macro.tsv"
  for g in Y Q; do awk -v gran=$g -f "$LIB/periods.awk" "$SPY_CSV" "$d/equity_curve.csv" "$d/x_expo.tsv" "$d/trades.csv" "$d/x_macro.tsv" > "$d/x_p$g.json"; done
  audit_rows "$d" > "$d/x_audit.tsv"
  if [ -d "$d/stage" ]; then sh "$LIB/stage_sum.sh" "$d" > "$d/x_stage.tsv"; else : > "$d/x_stage.tsv"; fi
  awk -f "$LIB/assemble.awk" "$d/trades.csv" "$d/x_trades.tsv" "$d/x_audit.tsv" "$d/x_macro.tsv" "$d/x_stage.tsv" > "$s/$1_trades.json"
  sh "$LIB/meta.sh" "$d" > "$s/$1_meta.json"
  cp "$d/x_pY.json" "$s/$1_years.json"; cp "$d/x_pQ.json" "$s/$1_quarters.json"
  nav_json "$d" > "$s/$1_nav.json"
}
site_common() {
  s="$OUT/site/data"; cl=$(charts_label); d="$OUT/runs/$cl"
  first=$(sed -n 2p "$d/equity_curve.csv" | cut -d, -f1); last=$(tail -1 "$d/equity_curve.csv" | cut -d, -f1)
  # %.4f: the store writes values like "741." which strict JSON rejects
  awk -F, -v a="$first" -v b="$last" 'NR>1 && $1>=a && $1<=b && $6+0>0 {printf "%s[\"%s\",%.4f]", (n++?",":"["), $1, $6+0} END{print "]"}' "$SPY_CSV" > "$s/spy.json"
  awk -F'\t' '{printf "%s[\"%s\",\"%s\",\"%s\"]", (n++?",":"["), $1,$2,$3} END{print "]"}' "$d/x_macro.tsv" > "$s/macro.json"
  rm -rf "$s/charts"; mkdir -p "$s/charts"
  awk -v STAGE_DIR="$d/stage" -v OUT="$s/charts" -f "$LIB/chart_shards.awk" "$d/x_daily.tsv" "$d/trades.csv"
  [ -n "$SUBTITLE" ] || SUBTITLE="$first → $last, $(grep -oE 'universe_size [0-9]+' "$d/params.sexp" | cut -d' ' -f2) symbols, \$$(grep -oE 'initial_cash [0-9]+' "$d/params.sexp" | cut -d' ' -f2) start"
  runs_json=$(labels | awk '{printf "%s{\"id\":\"%s\",\"label\":\"%s\"}", (n++?",":""), $1, $1}')
  printf '{"title":"%s","subtitle":"%s","charts_run":%s,"runs":[%s]}\n' "$TITLE" "$SUBTITLE" "$CHARTS" "$runs_json" > "$s/manifest.json"
  cp "$LIB/index.html" "$OUT/site/index.html"
}
check_json() {
  command -v jq >/dev/null 2>&1 || { log "jq not found; skipped the JSON check"; return 0; }
  bad=0; for f in "$OUT"/site/data/*.json "$OUT"/site/data/charts/*.json; do
    [ -e "$f" ] || continue; jq -e 'true' "$f" >/dev/null 2>&1 || { echo "review_pack: invalid JSON: $f" >&2; bad=1; }
  done; return $bad
}

for r in $RUNS; do stage_run "${r%%=*}" "${r#*=}"; done
[ "$DOCKER" = 1 ] && docker_steps
mkdir -p "$OUT/site/data"
i=0; for l in $(labels); do host_run "$l" "$i"; i=$((i + 1)); done
site_common
check_json
log "done: $OUT/site/index.html ($(du -sh "$OUT/site" | cut -f1))"
