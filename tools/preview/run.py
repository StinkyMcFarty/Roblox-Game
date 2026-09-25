"""Run the game's Costumes.lua against a mock R15 rig and dump the parts as JSON.

  pip install lupa pillow        (Lua 5.4 in Python)
  python3 tools/preview/run.py wolverine:Comic/Adamantium sentinel:Verity
  then render it: see render.js / shot.cjs
Specs: wolverine:<Skin>[/<Claw>][@pose]   sentinel:<SentinelSkin>[@pose]   (poses: POSES below)
"""
import json, sys, os
from lupa import LuaRuntime
from luau2lua import convert

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(__file__), 'prelude.lua')).read())

def load_src(path):
    return convert(open(os.path.join(REPO, path)).read())
lua.globals().py_src = load_src
lua.execute('''
local RS = game_services("ReplicatedStorage")
local Shared = Instance.new("Folder"); Shared.Name = "Shared"; Shared.Parent = RS
for _, n in ipairs({"Config", "Skins", "Util"}) do
  local m = Instance.new("ModuleScript"); m.Name = n; m.Parent = Shared
  m:SetAttribute("__path", "src/shared/" .. n .. ".lua")
end
local cache = {}
function require(m)
  local path = type(m) == "string" and m or m:GetAttribute("__path")
  if cache[path] then return cache[path] end
  local src = py_src(path)
  local f, err = load(src, "@" .. path)
  if not f then error(err) end
  local r = f()
  cache[path] = r
  return r
end
''')

RIG = {  # name: (size, center) for a standard blocky R15 rig, feet on y=0
    'Head': ((1.2, 1.2, 1.2), (0, 5.31, 0)),
    'UpperTorso': ((2, 1.6, 1), (0, 3.91, 0)),
    'LowerTorso': ((2, 0.4, 1), (0, 2.91, 0)),
    'HumanoidRootPart': ((2, 2, 1), (0, 3.2, 0)),
}
for side, sx in (('Right', 1), ('Left', -1)):
    RIG[side + 'UpperArm'] = ((1, 1.169, 1), (1.5 * sx, 4.1255, 0))
    RIG[side + 'LowerArm'] = ((1, 1.052, 1), (1.5 * sx, 3.015, 0))
    RIG[side + 'Hand'] = ((1, 0.3, 1), (1.5 * sx, 2.339, 0))
    RIG[side + 'UpperLeg'] = ((1, 1.217, 1), (0.5 * sx, 2.1015, 0))
    RIG[side + 'LowerLeg'] = ((1, 1.193, 1), (0.5 * sx, 0.8965, 0))
    RIG[side + 'Foot'] = ((1, 0.3, 1), (0.5 * sx, 0.15, 0))

def make_rig(name='Rig', skin=(226, 176, 140)):
    g = lua.globals()
    char = g.Instance.new('Model')
    char.Name = name
    for n, (size, pos) in RIG.items():
        p = g.Instance.new('MeshPart' if n != 'HumanoidRootPart' else 'Part')
        p.Name = n
        p.Size = g.Vector3.new(*size)
        p.CFrame = g.CFrame.new(*pos)
        p.Color = g.Color3.fromRGB(*skin)
        if n == 'HumanoidRootPart':
            p.Transparency = 1
        p.Parent = char
    hum = g.Instance.new('Humanoid'); hum.Parent = char
    char.Parent = g.workspace
    return char

