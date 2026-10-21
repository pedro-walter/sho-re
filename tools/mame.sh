#!/bin/bash
# Headless MAME (Flatpak org.mamedev.MAME 0.289) runner for Super Hang-On (Genesis).
# Usage: tools/mame.sh scripts/foo.lua [extra mame args]
# The script gets its parameters through environment variables (SHO_*); see scripts/lib.lua.
# Needs:  flatpak install --user flathub org.mamedev.MAME
D="$(cd "$(dirname "$0")/.." && pwd)"
ROM="${SHO_ROM:-$D/Super Hang-On (World) (En,Ja) (Rev A).md}"
SCRIPT="$(realpath "$1")"; shift
mkdir -p "$D/out"
# MAME wants a rompath; give it an empty dir so it never scans anything else.
mkdir -p "$D/out/.rompath"
ENVARGS=(--env=SHO_ROOT="$D")
while IFS='=' read -r k v; do case "$k" in SHO_ROOT) ;; SHO_*) ENVARGS+=("--env=$k=$v");; esac; done < <(env)
# No window ever: dummy SDL drivers and no X11/Wayland access inside the sandbox.
exec flatpak run --nosocket=x11 --nosocket=wayland --nosocket=fallback-x11 --env=SDL_VIDEODRIVER=dummy --env=SDL_AUDIODRIVER=dummy --unset-env=DISPLAY --unset-env=WAYLAND_DISPLAY --filesystem="$D" "${ENVARGS[@]}" \
  --command=mame org.mamedev.MAME genesis -cart "$ROM" \
  -rompath "$D/out/.rompath" -video none -sound none -nothrottle -debug -debugger none \
  -nvram_directory "$D/out/.nvram" -cfg_directory "$D/out/.cfg" -state_directory "$D/out/.sta" \
  -snapshot_directory "$D/out/snap" -skip_gameinfo -autoboot_script "$SCRIPT" \
  -seconds_to_run "${SHO_SECONDS:-600}" "$@" 2>&1 | grep -v -E '^(Average speed|Warning: -video none)'
