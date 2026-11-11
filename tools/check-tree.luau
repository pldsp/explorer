local fs = require("@lune/fs")
local luau = require("@lune/luau")
local active = 0
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local token = {}
			listeners[token] = callback
			active += 1
			return { Disconnect = function()
				if listeners[token] then listeners[token] = nil; active -= 1 end
			end }
		end,
		Fire = function(_, ...)
			for _, callback in listeners do callback(...) end
		end,
	}
end
local function node(name, parent)
	local item = { Name = name, ClassName = "Folder", Parent = parent, children = {}, ChildAdded = signal(), ChildRemoved = signal(), nameChanged = signal() }
	function item:GetChildren() return table.clone(self.children) end
	function item:GetPropertyChangedSignal() return self.nameChanged end
	function item:IsDescendantOf(root)
		local ancestor = self.Parent
		while ancestor do
			if ancestor == root then return true end
			ancestor = ancestor.Parent
		end
		return false
	end
	if parent then table.insert(parent.children, item) end
	return item
end
local pending, running = {}, {}
local scheduler = {
	delay = function(_, callback) table.insert(pending, callback) end,
	spawn = function(callback)
		local thread = coroutine.create(callback)
		local ok, err = coroutine.resume(thread)
		assert(ok, err)
		if coroutine.status(thread) ~= "dead" then table.insert(running, thread) end
	end,
	wait = coroutine.yield,
}
local function flush()
	while #pending > 0 or #running > 0 do
		local callbacks, threads = pending, running
		pending, running = {}, {}
		for _, callback in callbacks do callback() end
		for _, thread in threads do
			local ok, err = coroutine.resume(thread)
			assert(ok, err)
			if coroutine.status(thread) ~= "dead" then table.insert(running, thread) end
		end
	end
end
local janitor = {}
janitor.__index = janitor
function janitor.new() return setmetatable({ items = {} }, janitor) end
function janitor:Add(item) table.insert(self.items, item) end
function janitor:Destroy()
	for _, connection in self.items do connection:Disconnect() end
	table.clear(self.items)
end
local model = luau.load(fs.readFile("src/TreeModel.luau"), { environment = {
	script = { Parent = { Janitor = "Janitor", Config = "Config" } },
	require = function(name)
		if name == "Janitor" then return janitor end
		return { SearchBatch = 2, SearchLimit = 3 }
	end,
	task = scheduler,
} })()
local root = node("game")
local branch = node("Workspace", root)
local hidden = node("ExplorerPlus", root)
node("HiddenMatch", hidden)
local target = node("Target", branch)
node("Target2", branch)
node("Target3", branch)
node("Target4", branch)
local tree = model.new(root, { hidden }, function() end)
assert(#tree.rows == 1, "Collapsed tree or exclusion failed")
tree:Toggle(branch)
assert(#tree.rows == 5, "Expansion failed")
tree:Toggle(branch)
assert(#tree.rows == 1 and tree.watches[target] == nil, "Collapse did not release watches")
tree:Search("target")
flush()
assert(#tree.rows == 3, "Search cap failed")
tree:Search("target")
tree:Search("not-found")
flush()
assert(#tree.rows == 0, "Stale search overwrote the newer query")
tree:Reveal(target)
assert(#tree.rows == 5 and tree.expanded[branch], "Reveal failed")
local added = node("New", branch)
branch.ChildAdded:Fire(added)
branch.ChildAdded:Fire(added)
assert(#pending == 1, "Hierarchy updates were not coalesced")
flush()
assert(#tree.rows == 6, "Hierarchy update failed")
tree:Search("target")
tree:Destroy()
flush()
assert(active == 0 and #tree.rows == 0, "Destroy leaked listeners or search results")
print("Tree expansion, exclusion, search limits/cancellation, reveal, events and cleanup passed.")
