local nio = require("nio")
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local builders = require("neotest-kotlin.builders.util")
local util = require("neotest-kotlin.util")
local maven_surefire = require("neotest-kotlin.stream_processors.maven_surefire")

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
---@field create_spec fun(tree: neotest.Tree): DirRunSpec
local M = {
    rootIndicator = "pom.xml",
}

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

function M.create_spec(tree)
    local stream_processor = maven_surefire(tree)
    local position = tree:data()
    logger.debug("fucking positions are WHAT?")
    logger.debug(position)
    local proj_root = lib.files.match_root_pattern(M.rootIndicator)(position.path)

    local run_spec = {
        command = "",
        context = {},
    } ---@type neotest.RunSpec

    local split = util.split(position.id, "::")
    local test_ref = builders._get_test_ref(position.type, split)

    vim.fn.fnamemodify(require("neotest.async").fn.tempname(), ":h")

    -- local stream_path = nio.fn.tempname()
    if position.type == "dir" then
        run_spec.command = "mvn test --color never -f " .. proj_root .. ' -Dtest="' .. test_ref.test_id .. '/**"'
        local positions = create_context_for_tree_node(tree, position.id)
        for _, _position in ipairs(positions) do
            ---@return string
            local function results_path_from_position()
                local out = {}
                for str in string.gmatch(_position.path, "com/(.*)") do
                    table.insert(out, str)
                end
                -- /path/to/com/company/test/testFile.kt
                -- to com.company.test.testFile.kt
                local package = "TEST-com." .. table.concat(out):gsub("/", "."):gsub("%.kt", ".xml")
                -- prepend absolute path and surefire report path.
                return "/target/surefire-reports/" .. package
            end

            table.insert(run_spec.context, {
                results_path = proj_root .. results_path_from_position(),
                file = _position.path,
                id = _position.id,
            })
        end
    else
        run_spec.command = "mvn test --color never -f "
            .. proj_root
            .. " -Dtest="
            .. util.replace(test_ref.test_id, "`", "")
        table.insert(run_spec.context, {
            results_path = proj_root .. "/target/surefire-reports/" .. test_ref.report,
            file = position.path,
            id = position.id,
        })
    end

    -- this is CALLED by the neotest framework when the test process starts.
    run_spec.stream = stream_processor.consume
    -- run_spec.strategy = strategy_config -- TODO: dap

    logger.debug("neotest-kotlin: Running tests using command: " .. run_spec.command)
    return run_spec
end

return M
