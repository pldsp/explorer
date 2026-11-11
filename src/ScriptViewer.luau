local UI = require(script.Parent.UI)
local Config = require(script.Parent.Config)
local Janitor = require(script.Parent.Janitor)
local Reader = require(script.Parent.SourceReader)
local Document = require(script.Parent.SourceDocument)
local Syntax = require(script.Parent.Syntax)
local Drag = require(script.Parent.Drag)
local Viewer = {}
Viewer.__index = Viewer
local lineHeight, charWidth = 16, 7

function Viewer.new(parent, dock)
	local self = setmetatable({ janitor = Janitor.new(), reader = Reader.new(), dock = dock, dead = false, text = "", request = 0, textVersion = 0, pool = {}, document = Document.new("") }, Viewer)
	self.frame = UI.frame(parent, { Name = "ScriptViewer", Position = UDim2.new(0.5, -300, 0.5, -210), Size = UDim2.fromOffset(600, 420), Visible = false, ClipsDescendants = true, ZIndex = 5, BackgroundTransparency = Config.PanelTransparency, BorderSizePixel = 1, BorderColor3 = Color3.fromRGB(32, 32, 32) })
	local header = UI.frame(self.frame, { Name = "SourceTab", Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(51, 51, 51), Active = true })
	self.title = UI.text(header, "Notepad", { Position = UDim2.fromOffset(5, 0), Size = UDim2.new(1, -48, 1, 0) })
	self.minimize = UI.button(header, "−", { Position = UDim2.new(1, -34, 0, 0), Size = UDim2.fromOffset(16, 20), BackgroundTransparency = 1 })
	self.close = UI.button(header, "×", { Position = UDim2.new(1, -18, 0, 0), Size = UDim2.fromOffset(18, 20), BackgroundTransparency = 1, TextSize = 16 })
	local toolbar = UI.frame(self.frame, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 21), BackgroundTransparency = 0.5 })
	self.copy = UI.button(toolbar, "Copy to Clipboard", { Size = UDim2.new(1 / 3, 0, 1, 0), BackgroundTransparency = 1 })
	self.save = UI.button(toolbar, "Save to File", { Position = UDim2.fromScale(1 / 3, 0), Size = UDim2.new(1 / 3, 0, 1, 0), BackgroundTransparency = 1 })
	self.reload = UI.button(toolbar, "Reload Source", { Position = UDim2.fromScale(2 / 3, 0), Size = UDim2.new(1 / 3, 0, 1, 0), BackgroundTransparency = 1 })
	self.path = UI.text(self.frame, "", { Visible = false })
	local body = UI.frame(self.frame, { Name = "CodeBody", Position = UDim2.fromOffset(1, 42), Size = UDim2.new(1, -2, 1, -64), BackgroundTransparency = 1, ClipsDescendants = true })
	self.gutter = UI.frame(body, { Name = "LineNumbers", Size = UDim2.new(0, 48, 1, -8), BackgroundTransparency = 1, ClipsDescendants = true })
	self.scroll = UI.scroll(body, { Name = "SourceViewport", Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -54, 1, 0), ScrollingDirection = Enum.ScrollingDirection.XY, ScrollBarThickness = 10, ScrollBarImageColor3 = Color3.fromRGB(95, 95, 95) })
	self.status = UI.text(self.frame, "", { Position = UDim2.new(0, 6, 1, -21), Size = UDim2.new(1, -90, 0, 20), TextSize = 11, TextColor3 = Config.Colors.Muted })
	self.clear = UI.button(self.frame, "Clear", { Position = UDim2.new(1, -80, 1, -21), Size = UDim2.fromOffset(62, 20), BackgroundTransparency = 1 })
	local grip = UI.button(self.frame, "◢", { Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1 })
	Drag.Attach(self.frame, header, grip, self.janitor, parent)
	self.janitor:Add(self.close.Activated:Connect(function() self:Hide() end))
	self.janitor:Add(self.minimize.Activated:Connect(function() self:Hide() end))
	self.janitor:Add(self.reload.Activated:Connect(function() if self.item then self:Open(self.item, true) end end))
	self.janitor:Add(self.clear.Activated:Connect(function()
		self.request += 1
		self.reader:Cancel()
		self:SetText("")
		self.status.Text = ""
	end))
	self.janitor:Add(self.copy.Activated:Connect(function()
		local clipboard = setclipboard or toclipboard
		if type(clipboard) ~= "function" then self.status.Text = "Clipboard unavailable; use Save to File if supported"; return end
		local ok, message = pcall(clipboard, self.text)
		self.status.Text = ok and "Full source copied" or tostring(message)
	end))
	self.janitor:Add(self.save.Activated:Connect(function()
		if type(writefile) ~= "function" then self.status.Text = "This executor does not provide writefile"; return end
		local name = "Explorer_" .. string.gsub(self.item and self.item.Name or "Script", "[^%w_%-%.]", "_") .. ".luau"
		local ok, reason = pcall(writefile, name, self.text)
		self.status.Text = ok and ("Saved full source to " .. name) or tostring(reason)
	end))
	self.janitor:Add(self.scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:Render() end))
	self.janitor:Add(self.scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Render() end))
	self.janitor:Add(self.frame:GetPropertyChangedSignal("Size"):Connect(function() self:Render() end))
	self.janitor:Add(parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Layout() end))
	self:Layout()
	return self
