#!/bin/bash
# Inside the chroot, as the steam user, with DISPLAY set.
# STEAM_UI=gamepadui starts Big Picture; anything else starts the desktop client.
root=$HOME/.local/share/Steam
log=$HOME/steam-run.log
export STEAM_RUNTIME=1 STEAM_STEAMRT_RECURSION_GUARD=1
export LD_LIBRARY_PATH=$root/steamrtarm64:$root/steamrtarm64/panorama
export LD_PRELOAD=/usr/local/lib/lse/liblse_emu.so:/usr/local/lib/sysv/libsysv.so
export LSE_EMU=1 LSE_EMU_PATCH=${LSE_EMU_PATCH:-1} LSE_EMU_LOG=$HOME/lse_emu.log
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe
export SDL_VIDEO_X11_DGAMOUSE=0
export XDG_RUNTIME_DIR=/tmp/xdg-steam
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || eval "$(dbus-launch --sh-syntax)"
ui=()
[ "${STEAM_UI:-}" = gamepadui ] && ui=(-gamepadui)
cd "$root"
while :; do
  /usr/local/bin/patch-webhelper.py >>"$log" 2>&1
  echo "== starting steam ${ui[*]} $*" >>"$log"
  "$root/steamrtarm64/steam" -clientbeta "$(cat "$root/package/beta")" "${ui[@]}" \
    -no-cef-sandbox -cef-ozone-platform=x11 -cef-disable-gpu -cef-disable-gpu-compositing \
    "$@" >>"$log" 2>&1
  rc=$?
  echo "== steam exited rc=$rc" >>"$log"
  [ "$rc" = 42 ] || break
done
