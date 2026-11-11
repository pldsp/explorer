local UI = require(script.Parent.UI)
local Config = require(script.Parent.Config)
local Janitor = require(script.Parent.Janitor)
local Icons = require(script.Parent.Icons)
local Drag = require(script.Parent.Drag)
local Motion = require(script.Parent.Motion)
local Input = game:GetService("UserInputService")
local Window = {}
Window.__index = Window

local function searchBar(parent, placeholder, name)
	local input = UI.input(parent, placeholder, { Name = name, Position = UDim2.fromOffset(3, 21), Size = UDim2.new(1, -6, 0, 20), BorderSizePixel = 1, BorderColor3 = Color3.fromRGB(58, 58, 58) })
	input:FindFirstChildOfClass("UIPadding").PaddingRight = UDim.new(0, 20)
	local icon = UI.frame(parent, { Position = UDim2.new(1, -19, 0, 25), Size = UDim2.fromOffset(8, 8), BackgroundTransparency = 1 })
	UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }, icon)
	UI.new("UIStroke", { Thickness = 1.4, Color = Color3.fromRGB(116, 116, 116) }, icon)
	UI.frame(parent, { Position = UDim2.new(1, -11, 0, 34), Size = UDim2.fromOffset(5, 1), Rotation = 45, BackgroundColor3 = Color3.fromRGB(116, 116, 116) })
	return input
end

local function overlapButton(parent)
	local button = UI.button(parent, "", { Position = UDim2.new(1, -36, 0, 0), Size = UDim2.fromOffset(18, 20), BackgroundTransparency = 1 })
	UI.frame(button, { Position = UDim2.fromOffset(5, 8), Size = UDim2.fromOffset(6, 5), BackgroundTransparency = 1, BorderSizePixel = 1, BorderColor3 = Config.Colors.Text })
	UI.frame(button, { Position = UDim2.fromOffset(7, 5), Size = UDim2.fromOffset(6, 5), BackgroundColor3 = Color3.fromRGB(51, 51, 51), BorderSizePixel = 1, BorderColor3 = Config.Colors.Text })
	return button
end

