local TweenService = game:GetService("TweenService")
local Motion = {}
Motion.__index = Motion

function Motion.new()
	return setmetatable({ active = {}, dead = false }, Motion)
end

function Motion:Cancel(target)
	local record = self.active[target]
	if not record then return end
	self.active[target] = nil
	if record.connection then record.connection:Disconnect() end
	record.tween:Cancel()
end

function Motion:To(target, properties, duration, style, callback)
	if self.dead then return end
	self:Cancel(target)
	local tween = TweenService:Create(target, TweenInfo.new(duration or 0.22, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties)
	local record = { tween = tween }
	self.active[target] = record
	record.connection = tween.Completed:Connect(function(state)
		if self.active[target] ~= record then return end
		self.active[target] = nil
		record.connection:Disconnect()
		if not self.dead and state == Enum.PlaybackState.Completed and callback then callback() end
	end)
	tween:Play()
	return tween
end

function Motion:Busy(target)
	return self.active[target] ~= nil
end

function Motion:Button(button, janitor)
	local scale = Instance.new("UIScale")
	scale.Name, scale.Scale, scale.Parent = "HoverScale", 1, button
	local original = button.TextColor3
	janitor:Add(button.MouseEnter:Connect(function()
		self:To(button, { TextColor3 = Color3.fromRGB(140, 205, 255) }, 0.13)
	end))
	janitor:Add(button.MouseLeave:Connect(function() self:To(button, { TextColor3 = original }, 0.18) end))
	janitor:Add(button.Activated:Connect(function()
		self:To(scale, { Scale = 0.94 }, 0.07, Enum.EasingStyle.Quad, function()
			self:To(scale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back)
		end)
	end))
end

function Motion:Destroy()
	self.dead = true
	local targets = {}
	for target in self.active do table.insert(targets, target) end
	for _, target in targets do self:Cancel(target) end
end

return Motion
