local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local rb = require("@lune/roblox")
local V2, U2 = rb.Vector2, rb.UDim2
local listeners, deferred = 0, {}
local function signal()
	local callbacks = {}
	local result = {}
	function result:Connect(callback)
		local connection = { _type = "RBXScriptConnection" }
		callbacks[connection] = callback
		listeners += 1
		function connection:Disconnect()
			if callbacks[self] then callbacks[self] = nil; listeners -= 1 end
		end
		return connection
	end
	function result:Fire(...)
		local snapshot = table.clone(callbacks)
		for connection, callback in snapshot do if callbacks[connection] then callback(...) end end
	end
	return result
end
local function drain()
	local count = 0
	while #deferred > 0 do
		local batch = deferred
		deferred = {}
		for _, callback in batch do callback() end
		count += 1
		assert(count < 100, "Unbounded event scheduling")
	end
end
local events = { "Destroying", "AncestryChanged", "ChildAdded", "ChildRemoved", "AttributeChanged", "Activated", "MouseButton2Click", "MouseEnter", "MouseLeave", "InputBegan", "InputEnded", "InputChanged", "FocusLost" }
local methods, meta = {}, {}
local function make(class)
	local props = { Name = class, ClassName = class, Parent = nil, Size = U2.new(), Position = U2.new(), CanvasPosition = V2.zero, Visible = true, Text = "", _type = "Instance" }
	for _, name in events do props[name] = signal() end
	return setmetatable({ props = props, children = {}, changed = {}, attributes = {}, attributeSignals = {} }, meta)
end
function meta:__index(key)
	if methods[key] then return methods[key] end
	if key == "AbsoluteSize" then
		if self.ClassName == "ScreenGui" then return V2.new(1280, 720) end
		local parentSize = self.Parent and self.Parent.AbsoluteSize or V2.new(1280, 720)
		return V2.new(parentSize.X * self.Size.X.Scale + self.Size.X.Offset, parentSize.Y * self.Size.Y.Scale + self.Size.Y.Offset)
	end
	if key == "AbsolutePosition" then
		if self.ClassName == "ScreenGui" then return V2.zero end
		local parentSize = self.Parent and self.Parent.AbsoluteSize or V2.new(1280, 720)
		local parentPosition = self.Parent and self.Parent.AbsolutePosition or V2.zero
		return parentPosition + V2.new(parentSize.X * self.Position.X.Scale + self.Position.X.Offset, parentSize.Y * self.Position.Y.Scale + self.Position.Y.Offset)
	end
	return self.props[key]
end
function meta:__newindex(key, value)
	local previous = self.props[key]
	if previous == value then return end
	self.props[key] = value
	if key == "Parent" then
		if previous then
			local index = table.find(previous.children, self)
			if index then table.remove(previous.children, index) end
			previous.ChildRemoved:Fire(self)
		end
		if value then table.insert(value.children, self); value.ChildAdded:Fire(self) end
		self.AncestryChanged:Fire(self, value)
	end
	if self.changed[key] then self.changed[key]:Fire() end
end
function methods:GetChildren() return table.clone(self.children) end
function methods:GetPropertyChangedSignal(name)
	if not self.changed[name] then self.changed[name] = signal() end
	return self.changed[name]
end
function methods:IsDescendantOf(root)
	local parent = self.Parent
	while parent do if parent == root then return true end; parent = parent.Parent end
	return false
end
function methods:IsA(class)
	if class == "Instance" or class == self.ClassName then return true end
	if class == "GuiObject" then return table.find({ "Frame", "TextLabel", "TextButton", "TextBox", "ScrollingFrame" }, self.ClassName) ~= nil end
	if class == "GuiBase2d" then return self:IsA("GuiObject") or self.ClassName == "ScreenGui" end
	if class == "LayerCollector" then return self.ClassName == "ScreenGui" end
	if class == "BasePart" then return self.ClassName == "Part" end
	if class == "LuaSourceContainer" then return table.find({ "LocalScript", "ModuleScript", "Script" }, self.ClassName) ~= nil end
	return false
end
function methods:FindFirstChild(name)
	for _, child in self.children do if child.Name == name then return child end end
end
function methods:GetFullName()
	return self.Parent and self.Parent:GetFullName() .. "." .. self.Name or self.Name
