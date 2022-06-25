-- BaroStats v1 - sends barotrauma game session json info to an endpoint or a file
-- by MassCraxx

if CLIENT then return end

local path = table.pack(...)[1]

local json = dofile(path.."/json.lua")

-- CONFIG
local UpdateDelaySeconds = nil	-- If not nil, will checkstats every UpdateDelaySeconds
--local PostToEndpoint = true
--local EndPoint = "http://localhost:8080/update-status"
local WriteToFile = true
local CheckTickTimes = false	-- If true, will measure tick times for all mods, this may reduce overall performance

local updateTime = 0

local stats = {}
stats["Performance"] = {}

if CheckTickTimes and PerformanceCounter then
    Game.Log("[BaroStats] PerformanceCounter active", 6)
    PerformanceCounter.EnablePerformanceCounter = true
else
    CheckTickTimes = false
end

BaroStats = {}
BaroStats.AddStat = function(key, value)
    stats[key] = value
end

BaroStats.ResetTimer = function()
    updateTime = Timer.GetTime() + (UpdateDelaySeconds or 0)
end

BaroStats.UpdateStats = function()
    local statsJson = json.encode(stats)

    if WriteToFile then
        Game.Log("[BaroStats] Writing stats to disk...", 6)
        File.Write(path.."/stats.json", statsJson)
    end

    if PostToEndpoint and EndPoint then
        Networking.HttpPost(EndPoint, function(result)
            Game.Log("[BaroStats] UpdateStats POST complete. Result: " .. result, 6)
        end, statsJson)
    end
end

BaroStats.CheckPlayerStats = function()
    -- delay check to make sure hooks like roundEnded went through
    Timer.Wait(function () 
        BaroStats.ResetTimer()
        
        stats["Clients"] = {}
        stats["ClientsOnServer"] = #Client.ClientList
        stats["RoundStarted"] = Game.RoundStarted

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
                    if JustClownThings and JustClownThings.Clowns and client.Character and JustClownThings.Clowns[client.Character] then
                        clientStats.CharacterJob = "clown"
                    else
                        clientStats.CharacterJob = client.CharacterInfo.Job.Prefab.Identifier.Value
                    end
                end
                stats["Clients"][client.SteamID] = clientStats

                pingAverage = pingAverage + client.Ping

                if client.SpectateOnly then
                    spectators = spectators + 1
                elseif client.InGame then
                    playersInGame = playersInGame + 1
                end
            end
            pingAverage = pingAverage / #Client.ClientList

            stats["ClientsInGame"] = playersInGame
            stats["ClientsSpectating"] = spectators
            stats["ClientsPingAvg"] = pingAverage
        else
            stats["ClientsInGame"] = 0
            stats["ClientsSpectating"] = 0
            stats["ClientsPingAvg"] = 0
        end

        if Submarine.MainSub then
            stats["Submarine"] = Submarine.MainSub.Info.Name
        else
            stats["Submarine"] = "Lobby"
        end

        BaroStats.UpdateStats()
    end, 1000)
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

Hook.Add("think", "BaroStats.Think", function ()
    if CheckTickTimes then
        -- PerformanceCounter.HookElapsedTime and PerformanceCounter.UpdateElapsedTime
        -- HookElapsedTime is a table that contains how much time each hook took to process
        -- UpdateElapsedTime is just a number that shows how much time is taking for the game to process everything
        -- PerformanceCounter.HookElapsedTime["think"]["yourHookName"]
        
        for key, value in pairs(PerformanceCounter.HookElapsedTime) do
            if stats["Performance"][key] == nil then
                stats["Performance"][key] = {}
            end
            for key2, value2 in pairs(value) do
                if stats["Performance"][key][key2] == nil then
                    stats["Performance"][key][key2] = {}
                end
                if (stats["Performance"][key][key2].Min or 999) > value2 then
                    stats["Performance"][key][key2].Min = value2
                end

                if (stats["Performance"][key][key2].Max or -1) < value2 then
                    stats["Performance"][key][key2].Max = value2
                end
            end
        end

        if stats["Performance"].UpdateElapsedTime == nil then
            stats["Performance"].UpdateElapsedTime = {}
        end

        if (stats["Performance"].UpdateElapsedTime.Min or 999) > PerformanceCounter.UpdateElapsedTime then
            stats["Performance"].UpdateElapsedTime.Min = PerformanceCounter.UpdateElapsedTime
        end

        if (stats["Performance"].UpdateElapsedTime.Max or -1) < PerformanceCounter.UpdateElapsedTime then
            stats["Performance"].UpdateElapsedTime.Max = PerformanceCounter.UpdateElapsedTime
        end
    end

    if UpdateDelaySeconds and Timer.GetTime() > updateTime then
        BaroStats.CheckPlayerStats()
    end
end)

Game.AddCommand("writestats", "", function ()
    BaroStats.CheckPlayerStats()
end)

BaroStats.CheckPlayerStats()