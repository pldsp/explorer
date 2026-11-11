local Document = {}
Document.__index = Document

function Document.new(text, cancelled)
	local self = setmetatable({ text = text, starts = { 1 }, widths = {}, longest = 0 }, Document)
	local start, row = 1, 1
	while true do
		local stop = string.find(text, "\n", start, true)
		local finish = stop and stop - 1 or #text
		if string.byte(text, finish) == 13 then finish -= 1 end
		local line = string.sub(text, start, finish)
		local _, tabs = string.gsub(line, "\t", "")
		local length = utf8.len(line)
		local width = (length or #line) + tabs * 3
		self.widths[row] = width
		self.longest = math.max(self.longest, width)
		if not stop then break end
		start, row = stop + 1, row + 1
		self.starts[row] = start
		if row % 4096 == 0 then
			if cancelled and cancelled() then return nil end
			task.wait()
			if cancelled and cancelled() then return nil end
		end
	end
	return self
end

function Document:GetLine(row)
	local start = self.starts[row]
	if not start then return "" end
	local finish = self.starts[row + 1] and self.starts[row + 1] - 2 or #self.text
	if string.byte(self.text, finish) == 13 then finish -= 1 end
	return string.sub(self.text, start, finish)
end

function Document:Slice(row, column, count)
	if not self.starts[row] or column >= (self.widths[row] or 0) then return "" end
	local line = string.gsub(self:GetLine(row), "\t", "    ")
	local valid = utf8.len(line)
	if valid then
		local first = utf8.offset(line, column + 1)
		if not first then return "" end
		local finish = utf8.offset(line, column + count + 1)
		return string.sub(line, first, finish and finish - 1 or #line)
	end
	return string.sub(line, column + 1, column + count)
end

return Document
