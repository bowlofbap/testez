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

local function createTestCase(name, classname, status, errors)
    local tc = {
        tag = "testcase",
        attributes = {
            name = escapeXml(name),
            classname = escapeXml(classname),
        },
        children = {},
    }

    if status == TestEnum.TestStatus.Failure then
        local firstLine = errors and errors[1] or "Test failed"
        table.insert(tc.children, {
            tag = "failure",
            attributes = {
                message = escapeXml(firstLine),
            },
            children = {},
        })
    end

    return tc
end

local function reportNode(node, classPrefix)
    local elems = {}

    if node.planNode.type == TestEnum.NodeType.Describe then
        local suite = {
            tag = "testsuite",
            attributes = {
                name = escapeXml(node.planNode.phrase),
            },
            children = {},
        }

        local prefix = classPrefix and (classPrefix .. "." .. node.planNode.phrase) or node.planNode.phrase

        for _, child in ipairs(node.children) do
            for _, sub in ipairs(reportNode(child, prefix)) do
                table.insert(suite.children, sub)
            end
        end

        table.insert(elems, suite)
    else
        table.insert(elems, createTestCase(
            node.planNode.phrase,
            classPrefix or "",
            node.status,
            node.errors
        ))
    end

    return elems
end

function JUnitReporter.report(results)
    local root = {
        tag = "testsuites",
        children = {},
    }

    for _, child in ipairs(results.children or {}) do
        for _, suite in ipairs(reportNode(child)) do
            table.insert(root.children, suite)
        end
    end

    local function render(node)
        local attrStr = ""
        for k, v in pairs(node.attributes or {}) do
            attrStr = attrStr .. string.format(' %s="%s"', k, v)
        end

        local xml = ""

        if #node.children == 0 then
            xml = string.format("<%s%s></%s>", node.tag, attrStr, node.tag)
        else
            xml = string.format("<%s%s>", node.tag, attrStr)
			if node.tag ~= "failure" then

				for _, child in ipairs(node.children or {}) do
					xml = xml .. render(child)
				end
			end
            xml = xml .. string.format("</%s>", node.tag)
        end

        return xml
    end

    local xmlDoc = '<?xml version="1.0" encoding="UTF-8"?>\n' .. render(root)
	print(xmlDoc)
    return xmlDoc
end

return JUnitReporter