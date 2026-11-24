# Native arm64 Steam client on the Anbernic RG40XX-H (muOS)

Valve's arm64 Linux Steam client (`steamrtarm64/steam`, Steam Deck client channels) running natively
on an Allwinner H700 (4x Cortex-A53, ARMv8.0, 1 GB RAM, Mali-G31) under muOS 2601 / Linux 4.9.170.
It reaches the QR sign-in screen; signing in with the Steam mobile app works.

## What this device lacks, and the workaround for each

| Problem | Symptom | Workaround |
|---|---|---|
| No ARMv8.1 LSE atomics (A53) | `steam` has ~350 inline `ldadd`/`cas`/`swp`; SIGILL | `LD_PRELOAD` of LSE-Emu (SildurFX/LSE-Emu via DroidDeck `feat/lse-emu`), patches sites to LL/SC stubs |
| Kernel without `CONFIG_SYSVIPC` | `threadtools.cpp: semaphore creation failed`, "Thread synchronization object is unuseable" | `LD_PRELOAD` of DroidDeck's `tools/linuxfs/preload/sysv.c` (SysV sem/shm/msg over `/dev/shm` + futex) |
| No SysV shm for X MIT-SHM | `X_ShmAttach BadAccess` | Xvfb started with `-extension MIT-SHM` |
| No user namespaces (no bwrap/pressure-vessel) | - | `STEAM_RUNTIME=1 STEAM_STEAMRT_RECURSION_GUARD=1`, plain `LD_LIBRARY_PATH`, `-no-cef-sandbox` |
| No DRM/KMS, only `/dev/fb0` (640x480 32bpp) | - | Xvfb 960x720 + `fbblit` (bilinear scale of the X root window onto fb0, ~6 fps) |
| No GPU for CEF | - | `-cef-disable-gpu -cef-disable-gpu-compositing`, llvmpipe for GL |
| `lsof` missing | WebUI websocket "Connection rejected" -> "Unexpected Transport Error 0x3008" | install `lsof` (Steam identifies its own UI's TCP peers with it) |
| `steamwebhelper.sh` pins `taskset 0x7c` (Deck cores 2-6) | web helper gets only 2 of 4 cores | wrapper patched (same byte size, so the size-only verify keeps it) |
| Slow renderer on A53 + software raster | `killing unresponsive browser`, "error (#2) while rendering" | `--disable-hang-monitor` appended in the wrapper |
| No window manager | main window created but never mapped | openbox |
| 1 GB RAM | - | 2 GB swap file on the ext4 root partition |
| Built-in pad is `muOS-Keys` with sticks on ABS_Z/RX/RY/RZ | SDL would mix up sticks and triggers | `padmap` re-exposes it through uinput as an Xbox 360 pad (button meaning from muOS's own gamecontrollerdb entry); the raw device is hidden from the steam user |
| exFAT data partition | no Linux permissions/symlinks | 10 GB ext2 loop image `/mnt/mmc/steamrg.img` mounted at `/opt/steamrg` |

## Layout on the device

- `/mnt/mmc/steamrg.img` -> `/opt/steamrg` (ext2 loop). Debian trixie arm64 rootfs in `/opt/steamrg/root`.
- `/swapfile` (2 GB) on the muOS root partition.
- `/opt/steamrg/{mount.sh,start.sh,stop.sh,threads.sh}` run on muOS as root.
- Steam lives in `/home/steam/.local/share/Steam` inside the chroot, user `steam`.

## Running

```
adb shell /opt/steamrg/start.sh      # mounts, stops the muOS frontend, Xvfb + fbblit + openbox + padmap + Steam
adb shell 'echo gamepadui > /opt/steamrg/ui'   # Big Picture from now on (GEOM=640x480 renders at panel size)
adb shell /opt/steamrg/stop.sh       # stops Steam (add "all" to stop Xvfb and the blitter too)
powershell -File shot.ps1            # grabs fb0 to fb.png
```

A reboot brings muOS back (nothing is installed into its boot path). After a reboot run `start.sh` again.

## Rebuilding the rootfs

`docker build --platform linux/arm64 -t steam-rg40xx .` then `docker export` of a container, extract into
`/opt/steamrg/root`, then `steam-install.sh` inside the chroot as `steam` (downloads the
`steam_client_steamdeck_publicbeta_linuxarm64` manifest's `_all` and `_linuxarm64_linuxarm64` zips).
The first client start re-downloads the package (~670 MB) because no `.installed` marker is written.

## Timings seen

- Client start to web helper: ~1.5 min. Web helper to login window: ~3-5 min.
- QR sign-in to main window loaded: ~10-15 min (before the taskset fix).

## Licenses

GPL-3.0-or-later (see `LICENSE`). `rootfs/lse-emu/lse_emu.c` is from
[SildurFX/LSE-Emu](https://github.com/SildurFX/LSE-Emu) (GPL-3.0) via DroidDeck's `feat/lse-emu` branch, and
`rootfs/sysv/sysv.c` is DroidDeck's SysV IPC preload (GPL-3.0).

## Next

A flashable SteamOS-style image with a mainline kernel is in progress in a separate project (steamos-rg40xx).
