#!/bin/bash
# Drive one lap with a plan file and render the review video.
# Usage: tools/lap.sh PLAN.lua TRACK(1-3) TIRE(0-4) NAME     -> out/video/NAME.mp4 + per-turn table
set -e
cd "$(dirname "$0")/.."
PLAN=$1; TRACK=$2; TIRE=$3; NAME=$4
export SHO_ROOT=$PWD
SHO_ONELAP=1 SHO_SNAP=3 SHO_GENT=${GENT:-80} SHO_GFADE=40 SHO_NOBOTS=1 SHO_NOCHAIN=1 SHO_PLAN=$PLAN SHO_LEAD=40 SHO_BR=0.35 SHO_LOADSTATE=race$TRACK SHO_REL=20 SHO_MARG=0 SHO_TPRE=150 SHO_DUTY=1.0 SHO_RIVAL=$((TRACK-1)) SHO_TIRE=$TIRE SHO_ENGINE=0 SHO_LOG=3 SHO_FRAMES=11000 SHO_TAG=$NAME tools/mame.sh scripts/${SCRIPT:-autolap5.lua} > /tmp/$NAME.txt 2>&1
grep "LAP 0->1" /tmp/$NAME.txt
python3 tools/turnstats.py /tmp/$NAME.txt
python3 tools/mkvideo.py /tmp/$NAME.txt $NAME out/video/$NAME.mp4 20 | tail -n 1
