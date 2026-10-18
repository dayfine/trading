#!/bin/sh
# day.sh <date> <date dir>: the reader's day on one decision Friday, steps A-D (plan §3). Needs ours.sh's
# <date dir>/ours/ (our list joins the pool). Every step writes its own files and is skipped when they exist, so a
# stopped day restarts where it stopped.
#   A  market + groups   MODEL_A (default claude-opus-5-5), the market pack (full + 5y pages)  -> a/a.json
#   B  pool              pool.sh, mechanical                                                   -> pool.csv, store/
#   C  screen            MODEL_C (default claude-sonnet-5-5), one call per contact sheet       -> c/sheet-<n>.json
#                        shortlist: the SHORTLIST (10) best-scored names over all sheets        -> shortlist.txt
#   D  close look        MODEL_D (default claude-opus-5-5), the 2x2 composite per shortlisted name -> d/<PSEUDO>.json
#                        orders: the MAX_ORDERS (5) highest-conviction orders on the step-A side -> orders.csv
# The reader sees pseudonyms only (pool.sh's store; the pages, thumbnails, last-bar JSON and file names all carry
# them) and real price levels. A side of "neither" ends the day after A with no orders.
# Exit 0 done, 7 a limit reply (ask.sh; stop, state kept), 2 bad input. AGENT_STUB=1: stand-in answers (stub.awk
# for A and C, the 2026-10-13 dummy_agent.awk for D), no model calls.
# Env: DATA, MARKET_PAGES (pre-rendered market pack, default the 2026-10-13 pilot's), CWIDTH (composite width,
# default 2400), plus ask.sh's. Run from the repo root.
set -e
d=$1; DD=$2
E0=dev/experiments/fresh-eyes-2026-10-13; S0=$E0/scripts; S=dev/experiments/fresh-eyes-dated-2026-10-18/scripts
DATA=${DATA:-/Users/difan/Projects/trading-1/data}; export DATA
MODEL_A=${MODEL_A:-claude-opus-5-5}; MODEL_C=${MODEL_C:-claude-sonnet-5-5}; MODEL_D=${MODEL_D:-claude-opus-5-5}
SHORTLIST=${SHORTLIST:-10}; MAX_ORDERS=${MAX_ORDERS:-5}; CWIDTH=${CWIDTH:-2400}
MARKET_PAGES=${MARKET_PAGES:-/Users/difan/Projects/trading-1/.sweep-output/fresh-eyes/pilot/pages/market}
M=$E0/results/market
mkdir -p "$DD/a" "$DD/c" "$DD/d" "$DD/pages"
[ -e "$DD/pages/market" ] || { if [ -d "$MARKET_PAGES" ]; then ln -s "$MARKET_PAGES" "$DD/pages/market"; else mkdir -p "$DD/pages/market"; fi; }
mk=$DD/pages/market/MARKET-$d
[ -s "$mk-full.png" ] && [ -s "$mk-5y.svg" ] || sh $S0/render.sh MARKET "$d" "$DD/pages/market"
stub() { [ "${AGENT_STUB:-0}" = 1 ]; }

# ---- A: market phase, side, favoured groups.
sectors=$(awk -F, 'NR > 1 { print $2 }' $M/sector-strength.csv | sort -u | paste -sd'|' -)
if [ ! -f "$DD/a/a.json" ]; then
  cat > "$DD/a/a.prompt" <<EOF
Follow your rule card (your instructions). It is the weekend after $d. You see nothing after that date.
The two images are the market pack: the market since 2000 and its last 5 years (the S&P with its 30-week MA and
volume, the NYSE advance-decline line, sector strength). Grey = future, hidden.

