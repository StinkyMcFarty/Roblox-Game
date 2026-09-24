"""Paints the Wolverine suit textures as Roblox classic clothing templates.

Run:  python3 tools/generate_textures.py
Output: assets/textures/<Skin>_Shirt.png, <Skin>_Pants.png, <Skin>_Face.png

Shirt/Pants use Roblox's 585x559 clothing template. Transparent pixels let the
body colour (the player's skin tone) show through, so bare skin always matches.
Faces are 512x512 transparent decals (sideburns, stubble, brows, beards...).
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
W, H = 585, 559
rng = np.random.default_rng(7)

# ---------------------------------------------------------------------------
# Template regions (x, y, w, h)
# ---------------------------------------------------------------------------
TORSO = {
    "U": (231, 8, 128, 64), "F": (231, 74, 128, 128), "R": (165, 74, 64, 128),
    "L": (361, 74, 64, 128), "B": (427, 74, 128, 128), "D": (231, 204, 128, 64),
}
RIGHT = {  # right arm (shirt) / right leg (pants)
    "U": (217, 289, 64, 64), "D": (217, 485, 64, 64),
    "L": (19, 355, 64, 128), "B": (85, 355, 64, 128), "R": (151, 355, 64, 128), "F": (217, 355, 64, 128),
}
LEFT = {
    "U": (308, 289, 64, 64), "D": (308, 485, 64, 64),
    "F": (308, 355, 64, 128), "L": (374, 355, 64, 128), "B": (440, 355, 64, 128), "R": (506, 355, 64, 128),
}
LIMB_FACES = ["F", "L", "B", "R"]


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


# ---------------------------------------------------------------------------
# Procedural surface generators (return float RGB arrays h x w x 3, 0..255)
# ---------------------------------------------------------------------------

def noise(h, w, scale=1.0, blur=0):
    n = rng.normal(0, 1, (h, w))
    if blur:
        img = Image.fromarray(((n - n.min()) / (np.ptp(n) + 1e-6) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
        n = (np.asarray(img).astype(float) / 255 - 0.5) * 2
    return n * scale


def fabric(h, w, color, weave=6.0, grain=8.0, blotch=10.0):
    y, x = np.mgrid[0:h, 0:w]
    base = np.ones((h, w, 3)) * np.array(color, float)
    pattern = (np.sin(x * 1.9) * np.sin(y * 1.9)) * weave
    pattern += noise(h, w, grain)
    pattern += noise(h, w, blotch, blur=6)
    return base + pattern[..., None]


def spandex(h, w, color):
    """Superhero suit: fine knit + soft sheen."""
    y, x = np.mgrid[0:h, 0:w]
    base = np.ones((h, w, 3)) * np.array(color, float)
    knit = (np.sin(x * 2.6 + np.sin(y * 0.8)) * 3.5) + noise(h, w, 4)
    sheen = noise(h, w, 14, blur=10)
    return base + (knit + sheen)[..., None]


def denim(h, w, color):
    y, x = np.mgrid[0:h, 0:w]
    base = np.ones((h, w, 3)) * np.array(color, float)
    twill = np.sin((x + y) * 1.6) * 10 + np.sin((x + y) * 0.55) * 4
    fade = noise(h, w, 22, blur=12)
    speck = (rng.random((h, w)) > 0.985) * 40
    out = base + (twill + fade + speck)[..., None]
    out[..., 2] += fade * 0.4  # blue shift in faded areas
    return out


def leather(h, w, color):
    base = np.ones((h, w, 3)) * np.array(color, float)
    pores = noise(h, w, 6) + noise(h, w, 10, blur=2)
    creases = noise(h, w, 24, blur=8)
    creases = np.where(creases < -12, creases * 1.6, creases * 0.4)
    return base + (pores + creases)[..., None]


def ribbed(h, w, color):
    y, x = np.mgrid[0:h, 0:w]
    base = np.ones((h, w, 3)) * np.array(color, float)
    ribs = np.sin(x * 1.3) * 9 + noise(h, w, 5)
    return base + ribs[..., None]


def shade_face(arr, strength=40, top=0.0, bottom=0.0, sides=1.0):
    """Ambient occlusion: darken edges, keep the middle bright (rounded look)."""
    h, w = arr.shape[:2]
    y, x = np.mgrid[0:h, 0:w]
    dx = np.abs(x / (w - 1) - 0.5) * 2
    dy = y / (h - 1)
    ao = (dx ** 2.2) * strength * sides + (1 - dy) ** 6 * top * strength + dy ** 6 * bottom * strength
    return arr - ao[..., None]


def to_img(arr, alpha=255):
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    a = np.full(arr.shape[:2] + (1,), alpha, np.uint8)
    return Image.fromarray(np.concatenate([arr, a], axis=2), "RGBA")


def paste(canvas, region, img):
    x, y, w, h = region
    canvas.alpha_composite(img.resize((w, h)), (x, y))


def seam(draw, pts, color=(0, 0, 0), stitch=(235, 215, 150), width=2, dash=4, alpha=170):
    draw.line(pts, fill=rgba(color, alpha), width=width)
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        length = math.hypot(x1 - x0, y1 - y0)
        n = int(length // (dash * 2))
        for k in range(n):
            t0 = (k * 2 * dash) / length
            t1 = (k * 2 * dash + dash) / length
            ox, oy = (y1 - y0) / (length + 1e-6) * 2.5, -(x1 - x0) / (length + 1e-6) * 2.5
            draw.line([(x0 + (x1 - x0) * t0 + ox, y0 + (y1 - y0) * t0 + oy), (x0 + (x1 - x0) * t1 + ox, y0 + (y1 - y0) * t1 + oy)],
                      fill=rgba(stitch, 200), width=1)


def surface(kind, w, h, color, top=0.0, bottom=0.0, strength=38):
    gen = {"spandex": spandex, "fabric": fabric, "denim": denim, "leather": leather, "ribbed": ribbed}[kind]
    return shade_face(gen(h, w, color), strength=strength, top=top, bottom=bottom)


# ---------------------------------------------------------------------------
# Suit painters
# ---------------------------------------------------------------------------
YELLOW = (238, 184, 20)
BLUE = (28, 56, 140)
BLACK = (22, 22, 26)
RED = (160, 24, 24)


def comic_shirt():
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for face, reg in TORSO.items():
        x, y, w, h = reg
        arr = surface("spandex", w, h, YELLOW, top=0.3, bottom=0.2)
        img = to_img(arr)
        d = ImageDraw.Draw(img)
        if face in ("F", "B"):
            # blue side panels sweeping into a V
            for side in (0, 1):
                sx = 0 if side == 0 else w
                inner = w * 0.3 if side == 0 else w * 0.7
                d.polygon([(sx, 0), (inner, 0), (w * 0.47 if side == 0 else w * 0.53, h), (sx, h)], fill=rgba(BLUE))
            # black tiger stripes on the panels
            for i in range(4):
                yy = 18 + i * 26
                d.polygon([(0, yy), (w * 0.26, yy + 8), (0, yy + 14)], fill=rgba(BLACK))
                d.polygon([(w, yy), (w * 0.74, yy + 8), (w, yy + 14)], fill=rgba(BLACK))
            if face == "F":
                # pec + ab definition
                d.arc([w * 0.22, h * 0.08, w * 0.52, h * 0.38], 20, 160, fill=rgba((150, 105, 0), 150), width=3)
                d.arc([w * 0.48, h * 0.08, w * 0.78, h * 0.38], 20, 160, fill=rgba((150, 105, 0), 150), width=3)
                d.line([(w * 0.5, h * 0.38), (w * 0.5, h * 0.9)], fill=rgba((150, 105, 0), 120), width=2)
                for i in range(3):
                    yy = h * (0.5 + i * 0.13)
                    d.line([(w * 0.38, yy), (w * 0.62, yy)], fill=rgba((150, 105, 0), 100), width=2)
        elif face in ("R", "L"):
            d.rectangle([0, 0, w, h], fill=rgba(BLUE))
            for i in range(4):
                yy = 14 + i * 28
                d.polygon([(0, yy), (w * 0.7, yy + 6), (0, yy + 13)], fill=rgba(BLACK))
                d.polygon([(w, yy + 10), (w * 0.3, yy + 16), (w, yy + 23)], fill=rgba(BLACK))
        img = img.filter(ImageFilter.GaussianBlur(0.4))
        paste(c, reg, img)
    for limb in (RIGHT, LEFT):
        for face, reg in limb.items():
            x, y, w, h = reg
            arr = surface("spandex", w, h, YELLOW, strength=45)
            img = to_img(arr)
            d = ImageDraw.Draw(img)
            if face == "U":
                d.rectangle([0, 0, w, h], fill=rgba(BLUE))  # shoulder
            elif face == "D":
                d.rectangle([0, 0, w, h], fill=rgba(BLUE))
            else:
                # blue shoulder cap w/ black trim
                d.rectangle([0, 0, w, h * 0.2], fill=rgba(BLUE))
                d.polygon([(0, h * 0.2), (w, h * 0.2), (w, h * 0.24), (w * 0.5, h * 0.3), (0, h * 0.24)], fill=rgba(BLACK))
                # glove from the forearm down, with black cuff
                d.rectangle([0, h * 0.74, w, h], fill=rgba(BLUE))
                d.polygon([(0, h * 0.72), (w, h * 0.72), (w, h * 0.77), (w * 0.5, h * 0.82), (0, h * 0.77)], fill=rgba(BLACK))
            paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.4)))
    return c


def comic_pants():
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for face, reg in TORSO.items():
        x, y, w, h = reg
        img = to_img(surface("spandex", w, h, BLUE, top=0.2))
        d = ImageDraw.Draw(img)
        if face in ("F", "B", "R", "L"):
            # red belt with a round X buckle
            d.rectangle([0, h * 0.02, w, h * 0.2], fill=rgba(RED))
            d.line([(0, h * 0.04), (w, h * 0.04)], fill=rgba((90, 10, 10)), width=2)
            d.line([(0, h * 0.18), (w, h * 0.18)], fill=rgba((90, 10, 10)), width=2)
            if face == "F":
                cx, cy, r = w / 2, h * 0.11, h * 0.12
                d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgba((25, 25, 30)), outline=rgba((200, 200, 205)), width=3)
                d.line([(cx - r * 0.55, cy - r * 0.55), (cx + r * 0.55, cy + r * 0.55)], fill=rgba((210, 30, 30)), width=4)
                d.line([(cx + r * 0.55, cy - r * 0.55), (cx - r * 0.55, cy + r * 0.55)], fill=rgba((210, 30, 30)), width=4)
        paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.4)))
    for limb in (RIGHT, LEFT):
        for face, reg in limb.items():
            x, y, w, h = reg
            img = to_img(surface("spandex", w, h, YELLOW, strength=45))
            d = ImageDraw.Draw(img)
            if face in ("U", "D"):
                d.rectangle([0, 0, w, h], fill=rgba(BLUE))
            else:
                d.rectangle([0, 0, w, h * 0.16], fill=rgba(BLUE))  # briefs
                # tall blue boots with black folded tops
                d.rectangle([0, h * 0.55, w, h], fill=rgba(BLUE))
                d.polygon([(0, h * 0.5), (w, h * 0.5), (w, h * 0.58), (w * 0.5, h * 0.64), (0, h * 0.58)], fill=rgba(BLACK))
                d.rectangle([0, h * 0.92, w, h], fill=rgba((12, 12, 16)))  # sole
                seam(d, [(w * 0.5, h * 0.66), (w * 0.5, h * 0.9)], color=(10, 20, 60), stitch=(60, 90, 180))
                # thigh stripe detail
                d.polygon([(0, h * 0.24), (w * 0.4, h * 0.28), (0, h * 0.32)], fill=rgba(BLACK))
            paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.4)))
    return c


LEATHER = (96, 60, 36)
WHITE_TANK = (228, 226, 218)
DENIM = (52, 74, 118)
BOOT = (58, 38, 24)


TEE = (196, 198, 196)


def logan_shirt():
    """Heather-grey crew-neck tee (like the reference photo): soft folds, ribbed collar."""
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    def tee(w, h, strength=30, top=0.2, bottom=0.25):
        arr = fabric(h, w, TEE, weave=3, grain=6, blotch=8)
        heather = (rng.random((h, w)) - 0.5) * 22
        arr += heather[..., None]
        # soft diagonal folds
        y, x = np.mgrid[0:h, 0:w]
        folds = np.sin((x * 0.9 + y * 0.35) / 7.0) * 7 + np.sin((x * 0.4 - y * 0.8) / 11.0) * 6
        arr += folds[..., None]
        return shade_face(arr, strength=strength, top=top, bottom=bottom)

    for face, reg in TORSO.items():
        x, y, w, h = reg
        img = to_img(tee(w, h))
        d = ImageDraw.Draw(img)
        if face == "F":
            d.arc([w * 0.3, -h * 0.16, w * 0.7, h * 0.16], 0, 180, fill=rgba((150, 152, 150)), width=7)  # ribbed collar
            d.arc([w * 0.3, -h * 0.16, w * 0.7, h * 0.16], 0, 180, fill=rgba((175, 177, 175)), width=2)
            # chest / stomach fold shadows
            d.arc([w * 0.1, h * 0.25, w * 0.55, h * 0.5], 10, 170, fill=rgba((150, 152, 150), 90), width=3)
            d.arc([w * 0.45, h * 0.25, w * 0.9, h * 0.5], 10, 170, fill=rgba((150, 152, 150), 90), width=3)
            for k in range(3):
                d.arc([w * 0.2, h * (0.6 + k * 0.1), w * 0.8, h * (0.7 + k * 0.1)], 200, 340, fill=rgba((160, 162, 160), 70), width=2)
        if face == "B":
            d.arc([w * 0.3, -h * 0.1, w * 0.7, h * 0.1], 0, 180, fill=rgba((150, 152, 150)), width=6)
        seam(d, [(0, h - 4), (w, h - 4)], color=(140, 142, 140), stitch=(205, 207, 205), width=1)  # hem
        paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.5)))
    for limb in (RIGHT, LEFT):
        for face, reg in limb.items():
            x, y, w, h = reg
            if face == "U":
                img = to_img(tee(w, h, strength=20))
            elif face == "D":
                img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            else:
                img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
                sleeve = to_img(tee(w, int(h * 0.3), strength=36, top=0.0, bottom=0.6))
                img.alpha_composite(sleeve, (0, 0))
                d = ImageDraw.Draw(img)
                seam(d, [(0, h * 0.3 - 3), (w, h * 0.3 - 3)], color=(140, 142, 140), stitch=(205, 207, 205), width=1)
                d.line([(w * 0.45, h * 0.4), (w * 0.52, h * 0.55), (w * 0.48, h * 0.72)], fill=(90, 70, 110, 60), width=2)
            paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.5)))
    return c


def jeans_pants(color=DENIM, boot=BOOT, worn=0.0):
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for face, reg in TORSO.items():
        x, y, w, h = reg
        arr = shade_face(denim(h, w, color), strength=30, top=0.2)
        arr += noise(h, w, 25 * worn, blur=8)[..., None]
        img = to_img(arr)
        d = ImageDraw.Draw(img)
        if face in ("F", "B", "R", "L"):
            # leather belt + loops
            d.rectangle([0, h * 0.03, w, h * 0.16], fill=rgba((70, 42, 24)))
            seam(d, [(0, h * 0.05), (w, h * 0.05)], color=(40, 24, 14), stitch=(160, 130, 90), width=1)
            seam(d, [(0, h * 0.14), (w, h * 0.14)], color=(40, 24, 14), stitch=(160, 130, 90), width=1)
            for lx in (0.15, 0.85):
                d.rectangle([w * lx - 2, 0, w * lx + 2, h * 0.2], fill=rgba(tuple(int(v * 0.85) for v in color)))
            if face == "F":
                d.rectangle([w * 0.43, h * 0.01, w * 0.57, h * 0.18], outline=rgba((200, 200, 205)), width=3)
                seam(d, [(w * 0.5, h * 0.2), (w * 0.5, h * 0.7)], color=(20, 30, 60), stitch=(210, 160, 60))
                d.arc([w * 0.05, h * 0.2, w * 0.4, h * 0.6], 270, 360, fill=rgba((20, 30, 60)), width=2)
                d.arc([w * 0.6, h * 0.2, w * 0.95, h * 0.6], 180, 270, fill=rgba((20, 30, 60)), width=2)
                d.ellipse([w * 0.47, h * 0.3, w * 0.53, h * 0.36], fill=rgba((190, 150, 70)))
            if face == "B":
                for px in (w * 0.1, w * 0.58):
                    d.rectangle([px, h * 0.3, px + w * 0.32, h * 0.7], outline=rgba((20, 30, 60)), width=2)
                    seam(d, [(px + 3, h * 0.3 + 3), (px + w * 0.32 - 3, h * 0.3 + 3)], color=(20, 30, 60), stitch=(210, 160, 60), width=1)
        paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.35)))
    for limb in (RIGHT, LEFT):
        for face, reg in limb.items():
            x, y, w, h = reg
            arr = shade_face(denim(h, w, color), strength=40)
            # faded thighs and knees
            yy = np.linspace(0, 1, h)[:, None]
            arr += (np.exp(-((yy - 0.25) ** 2) / 0.01) * 22 + np.exp(-((yy - 0.5) ** 2) / 0.004) * 18)[..., None] * np.ones((1, w, 1))
            img = to_img(arr)
            d = ImageDraw.Draw(img)
            if face in ("F", "L", "B", "R"):
                seam(d, [(w * 0.08, 0), (w * 0.08, h * 0.7)], color=(20, 30, 60), stitch=(210, 160, 60))
                # boots
                boot_img = to_img(surface("leather", w, int(h * 0.32), boot, strength=25))
                img.alpha_composite(boot_img, (0, int(h * 0.68)))
                d = ImageDraw.Draw(img)
                d.rectangle([0, h * 0.66, w, h * 0.7], fill=rgba(tuple(int(v * 0.7) for v in color)))  # hem
                d.rectangle([0, h * 0.94, w, h], fill=rgba((25, 18, 12)))
                if face == "F":
                    for ly in range(int(h * 0.72), int(h * 0.9), 6):
                        d.line([(w * 0.35, ly), (w * 0.65, ly + 3)], fill=rgba((20, 14, 8)), width=1)
            elif face == "D":
                d.rectangle([0, 0, w, h], fill=rgba((25, 18, 12)))
            paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.35)))
    return c


SKIN_SHADE = (0, 0, 0)


def weaponx_shirt():
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for face, reg in TORSO.items():
        x, y, w, h = reg
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        # bruising + grime (semi transparent over the skin colour)
        bruise = noise(h, w, 1, blur=6)
        a = np.clip((bruise - 0.35) * 160, 0, 90).astype(np.uint8)
        tint = np.zeros((h, w, 4), np.uint8)
        tint[..., 0], tint[..., 1], tint[..., 2], tint[..., 3] = 90, 50, 70, a
        img.alpha_composite(Image.fromarray(tint, "RGBA"))
        d = ImageDraw.Draw(img)
        if face == "F":
            # chest + belly hair
            for _ in range(700):
                px = rng.normal(w * 0.5, w * 0.16)
                py = rng.uniform(h * 0.12, h * 0.95)
                if abs(px - w * 0.5) > w * (0.34 - (py / h) * 0.26):
                    continue
                a = math.radians(rng.uniform(60, 120))
                d.line([(px, py), (px + math.cos(a) * 4, py + math.sin(a) * 4)], fill=(45, 32, 24, 150), width=1)
            # surgical scars with stitches
            for sx, sy, ex, ey in ((0.3, 0.1, 0.45, 0.85), (0.72, 0.15, 0.6, 0.6)):
                p0, p1 = (w * sx, h * sy), (w * ex, h * ey)
                d.line([p0, p1], fill=(140, 30, 30, 220), width=3)
                n = 9
                for k in range(n):
                    t = (k + 0.5) / n
                    px, py = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
                    d.line([(px - 4, py - 1), (px + 4, py + 1)], fill=(30, 20, 20, 230), width=1)
            # electrode pads with wires
            for ex, ey in ((0.25, 0.3), (0.75, 0.3), (0.5, 0.55)):
                cx, cy = w * ex, h * ey
                d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=(210, 210, 215, 255), outline=(120, 120, 125, 255), width=2)
                d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(160, 40, 40, 255))
                d.line([(cx, cy), (cx + (w * 0.5 - cx) * 0.3, 0)], fill=(20, 20, 22, 255), width=2)
        if face == "B":
            d.line([(w * 0.5, h * 0.05), (w * 0.5, h * 0.95)], fill=(140, 30, 30, 200), width=4)
            for k in range(12):
                py = h * (0.08 + k * 0.075)
                d.line([(w * 0.5 - 5, py), (w * 0.5 + 5, py)], fill=(30, 20, 20, 230), width=1)
        paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.5)))
    for limb in (RIGHT, LEFT):
        for face, reg in limb.items():
            x, y, w, h = reg
            img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            d = ImageDraw.Draw(img)
            if face not in ("U", "D"):
                # restraint marks / taped IV at the wrist and bicep bands
                for band in (0.18, 0.66):
                    d.rectangle([0, h * band, w, h * band + 7], fill=(40, 40, 44, 255))
                    d.line([(0, h * band + 3), (w, h * band + 3)], fill=(110, 110, 115, 255), width=1)
                d.rectangle([w * 0.3, h * 0.5, w * 0.7, h * 0.56], fill=(225, 225, 220, 235))  # tape
                d.line([(w * 0.5, h * 0.53), (w * 0.5, 0)], fill=(200, 210, 220, 200), width=2)  # IV line
            paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.5)))
    return c


def weaponx_pants():
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    grey = (58, 60, 66)
    for face, reg in TORSO.items():
        x, y, w, h = reg
        img = to_img(surface("fabric", w, h, grey, top=0.2))
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, w, h * 0.12], fill=rgba((40, 42, 46)))
        if face == "F":
            d.text((w * 0.34, h * 0.4), "X-12", fill=rgba((200, 60, 50)))
        paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.35)))
    for limb in (RIGHT, LEFT):
        for face, reg in limb.items():
            x, y, w, h = reg
            if face == "D":
                img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            else:
                img = to_img(surface("fabric", w, h, grey, strength=35))
                d = ImageDraw.Draw(img)
                if face != "U":
                    d.rectangle([0, h * 0.34, w, h], fill=(0, 0, 0, 0))  # bare legs below the shorts
                    d.rectangle([0, h * 0.3, w, h * 0.345], fill=rgba((40, 42, 46)))
                    d.rectangle([0, h * 0.82, w, h * 0.86], fill=(40, 40, 44, 255))  # ankle cuff
            paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.35)))
    return c


COAT = (64, 46, 34)


def oldman_shirt():
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    henley = (92, 98, 108)
    for face, reg in TORSO.items():
        x, y, w, h = reg
        coat = to_img(surface("leather", w, h, COAT, top=0.2, strength=32) + noise(h, w, 12, blur=5)[..., None])
        if face == "F":
            shirt = to_img(surface("fabric", w, h, henley, strength=20))
            mask = Image.new("L", (w, h), 255)
            md = ImageDraw.Draw(mask)
            md.polygon([(w * 0.34, 0), (w * 0.66, 0), (w * 0.62, h), (w * 0.38, h)], fill=0)
            img = Image.composite(coat, shirt, mask)
            d = ImageDraw.Draw(img)
            for k in range(3):  # henley buttons
                cy = h * (0.12 + k * 0.1)
                d.ellipse([w * 0.48, cy, w * 0.52, cy + 5], fill=rgba((200, 190, 170)))
            d.line([(w * 0.34, 0), (w * 0.38, h)], fill=rgba((30, 22, 16)), width=3)
            d.line([(w * 0.66, 0), (w * 0.62, h)], fill=rgba((30, 22, 16)), width=3)
            # big collar
            d.polygon([(w * 0.2, 0), (w * 0.34, 0), (w * 0.3, h * 0.22)], fill=rgba((52, 36, 26)))
            d.polygon([(w * 0.8, 0), (w * 0.66, 0), (w * 0.7, h * 0.22)], fill=rgba((52, 36, 26)))
        else:
            img = coat
            d = ImageDraw.Draw(img)
            if face == "B":
                seam(d, [(w * 0.5, h * 0.5), (w * 0.5, h)], color=(30, 22, 16), stitch=(140, 120, 90))
        # dust and scuffs
        dust = np.clip((noise(h, w, 1, blur=4) - 0.4) * 120, 0, 70).astype(np.uint8)
        layer = np.zeros((h, w, 4), np.uint8)
        layer[..., 0], layer[..., 1], layer[..., 2], layer[..., 3] = 170, 150, 120, dust
        img.alpha_composite(Image.fromarray(layer, "RGBA"))
        paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.4)))
    for limb in (RIGHT, LEFT):
        for face, reg in limb.items():
            x, y, w, h = reg
            img = to_img(surface("leather", w, h, COAT, strength=34) + noise(h, w, 12, blur=5)[..., None])
            d = ImageDraw.Draw(img)
            if face not in ("U", "D"):
                d.rectangle([0, h * 0.78, w, h], fill=(0, 0, 0, 0))  # bare hands
                d.rectangle([0, h * 0.72, w, h * 0.785], fill=rgba((44, 30, 22)))  # rolled cuff
                for i in range(4):
                    yy = h * (0.38 + i * 0.035)
                    d.arc([w * 0.05, yy - 4, w * 0.95, yy + 4], 0, 180, fill=rgba((40, 28, 20), 170), width=1)
            elif face == "D":
                img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            paste(c, reg, img.filter(ImageFilter.GaussianBlur(0.4)))
    return c


# ---------------------------------------------------------------------------
# Faces (512x512 transparent decals)
# ---------------------------------------------------------------------------
F = 512


def hair_strokes(d, box, color, density=900, length=(8, 18), angle=(80, 100), width=2, alpha=(170, 240)):
    x0, y0, x1, y1 = min(box[0], box[2]), min(box[1], box[3]), max(box[0], box[2]), max(box[1], box[3])
    angle = (min(angle), max(angle))
    for _ in range(density):
        x = rng.uniform(x0, x1)
        y = rng.uniform(y0, y1)
        a = math.radians(rng.uniform(*angle))
        L = rng.uniform(*length)
        j = rng.normal(0, 10)
        col = tuple(int(np.clip(v + j, 0, 255)) for v in color) + (int(rng.uniform(*alpha)),)
        d.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=col, width=width)


def eyes(d, angry=True, iris=(70, 50, 30), y=215, spacing=78, lens=False):
    for s in (-1, 1):
        cx = F / 2 + s * spacing
        if lens:
            d.polygon([(cx - 46 * s, y - 30), (cx + 40 * s, y - 6), (cx + 34 * s, y + 20), (cx - 40 * s, y + 16)], fill=(250, 250, 250, 255), outline=(20, 20, 20, 255))
            continue
        d.ellipse([cx - 30, y - 15, cx + 30, y + 15], fill=(240, 236, 228, 255), outline=(40, 30, 25, 255), width=3)
        d.ellipse([cx - 13, y - 13, cx + 13, y + 13], fill=iris + (255,))
        d.ellipse([cx - 6, y - 6, cx + 6, y + 6], fill=(10, 8, 8, 255))
        d.ellipse([cx - 9, y - 9, cx - 3, y - 3], fill=(255, 255, 255, 220))
        if angry:  # heavy upper lid
            d.polygon([(cx - 34, y - 22), (cx + 34, y - 22), (cx + 34 * -s * -1, y - 4), (cx - 34 * -s, y - 12)], fill=(0, 0, 0, 0))
            d.line([(cx - 32, y - 10 + s * 6), (cx + 32, y - 10 - s * 6)], fill=(45, 30, 22, 255), width=5)


def brows(d, color, y=172, spacing=78, thick=16, angle=18):
    for s in (-1, 1):
        cx = F / 2 + s * spacing
        inner = (cx - s * 40, y + 14)
        outer = (cx + s * 44, y - 12)
        d.line([inner, outer], fill=color + (255,), width=thick)
        hair_strokes(d, (min(inner[0], outer[0]), y - 20, max(inner[0], outer[0]), y + 18), color, density=160, length=(6, 12), angle=(-10 * s + 180 * (s < 0), 10 * s + 180 * (s < 0)), width=2)


def scowl(d, y=360, w=70, color=(90, 40, 40)):
    d.line([(F / 2 - w, y + 12), (F / 2 - w * 0.3, y), (F / 2 + w * 0.3, y), (F / 2 + w, y + 12)], fill=color + (255,), width=6, joint="curve")
    d.line([(F / 2 - 12, y - 58), (F / 2 - 18, y - 30), (F / 2 + 4, y - 26)], fill=(120, 80, 60, 150), width=3)  # nose shadow


def stubble(img, box, color=(40, 30, 25), amount=0.35):
    x0, y0, x1, y1 = box
    arr = np.zeros((F, F, 4), np.uint8)
    yy, xx = np.mgrid[0:F, 0:F]
    cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    falloff = np.clip(1 - (((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2), 0, 1)
    m = rng.random((F, F)) < amount * falloff
    arr[m] = color + (100,)
    img.alpha_composite(Image.fromarray(arr, "RGBA").filter(ImageFilter.GaussianBlur(0.6)))


def mutton_chops(d, color):
    # Narrow sideburns running down the edges of the face into the beard
    for s in (-1, 1):
        x_out = F / 2 + s * 250
        x_in = F / 2 + s * 205
        d.polygon([(x_out, 150), (x_in, 150), (x_in + s * 5, 290), (x_out, 300)], fill=color + (200,))
        hair_strokes(d, (x_out, 150, x_in, 300), color, density=260, length=(8, 14), angle=(80, 100), width=2)


def beard(img, color, box=(70, 250, F - 70, 500), density=3200, alpha=(150, 235)):
    """Short full beard: soft base fill + thousands of short strokes."""
    x0, y0, x1, y1 = box
    base = Image.new("L", (F, F), 0)
    bd = ImageDraw.Draw(base)
    cx = F / 2
    # jaw-hugging beard shape with the mouth left clear
    bd.polygon([(x0, y0), (x0 + 30, y1 - 90), (cx - 60, y1 - 5), (cx + 60, y1 - 5), (x1 - 30, y1 - 90), (x1, y0),
                (x1 - 70, y0 + 60), (cx + 95, 330), (cx, 318), (cx - 95, 330), (x0 + 70, y0 + 60)], fill=200)
    bd.ellipse([cx - 62, 355, cx + 62, 395], fill=0)  # mouth
    base = base.filter(ImageFilter.GaussianBlur(10))
    layer = Image.new("RGBA", (F, F), color + (0,))
    layer.putalpha(base)
    img.alpha_composite(layer)
    d = ImageDraw.Draw(img)
    for _ in range(density):
        px, py = rng.uniform(x0, x1), rng.uniform(y0, y1)
        if np.asarray(base)[int(py) % F, int(px) % F] < 60:
            continue
        a = math.radians(rng.uniform(70, 110) + (px - cx) * 0.08)
        L = rng.uniform(5, 12)
        j = rng.normal(0, 10)
        col = tuple(int(np.clip(v + j, 0, 255)) for v in color) + (int(rng.uniform(*alpha)),)
        d.line([(px, py), (px + math.cos(a) * L, py + math.sin(a) * L)], fill=col, width=2)
    # moustache
    d.polygon([(cx - 95, 345), (cx, 322), (cx + 95, 345), (cx + 85, 362), (cx, 348), (cx - 85, 362)], fill=color + (235,))
    hair_strokes(d, (cx - 95, 322, cx + 95, 362), color, density=500, length=(6, 12), angle=(60, 120), width=2)


def logan_face():
    img = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # under-eye shadows + forehead creases (tired, intense look)
    for s_ in (-1, 1):
        cx = F / 2 + s_ * 78
        d.arc([cx - 36, 205, cx + 36, 250], 20, 160, fill=(80, 50, 40, 90), width=5)
    for k in range(2):
        d.arc([F / 2 - 80, 95 + k * 16, F / 2 + 80, 135 + k * 16], 200, 340, fill=(90, 60, 50, 90), width=2)
    beard(img, (46, 34, 26))
    d = ImageDraw.Draw(img)
    mutton_chops(d, (44, 32, 24))
    brows(d, (38, 28, 20), thick=18)
    eyes(d, iris=(90, 70, 45))
    d.line([(F / 2 - 50, 378), (F / 2 + 50, 378)], fill=(110, 60, 55, 255), width=6)  # lips
    d.line([(F / 2 - 12, 300), (F / 2 - 20, 325), (F / 2 + 6, 330)], fill=(120, 80, 60, 150), width=3)  # nose shadow
    return img


def comic_face():
    img = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # yellow cowl top + black mask around the eyes, skin jaw left transparent
    d.rectangle([0, 0, F, 290], fill=(238, 184, 20, 255))
    d.polygon([(0, 120), (F / 2, 175), (F, 120), (F, 300), (F / 2, 270), (0, 300)], fill=(20, 20, 24, 255))
    for s in (-1, 1):  # the iconic mask "wings"
        d.polygon([(F / 2 + s * 60, 150), (F / 2 + s * 250, 0), (F / 2 + s * 210, 170)], fill=(20, 20, 24, 255))
    eyes(d, lens=True, y=225)
    d.line([(F / 2 - 90, 180), (F / 2 - 20, 205)], fill=(20, 20, 24, 255), width=10)
    d.line([(F / 2 + 90, 180), (F / 2 + 20, 205)], fill=(20, 20, 24, 255), width=10)
    stubble(img, (130, 320, 382, 470), amount=0.2)
    d = ImageDraw.Draw(img)
    scowl(d, y=380)
    return img


def weaponx_face():
    img = logan_face()
    d = ImageDraw.Draw(img)
    for x0, y0, x1, y1 in ((150, 120, 210, 300), (330, 240, 370, 330)):
        d.line([(x0, y0), (x1, y1)], fill=(140, 30, 30, 200), width=4)
        for k in range(6):
            t = (k + 0.5) / 6
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            d.line([(px - 7, py), (px + 7, py)], fill=(30, 20, 20, 220), width=2)
    return img


def oldman_face():
    img = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    grey = (170, 168, 162)
    # wrinkles
    for s in (-1, 1):
        cx = F / 2 + s * 78
        for k in range(3):
            d.arc([cx - 40 + s * 20, 225 + k * 6, cx + 40 + s * 20, 260 + k * 6], 200 if s < 0 else 300, 250 if s < 0 else 350, fill=(90, 60, 50, 150), width=2)
    for k in range(3):
        d.arc([F / 2 - 90, 90 + k * 14, F / 2 + 90, 130 + k * 14], 200, 340, fill=(90, 60, 50, 110), width=2)
    # full grey beard + moustache
    beard(img, grey, box=(80, 260, F - 80, 505), density=3600)
    d = ImageDraw.Draw(img)
    d.polygon([(F / 2 - 110, 320), (F / 2, 300), (F / 2 + 110, 320), (F / 2 + 100, 350), (F / 2, 335), (F / 2 - 100, 350)], fill=(150, 148, 142, 255))
    hair_strokes(d, (F / 2 - 110, 300, F / 2 + 110, 350), (190, 188, 182), density=500, length=(8, 16), angle=(60, 120), width=2)
    d.line([(F / 2 - 50, 378), (F / 2 + 50, 378)], fill=(70, 40, 40, 255), width=5)
    mutton_chops(d, grey)
    brows(d, (185, 183, 178), thick=20)
    eyes(d, iris=(90, 110, 120))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    jobs = {
        "Comic_Shirt": comic_shirt, "Comic_Pants": comic_pants, "Comic_Face": comic_face,
        "Logan_Shirt": logan_shirt, "Logan_Pants": lambda: jeans_pants(), "Logan_Face": logan_face,
        "WeaponX_Shirt": weaponx_shirt, "WeaponX_Pants": weaponx_pants, "WeaponX_Face": weaponx_face,
        "OldManLogan_Shirt": oldman_shirt,
        "OldManLogan_Pants": lambda: jeans_pants((44, 50, 64), (48, 32, 22), worn=1.0),
        "OldManLogan_Face": oldman_face,
    }
    for name, fn in jobs.items():
        path = os.path.join(OUT, name + ".png")
        fn().save(path)
        print("wrote", path)

    # Contact sheet for previewing everything at once
    names = list(jobs)
    sheet = Image.new("RGBA", (4 * 300, 3 * 300), (30, 30, 34, 255))
    for i, name in enumerate(names):
        im = Image.open(os.path.join(OUT, name + ".png")).convert("RGBA")
        im.thumbnail((290, 290))
        bg = Image.new("RGBA", im.size, (200, 160, 130, 255))
        bg.alpha_composite(im)
        col = ["Comic", "Logan", "WeaponX", "OldManLogan"].index(name.split("_")[0])
        row = ["Shirt", "Pants", "Face"].index(name.split("_")[1])
        sheet.paste(bg, (col * 300 + 5, row * 300 + 5))
    sheet.save(os.path.join(OUT, "_preview.png"))


if __name__ == "__main__":
    main()
