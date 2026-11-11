local Janitor = require(script.Parent.Janitor)
local Selection = {}
Selection.__index = Selection

function Selection.new(parent, changed)
	local highlight = Instance.new("Highlight")
	highlight.Name = "ExplorerSelection"
	highlight.FillTransparency = 0.85
	highlight.OutlineColor = Color3.fromRGB(91, 172, 255)
	highlight.Enabled = false
	highlight.Parent = parent
	return setmetatable({ highlight = highlight, changed = changed, janitor = Janitor.new() }, Selection)
end

function Selection:Set(item)
	self.janitor:Destroy()
	self.item = item
	self.highlight.Enabled = false
	self.highlight.Adornee = nil
	if item then
		if item:IsA("BasePart") or item:IsA("Model") then
			self.highlight.Adornee = item
			self.highlight.Enabled = true
		end
		self.janitor:Add(item.Destroying:Connect(function() self:Set(nil) end))
		self.janitor:Add(item.AncestryChanged:Connect(function()
			if not item:IsDescendantOf(game) and item ~= game then self:Set(nil)
			else self.changed(item) end
		end))
		self.janitor:Add(item:GetPropertyChangedSignal("Name"):Connect(function() self.changed(item) end))
	end
	self.changed(item)
end

function Selection:Focus()
	local item, camera = self.item, workspace.CurrentCamera
	if not item or not camera then return false, "Select a BasePart or Model to focus" end
	local ok, err = pcall(function()
		local cf, size
		if item:IsA("BasePart") then cf, size = item.CFrame, item.Size
		elseif item:IsA("Model") then cf, size = item:GetBoundingBox()
		else error("Select a BasePart or Model to focus", 0) end
		local distance = math.max(8, size.Magnitude / (2 * math.tan(math.rad(camera.FieldOfView / 2))))
		camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(1, 0.65, 1).Unit * distance, cf.Position)
		camera.Focus = CFrame.new(cf.Position)
	end)
	return ok, ok and "Camera focused" or tostring(err)
end

function Selection:Destroy()
	self.janitor:Destroy()
	self.highlight:Destroy()
	self.item = nil
end

return Selection
