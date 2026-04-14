# jq filter for `claude -p --output-format stream-json` events.
#
# Usage:
#   claude -p --output-format stream-json ... | jq -r --unbuffered -f format-event.jq
#
# Produces one human-readable line per event, dropping types we don't
# care to surface in the live ticker. Unknown event shapes return empty
# (degrade to silence rather than crash).
#
# Test by hand against a fixture:
#   echo '{"type":"tool_use","name":"Agent","input":{"subagent_type":"feat-backtest"}}' \
#     | jq -r -f dev/lib/format-event.jq

def ts: (now | strftime("%H:%M:%S"));

if .type == "tool_use" then
  "[\(ts)] tool: \(.name // "?")"
    + (if .input.subagent_type then "  (subagent: \(.input.subagent_type))" else "" end)
elif .type == "text" then
  .text
elif .type == "result" then
  "[\(ts)] === orchestrator returned ==="
elif .type == "system" then
  "[\(ts)] system: \(.subtype // .message // "?")"
else
  empty
end
