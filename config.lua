local config = {}

config.Server = "http://localhost:8081/"

-- STATS --
config.WriteStatsToFile = true
config.SendStatsToEndpoint = false
config.StatsEndPoint = config.Server .. "update-status"
config.StatsRequestType = "PATCH"

-- LOGS --
config.SendLogsToEndpoint = false
config.LogsEndPoint = config.Server .. "push-log"
config.LogsRequestType = "POST"

-- EXTRAS --
config.UpdateDelaySeconds = nil	-- If not nil, will check stats every UpdateDelaySeconds
config.CheckTickTimes = false	-- If true, will measure tick times for all mods, this may reduce overall performance

return config