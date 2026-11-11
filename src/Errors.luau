local Errors = {}
Errors.Definitions = {
	E001 = { "Already running", "Explorer is already running. The existing window has been brought back into view.", "info" },
	E002 = { "Already loading", "Explorer is already loading. Wait for the current startup to finish.", "info" },
	E003 = { "Unsupported executor", "This environment does not provide loadstring.", "error" },
	E004 = { "Client required", "Run Explorer on the Roblox client.", "error" },
	E005 = { "GUI unavailable", "A writable GUI container could not be found.", "error" },
	E101 = { "Download failed", "A module could not be downloaded after three attempts.", "error" },
	E102 = { "Invalid download", "Downloaded module bytes did not match the pinned release.", "error" },
	E103 = { "Download timeout", "Module downloads exceeded the startup time limit. Try again.", "error" },
	E104 = { "Compile failed", "A downloaded module could not be compiled.", "error" },
	E105 = { "Invalid module", "A downloaded module did not return a valid factory.", "error" },
	E106 = { "Dependency cycle", "A module dependency cycle was detected.", "error" },
	E107 = { "Missing module", "A requested module is missing from the release.", "error" },
	E108 = { "Empty module", "A module returned no export.", "error" },
	E109 = { "Startup failed", "Explorer could not initialize. Close the error screen and try again.", "error" },
	E201 = { "Decompiler unavailable", "This executor has no decompile function and Source is unreadable.", "error" },
	E202 = { "Source unavailable", "The script's source could not be read or decompiled.", "error" },
	E203 = { "Decompiler timeout", "The executor's decompiler did not finish in time.", "error" },
}

function Errors.Get(code)
	return Errors.Definitions[code] or Errors.Definitions.E109
end

function Errors.Format(code, detail)
	local definition = Errors.Get(code)
	return "[Explorer " .. code .. "] " .. definition[2] .. (detail and detail ~= "" and ("\n" .. tostring(detail)) or "")
end

function Errors.Code(message)
	return string.match(tostring(message), "%[Explorer (E%d+)%]") or "E109"
end

return Errors
