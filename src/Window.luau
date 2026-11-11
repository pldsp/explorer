local UI = require(script.Parent.UI)
local Config = require(script.Parent.Config)
local Janitor = require(script.Parent.Janitor)
local Icons = require(script.Parent.Icons)
local Input = game:GetService("UserInputService")
local Window = {}
Window.__index = Window

function Window.new(parent)
	local self = setmetatable({ janitor = Janitor.new(), propertiesOpen = true, dockWidth = Config.DockWidth, ratio = Config.DockRatio }, Window)
	self.gui = UI.new("ScreenGui", { Name = "ExplorerPlus", ResetOnSpawn = false, DisplayOrder = 10000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false }, parent)
	self.frame = UI.frame(self.gui, { Name = "StudioDock", Position = UDim2.new(1, -self.dockWidth, 0, 0), Size = UDim2.new(0, self.dockWidth, 1, 0), Active = true, ClipsDescendants = true, BorderSizePixel = 1, BorderColor3 = Config.Colors.Border })
	local title = UI.frame(self.frame, { Name = "ExplorerTitle", Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Color3.fromRGB(53, 53, 53) })
	local titleIcon = Icons.new(title)
	Icons.set(titleIcon, { ClassName = "Workspace" })
	titleIcon.root.Position = UDim2.fromOffset(10, 6)
	UI.text(title, "Explorer", { Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -164, 1, 0), TextSize = 15 })
	self.viewScript = UI.button(title, "</>", { Name = "ViewScript", Position = UDim2.new(1, -112, 0, 2), Size = UDim2.fromOffset(28, 24), BackgroundTransparency = 1 })
	self.properties = UI.button(title, "▤", { Name = "Properties", Position = UDim2.new(1, -84, 0, 2), Size = UDim2.fromOffset(26, 24), BackgroundTransparency = 1 })
	self.hide = UI.button(title, "−", { Name = "Hide", Position = UDim2.new(1, -56, 0, 2), Size = UDim2.fromOffset(26, 24), BackgroundTransparency = 1 })
	self.close = UI.button(title, "×", { Name = "Close", Position = UDim2.new(1, -28, 0, 2), Size = UDim2.fromOffset(26, 24), BackgroundTransparency = 1 })
	local filter = UI.frame(self.frame, { Name = "FilterBar", Position = UDim2.fromOffset(1, 29), Size = UDim2.new(1, -2, 0, 28), BackgroundColor3 = Config.Colors.Input })
	UI.text(filter, "⌕", { Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(20, 28), TextSize = 20 })
	self.search = UI.input(filter, "Filter workspace (Ctrl+Shift+X)", { Name = "Search", Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 1, 0), BackgroundTransparency = 1 })
	self.tree = UI.frame(self.frame, { Name = "Tree", Position = UDim2.fromOffset(1, 58) })
	self.status = UI.text(self.frame, "", { Name = "Status", TextSize = 12, TextColor3 = Config.Colors.Muted })
	self.propertyFrame = UI.frame(self.frame, { Name = "Properties", Active = true, ClipsDescendants = true, BorderSizePixel = 1, BorderColor3 = Config.Colors.Border })
	local propertyTitle = UI.frame(self.propertyFrame, { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Color3.fromRGB(53, 53, 53) })
	UI.text(propertyTitle, "Properties", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -40, 1, 0), TextSize = 15 })
	local propertyClose = UI.button(propertyTitle, "×", { Position = UDim2.new(1, -28, 0, 2), Size = UDim2.fromOffset(26, 24), BackgroundTransparency = 1 })
	self.propertySearch = UI.input(self.propertyFrame, "Filter properties / categories", { Name = "PropertyFilter", Position = UDim2.fromOffset(4, 32), Size = UDim2.new(1, -8, 0, 26) })
	self.path = UI.input(self.propertyFrame, "Select an instance", { Position = UDim2.fromOffset(4, 61), Size = UDim2.new(1, -8, 0, 23), TextEditable = false, TextColor3 = Config.Colors.Muted })
	self.inspector = UI.frame(self.propertyFrame, { Position = UDim2.fromOffset(1, 88), Size = UDim2.new(1, -2, 1, -89) })
	self.widthGrip = UI.frame(self.frame, { Name = "ResizeDock", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 5, 1, 0), BackgroundTransparency = 1, Active = true, ZIndex = 10 })
	self.splitGrip = UI.frame(self.frame, { Name = "ResizeProperties", Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = Config.Colors.Border, Active = true, ZIndex = 10 })
	self.restore = UI.button(self.gui, "Explorer  ◂", { Position = UDim2.new(1, -112, 0, 4), Size = UDim2.fromOffset(108, 28), Visible = false })
	self.menu = UI.frame(self.gui, { Name = "ContextMenu", Size = UDim2.fromOffset(202, 176), Visible = false, ZIndex = 20, BorderSizePixel = 1, BorderColor3 = Config.Colors.Border })
	local actions = { { "scriptAction", "View script", "LocalScript" }, { "propertiesAction", "Properties", "Configuration" }, { "focus", "Focus selection", "Camera" }, { "reveal", "Reveal in Explorer", "Folder" }, { "copy", "Copy path", "StringValue" }, { "refresh", "Refresh", "Workspace" } }
	for index, action in actions do
		local button = UI.button(self.menu, action[2], { Name = action[1], Position = UDim2.fromOffset(2, (index - 1) * 28 + 4), Size = UDim2.new(1, -4, 0, 27), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, BackgroundTransparency = 1 })
		self[action[1]] = button
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 32) }, button)
		local icon = Icons.new(button)
		Icons.set(icon, { ClassName = action[3] })
		icon.root.Position, icon.root.ZIndex = UDim2.fromOffset(-24, 5), 22
		self.janitor:Add(button.Activated:Connect(function() self.menu.Visible = false end))
	end
	self.janitor:Add(self.hide.Activated:Connect(function() self:Toggle() end))
	self.janitor:Add(self.restore.Activated:Connect(function() self:Toggle() end))
	self.janitor:Add(self.properties.Activated:Connect(function() self:ShowProperties(not self.propertiesOpen) end))
	self.janitor:Add(propertyClose.Activated:Connect(function() self:ShowProperties(false) end))
	self.janitor:Add(self.propertiesAction.Activated:Connect(function() self:ShowProperties(true) end))
	self.janitor:Add(Input.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local point = Input:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
			local position, size = self.menu.AbsolutePosition, self.menu.AbsoluteSize
			if point.X < position.X or point.Y < position.Y or point.X > position.X + size.X or point.Y > position.Y + size.Y then self.menu.Visible = false end
		end
		if Input:GetFocusedTextBox() then return end
		if not processed and input.KeyCode == Config.ToggleKey then self:Toggle() end
		if input.KeyCode == Enum.KeyCode.X and (Input:IsKeyDown(Enum.KeyCode.LeftControl) or Input:IsKeyDown(Enum.KeyCode.RightControl)) and (Input:IsKeyDown(Enum.KeyCode.LeftShift) or Input:IsKeyDown(Enum.KeyCode.RightShift)) then
			if not self.frame.Visible then self:Toggle() end
			self.search:CaptureFocus()
		end
	end))
	local mode, origin, original, touch
	local function begin(input, nextMode)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		mode, origin = nextMode, input.Position
		touch = input.UserInputType == Enum.UserInputType.Touch and input or nil
		original = mode == "width" and self.dockWidth or self.ratio
	end
	self.janitor:Add(self.widthGrip.InputBegan:Connect(function(input) begin(input, "width") end))
	self.janitor:Add(self.splitGrip.InputBegan:Connect(function(input) begin(input, "split") end))
	self.janitor:Add(Input.InputEnded:Connect(function(input)
		if input == touch or input.UserInputType == Enum.UserInputType.MouseButton1 then mode = nil end
	end))
	self.janitor:Add(Input.InputChanged:Connect(function(input)
		if not mode then return end
		if touch then if input ~= touch then return end
		elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local delta = input.Position - origin
		if mode == "width" then self.dockWidth = original - delta.X
		else self.ratio = math.clamp(original + delta.Y / math.max(1, self.gui.AbsoluteSize.Y), 0.25, 0.8) end
		self:Clamp()
	end))
	self.janitor:Add(self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Clamp() end))
	task.defer(function() if self.gui.Parent then self:Clamp() end end)
	return self
