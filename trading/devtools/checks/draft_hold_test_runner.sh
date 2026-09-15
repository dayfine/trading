#!/bin/sh
# The tested function lives in Markdown outside dune's workspace root.
set -eu
. "$(dirname "$0")/_check_lib.sh"
sh "$(repo_root)/dev/scripts/draft_hold_test.sh"
