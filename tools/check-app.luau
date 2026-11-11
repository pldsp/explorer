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
local events = { "Changed", "Destroying", "AncestryChanged", "ChildAdded", "ChildRemoved", "AttributeChanged", "Activated", "MouseButton2Click", "MouseEnter", "MouseLeave", "InputBegan", "InputEnded", "InputChanged", "FocusLost" }
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
	self.Changed:Fire(key == "Value" and value or key)
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
	if class == "GuiObject" then return table.find({ "CanvasGroup", "Frame", "TextLabel", "TextButton", "TextBox", "ScrollingFrame" }, self.ClassName) ~= nil end
	if class == "GuiBase2d" then return self:IsA("GuiObject") or self.ClassName == "ScreenGui" end
	if class == "LayerCollector" then return self.ClassName == "ScreenGui" end
	if class == "BasePart" then return self.ClassName == "Part" end
	if class == "LuaSourceContainer" then return table.find({ "LocalScript", "ModuleScript", "Script" }, self.ClassName) ~= nil end
	return false
end
function methods:FindFirstChild(name)
	for _, child in self.children do if child.Name == name then return child end end
end
function methods:FindFirstChildOfClass(class)
	for _, child in self.children do if child.ClassName == class then return child end end
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
local manualTweens, tweens = false, {}
local tweenService = {}
function tweenService:Create(target, info, properties)
	local tween = { Completed = signal(), state = "created", info = info }
	function tween:Complete()
		if self.state == "cancelled" or self.state == "completed" then return end
		self.state = "completed"
		for key, value in properties do target[key] = value end
		self.Completed:Fire(rb.Enum.PlaybackState.Completed)
	end
	function tween:Play()
		self.state = "playing"
		if not manualTweens and info.RepeatCount ~= -1 then self:Complete() end
	end
	function tween:Cancel()
		self.state = "cancelled"
		self.Completed:Fire(rb.Enum.PlaybackState.Cancelled)
	end
	table.insert(tweens, tween)
	return tween
