local Janitor = require(script.Parent.Janitor)
local Config = require(script.Parent.Config)
local serviceOrder = { Workspace = 1, Players = 2, CoreGui = 3, Lighting = 4, ReplicatedFirst = 5, ReplicatedStorage = 6, StarterGui = 7, StarterPack = 8, StarterPlayer = 9, Teams = 10, SoundService = 11 }
local Tree = {}
Tree.__index = Tree

function Tree.new(root, excluded, changed)
	local self = setmetatable({
		root = root, excluded = excluded, changed = changed,
		expanded = { [root] = true }, watches = {}, rows = {},
		query = "", generation = 0, dead = false, pending = false,
	}, Tree)
	self:Refresh()
	return self
end

function Tree:IsExcluded(item)
	for _, root in self.excluded do
		if item == root or item:IsDescendantOf(root) then return true end
	end
	return false
end

function Tree:Schedule()
	if self.pending or self.dead then return end
	self.pending = true
	task.delay(0.08, function()
		self.pending = false
		if not self.dead then self:Refresh() end
	end)
end

function Tree:Refresh()
	if self.dead then return end
	if self.query ~= "" then
		self:Search(self.query)
		return
	end
	self.generation += 1
	local rows, wanted, stack = {}, {}, { { self.root, 0 } }
	while #stack > 0 do
		local entry = table.remove(stack)
		local item, depth = entry[1], entry[2]
		if self:IsExcluded(item) then continue end
		local children = {}
		for _, child in item:GetChildren() do
			if not self:IsExcluded(child) then table.insert(children, child) end
		end
		if item ~= self.root then table.insert(rows, { instance = item, depth = depth - 1, hasChildren = #children > 0 }) end
		wanted[item] = true
		if self.expanded[item] then
			table.sort(children, function(a, b)
				if item == self.root then
					local left, right = serviceOrder[a.ClassName] or 100, serviceOrder[b.ClassName] or 100
					if left ~= right then return left < right end
				end
				if a.Name == b.Name then return a.ClassName < b.ClassName end
				return string.lower(a.Name) < string.lower(b.Name)
			end)
			for i = #children, 1, -1 do table.insert(stack, { children[i], depth + 1 }) end
		end
	end
	for item, watch in self.watches do
		if not wanted[item] then watch:Destroy(); self.watches[item] = nil end
	end
	for item in wanted do
		if self.watches[item] then continue end
		local watch = Janitor.new()
		self.watches[item] = watch
		watch:Add(item.ChildAdded:Connect(function(child)
			if not self:IsExcluded(child) then self:Schedule() end
		end))
		watch:Add(item.ChildRemoved:Connect(function(child)
			if not self:IsExcluded(child) then self:Schedule() end
		end))
		watch:Add(item:GetPropertyChangedSignal("Name"):Connect(function() self:Schedule() end))
	end
	for item in self.expanded do
		if item ~= self.root and not item:IsDescendantOf(self.root) then self.expanded[item] = nil end
	end
	self.rows = rows
	self.changed(rows, tostring(#rows) .. " visible instances")
end

function Tree:Toggle(item)
	if self.query ~= "" then return end
	self.expanded[item] = not self.expanded[item]
	self:Refresh()
end

function Tree:Search(query)
	self.query = string.lower(string.match(query, "^%s*(.-)%s*$"))
	self.generation += 1
	local generation = self.generation
	if self.query == "" then self:Refresh(); return end
	local needle = self.query
	self.changed(self.rows, "Searching...")
	task.spawn(function()
		local queue, head, results, processed = { self.root }, 1, {}, 0
		while head <= #queue do
			if self.dead or generation ~= self.generation then return end
			local item = queue[head]
			head += 1
			processed += 1
			if not self:IsExcluded(item) then
				if item ~= self.root and (string.find(string.lower(item.Name), needle, 1, true)
					or string.find(string.lower(item.ClassName), needle, 1, true)) then
					table.insert(results, { instance = item, depth = 0, hasChildren = false })
					if #results >= Config.SearchLimit then break end
				end
				for _, child in item:GetChildren() do table.insert(queue, child) end
			end
			if processed % Config.SearchBatch == 0 then task.wait() end
		end
		if self.dead or generation ~= self.generation then return end
		self.rows = results
		self.changed(results, tostring(#results) .. " results" .. (head <= #queue and " (limit reached)" or ""))
	end)
end

function Tree:Reveal(item)
	local parent = item.Parent
	while parent do
		self.expanded[parent] = true
		parent = parent.Parent
	end
	self.query = ""
	self:Refresh()
end

function Tree:Destroy()
	self.dead = true
	self.generation += 1
	for _, watch in self.watches do watch:Destroy() end
	table.clear(self.watches)
	table.clear(self.expanded)
	table.clear(self.rows)
end

return Tree