# Poses: joint rotations in degrees { x, y, z [, tx, ty, tz] }, the same
# conventions as src/client/AnimClips.lua, applied before the suit is built.
lua.execute('''
local J = {
  {"LowerTorso", nil, Vector3.new(0, 2.91, 0)},
  {"UpperTorso", "LowerTorso", Vector3.new(0, 3.11, 0)},
  {"Head", "UpperTorso", Vector3.new(0, 4.71, 0)},
}
for _, s in ipairs({{"Right", 1}, {"Left", -1}}) do
  local n, x = s[1], s[2]
  table.insert(J, {n .. "UpperArm", "UpperTorso", Vector3.new(1.5 * x, 4.55, 0)})
  table.insert(J, {n .. "LowerArm", n .. "UpperArm", Vector3.new(1.5 * x, 3.54, 0)})
  table.insert(J, {n .. "Hand", n .. "LowerArm", Vector3.new(1.5 * x, 2.49, 0)})
  table.insert(J, {n .. "UpperLeg", "LowerTorso", Vector3.new(0.5 * x, 2.71, 0)})
  table.insert(J, {n .. "LowerLeg", n .. "UpperLeg", Vector3.new(0.5 * x, 1.49, 0)})
  table.insert(J, {n .. "Foot", n .. "LowerLeg", Vector3.new(0.5 * x, 0.3, 0)})
end
POSES = {
  feral = {
    LowerTorso = {-14, 20, 0, 0, -0.45, 0}, UpperTorso = {-12, 12, 0}, Head = {18, -16, 0},
    RightUpperArm = {80, 0, 40}, RightLowerArm = {40, 0, 0}, RightHand = {-20, 0, 0},
    LeftUpperArm = {40, 0, -60}, LeftLowerArm = {65, 0, 0}, LeftHand = {-10, 0, 0},
    RightUpperLeg = {35, 0, 10}, RightLowerLeg = {-50, 0, 0}, RightFoot = {18, 0, 0},
    LeftUpperLeg = {-12, 0, -10}, LeftLowerLeg = {-30, 0, 0}, LeftFoot = {25, 0, 0},
  },
  slam = {
    UpperTorso = {10, 0, 0}, Head = {-12, 0, 0},
    RightUpperArm = {165, 0, 28}, RightLowerArm = {40, 0, 0},
    LeftUpperArm = {165, 0, -28}, LeftLowerArm = {40, 0, 0},
    RightUpperLeg = {0, 0, 14}, LeftUpperLeg = {0, 0, -14}, RightFoot = {0, 0, -14}, LeftFoot = {0, 0, 14},
  },
  -- airborne dive: body pitched at the target, right claws sweeping down
  -- across, left arm flung back, legs trailing
  leap = {
    LowerTorso = {-30, 0, 6}, UpperTorso = {-8, 14, 0}, Head = {28, -6, 0},
    LeftUpperArm = {100, 0, -34}, LeftLowerArm = {6, 0, 0}, LeftHand = {-5, 10, 0},
    RightUpperArm = {128, 0, 62}, RightLowerArm = {62, 0, 0}, RightHand = {-10, 80, 0},
    RightUpperLeg = {-35, 0, 10}, RightLowerLeg = {-60, 0, 0}, RightFoot = {-20, 0, 0},
    LeftUpperLeg = {55, 0, -10}, LeftLowerLeg = {-100, 0, 0}, LeftFoot = {-10, 0, 0},
  },
  -- braced: right forearm up to take the blow, left fist cocked back
  -- charging, leaning away from the hit
  block = {
    LowerTorso = {6, -10, 0}, UpperTorso = {8, -12, 0}, Head = {-6, 18, 0},
    RightUpperArm = {62, 0, 44}, RightLowerArm = {48, 0, 0},
    LeftUpperArm = {165, 0, -34}, LeftLowerArm = {48, 0, 0},
    RightUpperLeg = {28, 0, 10}, RightLowerLeg = {-34, 0, 0}, RightFoot = {8, 0, 0},
    LeftUpperLeg = {-26, 0, -14}, LeftLowerLeg = {-14, 0, 0}, LeftFoot = {10, 0, 0},
  },
  stance = {
    LowerTorso = {-6, 12, 0, 0, -0.55, 0}, UpperTorso = {-8, 6, 0}, Head = {12, -12, 0},
    RightUpperArm = {40, 0, 52}, RightLowerArm = {30, 0, 0}, RightHand = {-10, 75, 0},
    LeftUpperArm = {34, 0, -56}, LeftLowerArm = {36, 0, 0}, LeftHand = {-10, -75, 0},
    RightUpperLeg = {22, 0, 18}, RightLowerLeg = {-42, 0, 0}, RightFoot = {20, 0, -10},
    LeftUpperLeg = {10, 0, -20}, LeftLowerLeg = {-30, 0, 0}, LeftFoot = {16, 0, 12},
  },
  lunge = {
    LowerTorso = {-16, 10, 0, 0, -0.5, 0}, UpperTorso = {-10, 8, 0}, Head = {22, -8, 0},
    RightUpperArm = {85, 0, 28}, RightLowerArm = {25, 0, 0}, RightHand = {-15, 0, 0},
    LeftUpperArm = {-10, 0, -62}, LeftLowerArm = {85, 0, 0}, LeftHand = {-20, 0, 0},
    RightUpperLeg = {40, 0, 10}, RightLowerLeg = {-55, 0, 0}, RightFoot = {20, 0, 0},
    LeftUpperLeg = {-14, 0, -12}, LeftLowerLeg = {-32, 0, 0}, LeftFoot = {28, 0, 0},
  },
  stomp = {
    LowerTorso = {0, -10, 0}, UpperTorso = {-6, -14, 0}, Head = {-4, 10, 0},
    RightUpperArm = {-35, 0, 22}, RightLowerArm = {80, 0, 0},
    LeftUpperArm = {55, 0, -18}, LeftLowerArm = {35, 0, 0},
    RightUpperLeg = {-18, 0, 4}, RightLowerLeg = {-12, 0, 0},
    LeftUpperLeg = {24, 0, -4}, LeftLowerLeg = {-24, 0, 0},
  },
}
function posed(char, name)
  local P = POSES[name]
  if not P then return end
  local T = {}
  for _, j in ipairs(J) do
    local part = char:FindFirstChild(j[1])
    local a = P[j[1]] or {0, 0, 0}
    local l = CFrame.new(j[3]) * CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3])) * CFrame.new(-j[3])
    if a[4] then l = CFrame.new(a[4], a[5], a[6]) * l end
    T[j[1]] = j[2] and (T[j[2]] * l) or l
    if part then part.CFrame = T[j[1]] * part.CFrame end
  end
  local hrp = char:FindFirstChild("HumanoidRootPart")
  if hrp then hrp.CFrame = T.LowerTorso * hrp.CFrame end
end
''')

