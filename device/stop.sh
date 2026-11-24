#!/bin/sh
# Stops Steam in the chroot (leaves Xvfb and the blitter running unless "all" is given).
pkill -9 -f '[r]un-steam.sh'
pkill -9 -f '[s]teamrtarm64/'
pkill -9 -f '[s]teamwebhelper'
pkill -f '[d]bus-daemon --fork --print-pid'
if [ "$1" = all ]; then
  pkill -f '^/usr/local/bin/[f]bblit'
  pkill -f '^[X]vfb :0'
fi
rm -rf /opt/steamrg/root/tmp/dumps /opt/steamrg/root/dev/shm/wnsysv
true
