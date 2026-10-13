#!/bin/sh
# Demo set for the step-1 visual check: 3 sampled symbols at 2 cuts each, plus the market pack at two of them.
# Writes .sweep-output/fresh-eyes/demo/ (not committed). Run from the repo root; DATA = daily store.
set -e
S=dev/experiments/fresh-eyes-2026-10-13/scripts; O=${OUT:-.sweep-output/fresh-eyes/demo}
for sc in RMD:2002-10-11 RMD:2008-10-10 TWTR:2015-06-26 TWTR:2021-12-31 MP:2021-12-31 MP:2024-06-28; do
  sh $S/render.sh "${sc%%:*}" "${sc#*:}" "$O"
done
for c in 2008-10-10 2021-12-31; do sh $S/render.sh MARKET $c "$O"; done
ls "$O"