def c3(c):
    return [round(c.R * 255), round(c.G * 255), round(c.B * 255)] if c is not None else None

def ud2(u):
    if u is None: return None
    return [u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset]

def gui_tree(o):
    out = []
    for c in o.GetChildren(o).values():
        cn = c.ClassName
        if cn in ('Frame', 'TextLabel', 'ImageLabel', 'TextButton'):
            node = {
                'class': cn, 'pos': ud2(c.Position) or [0, 0, 0, 0], 'size': ud2(c.Size) or [0, 100, 0, 100],
                'anchor': [c.AnchorPoint.X, c.AnchorPoint.Y] if c.AnchorPoint else [0, 0],
                'rot': c.Rotation or 0, 'bg': c3(c.BackgroundColor3) or [255, 255, 255],
                'bgt': c.BackgroundTransparency if c.BackgroundTransparency is not None else 0,
                'z': c.ZIndex or 1, 'visible': c.Visible is not False, 'clip': c.ClipsDescendants is True,
            }
            for d in c.GetChildren(c).values():
                if d.ClassName == 'UICorner':
                    cr = d.CornerRadius
                    node['corner'] = [cr.Scale, cr.Offset] if cr else [0, 8]
                elif d.ClassName == 'UIStroke':
                    node['stroke'] = {'t': d.Thickness or 1, 'c': c3(d.Color) or [0, 0, 0], 'tr': d.Transparency or 0, 'border': str(d.ApplyStrokeMode) == 'Border'}
                elif d.ClassName == 'UIGradient':
                    node['gradient'] = True
                elif d.ClassName == 'UIAspectRatioConstraint':
                    node['aspect'] = d.AspectRatio or 1
            if cn in ('TextLabel', 'TextButton'):
                node['text'] = c.Text or ''
                node['tc'] = c3(c.TextColor3) or [0, 0, 0]
                node['tt'] = c.TextTransparency or 0
            node['children'] = gui_tree(c)
            out.append(node)
    return out

