"""Run the game's Costumes.lua against a mock R15 rig and dump the parts as JSON.

  pip install lupa pillow        (Lua 5.4 in Python)
  python3 tools/preview/run.py wolverine:Comic/Adamantium sentinel:Verity
  then render it: see render.js / shot.cjs
Specs: wolverine:<Skin>[/<Claw>]   sentinel:<SentinelSkin>
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
                'z': c.ZIndex or 1, 'visible': c.Visible is not False,
            }
            for d in c.GetChildren(c).values():
                if d.ClassName == 'UICorner':
                    cr = d.CornerRadius
                    node['corner'] = [cr.Scale, cr.Offset] if cr else [0, 8]
                elif d.ClassName == 'UIStroke':
                    node['stroke'] = {'t': d.Thickness or 1, 'c': c3(d.Color) or [0, 0, 0], 'tr': d.Transparency or 0, 'border': str(d.ApplyStrokeMode) == 'Border'}
                elif d.ClassName == 'UIGradient':
                    node['gradient'] = True
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
        kind, _, arg = spec.partition(':')
        if kind == 'wolverine':
            skin, _, claw = arg.partition('/')
            ch = make_rig(skin)
            lua.globals().__char = ch
            lua.execute(f'Costumes.Dress(__char, "{skin}")')
            if claw:
                lua.execute(f'local Skins = require(game_services("ReplicatedStorage").Shared.Skins); Costumes.BuildClaws(__char, Skins.Claws["{claw}"], true)')
            tex = lua.eval(f'require(game_services("ReplicatedStorage").Shared.Skins).List["{skin}"].Textures')
            scenes[spec] = {'parts': dump(ch), 'skin': skin, 'shirt': bool(tex.Shirt), 'pants': bool(tex.Pants)}
        elif kind == 'sentinel':
            ch = make_rig('Sentinel')
            lua.globals().__char = ch
            lua.execute(f'Costumes.DressSentinel(__char, "{arg or "Default"}")')
            scenes[spec] = {'parts': dump(ch)}
    json.dump(scenes, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scene.json'), 'w'))
    print({k: len(v['parts']) for k, v in scenes.items()})
