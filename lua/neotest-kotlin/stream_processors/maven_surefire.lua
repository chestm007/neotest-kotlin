local logger = require("neotest.logging")
local lib = require("neotest.lib")
local util = require("neotest-kotlin.util")

---@param tree neotest.Tree
---@return table<string, table>
local function get_test_nodes_data(tree)
    local test_nodes = {}
    for _, node in tree:iter_nodes() do
        local data = node:data()
        -- if node:data().type == "test" then
        local key = util.replace(data.id, "`")
        test_nodes[key] = data
        -- table.insert(test_nodes, node)
        -- end
    end

    -- logger.debug("test_nodes:: ", test_nodes)
    return test_nodes
end

---@param line string
local function log_message_kind(line) end

local _States = {
    starting = 1,
    consuming = 2,
    parsing_tests = 5,
    parsing_failed_test = 7,
    finished_parsing_tests = 10,
    exited = 100,
}

---@param tree neotest.Tree?
return function(tree)
    local _state = _States.starting
    local _test_result = {
        output = "",
    } ---@type neotest.Result

    ---@param line string
    --- responsible for updating the main status changes we will have as the "stage" of the log progresses.
    local function assess_parsing_stage(line)
        if _state < _States.parsing_tests then
            if util.contains(line, "T E S T S") then
                -- update state when we hit the beginning of test log output.
                logger.debug("parsing tests.")
                _state = _States.parsing_tests
            end
        elseif _state == _States.parsing_failed_test then
            if vim.startswith(line, "[INFO]") then
                logger.debug("finished parsing failed tests.")
                logger.debug("parsing tests.")
                -- if we're parsing a stacktrace, but we hit "[INFO]", no more stacktrace
                -- this is likely a redundant state check as the main processor will already detect this
                _state = _States.parsing_tests
            end
        elseif _state < _States.finished_parsing_tests then
            if vim.startswith(line, "[INFO] Results:") then
                logger.debug("finished parsing tests.")
                _state = _States.finished_parsing_tests
            end
        end
    end

    local _test_nodes = get_test_nodes_data(tree) ---@type table<string, table>

    -- given a namespace and test case name, return the corresponding node ID to send back to neotest
    local function get_node_id_for_testcase(namespace, test_case)
        local prefix = namespace:gmatch("(.*)%.")() -- com.acme.test
        local package = namespace:gmatch(prefix .. "%.(.*)")() -- get everything AFTER the "prefix"
        local my_key
        if test_case ~= nil then
            my_key = "::" .. package .. "::" .. test_case
        else
            my_key = "::" .. package
        end
        logger.debug("finding node_id for :", my_key)
        for key, data in pairs(_test_nodes) do
            if vim.endswith(key, my_key) then
                logger.debug("found node id: ", key, data)
                return data.path .. my_key
            end
        end
    end

    ---@type fun(stream: string[]): fun(): table<string, neotest.Result>
    local function consume(stream)
        local results = {} ---@type table<string, neotest.Result>
        ---@param result neotest.Result
        ---@param namespace string
        ---@param test_case? string
        local function add_test_result(result, namespace, test_case)
            logger.debug("getting node id for: ", namespace, test_case)
            local node_id = nil
            if test_case ~= nil then
                for _, try in ipairs({ test_case, "`" .. test_case .. "`" }) do
                    node_id = get_node_id_for_testcase(namespace, try)
                    if node_id ~= nil then
                        break
                    end
                end
            else
                node_id = get_node_id_for_testcase(namespace)
            end
            if node_id == nil then
                logger.error("got no node_id for: ", namespace, test_case)
                local key = (namespace or "<none>") .. "::" .. (test_case or "")
                vim.notify(key .. " fucked up", vim.log.levels.ERROR)
            else
                logger.debug("recieved node id: ", node_id)
                logger.debug("adding result to the cache: ", result)
                results[node_id] = result
            end
        end

        _state = _States.consuming

        local _current_test_namespace = nil
        local _current_test_case = nil
        local _test_case_result = nil ---@type neotest.Result?

        local _namespace_result = nil ---@type neotest.Result

        logger.debug("test_nodes:: \n ")
        logger.debug(_test_nodes)
        logger.debug("consuming stream...")
        return function()
            results = {}
            chunk = stream()
            -- TODO: should we clear results here, so that we arent passing the same shit back when its not needed?

            for _, line in ipairs(chunk) do
                _test_result.output = _test_result.output .. "\n" .. line
                assess_parsing_stage(line)

                if _States.finished_parsing_tests > _state and _state >= _States.parsing_tests then
                    local _test_namespace = line:gmatch(" Running (.*)")() -- [INFO] Running com.acme.test.TestCase
                    if _test_namespace ~= nil then
                        logger.debug("_test_namespace: ", _test_namespace)
                        -- we've hit a namespace line, process it and add the previous results to the list if they exist
                        if _namespace_result ~= nil and _current_test_namespace ~= nil then
                            add_test_result(_namespace_result, _current_test_namespace)
                        end
                        _current_test_namespace, _ = _test_namespace:gsub(" ", "")
                        logger.debug("_current_test_namespace: ", _current_test_namespace)
                        _namespace_result = {
                            status = "skipped",
                            output = "",
                            short = line,
                            errors = {},
                        }
                    elseif _current_test_namespace ~= nil then
                        if _namespace_result ~= nil then
                            _namespace_result.output = _namespace_result.output .. "\n" .. line
                        end
                        -- [INFO] com.acme.test.TestCase.testTheTestsTest  Time elapsed: 0.008s
                        --  will also strip anything after $ incase its a parameterised test
                        local _test_case = nil
                        _test_case, _ = line:gmatch("%[INFO%] " .. _current_test_namespace .. ".(.*)  Time.*")()
                        logger.debug("_test_case: ", _test_case)
                        -- NOTE: example failure
                        -- [INFO] Running com.zepben.ewb.cim.iec61970.base.generation.production.PowerElectronicsUnitTest
                        -- [ERROR] Tests run: 3, Failures: 1, Errors: 0, Skipped: 0, Time elapsed: 0.102 s <<< FAILURE! - in com.zepben.ewb.cim.iec61970.base.generation.production.PowerElectronicsUnitTest
                        -- [ERROR] com.zepben.ewb.cim.iec61970.base.generation.production.PowerElectronicsUnitTest.accessorCoverage$ewb_sdk  Time elapsed: 0.075 s  <<< FAILURE!
                        -- java.lang.AssertionError:
                        --
                        -- Expected: <1>
                        --     but: was <3>
                        -- ...
                        -- 	at org.apache.maven.surefire.booter.ForkedBooter.run(ForkedBooter.java:595)
                        --     at org.apache.maven.surefire.booter.ForkedBooter.main(ForkedBooter.java:581)
                        --
                        -- [ERROR] com.zepben.ewb.cim.iec61970.base.generation.production.PowerElectronicsUnitTest.throwsOnReassignment$ewb_sdk  Time elapsed: 0.008 s
                        -- [ERROR] com.zepben.ewb.cim.iec61970.base.generation.production.PowerElectronicsUnitTest.constructorCoverage$ewb_sdk  Time elapsed: 0.001 s
                        -- [INFO] Running com.zepben.ewb.cim.iec61970.base.generation.production.PowerElectronicsUnitTest

                        -- NOTE: example test pass
                        -- [INFO] Running com.zepben.ewb.cim.iec61970.base.generation.production.PowerElectronicsUnitTest
                        -- [INFO] Tests run: 3, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 0.108 s - in com.zepben.ewb.cim.iec61970.base.generation.production.PowerElectronicsUnitTest
                        -- [INFO] com.zepben.ewb.cim.iec61970.base.generation.production.PowerElectronicsUnitTest.accessorCoverage$ewb_sdk  Time elapsed: 0.078 s
                        -- [INFO] com.zepben.ewb.cim.iec61970.base.generation.production.PowerElectronicsUnitTest.throwsOnReassignment$ewb_sdk  Time elapsed: 0.01 s
                        -- [INFO] com.zepben.ewb.cim.iec61970.base.generation.production.PowerElectronicsUnitTest.constructorCoverage$ewb_sdk  Time elapsed: 0.002 s

                        if _test_case ~= nil then
                            _test_case = _test_case:gsub("%$(.*)", "")
                            logger.debug("_test_case: ", _test_case)
                            logger.debug("_current_test_namespace: ", _current_test_namespace)
                            if _test_case_result ~= nil and _current_test_case ~= nil then
                                add_test_result(_test_case, _current_test_namespace, _current_test_case)
                                _test_case_result = nil
                            end
                            _current_test_case = _test_case

                            if
                                -- TODO: test has failed, capture errors until we hit another [INFO] line
                                vim.startswith(line, "[ERROR] " .. _current_test_namespace)
                                or _state == _States.parsing_failed_test
                            then
                                logger.debug("failed test, starting error capture")
                                _state = _States.parsing_failed_test
                                _test_case_result = {
                                    status = "failed",
                                    short = line,
                                    output = line,
                                }
                            elseif vim.startswith(line, "[INFO] " .. _current_test_namespace) then
                                -- TODO: test has passed, add to results

                                _test_case_result = nil
                                add_test_result({
                                    status = "passed",
                                    short = line,
                                    output = line,
                                }, _current_test_namespace, _current_test_case)
                            elseif _state == _States.parsing_failed_test then
                                logger.debug("failed test, continuing error capture")
                                _test_case_result.output = _test_case_result .. "\n" .. line
                            else
                                logger.debug("nothing interesting?")
                                _test_case_result = nil
                            end
                        end
                    end
                end
                logger.debug(line)
            end
            return results
        end
    end

    return {
        consume = consume,
    }
end
