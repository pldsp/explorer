local revision = "__REVISION__"
local manifest = __MANIFEST__
local Errors = __ERRORS__
local createIntro = __INTRO__
local environment = type(getgenv) == "function" and getgenv() or _G
local function fail(code, detail) error(Errors.Format(code, detail), 0) end
if type(loadstring) ~= "function" then fail("E003") end
if environment.ExplorerPlusLoading then
	local message = Errors.Format("E002")
	if environment.ExplorerPlusStartup then environment.ExplorerPlusStartup:Notice(message) end
	warn(message)
	return nil
end
local previous = environment.ExplorerPlus
if type(previous) == "table" and not previous.dead and previous.window and previous.window.gui and previous.window.gui.Parent then
	if type(previous.Reveal) == "function" then previous:Reveal() elseif not previous.window.frame.Visible then previous.window:Toggle() end
	if type(previous.Notify) == "function" then previous:Notify("E001") end
	warn(Errors.Format("E001"))
	return previous
end
environment.ExplorerPlusLoading = true
if environment.ExplorerPlusIntro then environment.ExplorerPlusIntro:Destroy(); environment.ExplorerPlusIntro = nil end
local intro
local ok, result = xpcall(function()
	local player = game:GetService("Players").LocalPlayer
	if not player then fail("E004") end
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
	if not parent then fail("E005") end
	intro = createIntro(parent, function(closed)
		if environment.ExplorerPlusIntro == closed then environment.ExplorerPlusIntro = nil end
	end)
	environment.ExplorerPlusIntro = intro
	environment.ExplorerPlusStartup = intro
	intro:Step(0.03, "Checking executor", "Client and GUI container ready")
	if not game:IsLoaded() then
		intro:Step(0.05, "Waiting for Roblox", "Preparing your client session")
		game.Loaded:Wait()
	end
	intro:Step(0.08, "Connecting to release", "Fetching " .. tostring(#manifest) .. " modules")
	local base = "https://raw.githubusercontent.com/pldsp/explorer/" .. revision .. "/dist/modules/"
	local sources, failures = {}, {}
	local function checksum(text)
		local a, b = 1, 0
		for index = 1, #text do a = (a + string.byte(text, index)) % 65521; b = (b + a) % 65521 end
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
				local reason, code
				for attempt = 1, 3 do
					local fetched, body = pcall(function() return game:HttpGet(base .. name .. ".luau", true) end)
					if fetched and type(body) == "string" and #body == size and checksum(body) == expected then sources[name] = body; break end
					code, reason = fetched and "E102" or "E101", fetched and "Release byte validation failed" or tostring(body)
					if attempt < 3 then task.wait(0.4 * attempt) end
				end
				if not sources[name] then failures[name] = { code, name .. ": " .. tostring(reason) } end
				finished += 1
				intro:Step(0.08 + finished / #manifest * 0.65, "Downloading modules", tostring(finished) .. " / " .. tostring(#manifest) .. "  ·  " .. name)
			end
		end)
	end
	local started = os.clock()
	while finished < #manifest do
		if os.clock() - started >= 45 then fail("E103") end
		task.wait(0.05)
	end
	for _, failure in failures do fail(failure[1], failure[2]) end
	local factories = {}
	for index, entry in manifest do
		local name = entry[1]
		intro:Step(0.73 + index / #manifest * 0.18, "Compiling modules", name)
		local chunk, reason = loadstring(sources[name], "@Explorer/" .. name)
		if not chunk then fail("E104", name .. ": " .. tostring(reason)) end
		local success, factory = pcall(chunk)
		if not success or type(factory) ~= "function" then fail("E105", name .. ": " .. tostring(factory)) end
		factories[name] = factory
	end
	local cache, loading = {}, {}
	local function Import(name)
		if cache[name] ~= nil then return cache[name] end
		if loading[name] then fail("E106", name) end
		if not factories[name] then fail("E107", tostring(name)) end
		loading[name] = true
		local value = factories[name](Import)
		if value == nil then fail("E108", name) end
		cache[name], loading[name] = value, nil
		return value
	end
	intro:Step(0.94, "Building the interface", "Preparing Explorer, Properties, and Notepad")
	local app = Import("App").new(parent)
	environment.ExplorerPlus = app
	intro:Finish()
	return app
end, debug.traceback)
environment.ExplorerPlusLoading, environment.ExplorerPlusStartup = nil, nil
if not ok then
	local code = Errors.Code(result)
	local message = tostring(result)
	if not string.find(message, "[Explorer ", 1, true) then message = Errors.Format(code, message) end
	if intro then intro:Fail(code, Errors.Get(code)[1], message) end
	error(message, 0)
end
return result
