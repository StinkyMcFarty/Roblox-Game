"""Draws the store icons (game pass + developer products), 512x512 PNGs.

Run:  python3 tools/generate_icons.py
Output: assets/icons/*.png  (upload each one as the item's icon on the Creator Dashboard)

Everything important sits inside the centre circle, since Roblox shows pass
icons cropped to a circle. Numbers use Luckiest Guy (the game's UI font) if
tools/fonts/LuckiestGuy-Regular.ttf exists (free from Google Fonts), otherwise
DejaVu Sans Bold.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
S = 1024  # drawn at 2x, saved at 512
FONT = os.path.join(os.path.dirname(__file__), "fonts", "LuckiestGuy-Regular.ttf")
FALLBACK_FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

GOLD_HI, GOLD_LO = (255, 226, 110), (196, 128, 18)
GOLD_IN_LO, GOLD_IN_HI = (214, 150, 26), (255, 214, 90)
GOLD_EDGE, GOLD_MARK = (120, 72, 6), (150, 90, 8)
YELLOW = (255, 200, 30)
INK = (14, 12, 16)


def font(size):
    path = FONT if os.path.exists(FONT) else FALLBACK_FONT
    return ImageFont.truetype(path, size)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def layer(size=None):
    w, h = (size, size) if isinstance(size, int) else (size or (S, S))
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def gradient(size, c1, c2, angle=90):
    """Linear gradient image (RGB) from c1 to c2; angle 90 = top to bottom."""
    w, h = size
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    a = math.radians(angle)
    d = (x - w / 2) * math.cos(a) + (y - h / 2) * math.sin(a)
    d = (d - d.min()) / max(1e-6, d.max() - d.min())
    c1, c2 = np.array(c1, np.float32), np.array(c2, np.float32)
    img = c1 * (1 - d[..., None]) + c2 * d[..., None]
    return Image.fromarray(img.clip(0, 255).astype(np.uint8), "RGB")


def fill(mask, c1, c2, angle=90):
    """RGBA layer: the gradient where mask (L image) is set."""
    out = gradient(mask.size, c1, c2, angle).convert("RGBA")
    out.putalpha(mask)
    return out


def place(base, img, x, y):
    """Composite img with its top-left corner at (x, y), clipped to the canvas."""
    x, y = int(round(x)), int(round(y))
    sx, sy = max(0, -x), max(0, -y)
    if sx >= img.width or sy >= img.height:
        return
    base.alpha_composite(img.crop((sx, sy, img.width, img.height)), dest=(x + sx, y + sy))


def shadow(img, blur=22, opacity=0.55):
    """A soft drop shadow of img, padded so the blur isn't cut off. Returns (shadow, pad)."""
    pad = blur * 2
    a = Image.new("L", (img.width + pad * 2, img.height + pad * 2), 0)
    a.paste(img.getchannel("A"), (pad, pad))
    a = a.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * opacity))
    sh = Image.new("RGBA", a.size, (0, 0, 0, 255))
    sh.putalpha(a)
    return sh, pad


def paste(base, img, center, with_shadow=True, shadow_offset=(0, 18)):
    x, y = center[0] - img.width / 2, center[1] - img.height / 2
    if with_shadow:
        sh, pad = shadow(img)
        place(base, sh, x + shadow_offset[0] - pad, y + shadow_offset[1] - pad)
    place(base, img, x, y)


def background(inner, outer, slashes=True):
    """Dark radial glow with faint claw gouges across it."""
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    r = np.sqrt((x - S / 2) ** 2 + (y - S * 0.46) ** 2) / (S * 0.72)
    r = np.clip(r, 0, 1) ** 1.3
    c1, c2 = np.array(inner, np.float32), np.array(outer, np.float32)
    img = c1 * (1 - r[..., None]) + c2 * r[..., None]
    bg = Image.fromarray(img.astype(np.uint8), "RGB").convert("RGBA")
    if slashes:
        marks = layer()
        d = ImageDraw.Draw(marks)
        for i in (-1, 0, 1):
            cx, cy = S * 0.5 + i * S * 0.13, S * 0.5
            dx, dy = S * 0.2, S * 0.46
            d.line([(cx + dx, cy - dy), (cx - dx, cy + dy)], fill=(0, 0, 0, 70), width=int(S * 0.045))
            d.line([(cx + dx + 8, cy - dy), (cx - dx + 8, cy + dy)], fill=(255, 255, 255, 18), width=int(S * 0.012))
        bg.alpha_composite(marks.filter(ImageFilter.GaussianBlur(2)))
    # vignette
    v = np.clip((np.sqrt((x - S / 2) ** 2 + (y - S / 2) ** 2) / (S * 0.72) - 0.55) / 0.45, 0, 1) ** 2
    vig = Image.fromarray((v * 150).astype(np.uint8), "L")
    dark = Image.new("RGBA", (S, S), (0, 0, 0, 255))
    dark.putalpha(vig)
    bg.alpha_composite(dark)
    return bg


