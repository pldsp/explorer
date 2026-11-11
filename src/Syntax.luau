local Syntax = {}
local keywords = {}
for word in string.gmatch("and break continue do else elseif end export false for function if in local nil not or repeat return then true type typeof until while", "%S+") do keywords[word] = true end
local globals = {}
for word in string.gmatch("assert error getmetatable ipairs next pairs pcall print rawequal rawget rawset require select setmetatable tonumber tostring unpack warn xpcall game workspace script task math string table coroutine utf8 bit32 os debug Enum Instance Vector2 Vector3 CFrame Color3 UDim UDim2", "%S+") do globals[word] = true end
local colors = { keyword = "#F86D7C", string = "#ADF195", number = "#FFC678", comment = "#8D9A8A", builtin = "#84D6F7", method = "#FDFBAC", field = "#61A6FF" }

function Syntax.Escape(text)
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

function Syntax.Highlight(text)
	local result, position, size = {}, 1, #text
	local function emit(value, kind)
		local escaped = Syntax.Escape(value)
		table.insert(result, kind and ('<font color="' .. colors[kind] .. '">' .. escaped .. '</font>') or escaped)
	end
	while position <= size do
		local char = string.sub(text, position, position)
		local rest = string.sub(text, position)
		if string.sub(rest, 1, 2) == "--" then emit(rest, "comment"); break end
		if char == '"' or char == "'" or char == "`" then
			local finish = position + 1
			while finish <= size do
				local current = string.sub(text, finish, finish)
				if current == "\\" then finish += 2
				elseif current == char then finish += 1; break
				else finish += 1 end
			end
			emit(string.sub(text, position, finish - 1), "string")
			position = finish
		else
			local word = string.match(rest, "^[%a_][%w_]*")
			local number = not word and string.match(rest, "^%d[%w%.]*")
			if word then
				local previous = string.sub(text, position - 1, position - 1)
				local after = string.sub(text, position + #word)
				local kind = keywords[word] and "keyword" or globals[word] and "builtin" or string.match(after, "^%s*%(") and "method" or (previous == "." or previous == ":") and "field" or nil
				emit(word, kind)
				position += #word
			elseif number then emit(number, "number"); position += #number
			else emit(char); position += 1 end
		end
	end
	return table.concat(result)
end

return Syntax
