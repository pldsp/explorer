local Config = require(script.Parent.Config)
local Colors = Config.Colors
local UI = {}

function UI.new(className, props, parent)
	local item = Instance.new(className)
	for key, value in props do item[key] = value end
	item.Parent = parent
	return item
end

function UI.frame(parent, props)
	local defaults = { BorderSizePixel = 0, BackgroundColor3 = Colors.Panel }
	for key, value in props or {} do defaults[key] = value end
	return UI.new("Frame", defaults, parent)
end

function UI.group(parent, props)
	local defaults = { BorderSizePixel = 0, BackgroundColor3 = Colors.Panel, GroupTransparency = 0 }
	for key, value in props or {} do defaults[key] = value end
	return UI.new("CanvasGroup", defaults, parent)
end

function UI.text(parent, text, props)
	local defaults = {
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Text = text, TextColor3 = Colors.Text, TextSize = Config.TextSize,
		Font = Config.Font, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for key, value in props or {} do defaults[key] = value end
	return UI.new("TextLabel", defaults, parent)
end

function UI.button(parent, text, props)
	local defaults = {
		BackgroundColor3 = Colors.Input, BorderSizePixel = 0,
		Text = text, TextColor3 = Colors.Text, TextSize = Config.TextSize,
		Font = Config.Font, AutoButtonColor = true,
	}
	for key, value in props or {} do defaults[key] = value end
	return UI.new("TextButton", defaults, parent)
end

function UI.input(parent, placeholder, props)
	local defaults = {
		BackgroundColor3 = Colors.Input, BorderSizePixel = 0,
		Text = "", PlaceholderText = placeholder, PlaceholderColor3 = Colors.Muted,
		TextColor3 = Colors.Text, TextSize = Config.TextSize, Font = Config.Font,
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
	}
	for key, value in props or {} do defaults[key] = value end
	local input = UI.new("TextBox", defaults, parent)
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, input)
	return input
end

function UI.scroll(parent, props)
	local defaults = {
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
		ScrollBarImageColor3 = Colors.Muted, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	for key, value in props or {} do defaults[key] = value end
	return UI.new("ScrollingFrame", defaults, parent)
end

return UI
