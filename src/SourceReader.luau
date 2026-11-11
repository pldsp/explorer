local Config = require(script.Parent.Config)
local Reader = {}
Reader.__index = Reader

function Reader.new()
	return setmetatable({ cache = setmetatable({}, { __mode = "k" }), serial = 0, dead = false }, Reader)
end

function Reader:Cancel()
	self.serial += 1
end

function Reader:Read(item, callback, refresh)
	self:Cancel()
	local serial = self.serial
	local finished = false
	local function finish(source, message)
		if finished or self.dead or serial ~= self.serial then return end
		finished = true
		callback(source, message)
	end
	if not item or not item:IsA("LuaSourceContainer") then finish(nil, "Select a LocalScript, ModuleScript, or client script"); return end
	if self.cache[item] and not refresh then
		finish(self.cache[item], "Cached source")
		return
	end
	task.delay(Config.DecompilerTimeout, function()
		finish(nil, "The executor's decompiler timed out. Retry when it is available.")
	end)
	task.spawn(function()
		local readable, source = pcall(function() return item.Source end)
		local method = "Source"
		if not readable or type(source) ~= "string" or source == "" then
			local environment = type(getgenv) == "function" and getgenv() or _G
			local decompiler = decompile or environment.decompile
			if type(decompiler) ~= "function" then
				finish(nil, "This executor has no decompile function and the script's Source is unreadable.")
				return
			end
			readable, source = pcall(decompiler, item)
			method = "Executor decompiler"
		end
		if not readable then
			finish(nil, "Unable to read this script: " .. tostring(source) .. ". Server-only source may be unavailable to the client.")
			return
		end
		if type(source) ~= "string" or source == "" then finish(nil, "The decompiler returned no source for this script"); return end
		if not finished and not self.dead and serial == self.serial then self.cache[item] = source end
		finish(source, method)
	end)
end

function Reader:Destroy()
	self.dead = true
	self:Cancel()
	table.clear(self.cache)
end

return Reader
