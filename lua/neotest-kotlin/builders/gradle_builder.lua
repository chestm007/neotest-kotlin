local lib = require("neotest.lib")
local logger = require("neotest.logging")
local builders = require("neotest-kotlin.builders.util")
local util = require("neotest-kotlin.util")

---@class GradleBuilder
---@field root_indicator string
---@field create_single_spec fun(tree: neotest.Tree): neotest.RunSpec
local M = {
    rootIndicator = "build.gradle.kts",
}

function M.create_spec(tree)
    local position = tree:data()
    local proj_root = lib.files.match_root_pattern(M.rootIndicator)(position.path)

    local split = util.split(position.id, "::")
    local test_ref = builders._get_test_ref(position.type, split)

    vim.fn.fnamemodify(require("neotest.async").fn.tempname(), ":h")

    local command = {
        "gradle",
        "test",
        "--tests " .. test_ref.test_id,
    }

    local command_string = table.concat(command, " ")

    logger.debug("neotest-dotnet: Running tests using command: " .. command_string)

    return {
        command = command_string,
        context = {
            results_path = proj_root .. "/build/test-results/test" .. test_ref.report,
            file = position.path,
            id = position.id,
        },
    }
end

return M
