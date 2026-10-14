#!/bin/sh
# limit.sh <out.jsonl> [<now epoch>]: is this headless-call output a limit / overload reply rather than an answer?
# Prints the seconds to wait before retrying the same cut, or 0 when the output is a real answer.
# A limit reply is: no result line; an error result; zero output tokens; or a result text naming a session, usage or
# rate limit, HTTP 429 / 529 or "overloaded". When the text says "resets <h[:mm]>am|pm (<TZ>)", the wait runs to that
# time + 2 minutes (the next day if the time has passed); otherwise 15 minutes. Pilot 2 (2026-10-13) logged 183
# "You've hit your session limit · resets 7:50pm (America/Los_Angeles)" replies as answers before this check.
f=$1; now=${2:-$(date +%s)}
res=$(grep '"type":"result"' "$f" 2>/dev/null | tail -1)
txt=$(printf '%s' "$res" | jq -r '.result // ""' 2>/dev/null)
err=$(printf '%s' "$res" | jq -r 'if (.is_error // false) then "y" else "n" end' 2>/dev/null)
out=$(printf '%s' "$res" | jq -r '.usage.output_tokens // 0' 2>/dev/null)
lim=n
[ -n "$res" ] || lim=y
[ "$err" = y ] && lim=y
[ "${out:-0}" -gt 0 ] 2>/dev/null || lim=y
# Words only on any reply; status codes only on an error result (an answer's prices could contain "529").
printf '%s' "$txt" | grep -qiE "session limit|usage limit|rate limit|you've hit your|overloaded" && lim=y
[ "$err" = y ] && printf '%s' "$txt" | grep -qE '429|529' && lim=y
[ $lim = y ] || { echo 0; exit 0; }
# "resets 7:50pm (America/Los_Angeles)" or "resets 8pm (...)".
spec=$(printf '%s' "$txt" | sed -nE 's/.*resets ([0-9]{1,2})(:([0-9]{2}))? ?([ap]m) \(([^)]+)\).*/\1 \3 \4 \5/p' | head -1)
if [ -n "$spec" ]; then
  set -- $spec
  h=$1; m=$2; ap=$3; tz=$4
  [ -n "$4" ] || { m=00; ap=$2; tz=$3; }
  h=$(expr "$h" % 12); m=$(expr "$m" + 0); [ "$ap" = pm ] && h=$((h + 12))
  day=$(TZ=$tz date -r "$now" +%Y-%m-%d)
  t=$(TZ=$tz date -j -f '%Y-%m-%d %H:%M:%S' "$day $(printf '%02d:%02d:00' "$h" "$m")" +%s 2>/dev/null)
  if [ -n "$t" ]; then
    [ "$t" -gt "$now" ] || t=$((t + 86400))
    echo $((t - now + 120)); exit 0
  fi
fi
echo 900
