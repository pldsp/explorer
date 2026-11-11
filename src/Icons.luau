local UI = require(script.Parent.UI)
local Icons = {}
local definitions = {
	Folder = { "folder", Color3.fromRGB(255, 220, 132), "" },
	Workspace = { "round", Color3.fromRGB(81, 199, 255), "⊕" },
	Players = { "person", Color3.fromRGB(255, 216, 121), "" },
	Player = { "person", Color3.fromRGB(236, 236, 236), "" },
	Backpack = { "box", Color3.fromRGB(222, 222, 222), "B" },
	LocalScript = { "page", Color3.fromRGB(128, 204, 250), "≡" },
	Script = { "page", Color3.fromRGB(210, 210, 210), "≡" },
	ModuleScript = { "page", Color3.fromRGB(191, 152, 233), "≡" },
	IntValue = { "symbol", Color3.fromRGB(225, 225, 225), "#" },
	NumberValue = { "symbol", Color3.fromRGB(225, 225, 225), "#" },
	BoolValue = { "symbol", Color3.fromRGB(225, 225, 225), "✓" },
	StringValue = { "symbol", Color3.fromRGB(225, 225, 225), "S" },
	Lighting = { "round", Color3.fromRGB(255, 232, 112), "•" },
	ReplicatedStorage = { "box", Color3.fromRGB(134, 212, 240), "" },
}

function Icons.new(parent)
	local root = UI.frame(parent, { Size = UDim2.fromOffset(14, 16), BackgroundTransparency = 1 })
	local body = UI.frame(root, { Position = UDim2.fromOffset(2, 4), Size = UDim2.fromOffset(10, 9) })
	local tab = UI.frame(root, { Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(5, 3) })
	local inset = UI.frame(body, { Position = UDim2.fromOffset(1, 2), Size = UDim2.new(1, -2, 1, -3), BackgroundColor3 = Color3.fromRGB(45, 45, 45) })
	local mark = UI.text(root, "", { Size = UDim2.fromScale(1, 1), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center })
	return { root = root, body = body, tab = tab, inset = inset, mark = mark }
end

function Icons.set(icon, item)
	local definition = definitions[item.ClassName]
	if not definition then
		if item:IsA("GuiBase2d") then definition = { "window", Color3.fromRGB(109, 187, 231), "" }
		elseif item:IsA("BasePart") then definition = { "box", Color3.fromRGB(172, 202, 223), "" }
		elseif item:IsA("Model") then definition = { "symbol", Color3.fromRGB(225, 225, 225), "◇" }
		else definition = { "symbol", Color3.fromRGB(208, 208, 208), "◇" } end
	end
	local kind, color, mark = definition[1], definition[2], definition[3]
	icon.body.BackgroundColor3, icon.tab.BackgroundColor3, icon.mark.TextColor3 = color, color, color
	icon.tab.Visible = kind == "folder" or kind == "person"
	icon.body.Visible = kind ~= "symbol" and kind ~= "round"
	icon.inset.Visible = kind == "window" or kind == "box" or kind == "page"
	icon.body.Position = kind == "person" and UDim2.fromOffset(3, 8) or UDim2.fromOffset(2, 4)
	icon.body.Size = kind == "person" and UDim2.fromOffset(8, 5) or UDim2.fromOffset(10, 9)
	icon.tab.Position = kind == "person" and UDim2.fromOffset(5, 2) or UDim2.fromOffset(2, 2)
	icon.tab.Size = kind == "person" and UDim2.fromOffset(4, 5) or UDim2.fromOffset(5, 3)
	icon.mark.Text = mark
end

return Icons
