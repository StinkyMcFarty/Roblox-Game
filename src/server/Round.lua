-- Shared round state used by every server module.
local Round = {
	Active = false,
	Released = false, -- Wolverine has left the tank room
	Wolverine = nil, -- Player
	Survivors = {}, -- [Player] = true while alive in the round (Sentinel counts)
	Map = nil,
	EndTime = 0,
	WolverineDead = false,
	WolverineLeft = false,
}

local killed = Instance.new("BindableEvent")
Round.Killed = killed.Event

function Round.FireKilled(victim, killer)
	killed:Fire(victim, killer)
end

return Round
