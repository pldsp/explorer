local Codec = {}
local function numbers(text, count)
	local values = {}
	for part in string.gmatch(text, "[^,]+") do
		local number = tonumber(part)
		if not number or number ~= number or math.abs(number) == math.huge then
			error("Enter finite numbers separated by commas", 0)
		end
		table.insert(values, number)
	end
	assert(#values == count, "Expected " .. count .. " comma-separated numbers")
	return table.unpack(values)
end

function Codec.format(value)
	if typeof(value) == "Color3" then
		return string.format("%.4f, %.4f, %.4f", value.R, value.G, value.B)
	elseif typeof(value) == "UDim2" then
		return string.format("%g, %g, %g, %g", value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
	elseif typeof(value) == "UDim" then
		return string.format("%g, %g", value.Scale, value.Offset)
	elseif typeof(value) == "CFrame" then
		local parts = { value:GetComponents() }
		for index, part in parts do parts[index] = string.format("%g", part) end
		return table.concat(parts, ", ")
	elseif typeof(value) == "BrickColor" then
		return value.Name
	elseif typeof(value) == "NumberRange" then
		return string.format("%g, %g", value.Min, value.Max)
	elseif typeof(value) == "Rect" then
		return string.format("%g, %g, %g, %g", value.Min.X, value.Min.Y, value.Max.X, value.Max.Y)
	end
	return tostring(value)
end

function Codec.parse(text, previous)
	local kind = typeof(previous)
	if kind == "string" then return text end
	if kind == "number" then return numbers(text, 1) end
	if kind == "boolean" then
		local normalized = string.lower(string.match(text, "^%s*(.-)%s*$"))
		assert(normalized == "true" or normalized == "false", "Enter true or false")
		return normalized == "true"
	end
	if kind == "Vector3" then return Vector3.new(numbers(text, 3)) end
	if kind == "Vector2" then return Vector2.new(numbers(text, 2)) end
	if kind == "UDim2" then return UDim2.new(numbers(text, 4)) end
	if kind == "UDim" then return UDim.new(numbers(text, 2)) end
	if kind == "CFrame" then return CFrame.new(numbers(text, 12)) end
	if kind == "Rect" then return Rect.new(numbers(text, 4)) end
	if kind == "NumberRange" then
		local minimum, maximum = numbers(text, 2)
		assert(minimum <= maximum, "Minimum must not exceed maximum")
		return NumberRange.new(minimum, maximum)
	end
	if kind == "BrickColor" then
		local color = BrickColor.new(tonumber(text) or text)
		assert(tonumber(text) or string.lower(color.Name) == string.lower(text), "Unknown BrickColor name")
		return color
	end
	if kind == "Color3" then
		local r, g, b = numbers(text, 3)
		assert(r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1, "RGB channels must be 0..1")
		return Color3.new(r, g, b)
	end
	if kind == "EnumItem" then
		local name = string.match(text, "([%w_]+)%s*$")
		for _, item in previous.EnumType:GetEnumItems() do
			if string.lower(item.Name) == string.lower(name or "") then return item end
		end
		error("Unknown enum item", 0)
	end
	error("This value is read-only", 0)
end

function Codec.editable(value)
	return table.find({ "string", "number", "boolean", "Vector2", "Vector3", "Color3", "UDim", "UDim2", "EnumItem", "CFrame", "BrickColor", "NumberRange", "Rect" }, typeof(value)) ~= nil
end

return Codec
