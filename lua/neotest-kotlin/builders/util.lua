local util = require("neotest-kotlin.util")
local lib = require("neotest.lib")
local tquery = require("neotest-kotlin.treesitter.junit-queries")

local M = {}

---@param path string
---@return string
local function test_package_from_path(path)
    local out = {}
    for str in string.gmatch(path, "com/(.*)") do
        table.insert(out, str)
    end
    return "com/" .. table.concat(out)
end

---@param position_type neotest.PositionType
---@param split string[]
---@param tree? neotest.Tree
function M._get_test_ref(position_type, split, tree)
    if position_type == "test" then
        return {
            test_id = split[#split - 1] .. "#" .. split[#split],
            report = "TEST-" .. util.get_package(split[1]) .. "." .. split[#split - 1] .. ".xml",
        }
    elseif position_type == "namespace" then
        return {
            test_id = split[#split],
            report = "TEST-" .. util.get_package(split[1]) .. "." .. split[#split] .. ".xml",
        }
    elseif position_type == "file" then
        local query = tquery.NameSpace .. tquery.TestCase

        local tree = lib.treesitter.parse_positions(split[1], query, {})
        return {
            test_id = tree:to_list()[2][1].name,
            report = "TEST-" .. util.get_package(split[1]) .. "." .. tree:to_list()[2][1].name .. ".xml",
        }
    elseif position_type == "dir" then
        local test_package = test_package_from_path(split[1])

        return {
            test_id = test_package,
            report = "TEST-" .. test_package,
        }
    end
end

return M
