local UI = require(script.Parent.UI)
local Config = require(script.Parent.Config)
local Codec = require(script.Parent.ValueCodec)
local Catalog = require(script.Parent.PropertyCatalog)
local Janitor = require(script.Parent.Janitor)
local Inspector = {}
Inspector.__index = Inspector

function Inspector.new(parent, status, filter)
	local self = setmetatable({ janitor = Janitor.new(), rowsJanitor = Janitor.new(), menuJanitor = Janitor.new(), status = status, query = "", collapsed = {} }, Inspector)
	self.scroll = UI.scroll(parent, { Name = "Properties", Size = UDim2.fromScale(1, 1), AutomaticCanvasSize = Enum.AutomaticSize.Y })
	UI.new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, self.scroll)
	UI.new("UIPadding", { PaddingBottom = UDim.new(0, 8) }, self.scroll)
	if filter then
		self.janitor:Add(filter:GetPropertyChangedSignal("Text"):Connect(function()
			self.query = string.lower(filter.Text)
			self:Select(self.item)
		end))
	end
	self:Select(nil)
	return self
end

function Inspector:CloseMenu()
	self.menuJanitor:Destroy()
	if self.enumMenu then self.enumMenu:Destroy(); self.enumMenu = nil end
end

function Inspector:Clear()
	self:CloseMenu()
	self.rowsJanitor:Destroy()
	for _, child in self.scroll:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	self.order = 0
end

function Inspector:Heading(text, collapsible)
	self.order += 1
	local heading = UI.button(self.scroll, (collapsible and (self.collapsed[text] and "▶  " or "▼  ") or "") .. text, {
		Name = "Category", Size = UDim2.new(1, -10, 0, 22), LayoutOrder = self.order,
		BackgroundColor3 = Color3.fromRGB(53, 53, 53), BackgroundTransparency = 0.5, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.SourceSansSemibold,
	})
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, heading)
	if collapsible then
		self.rowsJanitor:Add(heading.Activated:Connect(function()
			self.collapsed[text] = not self.collapsed[text]
			self:Select(self.item, true)
		end))
	end
end

function Inspector:EnumMenu(value, commit)
	self:CloseMenu()
	local host = self.scroll.Parent
	local menu = UI.scroll(host, {
		Name = "EnumChoices", Position = UDim2.new(0.42, 0, 0, 0), Size = UDim2.new(0.58, -8, 1, -4),
		BackgroundTransparency = 0, BackgroundColor3 = Config.Colors.Input, ZIndex = 12,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 1, BorderColor3 = Config.Colors.Border,
	})
	self.enumMenu = menu
	UI.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, menu)
	local choices = value.EnumType:GetEnumItems()
	for index, choice in choices do
		local button = UI.button(menu, choice.Name, { Size = UDim2.new(1, -6, 0, 24), LayoutOrder = index, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, BackgroundColor3 = choice == value and Config.Colors.Selected or Config.Colors.Input })
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, button)
		self.menuJanitor:Add(button.Activated:Connect(function() commit(choice.Name); self:CloseMenu() end))
	end
end

