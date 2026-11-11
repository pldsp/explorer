local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
	return setmetatable({ items = {} }, Janitor)
end

function Janitor:Add(item)
	table.insert(self.items, item)
	return item
end

function Janitor:Destroy()
	local items = self.items
	self.items = {}
	for index = #items, 1, -1 do
		local item = items[index]
		local ok, err = pcall(function()
			if typeof(item) == "RBXScriptConnection" then
				item:Disconnect()
			elseif type(item) == "function" then
				item()
			else
				item:Destroy()
			end
		end)
		if not ok then warn("Explorer+ cleanup: " .. tostring(err)) end
	end
end

return Janitor
