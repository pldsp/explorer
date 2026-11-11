local Config = require(script.Parent.Config)
local UI = require(script.Parent.UI)
local Janitor = require(script.Parent.Janitor)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local View = {}
View.__index = View

function View.new(parent, selectInstance, toggle, context)
	local self = setmetatable({ rows = {}, pool = {}, janitor = Janitor.new(), motion = Motion.new(), selected = nil }, View)
	self.scroll = UI.scroll(parent, { Name = "InstanceTree", Size = UDim2.fromScale(1, 1), ScrollingDirection = Enum.ScrollingDirection.XY, ScrollBarThickness = 10, ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100) })
	self.selectInstance, self.toggle = selectInstance, toggle
	self.context = context
	self.janitor:Add(self.scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:Render() end))
	self.janitor:Add(self.scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Render() end))
	return self
end

function View:SetRows(rows, expanded)
	self.rows, self.expanded = rows, expanded
	local width = self.scroll.AbsoluteSize.X - 10
	for _, row in rows do width = math.max(width, row.depth * 18 + #row.instance.Name * 7 + 62) end
	self.contentWidth = width
	self.scroll.CanvasSize = UDim2.fromOffset(width, #rows * Config.RowHeight)
	self:Render()
end

function View:Select(item)
	self.selected = item
	self:Render()
end

function View:Reveal(item)
	for index, row in self.rows do
		if row.instance == item then
			self.scroll.CanvasPosition = Vector2.new(0, (index - 1) * Config.RowHeight)
			break
		end
	end
	self:Render()
end

function View:Render()
	local height = Config.RowHeight
	local first = math.max(1, math.floor(self.scroll.CanvasPosition.Y / height) + 1)
	local count = math.ceil(self.scroll.AbsoluteSize.Y / height) + 2
	for slot = 1, count do
		local widget = self.pool[slot]
		if not widget then
			local button = UI.button(self.scroll, "", { Name = "Row", Size = UDim2.new(1, -10, 0, height), AutoButtonColor = false, BackgroundTransparency = 1 })
			local arrow = UI.button(button, "", { Size = UDim2.fromOffset(14, height), BackgroundTransparency = 1, TextSize = 22, TextColor3 = Color3.fromRGB(182, 182, 182) })
			local label = UI.text(button, "", { Size = UDim2.new(1, -30, 1, 0) })
			widget = { button = button, arrow = arrow, label = label, icon = Icons.new(button) }
			self.pool[slot] = widget
			self.janitor:Add(button.Activated:Connect(function()
				if not widget.row then return end
				local item = widget.row.instance
				self.selectInstance(item)
				local now = os.clock()
				if widget.lastItem == item and now - (widget.lastClick or 0) < 0.35 then
					if item:IsA("LuaSourceContainer") and self.openScript then self.openScript()
					elseif widget.row.hasChildren then self.toggle(item) end
					widget.lastClick = 0
				else widget.lastClick = now end
				widget.lastItem = item
			end))
			self.janitor:Add(button.MouseButton2Click:Connect(function()
				if widget.row and self.context then
					self.selectInstance(widget.row.instance)
					self.context()
				end
			end))
			self.janitor:Add(button.MouseEnter:Connect(function()
				if widget.row and widget.row.instance ~= self.selected then button.BackgroundColor3 = Config.Colors.Input; self.motion:To(button, { BackgroundTransparency = 0.6 }, 0.12) end
			end))
			self.janitor:Add(button.MouseLeave:Connect(function()
				if widget.row then button.BackgroundColor3 = Config.Colors.Selected; self.motion:To(button, { BackgroundTransparency = widget.row.instance == self.selected and 0 or 1 }, 0.18) end
			end))
			self.janitor:Add(arrow.Activated:Connect(function()
				if widget.row then self.toggle(widget.row.instance) end
			end))
		end
		local index = first + slot - 1
		local row = self.rows[index]
		widget.row = row
		widget.button.Visible = row ~= nil
		if row then
			local selected = row.instance == self.selected
			if widget.boundInstance ~= row.instance or widget.wasSelected ~= selected then
				self.motion:Cancel(widget.button)
				widget.boundInstance, widget.wasSelected = row.instance, selected
			end
			local indent = row.depth * 18 + 4
			widget.button.Position = UDim2.fromOffset(0, (index - 1) * height)
			widget.button.Size = UDim2.fromOffset(math.max(self.contentWidth or 0, self.scroll.AbsoluteSize.X - 10), height)
			widget.button.BackgroundColor3 = Config.Colors.Selected
			widget.button.BackgroundTransparency = row.instance == self.selected and 0 or 1
			widget.arrow.Position = UDim2.fromOffset(indent, 0)
			widget.arrow.Text = row.hasChildren and "›" or ""
			local rotation = self.expanded[row.instance] and 90 or 0
			if widget.arrowTarget ~= rotation then
				widget.arrowTarget = rotation
				self.motion:To(widget.arrow, { Rotation = rotation }, 0.17)
			end
			widget.arrow.Visible = row.hasChildren
			widget.icon.root.Position = UDim2.fromOffset(indent + 15, math.floor((height - 16) / 2))
			if widget.iconClass ~= row.instance.ClassName then
				widget.iconClass = row.instance.ClassName
				Icons.set(widget.icon, row.instance)
			end
			widget.label.Position = UDim2.fromOffset(indent + 32, 0)
			widget.label.Size = UDim2.new(1, -indent - 36, 1, 0)
			widget.label.Text = row.instance.Name
		end
	end
	for slot = count + 1, #self.pool do self.pool[slot].button.Visible = false end
end

function View:Destroy()
	self.motion:Destroy()
	self.janitor:Destroy()
	self.scroll:Destroy()
	table.clear(self.pool)
	table.clear(self.rows)
end

return View