end
local services = { TweenService = tweenService, Lighting = make("Lighting"), UserInputService = input, GuiService = { GetGuiInset = function() return V2.zero end } }
game.GetService = function(_, name) return assert(services[name], name) end
local target = make("Folder")
target.Name, target.Parent = "Target", workspace
target.Archivable = true
target:SetAttribute("Count", 3)
local copiedSource, savedSource, savedName, injectInitFailure
local env = {
	setclipboard = function(text) copiedSource = text end,
	writefile = function(name, text) savedName, savedSource = name, text end,
	Instance = { new = function(class) if injectInitFailure and class == "Highlight" then error("Injected initialization failure") end; return make(class) end }, game = game, workspace = workspace,
	Enum = rb.Enum, Vector2 = rb.Vector2, Vector3 = rb.Vector3,
	UDim = rb.UDim, UDim2 = rb.UDim2, Color3 = rb.Color3, CFrame = rb.CFrame,
	BrickColor = rb.BrickColor, Rect = rb.Rect, NumberRange = rb.NumberRange,
	ColorSequence = rb.ColorSequence, ColorSequenceKeypoint = rb.ColorSequenceKeypoint,
	TweenInfo = { new = function(duration, style, direction, repeatCount) return { Time = duration, Style = style, Direction = direction, RepeatCount = repeatCount } end },
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
assert(app.window.frame.Size.X.Offset == 320, "Incorrect panel width")
assert(app.window.frame.Size.Y.Scale == 1 and app.window.frame.Position.X.Scale == 1 and app.window.frame.Position.X.Offset == -320 and app.window.frame.Position.Y.Offset == 22, "Explorer is not attached to the right edge")
assert(app.window.explorerBody.BackgroundTransparency == 0.2 and app.window.propertyFrame.BackgroundTransparency == 0.2, "Reference panel transparency missing")
assert(app.window.search.PlaceholderText == "Search workspace" and app.window.propertySearch.PlaceholderText == "Search properties", "Reference search bars missing")
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
local addAttribute = app.inspector.scroll:FindFirstChild("AddAttribute")
addAttribute:FindFirstChild("Open").Activated:Fire()
addAttribute:FindFirstChild("AttributeName").Text = "CreatedFromExplorer"
addAttribute:FindFirstChild("AttributeValue").Text = "hello"
addAttribute:FindFirstChild("Create").Activated:Fire()
drain()
assert(target:GetAttribute("CreatedFromExplorer") == "hello", "Add Attribute failed")
app.window.widthGrip.InputBegan:Fire({ UserInputType = rb.Enum.UserInputType.MouseButton1, Position = rb.Vector3.new(860, 50, 0) })
input.InputChanged:Fire({ UserInputType = rb.Enum.UserInputType.MouseMovement, Position = rb.Vector3.new(800, 50, 0) })
assert(app.window.dockWidth == 380 and app.window.frame.Position.X.Offset == -380, "Dock resize detached it from the right")
input.InputEnded:Fire({ UserInputType = rb.Enum.UserInputType.MouseButton1 })
app.window.dockWidth = 320
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
manualTweens = true
app.window:SetShown(false)
local hiding = app.window.motion.active[app.window.frame].tween
app.window:SetShown(true)
assert(hiding.state == "cancelled", "Restore did not cancel the closing animation")
for _, tween in table.clone(tweens) do if tween.state == "playing" and tween.info.RepeatCount ~= -1 then tween:Complete() end end
assert(app.window.shown and app.window.frame.Visible and app.window.frame.GroupTransparency == 0, "A stale hide callback hid the restored dock")
app.window:ShowProperties(false)
local closingProperties = app.window.motion.active[app.window.propertyAmount].tween
app.window:ShowProperties(true)
assert(closingProperties.state == "cancelled", "Property transition was not interrupted cleanly")
for _, tween in table.clone(tweens) do if tween.state == "playing" and tween.info.RepeatCount ~= -1 then tween:Complete() end end
assert(app.window.propertyFrame.Visible and app.window.propertyAmount.Value == 1, "Interrupted property animation hid the panel")
manualTweens = false
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
assert(app.scriptViewer.frame.Visible and app.scriptViewer.document.text == "return 42", "Source viewer failed")
assert(app.scriptViewer.title.Text == "Notepad", "Reference Notepad header missing")
local largeSource = string.rep("local value = 1234567890\n", 20000) .. "return 'FINAL_LINE_MARKER'"
assert(#largeSource > 200000)
app.scriptViewer:SetText(largeSource)
assert(app.scriptViewer.text == largeSource and app.scriptViewer.document.text == largeSource, "Source is still truncated")
app.scriptViewer.scroll.CanvasPosition = V2.new(0, (#app.scriptViewer.document.starts - 1) * 16)
assert(string.find(app.scriptViewer.pool[1].raw, "FINAL_LINE_MARKER", 1, true), "Cannot scroll to the final source line")
assert(#app.scriptViewer.pool < 35, "Source UI grows with document length")
app.scriptViewer.copy.Activated:Fire()
app.scriptViewer.save.Activated:Fire()
assert(copiedSource == largeSource and savedSource == largeSource and savedName == "Explorer_Example.luau", "Full-source copy/save failed")
local longLine = string.rep("x", 260000) .. "LAST_COLUMN_MARKER"
app.scriptViewer:SetText(longLine)
app.scriptViewer.scroll.CanvasPosition = V2.new(260000 * 7, 0)
assert(string.find(app.scriptViewer.pool[1].raw, "LAST_COLUMN_MARKER", 1, true), "Single-line source is truncated horizontally")
app.scriptViewer.clear.Activated:Fire()
assert(app.scriptViewer.text == "" and #app.scriptViewer.document.starts == 1, "Clear failed")
app.window:Toggle()
assert(not app.scriptViewer.frame.Visible, "Hiding the dock left the source viewer visible")
app.window:Toggle()
app.window.viewScript.Activated:Fire()
app.scriptViewer.close.Activated:Fire()
assert(not app.scriptViewer.frame.Visible, "Source viewer close failed")
app.window.propertyFloat.Activated:Fire()
assert(app.window.floatingProperties and app.window.propertyFrame.Parent == app.window.gui, "Properties undock failed")
app.window.propertyFloat.Activated:Fire()
assert(not app.window.floatingProperties and app.window.propertyFrame.Parent == app.window.frame, "Properties redock failed")
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
	local globals, hits, corrupt, networkFailure = {}, {}, false, false
	local compileFailure = false
	local warnings = {}
	env.warn = function(message) table.insert(warnings, message) end
	env.getgenv = function() return globals end
	env.gethui = function() return playerGui end
	env.loadstring = function(source)
		if compileFailure and source == fs.readFile("dist/modules/Config.luau") then return nil, "Injected compile failure" end
		local ok, chunk = pcall(luau.load, source, { environment = env })
		if ok then return chunk end
		return nil, tostring(chunk)
	end
	game.IsLoaded = function() return true end
	services.Players = { LocalPlayer = make("Player") }
	game.HttpGet = function(_, url)
		local name = assert(string.match(url, "/([^/]+)%.luau$"))
		hits[name] = (hits[name] or 0) + 1
		if networkFailure then error("Network unavailable") end
		if corrupt then return "<html>Service unavailable</html>" end
		if name == "Config" and hits[name] == 1 then error("Transient connection error") end
		return fs.readFile("dist/modules/" .. name .. ".luau")
	end
	local loader = fs.readFile("loader.luau")
	local first = env.loadstring(loader)()
	drain()
	assert(globals.ExplorerPlus == first and globals.ExplorerPlusLoading == nil and hits.Config == 2, "Loader retry/startup failed")
	assert(globals.ExplorerPlusIntro == nil and #services.Lighting:GetChildren() == 0, "Successful intro did not remove its GUI/blur")
	local beforeHits = hits.Config
	first.window:SetShown(false)
	local second = env.loadstring(loader)()
	drain()
	assert(first == second and not first.dead and hits.Config == beforeHits and second.window.shown and string.find(warnings[#warnings], "E001", 1, true), "Duplicate launch did not reuse the running app with E001")
	second:Destroy()
	drain()
	corrupt = true
	local ok, reason = pcall(env.loadstring(loader))
	assert(not ok and string.find(reason, "E102", 1, true) and globals.ExplorerPlusLoading == nil, "Checksum failure did not report E102 or release the startup lock")
	assert(globals.ExplorerPlusIntro and globals.ExplorerPlusIntro.failed, "Download failure did not display the error card")
	corrupt = false
	networkFailure = true
	ok, reason = pcall(env.loadstring(loader))
	assert(not ok and string.find(reason, "E101", 1, true), "Network failure did not report E101")
	networkFailure = false
	compileFailure = true
	ok, reason = pcall(env.loadstring(loader))
	assert(not ok and string.find(reason, "E104", 1, true), "Compilation failure did not report E104")
	compileFailure = false
	injectInitFailure = true
	ok, reason = pcall(env.loadstring(loader))
	assert(not ok and string.find(reason, "E109", 1, true), "App initialization failure did not report E109")
	injectInitFailure = false
	local spawn = env.task.spawn
	env.task.spawn = function() end
	local clock = 0
	env.os = { clock = function() clock += 60; return clock end }
	ok, reason = pcall(env.loadstring(loader))
	assert(not ok and string.find(reason, "E103", 1, true), "Download timeout did not report E103")
	env.task.spawn, env.os = spawn, nil
	local recovered = env.loadstring(loader)()
	drain()
	assert(not recovered.dead and globals.ExplorerPlusLoading == nil and globals.ExplorerPlusIntro == nil, "Retry after an error failed")
	recovered:Destroy()
	drain()
	globals.ExplorerPlusLoading = true
	local startupNotice
	globals.ExplorerPlusStartup = { Notice = function(_, message) startupNotice = message end }
	ok, reason = pcall(env.loadstring(loader))
	assert(ok and reason == nil and string.find(warnings[#warnings], "E002", 1, true) and string.find(startupNotice, "E002", 1, true), "Concurrent launch did not report E002 in the intro")
	globals.ExplorerPlusLoading, globals.ExplorerPlusStartup = nil, nil
	drain()
	assert(listeners == 0 and #services.Lighting:GetChildren() == 0, "Loader or animation cleanup leaked listeners/blur")
	print("Minified loader: intro/blur cleanup; E001/E002 duplicates; E101 network, E102 bytes, E103 timeout, E104 compile, E109 initialization errors; and retry passed (mock HTTP/engine).")
end
