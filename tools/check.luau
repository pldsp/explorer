local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local files = fs.readDir("src")
table.sort(files)
local count = 0
for _, name in files do
	if string.match(name, "%.luau$") then
		luau.compile(fs.readFile("src/" .. name))
		count += 1
	end
end
local codec = luau.load(fs.readFile("src/ValueCodec.luau"), {
	environment = {
		Vector2 = roblox.Vector2, Vector3 = roblox.Vector3,
		Color3 = roblox.Color3, UDim = roblox.UDim, UDim2 = roblox.UDim2,
	},
})()
assert(codec.parse("false", true) == false)
assert(codec.parse(" 2.5 ", 0) == 2.5)
assert(codec.parse("new name", "old") == "new name")
assert(codec.parse("1, 2, 3", roblox.Vector3.zero) == roblox.Vector3.new(1, 2, 3))
assert(codec.parse("0.5, 3, 1, -4", roblox.UDim2.new()) == roblox.UDim2.new(0.5, 3, 1, -4))
assert(codec.parse("0, 0.5, 1", roblox.Color3.new()) == roblox.Color3.new(0, 0.5, 1))
for _, text in { "nan", "inf", "1,2", "" } do
	assert(not pcall(codec.parse, text, 0), "Accepted invalid number: " .. text)
end
assert(not pcall(codec.parse, "yes", true))
assert(not pcall(codec.parse, "2, 0, 0", roblox.Color3.new()))
print(string.format("Compiled %d Luau files; codec checks passed.", count))
if fs.isDir("dist/modules") then
	local modules = fs.readDir("dist/modules")
	for _, name in modules do luau.compile(fs.readFile("dist/modules/" .. name)) end
	local releasedCodec = luau.load(fs.readFile("dist/modules/ValueCodec.luau"), {
		environment = { Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, Color3 = roblox.Color3, UDim = roblox.UDim, UDim2 = roblox.UDim2 },
	})()(function() error("Unexpected dependency") end)
	assert(releasedCodec.parse("1, 2, 3", roblox.Vector3.zero) == codec.parse("1, 2, 3", roblox.Vector3.zero))
	assert(releasedCodec.parse("false", true) == false)
	assert(not pcall(releasedCodec.parse, "1,2", 0))
	if fs.isFile("loader.luau") then luau.compile(fs.readFile("loader.luau")) end
	print("All minified modules compiled; minified codec behavior passed.")
end