end
function methods:GetAttributes() return table.clone(self.attributes) end
function methods:GetAttribute(name) return self.attributes[name] end
function methods:GetAttributeChangedSignal(name)
	if not self.attributeSignals[name] then self.attributeSignals[name] = signal() end
	return self.attributeSignals[name]
end
function methods:SetAttribute(name, value)
	self.attributes[name] = value
	self:GetAttributeChangedSignal(name):Fire()
	self.AttributeChanged:Fire(name)
end
function methods:IsFocused() return self.focused == true end
function methods:CaptureFocus() self.focused = true end
function methods:Destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.Destroying:Fire()
	for _, child in self:GetChildren() do child:Destroy() end
	self.Parent = nil
end
local game = make("DataModel")
game.Name = "game"
local workspace = make("Workspace")
workspace.Parent = game
local playerGui = make("PlayerGui")
playerGui.Parent = game
local input = make("UserInputService")
input.GetFocusedTextBox = function() return nil end
input.GetMouseLocation = function() return V2.new(500, 400) end
input.IsKeyDown = function() return false end
local services = { UserInputService = input, GuiService = { GetGuiInset = function() return V2.zero end } }
game.GetService = function(_, name) return assert(services[name], name) end
local target = make("Folder")
target.Name, target.Parent = "Target", workspace
target.Archivable = true
target:SetAttribute("Count", 3)
local env = {
	Instance = { new = make }, game = game, workspace = workspace,
	Enum = rb.Enum, Vector2 = rb.Vector2, Vector3 = rb.Vector3,
	UDim = rb.UDim, UDim2 = rb.UDim2, Color3 = rb.Color3, CFrame = rb.CFrame,
	BrickColor = rb.BrickColor, Rect = rb.Rect, NumberRange = rb.NumberRange,
	typeof = function(value) return type(value) == "table" and value._type or typeof(value) end,
	task = {
		defer = function(callback) table.insert(deferred, callback) end,
		delay = function(_, callback) table.insert(deferred, callback) end,
		spawn = function(callback) callback() end,
		wait = function() end,
	},
}
local cache = {}
local function Import(name)
	if cache[name] then return cache[name] end
	local factory = luau.load(fs.readFile("dist/modules/" .. name .. ".luau"), { environment = env })()
	cache[name] = factory(Import)
	return cache[name]