Decide, as the book's weekend routine does, before looking at any stock:
- the market phase (the S&P's stage, and what the A-D line and the sectors say about it);
- whether to look for longs, shorts or neither this weekend;
- up to 3 favoured groups to look in, from this list exactly: ${sectors}.

Reply with ONE line of JSON and nothing else:
{"phase": "<short phrase>", "side": "long" | "short" | "neither", "groups": ["<group>", ...], "reason": "<one short sentence>"}
EOF
  stub && { awk -F, -v mode=A -v date="$d" -f $S/stub.awk $M/spy-weekly.csv $M/sector-strength.csv > "$DD/a/stub.txt"; export STUB_ANSWER=$DD/a/stub.txt; }
  sh $S/ask.sh A "$MODEL_A" "$DD/a" a "$DD/a/a.prompt" "$mk-full.png" "$mk-5y.png" || exit $?
fi
side=$(jq -r '.side // "neither"' "$DD/a/a.json" 2>/dev/null || echo neither)
case $side in long|short) ;; *) side=neither ;; esac
groups=$(jq -r '[.groups[]? | select(type == "string")] | .[:3] | join("|")' "$DD/a/a.json" 2>/dev/null || true)
printf "%s\n" "$sectors" | tr "|" "\n" > "$DD/a/sectors.txt"
groups=$(printf "%s\n" "$groups" | tr "|" "\n" | grep -Fx -f "$DD/a/sectors.txt" | paste -sd"|" - || true)
[ -n "$groups" ] || groups=all
echo "$side" > "$DD/side.txt"; echo "$groups" > "$DD/groups.txt"
if [ "$side" = neither ]; then
  echo "pseudo,symbol,action,trigger,limit,stop,conviction" > "$DD/orders.csv"; : > "$DD/shortlist.txt"
  echo "day.sh: $d side neither, no orders"; exit 0
fi

# ---- B: the pool and its contact sheets.
[ -s "$DD/pool.csv" ] || sh $S/pool.sh "$d" "$DD" "$groups" "$side"
if [ "$(wc -l < "$DD/pool.csv")" -le 1 ]; then
  echo "pseudo,symbol,action,trigger,limit,stop,conviction" > "$DD/orders.csv"; : > "$DD/shortlist.txt"
  echo "day.sh: $d empty pool, no orders"; exit 0
fi
sh $S/sheets.sh "$d" "$DD"

# ---- C: screen the sheets.
for sh_png in "$DD"/sheets/sheet-*.png; do
  n=$(basename "$sh_png" .png); [ -f "$DD/c/$n.json" ] && continue
  names=$(paste -sd' ' - < "$DD/sheets/$n.txt")
  cat > "$DD/c/$n.prompt" <<EOF
Follow your rule card (your instructions). It is the weekend after $d. You see nothing after that date.
This weekend you are looking for $side entries. The image is a contact sheet of $(wc -l < "$DD/sheets/$n.txt" | tr -d ' ') stocks, each labelled
with a name (weekly bars for the last 5 years, 30-week MA in blue, volume, Mansfield relative strength vs the
S&P; grey = future, hidden). The names on this sheet: $names.

Pick at most 5 names on this sheet that are worth a close look now for a $side entry by the book, and score each
1 (marginal) to 5 (a textbook setup). Picking none is fine.

Reply with ONE line of JSON and nothing else:
{"picks": [{"name": "<name>", "score": <1-5>}, ...], "reason": "<one short sentence>"}
EOF
  if stub; then
    files=$(sed "s|.*|$DD/weekly/&.csv|" "$DD/sheets/$n.txt" | paste -sd' ' -)
    awk -F, -v mode=C -v date="$d" -v k=3 -f $S/stub.awk $files > "$DD/c/$n.stub.txt"; export STUB_ANSWER=$DD/c/$n.stub.txt
  fi
  sh $S/ask.sh C "$MODEL_C" "$DD/c" "$n" "$DD/c/$n.prompt" "$sh_png" || exit $?
done
# Shortlist: valid names only (on that sheet), best score first, then sheet and pick order.
for f in "$DD"/c/sheet-*.json; do
  n=$(basename "$f" .json); [ -s "$f" ] || continue
  jq -r --arg n "${n#sheet-}" '.picks[]? | select(.name and .score) | "\(.score) \($n) \(.name)"' "$f" 2>/dev/null |
    awk -v ok="$(paste -sd' ' - < "$DD/sheets/$n.txt")" 'BEGIN { split(ok, a, " "); for (i in a) v[a[i]] = 1 } ($3 in v) { print $0, NR }'
done | sort -k1,1nr -k2,2n -k4,4n | awk '!seen[$3]++ { print $3 }' | head -n "$SHORTLIST" > "$DD/shortlist.txt"

