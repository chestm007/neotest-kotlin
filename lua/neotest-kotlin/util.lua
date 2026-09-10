local M = {}

function M.contains(inputstr, pattern)
    return (inputstr:gmatch(pattern)() ~= nil)
end

function M.split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function M.indexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

-- TODO: should we allow people to specify the cutoff ?
function M.get_package(file)
    local x = vim.fn.fnamemodify(file, ":p:h")
    local pathTable = M.split(x, "/")

    --- Handle cases where lazy dev's havent renamed the test directory.
    local cutoff
    if vim.tbl_contains(pathTable, "kotlin") then
        cutoff = M.indexOf(pathTable, "kotlin")
    elseif vim.tbl_contains(pathTable, "java") then
        cutoff = M.indexOf(pathTable, "java")
    else
        vim.notify("unable to determine package, neither 'kotlin', nor 'java' were present in the filepath.")
    end

    local size1 = 0
    for _ in pairs(pathTable) do
        size1 = size1 + 1
    end
    for _ = cutoff, 1, -1 do
        table.remove(pathTable, 1)
    end

    return table.concat(pathTable, ".")
end

---@param test_ref string
---@param pattern string
---@param replace? string  default = ""
---@return string
function M.replace(test_ref, pattern, replace)
    local sanitised, _ = string.gsub(test_ref, pattern, replace or "")
    return sanitised
end

return M
