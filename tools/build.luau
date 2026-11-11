local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local root = roblox.Instance.new("LocalScript")
root.Name = "ExplorerPlus"
root.Source = fs.readFile("src/init.client.luau")
luau.compile(root.Source)
for _, name in fs.readDir("src") do
	if not string.match(name, "%.luau$") or name == "init.client.luau" then continue end
	local source = fs.readFile("src/" .. name)
	luau.compile(source)
	local module = roblox.Instance.new("ModuleScript")
	module.Name = string.gsub(name, "%.luau$", "")
	module.Source = source
	module.Parent = root
end
if not fs.isDir("dist") then fs.writeDir("dist") end
local path = "dist/ExplorerPlus.rbxm"
fs.writeFile(path, roblox.serializeModel({ root }))
local restored = roblox.deserializeModel(fs.readFile(path))[1]
assert(restored.ClassName == "LocalScript" and #restored:GetChildren() == 12)
assert(restored.Source == root.Source)
for _, module in root:GetChildren() do
	assert(restored:FindFirstChild(module.Name).Source == module.Source)
end
print("Built and round-trip verified " .. path .. " (loader + 12 ModuleScripts)")
