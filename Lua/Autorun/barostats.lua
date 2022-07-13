-- BaroStats v4 - sends barotrauma game session json info to an endpoint or a file
-- by MassCraxx

if CLIENT then return end

local path = table.pack(...)[1]
local json = dofile(path.."/json.lua")
local updateTime = 0
local logSendTime = 0
local pendingLogs = {}

BaroStats = {}
BaroStats.Stats = {}
BaroStats.Stats["ClientsMax"] = Game.ServerSettings.MaxPlayers
BaroStats.Config = dofile(path.."/config.lua")

if BaroStats.Config.CheckTickTimes and PerformanceCounter then
    BaroStats.Stats["Performance"] = {}
    Game.Log("[BaroStats] PerformanceCounter active", 6)
    PerformanceCounter.EnablePerformanceCounter = true
else
    BaroStats.Config.CheckTickTimes = false
end

BaroStats.AddStat = function(key, value)
    BaroStats.Stats[key] = value
end

BaroStats.UpdateStats = function()
    local statsJson = json.encode(BaroStats.Stats)

    if BaroStats.Config.WriteStatsToFile then
        Game.Log("[BaroStats] Writing stats to disk...", 6)
        File.Write(path.."/stats.json", statsJson)
    end

    if BaroStats.Config.SendStatsToEndpoint and BaroStats.Config.StatsEndPoint and Networking.HttpRequest then
        Networking.HttpRequest(BaroStats.Config.StatsEndPoint, function(result)
            Game.Log("[BaroStats] UpdateStats " .. BaroStats.Config.StatsRequestType .. " complete. Result: " .. result, 6)
        end, statsJson, BaroStats.Config.StatsRequestType)
    end
end

BaroStats.CheckPlayerStats = function()
    -- delay check to make sure hooks like roundEnded went through
    Timer.Wait(function () 
        updateTime = Timer.GetTime() + (BaroStats.Config.UpdateDelaySeconds or 0)
        
        BaroStats.Stats["Clients"] = {}
        BaroStats.Stats["ClientsOnServer"] = #Client.ClientList

        if #Client.ClientList > 0 then

            local playersInGame = 0
            local spectators = 0
            local pingAverage = 0

            for client in Client.ClientList do
                local clientStats = {}
                clientStats.Name = client.Name
                clientStats.Ping = client.Ping
                clientStats.Karma = client.Karma
                if client.CharacterInfo and client.CharacterInfo.Job then
                    if JustClownThings and JustClownThings.Clowns and client.Character 
                        and JustClownThings.Clowns[client.Character] and client.Character.TeamID == 0 then
                        clientStats.CharacterJob = "clown"
                    else
                        clientStats.CharacterJob = client.CharacterInfo.Job.Prefab.Identifier.Value
                    end
                end
                BaroStats.Stats["Clients"][client.SteamID] = clientStats

                pingAverage = pingAverage + client.Ping

                if client.SpectateOnly then
                    spectators = spectators + 1
                elseif client.InGame then
                    playersInGame = playersInGame + 1
                end
            end
            pingAverage = pingAverage / #Client.ClientList

            BaroStats.Stats["ClientsInGame"] = playersInGame
            BaroStats.Stats["ClientsSpectating"] = spectators
            BaroStats.Stats["ClientsPingAvg"] = pingAverage
        else
            BaroStats.Stats["ClientsInGame"] = 0
            BaroStats.Stats["ClientsSpectating"] = 0
            BaroStats.Stats["ClientsPingAvg"] = 0
        end

        BaroStats.Stats["RoundStarted"] = Game.RoundStarted
        
        if Submarine.MainSub then
            BaroStats.Stats["Submarine"] = Submarine.MainSub.Info.Name
        else
            BaroStats.Stats["Submarine"] = "Lobby"
        end

        BaroStats.UpdateStats()
    end, 1000)
end

BaroStats.SendLogs = function(data)
    Networking.HttpRequest(BaroStats.Config.LogsEndPoint, function(result) end, json.encode(data), BaroStats.Config.LogsRequestType)
end

Hook.Add("roundStart", "BaroStats.roundStart", function ()
    BaroStats.CheckPlayerStats()
end)

Hook.Add("roundEnd", "BaroStats.roundEnd", function ()
    BaroStats.CheckPlayerStats()
end)

Hook.Add("client.connected", "BaroStats.clientConnected", function ()
    BaroStats.CheckPlayerStats()
end)

Hook.Add("client.disconnected", "BaroStats.clientDisconnected", function ()
    BaroStats.CheckPlayerStats()
end)

if BaroStats.Config.LogsSendDelay or BaroStats.Config.CheckTickTimes or BaroStats.Config.UpdateDelaySeconds then
Hook.Add("think", "BaroStats.Think", function ()
    if BaroStats.Config.CheckTickTimes then
        -- PerformanceCounter.HookElapsedTime and PerformanceCounter.UpdateElapsedTime
        -- HookElapsedTime is a table that contains how much time each hook took to process
        -- UpdateElapsedTime is just a number that shows how much time is taking for the game to process everything
        -- PerformanceCounter.HookElapsedTime["think"]["yourHookName"]
        
        for key, value in pairs(PerformanceCounter.HookElapsedTime) do
            if BaroStats.Stats["Performance"][key] == nil then
                BaroStats.Stats["Performance"][key] = {}
            end
            for key2, value2 in pairs(value) do
                if BaroStats.Stats["Performance"][key][key2] == nil then
                    BaroStats.Stats["Performance"][key][key2] = {}
                end
                if (BaroStats.Stats["Performance"][key][key2].Min or 999) > value2 then
                    BaroStats.Stats["Performance"][key][key2].Min = value2
                end

                if (BaroStats.Stats["Performance"][key][key2].Max or -1) < value2 then
                    BaroStats.Stats["Performance"][key][key2].Max = value2
                end
            end
        end

        if BaroStats.Stats["Performance"].UpdateElapsedTime == nil then
            BaroStats.Stats["Performance"].UpdateElapsedTime = {}
        end

        if (BaroStats.Stats["Performance"].UpdateElapsedTime.Min or 999) > PerformanceCounter.UpdateElapsedTime then
            BaroStats.Stats["Performance"].UpdateElapsedTime.Min = PerformanceCounter.UpdateElapsedTime
        end

        if (BaroStats.Stats["Performance"].UpdateElapsedTime.Max or -1) < PerformanceCounter.UpdateElapsedTime then
            BaroStats.Stats["Performance"].UpdateElapsedTime.Max = PerformanceCounter.UpdateElapsedTime
        end
    end

    if BaroStats.Config.UpdateDelaySeconds and Timer.GetTime() > updateTime then
        BaroStats.CheckPlayerStats()
    end

    if BaroStats.Config.LogsSendDelay and Timer.GetTime() > logSendTime then
        if #pendingLogs > 0 then
            BaroStats.SendLogs(pendingLogs)
            pendingLogs = {}
        end
        logSendTime = Timer.GetTime() + (BaroStats.Config.LogsSendDelay or 1)
    end
end)
end

if BaroStats.Config.SendLogsToEndpoint then
Hook.Add("serverLog", "BaroStats.serverLog", function (line, messageType)
    local data = {}
    data["Line"] = line
    data["MessageType"] = messageType
    data["Time"] = os.time()

    if BaroStats.Config.LogsSendDelay then
        table.insert(pendingLogs, data)
    else
        BaroStats.SendLogs(data)
    end
end)
end

Game.AddCommand("updatestats", "", function ()
    BaroStats.CheckPlayerStats()
end)

BaroStats.CheckPlayerStats()