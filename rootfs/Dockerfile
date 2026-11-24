# Build context is the repository root: docker build --platform linux/arm64 -f rootfs/Dockerfile .
FROM debian:trixie
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip xz-utils file procps psmisc strace gdb binutils less nano lsof pciutils \
    gcc libc6-dev python3 \
    xvfb xauth x11-xserver-utils x11-utils x11-apps xdotool xterm openbox \
    dbus dbus-x11 \
    libnss3 libnspr4 libgbm1 libdrm2 libgl1 libegl1 libgles2 libgl1-mesa-dri libglx-mesa0 \
    mesa-vulkan-drivers libvulkan1 libgtk-3-0t64 libgtk2.0-0t64 libxss1 libxtst6 libxrandr2 libxcomposite1 \
    libxdamage1 libxkbcommon0 libxkbcommon-x11-0 libasound2t64 libpulse0 libcups2t64 \
    libatk-bridge2.0-0t64 libatspi2.0-0t64 libudev1 libusb-1.0-0 libsdl2-2.0-0 libfontconfig1 \
    libfreetype6 fonts-dejavu-core fonts-liberation libxcursor1 libxi6 libxinerama1 libxshmfence1 \
    libxxf86vm1 libcurl4t64 libdbus-1-3 libopenal1 libva2 libibus-1.0-5 libpipewire-0.3-0t64 \
    libxcb-res0 libxcb-xinput0 libxcb-xfixes0 libxcb-shape0 libxcb-randr0 libxcb-dri3-0 \
    libnm0 libsecret-1-0 libgdk-pixbuf-2.0-0 libpango-1.0-0 libcairo2 libpng16-16t64 libjpeg62-turbo \
    libx11-dev evtest zenity locales \
 && sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# ARMv8.0 has no LSE atomics; the client is built with them inline.
COPY rootfs/lse-emu/lse_emu.c /usr/local/src/lse_emu.c
RUN mkdir -p /usr/local/lib/lse && gcc -shared -fPIC -O2 -march=armv8-a -mno-outline-atomics \
      -Wl,-z,now -o /usr/local/lib/lse/liblse_emu.so /usr/local/src/lse_emu.c -ldl \
 && strip --strip-unneeded /usr/local/lib/lse/liblse_emu.so \
 && ! objdump -d /usr/local/lib/lse/liblse_emu.so | grep -qE $'\t((ld|st)(add|clr|eor|set|smax|smin|umax|umin)|swp|cas)[a-z]*\t'

# The muOS 4.9 kernel is built without CONFIG_SYSVIPC; tier0 creates SysV semaphores.
COPY rootfs/sysv/sysv.c /usr/local/src/sysv.c
RUN mkdir -p /usr/local/lib/sysv && gcc -shared -fPIC -O2 -Wall -pthread -march=armv8-a -mno-outline-atomics \
      -o /usr/local/lib/sysv/libsysv.so /usr/local/src/sysv.c -ldl

COPY rootfs/fbblit/fbblit.c /usr/local/src/fbblit.c
RUN gcc -O2 -Wall -o /usr/local/bin/fbblit /usr/local/src/fbblit.c -lX11

RUN useradd -m -s /bin/bash steam
COPY chroot/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh
