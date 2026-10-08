--[[
	CurrencyService (Script, ServerScriptService)

	Server-side orb total, saved with DataStoreService.
	  - The client reports each collected orb by kind name through a
	    RemoteEvent; the server looks up its value in Config.Orbs.Kinds.
	  - Collects are rate-limited (Config.Orbs.MaxCollectsPerSecond).
	  - The total is shown to the client as player:GetAttribute("OrbTotal").
	  - Saves on leave, every Config.Orbs.SaveInterval seconds, and on shutdown.

	If DataStores aren't available (place not published, or Studio API
	access turned off) it warns once and keeps a session-only total.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("RaceTheSun"):WaitForChild("FlightConfig"))
local Settings = Config.Orbs
local KEY_PREFIX = "player_"

local remote = Instance.new("RemoteEvent")
remote.Name = Settings.RemoteName
remote.Parent = ReplicatedStorage

local warned = false
local function warnOnce(message: any)
	if not warned then
		warned = true
		warn("[CurrencyService] Orb totals will not be saved this session: " .. tostring(message))
	end
end

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Settings.DataStoreName)
	end)
	if ok then
		store = result
	else
		warnOnce(result)
	end
end

local totals: { [Player]: number } = {}
local loaded: { [Player]: boolean } = {} -- true once the saved total was read successfully
local dirty: { [Player]: boolean } = {}
local buckets: { [Player]: { Tokens: number, Last: number } } = {}

local function publish(player: Player)
	player:SetAttribute("OrbTotal", totals[player])
end

local function load(player: Player)
	totals[player] = 0
	if store then
		local ok, saved = pcall(store.GetAsync, store, KEY_PREFIX .. player.UserId)
		if totals[player] == nil then
			return -- left while loading
		end
		if ok then
			-- Add rather than replace, in case orbs were collected while loading.
			totals[player] += if typeof(saved) == "number" then saved else 0
			loaded[player] = true
		else
			warnOnce(saved)
		end
	end
	publish(player)
end

local function save(player: Player)
	-- Never save if the load failed, so a bad load can't overwrite real data with 0.
	if not (store and loaded[player] and dirty[player]) then
		return
	end
	dirty[player] = nil
	local ok, err = pcall(store.SetAsync, store, KEY_PREFIX .. player.UserId, totals[player])
	if not ok then
		dirty[player] = true
		warn("[CurrencyService] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

-- Token bucket: refills at MaxCollectsPerSecond, holds at most that many.
local function allowCollect(player: Player): boolean
	local max = Settings.MaxCollectsPerSecond
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = max, Last = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(max, bucket.Tokens + (now - bucket.Last) * max)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

remote.OnServerEvent:Connect(function(player: Player, kind: any)
	if typeof(kind) ~= "string" then
		return
	end
	local info = Settings.Kinds[kind]
	if not info or totals[player] == nil or not allowCollect(player) then
		return
	end
	totals[player] += info.Value
	dirty[player] = true
	publish(player)
end)

Players.PlayerAdded:Connect(load)
for _, player in Players:GetPlayers() do
	task.spawn(load, player)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	totals[player] = nil
	loaded[player] = nil
	dirty[player] = nil
	buckets[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(Settings.SaveInterval)
		for _, player in Players:GetPlayers() do
			task.spawn(save, player)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			save(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait()
	end
end)
