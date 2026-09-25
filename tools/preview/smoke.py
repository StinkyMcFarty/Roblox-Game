"""Strict smoke test: builds the lobby and dresses every suit/claw/Sentinel skin
against a mock Roblox that rejects unknown classes, properties, enum items and
wrongly-typed values, like the real engine does. Run before pushing server
changes:  python3 tools/preview/smoke.py
(pip install lupa; the Roblox API dump downloads once into api.json)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import lua, make_rig
import strict

strict.install(lua)
lua.execute('''
local cs = game_services("CollectionService")
rawset(cs, "AddTag", function() end)
rawset(cs, "HasTag", function() return false end)
rawset(cs, "GetTagged", function() return {} end)
workspace.Terrain = Instance.new("Terrain")
local SSS = game_services("ServerScriptService")
local Server = Instance.new("Folder"); Server.Name = "Server"; Server.Parent = SSS
for _, n in ipairs({"Costumes", "MapBuilder"}) do
  local m = Instance.new("ModuleScript"); m.Name = n; m.Parent = Server
  m:SetAttribute("__path", "src/server/" .. n .. ".lua")
end
script = Server.MapBuilder
Costumes = require(Server.Costumes)
MapBuilder = require(Server.MapBuilder)
Skins = require(game_services("ReplicatedStorage").Shared.Skins)
''')

fails = []
def check(label, code):
    ok, err = lua.execute(f'local ok, err = xpcall(function() {code} end, debug.traceback) return ok, err or ""')
    print(('ok   ' if ok else 'FAIL ') + label)
    if not ok:
        fails.append(label)
        print('     ' + str(err).replace('\n', '\n     ')[:1500])

for fn in ('SetupLighting', 'SetupTerrain', 'BuildLobby'):
    check('MapBuilder.' + fn, f'MapBuilder.{fn}()')
for skin in lua.eval('Skins.Order').values():
    for claw in lua.eval('Skins.ClawOrder').values():
        lua.globals().__char = make_rig(skin)
        check(f'suit {skin} + claws {claw}', f'Costumes.Dress(__char, "{skin}"); local s = Costumes.BuildClaws(__char, Skins.Claws["{claw}"], true); if s then Costumes.PopClaws(s) end')
for sk in lua.eval('Skins.SentinelOrder').values():
    lua.globals().__char = make_rig('S')
    check(f'sentinel {sk}', f'Costumes.DressSentinel(__char, "{sk}")')
    check(f'sentinel statue {sk}', f'Costumes.SentinelStatue(Instance.new("Folder"), CFrame.new(), 1.2, "{sk}")')
check('claw displays', 'for _, id in ipairs(Skins.ClawOrder) do Costumes.ClawDisplay(Instance.new("Folder"), CFrame.new(), Skins.Claws[id]) end')
print(f'\n{len(fails)} failed' if fails else '\nall passed')
sys.exit(1 if fails else 0)
