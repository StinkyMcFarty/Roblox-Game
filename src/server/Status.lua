-- Timed status effects: Stunned, Slowed, Frozen, Busy, Immune, Boost.
local Status = {}
local data = {}

function Status.Apply(player, key, duration)
	local s = data[player]
	if not s then
		s = {}
		data[player] = s
	end
	local untilTime = os.clock() + duration
	if (s[key] or 0) < untilTime then
		s[key] = untilTime
	end
end

function Status.Clear(player, key)
	if data[player] then
		data[player][key] = nil
	end
end

function Status.Has(player, key)
	local s = data[player]
	return s ~= nil and (s[key] or 0) > os.clock()
end

function Status.Reset(player)
	data[player] = nil
end

return Status
