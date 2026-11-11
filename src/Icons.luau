local UI = require(script.Parent.UI)
local Atlas = require(script.Parent.IconAtlas)
local Icons = {}
local inheritance = { "BasePart", "Model", "GuiObject", "ValueBase", "Constraint", "Light", "LuaSourceContainer" }
local aliases = { BasePart = "Part", GuiObject = "Frame", ValueBase = "Value", LuaSourceContainer = "Script", Terrain = "Terrain", DataModel = "Workspace" }

function Icons.new(parent)
	local image = UI.new("ImageLabel", {
		Name = "ClassIcon", Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1,
		Image = Atlas.Image, ImageRectSize = Vector2.new(Atlas.Size, Atlas.Size),
		ScaleType = Enum.ScaleType.Fit,
	}, parent)
	return { root = image }
end

function Icons.set(icon, item)
	local name = aliases[item.ClassName] or item.ClassName
	local index = Atlas.Classes[name]
	if index == nil and type(item.IsA) == "function" then
		for _, className in inheritance do
			if item:IsA(className) then
				index = Atlas.Classes[aliases[className] or className]
				if index ~= nil then break end
			end
		end
	end
	index = index or Atlas.Classes.Folder or 0
	icon.root.ImageRectOffset = Vector2.new(index % Atlas.Columns * Atlas.Size, math.floor(index / Atlas.Columns) * Atlas.Size)
end

return Icons
