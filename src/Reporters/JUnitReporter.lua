local TestEnum = require(script.Parent.Parent.TestEnum)

local JUnitReporter = {}

local function escapeXml(str)
	return tostring(str)
		:gsub("&", "&amp;")
		:gsub("<", "&lt;")
		:gsub(">", "&gt;")
		:gsub('"', "&quot;")
		:gsub("'", "&apos;")
end

local function createTestCase(testNode, classname)
	local phrase = testNode.planNode.phrase
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

-- Recursively walk test tree and collect grouped test cases
local function collectTestSuites(node, parentPath, suites)
	local currentPath = parentPath and (parentPath .. "." .. node.planNode.phrase) or node.planNode.phrase

	if node.planNode.type == TestEnum.NodeType.Describe then
		for _, child in ipairs(node.children) do
			collectTestSuites(child, currentPath, suites)
		end
	elseif node.planNode.type == TestEnum.NodeType.It then
		-- Extract suite name from path: everything except the last segment
		local suiteName = parentPath or "Root"
		local fullClassname = currentPath

		local suite = suites[suiteName]
		if not suite then
			suite = {
				tag = "testsuite",
				attributes = {
					name = escapeXml(suiteName),
					tests = 0,
					failures = 0,
					errors = 0,
				},
				children = {},
			}
			suites[suiteName] = suite
		end

		suite.attributes.tests += 1
		if node.status == TestEnum.TestStatus.Failure then
			suite.attributes.failures += 1
		end

		local testCase = createTestCase(node, fullClassname)
		table.insert(suite.children, testCase)
	end
end

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

function JUnitReporter.report(results)
	local suites = {}

	for _, child in ipairs(results.children or {}) do
		collectTestSuites(child, nil, suites)
	end

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
