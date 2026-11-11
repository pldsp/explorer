local Metadata = require(script.Parent.ApiMetadata)
local Fallback = require(script.Parent.PropertySchema)
local Catalog = {}
local cache = {}

function Catalog.Get(item)
	local className = item.ClassName
	if cache[className] then return cache[className] end
	local result, seen = {}, {}
	local current = className
	while Metadata.Classes[current] do
		local data = Metadata.Classes[current]
		for _, property in data[2] do
			if not seen[property[1]] then
				seen[property[1]] = true
				table.insert(result, property)
			end
		end
		current = data[1]
	end
	for _, group in Fallback do
		if item:IsA(group[1]) then
			for _, name in group[2] do
				if name ~= "Source" and not seen[name] then
					seen[name] = true
					table.insert(result, { name, "Other", name == "ClassName" or name == "IsPlaying" })
				end
			end
		end
	end
	table.sort(result, function(a, b)
		if a[2] ~= b[2] then return a[2] < b[2] end
		return a[1] < b[1]
	end)
	cache[className] = result
	return result
end

return Catalog
