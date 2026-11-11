local revision = "__REVISION__"
local manifest = __MANIFEST__
local environment = type(getgenv) == "function" and getgenv() or _G
assert(type(loadstring) == "function", "Explorer: this environment needs loadstring support")
assert(not environment.ExplorerPlusLoading, "Explorer is already loading; wait for it to finish")
environment.ExplorerPlusLoading = true

local ok, result = xpcall(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	local base = "https://raw.githubusercontent.com/pldsp/explorer/" .. revision .. "/dist/modules/"
	local sources, failures = {}, {}
	local function checksum(text)
		local a, b = 1, 0
		for index = 1, #text do
			a = (a + string.byte(text, index)) % 65521
			b = (b + a) % 65521
		end
		return b * 65536 + a
	end
	local cursor, finished = 0, 0
	for _ = 1, math.min(4, #manifest) do
		task.spawn(function()
			while true do
				cursor += 1
				local entry = manifest[cursor]
				if not entry then return end
				local name, size, expected = entry[1], entry[2], entry[3]
				local reason
				for attempt = 1, 3 do
					local fetched, body = pcall(function()
						return game:HttpGet(base .. name .. ".luau", true)
					end)
					if fetched and type(body) == "string" and #body == size and checksum(body) == expected then
						sources[name] = body
						break
					end
					reason = fetched and "download did not match the release manifest" or tostring(body)
					if attempt < 3 then task.wait(0.4 * attempt) end
				end
				if not sources[name] then failures[name] = reason end
				finished += 1
			end
		end)
	end
	local started = os.clock()
	while finished < #manifest do
		assert(os.clock() - started < 45, "Explorer: module downloads timed out; try again")
		task.wait(0.05)
	end
	for name, reason in failures do error("Explorer: unable to load " .. name .. ": " .. reason, 0) end
	local factories = {}
	for name, source in sources do
		local chunk, reason = loadstring(source, "@Explorer/" .. name)
		assert(chunk, "Explorer: " .. name .. " compile failed: " .. tostring(reason))
		local factory = chunk()
		assert(type(factory) == "function", "Explorer: invalid module " .. name)
		factories[name] = factory
	end
	local cache, loading = {}, {}
	local function Import(name)
		if cache[name] ~= nil then return cache[name] end
		assert(not loading[name], "Explorer: circular dependency " .. name)
		assert(factories[name], "Explorer: unknown module " .. tostring(name))
		loading[name] = true
		local value = factories[name](Import)
		assert(value ~= nil, "Explorer: module returned nil: " .. name)
		cache[name], loading[name] = value, nil
		return value
	end
	local player = game:GetService("Players").LocalPlayer
	assert(player, "Explorer: run this on the client")
	local parent
	if type(gethui) == "function" then
		local success, container = pcall(gethui)
		if success and typeof(container) == "Instance" then parent = container end
	end
	if not parent then
		local success, container = pcall(function()
			local core = game:GetService("CoreGui")
			local probe = Instance.new("Folder")
			probe.Parent = core
			probe:Destroy()
			return core
		end)
		if success then parent = container end
	end
	parent = parent or player:WaitForChild("PlayerGui", 10)
	assert(parent, "Explorer: no GUI container available")
	local App = Import("App")
	local previous = environment.ExplorerPlus
	if type(previous) == "table" and type(previous.Destroy) == "function" then previous:Destroy() end
	local app = App.new(parent)
	environment.ExplorerPlus = app
	return app
end, debug.traceback)
environment.ExplorerPlusLoading = nil
if not ok then error(result, 0) end
return result
