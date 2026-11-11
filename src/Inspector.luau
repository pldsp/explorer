local UI = require(script.Parent.UI)
local Config = require(script.Parent.Config)
local Codec = require(script.Parent.ValueCodec)
local Schema = require(script.Parent.PropertySchema)
local Janitor = require(script.Parent.Janitor)
local Inspector = {}
Inspector.__index = Inspector

function Inspector.new(parent, status)
	local self = setmetatable({ janitor = Janitor.new(), status = status }, Inspector)
	self.scroll = UI.scroll(parent, { Name = "Properties", Size = UDim2.fromScale(1, 1), AutomaticCanvasSize = Enum.AutomaticSize.Y })
	UI.new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, self.scroll)
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, self.scroll)
	self:Select(nil)
	return self
end

function Inspector:Clear()
	self.janitor:Destroy()
	for _, child in self.scroll:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	self.order = 0
end

function Inspector:Heading(text)
	self.order += 1
	UI.text(self.scroll, text, { Size = UDim2.new(1, -6, 0, 23), LayoutOrder = self.order, TextColor3 = Config.Colors.Accent })
end

function Inspector:AddRow(item, name, attribute)
	local function read()
		if attribute then return item:GetAttribute(name) end
		return item[name]
	end
	local success, value = pcall(read)
	if not success or value == nil then return end
	self.order += 1
	local row = UI.frame(self.scroll, { Size = UDim2.new(1, -6, 0, 23), BackgroundTransparency = 1, LayoutOrder = self.order })
	UI.text(row, name, { Size = UDim2.new(0.44, -4, 1, 0), TextColor3 = Config.Colors.Muted })
	local editable = Codec.editable(value) and (attribute or (name ~= "ClassName" and name ~= "Source" and name ~= "IsPlaying"))
	local input = UI.input(row, "", {
		Position = UDim2.fromScale(0.44, 0), Size = UDim2.new(0.56, 0, 1, 0),
		Text = Codec.format(value), TextEditable = editable,
		TextColor3 = editable and Config.Colors.Text or Config.Colors.Muted,
	})
	local function update()
		if input:IsFocused() then return end
		local ok, current = pcall(read)
		if ok then input.Text = Codec.format(current) end
	end
	local signal = attribute and item:GetAttributeChangedSignal(name) or item:GetPropertyChangedSignal(name)
	self.janitor:Add(signal:Connect(update))
	if editable then
		self.janitor:Add(input.FocusLost:Connect(function()
			local ok, err = pcall(function()
				local previous = read()
				if input.Text == Codec.format(previous) then return end
				local parsed = Codec.parse(input.Text, previous)
				if attribute then item:SetAttribute(name, parsed) else item[name] = parsed end
			end)
			self.status(ok and ("Updated " .. name .. " (client)") or tostring(err), not ok)
			update()
		end))
	end
end

function Inspector:Select(item)
	self:Clear()
	self.item = item
	self.scroll.CanvasPosition = Vector2.zero
	if not item then self:Heading("Select an instance"); return end
	self:Heading(item.ClassName .. " / PROPERTIES")
	local seen = {}
	for _, group in Schema do
		if not item:IsA(group[1]) then continue end
		for _, name in group[2] do
			if not seen[name] then
				seen[name] = true
				self:AddRow(item, name, false)
			end
		end
	end
	self:Heading("ATTRIBUTES")
	local names = {}
	for name in item:GetAttributes() do table.insert(names, name) end
	table.sort(names)
	for _, name in names do self:AddRow(item, name, true) end
	if #names == 0 then self:Heading("No attributes") end
	self.janitor:Add(item.AttributeChanged:Connect(function()
		local current = item:GetAttributes()
		local count = 0
		for _ in current do count += 1 end
		local same = count == #names
		for _, name in names do if current[name] == nil then same = false end end
		if not same and not self.rebuildPending then
			self.rebuildPending = true
			task.defer(function()
				self.rebuildPending = false
				if self.item == item then self:Select(item) end
			end)
		end
	end))
end

function Inspector:Destroy()
	self.item = nil
	self.janitor:Destroy()
	self.scroll:Destroy()
end

return Inspector
