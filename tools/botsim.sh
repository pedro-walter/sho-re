#!/bin/bash
# Headless bot-movement log.  Usage: tools/botsim.sh NAME TRACK(1-3) LAPS [driver: auto|ram]
#   auto: the lap autopilot drives (tune file of that track), ram: simple driver that steers into the nearest bot
set -e
cd "$(dirname "$0")/.."
NAME=$1; TRACK=${2:-1}; LAPS=${3:-2}; MODE=${4:-auto}
export SHO_ROOT=$PWD SHO_LOADSTATE=race$TRACK SHO_RIVAL=$((TRACK-1)) SHO_FRAMES=$((11000*LAPS)) SHO_SECONDS=900
if [ "$MODE" = auto ]; then
  PLAN=tune/track1_t0.lua; [ "$TRACK" = 3 ] && PLAN=tune/track3_t0.lua
  export SHO_DRIVER=autolap5.lua SHO_ONELAP=$LAPS SHO_GENT=80 SHO_GFADE=40 SHO_NOCHAIN=1 SHO_PLAN=$PLAN SHO_LEAD=40 SHO_BMARG=1.25 SHO_BR=0.35 SHO_REL=20 SHO_MARG=0 SHO_TPRE=150 SHO_DUTY=1.0 SHO_TIRE=0 SHO_ENGINE=0 SHO_FRAME=0 SHO_BRAKET=0 SHO_MUFFLER=0 SHO_OIL=0
else
  export SHO_RAM=1
fi
tools/mame.sh scripts/botsim.lua > out/botsim/$NAME.txt 2>&1
wc -l out/botsim/$NAME.txt
