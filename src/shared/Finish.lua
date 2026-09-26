-- No stock Roblox material textures on the map. Metal, Concrete, Brick,
-- DiamondPlate, Wood and the rest are Roblox's own tiled textures and make
-- a build look like a free model, so every map surface is SmoothPlastic and
-- the detail is modelled instead (bevels, panels, seams, bolts).
-- Glass, Neon and ForceField carry no texture and are left alone.
--
-- Finish(part) swaps a stock material. A part the claws can hit keeps what
-- it stood for as its Surface attribute ("Metal" / "Stone"), which is how
-- Combat.Surface picks the clash effect.
local M = Enum.Material

local KEEP = {
	[M.SmoothPlastic] = true,
	[M.Glass] = true,
	[M.Neon] = true,
	[M.ForceField] = true,
}

local METAL = {
	[M.Metal] = true,
	[M.DiamondPlate] = true,
	[M.CorrodedMetal] = true,
	[M.Foil] = true,
}

local STONE = {
	[M.Concrete] = true,
	[M.Plaster] = true,
	[M.Brick] = true,
	[M.Cobblestone] = true,
	[M.Rock] = true,
	[M.Slate] = true,
	[M.Granite] = true,
	[M.Marble] = true,
	[M.Pavement] = true,
	[M.Limestone] = true,
	[M.Sandstone] = true,
	[M.Basalt] = true,
	[M.Asphalt] = true,
	[M.CeramicTiles] = true,
}

return function(p)
	local m = p.Material
	if KEEP[m] then
		return p
	end
	if p.CanQuery and p:GetAttribute("Surface") == nil then
		if METAL[m] then
			p:SetAttribute("Surface", "Metal")
		elseif STONE[m] then
			p:SetAttribute("Surface", "Stone")
		end
	end
	p.Material = M.SmoothPlastic
	return p
end
