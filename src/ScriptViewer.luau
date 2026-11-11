local UI = require(script.Parent.UI)
local Config = require(script.Parent.Config)
local Janitor = require(script.Parent.Janitor)
local Reader = require(script.Parent.SourceReader)
local Viewer = {}
Viewer.__index = Viewer

function Viewer.new(parent, dock)
	local self = setmetatable({ janitor = Janitor.new(), reader = Reader.new(), dock = dock, dead = false, text = "", request = 0 }, Viewer)
	self.frame = UI.frame(parent, { Name = "ScriptViewer", Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -Config.DockWidth - 24, 1, -24), Visible = false, ClipsDescendants = true, ZIndex = 5, BorderSizePixel = 1, BorderColor3 = Config.Colors.Border })
	local header = UI.frame(self.frame, { Name = "SourceTab", Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Color3.fromRGB(53, 53, 53) })
	self.title = UI.text(header, "Script", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -208, 1, 0), TextSize = 15 })
	self.copy = UI.button(header, "Copy", { Position = UDim2.new(1, -192, 0, 3), Size = UDim2.fromOffset(58, 26) })
	self.reload = UI.button(header, "Reload", { Position = UDim2.new(1, -130, 0, 3), Size = UDim2.fromOffset(62, 26) })
	self.close = UI.button(header, "×", { Position = UDim2.new(1, -34, 0, 3), Size = UDim2.fromOffset(30, 26), BackgroundTransparency = 1 })
	self.path = UI.text(self.frame, "", { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 24), TextColor3 = Config.Colors.Muted, TextSize = 12 })
	self.scroll = UI.scroll(self.frame, { Position = UDim2.fromOffset(1, 62), Size = UDim2.new(1, -2, 1, -88), ScrollingDirection = Enum.ScrollingDirection.XY, ScrollBarThickness = 7 })
	self.gutter = UI.text(self.scroll, "", { Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(54, 0), Font = Enum.Font.Code, TextSize = 14, TextColor3 = Config.Colors.Muted, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.None })
	self.code = UI.new("TextBox", { Name = "Source", Position = UDim2.fromOffset(70, 8), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", TextEditable = false, ClearTextOnFocus = false, MultiLine = true, TextWrapped = false, Font = Enum.Font.Code, TextSize = 14, TextColor3 = Color3.fromRGB(220, 225, 233), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, self.scroll)
	self.status = UI.text(self.frame, "", { Position = UDim2.new(0, 12, 1, -24), Size = UDim2.new(1, -24, 0, 22), TextSize = 12, TextColor3 = Config.Colors.Muted })
	self.janitor:Add(self.close.Activated:Connect(function() self:Hide() end))
	self.janitor:Add(self.reload.Activated:Connect(function() if self.item then self:Open(self.item, true) end end))
	self.janitor:Add(self.copy.Activated:Connect(function()
		local clipboard = setclipboard or toclipboard
		if type(clipboard) == "function" then
			local ok, message = pcall(clipboard, self.text)
			self.status.Text = ok and "Source copied" or tostring(message)
		else
			self.code:CaptureFocus()
			self.code.SelectionStart, self.code.CursorPosition = 1, #self.code.Text + 1
			self.status.Text = "Press Ctrl+C to copy"
		end
	end))
	self.janitor:Add(parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Layout() end))
	self.janitor:Add(dock:GetPropertyChangedSignal("Size"):Connect(function() self:Layout() end))
	self:Layout()
	return self
end

function Viewer:Layout()
	local bounds = self.frame.Parent.AbsoluteSize
	local available = bounds.X - self.dock.AbsoluteSize.X - 24
	if available < 300 then available = bounds.X - 24 end
	self.frame.Size = UDim2.fromOffset(math.max(100, available), math.max(100, bounds.Y - 24))
end

function Viewer:SetText(text)
	self.text = text
	local visible = string.sub(text, 1, Config.MaxSourceBytes)
	local lines, width = {}, 0
	local line = 0
	for value in string.gmatch(visible .. "\n", "(.-)\n") do
		line += 1
		table.insert(lines, tostring(line))
		width = math.max(width, #string.gsub(value, "\t", "    "))
	end
	self.gutter.Text = table.concat(lines, "\n")
	self.code.Text = visible
	local height = math.max(40, #lines * 14 + 20)
	local pixels = math.max(200, width * 9 + 40)
	self.code.Size = UDim2.fromOffset(pixels, height)
	self.gutter.Size = UDim2.fromOffset(54, height)
	self.scroll.CanvasSize = UDim2.fromOffset(pixels + 90, height + 16)
	self.scroll.CanvasPosition = Vector2.zero
	return #text > #visible
end

function Viewer:Open(item, refresh)
	self.request += 1
	local request = self.request
	self.item = item
	self.frame.Visible = true
	self.title.Text = item and item.Name or "Script"
	self.path.Text = item and item:GetFullName() or ""
	self.status.Text = "Reading script..."
	self:SetText("")
	self.reader:Read(item, function(source, message)
		if self.dead or request ~= self.request then return end
		if not source then self:SetText(message); self.status.Text = "Source unavailable"; return end
		local truncated = self:SetText(source)
		self.status.Text = message .. "  |  " .. tostring(#source) .. " bytes" .. (truncated and "  |  Display limited; Copy keeps full source" or "")
	end, refresh)
end

function Viewer:Hide()
	self.frame.Visible = false
	self.request += 1
	self.reader:Cancel()
end

function Viewer:Destroy()
	self.dead = true
	self.reader:Destroy()
	self.janitor:Destroy()
	self.frame:Destroy()
end

return Viewer