end

function Viewer:Layout()
	local bounds = self.frame.Parent.AbsoluteSize
	local size = self.frame.Size
	local width, height = math.min(size.X.Offset, bounds.X), math.min(size.Y.Offset, bounds.Y)
	self.frame.Size = UDim2.fromOffset(width, height)
	local position = self.frame.Position
	self.frame.Position = UDim2.fromOffset(math.clamp(bounds.X * position.X.Scale + position.X.Offset, 0, math.max(0, bounds.X - width)), math.clamp(bounds.Y * position.Y.Scale + position.Y.Offset, 0, math.max(0, bounds.Y - height)))
	self:Render()
end

function Viewer:Render()
	if self.dead or not self.document then return end
	local offset = self.scroll.CanvasPosition
	local first = math.max(1, math.floor(offset.Y / lineHeight) + 1)
	local column = math.max(0, math.floor(offset.X / charWidth))
	local columns = math.ceil(self.scroll.AbsoluteSize.X / charWidth) + 3
	local count = math.ceil(self.scroll.AbsoluteSize.Y / lineHeight) + 2
	for slot = 1, count do
		local widget = self.pool[slot]
		if not widget then
			local props = { BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.None }
			local code = UI.text(self.scroll, "", props)
			code.Name, code.RichText = "CodeLine", true
			local number = UI.text(self.gutter, "", props)
			number.TextXAlignment, number.TextColor3 = Enum.TextXAlignment.Right, Color3.fromRGB(190, 190, 190)
			widget = { code = code, number = number }
			self.pool[slot] = widget
		end
		local row = first + slot - 1
		local visible = row <= #self.document.starts
		widget.code.Visible, widget.number.Visible = visible, visible
		if visible then
			local text = self.document:Slice(row, column, columns)
			widget.code.Position = UDim2.fromOffset(column * charWidth, (row - 1) * lineHeight + 4)
			widget.code.Size = UDim2.fromOffset(columns * charWidth + 8, lineHeight)
			if widget.raw ~= text then widget.code.Text = Syntax.Highlight(text); widget.raw = text end
			widget.number.Position = UDim2.fromOffset(0, (row - 1) * lineHeight - offset.Y + 4)
			widget.number.Size = UDim2.fromOffset(44, lineHeight)
			widget.number.Text = tostring(row)
			widget.row = row
		end
	end
	for slot = count + 1, #self.pool do self.pool[slot].code.Visible, self.pool[slot].number.Visible = false, false end
end

function Viewer:SetText(text)
	self.textVersion += 1
	local version = self.textVersion
	self.text = text
	local document = Document.new(text, function() return self.dead or version ~= self.textVersion end)
	if not document or self.dead or version ~= self.textVersion then return false end
	self.document = document
	self.scroll.CanvasSize = UDim2.fromOffset(document.longest * charWidth + 20, #document.starts * lineHeight + 12)
	self.scroll.CanvasPosition = Vector2.zero
	self:Render()
	return true
end

function Viewer:Open(item, refresh)
	self.request += 1
	local request = self.request
	self.item = item
	self.frame.Visible = true
	self.path.Text = item and item:GetFullName() or ""
	self.status.Text = "Reading script..."
	self:SetText("")
	self.reader:Read(item, function(source, message)
		if self.dead or request ~= self.request then return end
		if not source then self:SetText(message); self.status.Text = "Source unavailable"; return end
		self.status.Text = "Indexing full source..."
		if self:SetText(source) and request == self.request then
			self.status.Text = message .. "  |  " .. tostring(#source) .. " bytes  |  " .. tostring(#self.document.starts) .. " lines"
		end
	end, refresh)
end

function Viewer:Hide()
	self.frame.Visible = false
	self.request += 1
	self.textVersion += 1
	self.reader:Cancel()
end

function Viewer:Destroy()
	self.dead = true
	self.textVersion += 1
	self.reader:Destroy()
	self.janitor:Destroy()
	self.frame:Destroy()
	table.clear(self.pool)
	self.text, self.document = "", nil
end

return Viewer
