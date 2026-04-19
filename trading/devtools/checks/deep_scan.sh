#!/bin/sh
# Deep scan shim — delegates to deep_scan/main.sh.
# See trading/devtools/checks/deep_scan/ for per-check scripts.
exec sh "$(dirname "$0")/deep_scan/main.sh" "$@"
