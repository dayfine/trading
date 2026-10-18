#!/bin/sh
# follow.sh <date> <date dir>: plan §4, each of day.sh's orders followed to its exit, capped at 104 weeks.
# Each order runs in the 2026-10-13 stepper (step.sh / sim.awk, unchanged) under its pseudonym (pool.sh's store),
# in <date dir>/follow/<PSEUDO>/:
#   - the order is placed at the decision date; it fills by sim.awk's rules (buy-stop fills at max(open, trigger),
#     no fill on a day opening past the limit) or expires at its 8-week checkpoint (no re-issue);
#   - the protective stop is run day by day; a stop hit ends the trade;
#   - the reader looks again (MODEL_F, default claude-opus-5-5; the composite at that checkpoint, the last bar and
#     the status block, never a bar after the checkpoint) at the fill checkpoint and then whenever LOOK_WEEKS (8)
#     have passed since its last look; it may raise the stop, sell (exit at the next open) or do nothing. Every
#     other checkpoint is applied as "none" without a call;
#   - the trade ends at the exit or 104 weeks after entry (END = entry + 728 days; sim.awk then marks it to that
#     close as open_at_end, flagged cap104 here; data_end when the stock's data stops first).
# Writes <date dir>/follow/<PSEUDO>/result.csv and <date dir>/reader-trades.csv:
#   pseudo,symbol,side,entry_date,exit_date,how,ret,spy_ret,excess,days,r104,max104,min104,spy104,end104,looks
# (how: stop, exit, cap104, data_end, expired (never filled), rejected (the stepper refused the order)), with the
# 104-week price path from path.awk on the adjusted basis. Restartable: a finished order keeps its result.csv; an
# unfinished one resumes from its stepper state. Exit 7 on a limit reply (stop, state kept).
# AGENT_STUB=1: the 2026-10-13 dummy_agent.awk answers the looks. Run from the repo root.
set -e
d=$1; DD=$2
E0=dev/experiments/fresh-eyes-2026-10-13; S0=$E0/scripts; S=dev/experiments/fresh-eyes-dated-2026-10-18/scripts
MODEL_F=${MODEL_F:-claude-opus-5-5}; LOOK_WEEKS=${LOOK_WEEKS:-8}; CWIDTH=${CWIDTH:-2400}
DATA0=${DATA:-/Users/difan/Projects/trading-1/data}
export DATA=$DD/store WEEKLY=$DD/weekly PAGES=$DD/pages
H="pseudo,symbol,side,entry_date,exit_date,how,ret,spy_ret,excess,days,r104,max104,min104,spy104,end104,looks"
plus() { awk -v d="$1" -v n="$2" -f $S0/days.awk -f $S/plus.awk; }
st() { sed -n "s/^$1=//p" "$R/state"; }
wk() { awk -v a="$1" -v b="$2" -f $S0/days.awk -f $S/weeks.awk; }
result() {  # result <how> [<trades.csv row>]
  if [ -n "$2" ]; then
    printf '%s\n' "$2" | awk -F, '{ print $2, $3, $4, $5, $6, $7 }' | { read -r side ed epx xd xpx how0
      a=$(printf %s "$sym" | cut -c1); b=$(printf %s "$sym" | rev | cut -c1)
      xo=0; [ "$how0" = exit ] && xo=1
      pr=$(awk -F, -v side="$side" -v ed="$ed" -v xd="$xd" -v epx="$epx" -v xpx="$xpx" -v basis=adj -v xo="$xo" \
        -f $S0/days.awk -f $S/path.awk "$DATA0/S/Y/SPY/data.csv" "$DATA0/$a/$b/$sym/data.csv")
      echo "$p,$sym,$side,$ed,$xd,$1,$pr,$looks"; } > "$R/result.csv.tmp"
  else echo "$p,$sym,,,,$1,,,,,,,,,,$looks" > "$R/result.csv.tmp"; fi
  mv "$R/result.csv.tmp" "$R/result.csv"
}
look() {  # look <label>: one reader look at the current checkpoint; leaves $R/dec.json
  c=$(st cut)
  sf=$(sed -n 's/^stock pages: //p' "$R/pending.txt" | awk '{ print $1 }'); mf=$(sed -n 's/^market pages: //p' "$R/pending.txt" | awk '{ print $1 }')
  [ -s "$R/looks/$1.png" ] || sh $S0/composite.sh "${sf%-full.png}" "${mf%-full.png}" "$R/looks/$1.png" "$CWIDTH"
  cat > "$R/looks/$1.prompt" <<EOF
Follow your rule card (your instructions). If a specific question is not settled by the card, you may grep the book
at @BOOK@ (OCR text; search short terms); usually you will not need to.

It is the weekend after the cut date below. You see nothing after that date. You hold a position in this stock
($p), entered on your own order. The image holds four charts: top left the stock since 2000, top right the stock's
last 5 years (weekly bars, 30-week MA, volume, Mansfield relative strength vs the S&P); bottom left the market since
2000, bottom right the market's last 5 years. Grey = future, hidden. Prices on the charts, in the last week's
numbers and in the status are all on the same scale.

Last week (exact numbers): $(cat "$(sed -n 's/^last bar: //p' "$R/pending.txt")")

Status:
$(grep -v -e '^stock pages:' -e '^last bar:' -e '^market pages:' -e '^DECISION NEEDED' "$R/pending.txt")

Manage the position by the book. Actions: none (keep it as it is); set_stop (move the protective stop; never
lower a long stop or raise a short stop); exit (close at the next open). The stop triggers intraday. You will be
shown the chart again in $LOOK_WEEKS weeks, or at once if the stop is hit (which ends the trade).

Reply with ONE line of JSON and nothing else:
{"stage": <1-4>, "action": "none" | "set_stop" | "exit", "stop": <number or null>, "reason": "<one short sentence>"}
EOF
  if [ "${AGENT_STUB:-0}" = 1 ]; then
    awk -F, -f $S0/dummy_agent.awk "$R/state" "$WEEKLY/$p.csv" | awk -F= '{ v[$1] = $2 }
      END { printf "{\"stage\":2,\"action\":\"%s\",\"stop\":%s,\"reason\":\"%s\"}\n", v["action"], (v["stop"] == "" ? "null" : v["stop"]), v["reason"] }' > "$R/looks/$1.stub.txt"
    export STUB_ANSWER=$R/looks/$1.stub.txt
  fi
  CALLS=$DD/calls.csv sh $S/ask.sh F "$MODEL_F" "$R/looks" "$1" "$R/looks/$1.prompt" "$R/looks/$1.png" || exit $?
  jq -c '{action: (.action // "none"), stop: (.stop // ""), reason: (.reason // "")}' "$R/looks/$1.json" 2>/dev/null > "$R/dec.json" || true
  [ -s "$R/dec.json" ] || echo '{"action":"none"}' > "$R/dec.json"
  sed 's/: *null/: ""/g' "$R/dec.json" > "$R/dec.json.tmp" && mv "$R/dec.json.tmp" "$R/dec.json"
  echo "$c" > "$R/lastlook"; looks=$((looks + 1)); echo "$looks" > "$R/nlooks"
}
apply() {  # apply: step.sh apply $R/dec.json with END for the current book; prints the exit code
  ed=$(st edate)
  if [ -n "$ed" ]; then END=$(plus "$ed" 728); else END=$(plus "$d" 63); fi
  set +e; END=$END sh $S0/step.sh "$p" "$R" apply "$R/dec.json" > /dev/null; rc=$?; set -e
  echo $rc
}
mkdir -p "$DD/follow"
tail -n +2 "$DD/orders.csv" | while IFS=, read -r p sym act trig lim stp cv; do
  R=$DD/follow/$p; mkdir -p "$R/looks"
  [ -s "$R/result.csv" ] && continue
  looks=$(cat "$R/nlooks" 2>/dev/null || echo 0)
  if [ ! -f "$R/state" ]; then
    END=$(plus "$d" 63) sh $S0/step.sh "$p" "$R" init "$d" > /dev/null
    printf '{"action":"%s","trigger":%s,"limit":"%s","stop":%s,"reason":"step D order"}\n' "$act" "$trig" "$lim" "$stp" > "$R/dec.json"
    rc=$(apply)
    if [ "$rc" = 3 ]; then result rejected; echo "follow.sh: $p rejected: $(sed -n 's/^REJECTED: //p' "$R/pending.txt")"; continue; fi
  fi
  while :; do
    pos=$(st pos); ord=$(st ord); c=$(st cut); n=$(($(wc -l < "$R/trades.csv") - 1))
    if [ "$n" -ge 1 ]; then
      row=$(sed -n 2p "$R/trades.csv"); how=$(printf %s "$row" | cut -d, -f7); xd=$(printf %s "$row" | cut -d, -f5)
      if [ "$how" = open_at_end ]; then
        how=cap104; [ "$xd" \< "$(plus "$(printf %s "$row" | cut -d, -f3)" 718)" ] && how=data_end
      fi
      result "$how" "$row"; break
    fi
    if [ "$pos" = none ] && [ "$ord" = none ]; then result expired; break; fi
    [ "$(st status)" = done ] && { result expired; break; }
    lw=$(cat "$R/lastlook" 2>/dev/null || echo "")
    if [ "$pos" != none ] && { [ -z "$lw" ] || [ "$(wk "$lw" "$c")" -ge "$LOOK_WEEKS" ]; }; then
      look "$c"
    else echo '{"action":"none"}' > "$R/dec.json"; fi
    rc=$(apply)
    if [ "$rc" = 3 ]; then  # a rejected look: re-ask once with the message, then none
      cp "$R/looks/$c.json" "$R/looks/$c.rejected.json" 2>/dev/null || true; rm -f "$R/looks/$c.json"
      look "$c"; rc=$(apply); [ "$rc" = 3 ] && { echo '{"action":"none"}' > "$R/dec.json"; rc=$(apply); }
    fi
    case $rc in 0|4) ;; *) echo "follow.sh: $p step.sh exit $rc at $c" >&2; exit "$rc" ;; esac
  done
  echo "follow.sh: $p $(cut -d, -f6 "$R/result.csv") looks $looks"
done
{ echo "$H"; cat "$DD"/follow/*/result.csv 2>/dev/null || true; } > "$DD/reader-trades.csv"
echo "follow.sh: $d $(($(wc -l < "$DD/reader-trades.csv") - 1)) orders followed"
