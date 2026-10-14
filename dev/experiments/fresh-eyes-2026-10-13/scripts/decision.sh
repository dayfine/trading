#!/bin/sh
# decision.sh <decision file>: the agent's decision normalised to key=value lines (see decision.awk).
awk -f "$(dirname "$0")/decision.awk" "$1"
