"""Z-fighting finder: pairs of part faces (and SurfaceGui faces) that face the
same way, lie in the same plane, overlap, are visible (not buried against
another solid) and don't look identical - the surfaces that flicker.

  python3 tools/preview/zfight.py dump.json [more.json ...] [--eps 0.012] [--top 80] [--detail] [--floor Y]

--floor Y skips downward faces less than half a stud above a floor at height Y
(no camera ever gets under them).
--detail groups the hits by the two parts' size, colour and material instead of
their names (most map parts are just "Part"), which points at the builder code.

A dump is {"parts": [...]} or {"<scene>": {"parts": [...]}, ...} as written by
run.py / thumb_scene.py / the lobby dump (part: name, class, shape, size, cf,
color, mat, tr, guis). Boxes give six faces, cylinders their two end caps,
wedges their bottom and back; balls none. Invisible parts count only through
their SurfaceGuis.
"""
import json, math, sys
from collections import defaultdict

EPS = 0.012   # studs between planes that still fight
MIN = 0.03    # overlap (studs) needed along each in-plane axis
args = sys.argv[1:]
top_n = 80
if '--eps' in args:
    i = args.index('--eps'); EPS = float(args[i + 1]); del args[i:i + 2]
floor = None
if '--floor' in args:
    i = args.index('--floor'); floor = float(args[i + 1]); del args[i:i + 2]
detail = '--detail' in args
if detail:
    args.remove('--detail')
if '--top' in args:
    i = args.index('--top'); top_n = int(args[i + 1]); del args[i:i + 2]

FACE = {  # normal, u, v (part space)
    'Right': ((1, 0, 0), (0, 1, 0), (0, 0, 1)), 'Left': ((-1, 0, 0), (0, 1, 0), (0, 0, 1)),
    'Top': ((0, 1, 0), (1, 0, 0), (0, 0, 1)), 'Bottom': ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
    'Back': ((0, 0, 1), (1, 0, 0), (0, 1, 0)), 'Front': ((0, 0, -1), (1, 0, 0), (0, 1, 0)),
}


def rot(R, v):
    return (R[0][0] * v[0] + R[0][1] * v[1] + R[0][2] * v[2],
            R[1][0] * v[0] + R[1][1] * v[1] + R[1][2] * v[2],
            R[2][0] * v[0] + R[2][1] * v[1] + R[2][2] * v[2])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


class Part:
    def __init__(self, p, i):
        x, y, z, *r = p['cf']
        self.i = i
        self.p = p
        self.pos = (x, y, z)
        self.R = ((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8]))
        self.half = tuple(s / 2 for s in p['size'])
        self.shape = p.get('shape', 'Block').split('.')[-1]
        self.cls = p.get('class', 'Part')
        self.opaque = (p.get('tr') or 0) < 0.05 and self.cls != 'WedgePart' and self.shape == 'Block'
        self.look = (tuple(p.get('color') or ()), p.get('mat'), round(p.get('tr') or 0, 2))
        ext = [sum(abs(self.R[a][b]) * self.half[b] for b in range(3)) for a in range(3)]
        self.lo = tuple(self.pos[a] - ext[a] for a in range(3))
        self.hi = tuple(self.pos[a] + ext[a] for a in range(3))

    def inside(self, q, margin=-0.005):
        """is world point q inside this (box) part? (a point on a seam between two
        solids counts as inside)"""
        d = sub(q, self.pos)
        for a in range(3):
            loc = self.R[0][a] * d[0] + self.R[1][a] * d[1] + self.R[2][a] * d[2]
            if abs(loc) > self.half[a] - margin:
                return False
        return True


def faces_of(pt):
    p = pt.p
    visible = (p.get('tr') or 0) < 0.999
    gui_faces = {g['face'].split('.')[-1] for g in p.get('guis', [])}
    if pt.cls == 'WedgePart':
        names = ['Bottom', 'Back']
    elif pt.shape == 'Cylinder':
        names = ['Right', 'Left']
    elif pt.shape == 'Ball':
        names = []
    else:
        names = list(FACE)
    out = []
    for f in set(names) | gui_faces:
        if not visible and f not in gui_faces:
            continue
        n, u, v = FACE[f]
        ni, ui, vi = n.index(max(n, key=abs)), u.index(1), v.index(1)
        c = [0, 0, 0]
        c[ni] = n[ni] * pt.half[ni]
        hu, hv = pt.half[ui], pt.half[vi]
        if pt.shape == 'Cylinder' and pt.cls != 'WedgePart' and f in ('Right', 'Left'):
            hu = hv = min(pt.half[1], pt.half[2]) * 0.886  # a square of the disc's area
        centre = tuple(a + b for a, b in zip(pt.pos, rot(pt.R, c)))
        N = rot(pt.R, n)
        out.append({'part': pt, 'face': f, 'c': centre, 'n': N, 'u': rot(pt.R, u), 'v': rot(pt.R, v),
                    'hu': hu, 'hv': hv, 'kind': 'gui' if f in gui_faces else 'part', 'd': dot(N, centre)})
    return out


def overlap(a, b):
    d = sub(b['c'], a['c'])
    for ax in (a['u'], a['v'], b['u'], b['v']):
        ra = a['hu'] * abs(dot(a['u'], ax)) + a['hv'] * abs(dot(a['v'], ax))
        rb = b['hu'] * abs(dot(b['u'], ax)) + b['hv'] * abs(dot(b['v'], ax))
        if abs(dot(d, ax)) > ra + rb - MIN:
            return False
    return True


