"""Thumbnail scene: the Sentinel Hangar (built by the real Facility.Build) and
posed characters (the real Costumes) dumped to hangar.json + chars.json.
  python3 tools/preview/thumb_scene.py . tools/preview "wolf=wolverine:Logan/Adamantium:ready" "sd=sentinel:Default:guard" "sv=sentinel:Verity:charge"
"""
import json, os, sys
repo = os.path.abspath(sys.argv[1]); OUT = os.path.abspath(sys.argv[2])
sys.path.insert(0, os.path.join(repo, 'tools', 'preview'))
os.chdir(os.path.join(repo, 'tools', 'preview'))
import run
from run import lua, make_rig, c3, gui_tree

lua.execute('''
local cs = game_services("CollectionService")
rawset(cs, "AddTag", function() end)
rawset(cs, "HasTag", function() return false end)
rawset(cs, "GetTagged", function() return {} end)
rawset(game_services("HttpService"), "JSONEncode", function() return "{}" end)
workspace.Terrain = Instance.new("Terrain")
local SSS = game_services("ServerScriptService")
local Server = Instance.new("Folder"); Server.Name = "Server"; Server.Parent = SSS
for _, n in ipairs({"Costumes", "MapBuilder", "Facility"}) do
  local m = Instance.new("ModuleScript"); m.Name = n; m.Parent = Server
  m:SetAttribute("__path", "src/server/" .. n .. ".lua")
end
script = Server.Facility
Costumes = require(Server.Costumes)
Facility = require(Server.Facility)
Skins = require(game_services("ReplicatedStorage").Shared.Skins)
Config = require(game_services("ReplicatedStorage").Shared.Config)
Facility.Build()
''')

LIGHTS = ('PointLight', 'SpotLight', 'SurfaceLight')

def dump_part(d):
    kids = list(d.GetChildren(d).values())
    cf = d.CFrame
    mesh, guis, lights = None, [], []
    for ch in kids:
        if ch.ClassName == 'SpecialMesh':
            mesh = {'type': str(ch.MeshType), 'scale': [ch.Scale.X, ch.Scale.Y, ch.Scale.Z] if ch.Scale else [1, 1, 1]}
        elif ch.ClassName == 'SurfaceGui' and ch.Enabled is not False:
            cs = ch.CanvasSize
            guis.append({'face': str(ch.Face) if ch.Face else 'Front', 'mode': str(ch.SizingMode) if ch.SizingMode else 'FixedSize',
                         'canvas': [cs.X, cs.Y] if cs else [800, 600], 'pps': ch.PixelsPerStud or 50, 'tree': gui_tree(ch)})
        elif ch.ClassName in LIGHTS:
            lights.append({'cls': ch.ClassName, 'c': c3(ch.Color) or [255, 255, 255], 'range': ch.Range or 8,
                           'b': ch.Brightness if ch.Brightness is not None else 1, 'face': str(ch.Face) if ch.Face else 'Front',
                           'angle': ch.Angle if ch.Angle is not None else 90})
    return {
        'name': d.Name, 'class': d.ClassName, 'shape': str(d.Shape) if d.Shape else 'Block',
        'size': [d.Size.X, d.Size.Y, d.Size.Z], 'cf': list(cf.GetComponents(cf)), 'color': c3(d.Color),
        'mat': str(d.Material) if d.Material else 'Plastic', 'tr': d.Transparency or 0, 'refl': d.Reflectance or 0,
        'mesh': mesh, 'guis': guis, 'lights': lights,
    }

def dump(model, box=None):
    parts = []
    for d in model.GetDescendants(model).values():
        if not d.IsA(d, 'BasePart'):
            continue
        kids = list(d.GetChildren(d).values())
        if (d.Transparency or 0) >= 0.999 and not any(ch.ClassName in ('SurfaceGui',) + LIGHTS for ch in kids):
            continue
        if box:
            p, s = d.Position, d.Size
            r = max(s.X, s.Y, s.Z) / 2
            if p.X + r < box[0] or p.X - r > box[3] or p.Y + r < box[1] or p.Y - r > box[4] or p.Z + r < box[2] or p.Z - r > box[5]:
                continue
        parts.append(dump_part(d))
    return parts

