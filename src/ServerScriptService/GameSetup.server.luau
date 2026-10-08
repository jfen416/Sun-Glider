--[[
	GameSetup (Script, ServerScriptService)

	The player is the glider, so no Roblox avatar is spawned. Everything
	else runs on the client in FlightClient.
]]

local Players = game:GetService("Players")

Players.CharacterAutoLoads = false

-- In case anyone spawned before this script ran.
for _, player in Players:GetPlayers() do
	if player.Character then
		player.Character:Destroy()
	end
end
