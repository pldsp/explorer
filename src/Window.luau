local UI = require(script.Parent.UI)
local Config = require(script.Parent.Config)
local Janitor = require(script.Parent.Janitor)
local Input = game:GetService("UserInputService")
local Window = {}
Window.__index = Window

function Window.new(parent)
	local self = setmetatable({ janitor = Janitor.new(), propertiesOpen = false }, Window)
	self.gui = UI.new("ScreenGui", {
		Name = "ExplorerPlus", ResetOnSpawn = false, DisplayOrder = 10000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false,
	}, parent)
	self.frame = UI.frame(self.gui, {
		Name = "Explorer", Position = UDim2.new(1, -Config.WindowSize.X - 8, 0, 8),
		Size = UDim2.fromOffset(Config.WindowSize.X, Config.WindowSize.Y), Active = true,
		ClipsDescendants = true, BorderSizePixel = 1, BorderColor3 = Config.Colors.Border,
	})
	local title = UI.frame(self.frame, {
		Name = "TitleBar", Size = UDim2.new(1, 0, 0, 21), Active = true,
		BackgroundColor3 = Color3.fromRGB(53, 53, 53), BorderSizePixel = 1, BorderColor3 = Config.Colors.Border,
	})
	UI.text(title, "Explorer", { Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -8, 1, 0), TextXAlignment = Enum.TextXAlignment.Center })
	self.hide = UI.button(title, "v", { Name = "Hide", Position = UDim2.new(1, -54, 0, 1), Size = UDim2.fromOffset(17, 19), BackgroundTransparency = 1 })
	self.properties = UI.button(title, "P", { Name = "Properties", Position = UDim2.new(1, -36, 0, 1), Size = UDim2.fromOffset(17, 19), BackgroundTransparency = 1 })
	self.close = UI.button(title, "x", { Name = "Close", Position = UDim2.new(1, -18, 0, 1), Size = UDim2.fromOffset(17, 19), BackgroundTransparency = 1 })
	local filter = UI.frame(self.frame, { Name = "FilterBar", Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 21), BackgroundColor3 = Config.Colors.Input })
	UI.text(filter, "⌕", { Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(17, 21) })
	self.search = UI.input(filter, "Filter workspace (Ctrl+Shift+X)", { Name = "Search", Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1 })
	self.tree = UI.frame(self.frame, { Name = "Tree", Position = UDim2.fromOffset(1, 44), Size = UDim2.new(1, -2, 1, -62) })
	self.status = UI.text(self.frame, "", { Position = UDim2.new(0, 4, 1, -17), Size = UDim2.new(1, -20, 0, 16), TextSize = 10, TextColor3 = Config.Colors.Muted })
	local grip = UI.button(self.frame, "◢", { Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, TextColor3 = Config.Colors.Muted })
	self.restore = UI.button(self.gui, "Explorer", { Position = UDim2.new(1, -86, 0, 8), Size = UDim2.fromOffset(78, 22), Visible = false })
	self.propertyFrame = UI.frame(self.gui, {
		Name = "Properties", Position = UDim2.new(1, -572, 0, 8), Size = UDim2.fromOffset(282, 500),
		Visible = false, Active = true, ClipsDescendants = true,
		BorderSizePixel = 1, BorderColor3 = Config.Colors.Border,
	})
	local propertyTitle = UI.frame(self.propertyFrame, { Size = UDim2.new(1, 0, 0, 21), Active = true, BackgroundColor3 = Color3.fromRGB(53, 53, 53) })
	UI.text(propertyTitle, "Properties", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	local propertyClose = UI.button(propertyTitle, "x", { Position = UDim2.new(1, -18, 0, 1), Size = UDim2.fromOffset(17, 19), BackgroundTransparency = 1 })
	self.path = UI.input(self.propertyFrame, "No selection", { Position = UDim2.fromOffset(3, 23), Size = UDim2.new(1, -6, 0, 22), TextEditable = false })
	self.inspector = UI.frame(self.propertyFrame, { Position = UDim2.fromOffset(1, 48), Size = UDim2.new(1, -2, 1, -49) })
	self.menu = UI.frame(self.gui, { Name = "ContextMenu", Size = UDim2.fromOffset(156, 126), Visible = false, ZIndex = 20, BorderSizePixel = 1, BorderColor3 = Config.Colors.Border })
	local actions = { { "propertiesAction", "Properties" }, { "focus", "Focus selection" }, { "reveal", "Reveal in Explorer" }, { "copy", "Copy path" }, { "refresh", "Refresh" } }
	for index, action in actions do
		self[action[1]] = UI.button(self.menu, action[2], { Name = action[1], Position = UDim2.fromOffset(2, (index - 1) * 24 + 3), Size = UDim2.new(1, -4, 0, 23), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, BackgroundTransparency = 1 })
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 9) }, self[action[1]])
		self.janitor:Add(self[action[1]].Activated:Connect(function() self.menu.Visible = false end))
	end
	self.janitor:Add(self.hide.Activated:Connect(function() self:Toggle() end))
	self.janitor:Add(self.restore.Activated:Connect(function() self:Toggle() end))
	self.janitor:Add(self.properties.Activated:Connect(function() self:ShowProperties(not self.propertiesOpen) end))
	self.janitor:Add(propertyClose.Activated:Connect(function() self:ShowProperties(false) end))
	self.janitor:Add(self.propertiesAction.Activated:Connect(function() self:ShowProperties(true) end))
	self.janitor:Add(Input.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local point, position, size = Input:GetMouseLocation(), self.menu.AbsolutePosition, self.menu.AbsoluteSize
			point -= game:GetService("GuiService"):GetGuiInset()
			if point.X < position.X or point.Y < position.Y or point.X > position.X + size.X or point.Y > position.Y + size.Y then self.menu.Visible = false end
		end
		if Input:GetFocusedTextBox() then return end
		if not processed and input.KeyCode == Config.ToggleKey then self:Toggle() end
		if input.KeyCode == Enum.KeyCode.X and (Input:IsKeyDown(Enum.KeyCode.LeftControl) or Input:IsKeyDown(Enum.KeyCode.RightControl)) and (Input:IsKeyDown(Enum.KeyCode.LeftShift) or Input:IsKeyDown(Enum.KeyCode.RightShift)) then
			self.frame.Visible, self.restore.Visible = true, false
			self.search:CaptureFocus()
		end
	end))
	local mode, origin, original, target, activeTouch
	local function begin(input, nextMode, frame)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		mode, origin, target = nextMode, input.Position, frame
		activeTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
		original = mode == "move" and target.Position or target.Size
	end
	self.janitor:Add(title.InputBegan:Connect(function(input) begin(input, "move", self.frame) end))
	self.janitor:Add(propertyTitle.InputBegan:Connect(function(input) begin(input, "move", self.propertyFrame) end))
	self.janitor:Add(grip.InputBegan:Connect(function(input) begin(input, "resize", self.frame) end))
	self.janitor:Add(Input.InputEnded:Connect(function(input)
		if input == activeTouch or input.UserInputType == Enum.UserInputType.MouseButton1 then mode = nil end
	end))
	self.janitor:Add(Input.InputChanged:Connect(function(input)
		if not mode then return end
		if activeTouch then if input ~= activeTouch then return end
		elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local delta = input.Position - origin
		if mode == "move" then
			target.Position = UDim2.new(original.X.Scale, original.X.Offset + delta.X, original.Y.Scale, original.Y.Offset + delta.Y)
		else
			target.Size = UDim2.fromOffset(math.max(220, original.X.Offset + delta.X), math.max(180, original.Y.Offset + delta.Y))
		end
		self:Clamp()
	end))
	self.janitor:Add(self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Clamp() end))
	task.defer(function() if self.gui.Parent then self:Clamp() end end)
	return self
