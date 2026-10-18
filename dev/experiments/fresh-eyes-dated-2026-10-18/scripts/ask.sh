#!/bin/sh
# ask.sh <role> <model> <dir> <label> <prompt.txt> [<image.png> ...]: one fresh reader call; the answer's JSON
# object goes to <dir>/<label>.json (empty when the answer is malformed twice), the raw text to <dir>/<label>.txt,
# one row to <dir>/../calls.csv (or $CALLS).
#
# Live: one headless `claude -p` call, as the 2026-10-13 reader.sh makes it: the rule card as the system prompt, the
# images inline in the user message (stream-json), run from an empty working folder outside the repository, Grep
# as the only tool, reaching only BOOKDIR (a folder holding only book.txt; never committed, never printed).
# A malformed answer is re-asked once (<label>-2).
# Stub (AGENT_STUB=1): no model call. The caller has written the stand-in answer to $STUB_ANSWER; it is copied in
# as the raw answer and logged with zero tokens, so the rest of the pipeline runs exactly as live.
#
# Guards (plan §8): a limit / overload reply (the 2026-10-13 limit.sh) is never waited out: the reply is kept in
# <dir>/<label>.limit and ask.sh exits 7, so the run stops with its state kept. Restartable: an existing
# <label>.json is reused without a call.
# Env: CARD (default the 2026-10-13 results/rulecard.md), BOOKDIR (default ~/.fresh-eyes-book), BOOK_SRC, RWORK
# (reader folders, default ~/.fresh-eyes-dated-run), AGENT_STUB, STUB_ANSWER, CALLS.
set -e
role=$1; model=$2; dir=$3; label=$4; prompt=$5; shift 5
E0=dev/experiments/fresh-eyes-2026-10-13; S0=$E0/scripts
CARD=${CARD:-$PWD/$E0/results/rulecard.md}; CALLS=${CALLS:-$dir/../calls.csv}
mkdir -p "$dir"
[ -f "$dir/$label.json" ] && exit 0
[ -f "$CALLS" ] || echo "role,label,model,input,cache_read,cache_creation,output,cost_usd,wall_s,turns" > "$CALLS"
extract() {  # extract <raw> <json>: the last {...} in the answer, when it parses
  d=$(tr '\n' ' ' < "$1" | grep -o '{.*}' | tail -1 || true)
  if [ -n "$d" ] && printf '%s' "$d" | jq -e 'type == "object"' > /dev/null 2>&1; then printf '%s\n' "$d" > "$2"; else : > "$2"; fi
}
if [ "${AGENT_STUB:-0}" = 1 ]; then
  [ -s "$STUB_ANSWER" ] || { echo "ask.sh: AGENT_STUB=1 needs STUB_ANSWER" >&2; exit 2; }
  cp "$STUB_ANSWER" "$dir/$label.txt"; extract "$dir/$label.txt" "$dir/$label.json.tmp"; mv "$dir/$label.json.tmp" "$dir/$label.json"
  echo "$role,$label,stub,0,0,0,0,0,0,0" >> "$CALLS"; exit 0
fi
BOOKDIR=${BOOKDIR:-$HOME/.fresh-eyes-book}; BOOK=$BOOKDIR/book.txt
BOOK_SRC=${BOOK_SRC:-/Users/difan/Downloads/486827303-Stan-Weinstein-s-Secrets-For-Profiting-in-Bull-and-Bear-Mark-pdf.txt}
RWORK=${RWORK:-$HOME/.fresh-eyes-dated-run}; C=$RWORK/cwd-$role-$$
for d in "$RWORK" "$BOOKDIR"; do
  case "$d" in /Users/difan/Projects/*) echo "ask.sh: $d must be outside the repository" >&2; exit 2 ;; esac
done
mkdir -p "$C" "$BOOKDIR"
[ -s "$BOOK" ] || cp "$BOOK_SRC" "$BOOK"
[ "$(ls -A "$BOOKDIR")" = book.txt ] || { echo "ask.sh: $BOOKDIR must hold only book.txt" >&2; exit 2; }
[ -z "$(ls -A "$C")" ] || { echo "ask.sh: reader folder $C must be empty" >&2; exit 2; }
sys=$RWORK/system.md
{ echo "You are a stock trader who follows the rule card below, written from Stan Weinstein's book. Answer in the exact format asked."; echo; cat "$CARD"; } > "$sys"
one() {  # one <image ...>: one call with prompt $P, answer to $dir/$A.txt
  W=$RWORK/_work-$role-$$; mkdir -p "$W"
  { printf '['; first=1
    for im in "$@"; do [ $first = 1 ] || printf ','; first=0
      printf '{"type":"image","source":{"type":"base64","media_type":"image/png","data":"'; base64 < "$im" | tr -d '\n'; printf '"}}'
    done; printf ']'; } > "$W/imgs.json"
  jq -cn --slurpfile im "$W/imgs.json" --rawfile t "$P" \
    '{type:"user",message:{role:"user",content:($im[0] + [{type:"text",text:$t}])}}' > "$W/in.jsonl"
  t0=$(date +%s)
  (cd "$C" && claude -p --model "$model" --input-format stream-json --output-format stream-json --verbose \
     --no-session-persistence --restricted --strict-mcp-config --system-prompt-file "$sys" \
     --allowedTools "Grep" --add-dir "$BOOKDIR" < "$W/in.jsonl" > "$W/out.jsonl" 2> "$W/out.err") || true
  wl=$(( $(date +%s) - t0 ))
  if [ "$(sh $S0/limit.sh "$W/out.jsonl")" != 0 ]; then
    cp "$W/out.jsonl" "$dir/$label.limit"; rm -rf "$W" "$C"
    echo "ask.sh: limit or overload reply at $dir/$label; stopping (no retry; restart later)" >&2; exit 7
  fi
  grep '"type":"result"' "$W/out.jsonl" | tail -1 > "$W/res"
  jq -r '.result // ""' "$W/res" > "$dir/$A.txt"
  u=$(jq -r '[.usage.input_tokens, .usage.cache_read_input_tokens, .usage.cache_creation_input_tokens, .usage.output_tokens, .total_cost_usd] | map(. // 0) | join(",")' "$W/res")
  echo "$role,$A,$model,$u,$wl,$(jq -r '.num_turns // 0' "$W/res")" >> "$CALLS"
  rm -rf "$W"
}
# The prompt may name the book as @BOOK@; the path is filled in here, where it is known.
sed "s|@BOOK@|$BOOK|g" "$prompt" > "$dir/$label.prompt.sent"
A=$label; P=$dir/$label.prompt.sent; one "$@"
extract "$dir/$A.txt" "$dir/$label.json.tmp"
if [ ! -s "$dir/$label.json.tmp" ]; then
  { cat "$dir/$label.prompt.sent"; echo; echo "Your last answer was not one line of valid JSON. Reply with the JSON line only."; } > "$dir/$label-2.prompt"
  A=$label-2; P=$dir/$label-2.prompt; one "$@"
  extract "$dir/$A.txt" "$dir/$label.json.tmp"
fi
mv "$dir/$label.json.tmp" "$dir/$label.json"; rmdir "$C" 2>/dev/null || true