hangar = dump(lua.eval('workspace.Map'), (-60, -2, 50, 60, 40, 146))
json.dump({'parts': hangar}, open(os.path.join(OUT, 'hangar.json'), 'w'))
print('hangar', len(hangar), 'parts', sum(len(p['lights']) for p in hangar), 'lights')

# poses for the thumbnail (degrees, AnimClips conventions; see run.py POSES)
lua.execute('''
POSES.ready = {
  LowerTorso = {-20, 0, 0, 0, -0.75, 0}, UpperTorso = {-16, 0, 0}, Head = {26, 0, 0},
  RightUpperArm = {28, 0, 48}, RightLowerArm = {48, 0, 0}, RightHand = {-35, 70, 0},
  LeftUpperArm = {28, 0, -48}, LeftLowerArm = {48, 0, 0}, LeftHand = {-35, -70, 0},
  RightUpperLeg = {34, 0, 16}, RightLowerLeg = {-58, 0, 0}, RightFoot = {24, 0, -12},
  LeftUpperLeg = {-14, 0, -18}, LeftLowerLeg = {-38, 0, 0}, LeftFoot = {22, 0, 14},
}
POSES.guard = { -- Sentinel: left fist cocked back, right forearm up, braced
  LowerTorso = {4, 14, 0, 0, -0.35, 0}, UpperTorso = {10, 16, 0}, Head = {-8, -22, 0},
  RightUpperArm = {48, 0, 34}, RightLowerArm = {62, 0, 0},
  LeftUpperArm = {-30, 0, -38}, LeftLowerArm = {95, 0, 0},
  RightUpperLeg = {30, 0, 12}, RightLowerLeg = {-40, 0, 0}, RightFoot = {10, 0, 0},
  LeftUpperLeg = {-22, 0, -16}, LeftLowerLeg = {-16, 0, 0}, LeftFoot = {10, 0, 0},
}
POSES.charge = { -- Sentinel: stepping in, right fist drawn back to swing
  LowerTorso = {-10, -18, 0, 0, -0.4, 0}, UpperTorso = {-8, -22, 0}, Head = {12, 28, 0},
  RightUpperArm = {-40, 0, 40}, RightLowerArm = {100, 0, 0},
  LeftUpperArm = {70, 0, -24}, LeftLowerArm = {40, 0, 0},
  RightUpperLeg = {-20, 0, 12}, RightLowerLeg = {-20, 0, 0}, RightFoot = {12, 0, 0},
  LeftUpperLeg = {40, 0, -12}, LeftLowerLeg = {-50, 0, 0}, LeftFoot = {16, 0, 0},
}
''')
chars = {}
for key, kind, arg, pose in [(a.split('=')[0], *a.split('=')[1].split(':')) for a in sys.argv[3:]]:
    ch = make_rig(key)
    lua.globals().__char = ch
    lua.execute(f'posed(__char, "{pose}")')
    if kind == 'wolverine':
        skin, _, claw = arg.partition('/')
        lua.execute(f'Costumes.Dress(__char, "{skin}")')
        lua.execute(f'Costumes.BuildClaws(__char, Skins.Claws["{claw or "Adamantium"}"], true)')
        tex = lua.eval(f'Skins.List["{skin}"].Textures')
        chars[key] = {'parts': dump(ch), 'skin': skin, 'shirt': bool(tex.Shirt), 'pants': bool(tex.Pants)}
    else:
        lua.execute(f'Costumes.DressSentinel(__char, "{arg}")')
        chars[key] = {'parts': dump(ch)}
json.dump(chars, open(os.path.join(OUT, 'chars.json'), 'w'))
print({k: len(v['parts']) for k, v in chars.items()}, 'sentinel scale', lua.eval('Config.Sentinel.Scale'))