end

function Window:ShowProperties(show)
	self.propertiesOpen = show
	self.propertyFrame.Visible = show and self.frame.Visible
end

function Window:OpenMenu()
	local point = Input:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
	local bounds = self.gui.AbsoluteSize
	self.menu.Position = UDim2.fromOffset(math.clamp(point.X, 0, math.max(0, bounds.X - 156)), math.clamp(point.Y, 0, math.max(0, bounds.Y - 126)))
	self.menu.Visible = true
end

function Window:Clamp()
	local bounds = self.gui.AbsoluteSize
	if bounds.X == 0 or bounds.Y == 0 then return end
	for _, frame in { self.frame, self.propertyFrame } do
		local size = frame.Size
		local width, height = math.min(size.X.Offset, bounds.X), math.min(size.Y.Offset, bounds.Y)
		frame.Size = UDim2.fromOffset(width, height)
		local position = frame.Position
		local x = bounds.X * position.X.Scale + position.X.Offset
		local y = bounds.Y * position.Y.Scale + position.Y.Offset
		frame.Position = UDim2.fromOffset(math.clamp(x, 0, math.max(0, bounds.X - width)), math.clamp(y, 0, math.max(0, bounds.Y - height)))
	end
end

function Window:Toggle()
	self.frame.Visible = not self.frame.Visible
	self.restore.Visible = not self.frame.Visible
	self.propertyFrame.Visible = self.frame.Visible and self.propertiesOpen
	self.menu.Visible = false
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
