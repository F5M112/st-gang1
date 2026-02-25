local QBCore = exports['qb-core']:GetCoreObject()
local CurrentLeaderboards = nil

-- Request leaderboards
RegisterNetEvent('gang:client:requestLeaderboards', function()
    TriggerServerEvent('gang:server:getLeaderboards')
end)

-- Receive leaderboards
RegisterNetEvent('gang:client:receiveLeaderboards', function(leaderboards)
    CurrentLeaderboards = leaderboards
    
    -- Send to NUI
    SendNUIMessage({
        action = 'updateLeaderboards',
        data = leaderboards
    })
end)

-- Auto-refresh leaderboards
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        TriggerServerEvent('gang:server:getLeaderboards')
    end
end)

-- Leaderboard display command
RegisterCommand('gangleaderboard', function()
    TriggerServerEvent('gang:server:getLeaderboards')
    Wait(500)
    
    if CurrentLeaderboards then
        print('^2========== GANG LEADERBOARD ==========^7')
        
        print('^3=== TOP GANGS BY MONEY ===^7')
        for i, gang in ipairs(CurrentLeaderboards.money) do
            if i <= 10 then
                print(string.format('#%d - %s: $%s', i, gang.name, gang.value))
            end
        end
        
        print('^3=== TOP GANGS BY TERRITORIES ===^7')
        for i, gang in ipairs(CurrentLeaderboards.territories) do
            if i <= 10 then
                print(string.format('#%d - %s: %d territories', i, gang.name, gang.value))
            end
        end
        
        print('^3=== TOP GANGS BY KILLS ===^7')
        for i, gang in ipairs(CurrentLeaderboards.kills) do
            if i <= 10 then
                print(string.format('#%d - %s: %d kills', i, gang.name, gang.value))
            end
        end
        
        print('^3=== TOP GANGS BY REPUTATION ===^7')
        for i, gang in ipairs(CurrentLeaderboards.reputation) do
            if i <= 10 then
                print(string.format('#%d - %s: %d reputation', i, gang.name, gang.value))
            end
        end
        
        print('^2=====================================^7')
    end
end)

-- Leaderboard history
RegisterNetEvent('gang:client:receiveLeaderboardHistory', function(history)
    if history and #history > 0 then
        print('^2========== LEADERBOARD HISTORY ==========^7')
        for _, entry in ipairs(history) do
            print(string.format('Week %d/%d - Category: %s - Position: #%d - Value: %d',
                entry.week, entry.year, entry.category, entry.position, entry.value))
        end
        print('^2=========================================^7')
    else
        QBCore.Functions.Notify('No leaderboard history available', 'error')
    end
end)

RegisterCommand('gangleaderboardhistory', function()
    TriggerServerEvent('gang:server:getLeaderboardHistory')
end)