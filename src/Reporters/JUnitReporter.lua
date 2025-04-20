local TestEnum = require(script.Parent.Parent.TestEnum)

local JUnitReporter = {}

-- Escape special XML characters in attributes
local function escapeXml(str)
	return tostring(str)
		:gsub("&", "&amp;")
		:gsub("<", "&lt;")
		:gsub(">", "&gt;")
		:gsub('"', "&quot;")
		:gsub("'", "&apos;")
end

-- Create a <testcase> XML node
local function createTestCase(testNode, classPrefix)
	local phrase = testNode.planNode.phrase
	local classname = classPrefix or ""
	local status = testNode.status
	local errors = testNode.errors

	local testCase = {
		tag = "testcase",
		attributes = {
			name = escapeXml(phrase),
			classname = escapeXml(classname),
		},
		children = {},
	}

	if status == TestEnum.TestStatus.Failure then
		local message = errors and errors[1] or "Test failed"
		table.insert(testCase.children, {
			tag = "failure",
			attributes = {
				message = escapeXml(message),
			},
			children = {},
		})
	end

	return testCase
end

-- Recursively flatten test nodes and collect test cases grouped by suite
local function collectTestSuites(node, parentName, suites)
	parentName = parentName and (parentName .. "." .. node.planNode.phrase) or node.planNode.phrase

	if node.planNode.type == TestEnum.NodeType.Describe then
		for _, child in ipairs(node.children) do
			collectTestSuites(child, parentName, suites)
		end
	elseif node.planNode.type == TestEnum.NodeType.It then
		local suite = suites[parentName]

		if not suite then
			suite = {
				tag = "testsuite",
				attributes = {
					name = escapeXml(parentName),
					tests = 0,
					failures = 0,
					errors = 0,
				},
				children = {},
			}
			suites[parentName] = suite
		end

		suite.attributes.tests = suite.attributes.tests + 1

		if node.status == TestEnum.TestStatus.Failure then
			suite.attributes.failures = suite.attributes.failures + 1
		end

		local testCase = createTestCase(node, parentName)
		table.insert(suite.children, testCase)
	end
end

-- Render XML from our custom node structure
local function render(node)
	local attrStr = ""
	for k, v in pairs(node.attributes or {}) do
		attrStr = attrStr .. string.format(' %s="%s"', k, v)
	end

	local xml = ""

	if #node.children == 0 then
		xml = string.format("<%s%s />", node.tag, attrStr)
	else
		xml = string.format("<%s%s>", node.tag, attrStr)

		for _, child in ipairs(node.children or {}) do
			xml = xml .. render(child)
		end

		xml = xml .. string.format("</%s>", node.tag)
	end

	return xml
end

-- Main report function
function JUnitReporter.report(results)
	local suites = {}

	-- Collect flat suite list
	for _, child in ipairs(results.children or {}) do
		collectTestSuites(child, nil, suites)
	end

	-- Assemble top-level <testsuites> node
	local root = {
		tag = "testsuites",
		children = {},
	}

	for _, suite in pairs(suites) do
		table.insert(root.children, suite)
	end

	local xmlDoc = '<?xml version="1.0" encoding="UTF-8"?>\n' .. render(root)
	print(xmlDoc)
	return xmlDoc
end

return JUnitReporter