def dump(model):
    parts = []
    for d in model.GetDescendants(model).values():
        if not d.IsA(d, 'BasePart'):
            continue
        if (d.Transparency or 0) >= 0.999 and not any(ch.ClassName == 'SurfaceGui' for ch in d.GetChildren(d).values()):
            continue
        cf = d.CFrame
        comps = list(cf.GetComponents(cf))
        mesh = None
        guis = []
        lights = []
        for ch in d.GetChildren(d).values():
            if ch.ClassName == 'SpecialMesh':
                mesh = {'type': str(ch.MeshType), 'scale': [ch.Scale.X, ch.Scale.Y, ch.Scale.Z] if ch.Scale else [1, 1, 1]}
            elif ch.ClassName == 'SurfaceGui' and ch.Enabled is not False:
                cs = ch.CanvasSize
                guis.append({'face': str(ch.Face) if ch.Face else 'Front', 'mode': str(ch.SizingMode) if ch.SizingMode else 'FixedSize',
                             'canvas': [cs.X, cs.Y] if cs else [800, 600], 'pps': ch.PixelsPerStud or 50, 'tree': gui_tree(ch)})
            elif ch.ClassName in ('PointLight', 'SpotLight', 'SurfaceLight'):
                lights.append({'c': c3(ch.Color) or [255, 255, 255], 'range': ch.Range or 8, 'b': ch.Brightness or 1})
        parts.append({
            'name': d.Name, 'class': d.ClassName, 'shape': str(d.Shape) if d.Shape else 'Block',
            'size': [d.Size.X, d.Size.Y, d.Size.Z], 'cf': comps, 'color': c3(d.Color),
            'mat': str(d.Material) if d.Material else 'Plastic', 'tr': d.Transparency or 0, 'refl': d.Reflectance or 0,
            'mesh': mesh, 'guis': guis, 'lights': lights,
        })
    return parts

if __name__ == '__main__':
    g = lua.globals()
    lua.execute('Costumes = load(py_src("src/server/Costumes.lua"), "@Costumes")()')
    scenes = {}
    for spec in sys.argv[1:]:
        body, _, pose = spec.partition('@')
        kind, _, arg = body.partition(':')
        if kind == 'wolverine':
            skin, _, claw = arg.partition('/')
            ch = make_rig(skin)
            lua.globals().__char = ch
            lua.execute(f'posed(__char, "{pose}")')
            lua.execute(f'Costumes.Dress(__char, "{skin}")')
            if claw:
                lua.execute(f'local Skins = require(game_services("ReplicatedStorage").Shared.Skins); Costumes.BuildClaws(__char, Skins.Claws["{claw}"], true)')
                # claws are out: show what PopClaws shows (the Verity faces)
                lua.execute('for _, d in ipairs(__char:GetDescendants()) do if d.ClassName == "SurfaceGui" and d.Name == "VerityFaces" then d.Enabled = true end end')
            tex = lua.eval(f'require(game_services("ReplicatedStorage").Shared.Skins).List["{skin}"].Textures')
            scenes[spec] = {'parts': dump(ch), 'skin': skin, 'shirt': bool(tex.Shirt), 'pants': bool(tex.Pants)}
        elif kind == 'sentinel':
            ch = make_rig('Sentinel')
            lua.globals().__char = ch
            lua.execute(f'posed(__char, "{pose}")')
            lua.execute(f'Costumes.DressSentinel(__char, "{arg or "Default"}")')
            scenes[spec] = {'parts': dump(ch)}
    json.dump(scenes, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scene.json'), 'w'))
    print({k: len(v['parts']) for k, v in scenes.items()})
