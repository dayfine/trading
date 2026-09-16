#!/bin/sh
set -eu
. "$(dirname "$0")/_check_lib.sh"
sh "$(repo_root)/dev/scripts/weekly_sweep_pr_test.sh"
