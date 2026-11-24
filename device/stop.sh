#!/bin/sh
# Stops Steam in the chroot (leaves Xvfb, the blitter and the pad remapper running unless "all" is given).
R=/opt/steamrg/root
pkill -9 -f '[r]un-steam.sh'
pkill -9 -f '[s]teamrtarm64/'
pkill -9 -f '[s]teamwebhelper'
pkill -f '[d]bus-daemon --fork --print-pid'
if [ "$1" = all ]; then
  pkill -9 -f '^/usr/local/bin/[f]bblit'
  pkill -9 -f '^/usr/local/bin/[p]admap'
  pkill -9 -x openbox
  pkill -9 -f '^[X]vfb :0'
  rm -f $R/tmp/.X11-unix/X0 $R/tmp/.X0-lock
fi
rm -rf $R/tmp/dumps $R/dev/shm/wnsysv
true