# ---- D: the close look, one composite per shortlisted name.
while read -r p; do
  [ -f "$DD/d/$p.json" ] && continue
  [ -s "$DD/pages/$p-$d-5y.svg" ] && [ -s "$DD/pages/$p-$d.json" ] || DATA=$DD/store WEEKLY=$DD/weekly sh $S0/render.sh "$p" "$d" "$DD/pages"
  [ -s "$DD/d/$p.png" ] || sh $S0/composite.sh "$DD/pages/$p-$d" "$mk" "$DD/d/$p.png" "$CWIDTH"
  act=buy_stop; [ "$side" = short ] && act=short_stop
  cat > "$DD/d/$p.prompt" <<EOF
Follow your rule card (your instructions). If a specific question is not settled by the card, you may grep the book
at @BOOK@ (OCR text; search short terms); usually you will not need to.

It is the weekend after $d. You see nothing after that date. This weekend you are looking for $side entries, and
this stock ($p) made your shortlist. The image holds four charts: top left the stock since 2000, top right the
stock's last 5 years (weekly bars, 30-week MA, volume, Mansfield relative strength vs the S&P); bottom left the
market since 2000, bottom right the market's last 5 years. Grey = future, hidden. Prices on the charts and in the
numbers below are on the same scale.

Last week (exact numbers): $(cat "$DD/pages/$p-$d.json")

You hold nothing in this stock. Decide whether to place an order now:
- $act: needs trigger and stop (the protective stop once filled)$( [ "$side" = long ] && echo ', stop below the trigger; optional limit >= trigger' || echo ', stop above the trigger; optional limit <= trigger').
- none: no order.
An order rests until it fills or 8 weeks pass (then it expires). Once filled you will be shown the chart again at
the fill and every 8 weeks, and may raise the stop or sell. Rate your conviction 1 (marginal) to 5 (textbook).

Reply with ONE line of JSON and nothing else:
{"stage": <1-4>, "action": "$act" | "none", "trigger": <number or null>, "limit": <number or null>, "stop": <number or null>, "conviction": <1-5>, "reason": "<one short sentence>"}
EOF
  if stub; then
    printf 'cut=%s\npos=none\nord=none\nstop=\ndue=0\n' "$d" > "$DD/d/$p.state"
    awk -F, -f $S0/dummy_agent.awk "$DD/d/$p.state" "$DD/weekly/$p.csv" | awk -F= -v a="$act" '
      { v[$1] = $2 } END { if (v["action"] == "buy_stop") printf "{\"stage\":2,\"action\":\"%s\",\"trigger\":%s,\"limit\":null,\"stop\":%s,\"conviction\":3,\"reason\":\"%s\"}\n", a, v["trigger"], v["stop"], v["reason"]
        else print "{\"stage\":1,\"action\":\"none\",\"trigger\":null,\"limit\":null,\"stop\":null,\"conviction\":1,\"reason\":\"dummy: none\"}" }' > "$DD/d/$p.stub.txt"
    export STUB_ANSWER=$DD/d/$p.stub.txt
  fi
  sh $S/ask.sh D "$MODEL_D" "$DD/d" "$p" "$DD/d/$p.prompt" "$DD/d/$p.png" || exit $?
done < "$DD/shortlist.txt"
# Orders: the step-A side only, highest conviction first (shortlist order breaks ties), at most MAX_ORDERS.
act=buy_stop; [ "$side" = short ] && act=short_stop
{ echo "pseudo,symbol,action,trigger,limit,stop,conviction"
  r=0; while read -r p; do r=$((r + 1)); f=$DD/d/$p.json; [ -s "$f" ] || continue
    jq -r --arg a "$act" --arg p "$p" --arg r "$r" 'select(.action == $a and (.trigger|type) == "number" and (.stop|type) == "number")
      | "\(.conviction // 0) \($r) \($p) \(.trigger) \(if (.limit|type) == "number" then .limit else "-" end) \(.stop)"' "$f" 2>/dev/null || true
  done < "$DD/shortlist.txt" | sort -k1,1nr -k2,2n | head -n "$MAX_ORDERS" |
  while read -r cv r p tr lm stp; do
    [ "$lm" = - ] && lm=
    printf '%s,%s,%s,%s,%s,%s,%s\n' "$p" "$(awk -F, -v p="$p" '$1 == p { print $2 }' "$DD/pool.csv")" "$act" "$tr" "$lm" "$stp" "$cv"
  done; } > "$DD/orders.csv"
echo "day.sh: $d side $side groups '$groups' shortlist $(wc -l < "$DD/shortlist.txt" | tr -d ' ') orders $(($(wc -l < "$DD/orders.csv") - 1))"
