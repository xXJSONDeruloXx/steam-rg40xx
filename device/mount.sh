#!/bin/sh
# Runs on muOS as root: mounts the ext4 image and the chroot's virtual filesystems.
R=/opt/steamrg/root
IMG=/mnt/mmc/steamrg.img
mkdir -p /opt/steamrg
mountpoint -q /opt/steamrg || mount -o loop,noatime "$IMG" /opt/steamrg
grep -q '^/swapfile' /proc/swaps || swapon /swapfile
echo 60 > /proc/sys/vm/swappiness
m() { mountpoint -q "$R$2" || { mkdir -p "$R$2"; mount "$@"; }; }
mb() { mountpoint -q "$R$2" || { mkdir -p "$R$2"; mount --bind "$1" "$R$2"; }; }
mb /dev /dev
mb /dev/pts /dev/pts
mb /proc /proc
mb /sys /sys
mountpoint -q "$R/dev/shm" || mount -t tmpfs -o mode=1777,size=256m shm "$R/dev/shm"
mountpoint -q "$R/tmp" || mount -t tmpfs -o mode=1777,size=256m tmp "$R/tmp"
mountpoint -q "$R/run" || mount -t tmpfs -o mode=755 run "$R/run"
mkdir -p "$R/run/dbus" "$R/tmp/.X11-unix"
chmod 1777 "$R/tmp/.X11-unix"
cp -L /etc/resolv.conf "$R/etc/resolv.conf"
[ -d /run/udev ] && mb /run/udev /run/udev
true