function Window.new(parent)
	local self = setmetatable({ janitor = Janitor.new(), motion = Motion.new(), propertiesOpen = true, shown = true, entered = false, dockWidth = Config.DockWidth, ratio = Config.DockRatio, floatingProperties = false, showingPath = false }, Window)
	self.gui = UI.new("ScreenGui", { Name = "ExplorerPlus", ResetOnSpawn = false, DisplayOrder = 10000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false }, parent)
	self.frame = UI.group(self.gui, { Name = "StudioDock", GroupTransparency = 1, BackgroundTransparency = 1, Active = true, ClipsDescendants = false, BorderSizePixel = 1, BorderColor3 = Color3.fromRGB(29, 29, 29) })
	self.propertyAmount = UI.new("NumberValue", { Name = "PropertyAnimation", Value = 1 }, self.gui)
	self.explorerBody = UI.frame(self.frame, { Name = "Explorer", BackgroundTransparency = Config.PanelTransparency, ClipsDescendants = true })
	local title = UI.frame(self.explorerBody, { Name = "ExplorerTitle", Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(51, 51, 51) })
	UI.text(title, "Explorer", { Position = UDim2.fromOffset(5, 0), Size = UDim2.new(1, -48, 1, 0) })
	self.properties = overlapButton(title)
	self.properties.Name = "ToggleProperties"
	self.close = UI.button(title, "×", { Name = "Close", Position = UDim2.new(1, -18, 0, 0), Size = UDim2.fromOffset(18, 20), BackgroundTransparency = 1, TextSize = 16 })
	self.hide = UI.button(self.gui, ">", { Name = "Hide", Position = UDim2.new(1, -16, 0, -14), Size = UDim2.fromOffset(16, 36), BackgroundColor3 = Color3.fromRGB(51, 51, 51), BorderSizePixel = 1, BorderColor3 = Color3.fromRGB(29, 29, 29) })
	self.restore = UI.button(self.gui, "<", { Position = self.hide.Position, Size = self.hide.Size, BackgroundColor3 = Color3.fromRGB(51, 51, 51), Visible = false })
	self.search = searchBar(self.explorerBody, "Search workspace", "Search")
	self.tree = UI.frame(self.explorerBody, { Name = "Tree", Position = UDim2.fromOffset(1, 43), BackgroundTransparency = 1 })
	self.status = UI.text(self.explorerBody, "", { Name = "Status", Visible = false, TextSize = 11, TextColor3 = Config.Colors.Error, BackgroundTransparency = 0.1, BackgroundColor3 = Config.Colors.Panel, ZIndex = 11 })
	self.propertyFrame = UI.group(self.frame, { Name = "Properties", Active = true, ClipsDescendants = true, BackgroundTransparency = Config.PanelTransparency, BorderSizePixel = 1, BorderColor3 = Color3.fromRGB(29, 29, 29) })
	local propertyTitle = UI.frame(self.propertyFrame, { Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(51, 51, 51), Active = true })
	UI.text(propertyTitle, "Properties", { Position = UDim2.fromOffset(5, 0), Size = UDim2.new(1, -48, 1, 0) })
	self.propertyFloat = overlapButton(propertyTitle)
	local propertyClose = UI.button(propertyTitle, "×", { Position = UDim2.new(1, -18, 0, 0), Size = UDim2.fromOffset(18, 20), BackgroundTransparency = 1, TextSize = 16 })
	self.propertySearch = searchBar(self.propertyFrame, "Search properties", "PropertyFilter")
	self.path = UI.input(self.propertyFrame, "Select an instance", { Name = "Path", Visible = false, Position = UDim2.fromOffset(3, 44), Size = UDim2.new(1, -6, 0, 22), TextEditable = false, TextColor3 = Config.Colors.Muted })
	self.inspector = UI.frame(self.propertyFrame, { Position = UDim2.fromOffset(1, 44), Size = UDim2.new(1, -2, 1, -45), BackgroundTransparency = 1 })
	self.widthGrip = UI.frame(self.frame, { Name = "ResizeDock", Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Color3.fromRGB(30, 30, 30), BackgroundTransparency = 0.1, Active = true, ZIndex = 10 })
	self.splitGrip = UI.frame(self.frame, { Name = "ResizeProperties", Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Color3.fromRGB(31, 31, 31), Active = true, ZIndex = 10 })
	local floatGrip = UI.button(self.propertyFrame, "◢", { Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Visible = false })
	self.floatGrip = floatGrip
	Drag.Attach(self.propertyFrame, propertyTitle, floatGrip, self.janitor, self.gui, function() return self.floatingProperties end)
	self.menu = UI.group(self.gui, { Name = "ContextMenu", Size = UDim2.fromOffset(202, 176), Visible = false, GroupTransparency = 1, ZIndex = 20, BorderSizePixel = 1, BorderColor3 = Config.Colors.Border })
	local actions = { { "scriptAction", "View script", "LocalScript" }, { "propertiesAction", "Properties", "Configuration" }, { "focus", "Focus selection", "Camera" }, { "reveal", "Reveal in Explorer", "Folder" }, { "copy", "Copy path", "StringValue" }, { "refresh", "Refresh", "Workspace" } }
	for index, action in actions do
		local button = UI.button(self.menu, action[2], { Name = action[1], Position = UDim2.fromOffset(2, (index - 1) * 28 + 4), Size = UDim2.new(1, -4, 0, 27), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, BackgroundTransparency = 1 })
		self[action[1]] = button
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 32) }, button)
		local icon = Icons.new(button)
		Icons.set(icon, { ClassName = action[3] })
		icon.root.Position, icon.root.ZIndex = UDim2.fromOffset(-24, 5), 22
		self.janitor:Add(button.Activated:Connect(function() self:CloseMenu() end))
		self.motion:Button(button, self.janitor)
	end
	self.viewScript = self.scriptAction
	for _, button in { self.hide, self.restore, self.close, self.properties, self.propertyFloat, propertyClose } do self.motion:Button(button, self.janitor) end
	self.janitor:Add(self.hide.Activated:Connect(function() self:Toggle() end))
	self.janitor:Add(self.restore.Activated:Connect(function() self:Toggle() end))
	self.janitor:Add(self.properties.Activated:Connect(function() self:ShowProperties(not self.propertiesOpen) end))
	self.janitor:Add(propertyClose.Activated:Connect(function() self:ShowProperties(false) end))
	self.janitor:Add(self.propertyFloat.Activated:Connect(function()
		self.floatingProperties = not self.floatingProperties
		self.floatGrip.Visible = self.floatingProperties
		if self.floatingProperties then
			self.propertyFrame.Parent = self.gui
			self.propertyFrame.ZIndex = 4
			self.propertyFrame.Position = UDim2.fromOffset(math.max(0, self.gui.AbsoluteSize.X - self.dockWidth * 2 - 12), 32)
			self.propertyFrame.Size = UDim2.fromOffset(self.dockWidth, math.min(460, self.gui.AbsoluteSize.Y - 32))
		else
			self.propertyFrame.Parent = self.frame
			self.propertyFrame.ZIndex = 1
		end
		self:Clamp()
		self.propertyFrame.GroupTransparency = 1
		self.motion:To(self.propertyFrame, { GroupTransparency = 0 }, 0.25)
	end))
	self.janitor:Add(self.propertiesAction.Activated:Connect(function() self:ShowProperties(true) end))
	self.janitor:Add(Input.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local point = Input:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
			local position, size = self.menu.AbsolutePosition, self.menu.AbsoluteSize
			if point.X < position.X or point.Y < position.Y or point.X > position.X + size.X or point.Y > position.Y + size.Y then self:CloseMenu() end
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
		else self.ratio = math.clamp(original + delta.Y / math.max(1, self.frame.AbsoluteSize.Y), 0.25, 0.8) end
		self:Clamp()
	end))
	self.janitor:Add(self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Clamp() end))
	self.janitor:Add(self.propertyAmount.Changed:Connect(function() self:Clamp() end))
	task.defer(function() if self.gui.Parent then self:Clamp() end end)
	return self
