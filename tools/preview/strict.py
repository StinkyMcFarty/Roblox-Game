# Make the preview mock strict like Roblox: unknown classes, properties, enum
# items and wrongly-typed values raise errors.
import json, os, urllib.request
S = os.path.dirname(os.path.abspath(__file__))
DUMP = 'https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json'

def api():
    """Roblox's API dump, cached next to this file (api.json, gitignored)."""
    path = os.path.join(S, 'api.json')
    if not os.path.exists(path):
        urllib.request.urlretrieve(DUMP, path)
    d = json.load(open(path))
    props = {c['Name']: {'super': c['Superclass'], 'props': {
        m['Name']: ('E:' if m['ValueType']['Category'] == 'Enum' else '') + m['ValueType']['Name']
        for m in c['Members'] if m['MemberType'] == 'Property'}} for c in d['Classes']}
    enums = {e['Name']: [i['Name'] for i in e['Items']] for e in d['Enums']}
    return props, enums

def install(lua):
    props, enums = api()
    lua.globals().API = lua.table_from(props, recursive=True)
    lua.globals().ENUMS = lua.table_from({k: {i: True for i in v} for k, v in enums.items()}, recursive=True)
    lua.execute(r'''
local I = getmetatable(Instance.new("Folder"))
local oldNew, oldIndexSet = Instance.new, I.__newindex
local SKIP = { Parent = true, Name = true, __path = true }
local function findProp(class, key)
  local c = class
  while c and API[c] do
    local t = API[c].props[key]
    if t then return t end
    c = API[c].super
  end
  return nil
end
Instance.new = function(class, parent)
  if not API[class] then error("Unable to create an Instance of type \"" .. tostring(class) .. "\"", 2) end
  return oldNew(class, parent)
end
local NUM = { float = true, double = true, int = true, int64 = true }
I.__newindex = function(o, k, v)
  local class = rawget(o, "__props").ClassName
  if not SKIP[k] and API[class] and class ~= "ModuleScript" then
    local t = findProp(class, k)
    if not t then error(tostring(k) .. " is not a valid member of " .. class, 2) end
    if t:sub(1, 2) == "E:" and v ~= nil then
      local et = t:sub(3)
      if type(v) ~= "table" or v.EnumType ~= et then error("Invalid value for enum " .. et .. " on " .. class .. "." .. k, 2) end
    elseif NUM[t] and type(v) ~= "number" then error(class .. "." .. k .. " expects a number, got " .. type(v), 2)
    elseif t == "bool" and type(v) ~= "boolean" then error(class .. "." .. k .. " expects a boolean", 2)
    elseif t == "string" and type(v) ~= "string" then error(class .. "." .. k .. " expects a string, got " .. type(v), 2)
    elseif t == "Color3" and not (type(v) == "table" and v.__c3) then error(class .. "." .. k .. " expects a Color3", 2)
    elseif t == "Vector3" and not (type(v) == "table" and v.__v3) then error(class .. "." .. k .. " expects a Vector3", 2)
    elseif t == "CFrame" and not (type(v) == "table" and v.__cf) then error(class .. "." .. k .. " expects a CFrame", 2)
    end
  end
  return oldIndexSet(o, k, v)
end
local EM = getmetatable(Enum)
local oldEnumIndex = EM.__index
EM.__index = function(t, typeName)
  if not ENUMS[typeName] then error(tostring(typeName) .. " is not a valid Enum", 2) end
  local et = oldEnumIndex(t, typeName)
  local m = getmetatable(et)
  local inner = m.__index
  m.__index = function(t2, item)
    if not ENUMS[typeName][item] then error(tostring(item) .. " is not a valid EnumItem of " .. typeName, 2) end
    return inner(t2, item)
  end
  return et
end
-- ColorSequence / NumberSequence rules
ColorSequence.new = function(a, b)
  if type(a) == "table" and not a.__c3 and b == nil then
    if #a < 2 or #a > 20 then error("ColorSequence: between 2 and 20 keypoints, got " .. #a, 2) end
    if a[1].Time ~= 0 or a[#a].Time ~= 1 then error("ColorSequence: must start at 0 and end at 1", 2) end
    for i = 2, #a do if a[i].Time <= a[i - 1].Time then error("ColorSequence: keypoint times must increase", 2) end end
  end
  return {a, b}
end
''')
