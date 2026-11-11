local fs = require("@lune/fs")
local luau = require("@lune/luau")
local env = { task = { wait = function() end } }
local Document = luau.load(fs.readFile("dist/modules/SourceDocument.luau"), { environment = env })()(function() error("Unexpected dependency") end)
local Syntax = luau.load(fs.readFile("dist/modules/Syntax.luau"))()(function() error("Unexpected dependency") end)
local text = "first\r\n\tsecond 😀é\n"
local doc = Document.new(text)
assert(doc.text == text and #doc.starts == 3 and doc:GetLine(1) == "first" and doc:GetLine(3) == "", "Line indexing changed source bytes")
assert(doc:Slice(2, 4, 6) == "second", "Tab columns failed")
assert(doc:Slice(2, 11, 2) == "😀é", "Unicode columns were split")
local source = string.rep("-- line\n", 100000) .. "THE_END"
local large = Document.new(source)
assert(#large.starts == 100001 and large:GetLine(100001) == "THE_END", "Large source indexing failed")
assert(Document.new(source, function() return true end) == nil, "Cancelled indexing continued")
local line = string.rep("a", 300000) .. "_FINAL"
assert(Document.new(line):Slice(1, 300000, 6) == "_FINAL", "Long lines are truncated")
local escaped = Syntax.Highlight('return "<font> & value" -- hi')
assert(string.find(escaped, "&lt;font&gt;", 1, true) and string.find(escaped, "&amp;", 1, true), "Source escaped incorrectly")
assert(string.find(escaped, "#F86D7C", 1, true) and string.find(escaped, "#8D9A8A", 1, true), "Syntax colors missing")
print("Minified document: exact bytes, CRLF, tabs, Unicode, 100,001 lines, cancellation, 300,006-character line, and syntax escaping passed.")