def load(path):
    d = json.load(open(path))
    if 'parts' in d:
        return [(path, d['parts'])]
    return [(f'{path}:{k}', v['parts']) for k, v in d.items() if isinstance(v, dict) and 'parts' in v]


total = []
for path in args:
    for label, raw in load(path):
        parts = [Part(p, i) for i, p in enumerate(raw)]
        # opaque boxes, hashed, to tell buried faces from visible ones
        SOL = 8.0
        solids = defaultdict(list)
        for pt in parts:
            if pt.opaque:
                for gx in range(math.floor(pt.lo[0] / SOL), math.floor(pt.hi[0] / SOL) + 1):
                    for gy in range(math.floor(pt.lo[1] / SOL), math.floor(pt.hi[1] / SOL) + 1):
                        for gz in range(math.floor(pt.lo[2] / SOL), math.floor(pt.hi[2] / SOL) + 1):
                            solids[(gx, gy, gz)].append(pt)

        def buried(q, skip):
            for pt in solids.get((math.floor(q[0] / SOL), math.floor(q[1] / SOL), math.floor(q[2] / SOL)), ()):
                if pt not in skip and pt.inside(q):
                    return True
            return False

        faces = [f for pt in parts for f in faces_of(pt)]
        # group by direction, then chain faces whose planes are within EPS
        groups = defaultdict(list)
        for f in faces:
            groups[tuple(round(x, 3) for x in f['n'])].append(f)
        hits = []
        for fs in groups.values():
            fs.sort(key=lambda f: f['d'])
            start = 0
            while start < len(fs):
                end = start + 1
                while end < len(fs) and fs[end]['d'] - fs[end - 1]['d'] <= EPS:
                    end += 1
                cluster = fs[start:end]
                start = end
                if len(cluster) < 2:
                    continue
                # 2D grid in the plane
                u0, v0 = cluster[0]['u'], cluster[0]['v']
                CELL = 6.0
                grid = defaultdict(list)
                for k, f in enumerate(cluster):
                    cu, cv = dot(f['c'], u0), dot(f['c'], v0)
                    r = max(f['hu'], f['hv']) * 1.42
                    for gu in range(math.floor((cu - r) / CELL), math.floor((cu + r) / CELL) + 1):
                        for gv in range(math.floor((cv - r) / CELL), math.floor((cv + r) / CELL) + 1):
                            grid[(gu, gv)].append(k)
                seen = set()
                for cell in grid.values():
                    for i in range(len(cell)):
                        for j in range(i + 1, len(cell)):
                            key = (cell[i], cell[j]) if cell[i] < cell[j] else (cell[j], cell[i])
                            if key in seen:
                                continue
                            seen.add(key)
                            a, b = cluster[key[0]], cluster[key[1]]
                            if a['part'] is b['part']:
                                continue
                            if abs(a['d'] - b['d']) > EPS:
                                continue
                            if a['kind'] == 'part' and b['kind'] == 'part' and a['part'].look == b['part'].look:
                                continue  # identical surfaces: nothing to see
                            if not overlap(a, b):
                                continue
                            if floor is not None and a['n'][1] < -0.99 and a['c'][1] < floor + 0.5:
                                continue  # the underside of something on the floor
                            # the middle of their overlap, just off the surface
                            d = sub(b['c'], a['c'])
                            mid = a['c']
                            for ax, h in ((a['u'], a['hu']), (a['v'], a['hv'])):
                                cb = dot(d, ax)
                                rb = b['hu'] * abs(dot(b['u'], ax)) + b['hv'] * abs(dot(b['v'], ax))
                                t = (max(-h, cb - rb) + min(h, cb + rb)) / 2
                                mid = tuple(m + x * t for m, x in zip(mid, ax))
                            q = tuple(m + n * 0.02 for m, n in zip(mid, a['n']))
                            if buried(q, (a['part'], b['part'])):
                                continue
                            hits.append((a, b, mid))
        print(f'{label}: {len(parts)} parts, {len(faces)} faces, {len(hits)} visible coplanar overlaps')
        for a, b, mid in hits:
            def sig(f):
                p = f['part'].p
                if not detail:
                    return p['name']
                return '%s[%s %s %s]' % (p['name'], 'x'.join('%g' % round(v, 2) for v in p['size']),
                                         ','.join(str(round(c)) for c in (p.get('color') or ())), str(p.get('mat')).split('.')[-1])
            total.append((label, sig(a), a['face'], a['kind'], sig(b), b['face'], b['kind'],
                          tuple(round(x, 2) for x in mid), abs(a['d'] - b['d'])))

by = defaultdict(list)
for t in total:
    by[(t[1], t[2], t[3], t[4], t[5], t[6])].append(t)
for k, ts in sorted(by.items(), key=lambda kv: -len(kv[1]))[:top_n]:
    gap = min(t[8] for t in ts)
    print(f'{len(ts):5d}x  gap {gap:.3f}  {k[0]}.{k[1]}({k[2]})  vs  {k[3]}.{k[4]}({k[5]})   e.g. at {ts[0][7]}  [{ts[0][0]}]')
