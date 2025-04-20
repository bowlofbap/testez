local TestEnum = require(script.Parent.Parent.TestEnum)

local JUnitReporter = {}

local function createTestCase(name, classname, status, errors)
	local testcase = {
		tag = "testcase",
		attributes = {
			name = name,
			classname = classname
		},
		children = {}
	}

	if status == TestEnum.TestStatus.Failure then
		table.insert(testcase.children, {
			tag = "failure",
			attributes = {
				message = errors and errors[1] or "Test failed"
			},
			text = table.concat(errors or {}, "\n")
		})
	end

	return testcase
end

local function reportNode(node, classPrefix)
	local elements = {}

	if node.planNode.type == TestEnum.NodeType.Describe then
		local suite = {
			tag = "testsuite",
			attributes = {
				name = node.planNode.phrase
			},
			children = {}
		}
		for _, child in ipairs(node.children) do
			for _, c in ipairs(reportNode(child, (classPrefix and classPrefix .. "." or "") .. node.planNode.phrase)) do
				table.insert(suite.children, c)
			end
		end
		table.insert(elements, suite)
	else
		table.insert(elements, createTestCase(
			node.planNode.phrase,
			classPrefix,
			node.status,
			node.errors
		))
	end

	return elements
end

function JUnitReporter.report(results)
	local rootSuite = {
		tag = "testsuites",
		children = {}
	}

	for _, child in ipairs(results.children) do
		for _, suite in ipairs(reportNode(child)) do
			table.insert(rootSuite.children, suite)
		end
	end

	local function render(node)
		local attributes = ""
		for k, v in pairs(node.attributes or {}) do
			attributes = attributes .. string.format(' %s="%s"', k, v)
		end

		if (not node.children or #node.children == 0) and not node.text then
			return string.format("<%s%s />", node.tag, attributes)
		end

		local inner = ""
		if node.text then inner = node.text end
		if node.children then
			for _, c in ipairs(node.children) do
				inner = inner .. render(c)
			end
		end

		return string.format("<%s%s>%s</%s>", node.tag, attributes, inner, node.tag)
	end

	local xml = '<?xml version="1.0" encoding="UTF-8"?>\n' .. render(rootSuite)

	print(xml)
    return xml
end

return JUnitReporter