function Inspector:AddRow(item, definition, attribute)
	local name, readonly = definition[1], definition[3]
	local function read()
		if attribute then return item:GetAttribute(name) end
		return item[name]
	end
	local success, value = pcall(read)
	if not success then return end
	self.order += 1
	local row = UI.frame(self.scroll, { Name = name, Size = UDim2.new(1, -10, 0, 22), LayoutOrder = self.order, BackgroundTransparency = self.order % 2 == 0 and 0.65 or 0.85, BackgroundColor3 = Config.Colors.Panel })
	UI.text(row, name, { Position = UDim2.fromOffset(24, 0), Size = UDim2.new(0.34, -26, 1, 0), TextColor3 = readonly and Color3.fromRGB(116, 116, 116) or Config.Colors.Text })
	UI.frame(row, { Position = UDim2.new(0.34, -2, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Color3.fromRGB(32, 32, 32), BackgroundTransparency = 0.4 })
	local editable = not readonly and Codec.editable(value)
	local input, checkbox, swatch
	if typeof(value) == "boolean" and editable then
		checkbox = UI.button(row, value and "✓" or "", { Name = "Checkbox", Position = UDim2.new(0.34, 6, 0, 3), Size = UDim2.fromOffset(16, 16), TextSize = 15, TextColor3 = Config.Colors.Accent, BorderSizePixel = 1, BorderColor3 = Color3.fromRGB(30, 30, 30) })
	else
		input = UI.input(row, "", { Name = "Value", Position = UDim2.fromScale(0.34, 0), Size = UDim2.new(0.66, 0, 1, 0), Text = value == nil and "" or Codec.format(value), TextEditable = editable, BackgroundTransparency = 1, TextColor3 = editable and Config.Colors.Text or Color3.fromRGB(116, 116, 116) })
		if typeof(value) == "Color3" then
			swatch = UI.frame(row, { Position = UDim2.new(1, -22, 0, 5), Size = UDim2.fromOffset(16, 15), BackgroundColor3 = value, BorderSizePixel = 1, BorderColor3 = Config.Colors.Muted })
			input.Size = UDim2.new(0.66, -26, 1, 0)
		end
	end
	local function update()
		if input and input:IsFocused() then return end
		local ok, current = pcall(read)
		if not ok then return end
		if checkbox then checkbox.Text = current and "✓" or "" end
		if input then input.Text = current == nil and "" or Codec.format(current) end
		if swatch and typeof(current) == "Color3" then swatch.BackgroundColor3 = current end
	end
	local function commit(text)
		local ok, reason = pcall(function()
			local previous = read()
			if text == Codec.format(previous) then return end
			local parsed = Codec.parse(text, previous)
			if attribute then item:SetAttribute(name, parsed) else item[name] = parsed end
		end)
		self.status(ok and ("Updated " .. name .. " (client)") or tostring(reason), not ok)
		update()
	end
	local ok, signal = pcall(function() return attribute and item:GetAttributeChangedSignal(name) or item:GetPropertyChangedSignal(name) end)
	if ok then self.rowsJanitor:Add(signal:Connect(update)) end
	if editable then
		if checkbox then
			self.rowsJanitor:Add(checkbox.Activated:Connect(function() commit(tostring(not read())) end))
		else
			self.rowsJanitor:Add(input.FocusLost:Connect(function() commit(input.Text) end))
			if typeof(value) == "EnumItem" then
				input.Size = UDim2.new(0.66, -23, 1, 0)
				local picker = UI.button(row, "▾", { Position = UDim2.new(1, -23, 0, 0), Size = UDim2.fromOffset(22, 25), BackgroundTransparency = 1 })
				self.rowsJanitor:Add(picker.Activated:Connect(function()
					if self.enumMenu then self:CloseMenu() else self:EnumMenu(read(), commit) end
				end))
			end
		end
	end
end

function Inspector:AddAttributeButton(item)
	self.order += 1
	local row = UI.frame(self.scroll, { Name = "AddAttribute", Size = UDim2.new(1, -10, 0, 22), LayoutOrder = self.order, BackgroundTransparency = 1 })
	local open = UI.button(row, "Add Attribute", { Name = "Open", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.6 })
	self.rowsJanitor:Add(open.Activated:Connect(function()
		if row:FindFirstChild("AttributeName") then return end
		open.Visible = false
		row.Size = UDim2.new(1, -10, 0, 78)
		local name = UI.input(row, "Attribute name", { Name = "AttributeName", Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -8, 0, 22) })
		local value = UI.input(row, "Value", { Name = "AttributeValue", Position = UDim2.fromOffset(4, 26), Size = UDim2.new(0.65, -6, 0, 22) })
		local kinds, index = { "String", "Number", "Boolean" }, 1
		local kind = UI.button(row, "String ▾", { Name = "AttributeType", Position = UDim2.new(0.65, 0, 0, 26), Size = UDim2.new(0.35, -4, 0, 22) })
		local create = UI.button(row, "Create Attribute", { Name = "Create", Position = UDim2.fromOffset(4, 52), Size = UDim2.new(1, -8, 0, 22) })
		self.rowsJanitor:Add(kind.Activated:Connect(function() index = index % #kinds + 1; kind.Text = kinds[index] .. " ▾" end))
		self.rowsJanitor:Add(create.Activated:Connect(function()
			local ok, reason = pcall(function()
				assert(name.Text ~= "", "Enter an attribute name")
				assert(item:GetAttribute(name.Text) == nil, "An attribute with this name already exists")
				local parsed = value.Text
				if index == 2 then parsed = Codec.parse(value.Text, 0)
				elseif index == 3 then parsed = Codec.parse(value.Text, false) end
				item:SetAttribute(name.Text, parsed)
			end)
			self.status(ok and "Attribute created" or tostring(reason), not ok)
		end))
		name:CaptureFocus()
	end))
end

function Inspector:Select(item, preserve)
	local previousPosition = self.scroll.CanvasPosition
	self:Clear()
	self.item = item
	self.scroll.CanvasPosition = preserve and previousPosition or Vector2.zero
	if not item then return end
	local properties = Catalog.Get(item)
	local category, show = nil, false
	for _, definition in properties do
		local name, group = definition[1], definition[2]
		if self.query ~= "" and not string.find(string.lower(name .. " " .. group), self.query, 1, true) then continue end
		if category ~= group then
			category = group
			self:Heading(group, true)
			show = not self.collapsed[group] or self.query ~= ""
		end
		if show then self:AddRow(item, definition, false) end
	end
	local names, attributes = {}, item:GetAttributes()
	for name in attributes do table.insert(names, name) end
	table.sort(names)
	if self.query == "" or string.find("attributes", self.query, 1, true) or #names > 0 then
		self:Heading("Attributes", true)
		if not self.collapsed.Attributes or self.query ~= "" then
			for _, name in names do
				if self.query == "" or string.find(string.lower(name .. " attributes"), self.query, 1, true) then self:AddRow(item, { name, "Attributes", false }, true) end
			end
			if self.query == "" then self:AddAttributeButton(item) end
		end
	end
	self.rowsJanitor:Add(item.AttributeChanged:Connect(function()
		local current, count = item:GetAttributes(), 0
		for _ in current do count += 1 end
		local same = count == #names
		for _, name in names do if current[name] == nil then same = false end end
		if not same and not self.rebuildPending then
			self.rebuildPending = true
			task.defer(function()
				self.rebuildPending = false
				if self.item == item then self:Select(item, true) end
			end)
		end
	end))
end

function Inspector:Destroy()
	self.item = nil
	self:Clear()
	self.janitor:Destroy()
	self.scroll:Destroy()
end

return Inspector
