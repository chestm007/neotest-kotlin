---@alias StreamConsumer fun(stream: string[]): fun(): table<string, neotest.Result>

---@class neotest.StreamProcessor
---@field consume StreamConsumer
