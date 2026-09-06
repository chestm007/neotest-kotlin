local async = require("neotest.async")
local logger = require("neotest.logging")
local builders = require("neotest-kotlin.builders.util")
local util = require("neotest-kotlin.util")

---@class DirRunSpec : neotest.RunSpec
---@field context RunContext[]

---@class RunContext
---@field results_path string
---@field file string
---@field id string

---@class RunSpec : neotest.RunSpec
---@field context RunContext

---@class MavenBuilder
---@field root_indicator string
---@field create_single_spec fun(position: neotest.Position, proj_root: string, filter_arg?: {}): RunSpec
---@field create_dir_spec fun(tree: neotest.Tree, proj_root: string, filter_arg?: {}): DirRunSpec
local M = {
    rootIndicator = "pom.xml",
}

function M.create_single_spec(position, proj_root, filter_arg)
    local results_path = async.fn.tempname() .. ".trx"
    filter_arg = filter_arg or ""

    local split = util.split(position.id, "::")
    local test_ref = builders._get_test_ref(position.type, split)

    vim.fn.fnamemodify(require("neotest.async").fn.tempname(), ":h")

    local command = {
        "mvn",
        "test",
        "-l " .. results_path,
        "-f " .. proj_root,
        '-Dtest="' .. util.replace(test_ref.test_id, "`") .. '"',
    }

    local command_string = table.concat(command, " ")

    logger.warn("neotest-kotlin: Running tests using command: " .. command_string)

    return {
        command = command_string,
        context = {
            results_path = proj_root .. "/target/surefire-reports/" .. test_ref.report,
            file = position.path,
            id = position.id,
        },
    }
end

---@param tree neotest.Tree
---@param node_id string
---@param positions? neotest.Position[]
---@return neotest.Position[]
local function create_context_for_tree_node(tree, node_id, positions)
    logger.debug("processing context for node: " .. node_id)
    positions = positions or {} ---@type neotest.PositionType[]
    for _, node in tree:get_key(node_id):iter_nodes() do
        local node_data = node:data()
        if node_data.type == "dir" then
            logger.debug("processing dir: " .. node_data.id)
        elseif node_data.type == "file" then
            logger.debug("processing file: " .. node_data.name)
            table.insert(positions, node_data)
        end
    end
    return positions
end

function M.create_dir_spec(tree, proj_root, filter_arg)
    local position = tree:data()
    local results_path = async.fn.tempname() .. ".trx"

    local split = util.split(position.id, "::")
    local test_ref = builders._get_test_ref(position.type, split)

    local positions = create_context_for_tree_node(tree, position.id)

    filter_arg = filter_arg or ""

    vim.fn.fnamemodify(require("neotest.async").fn.tempname(), ":h")

    local command = {
        "mvn",
        "test",
        "-l " .. results_path,
        "-f " .. proj_root,
        '-Dtest="' .. test_ref.test_id .. '/**"',
    }

    local command_string = table.concat(command, " ")

    logger.debug("neotest-kotlin: Running tests using command: " .. command_string)

    local context = {} ---@type RunContext[]

    for _, _position in ipairs(positions) do
        ---@return string
        local function results_path_from_position()
            local out = {}
            for str in string.gmatch(_position.path, "com/(.*)") do
                table.insert(out, str)
            end
            -- /path/to/com/company/test/testFile.kt
            -- to com.company.test.testFile.kt
            local package = "TEST-com." .. table.concat(out):gsub("/", "."):gsub(".kt", ".xml")
            -- prepend absolute path and surefire report path.
            return "/target/surefire-reports/" .. package
        end

        table.insert(context, {
            results_path = proj_root .. results_path_from_position(),
            file = _position.path,
            id = _position.id,
        })
    end

    return {
        command = command_string,
        context = context,
    }
end

return M
