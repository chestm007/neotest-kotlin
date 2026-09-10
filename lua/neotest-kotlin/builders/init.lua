local maven = require("neotest-kotlin.builders.maven_builder")
local gradle = require("neotest-kotlin.builders.gradle_builder")
local async = require("neotest.async")
local logger = require("neotest.logging")

---@class Builder
---@field build_spec fun(tree: neotest.Tree, specs?: neotest.RunSpec[]): neotest.RunSpec[]
---@field build_spec_exp fun(tree: neotest.Tree, specs?: neotest.RunSpec[]): neotest.RunSpec[]
local M = {}

---@param mode "maven" | "gradle"
function M.set_builder(mode)
    if mode == "maven" then
        M._builder = maven
    end
    if mode == "gradle" then
        M._builder = gradle
    end
    return M
end

M._builder = {
    build_spec = function(...)
        error("No valid builder set.")
    end,
}

function M.build_spec(tree, specs)
    specs = specs or {}
    local spec = M._builder.create_spec(tree)
    if spec == nil then
        logger.warn("create_spec returned nil.")
    else
        table.insert(specs, spec)
    end
    return #specs < 0 and nil or specs
end

return M
