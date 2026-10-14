#!/bin/sh
# reader.sh <SYM> <run dir>: the forward pass for one symbol with a fresh model reader at every checkpoint (plan §4
# layer (ii), the adaptive-look amendment; pilot 2 format).
#
# Each checkpoint is one headless `claude -p` call with no memory of earlier calls, from a reader folder outside the
# repository. The rule card is the system prompt. The cut's four pages (stock full / 5y, market full / 5y) go in as
# ONE inline composite image (composite.sh, 2x2) in the user message (--input-format stream-json), with the last
# week's numbers and the status as text, so a decision is normally one model turn. The reader may Grep the book for a
# specific question (the only tool allowed); it is not told anything about our system. Its one-line JSON decision goes
# to step.sh apply. A malformed answer is re-asked once, then applied as {"action":"none"}; a rejected decision (exit
# 3) is re-asked at the same cut, at most twice, then applied as none.
#
# Shadow reader (agreement): when SHADOW_MODEL is set, every first-attempt prompt is also sent, in the background, to
# that model; its answer is logged to <run dir>/shadow.csv and shadow-raw/, and never drives the stepper.
#
# Env: DATA, PAGES (default <run dir>/../pages, market pack in PAGES/market), WEEKLY, END (as step.sh); CARD (rule
# card), BOOK (the book's text file), RWORK (reader folders root), MODEL (default claude-opus-5-5), MAXUSD (stop this
# symbol when its driving calls pass this many dollars, default 40), SHADOW_MODEL, SHADOW_MAXUSD (no new shadow call
# once this symbol's shadow calls pass it, default 15), CWIDTH (composite width, default 2400).
# Writes <run dir>/calls.csv and raw/<cut>-<n>.txt; shadow.csv and shadow-raw/ with a shadow model.
# Run from the repo root. Exit 0 when the run finished, 5 when MAXUSD stopped it.
set -e
s=$1; R=$2
E=dev/experiments/fresh-eyes-2026-10-13; S=$E/scripts
SP=/private/tmp/claude-501/-Users-difan-Projects-trading-1/0bdb1704-90a7-4760-bb6e-40335d5259c0/scratchpad/fresh-eyes
CARD=${CARD:-$SP/rulecard.md}
BOOK=${BOOK:-/Users/difan/Downloads/486827303-Stan-Weinstein-s-Secrets-For-Profiting-in-Bull-and-Bear-Mark-pdf.txt}
RWORK=${RWORK:-$SP/readers}; MODEL=${MODEL:-claude-opus-5-5}; MAXUSD=${MAXUSD:-40}
SHADOW_MAXUSD=${SHADOW_MAXUSD:-15}; CWIDTH=${CWIDTH:-2400}
PAGES=${PAGES:-$R/../pages}; export PAGES
mkdir -p "$R/raw"; W=$RWORK/$s; mkdir -p "$W"
case "$W" in /Users/difan/Projects/*) echo "reader.sh: reader folder must be outside the repository" >&2; exit 2 ;; esac
[ -f "$R/state" ] || sh $S/step.sh "$s" "$R" init auto
H="sym,cut,attempt,input,cache_read,cache_creation,output,cost_usd,wall_s,turns,action"
[ -f "$R/calls.csv" ] || echo "$H" > "$R/calls.csv"
if [ -n "$SHADOW_MODEL" ]; then mkdir -p "$R/shadow-raw"; [ -f "$R/shadow.csv" ] || echo "$H" > "$R/shadow.csv"; fi
{ echo "You are a stock trader who follows the rule card below, written from Stan Weinstein's book. Answer in the exact format asked."; echo; cat "$CARD"; } > "$W/system.md"

word() { sed -n "s/^$1 //p" "$R/pending.txt" | awk -v n="$2" '{print $n}'; }

stage_inputs() {
  rm -f "$W"/*.png "$W"/status.txt
  sf=$(word 'stock pages:' 1); mf=$(word 'market pages:' 1)
  sh $S/composite.sh "${sf%-full.png}" "${mf%-full.png}" "$W/cut.png" "$CWIDTH"
  cp "$(word 'last bar:' 1)" "$W/lastbar.json"
  grep -v -e '^stock pages:' -e '^last bar:' -e '^market pages:' "$R/pending.txt" > "$W/status.txt"
}

write_prompt() {  # write_prompt <extra note>: $W/in.jsonl, the user message with the image and the text
  cat > "$W/prompt.txt" <<EOF
Follow your rule card (your instructions). If a specific question is not settled by the card, you may grep the book
at $BOOK (OCR text; search short terms); usually you will not need to.

It is the weekend after the cut date below. You see nothing after that date. The image holds four charts:
top left the stock since 2000, top right the stock's last 5 years (weekly bars, 30-week MA, volume, Mansfield
relative strength vs the S&P); bottom left the market since 2000, bottom right the market's last 5 years (S&P with
its 30-week MA and volume, the NYSE advance-decline line, sector strength). Grey = future, hidden. Prices on the
charts, in the last week's numbers and in the status are all on the same scale.

Last week (exact numbers): $(cat "$W/lastbar.json")

Status (your position, resting order, recent trades):
$(cat "$W/status.txt")

Decide what to do now, for this one stock, long or short. Actions:
- none: do nothing (keeps any resting order and position as they are).
- buy_stop: place a buy-stop order (needs trigger, stop = protective stop once filled; optional limit >= trigger).
- short_stop: place a sell-short stop order (needs trigger, stop above it; optional limit <= trigger).
- cancel: cancel the resting order.  - set_stop: move the protective stop (never against you).  - exit: close at
  the next open.
An order rests until it fills, you cancel it, or 8 weeks pass (then re-issue it or it is cancelled). Stops trigger
intraday. When you hold no position and no order, set next_look (whole weeks 1-13) to say when to look again;
otherwise you will be shown the chart again in 4 weeks, or sooner after a fill or a stop.

Reply with ONE line of JSON and nothing else:
{"stage": <1-4 for the stock>, "action": "...", "trigger": <number or null>, "limit": <number or null>, "stop": <number or null>, "next_look": <weeks or null>, "reason": "<one short sentence>"}
$1
EOF
  base64 < "$W/cut.png" | tr -d '\n' > "$W/cut.b64"
  jq -cn --rawfile b "$W/cut.b64" --rawfile t "$W/prompt.txt" \
    '{type:"user",message:{role:"user",content:[{type:"image",source:{type:"base64",media_type:"image/png",data:$b}},{type:"text",text:$t}]}}' > "$W/in.jsonl"
  rm -f "$W/cut.b64"
}

usd_of() { [ -f "$1" ] && awk -F, 'NR > 1 { t += $8 } END { printf "%.4f\n", t + 0 }' "$1" || echo 0; }
over() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 >= b + 0) }'; }

# call <model> <dir> <in.jsonl> <out.jsonl>: one headless call; prints "<wall>".
call() {
  t0=$(date +%s)
  (cd "$2" && claude -p --model "$1" --input-format stream-json --output-format stream-json --verbose \
     --no-session-persistence --restricted --strict-mcp-config --system-prompt-file "$W/system.md" \
     --allowedTools "Grep" --add-dir "$(dirname "$BOOK")" < "$3" > "$4" 2> "$4.err") || true
  echo $(( $(date +%s) - t0 ))
}

# log_call <out.jsonl> <raw file> <csv> <cut> <attempt> <wall>: the answer to <raw file>, one row to <csv>; prints
# the decision JSON (empty when malformed).
log_call() {
  grep '"type":"result"' "$1" | tail -1 > "$1.res" || : > "$1.res"
  jq -r '.result // ""' "$1.res" > "$2" 2>/dev/null || : > "$2"
  d=$(grep -o '{.*}' "$2" | tail -1 || true)
  printf '%s' "$d" | jq -e '.action' > /dev/null 2>&1 || d=""
  a=$( [ -n "$d" ] && printf '%s' "$d" | jq -r '.action' || echo MALFORMED )
  u=$(jq -r '[.usage.input_tokens, .usage.cache_read_input_tokens, .usage.cache_creation_input_tokens, .usage.output_tokens, .total_cost_usd, .num_turns] | map(. // 0) | join(",")' "$1.res" 2>/dev/null || echo 0,0,0,0,0,0)
  # u ends with turns; the row puts wall before turns.
  pre=${u%,*}; turns=${u##*,}
  echo "$s,$4,$5,$pre,$6,$turns,$a" >> "$3"
  printf '%s' "$d"
}

shadow() {  # shadow <cut>: the shadow model on the same first-attempt message, in the background
  [ -n "$SHADOW_MODEL" ] || return 0
  over "$(usd_of "$R/shadow.csv")" "$SHADOW_MAXUSD" && return 0
  sd=$W/shadow-$1; mkdir -p "$sd"; cp "$W/in.jsonl" "$sd/in.jsonl"
  ( wl=$(call "$SHADOW_MODEL" "$sd" "$sd/in.jsonl" "$sd/out.jsonl")
    log_call "$sd/out.jsonl" "$R/shadow-raw/$1.txt" "$R/shadow.csv" "$1" 1 "$wl" > /dev/null
    rm -rf "$sd" ) &
}

ask() {  # ask <attempt>: one driving call; leaves the decision in $W/decision.json (empty when malformed)
  c=$(sed -n 's/^cut=//p' "$R/state")
  [ "$1" = 1 ] && shadow "$c"
  wl=$(call "$MODEL" "$W" "$W/in.jsonl" "$W/out.jsonl")
  log_call "$W/out.jsonl" "$R/raw/$c-$1.txt" "$R/calls.csv" "$c" "$1" "$wl" > "$W/decision.json"
}

denull() { sed 's/: *null/: ""/g' "$W/decision.json" > "$R/dec.json"; }

rc=0
while ! grep -q '^RUN FINISHED' "$R/pending.txt"; do
  over "$(usd_of "$R/calls.csv")" "$MAXUSD" && { wait; echo "reader.sh: $s stopped at MAXUSD" >&2; exit 5; }
  stage_inputs; rejects=0
  while :; do
    write_prompt ""; ask 1
    if [ ! -s "$W/decision.json" ]; then
      write_prompt "Your last answer was not one line of valid JSON with an action. Reply with the JSON line only."; ask 2
    fi
    [ -s "$W/decision.json" ] && denull || echo '{"action":"none"}' > "$R/dec.json"
    set +e; sh $S/step.sh "$s" "$R" apply "$R/dec.json"; rc=$?; set -e
    [ $rc = 3 ] || break
    rejects=$((rejects + 1))
    if [ $rejects -ge 2 ]; then
      echo '{"action":"none","reason":"two rejected decisions at this cut"}' > "$R/dec.json"
      set +e; sh $S/step.sh "$s" "$R" apply "$R/dec.json"; rc=$?; set -e; break
    fi
    stage_inputs
  done
  [ $rc = 0 ] || [ $rc = 4 ] || { wait; echo "reader.sh: step.sh apply exit $rc at $(sed -n 's/^cut=//p' "$R/state")" >&2; exit $rc; }
done
wait
echo "reader.sh: $s finished, $(awk 'END { print NR - 1 }' "$R/calls.csv") calls, \$$(usd_of "$R/calls.csv")"
