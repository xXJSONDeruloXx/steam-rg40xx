// Re-exposes the built-in "muOS-Keys" pad as an Xbox 360 pad through uinput.
// The button meaning follows muOS's own gamecontrollerdb entry for muOS-Keys.
// The source device is not grabbed, so muOS's hotkey daemon keeps the volume keys.
// usage: padmap [/dev/input/eventN]   (default: first device named muOS-Keys)
#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int find_pad(void) {
    DIR *d = opendir("/dev/input");
    struct dirent *e;
    char path[300], name[256];
    while (d && (e = readdir(d))) {
        if (strncmp(e->d_name, "event", 5)) continue;
        snprintf(path, sizeof path, "/dev/input/%s", e->d_name);
        int fd = open(path, O_RDONLY);
        if (fd < 0) continue;
        if (ioctl(fd, EVIOCGNAME(sizeof name), name) > 0 && !strcmp(name, "muOS-Keys")) {
            closedir(d);
            fprintf(stderr, "padmap: source %s\n", path);
            return fd;
        }
        close(fd);
    }
    if (d) closedir(d);
    return -1;
}

static void abs_setup(int u, int code, int min, int max, int fuzz, int flat) {
    struct uinput_abs_setup a = {0};
    a.code = code;
    a.absinfo.minimum = min;
    a.absinfo.maximum = max;
    a.absinfo.fuzz = fuzz;
    a.absinfo.flat = flat;
    ioctl(u, UI_SET_ABSBIT, code);
    ioctl(u, UI_ABS_SETUP, &a);
}

static void emit(int u, int type, int code, int value) {
    struct input_event ev = {0};
    ev.type = type;
    ev.code = code;
    ev.value = value;
    if (write(u, &ev, sizeof ev) < 0) perror("padmap: write");
}

int main(int argc, char **argv) {
    int src = argc > 1 ? open(argv[1], O_RDONLY) : find_pad();
    if (src < 0) { fprintf(stderr, "padmap: no muOS-Keys device\n"); return 1; }
    int u = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (u < 0) { perror("padmap: /dev/uinput"); return 1; }

    static const int buttons[] = { BTN_A, BTN_B, BTN_X, BTN_Y, BTN_TL, BTN_TR, BTN_SELECT, BTN_START,
                                   BTN_MODE, BTN_THUMBL, BTN_THUMBR };
    ioctl(u, UI_SET_EVBIT, EV_KEY);
    for (size_t i = 0; i < sizeof buttons / sizeof *buttons; i++) ioctl(u, UI_SET_KEYBIT, buttons[i]);
    ioctl(u, UI_SET_EVBIT, EV_ABS);
    abs_setup(u, ABS_X, -32768, 32767, 16, 128);
    abs_setup(u, ABS_Y, -32768, 32767, 16, 128);
    abs_setup(u, ABS_RX, -32768, 32767, 16, 128);
    abs_setup(u, ABS_RY, -32768, 32767, 16, 128);
    abs_setup(u, ABS_Z, 0, 255, 0, 0);
    abs_setup(u, ABS_RZ, 0, 255, 0, 0);
    abs_setup(u, ABS_HAT0X, -1, 1, 0, 0);
    abs_setup(u, ABS_HAT0Y, -1, 1, 0, 0);

    struct uinput_setup s = {0};
    s.id.bustype = BUS_USB;
    s.id.vendor = 0x045e;
    s.id.product = 0x028e;
    s.id.version = 0x0114;
    snprintf(s.name, sizeof s.name, "Microsoft X-Box 360 pad");
    if (ioctl(u, UI_DEV_SETUP, &s) < 0 || ioctl(u, UI_DEV_CREATE) < 0) { perror("padmap: create"); return 1; }
    fprintf(stderr, "padmap: virtual Xbox 360 pad created\n");

    struct input_event ev;
    while (read(src, &ev, sizeof ev) == sizeof ev) {
        if (ev.type == EV_KEY) {
            int code = -1;
            switch (ev.code) {
            case BTN_EAST:   code = BTN_A; break;
            case BTN_SOUTH:  code = BTN_B; break;
            case BTN_C:      code = BTN_X; break;
            case BTN_NORTH:  code = BTN_Y; break;
            case BTN_WEST:   code = BTN_TL; break;
            case BTN_Z:      code = BTN_TR; break;
            case BTN_TL:     code = BTN_SELECT; break;
            case BTN_TR:     code = BTN_START; break;
            case BTN_TL2:    code = BTN_MODE; break;
            case BTN_TR2:    code = BTN_THUMBL; break;
            case BTN_MODE:   code = BTN_THUMBR; break;
            case BTN_SELECT: emit(u, EV_ABS, ABS_Z, ev.value ? 255 : 0); break;
            case BTN_START:  emit(u, EV_ABS, ABS_RZ, ev.value ? 255 : 0); break;
            }
            if (code >= 0) emit(u, EV_KEY, code, ev.value);
        } else if (ev.type == EV_ABS) {
            int v = ev.value * 8;
            if (v > 32767) v = 32767;
            if (v < -32768) v = -32768;
            switch (ev.code) {
            case ABS_Z:  emit(u, EV_ABS, ABS_X, v); break;
            case ABS_RX: emit(u, EV_ABS, ABS_Y, v); break;
            case ABS_RY: emit(u, EV_ABS, ABS_RX, v); break;
            case ABS_RZ: emit(u, EV_ABS, ABS_RY, v); break;
            case ABS_HAT0X: case ABS_HAT0Y: emit(u, EV_ABS, ev.code, ev.value); break;
            }
        } else if (ev.type == EV_SYN) {
            emit(u, EV_SYN, SYN_REPORT, 0);
        }
    }
    perror("padmap: read");
    return 1;
}
