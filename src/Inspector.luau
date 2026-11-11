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
		Name = "Category", Size = UDim2.new(1, -6, 0, 25), LayoutOrder = self.order,
		BackgroundColor3 = Color3.fromRGB(53, 53, 53), TextXAlignment = Enum.TextXAlignment.Left,
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
	local row = UI.frame(self.scroll, { Name = name, Size = UDim2.new(1, -6, 0, 25), LayoutOrder = self.order, BackgroundColor3 = self.order % 2 == 0 and Config.Colors.Panel or Color3.fromRGB(42, 42, 42) })
	UI.text(row, name, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.44, -14, 1, 0), TextColor3 = readonly and Config.Colors.Muted or Config.Colors.Text })
	UI.frame(row, { Position = UDim2.new(0.44, -2, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Config.Colors.Border })
	local editable = not readonly and Codec.editable(value)
	local input, checkbox, swatch
	if typeof(value) == "boolean" and editable then
		checkbox = UI.button(row, value and "✓" or "", { Name = "Checkbox", Position = UDim2.new(0.44, 6, 0, 4), Size = UDim2.fromOffset(17, 17), TextSize = 15, BorderSizePixel = 1, BorderColor3 = Config.Colors.Muted })
	else
		input = UI.input(row, "nil", { Name = "Value", Position = UDim2.fromScale(0.44, 0), Size = UDim2.new(0.56, 0, 1, 0), Text = value == nil and "nil" or Codec.format(value), TextEditable = editable, BackgroundTransparency = 1, TextColor3 = editable and Config.Colors.Text or Config.Colors.Muted })
		if typeof(value) == "Color3" then
			swatch = UI.frame(row, { Position = UDim2.new(1, -22, 0, 5), Size = UDim2.fromOffset(16, 15), BackgroundColor3 = value, BorderSizePixel = 1, BorderColor3 = Config.Colors.Muted })
			input.Size = UDim2.new(0.56, -26, 1, 0)
		end
	end
	local function update()
		if input and input:IsFocused() then return end
		local ok, current = pcall(read)
		if not ok then return end
		if checkbox then checkbox.Text = current and "✓" or "" end
		if input then input.Text = current == nil and "nil" or Codec.format(current) end
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
				input.Size = UDim2.new(0.56, -23, 1, 0)
				local picker = UI.button(row, "▾", { Position = UDim2.new(1, -23, 0, 0), Size = UDim2.fromOffset(22, 25), BackgroundTransparency = 1 })
				self.rowsJanitor:Add(picker.Activated:Connect(function()
					if self.enumMenu then self:CloseMenu() else self:EnumMenu(read(), commit) end
				end))
			end
		end
	end
end

function Inspector:Select(item, preserve)
	local previousPosition = self.scroll.CanvasPosition
	self:Clear()
	self.item = item
	self.scroll.CanvasPosition = preserve and previousPosition or Vector2.zero
	if not item then self:Heading("Select an instance to view properties"); return end
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
