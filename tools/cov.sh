#!/bin/bash
# Execution-coverage run: tools/cov.sh TAG   (inputs/frames via SHO_INPUT / SHO_FRAMES as in scripts/play.lua)
# Every distinct executed PC (instruction start) lands in out/cov_TAG.txt, sorted, as 6 hex digits per line.
D="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:?tag}"
F="$D/out/cov_$TAG.fifo"; rm -f "$F"; mkfifo "$F"
awk '/^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$/ && !s[$0]++' < "$F" | sort > "$D/out/cov_$TAG.txt" &
SHO_COV="$F" SHO_TAG="$TAG" "$D/tools/mame.sh" "$D/scripts/play.lua"
wait; rm -f "$F"
wc -l "$D/out/cov_$TAG.txt"
