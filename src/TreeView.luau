local Config = require(script.Parent.Config)
local UI = require(script.Parent.UI)
local Janitor = require(script.Parent.Janitor)
local Icons = require(script.Parent.Icons)
local View = {}
View.__index = View

function View.new(parent, selectInstance, toggle, context)
	local self = setmetatable({ rows = {}, pool = {}, janitor = Janitor.new(), selected = nil }, View)
	self.scroll = UI.scroll(parent, { Name = "InstanceTree", Size = UDim2.fromScale(1, 1) })
	self.selectInstance, self.toggle = selectInstance, toggle
	self.context = context
	self.janitor:Add(self.scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:Render() end))
	self.janitor:Add(self.scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Render() end))
	return self
end

function View:SetRows(rows, expanded)
	self.rows, self.expanded = rows, expanded
	self.scroll.CanvasSize = UDim2.fromOffset(0, #rows * Config.RowHeight)
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
			local button = UI.button(self.scroll, "", { Name = "Row", Size = UDim2.new(1, -5, 0, height), AutoButtonColor = false })
			local arrow = UI.button(button, "", { Size = UDim2.fromOffset(14, height), BackgroundTransparency = 1, TextSize = 10 })
			local label = UI.text(button, "", { Size = UDim2.new(1, -30, 1, 0) })
			widget = { button = button, arrow = arrow, label = label, icon = Icons.new(button) }
			self.pool[slot] = widget
			self.janitor:Add(button.Activated:Connect(function()
				if widget.row then self.selectInstance(widget.row.instance) end
			end))
			self.janitor:Add(button.MouseButton2Click:Connect(function()
				if widget.row and self.context then
					self.selectInstance(widget.row.instance)
					self.context()
				end
			end))
			self.janitor:Add(button.MouseEnter:Connect(function()
				if widget.row and widget.row.instance ~= self.selected then button.BackgroundColor3 = Config.Colors.Input end
			end))
			self.janitor:Add(button.MouseLeave:Connect(function()
				if widget.row then button.BackgroundColor3 = widget.row.instance == self.selected and Config.Colors.Selected or Config.Colors.Panel end
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
			local indent = math.min(row.depth, 18) * 14 + 2
			widget.button.Position = UDim2.fromOffset(0, (index - 1) * height)
			widget.button.BackgroundColor3 = row.instance == self.selected and Config.Colors.Selected or Config.Colors.Panel
			widget.arrow.Position = UDim2.fromOffset(indent, 0)
			widget.arrow.Text = row.hasChildren and (self.expanded[row.instance] and "▼" or "▶") or ""
			widget.arrow.Visible = row.hasChildren
			widget.icon.root.Position = UDim2.fromOffset(indent + 15, -1)
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
	self.janitor:Destroy()
	self.scroll:Destroy()
	table.clear(self.pool)
	table.clear(self.rows)
end

return View
