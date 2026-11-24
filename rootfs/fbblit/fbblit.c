// Copies an X screen onto /dev/fb0, scaled to fit with bilinear filtering.
// usage: fbblit [interval_ms]   (DISPLAY selects the X server)
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

int main(int argc, char **argv) {
    int interval = argc > 1 ? atoi(argv[1]) : 100;
    Display *d = XOpenDisplay(NULL);
    if (!d) { fprintf(stderr, "fbblit: no X display\n"); return 1; }
    int scr = DefaultScreen(d);
    Window root = RootWindow(d, scr);
    int sw = DisplayWidth(d, scr), sh = DisplayHeight(d, scr);

    int fd = open("/dev/fb0", O_RDWR);
    if (fd < 0) { perror("fb0"); return 1; }
    struct fb_var_screeninfo v;
    struct fb_fix_screeninfo f;
    ioctl(fd, FBIOGET_VSCREENINFO, &v);
    ioctl(fd, FBIOGET_FSCREENINFO, &f);
    if (v.bits_per_pixel != 32) { fprintf(stderr, "fbblit: %u bpp unsupported\n", v.bits_per_pixel); return 1; }
    size_t len = f.smem_len;
    uint8_t *fb = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (fb == MAP_FAILED) { perror("mmap"); return 1; }
    if (v.yoffset) { v.yoffset = 0; ioctl(fd, FBIOPAN_DISPLAY, &v); }
    int dw = v.xres, dh = v.yres, stride = f.line_length;
    fprintf(stderr, "fbblit: %dx%d -> %dx%d (r%u g%u b%u a%u/%u)\n", sw, sh, dw, dh,
            v.red.offset, v.green.offset, v.blue.offset, v.transp.offset, v.transp.length);

    double scale = (double)dw / sw < (double)dh / sh ? (double)dw / sw : (double)dh / sh;
    int ow = (int)(sw * scale), oh = (int)(sh * scale);
    int ox = (dw - ow) / 2, oy = (dh - oh) / 2;
    uint32_t amask = v.transp.length ? (((1u << v.transp.length) - 1) << v.transp.offset) : 0;

    // Precomputed source coordinates (16.16 fixed point) for each output column and row.
    int *xs = malloc(sizeof(int) * ow), *ys = malloc(sizeof(int) * oh);
    for (int x = 0; x < ow; x++) { double s = (x + 0.5) / scale - 0.5; xs[x] = s < 0 ? 0 : (int)(s * 65536); }
    for (int y = 0; y < oh; y++) { double s = (y + 0.5) / scale - 0.5; ys[y] = s < 0 ? 0 : (int)(s * 65536); }

    memset(fb, 0, (size_t)stride * dh);
    struct timespec ts = { interval / 1000, (interval % 1000) * 1000000L };
    for (;;) {
        XImage *img = XGetImage(d, root, 0, 0, sw, sh, AllPlanes, ZPixmap);
        if (!img) { nanosleep(&ts, NULL); continue; }
        const uint8_t *src = (const uint8_t *)img->data;
        int sbl = img->bytes_per_line;
        for (int y = 0; y < oh; y++) {
            int sy = ys[y] >> 16, fy = (ys[y] >> 8) & 0xff;
            int sy1 = sy + 1 < sh ? sy + 1 : sy;
            const uint32_t *r0 = (const uint32_t *)(src + (size_t)sy * sbl);
            const uint32_t *r1 = (const uint32_t *)(src + (size_t)sy1 * sbl);
            uint32_t *out = (uint32_t *)(fb + (size_t)(y + oy) * stride) + ox;
            for (int x = 0; x < ow; x++) {
                int sx = xs[x] >> 16, fx = (xs[x] >> 8) & 0xff;
                int sx1 = sx + 1 < sw ? sx + 1 : sx;
                uint32_t a = r0[sx], b = r0[sx1], c = r1[sx], e = r1[sx1];
                uint32_t px = 0;
                for (int sh8 = 0; sh8 < 24; sh8 += 8) {
                    int ca = (a >> sh8) & 0xff, cb = (b >> sh8) & 0xff, cc = (c >> sh8) & 0xff, ce = (e >> sh8) & 0xff;
                    int top = ca * (256 - fx) + cb * fx, bot = cc * (256 - fx) + ce * fx;
                    int val = (top * (256 - fy) + bot * fy) >> 16;
                    px |= (uint32_t)val << sh8;
                }
                // X gives 0x00RRGGBB; place channels at the framebuffer's offsets.
                uint32_t r = (px >> 16) & 0xff, g = (px >> 8) & 0xff, bl = px & 0xff;
                out[x] = (r << v.red.offset) | (g << v.green.offset) | (bl << v.blue.offset) | amask;
            }
        }
        XDestroyImage(img);
        nanosleep(&ts, NULL);
    }
}