end

function Window:ShowProperties(show)
	self.propertiesOpen = show
	self.propertyFrame.Visible = show
	self:Clamp()
end

function Window:OpenMenu()
	local point = Input:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
	local bounds = self.gui.AbsoluteSize
	self.menu.Position = UDim2.fromOffset(math.clamp(point.X, 0, math.max(0, bounds.X - 202)), math.clamp(point.Y, 0, math.max(0, bounds.Y - 176)))
	self.menu.Visible = true
end

function Window:Clamp()
	local bounds = self.gui.AbsoluteSize
	if bounds.X == 0 or bounds.Y == 0 then return end
	self.dockWidth = math.clamp(self.dockWidth, math.min(300, bounds.X), math.min(760, bounds.X))
	self.frame.Position = UDim2.new(1, -self.dockWidth, 0, 0)
	self.frame.Size = UDim2.new(0, self.dockWidth, 1, 0)
	local split = self.propertiesOpen and math.floor(bounds.Y * self.ratio) or bounds.Y
	self.tree.Size = UDim2.new(1, -2, 0, math.max(0, split - 81))
	self.status.Position, self.status.Size = UDim2.fromOffset(8, split - 22), UDim2.new(1, -16, 0, 19)
	self.splitGrip.Visible = self.propertiesOpen
	self.splitGrip.Position = UDim2.fromOffset(0, split - 3)
	self.propertyFrame.Position = UDim2.fromOffset(0, split + 2)
	self.propertyFrame.Size = UDim2.new(1, 0, 0, math.max(0, bounds.Y - split - 2))
end

function Window:Toggle()
	self.frame.Visible = not self.frame.Visible
	self.restore.Visible = not self.frame.Visible
	self.menu.Visible = false
	if self.onToggle then self.onToggle(self.frame.Visible) end
end

function Window:SetStatus(message, isError)
	self.status.Text = message
	self.status.TextColor3 = isError and Config.Colors.Error or Config.Colors.Muted
end

function Window:Destroy()
	self.janitor:Destroy()
	self.gui:Destroy()
end

return Window
