local fs = require("@lune/fs")
local luau = require("@lune/luau")
local globals, jobs, timers = {}, {}, {}
local config = { DecompilerTimeout = 25 }
local factory = luau.load(fs.readFile("dist/modules/SourceReader.luau"), { environment = {
	getgenv = function() return globals end,
	task = {
		spawn = function(callback) table.insert(jobs, callback) end,
		delay = function(_, callback) table.insert(timers, callback) end,
	},
} })()
local Reader = factory(function(name) assert(name == "Config"); return config end)
local reader = Reader.new()
local function scriptItem(source)
	return setmetatable({ source = source, IsA = function(_, class) return class == "LuaSourceContainer" end }, {
		__index = function(self, key)
			if key == "Source" then if self.source == false then error("Source is protected") end; return self.source end
		end,
	})
end
local function work()
	local batch = jobs
	jobs = {}
	for _, callback in batch do callback() end
end
local result, message, callbacks = nil, nil, 0
local function callback(source, reason) result, message, callbacks = source, reason, callbacks + 1 end
local direct = scriptItem("return 1")
reader:Read(direct, callback)
work()
assert(result == "return 1" and message == "Source", "Direct source failed")
direct.source = "return 2"
reader:Read(direct, callback)
assert(result == "return 1" and message == "Cached source", "Source cache failed")
reader:Read(direct, callback, true)
work()
assert(result == "return 2", "Reload did not refresh source")
local protected = scriptItem(false)
reader:Read(protected, callback)
work()
assert(result == nil and string.find(message, "no decompile", 1, true), "Unsupported decompiler error missing")
local calls = 0
globals.decompile = function(item) assert(item == protected); calls += 1; return "return 'decompiled'" end
reader:Read(protected, callback)
work()
assert(calls == 1 and result == "return 'decompiled'" and message == "Executor decompiler", "Native executor decompiler failed")
globals.decompile = function() error("Decompiler unavailable") end
reader:Read(protected, callback, true)
work()
assert(result == nil and string.find(message, "Decompiler unavailable", 1, true), "Decompiler exceptions were not handled")
globals.decompile = function() return nil end
reader:Read(protected, callback, true)
work()
assert(result == nil and string.find(message, "no source", 1, true), "Empty decompile result accepted")
reader:Read(direct, callback, true)
local before = callbacks
reader:Cancel()
work()
assert(callbacks == before, "Cancelled reader updated the viewer")
reader:Read(direct, callback, true)
for _, timeout in timers do timeout() end
assert(result == nil and string.find(message, "timed out", 1, true), "Timeout failed")
before = callbacks
work()
assert(callbacks == before, "Late decompiler result replaced timeout")
reader:Read(direct, callback, true)
reader:Destroy()
before = callbacks
work()
assert(callbacks == before and next(reader.cache) == nil, "Reader cleanup failed")
print("Minified SourceReader: direct source, native decompiler, caching/reload, missing decompiler, errors, empty results, cancellation, timeout, late results and unload passed.")
