"""Finish a raw render into a thumbnail: depth-of-field on the background,
depth haze, a painterly (Kuwahara) pass, cinematic grade, glow, vignette,
chromatic fringing and grain.
  python3 tools/preview/thumb_post.py raw.png depth.png out.png WIDTH HEIGHT [focus_far]
"""
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, uniform_filter, map_coordinates

raw, depth, out = sys.argv[1:4]
OW, OH = int(sys.argv[4]), int(sys.argv[5])
far0 = float(sys.argv[6]) if len(sys.argv) > 6 else 0.36

img = np.asarray(Image.open(raw).convert('RGB')).astype(np.float32) / 255
d = np.asarray(Image.open(depth).convert('L')).astype(np.float32) / 255
H, W, _ = img.shape
s = W / 1920  # blur sizes are tuned for 1920 wide


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# 1. depth of field: the far background goes soft, the fighters stay sharp
near_blur = gaussian_filter(img, (2.2 * s, 2.2 * s, 0))
far_blur = gaussian_filter(img, (5.5 * s, 5.5 * s, 0))
k1 = smooth(far0, far0 + 0.12, d)[..., None]
k2 = smooth(far0 + 0.12, far0 + 0.35, d)[..., None]
img = img * (1 - k1) + near_blur * k1
img = img * (1 - k2) + far_blur * k2

# 2. depth haze: the far hangar sinks into violet murk
haze = np.array([0.10, 0.07, 0.19], np.float32)
hk = (smooth(0.3, 0.85, d) * 0.4)[..., None]
img = img * (1 - hk) + haze * hk


# 3. painterly: Kuwahara (each pixel takes the calmest of four neighbouring
# boxes), blended with the original so edges and faces stay crisp
def kuwahara(a, r):
    k = r + 1
    lum = a @ np.array([0.299, 0.587, 0.114], np.float32)
    mean = uniform_filter(a, size=(k, k, 1))
    lm = uniform_filter(lum, size=k)
    var = uniform_filter(lum * lum, size=k) - lm * lm
    h = r // 2
    best_m = None
    best_v = None
    for dy in (-h, h):
        for dx in (-h, h):
            m = np.roll(mean, (dy, dx), axis=(0, 1))
            v = np.roll(var, (dy, dx), axis=(0, 1))
            if best_v is None:
                best_m, best_v = m.copy(), v.copy()
            else:
                pick = v < best_v
                best_v = np.where(pick, v, best_v)
                best_m = np.where(pick[..., None], m, best_m)
    return best_m


paint = kuwahara(img, max(2, int(round(4 * s))))
img = img * 0.35 + paint * 0.65
# unsharp mask to bring back crisp edges after the paint pass
img = np.clip(img + (img - gaussian_filter(img, (1.6 * s, 1.6 * s, 0))) * 0.9, 0, 1)

# 4. glow: highlights bleed a warm halo
lum = img @ np.array([0.299, 0.587, 0.114], np.float32)
hi = img * smooth(0.62, 1.0, lum)[..., None]
glow = gaussian_filter(hi, (18 * s, 18 * s, 0)) * 0.55 + gaussian_filter(hi, (6 * s, 6 * s, 0)) * 0.35
img = 1 - (1 - img) * (1 - np.clip(glow * np.array([1.05, 0.95, 0.9], np.float32), 0, 1))  # screen blend

# 5. grade: teal-violet shadows, warm highlights, richer colour, an S-curve
lum = img @ np.array([0.299, 0.587, 0.114], np.float32)
shadow = (1 - smooth(0.0, 0.45, lum))[..., None]
highl = smooth(0.5, 1.0, lum)[..., None]
img = img + shadow * np.array([-0.01, 0.012, 0.045], np.float32) * 0.9
img = img * (1 + highl * np.array([0.06, 0.01, -0.06], np.float32))
grey = (img @ np.array([0.299, 0.587, 0.114], np.float32))[..., None]
img = grey + (img - grey) * 1.22
img = np.clip(img, 0, 1)
img = img + 0.5 * (img - 0.5) * (1 - np.abs(2 * img - 1)) * 0.55  # gentle S-curve
img = np.clip(img, 0, 1)

# 6. vignette
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
nx, ny = (xx / W - 0.5) * 2, (yy / H - 0.5) * 2
r2 = nx * nx * 0.8 + ny * ny
img = img * (1 - 0.42 * smooth(0.35, 1.6, r2))[..., None]

# 7. chromatic fringing towards the corners
amt = 1.4 * s
dx, dy = nx * amt * r2, ny * amt * r2
def shift(ch, sx, sy):
    return map_coordinates(ch, [yy + sy, xx + sx], order=1, mode='nearest')
img = np.stack([shift(img[..., 0], dx, dy), img[..., 1], shift(img[..., 2], -dx, -dy)], -1)

# 8. grain
rng = np.random.default_rng(5)
img = np.clip(img + rng.normal(0, 0.012, img.shape[:2])[..., None], 0, 1)

Image.fromarray((img * 255 + 0.5).astype(np.uint8)).resize((OW, OH), Image.LANCZOS).save(out)
print('wrote', out, OW, 'x', OH)
