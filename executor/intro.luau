return function(parent, onDestroy)
	local TweenService = game:GetService("TweenService")
	local self = { dead = false, closing = false, failed = false, tweens = {}, connections = {}, progress = 0, noticeVersion = 0, started = os.clock() }
	local function create(className, properties, owner)
		local item = Instance.new(className)
		for key, value in properties do item[key] = value end
		item.Parent = owner
		return item
	end
	local function tween(target, properties, duration, style, callback)
		local previous = self.tweens[target]
		if previous then
			if previous.connection then previous.connection:Disconnect() end
			previous.tween:Cancel()
		end
		local animation = TweenService:Create(target, TweenInfo.new(duration or 0.3, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties)
		local record = { tween = animation }
		self.tweens[target] = record
		record.connection = animation.Completed:Connect(function(state)
			if self.tweens[target] ~= record then return end
			self.tweens[target] = nil
			record.connection:Disconnect()
			if not self.dead and state == Enum.PlaybackState.Completed and callback then callback() end
		end)
		animation:Play()
	end
	self.gui = create("ScreenGui", { Name = "ExplorerLoading", DisplayOrder = 10001, IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, parent)
	local shade = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(7, 10, 17), BackgroundTransparency = 1, BorderSizePixel = 0, Active = true }, self.gui)
	local card = create("CanvasGroup", { Name = "IntroCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 22), Size = UDim2.fromOffset(480, 286), GroupTransparency = 1, BackgroundColor3 = Color3.fromRGB(20, 25, 35), BorderSizePixel = 0 }, shade)
	create("UICorner", { CornerRadius = UDim.new(0, 14) }, card)
	create("UIStroke", { Color = Color3.fromRGB(67, 105, 151), Thickness = 1.2, Transparency = 0.25 }, card)
	local scale = create("UIScale", { Scale = 0.92 }, card)
	local size = self.gui.AbsoluteSize
	local targetScale = math.min(1, math.max(0.1, (size.X - 24) / 480), math.max(0.1, (size.Y - 24) / 286))
	local glow = create("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.fromRGB(105, 185, 255), BorderSizePixel = 0 }, card)
	create("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(88, 168, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(169, 126, 255)) }) }, glow)
	local function label(text, position, dimensions, fontSize, color)
		return create("TextLabel", { Text = text, Position = position, Size = dimensions, BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.SourceSans, TextSize = fontSize, TextColor3 = color or Color3.fromRGB(230, 238, 250), TextXAlignment = Enum.TextXAlignment.Left }, card)
	end
	label("EXPLORER", UDim2.fromOffset(30, 26), UDim2.fromOffset(330, 22), 13, Color3.fromRGB(128, 180, 236))
	local logo = label("Explorer+", UDim2.fromOffset(25, 48), UDim2.fromOffset(390, 64), 48)
	logo.Font, logo.TextTransparency = Enum.Font.SourceSansLight, 1
	local subtitle = label("Your world, inspected.", UDim2.fromOffset(30, 112), UDim2.fromOffset(400, 22), 16, Color3.fromRGB(151, 168, 192))
	subtitle.TextTransparency = 1
	local stage = label("Preparing Explorer", UDim2.fromOffset(30, 158), UDim2.fromOffset(360, 24), 16)
	local percentage = label("0%", UDim2.new(1, -94, 0, 158), UDim2.fromOffset(64, 24), 14, Color3.fromRGB(143, 195, 255))
	percentage.TextXAlignment = Enum.TextXAlignment.Right
	local track = create("Frame", { Position = UDim2.fromOffset(30, 194), Size = UDim2.new(1, -60, 0, 5), BackgroundColor3 = Color3.fromRGB(40, 51, 69), BorderSizePixel = 0, ClipsDescendants = true }, card)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local bar = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(105, 185, 255), BorderSizePixel = 0 }, track)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
	create("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(88, 168, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(169, 126, 255)) }) }, bar)
	local detail = label("Connecting to the pinned release", UDim2.fromOffset(30, 211), UDim2.new(1, -60, 0, 22), 13, Color3.fromRGB(141, 158, 183))
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	local notice = label("", UDim2.fromOffset(30, 244), UDim2.new(1, -60, 0, 21), 12, Color3.fromRGB(255, 206, 134))
	notice.TextTransparency = 1
	local errorText = label("", UDim2.fromOffset(30, 113), UDim2.new(1, -60, 0, 89), 14, Color3.fromRGB(194, 205, 223))
	errorText.Visible, errorText.TextWrapped, errorText.TextYAlignment = false, true, Enum.TextYAlignment.Top
	local close = create("TextButton", { Text = "Close", Position = UDim2.new(1, -105, 1, -46), Size = UDim2.fromOffset(75, 28), Visible = false, Font = Enum.Font.SourceSans, TextSize = 14, TextColor3 = Color3.fromRGB(230, 238, 250), BackgroundColor3 = Color3.fromRGB(47, 60, 79), BorderSizePixel = 0 }, card)
	create("UICorner", { CornerRadius = UDim.new(0, 6) }, close)
	local dots = {}
	for index = 1, 3 do
		local dot = create("Frame", { Position = UDim2.new(1, -66 + index * 10, 0, 38), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.fromRGB(139, 199, 255), BackgroundTransparency = 0.75, BorderSizePixel = 0 }, card)
		create("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
		local animation = TweenService:Create(dot, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, index * 0.14), { BackgroundTransparency = 0.1, Position = UDim2.new(1, -66 + index * 10, 0, 34) })
		table.insert(dots, animation)
		animation:Play()
	end
	local blur
	pcall(function()
		blur = create("BlurEffect", { Name = "ExplorerIntroBlur", Size = 0 }, game:GetService("Lighting"))
		tween(blur, { Size = 12 }, 0.45)
	end)
	function self:Destroy()
		if self.dead then return end
		self.dead = true
		for _, connection in self.connections do connection:Disconnect() end
		for _, record in self.tweens do
			if record.connection then record.connection:Disconnect() end
			record.tween:Cancel()
		end
		for _, animation in dots do animation:Cancel() end
		if blur then blur:Destroy() end
		self.gui:Destroy()
		table.clear(self.tweens)
		table.clear(self.connections)
		if onDestroy then onDestroy(self) end
	end
	local function dismiss()
		if self.dead or self.closing then return end
		self.closing = true
		for _, animation in dots do animation:Cancel() end
		if blur then tween(blur, { Size = 0 }, 0.3) end
		tween(shade, { BackgroundTransparency = 1 }, 0.32)
		tween(scale, { Scale = targetScale * 0.96 }, 0.28)
		tween(card, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, -12) }, 0.32, nil, function() self:Destroy() end)
	end
	table.insert(self.connections, close.Activated:Connect(dismiss))
	function self:Step(progress, title, description)
		if self.dead or self.failed or self.closing then return end
		self.progress = math.max(self.progress, math.clamp(progress, 0, 1))
		stage.Text, detail.Text = title, description or ""
		percentage.Text = tostring(math.floor(self.progress * 100)) .. "%"
		tween(bar, { Size = UDim2.fromScale(self.progress, 1) }, 0.3)
	end
	function self:Notice(message)
		if self.dead or self.closing then return end
		self.noticeVersion += 1
		local version = self.noticeVersion
		notice.Text = message
		tween(notice, { TextTransparency = 0 }, 0.18)
		task.delay(3, function()
			if not self.dead and version == self.noticeVersion then tween(notice, { TextTransparency = 1 }, 0.25) end
		end)
	end
	function self:Fail(code, title, message)
		if self.dead then return end
		self.failed = true
		for _, animation in dots do animation:Cancel() end
		logo.Text, logo.TextSize = code .. "  ·  " .. title, 25
		logo.TextColor3, glow.BackgroundColor3 = Color3.fromRGB(255, 137, 155), Color3.fromRGB(255, 137, 155)
		subtitle.Visible, stage.Visible, percentage.Visible, track.Visible, detail.Visible, notice.Visible = false, false, false, false, false, false
		errorText.Visible, errorText.Text, close.Visible = true, string.sub(message, 1, 230) .. (#message > 230 and "…\nFull details are in the executor output." or ""), true
		tween(card, { GroupTransparency = 0 }, 0.2)
	end
	function self:Finish()
		self:Step(1, "Ready", "Explorer is ready to use")
		task.delay(math.max(0.15, 0.9 - (os.clock() - self.started)), function() if not self.dead and not self.failed then dismiss() end end)
	end
	tween(shade, { BackgroundTransparency = 0.5 }, 0.4)
	tween(card, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0) }, 0.48, Enum.EasingStyle.Quint)
	tween(scale, { Scale = targetScale }, 0.52, Enum.EasingStyle.Back)
	tween(logo, { TextTransparency = 0 }, 0.42)
	tween(subtitle, { TextTransparency = 0 }, 0.55)
	return self
end