end

function Window:ShowPath()
	self.showingPath, self.path.Visible = true, true
	self.inspector.Position, self.inspector.Size = UDim2.fromOffset(1, 68), UDim2.new(1, -2, 1, -69)
end

function Window:ShowProperties(show)
	self.propertiesOpen = show
	self.propertyFrame.Visible = self.shown
	self.motion:To(self.propertyAmount, { Value = show and 1 or 0 }, 0.32, Enum.EasingStyle.Quint, function()
		self.propertyFrame.Visible = show and self.shown
	end)
end

function Window:CloseMenu()
	if not self.menu.Visible then return end
	self.motion:To(self.menu, { GroupTransparency = 1 }, 0.12, nil, function() self.menu.Visible = false end)
end

function Window:OpenMenu()
	local point = Input:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
	local bounds = self.gui.AbsoluteSize
	local position = UDim2.fromOffset(math.clamp(point.X, 0, math.max(0, bounds.X - 202)), math.clamp(point.Y, 0, math.max(0, bounds.Y - 176)))
	self.menu.Position = position + UDim2.fromOffset(0, 8)
	self.menu.GroupTransparency = 1
	self.menu.Visible = true
	self.motion:To(self.menu, { Position = position, GroupTransparency = 0 }, 0.19, Enum.EasingStyle.Quint)
end

function Window:Clamp()
	local bounds = self.gui.AbsoluteSize
	if bounds.X == 0 or bounds.Y == 0 then return end
	self.dockWidth = math.clamp(self.dockWidth, math.min(240, bounds.X), math.min(760, bounds.X))
	local height = math.max(0, bounds.Y - Config.DockTop)
	self.basePosition = UDim2.new(1, -self.dockWidth, 0, Config.DockTop)
	if not self.motion:Busy(self.frame) then self.frame.Position = self.shown and self.basePosition or UDim2.new(1, 16, 0, Config.DockTop) end
	self.frame.Size = UDim2.new(0, self.dockWidth, 1, -Config.DockTop)
	local amount = self.floatingProperties and 0 or self.propertyAmount.Value
	local split = math.floor(height * (1 - (1 - self.ratio) * amount))
	if not self.floatingProperties then self.propertyFrame.GroupTransparency = 1 - self.propertyAmount.Value end
	self.explorerBody.Size = UDim2.new(1, 0, 0, math.max(0, split - 2))
	self.tree.Size = UDim2.new(1, -2, 1, -44)
	self.status.Position, self.status.Size = UDim2.new(0, 6, 1, -22), UDim2.new(1, -12, 0, 20)
	self.splitGrip.Visible = amount > 0.01 and not self.floatingProperties
	self.splitGrip.Position = UDim2.fromOffset(0, split - 2)
	if not self.floatingProperties then
		self.propertyFrame.Position = UDim2.fromOffset(0, split + 2)
		self.propertyFrame.Size = UDim2.new(1, 0, 0, math.max(0, height - split - 2))
	end
end

function Window:SetShown(show, entrance)
	self.shown = show
	self.hide.Visible, self.restore.Visible = show, not show
	self:CloseMenu()
	if show then
		self.frame.Visible = true
		self.propertyFrame.Visible = self.propertiesOpen
		if entrance then self.frame.Position, self.frame.GroupTransparency = UDim2.new(1, 16, 0, Config.DockTop), 1 end
		self.motion:To(self.frame, { Position = self.basePosition, GroupTransparency = 0 }, entrance and 0.52 or 0.36, Enum.EasingStyle.Quint)
		if self.floatingProperties and self.propertiesOpen then
			self.propertyFrame.Visible = true
			self.motion:To(self.propertyFrame, { GroupTransparency = 0 }, 0.3)
		end
	else
		self.motion:To(self.frame, { Position = UDim2.new(1, 16, 0, Config.DockTop), GroupTransparency = 1 }, 0.28, Enum.EasingStyle.Quart, function() self.frame.Visible = false end)
		if self.floatingProperties then self.motion:To(self.propertyFrame, { GroupTransparency = 1 }, 0.2, nil, function() self.propertyFrame.Visible = false end) end
	end
	if self.onToggle then self.onToggle(show) end
end

function Window:Enter()
	self:Clamp()
	self.entered = true
	self:SetShown(true, true)
end

function Window:Toggle()
	self:SetShown(not self.shown)
end

function Window:SetStatus(message, isError)
	self.status.Text = message
	self.status.Visible = isError == true
end

function Window:Destroy()
	self.motion:Destroy()
	self.janitor:Destroy()
	self.gui:Destroy()
end

return Window
