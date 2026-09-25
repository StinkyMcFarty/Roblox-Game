local Player = game.Players.LocalPlayer

Player.CharacterAdded:Connect(function(Character)
	local Highlight = Instance.new("Highlight")
	Highlight.Parent = Character
	Highlight.FillTransparency = 0.8
	Highlight.FillColor = Color3.fromRGB(0, 0, 0)
	Highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
	Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	Highlight.Enabled = true
	Highlight.Adornee = Character
end)