def text(base, s, center, size, fill_color=YELLOW, stroke=14):
    f = font(size)
    d = ImageDraw.Draw(base)
    box = d.textbbox((0, 0), s, font=f, stroke_width=stroke)
    w, h = box[2] - box[0], box[3] - box[1]
    pos = (center[0] - w / 2 - box[0], center[1] - h / 2 - box[1])
    sh = layer()
    ImageDraw.Draw(sh).text((pos[0], pos[1] + 12), s, font=f, fill=(0, 0, 0, 160), stroke_width=stroke, stroke_fill=(0, 0, 0, 160))
    base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))
    d.text(pos, s, font=f, fill=fill_color, stroke_width=stroke, stroke_fill=INK)


# ---------------------------------------------------------------------------
# props
# ---------------------------------------------------------------------------

def coin(size, rotation=0):
    """The game's Berserker Coin: gold rim, inner face, three claw marks, glint."""
    img = layer(size)
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse([0, 0, size - 1, size - 1], fill=255)
    img.alpha_composite(fill(m, GOLD_HI, GOLD_LO, 60))
    edge = layer(size)
    ImageDraw.Draw(edge).ellipse([0, 0, size - 1, size - 1], outline=GOLD_EDGE + (255,), width=max(2, size // 14))
    img.alpha_composite(edge)
    inner = int(size * 0.68)
    o = (size - inner) // 2
    mi = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mi).ellipse([o, o, o + inner, o + inner], fill=255)
    img.alpha_composite(fill(mi, GOLD_IN_LO, GOLD_IN_HI, 60))
    # three claw marks stamped in the middle
    marks = layer(size)
    dm = ImageDraw.Draw(marks)
    w = max(2, size // 12)
    for i in (-1, 0, 1):
        cx = size / 2 + i * size * 0.16
        dm.rounded_rectangle([cx - w / 2, size / 2 - inner * 0.31, cx + w / 2, size / 2 + inner * 0.31], radius=w // 2, fill=GOLD_MARK + (255,))
    marks = marks.rotate(-18, resample=Image.BICUBIC, center=(size / 2, size / 2))
    img.alpha_composite(marks)
    # glint
    g = layer(size)
    ImageDraw.Draw(g).ellipse([size * 0.2, size * 0.12, size * 0.44, size * 0.25], fill=(255, 255, 255, 170))
    img.alpha_composite(g.rotate(28, resample=Image.BICUBIC, center=(size * 0.32, size * 0.18)))
    return img.rotate(rotation, resample=Image.BICUBIC, expand=False) if rotation else img


def coin_pile(base, spots):
    """spots: (x, y, size, rotation) back to front."""
    for x, y, size, rot in spots:
        paste(base, coin(int(size), rot), (x, y), shadow_offset=(0, int(size * 0.08)))


def blade(length, width):
    """One adamantium claw pointing up: straight back edge, the cutting edge
    sweeping up into a hooked point, a bright bevel ridge down its length."""
    pad = int(width * 0.8)
    w, h = int(width * 1.9) + pad * 2, length + pad
    bend = width * 0.55  # the whole blade curves forward a little

    def x_at(t, side):  # side 0 = back edge, 1 = cutting edge
        curve = bend * t ** 2
        if side == 0:
            return pad + curve
        taper = 1 if t < 0.62 else max(0.0, 1 - ((t - 0.62) / 0.38) ** 1.25)
        return pad + curve + width * taper

    n = 40
    back = [(x_at(i / n, 0), h - i / n * length) for i in range(n + 1)]
    edge = [(x_at(i / n, 1), h - i / n * length) for i in range(n, -1, -1)]
    pts = back + edge
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    img = fill(m, (250, 251, 255), (120, 126, 142), 0)

    def ridge(d):
        line = [(x_at(t, 0) + width * 0.38 * (1 if t < 0.62 else max(0.0, 1 - (t - 0.62) / 0.4)), h - t * length) for t in np.linspace(0.02, 0.93, 30)]
        d.line(line, fill=(255, 255, 255, 200), width=max(2, width // 8))
        d.line([(x + width * 0.2, y) for x, y in line[:22]], fill=(70, 76, 92, 110), width=max(2, width // 10))

    overlay(img, ridge)
    img.putalpha(Image.fromarray(np.minimum(np.array(img.getchannel("A")), np.array(m)), "L"))
    ImageDraw.Draw(img).line(pts + [pts[0]], fill=(34, 36, 46, 255), width=max(2, width // 10))
    return img


def claws(length, width, spread=3, gap=None):
    """Three claws punching out of a gloved fist, pointing up."""
    gap = gap or width * 1.5
    size = int(length * 1.9)
    img = layer(size)
    base_y = size * 0.72
    for i in (-1, 0, 1):
        b = blade(int(length * (0.94 if i else 1.0)), width)
        b = b.rotate(-i * spread, resample=Image.BICUBIC, expand=True)
        cx = size / 2 + i * gap
        img.alpha_composite(b, (int(cx - b.width / 2 + width * 0.2), int(base_y - b.height + width * 0.6)))
    # the fist the claws come out of
    fw, fh = gap * 2 + width * 2.2, width * 2.3
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([size / 2 - fw / 2, base_y - fh * 0.25, size / 2 + fw / 2, base_y + fh * 0.75], radius=int(fh * 0.42), fill=255)
    img.alpha_composite(fill(m, (86, 66, 52), (38, 28, 22), 90))

    def knuckles(d):
        for i in (-1, 0, 1):
            cx = size / 2 + i * gap + width * 0.45
            d.ellipse([cx - width * 0.62, base_y - fh * 0.32, cx + width * 0.62, base_y + fh * 0.12], fill=(120, 94, 76, 255), outline=(26, 18, 14, 255), width=max(2, width // 10))
            d.ellipse([cx - width * 0.35, base_y - fh * 0.26, cx + width * 0.05, base_y - fh * 0.08], fill=(255, 255, 255, 60))
        d.rounded_rectangle([size / 2 - fw / 2, base_y - fh * 0.25, size / 2 + fw / 2, base_y + fh * 0.75], radius=int(fh * 0.42), outline=(22, 16, 12, 255), width=max(3, width // 8))

    overlay(img, knuckles)
    return img


def crown(width):
    h = int(width * 0.72)
    img = layer((width, h))
    m = Image.new("L", (width, h), 0)
    band_top = h * 0.62
    pts = [(0.04 * width, h * 0.96), (0.02 * width, h * 0.2), (0.24 * width, band_top * 0.62), (0.33 * width, h * 0.08),
           (0.5 * width, band_top * 0.55), (0.67 * width, h * 0.08), (0.76 * width, band_top * 0.62), (0.98 * width, h * 0.2),
           (0.96 * width, h * 0.96)]
    ImageDraw.Draw(m).polygon(pts, fill=255)
    img.alpha_composite(fill(m, (255, 236, 130), (200, 120, 10), 80))
    d = ImageDraw.Draw(img)
    d.polygon(pts, outline=(96, 56, 4, 255), width=max(3, width // 60))
    d.rectangle([0.04 * width, h * 0.74, 0.96 * width, h * 0.9], fill=(170, 100, 8, 255), outline=(96, 56, 4, 255), width=max(2, width // 80))
    r = width * 0.055
    for x, color in ((0.5, (220, 30, 40)), (0.27, (40, 140, 255)), (0.73, (40, 140, 255))):
        cx, cy = x * width, h * 0.82
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (255,), outline=(96, 56, 4, 255), width=max(2, width // 90))
        overlay(img, lambda o, cx=cx, cy=cy: o.ellipse([cx - r * 0.5, cy - r * 0.6, cx - r * 0.05, cy - r * 0.15], fill=(255, 255, 255, 170)))
    for x, y in ((0.02, 0.2), (0.33, 0.08), (0.67, 0.08), (0.98, 0.2)):
        cx, cy = x * width, y * h
        d.ellipse([cx - r * 0.7, cy - r * 0.7, cx + r * 0.7, cy + r * 0.7], fill=(255, 240, 170, 255), outline=(96, 56, 4, 255), width=max(2, width // 90))
    return img


def die(size, pips, rotation):
    img = layer(size)
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=size // 5, fill=255)
    img.alpha_composite(fill(m, (250, 70, 70), (170, 16, 24), 70))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=size // 5, outline=(70, 6, 10, 255), width=max(3, size // 26))
    overlay(img, lambda o: o.rounded_rectangle([size * 0.1, size * 0.07, size * 0.9, size * 0.3], radius=size // 8, fill=(255, 255, 255, 45)))
    spots = {
        1: [(0.5, 0.5)], 2: [(0.28, 0.28), (0.72, 0.72)], 3: [(0.26, 0.26), (0.5, 0.5), (0.74, 0.74)],
        4: [(0.28, 0.28), (0.72, 0.28), (0.28, 0.72), (0.72, 0.72)],
        5: [(0.26, 0.26), (0.74, 0.26), (0.5, 0.5), (0.26, 0.74), (0.74, 0.74)],
        6: [(0.28, 0.24), (0.72, 0.24), (0.28, 0.5), (0.72, 0.5), (0.28, 0.76), (0.72, 0.76)],
    }[pips]
    r = size * 0.085
    for x, y in spots:
        d.ellipse([x * size - r, y * size - r, x * size + r, y * size + r], fill=(255, 255, 255, 255))
    pad = size // 3
    big = layer(size + pad * 2)
    big.alpha_composite(img, (pad, pad))
    return big.rotate(rotation, resample=Image.BICUBIC)


def pouch(width):
    h = int(width * 1.05)
    img = layer((width, h))
    m = Image.new("L", (width, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([0.02 * width, h * 0.3, 0.98 * width, h * 0.99], fill=255)  # belly
    d.polygon([(0.3 * width, h * 0.36), (0.38 * width, h * 0.2), (0.62 * width, h * 0.2), (0.7 * width, h * 0.36)], fill=255)  # neck
    d.polygon([(0.22 * width, h * 0.02), (0.4 * width, h * 0.18), (0.6 * width, h * 0.18), (0.78 * width, h * 0.02), (0.5 * width, h * 0.1)], fill=255)  # flare
    img.alpha_composite(fill(m, (178, 108, 56), (92, 48, 20), 70))
    o = ImageDraw.Draw(img)
    edge = Image.fromarray((np.array(m.filter(ImageFilter.FIND_EDGES)) > 40).astype(np.uint8) * 255, "L").filter(ImageFilter.MaxFilter(7))
    ink = Image.new("RGBA", (width, h), (54, 26, 8, 255))
    ink.putalpha(edge)
    img.alpha_composite(ink)
    o.rounded_rectangle([0.3 * width, h * 0.19, 0.7 * width, h * 0.27], radius=int(width * 0.03), fill=(226, 190, 120, 255), outline=(90, 60, 20, 255), width=max(3, width // 70))
    overlay(img, lambda d: d.ellipse([0.16 * width, h * 0.4, 0.4 * width, h * 0.56], fill=(255, 235, 200, 45)))  # sheen

    def stamp(d):  # the Berserker claw stamp
        for i in (-1, 0, 1):
            cx = 0.5 * width + i * width * 0.1
            d.line([(cx + width * 0.05, h * 0.52), (cx - width * 0.05, h * 0.82)], fill=(60, 28, 8, 230), width=max(4, width // 28))

    overlay(img, stamp)
    return img


def crate(width):
    h = int(width * 0.8)
    img = layer((width, h))
    d = ImageDraw.Draw(img)
    planks = 4
    for i in range(planks):
        y0, y1 = h * i / planks, h * (i + 1) / planks
        m = Image.new("L", (width, h), 0)
        ImageDraw.Draw(m).rectangle([0, y0, width - 1, y1], fill=255)
        tone = (194, 132, 70) if i % 2 == 0 else (178, 118, 60)
        img.alpha_composite(fill(m, tone, tuple(int(c * 0.72) for c in tone), 90))
        d.line([(0, y1), (width, y1)], fill=(74, 40, 14, 255), width=max(3, width // 90))
        overlay(img, lambda o, y0=y0, y1=y1: [o.line([(width * 0.08 + g * 17 % 60, y0 + (y1 - y0) * (0.2 + 0.12 * g)),
                                                        (width * 0.92 - g * 23 % 70, y0 + (y1 - y0) * (0.2 + 0.12 * g) + 3)],
                                                       fill=(120, 72, 30, 70), width=2) for g in range(6)])  # grain
    frame = max(10, width // 12)
    wood = (130, 80, 34, 255)
    d.rectangle([0, 0, frame, h], fill=wood)
    d.rectangle([width - frame, 0, width, h], fill=wood)
    d.line([(frame, h - frame * 0.6), (width - frame, frame * 0.6)], fill=wood, width=frame)
    d.rectangle([0, 0, width - 1, h - 1], outline=(58, 30, 10, 255), width=max(4, width // 60))
    for x in (frame / 2, width - frame / 2):  # nails
        for y in (frame * 0.8, h - frame * 0.8):
            d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(70, 70, 76, 255))
    # stencil claw marks
    overlay(img, lambda o: [o.line([(width * 0.5 + i * width * 0.09 + width * 0.05, h * 0.22),
                                    (width * 0.5 + i * width * 0.09 - width * 0.05, h * 0.62)],
                                   fill=(60, 30, 10, 170), width=max(5, width // 30)) for i in (-1, 0, 1)])
    return img


def vault(size):
    img = layer(size)
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse([0, 0, size - 1, size - 1], fill=255)
    img.alpha_composite(fill(m, (196, 204, 216), (74, 80, 94), 60))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, size - 1, size - 1], outline=(30, 32, 40, 255), width=max(6, size // 40))
    ring = size * 0.12
    d.ellipse([ring, ring, size - ring, size - ring], outline=(50, 54, 64, 255), width=max(5, size // 50))
    # bolts around the rim
    for k in range(12):
        a = k / 12 * math.tau
        cx, cy = size / 2 + math.cos(a) * size * 0.44, size / 2 + math.sin(a) * size * 0.44
        r = size * 0.025
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(230, 232, 238, 255), outline=(40, 42, 50, 255), width=3)
    # handle wheel
    c, R = size / 2, size * 0.2
    for k in range(3):
        a = k / 3 * math.pi
        d.line([(c + math.cos(a) * R, c + math.sin(a) * R), (c - math.cos(a) * R, c - math.sin(a) * R)], fill=(40, 42, 50, 255), width=max(8, size // 30))
    d.ellipse([c - R, c - R, c + R, c + R], outline=(40, 42, 50, 255), width=max(8, size // 30))
    d.ellipse([c - size * 0.06, c - size * 0.06, c + size * 0.06, c + size * 0.06], fill=(255, 196, 40, 255), outline=(40, 42, 50, 255), width=4)
    # three claw gouges torn across the door, glowing hot inside
    g = layer(size)
    dg = ImageDraw.Draw(g)
    for i in (-1, 0, 1):
        x0 = size * (0.62 + i * 0.12)
        dg.line([(x0 + size * 0.12, size * 0.1), (x0 - size * 0.16, size * 0.9)], fill=(20, 18, 22, 255), width=int(size * 0.05))
        dg.line([(x0 + size * 0.12, size * 0.1), (x0 - size * 0.16, size * 0.9)], fill=(255, 140, 40, 255), width=int(size * 0.014))
    g.putalpha(Image.fromarray(np.minimum(np.array(g.getchannel("A")), np.array(m)), "L"))
    img.alpha_composite(g)
    overlay(img, lambda o: o.arc([size * 0.06, size * 0.06, size * 0.94, size * 0.94], 200, 250, fill=(255, 255, 255, 120), width=max(4, size // 60)))
    return img


def overlay(img, draw):
    """Run draw(ImageDraw) on a transparent layer and blend it over img."""
    top = layer(img.size)
    draw(ImageDraw.Draw(top))
    img.alpha_composite(top)


def glow(base, center, radius, color, strength=180):
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    r = np.sqrt((x - center[0]) ** 2 + (y - center[1]) ** 2) / radius
    a = (np.clip(1 - r, 0, 1) ** 2 * strength).astype(np.uint8)
    g = Image.new("RGBA", (S, S), color + (255,))
    g.putalpha(Image.fromarray(a, "L"))
    base.alpha_composite(g)


# ---------------------------------------------------------------------------
# icons
# ---------------------------------------------------------------------------

def double_chance():
    img = background((110, 50, 170), (18, 8, 30))
    glow(img, (S * 0.5, S * 0.45), S * 0.42, (190, 120, 255), 120)
    paste(img, die(int(S * 0.32), 6, 16), (S * 0.35, S * 0.4))
    paste(img, die(int(S * 0.32), 5, -12), (S * 0.65, S * 0.38))
    text(img, "2X", (S * 0.5, S * 0.72), int(S * 0.3), stroke=18)
    return img


def become_wolverine():
    img = background((170, 24, 24), (26, 4, 6))
    glow(img, (S * 0.5, S * 0.5), S * 0.45, (255, 90, 40), 140)
    # fists crossed, the claws out in an X (like his wake-up in the tank). The
    # blades' midpoints sit at the centre of each image, so both are placed on
    # the same spot and cross halfway along.
    length, width = int(S * 0.44), int(S * 0.034)
    up_right = claws(length, width).rotate(-40, resample=Image.BICUBIC)
    up_left = claws(length, width).transpose(Image.FLIP_LEFT_RIGHT).rotate(40, resample=Image.BICUBIC)
    paste(img, up_right, (S * 0.5, S * 0.6))
    paste(img, up_left, (S * 0.5, S * 0.6))
    paste(img, crown(int(S * 0.34)), (S * 0.5, S * 0.2))
    return img


def coin_pack(amount, prop):
    img = background((120, 84, 20), (20, 14, 6))
    glow(img, (S * 0.5, S * 0.48), S * 0.4, (255, 200, 60), 150)
    prop(img)
    text(img, amount, (S * 0.5, S * 0.8), int(S * 0.17), stroke=14)
    return img


def handful(img):
    coin_pile(img, [
        (S * 0.36, S * 0.5, S * 0.26, 14), (S * 0.64, S * 0.5, S * 0.26, -10),
        (S * 0.5, S * 0.42, S * 0.36, 0),
    ])


def pouch_pack(img):
    paste(img, pouch(int(S * 0.44)), (S * 0.5, S * 0.4))
    coin_pile(img, [
        (S * 0.28, S * 0.6, S * 0.16, 20), (S * 0.72, S * 0.6, S * 0.17, -14),
        (S * 0.38, S * 0.64, S * 0.19, -6), (S * 0.62, S * 0.65, S * 0.18, 10),
    ])


def crate_pack(img):
    coin_pile(img, [
        (S * 0.36, S * 0.28, S * 0.16, 12), (S * 0.5, S * 0.25, S * 0.17, -8), (S * 0.64, S * 0.29, S * 0.16, 16),
        (S * 0.43, S * 0.21, S * 0.15, 4), (S * 0.57, S * 0.2, S * 0.15, -18),
    ])
    paste(img, crate(int(S * 0.52)), (S * 0.5, S * 0.49))
    coin_pile(img, [(S * 0.25, S * 0.66, S * 0.15, 18), (S * 0.76, S * 0.66, S * 0.15, -20)])


def vault_pack(img):
    paste(img, vault(int(S * 0.5)), (S * 0.5, S * 0.4))
    coin_pile(img, [
        (S * 0.24, S * 0.66, S * 0.15, 20), (S * 0.76, S * 0.66, S * 0.15, -16),
        (S * 0.35, S * 0.63, S * 0.18, -8), (S * 0.65, S * 0.63, S * 0.18, 12),
        (S * 0.5, S * 0.62, S * 0.21, 0),
    ])


ICONS = {
    "Pass_2xWolverineChance": double_chance,
    "Product_BecomeWolverine": become_wolverine,
    "Product_HandfulOfCoins": lambda: coin_pack("500", handful),
    "Product_PouchOfCoins": lambda: coin_pack("1,200", pouch_pack),
    "Product_CrateOfCoins": lambda: coin_pack("3,000", crate_pack),
    "Product_WeaponXVault": lambda: coin_pack("7,000", vault_pack),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in ICONS.items():
        img = fn().convert("RGB").resize((512, 512), Image.LANCZOS)
        path = os.path.join(OUT, name + ".png")
        img.save(path, optimize=True)
        print("wrote", path)


if __name__ == "__main__":
    main()
