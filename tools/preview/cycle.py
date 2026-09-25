"""Filmstrip of the Sentinel's walk/run cycle, straight from src/client/Anims.lua
(the SENTINEL LOCOMOTION block) on the dressed suit.
  python3 tools/preview/cycle.py stomp 8 [skin]    -> scene.json with scenes cycle:stomp:0..7
then render them side by side (see CLAUDE.md), e.g.
  node tools/preview/shot.cjs strip.png "compose=1&nofloor=1&scenes=...&place=..." 1920 600
"""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run
from run import lua, make_rig, dump

REPO = run.REPO
src = open(os.path.join(REPO, 'src/client/Anims.lua')).read()
block = src[src.index('-- SENTINEL LOCOMOTION'):src.index('-- END SENTINEL LOCOMOTION')]
lua.execute('rad = math.rad; TAU = 2 * math.pi')
lua.globals().__loco = run.convert(block) + '\nreturn { stomp = stompPose, charge = chargePose, warp = sentinelWarp }'
lua.execute('LOCO = load(__loco, "@loco")()')
lua.execute('''
local J = {
  { "Root", "LowerTorso", nil, Vector3.new(0, 3.0, 0) },
  { "Waist", "UpperTorso", "Root", Vector3.new(0, 3.11, 0) },
  { "Neck", "Head", "Waist", Vector3.new(0, 4.71, 0) },
}
for _, s in ipairs({ { "R", "Right", 1 }, { "L", "Left", -1 } }) do
  local a, n, x = s[1], s[2], s[3]
  table.insert(J, { a .. "Shoulder", n .. "UpperArm", "Waist", Vector3.new(1.5 * x, 4.55, 0) })
  table.insert(J, { a .. "Elbow", n .. "LowerArm", a .. "Shoulder", Vector3.new(1.5 * x, 3.54, 0) })
  table.insert(J, { a .. "Wrist", n .. "Hand", a .. "Elbow", Vector3.new(1.5 * x, 2.49, 0) })
  table.insert(J, { a .. "Hip", n .. "UpperLeg", "Root", Vector3.new(0.5 * x, 2.71, 0) })
  table.insert(J, { a .. "Knee", n .. "LowerLeg", a .. "Hip", Vector3.new(0.5 * x, 1.49, 0) })
  table.insert(J, { a .. "Ankle", n .. "Foot", a .. "Knee", Vector3.new(0.5 * x, 0.3, 0) })
end
function animate(char, pose)
  local T = {}
  for _, j in ipairs(J) do
    local cf = pose[j[1]] or CFrame.new()
    local l = CFrame.new(j[4]) * cf * CFrame.new(-j[4])
    T[j[1]] = j[3] and (T[j[3]] * l) or l
    local part = char:FindFirstChild(j[2])
    if part then part.CFrame = T[j[1]] * part.CFrame end
  end
  local hrp = char:FindFirstChild("HumanoidRootPart")
  if hrp then hrp.CFrame = T.Root * hrp.CFrame end
end
''')
lua.execute('Costumes = load(py_src("src/server/Costumes.lua"), "@Costumes")()')

kind = sys.argv[1] if len(sys.argv) > 1 else 'stomp'
n = int(sys.argv[2]) if len(sys.argv) > 2 else 8
skin = sys.argv[3] if len(sys.argv) > 3 else 'Default'
scenes = {}
for i in range(n):
    ch = make_rig('S')
    lua.globals().__c = ch
    t = 2 * 3.141592653589793 * i / n  # evenly spaced in time: the warp shows as lingering
    lua.execute(f'animate(__c, LOCO.{kind}(LOCO.warp({t}), 1))' + ('' if skin == 'none' else f'; Costumes.DressSentinel(__c, "{skin}")'))
    scenes[f'cycle:{kind}:{i}'] = {'parts': dump(ch)}
json.dump(scenes, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scene.json'), 'w'))
print(list(scenes))
