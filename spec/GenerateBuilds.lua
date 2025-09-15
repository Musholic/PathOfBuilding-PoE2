local dkjson = require "dkjson"

local function fetchBuilds(path, buildList)
	buildList = buildList or {}
	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." then
			local f = path .. '/' .. file
			local attr = lfs.attributes(f)
			assert(type(attr) == "table")
			if attr.mode == "directory" then
				fetchBuilds(f, buildList)
			else
				if file:match("^.+(%..+)$") == ".json" then
					local fileHnd, errMsg = io.open(f, "r")
					if not fileHnd then
						return nil, errMsg
					end
					local fileText = fileHnd:read("*a")
					fileHnd:close()
					local fullCharData = dkjson.decode(fileText)
					buildList[f] = fullCharData.character
				end
			end
		end
	end
	return buildList
end

function buildTable(tableName, values, string, indent)
	string = string or ""
	indent = indent or 0
	local indentStr = string.rep("\t", indent)
	local nextIndentStr = string.rep("\t", indent + 1)
	string = string .. indentStr .. tableName .. " = {\n"
	for key, value in pairsSortByKey(values) do
		if type(value) == "table" then
			string = buildTable("[\"" .. key .. "\"]", value, string, indent + 1) .. ",\n"
		elseif type(value) == "boolean" then
			string = string .. nextIndentStr .. "[\"" .. key .. "\"] = " .. (value and "true" or "false") .. ",\n"
		elseif type(value) == "string" then
			string = string .. nextIndentStr .. "[\"" .. key .. "\"] = \"" .. value .. "\",\n"
		else
			string = string .. nextIndentStr .. "[\"" .. key .. "\"] = " .. round(value, 4) .. ",\n"
		end
	end
	string = string .. indentStr .. "}"
	return string
end

local function formatXmlFile(filepath)
	local command = "xmllint --c14n " .. filepath

	-- Open the command process for reading ('r')
	local handle = io.popen(command, 'r')
	if not handle then
		return nil, "Failed to run xmllint. Is it installed and in your PATH?"
	end

	-- Read the entire output from the command
	local result = handle:read("*a")
	handle:close()

	local fileHnd, errMsg = io.open(filepath:gsub("-unformatted", ""), "w")
	fileHnd:write(result)
	fileHnd:close()
end

expose("generate all builds", function()
	local buildList = fetchBuilds("../spec/TestBuilds")
	for filename, testBuild in pairs(buildList) do
		local buildName = filename:gsub("^.*/([^/]+/[^/]+)%.[^.]+$", "%1")

		it("on build: " .. buildName, function()
			-- Load the build and calculate stats
			print("Loading build: " .. buildName)
			loadBuildFromJSON(testBuild, testBuild)

			print("Saving main output")
			-- Save the calculated output to a Lua file in the generated sub-folder
			-- Get rid of circular reference issues first
			build.calcsTab.mainOutput.ReqDexItem = nil
			build.calcsTab.mainOutput.ReqIntItem = nil
			build.calcsTab.mainOutput.ReqStrItem = nil
			local outputFile = filename:gsub("^(.+)%..+$", "%1.lua")
			outputFile = outputFile:gsub("^(.+)/([^/]+)$", "%1/generated/%2")
			local fileHnd, errMsg = io.open(outputFile, "w+")
			fileHnd:write(buildTable("output", build.calcsTab.mainOutput))
			fileHnd:close()

			-- Save the XML DB file in the generated sub-folder
			print("Saving xml db file")
			build.dbFileName = outputFile:gsub("^(.+)%..+$", "%1-unformatted.xml")
			build:SaveDBFile()
			-- Format/order the XML file to easily see differences with previous generations
			formatXmlFile(build.dbFileName)
			-- Remove the unformatted XML file
			os.remove(build.dbFileName)
		end)
	end
end)
