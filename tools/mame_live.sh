#!/bin/bash
# Like tools/mame.sh but WITH a window and real-time speed (only for when the user explicitly asks to watch). Usage: tools/mame_live.sh scripts/foo.lua
D="$(cd "$(dirname "$0")/.." && pwd)"
ROM="${SHO_ROM:-$D/Super Hang-On (World) (En,Ja) (Rev A).md}"
SCRIPT="$(realpath "$1")"; shift
mkdir -p "$D/out" "$D/out/.rompath"
ENVARGS=(--env=SHO_ROOT="$D")
while IFS='=' read -r k v; do case "$k" in SHO_ROOT) ;; SHO_*) ENVARGS+=("--env=$k=$v");; esac; done < <(env)
exec flatpak run --socket=x11 --socket=wayland --device=dri --filesystem="$D" "${ENVARGS[@]}" \
  --command=mame org.mamedev.MAME genesis -cart "$ROM" \
  -rompath "$D/out/.rompath" -window -sound none -debug -debugger none \
  -nvram_directory "$D/out/.nvram" -cfg_directory "$D/out/.cfg" -state_directory "$D/out/.sta" \
  -snapshot_directory "$D/out/snap" -skip_gameinfo -autoboot_script "$SCRIPT" \
  -seconds_to_run "${SHO_SECONDS:-900}" "$@" 2>&1
