-- Minimal Roblox API mock for previewing costume code
local sqrt, sin, cos, abs = math.sqrt, math.sin, math.cos, math.abs

function __iter(t)
  if type(t) == "function" then return t end
  local keys, n = {}, #t
  for i = 1, n do keys[#keys+1] = i end
  for k in pairs(t) do
    if not (math.type(k) == "integer" and k >= 1 and k <= n) then keys[#keys+1] = k end
  end
  local i = 0
  return function() i = i + 1; local k = keys[i]; if k ~= nil then return k, t[k] end end
end

table.clone = table.clone or function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end
table.find = table.find or function(t, v) for i, x in ipairs(t) do if x == v then return i end end end
table.freeze = table.freeze or function(t) return t end
math.clamp = math.clamp or function(x, a, b) return math.max(a, math.min(b, x)) end
math.round = math.round or function(x) return math.floor(x + 0.5) end
math.sign = math.sign or function(x) return x > 0 and 1 or x < 0 and -1 or 0 end
math.noise = math.noise or function() return 0 end
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
math.pow = math.pow or function(a, b) return a ^ b end
unpack = unpack or table.unpack
loadstring = loadstring or load
string.split = string.split or function(s, sep)
  local out, i = {}, 1
  sep = sep or ","
  while true do
    local a, b = string.find(s, sep, i, true)
    if not a then out[#out + 1] = s:sub(i) break end
    out[#out + 1] = s:sub(i, a - 1); i = b + 1
  end
  return out
end

-- Vector3 ------------------------------------------------------------
Vector3 = {}
local V = {}
local function v3(x, y, z) return setmetatable({X = x or 0, Y = y or 0, Z = z or 0, __v3 = true}, V) end
Vector3.new = v3
V.__add = function(a, b) return v3(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
V.__sub = function(a, b) return v3(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
V.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b)
  if type(a) == "number" then return v3(a*b.X, a*b.Y, a*b.Z) end
  if type(b) == "number" then return v3(a.X*b, a.Y*b, a.Z*b) end
  return v3(a.X*b.X, a.Y*b.Y, a.Z*b.Z)
end
V.__div = function(a, b)
  if type(b) == "number" then return v3(a.X/b, a.Y/b, a.Z/b) end
  return v3(a.X/b.X, a.Y/b.Y, a.Z/b.Z)
end
V.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
local Vm = {}
function Vm.Dot(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end
function Vm.Cross(a, b) return v3(a.Y*b.Z - a.Z*b.Y, a.Z*b.X - a.X*b.Z, a.X*b.Y - a.Y*b.X) end
function Vm.Lerp(a, b, t) return a + (b - a) * t end
function Vm.Abs(a) return v3(abs(a.X), abs(a.Y), abs(a.Z)) end
function Vm.Max(a, b) return v3(math.max(a.X,b.X), math.max(a.Y,b.Y), math.max(a.Z,b.Z)) end
function Vm.Min(a, b) return v3(math.min(a.X,b.X), math.min(a.Y,b.Y), math.min(a.Z,b.Z)) end
V.__index = function(a, k)
  if k == "Magnitude" then return sqrt(a.X*a.X + a.Y*a.Y + a.Z*a.Z) end
  if k == "Unit" then local m = sqrt(a.X*a.X + a.Y*a.Y + a.Z*a.Z); if m == 0 then return v3(0,0,0) end return v3(a.X/m, a.Y/m, a.Z/m) end
  return Vm[k]
end
Vector3.zero = v3(0,0,0); Vector3.one = v3(1,1,1)
Vector3.xAxis = v3(1,0,0); Vector3.yAxis = v3(0,1,0); Vector3.zAxis = v3(0,0,1)

local V2 = {}
V2.__index = function(t, k) if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y) elseif k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y); return Vector2.new(t.X / m, t.Y / m) end end
V2.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
V2.__unm = function(a) return Vector2.new(-a.X, -a.Y) end
V2.__mul = function(a, b)
  if type(a) == "number" then return Vector2.new(a * b.X, a * b.Y) end
  if type(b) == "number" then return Vector2.new(a.X * b, a.Y * b) end
  return Vector2.new(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
  if type(b) == "number" then return Vector2.new(a.X / b, a.Y / b) end
  return Vector2.new(a.X / b.X, a.Y / b.Y)
end
Vector2 = { new = function(x, y) return setmetatable({X = x or 0, Y = y or 0}, V2) end }
Vector2.zero = Vector2.new(0, 0); Vector2.one = Vector2.new(1, 1)

-- CFrame -------------------------------------------------------------
CFrame = {}
local C = {}
local function cf(px, py, pz, r) -- r = {r00,r01,r02,r10,r11,r12,r20,r21,r22}
  return setmetatable({p = v3(px, py, pz), r = r or {1,0,0, 0,1,0, 0,0,1}, __cf = true}, C)
end
local function mulR(a, b)
  local r = {}
  for i = 0, 2 do for j = 0, 2 do
    local s = 0
    for k = 0, 2 do s = s + a[i*3+k+1] * b[k*3+j+1] end
    r[i*3+j+1] = s
  end end
  return r
end
local function rotV(r, v)
  return v3(r[1]*v.X + r[2]*v.Y + r[3]*v.Z, r[4]*v.X + r[5]*v.Y + r[6]*v.Z, r[7]*v.X + r[8]*v.Y + r[9]*v.Z)
end
CFrame.new = function(a, b, c, ...)
  local extra = {...}
  if a == nil then return cf(0,0,0) end
  if type(a) == "table" and a.__v3 then
    if b and b.__v3 then return CFrame.lookAt(a, b) end
    return cf(a.X, a.Y, a.Z)
  end
  if #extra == 9 then return cf(a, b, c, extra) end
  return cf(a, b, c)
end
local function rx(t) local c, s = cos(t), sin(t) return {1,0,0, 0,c,-s, 0,s,c} end
local function ry(t) local c, s = cos(t), sin(t) return {c,0,s, 0,1,0, -s,0,c} end
local function rz(t) local c, s = cos(t), sin(t) return {c,-s,0, s,c,0, 0,0,1} end
CFrame.Angles = function(x, y, z) return cf(0,0,0, mulR(mulR(rx(x or 0), ry(y or 0)), rz(z or 0))) end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
CFrame.fromEulerAnglesYXZ = function(x, y, z) return cf(0,0,0, mulR(mulR(ry(y or 0), rx(x or 0)), rz(z or 0))) end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
CFrame.fromAxisAngle = function(axis, t)
  local u = axis.Unit; local c, s = cos(t), sin(t); local x, y, z = u.X, u.Y, u.Z; local C1 = 1 - c
  return cf(0,0,0, {c+x*x*C1, x*y*C1-z*s, x*z*C1+y*s, y*x*C1+z*s, c+y*y*C1, y*z*C1-x*s, z*x*C1-y*s, z*y*C1+x*s, c+z*z*C1})
end
CFrame.lookAt = function(at, target, up)
  up = up or v3(0,1,0)
  local look = (target - at).Unit
  local right = look:Cross(up)
  if right.Magnitude < 1e-6 then right = look:Cross(v3(0,0,1)) end
  right = right.Unit
  local up2 = right:Cross(look).Unit
  local b = -look
  return cf(at.X, at.Y, at.Z, {right.X, up2.X, b.X, right.Y, up2.Y, b.Y, right.Z, up2.Z, b.Z})
end
CFrame.fromMatrix = function(pos, vx, vy, vz)
  vz = vz or vx:Cross(vy).Unit
  return cf(pos.X, pos.Y, pos.Z, {vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z})
end
CFrame.identity = cf(0,0,0)
C.__mul = function(a, b)
  if b.__v3 then return rotV(a.r, b) + a.p end
  local p = rotV(a.r, b.p) + a.p
  return cf(p.X, p.Y, p.Z, mulR(a.r, b.r))
end
C.__add = function(a, v) return cf(a.p.X + v.X, a.p.Y + v.Y, a.p.Z + v.Z, a.r) end
C.__sub = function(a, v) return cf(a.p.X - v.X, a.p.Y - v.Y, a.p.Z - v.Z, a.r) end
local Cm = {}
function Cm.Inverse(a)
  local r = a.r
  local t = {r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9]}
  local p = -rotV(t, a.p)
  return cf(p.X, p.Y, p.Z, t)
end
function Cm.ToWorldSpace(a, b) return a * b end
function Cm.ToObjectSpace(a, b) return a:Inverse() * b end
function Cm.PointToWorldSpace(a, v) return a * v end
function Cm.PointToObjectSpace(a, v) return a:Inverse() * v end
function Cm.VectorToWorldSpace(a, v) return rotV(a.r, v) end
function Cm.Lerp(a, b, t)
  local p = a.p:Lerp(b.p, t)
  return cf(p.X, p.Y, p.Z, t < 0.5 and a.r or b.r)
end
function Cm.GetComponents(a) local r = a.r return a.p.X, a.p.Y, a.p.Z, r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9] end
C.__index = function(a, k)
  if k == "Position" then return a.p end
  if k == "X" then return a.p.X elseif k == "Y" then return a.p.Y elseif k == "Z" then return a.p.Z end
  local r = a.r
  if k == "RightVector" then return v3(r[1], r[4], r[7]) end
  if k == "UpVector" then return v3(r[2], r[5], r[8]) end
  if k == "LookVector" then return v3(-r[3], -r[6], -r[9]) end
  if k == "Rotation" then return cf(0,0,0, r) end
  return Cm[k]
end

-- Color3 -------------------------------------------------------------
Color3 = {}
local Col = {}
local function c3(r, g, b) return setmetatable({R = r, G = g, B = b, __c3 = true}, Col) end
Color3.new = function(r, g, b) return c3(r or 0, g or 0, b or 0) end
Color3.fromRGB = function(r, g, b) return c3((r or 0)/255, (g or 0)/255, (b or 0)/255) end
Color3.fromHSV = function(h, s, v)
  local i = math.floor(h * 6); local f = h * 6 - i; local p, q, t = v*(1-s), v*(1-f*s), v*(1-(1-f)*s)
  i = i % 6
  if i == 0 then return c3(v,t,p) elseif i == 1 then return c3(q,v,p) elseif i == 2 then return c3(p,v,t)
  elseif i == 3 then return c3(p,q,v) elseif i == 4 then return c3(t,p,v) else return c3(v,p,q) end
end
Col.__index = {
  Lerp = function(a, b, t) return c3(a.R + (b.R-a.R)*t, a.G + (b.G-a.G)*t, a.B + (b.B-a.B)*t) end,
  ToHSV = function(a)
    local r, g, b = a.R, a.G, a.B
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d, h = mx - mn, 0
    if d > 0 then
      if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
      h = h / 6
    end
    return h, mx == 0 and 0 or d / mx, mx
  end,
}
Col.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end

-- misc value types
UDim = { new = function(s, o) return {Scale = s or 0, Offset = o or 0} end }
UDim2 = {
  new = function(xs, xo, ys, yo) return {X = UDim.new(xs, xo), Y = UDim.new(ys, yo)} end,
  fromScale = function(x, y) return {X = UDim.new(x, 0), Y = UDim.new(y, 0)} end,
  fromOffset = function(x, y) return {X = UDim.new(0, x), Y = UDim.new(0, y)} end,
}
NumberRange = { new = function(a, b) return {Min = a, Max = b or a} end }
NumberSequenceKeypoint = { new = function(t, v, e) return {Time = t, Value = v} end }
NumberSequence = { new = function(a, b) return {a, b} end }
ColorSequenceKeypoint = { new = function(t, c) return {Time = t, Value = c} end }
ColorSequence = { new = function(a, b) return {a, b} end }
TweenInfo = { new = function(...) return {...} end }
Font = { new = function(f, w, s) return {Family = f, Weight = w} end }
PhysicalProperties = { new = function(...) return {...} end }
Random = { new = function(seed)
  local s = seed or 1
  local r = {}
  function r:NextNumber(a, b) s = (s * 1103515245 + 12345) % 2147483648; local u = s / 2147483648; if a then return a + (b - a) * u end return u end
  function r:NextInteger(a, b) return math.floor(self:NextNumber(a, b + 1)) end
  return r
end }

-- Enum ---------------------------------------------------------------
local enumItemMT = { __tostring = function(e) return e.Name end }
Enum = setmetatable({}, { __index = function(t, typeName)
  local et = setmetatable({}, { __index = function(t2, item)
    local e = setmetatable({Name = item, EnumType = typeName}, enumItemMT)
    rawset(t2, item, e)
    return e
  end })
  rawset(t, typeName, et)
  return et
end })

-- Instances ----------------------------------------------------------
local signal = { Connect = function() return { Disconnect = function() end } end, Once = function() return { Disconnect = function() end } end, Wait = function() end }
local classes = {
  Part = "BasePart", WedgePart = "BasePart", MeshPart = "BasePart", CornerWedgePart = "BasePart", TrussPart = "BasePart", UnionOperation = "BasePart",
  Frame = "GuiObject", TextLabel = "GuiObject", ImageLabel = "GuiObject", TextButton = "GuiObject",
  PointLight = "Light", SpotLight = "Light", SurfaceLight = "Light",
  Weld = "JointInstance", Motor6D = "JointInstance", WeldConstraint = "Constraint",
  Decal = "FaceInstance", Texture = "FaceInstance",
  Model = "PVInstance",
}
local I = {}
local allInstances = {}
local function isA(obj, name)
  local c = obj.ClassName
  if c == name or name == "Instance" then return true end
  local base = classes[c]
  while base do
    if base == name then return true end
    base = classes[base]
  end
  if name == "PVInstance" and (classes[c] == "BasePart" or c == "Model") then return true end
  return false
end
local methods = {}
function methods:IsA(n) return isA(self, n) end
function methods:FindFirstChild(name, recursive)
  for _, c in ipairs(rawget(self, "__children")) do if c.Name == name then return c end end
  if recursive then
    for _, c in ipairs(rawget(self, "__children")) do local f = c:FindFirstChild(name, true); if f then return f end end
  end
  return nil
end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:FindFirstChildOfClass(cn) for _, c in ipairs(rawget(self, "__children")) do if c.ClassName == cn then return c end end end
function methods:FindFirstChildWhichIsA(cn, rec)
  for _, c in ipairs(rawget(self, "__children")) do if isA(c, cn) then return c end end
  if rec then for _, c in ipairs(rawget(self, "__children")) do local f = c:FindFirstChildWhichIsA(cn, true); if f then return f end end end
end
function methods:FindFirstAncestor(name) local p = self.Parent while p do if p.Name == name then return p end p = p.Parent end end
function methods:FindFirstAncestorWhichIsA(cn) local p = self.Parent while p do if isA(p, cn) then return p end p = p.Parent end end
function methods:GetChildren() local t = {} for i, c in ipairs(rawget(self, "__children")) do t[i] = c end return t end
function methods:GetDescendants()
  local t = {}
  local function rec(o) for _, c in ipairs(rawget(o, "__children")) do t[#t+1] = c; rec(c) end end
  rec(self)
  return t
end
function methods:IsDescendantOf(a) local p = self.Parent while p do if p == a then return true end p = p.Parent end return false end
function methods:SetAttribute(k, v) rawget(self, "__attr")[k] = v end
function methods:GetAttribute(k) return rawget(self, "__attr")[k] end
function methods:GetAttributes() return rawget(self, "__attr") end
function methods:GetAttributeChangedSignal() return signal end
function methods:GetPropertyChangedSignal() return signal end
function methods:Destroy() self.Parent = nil; rawset(self, "__destroyed", true) end
function methods:ClearAllChildren() for _, c in ipairs(self:GetChildren()) do c:Destroy() end end
function methods:Clone()
  local n = Instance.new(self.ClassName)
  for k, v in pairs(rawget(self, "__props")) do if k ~= "Parent" then rawget(n, "__props")[k] = v end end
  for k, v in pairs(rawget(self, "__attr")) do rawget(n, "__attr")[k] = v end
  for _, c in ipairs(rawget(self, "__children")) do local cc = c:Clone(); cc.Parent = n end
  return n
end
function methods:GetPivot()
  if isA(self, "BasePart") then return self.CFrame end
  local pp = self.PrimaryPart
  if pp then return pp.CFrame end
  for _, d in ipairs(self:GetDescendants()) do if isA(d, "BasePart") then return d.CFrame end end
  return CFrame.new()
end
function methods:PivotTo(target)
  if isA(self, "BasePart") then self.CFrame = target return end
  local cur = self:GetPivot()
  local delta = target * cur:Inverse()
  for _, d in ipairs(self:GetDescendants()) do if isA(d, "BasePart") then d.CFrame = delta * d.CFrame end end
end
function methods:SetPrimaryPartCFrame(c) self:PivotTo(c) end
function methods:GetBoundingBox() return self:GetPivot(), Vector3.new(4,4,4) end
function methods:ScaleTo() end
function methods:AddAccessory() end
function methods:SetNetworkOwner() end
function methods:GetFullName() return self.Name end
function methods:BreakJoints() end
function methods:Play() end
function methods:LoadAnimation() return { Play = function() end, Stop = function() end } end
function methods:GetService(n) return game_services(n) end
local DEFAULTS = {
  BasePart = function(o)
    local p = rawget(o, "__props")
    p.Size = Vector3.new(4, 1, 2); p.CFrame = CFrame.new(); p.Color = Color3.fromRGB(163, 162, 165)
    p.Transparency = 0; p.Reflectance = 0; p.Material = Enum.Material.Plastic; p.Shape = Enum.PartType.Block
    p.Anchored = false; p.CanCollide = true
  end,
}
I.__index = function(o, k)
  local m = methods[k]
  if m then return m end
  local props = rawget(o, "__props")
  local v = props[k]
  if v ~= nil then return v end
  if k == "Position" and props.CFrame and isA(o, "BasePart") then return props.CFrame.Position end
  if k == "Orientation" then return Vector3.new() end
  if k == "Parent" then return nil end
  if k == "ChildAdded" or k == "ChildRemoved" or k == "Changed" or k == "Touched" or k == "AncestryChanged" or k == "Destroying" or k == "Died" then return signal end
  for _, c in ipairs(rawget(o, "__children")) do if c.Name == k then return c end end
  return nil
end
I.__newindex = function(o, k, v)
  local props = rawget(o, "__props")
  if k == "Parent" then
    local old = props.Parent
    if old then
      local ch = rawget(old, "__children")
      for i, c in ipairs(ch) do if c == o then table.remove(ch, i) break end end
    end
    props.Parent = v
    if v then table.insert(rawget(v, "__children"), o) end
    return
  end
  if k == "Position" and isA(o, "BasePart") then props.CFrame = CFrame.new(v) * (props.CFrame or CFrame.new()).Rotation return end
  props[k] = v
end
I.__tostring = function(o) return o.Name end
Instance = {}
Instance.new = function(class, parent)
  local o = setmetatable({__props = {ClassName = class, Name = class}, __children = {}, __attr = {}}, I)
  for c, f in pairs(DEFAULTS) do if isA(o, c) then f(o) end end
  allInstances[#allInstances+1] = o
  if parent then o.Parent = parent end
  return o
end

-- services / game ----------------------------------------------------
local services = {}
function game_services(n)
  if not services[n] then
    local s = Instance.new(n)
    s.Name = n
    if n == "TweenService" then
      rawset(s, "Create", function(_, obj, info, goal) return { Play = function() for k, v in pairs(goal) do obj[k] = v end end, Cancel = function() end, Completed = signal } end)
    end
    services[n] = s
  end
  return services[n]
end
game = Instance.new("DataModel")
workspace = game_services("Workspace")
game.Name = "Game"
task = { wait = function() return 0 end, spawn = function(f, ...) f(...) end, delay = function() end, defer = function(f, ...) end }
wait = task.wait
tick = os.clock
