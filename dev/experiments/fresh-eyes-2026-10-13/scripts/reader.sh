#!/bin/sh
# reader.sh <SYM> <run dir>: the forward pass for one symbol with a fresh model reader at every checkpoint (plan §4
# layer (ii), the adaptive-look amendment).
#
# Each checkpoint is one headless `claude -p` call with no memory of earlier calls, run from a reader folder outside
# the repository that holds only: the rule card, the cut's four pages (stock full / 5y, market full / 5y), the
# last-bar JSON and the status block. The reader may Read and Grep (the folder and the book), nothing else; it is not
# told anything about our system. Its one-line JSON decision goes to step.sh apply. A malformed answer is re-asked
# once, then applied as {"action":"none"}; a rejected decision (exit 3) is re-asked at the same cut, at most twice,
# then applied as none.
#
# Env: DATA (daily store), PAGES (default <run dir>/../pages, with the shared market pack in PAGES/market), WEEKLY,
# END (as step.sh); CARD (the rule card), BOOK (the book's text file), RWORK (reader folders root), MODEL
# (default claude-opus-5-5), MAXTOK (stop this symbol when its calls pass this many tokens, default 4000000).
# Writes <run dir>/calls.csv (one row per model call) and <run dir>/raw/<cut>-<n>.txt (each raw answer).
# Run from the repo root. Exit 0 when the run finished, 5 when MAXTOK stopped it.
set -e
s=$1; R=$2
E=dev/experiments/fresh-eyes-2026-10-13; S=$E/scripts
SP=/private/tmp/claude-501/-Users-difan-Projects-trading-1/0bdb1704-90a7-4760-bb6e-40335d5259c0/scratchpad/fresh-eyes
CARD=${CARD:-$SP/rulecard.md}
BOOK=${BOOK:-/Users/difan/Downloads/486827303-Stan-Weinstein-s-Secrets-For-Profiting-in-Bull-and-Bear-Mark-pdf.txt}
RWORK=${RWORK:-$SP/readers}; MODEL=${MODEL:-claude-opus-5-5}; MAXTOK=${MAXTOK:-4000000}
mkdir -p "$R/raw"; W=$RWORK/$s; mkdir -p "$W"
case "$W" in /Users/difan/Projects/*) echo "reader.sh: reader folder must be outside the repository" >&2; exit 2 ;; esac
[ -f "$R/state" ] || sh $S/step.sh "$s" "$R" init auto
[ -f "$R/calls.csv" ] || echo "sym,cut,attempt,input,cache_read,cache_creation,output,cost_usd,wall_s,action" > "$R/calls.csv"
cp "$CARD" "$W/rulecard.md"
{ echo "You are a stock trader who follows the rule card below, written from Stan Weinstein's book. Use the Read tool to look at images. Answer in the exact format asked."; echo; cat "$CARD"; } > "$W/system.md"

# path_of <label>: the first path on the pending.txt line starting with <label>, the n-th word after it.
word() { sed -n "s/^$1 //p" "$R/pending.txt" | awk -v n="$2" '{print $n}'; }

stage_inputs() {
  rm -f "$W"/*.png "$W"/*.json "$W"/status.txt
  cp "$(word 'stock pages:' 1)" "$W/stock-full.png"; cp "$(word 'stock pages:' 2)" "$W/stock-5y.png"
  cp "$(word 'market pages:' 1)" "$W/market-full.png"; cp "$(word 'market pages:' 2)" "$W/market-5y.png"
  cp "$(word 'last bar:' 1)" "$W/lastbar.json"
  grep -v -e '^stock pages:' -e '^last bar:' -e '^market pages:' "$R/pending.txt" > "$W/status.txt"
}

write_prompt() {  # write_prompt <extra note>
  cat > "$W/prompt.txt" <<EOF
Follow your rule card (your instructions; the same text is at ./rulecard.md). If a specific question is not settled
by the card, you may grep the book at $BOOK (OCR text; search short terms).

It is the weekend after the cut date below. You see nothing after that date. Read all four images:
./stock-full.png and ./stock-5y.png (the stock: weekly bars, 30-week MA, volume, relative strength vs the S&P),
./market-full.png and ./market-5y.png (S&P with its 30-week MA and volume, the NYSE advance-decline line, sector
strength). Prices on the charts, in the last week's numbers and in the status are all on the same scale.

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
}

tokens_so_far() { awk -F, 'NR > 1 { t += $4 + $5 + $6 + $7 } END { print t + 0 }' "$R/calls.csv"; }

ask() {  # ask <attempt>: one model call; leaves the decision JSON in $W/decision.json (empty when malformed)
  c=$(sed -n 's/^cut=//p' "$R/state"); t0=$(date +%s)
  (cd "$W" && claude -p --model "$MODEL" --output-format json --no-session-persistence --restricted \
     --strict-mcp-config --system-prompt-file system.md --allowedTools "Read Grep" --add-dir "$(dirname "$BOOK")" < prompt.txt > out.json 2> err.txt) || true
  wall=$(( $(date +%s) - t0 ))
  jq -r '.result // ""' "$W/out.json" > "$R/raw/$c-$1.txt" 2>/dev/null || : > "$R/raw/$c-$1.txt"
  grep -o '{.*}' "$R/raw/$c-$1.txt" | tail -1 > "$W/decision.json" || true
  jq -e '.action' "$W/decision.json" > /dev/null 2>&1 || : > "$W/decision.json"
  a=$( [ -s "$W/decision.json" ] && jq -r '.action' "$W/decision.json" || echo MALFORMED )
  u=$(jq -r '[.usage.input_tokens, .usage.cache_read_input_tokens, .usage.cache_creation_input_tokens, .usage.output_tokens, .total_cost_usd] | map(. // 0) | join(",")' "$W/out.json" 2>/dev/null || echo 0,0,0,0,0)
  echo "$s,$c,$1,$u,$wall,$a" >> "$R/calls.csv"
}

# JSON nulls become empty values for decision.awk.
denull() { sed 's/: *null/: ""/g' "$W/decision.json" > "$R/dec.json"; }

rc=0
while ! grep -q '^RUN FINISHED' "$R/pending.txt"; do
  [ "$(tokens_so_far)" -lt "$MAXTOK" ] || { echo "reader.sh: $s stopped at MAXTOK" >&2; exit 5; }
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
  [ $rc = 0 ] || [ $rc = 4 ] || { echo "reader.sh: step.sh apply exit $rc at $(sed -n 's/^cut=//p' "$R/state")" >&2; exit $rc; }
done
echo "reader.sh: $s finished, $(awk 'END { print NR - 1 }' "$R/calls.csv") calls, $(tokens_so_far) tokens"
