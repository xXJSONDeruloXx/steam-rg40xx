#!/bin/bash
# Sets up a muOS device over adb from nothing: swap, ext2 image, rootfs, scripts, Steam client.
# Every step is skipped when already done. SERIAL selects the device.
#   tools/deploy.sh            full setup
#   tools/deploy.sh scripts    only push device and chroot scripts
set -euo pipefail
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.."
SERIAL=${SERIAL:-0c001080c69249221d2}
IMG_GB=${IMG_GB:-10}
SWAP_GB=${SWAP_GB:-2}
a() { adb -s "$SERIAL" "$@"; }
sh_() { a shell "$1"; }
# Long steps run detached on the device: an adb disconnect must not kill them.
detached() {
  local name=$1 cmd=$2
  sh_ "rm -f /opt/$name.rc; setsid sh -c '($cmd) >/opt/$name.log 2>&1; echo \$? >/opt/$name.rc' </dev/null >/dev/null 2>&1 &"
  until sh_ "cat /opt/$name.rc 2>/dev/null" | grep -q .; do sleep 10; done
  local rc; rc=$(sh_ "cat /opt/$name.rc" | tr -d '\r')
  [ "$rc" = 0 ] || { sh_ "tail -20 /opt/$name.log"; echo "deploy: $name failed ($rc)"; exit 1; }
}

push_scripts() {
  sh_ "mkdir -p /opt/steamrg"
  for f in device/*.sh; do a push "$f" /opt/steamrg/ >/dev/null; done
  sh_ "chmod +x /opt/steamrg/*.sh"
  if sh_ "[ -d /opt/steamrg/root/usr/local/bin ] && echo y" | grep -q y; then
    for f in chroot/*; do a push "$f" /opt/steamrg/root/usr/local/bin/ >/dev/null; done
    sh_ "chmod +x /opt/steamrg/root/usr/local/bin/*"
  fi
  echo "deploy: scripts pushed"
}

if [ "${1:-}" = scripts ]; then push_scripts; exit 0; fi

a get-state >/dev/null
echo "deploy: device $(sh_ 'uname -r; grep PRETTY /etc/os-release' | tr '\r\n' '  ')"

if ! sh_ "[ -f /swapfile ] && echo y" | grep -q y; then
  echo "deploy: creating ${SWAP_GB} GB swap on the root partition"
  detached swap "fallocate -l ${SWAP_GB}G /swapfile && chmod 600 /swapfile && mkswap /swapfile"
fi

if ! sh_ "[ -f /mnt/mmc/steamrg.img ] && echo y" | grep -q y; then
  echo "deploy: creating ${IMG_GB} GB ext2 image on /mnt/mmc (exFAT; zero-fills, ~15 min)"
  detached image "fallocate -l ${IMG_GB}G /mnt/mmc/steamrg.img && mke2fs -F -b 4096 -m 0 /mnt/mmc/steamrg.img"
fi

push_scripts
sh_ "/opt/steamrg/mount.sh" || true
sh_ "mountpoint -q /opt/steamrg" || { echo "deploy: image did not mount"; exit 1; }

if ! sh_ "[ -x /opt/steamrg/root/usr/local/lib/lse/liblse_emu.so ] && echo y" | grep -q y; then
  [ -f out/rootfs.tar ] || tools/build-rootfs.sh
  echo "deploy: pushing rootfs"
  a push out/rootfs.tar /mnt/mmc/rootfs.tar
  detached rootfs "mkdir -p /opt/steamrg/root && cd /opt/steamrg/root && tar xf /mnt/mmc/rootfs.tar && rm /mnt/mmc/rootfs.tar"
  push_scripts
  sh_ "/opt/steamrg/mount.sh"
fi

if ! sh_ "[ -x /opt/steamrg/root/home/steam/.local/share/Steam/steamrtarm64/steam ] && echo y" | grep -q y; then
  echo "deploy: installing the arm64 Steam client"
  detached steaminstall "chroot /opt/steamrg/root su - steam -c steam-install.sh"
fi
echo "deploy: done. Start with: adb -s $SERIAL shell /opt/steamrg/start.sh"