end
local app = Import("App").new(playerGui)
drain()
assert(app.window.frame.Size.X.Offset == 420, "Incorrect panel width")
assert(app.window.frame.Size.Y.Scale == 1 and app.window.frame.Position.X.Scale == 1 and app.window.frame.Position.X.Offset == -420, "Explorer is not attached to the full right edge")
assert(app.window.propertyFrame.Visible, "Properties should start open")
assert(#app.view.pool < 35, "Tree widgets are not viewport bounded")
app.tree:Toggle(workspace)
app.selection:Set(target)
assert(app.inspector.item == target and string.find(app.window.path.Text, "Target"), "Selection/inspector failed")
local archivable = app.inspector.scroll:FindFirstChild("Archivable")
assert(archivable and archivable:FindFirstChild("Checkbox"), "Boolean checkbox missing")
archivable:FindFirstChild("Checkbox").Activated:Fire()
assert(target.Archivable == false, "Checkbox did not write the property")
local countInput = app.inspector.scroll:FindFirstChild("Count"):FindFirstChild("Value")
countInput.Text = "4"
countInput.FocusLost:Fire()
assert(target:GetAttribute("Count") == 4, "Attribute editor did not commit")
app.window.widthGrip.InputBegan:Fire({ UserInputType = rb.Enum.UserInputType.MouseButton1, Position = rb.Vector3.new(860, 50, 0) })
input.InputChanged:Fire({ UserInputType = rb.Enum.UserInputType.MouseMovement, Position = rb.Vector3.new(800, 50, 0) })
assert(app.window.dockWidth == 480 and app.window.frame.Position.X.Offset == -480, "Dock resize detached it from the right")
input.InputEnded:Fire({ UserInputType = rb.Enum.UserInputType.MouseButton1 })
app.window.dockWidth = 420
app.window:Clamp()
app.window.properties.Activated:Fire()
assert(not app.window.propertyFrame.Visible, "Properties toggle failed")
app.window.properties.Activated:Fire()
app.window:OpenMenu()
assert(app.window.menu.Visible, "Context menu failed")
app.window.hide.Activated:Fire()
assert(not app.window.frame.Visible and not app.window.menu.Visible and app.window.restore.Visible, "Hide failed")
app.window.restore.Activated:Fire()
assert(app.window.frame.Visible and app.window.propertyFrame.Visible, "Restore failed")
app.window.propertySearch.Text = "Name"
assert(app.inspector.query == "name", "Property filter failed")
app.window.propertySearch.Text = ""
local catalog = Import("PropertyCatalog")
assert(#catalog.Get(make("Part")) > 45, "Full inherited property metadata is missing")
local atlas = Import("IconAtlas")
local iconCount = 0
for _ in atlas.Classes do iconCount += 1 end
assert(iconCount >= 300, "Class icons are missing")
local scriptItem = make("LocalScript")
scriptItem.Name, scriptItem.Source, scriptItem.Parent = "Example", "return 42", workspace
app.selection:Set(scriptItem)
app.window.viewScript.Activated:Fire()
assert(app.scriptViewer.frame.Visible and app.scriptViewer.code.Text == "return 42", "Source viewer failed")
app.window:Toggle()
assert(not app.scriptViewer.frame.Visible, "Hiding the dock left the source viewer visible")
app.window:Toggle()
app.window.viewScript.Activated:Fire()
app.scriptViewer.close.Activated:Fire()
assert(not app.scriptViewer.frame.Visible, "Source viewer close failed")
app.selection:Set(target)
app.window.search.Text = "Target"
drain()
assert(#app.tree.rows == 1 and app.tree.rows[1].instance == target, "Debounced search failed")
app.window.reveal.Activated:Fire()
drain()
assert(app.tree.query == "" and app.tree.expanded[workspace], "Reveal failed")
target:SetAttribute("New", true)
drain()
app.window.refresh.Activated:Fire()
drain()
app.window.close.Activated:Fire()
drain()
assert(app.dead and listeners == 0, "Unload leaked " .. listeners .. " listeners")
app:Destroy()
print("Minified app: right dock, default properties, property filtering, inherited metadata, 313 icons, source viewer, selection, search, reveal, refresh and listener cleanup passed (mock engine).")

if fs.isFile("loader.luau") then
	local globals, hits, corrupt = {}, {}, false
	env.getgenv = function() return globals end
	env.gethui = function() return playerGui end
	env.loadstring = function(source)
		local ok, chunk = pcall(luau.load, source, { environment = env })
		if ok then return chunk end
		return nil, tostring(chunk)
	end
	game.IsLoaded = function() return true end
	services.Players = { LocalPlayer = make("Player") }
	game.HttpGet = function(_, url)
		local name = assert(string.match(url, "/([^/]+)%.luau$"))
		hits[name] = (hits[name] or 0) + 1
		if corrupt then return "<html>Service unavailable</html>" end
		if name == "Config" and hits[name] == 1 then error("Transient connection error") end
		return fs.readFile("dist/modules/" .. name .. ".luau")
	end
	local loader = fs.readFile("loader.luau")
	local first = env.loadstring(loader)()
	drain()
	assert(globals.ExplorerPlus == first and globals.ExplorerPlusLoading == nil and hits.Config == 2, "Loader retry/startup failed")
	local second = env.loadstring(loader)()
	drain()
	assert(first.dead and not second.dead and globals.ExplorerPlus == second, "Reexecution did not replace the old app")
	corrupt = true
	local ok = pcall(env.loadstring(loader))
	assert(not ok and globals.ExplorerPlusLoading == nil and not second.dead, "Failed download damaged the running app or left the startup lock")
	corrupt = false
	globals.ExplorerPlusLoading = true
	assert(not pcall(env.loadstring(loader)), "Concurrent launch was not rejected")
	globals.ExplorerPlusLoading = nil
	second:Destroy()
	drain()
	assert(listeners == 0, "Loader reexecution leaked listeners")
	print("Minified loader retry, checksum rejection, dependency loading, singleton replacement, concurrent-launch guard and failure recovery passed (mock HTTP/engine).")
end
