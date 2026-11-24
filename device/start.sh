#!/bin/sh
# Runs on muOS as root. Stops the muOS frontend, starts Xvfb + the framebuffer blitter + openbox + Steam.
#   start.sh [nosteam] [steam args...]
#   STEAM_UI=gamepadui start.sh     Big Picture
#   GEOM=WxH start.sh               X screen size (scaled to the 640x480 panel)
R=/opt/steamrg/root
GEOM=${GEOM:-960x720}
STEAM_UI=${STEAM_UI:-$(cat /opt/steamrg/ui 2>/dev/null)}
/opt/steamrg/mount.sh
for p in frontend.sh idle.sh lowpower.sh; do pkill -f "$p"; done
pkill -9 -f /opt/muos/frontend/muxfrontend
sleep 1
# Steam (user steam) reads the built-in controls and creates virtual pads.
[ -e /dev/uinput ] || modprobe uinput 2>/dev/null
chmod 666 /dev/uinput
C="chroot $R /usr/bin/env -i PATH=/usr/local/bin:/usr/bin:/bin HOME=/root LANG=en_US.UTF-8"
pgrep -f '^/usr/local/bin/padmap' >/dev/null || { setsid $C /usr/local/bin/padmap >/opt/steamrg/padmap.log 2>&1 </dev/null & sleep 1; }
# Steam sees only the remapped pad; the raw one stays readable by muOS's root daemons.
for dev in /sys/class/input/event*; do
  case $(cat "$dev/device/name") in
    muOS-Keys) chmod 600 "/dev/input/${dev##*/}" ;;
    *) chmod 666 "/dev/input/${dev##*/}" ;;
  esac
done
pgrep -f '^Xvfb :0' >/dev/null || { setsid $C Xvfb :0 -screen 0 ${GEOM}x24 -nolisten tcp -ac -extension MIT-SHM >/opt/steamrg/xvfb.log 2>&1 </dev/null & sleep 3; }
pgrep -f '^/usr/local/bin/fbblit' >/dev/null || { setsid $C DISPLAY=:0 /usr/local/bin/fbblit 150 >/opt/steamrg/fbblit.log 2>&1 </dev/null & }
pgrep -x openbox >/dev/null || { setsid $C DISPLAY=:0 openbox >/opt/steamrg/openbox.log 2>&1 </dev/null & }
[ -S $R/run/dbus/system_bus_socket ] || { [ -s $R/etc/machine-id ] || chroot $R dbus-uuidgen --ensure=/etc/machine-id; chroot $R dbus-daemon --system --fork; }
[ "$1" = nosteam ] && exit 0
setsid chroot $R su - steam -c "DISPLAY=:0 LANG=en_US.UTF-8 STEAM_UI=$STEAM_UI /usr/local/bin/run-steam.sh $*" >/opt/steamrg/steam-outer.log 2>&1 </dev/null &
echo started
