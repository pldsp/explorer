local Window = require(script.Parent.Window)
local TreeModel = require(script.Parent.TreeModel)
local TreeView = require(script.Parent.TreeView)
local Inspector = require(script.Parent.Inspector)
local Selection = require(script.Parent.Selection)
local Janitor = require(script.Parent.Janitor)
local Config = require(script.Parent.Config)
local ScriptViewer = require(script.Parent.ScriptViewer)
local App = {}
App.__index = App

function App.new(parent)
	local self = setmetatable({ janitor = Janitor.new(), dead = false, searchVersion = 0 }, App)
	local ok, err = xpcall(function()
	self.window = Window.new(parent)
	local window = self.window
	self.inspector = Inspector.new(window.inspector, function(message, isError) window:SetStatus(message, isError) end, window.propertySearch)
	self.scriptViewer = ScriptViewer.new(window.gui, window.frame)
	window.onToggle = function(visible) if not visible then self.scriptViewer:Hide() end end
	self.selection = Selection.new(workspace, function(item)
		self.view:Select(item)
		if self.inspector.item ~= item then self.inspector:Select(item) end
		window.path.Text = item and item:GetFullName() or ""
	end)
	self.view = TreeView.new(window.tree, function(item) self.selection:Set(item) end, function(item) self.tree:Toggle(item) end, function() window:OpenMenu() end)
	self.tree = TreeModel.new(game, { window.gui, self.selection.highlight }, function(rows, message)
		self.view:SetRows(rows, self.tree and self.tree.expanded or { [game] = true })
		window:SetStatus(message)
	end)
	self.janitor:Add(window.search:GetPropertyChangedSignal("Text"):Connect(function()
		self.searchVersion += 1
		local version = self.searchVersion
		self.tree.generation += 1
		task.delay(Config.SearchDebounce, function()
			if not self.dead and version == self.searchVersion then self.tree:Search(window.search.Text) end
		end)
	end))
	self.janitor:Add(window.refresh.Activated:Connect(function()
		self.tree:Search(window.search.Text)
		self.inspector:Select(self.selection.item)
	end))
	self.janitor:Add(window.focus.Activated:Connect(function()
		local ok, message = self.selection:Focus()
		window:SetStatus(message, not ok)
	end))
	local function viewScript()
		local item = self.selection.item
		if not item or not item:IsA("LuaSourceContainer") then window:SetStatus("Select a script to view its source", true); return end
		self.scriptViewer:Open(item)
	end
	self.janitor:Add(window.viewScript.Activated:Connect(viewScript))
	self.janitor:Add(window.scriptAction.Activated:Connect(viewScript))
	self.view.openScript = viewScript
	self.janitor:Add(window.copy.Activated:Connect(function()
		if not self.selection.item then window:SetStatus("Select an instance first", true); return end
		local clipboard = setclipboard or toclipboard
		if type(clipboard) == "function" then
			local copied, reason = pcall(clipboard, window.path.Text)
			window:SetStatus(copied and "Path copied" or tostring(reason), not copied)
		else
			window:ShowProperties(true)
			window.path:CaptureFocus()
			window.path.SelectionStart = 1
			window.path.CursorPosition = #window.path.Text + 1
			window:SetStatus("Press Ctrl+C to copy the path")
		end
	end))
	self.janitor:Add(window.reveal.Activated:Connect(function()
		local item = self.selection.item
		if not item then window:SetStatus("Select an instance first", true); return end
		window.search.Text = ""
		self.tree:Reveal(item)
		self.view:Reveal(item)
	end))
	self.janitor:Add(window.close.Activated:Connect(function() self:Destroy() end))
	self.janitor:Add(window.gui.Destroying:Connect(function() self:Destroy() end))
	end, debug.traceback)
	if not ok then self:Destroy(); error(err, 0) end
	return self
end

function App:Destroy()
	if self.dead then return end
	self.dead = true
	self.searchVersion += 1
	self.janitor:Destroy()
	for _, name in { "tree", "selection", "scriptViewer", "inspector", "view", "window" } do
		if self[name] then self[name]:Destroy() end
	end
end

return App
